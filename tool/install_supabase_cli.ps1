param(
  [string]$Version = 'latest'
)

$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

$installDir = Join-Path $workspace 'tool\.supabase-cli'
New-Item -ItemType Directory -Force -Path $installDir | Out-Null

function Get-LatestRelease {
  $headers = @{
    'User-Agent' = 'freshline-setup'
    'Accept'     = 'application/vnd.github+json'
  }
  return Invoke-RestMethod -Uri 'https://api.github.com/repos/supabase/cli/releases/latest' -Headers $headers
}

function Get-ReleaseByTag {
  param([Parameter(Mandatory = $true)][string]$Tag)
  $headers = @{
    'User-Agent' = 'freshline-setup'
    'Accept'     = 'application/vnd.github+json'
  }
  return Invoke-RestMethod -Uri ("https://api.github.com/repos/supabase/cli/releases/tags/{0}" -f $Tag) -Headers $headers
}

$release = if ($Version -eq 'latest') { Get-LatestRelease } else { Get-ReleaseByTag -Tag $Version }

$asset = $release.assets |
  Where-Object { $_.name -match 'windows' -and $_.name -match 'amd64' -and $_.name -match '\\.zip$' } |
  Select-Object -First 1

if (-not $asset) {
  $asset = $release.assets |
    Where-Object { $_.name -match 'windows' -and $_.name -match '\\.zip$' } |
    Select-Object -First 1
}

if (-not $asset) {
  throw "Could not find a Windows zip asset in Supabase CLI release '$($release.tag_name)'."
}

$zipPath = Join-Path $env:TEMP ("supabase-cli-{0}.zip" -f $release.tag_name)
Write-Host "Downloading Supabase CLI $($release.tag_name) -> $zipPath"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

Write-Host "Extracting to $installDir"
Get-ChildItem -LiteralPath $installDir -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Expand-Archive -LiteralPath $zipPath -DestinationPath $installDir -Force

$exe = Get-ChildItem -LiteralPath $installDir -Recurse -Filter supabase.exe | Select-Object -First 1
if (-not $exe) {
  throw "supabase.exe not found after extraction."
}

Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $installDir 'supabase.exe') -Force

Write-Host "Installed: $installDir\\supabase.exe"
Write-Host "Try: .\\tool\\.supabase-cli\\supabase.exe --version"

