param(
  [string]$ProjectRef,
  [string]$ResendApiKey,
  [string]$AuthEmailFrom,
  [string]$AuthEmailReplyTo
)

$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $workspace

function Resolve-SupabaseProjectRef {
  if ($ProjectRef -and $ProjectRef.Trim() -ne '') {
    return $ProjectRef.Trim()
  }

  $configPath = Join-Path $workspace 'lib\src\config\app_config.dart'
  if (-not (Test-Path -LiteralPath $configPath)) {
    return $null
  }

  $content = Get-Content -LiteralPath $configPath -Raw
  $match = [regex]::Match($content, "supabaseUrl\\s*=\\s*'https://([a-z0-9-]+)\\.supabase\\.co'", 'IgnoreCase')
  if ($match.Success) {
    return $match.Groups[1].Value
  }

  return $null
}

function Require-Command {
  param([Parameter(Mandatory = $true)][string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $local = Join-Path $workspace 'tool\.supabase-cli\supabase.exe'
    if ($Name -eq 'supabase' -and (Test-Path -LiteralPath $local)) {
      return $local
    }
    throw "Missing required CLI: '$Name'. Install Supabase CLI then retry (or run tool\\install_supabase_cli.ps1)."
  }
  return $cmd.Source
}

$supabase = Require-Command -Name 'supabase'
$ref = Resolve-SupabaseProjectRef

if (-not $ref) {
  throw "Could not determine Supabase project ref. Pass -ProjectRef <ref>."
}

Write-Host "Linking Supabase project ref: $ref"
& $supabase link --project-ref $ref

Write-Host "Deploying Edge Functions: send-auth-otp, verify-auth-otp"
& $supabase functions deploy send-auth-otp
& $supabase functions deploy verify-auth-otp

if (($ResendApiKey -and $ResendApiKey.Trim() -ne '') -or
    ($AuthEmailFrom -and $AuthEmailFrom.Trim() -ne '') -or
    ($AuthEmailReplyTo -and $AuthEmailReplyTo.Trim() -ne '')) {
  $secrets = @()
  if ($ResendApiKey -and $ResendApiKey.Trim() -ne '') { $secrets += "RESEND_API_KEY=$ResendApiKey" }
  if ($AuthEmailFrom -and $AuthEmailFrom.Trim() -ne '') { $secrets += "AUTH_EMAIL_FROM=$AuthEmailFrom" }
  if ($AuthEmailReplyTo -and $AuthEmailReplyTo.Trim() -ne '') { $secrets += "AUTH_EMAIL_REPLY_TO=$AuthEmailReplyTo" }

  Write-Host "Setting Edge Function secrets (project-wide)..."
  & $supabase secrets set @secrets
} else {
  Write-Host "Skipping secrets. If email OTP does not arrive, set secrets:"
  Write-Host "  supabase secrets set RESEND_API_KEY=... AUTH_EMAIL_FROM=..."
}

Write-Host "Done. Re-open the app and retry Send Code."
