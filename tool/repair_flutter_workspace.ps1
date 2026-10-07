param(
  [switch]$SkipPubGet,
  [switch]$UnlockOnly
)

$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:IncludeLanguageServerOnRetry = $true
Set-Location $workspace

function Resolve-FlutterCommand {
  $command = Get-Command flutter -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $settingsPath = Join-Path $workspace '.vscode\settings.json'
  if (Test-Path -LiteralPath $settingsPath) {
    try {
      $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
      $flutterSdkPath = $settings.'dart.flutterSdkPath'
      if ($flutterSdkPath) {
        $resolvedSdk = (Resolve-Path -LiteralPath $flutterSdkPath -ErrorAction SilentlyContinue).Path
        if ($resolvedSdk) {
          $candidate = Join-Path $resolvedSdk 'bin\flutter.bat'
          if (Test-Path -LiteralPath $candidate) {
            return $candidate
          }
        }
      }
    } catch {
      # Ignore malformed settings.
    }
  }

  $envCandidates = @(
    $env:FRESHLINE_FLUTTER_SDK,
    $env:FLUTTER_ROOT,
    $env:FLUTTER_HOME
  ) | Where-Object { $_ -and $_.Trim() -ne '' }

  foreach ($candidateRoot in $envCandidates) {
    $resolvedRoot = (Resolve-Path -LiteralPath $candidateRoot -ErrorAction SilentlyContinue).Path
    if (-not $resolvedRoot) {
      continue
    }
    $candidate = Join-Path $resolvedRoot 'bin\flutter.bat'
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $workspaceFlutter = Join-Path $workspace 'flutter\bin\flutter.bat'
  if (Test-Path -LiteralPath $workspaceFlutter) {
    return $workspaceFlutter
  }

  $bundledFlutter = Join-Path $workspace '.flutter_sdk\flutter\bin\flutter.bat'
  if (Test-Path -LiteralPath $bundledFlutter) {
    return $bundledFlutter
  }

  return $null
}

function Resolve-DartCommand {
  $command = Get-Command dart -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $bundled = Join-Path $workspace 'flutter\bin\cache\dart-sdk\bin\dart.exe'
  if (Test-Path -LiteralPath $bundled) {
    return $bundled
  }

  $bundled = Join-Path $workspace '.flutter_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe'
  if (Test-Path -LiteralPath $bundled) {
    return $bundled
  }

  return $null
}

function Stop-StaleFlutterProcesses {
  param(
    [switch]$IncludeLanguageServer
  )

  $patterns = @(
    '*flutter_tools.snapshot*daemon*',
    '*devtools --machine*',
    '*tooling-daemon*'
  )

  if ($IncludeLanguageServer) {
    $patterns += '*language-server --protocol=lsp*'
  }

  $processes = Get-CimInstance Win32_Process |
    Where-Object {
      $commandLine = $_.CommandLine
      $_.Name -in @('dart.exe', 'dartvm.exe', 'flutter.bat') -and
      $commandLine -and
      (($patterns | Where-Object { $commandLine -like $_ }).Count -gt 0)
    }

  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
    } catch {
      Write-Host "Could not stop process $($process.ProcessId): $($_.Exception.Message)"
    }
  }
}

function Clear-WorkspaceAttributes {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  attrib -R $Path /S /D 2>$null | Out-Null
}

function Remove-WorkspacePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $resolved = (Resolve-Path -LiteralPath $Path).Path
  if (-not $resolved.StartsWith($workspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove path outside workspace: $resolved"
  }

  Clear-WorkspaceAttributes -Path $resolved

  for ($attempt = 1; $attempt -le 12; $attempt++) {
    if (Invoke-IsolatedRemove -LiteralPath $resolved) {
      return
    } else {
      if ($attempt -eq 1) {
        Stop-StaleFlutterProcesses -IncludeLanguageServer:$script:IncludeLanguageServerOnRetry
        Start-Sleep -Milliseconds 750
      }

      if ($attempt -lt 12) {
        Start-Sleep -Seconds 1
      }
    }
  }
  throw "Could not remove locked path after multiple retries: $resolved"
}

function Invoke-IsolatedRemove {
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )

  $escapedPath = $LiteralPath.Replace("'", "''")
  $command = @"
try {
  Remove-Item -LiteralPath '$escapedPath' -Recurse -Force -ErrorAction Stop
  exit 0
} catch {
  exit 1
}
"@

  & powershell -NoProfile -NonInteractive -Command $command | Out-Null
  return $LASTEXITCODE -eq 0
}

function Test-SymlinkSupport {
  $target = Join-Path $workspace 'pubspec.yaml'
  $link = Join-Path $workspace '.codex_symlink_test'

  if (Test-Path -LiteralPath $link) {
    Remove-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
  }

  try {
    New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    return $true
  } catch {
    Write-Host 'Windows symlink support is disabled for this terminal.'
    Write-Host 'Enable Developer Mode from Settings > For developers, or run PowerShell as Administrator once, then rerun this script.'
    return $false
  }
}

function Invoke-DartPubGetFallback {
  Write-Host 'Running dart pub get as a fallback so package_config.json is restored.'
  $dartCommand = Resolve-DartCommand
  if (-not $dartCommand) {
    throw 'dart is not available. Install Flutter (recommended) or Dart, then rerun.'
  }
  & $dartCommand pub get
  if ($LASTEXITCODE -ne 0) {
    throw 'dart pub get failed.'
  }
  Write-Host 'dart pub get completed. Flutter desktop plugin regeneration still requires Developer Mode or an elevated terminal.'
}

if ($UnlockOnly) {
  $script:IncludeLanguageServerOnRetry = $false
  Write-Host "Unlocking Flutter workspace at $workspace"

  Write-Host 'Stopping stale Flutter tooling daemons so the workspace can be reopened cleanly.'
  Stop-StaleFlutterProcesses

  $pathsToUnlock = @(
    (Join-Path $workspace 'build'),
    (Join-Path $workspace '.dart_tool\hooks_runner')
  )

  foreach ($path in $pathsToUnlock) {
    Remove-WorkspacePath -Path $path
  }

  Write-Host 'Flutter workspace unlock completed.'
  return
}

Write-Host "Repairing Flutter workspace at $workspace"

$flutterCommand = Resolve-FlutterCommand
if (-not $flutterCommand) {
  Write-Host 'Flutter was not found on PATH, and no SDK path was configured.'
  Write-Host 'Fix:'
  Write-Host '  1) Install Flutter, then ensure `flutter --version` works in a new terminal.'
  Write-Host '  2) Or set VS Code setting `dart.flutterSdkPath`.'
  Write-Host '  3) Or set env var FRESHLINE_FLUTTER_SDK to your Flutter SDK folder.'
  throw 'Flutter SDK missing.'
}

$symlinkSupported = Test-SymlinkSupport

$pathsToRemove = @(
  (Join-Path $workspace 'build'),
  (Join-Path $workspace '.dart_tool'),
  (Join-Path $workspace 'ios\Flutter\ephemeral'),
  (Join-Path $workspace 'macos\Flutter\ephemeral'),
  (Join-Path $workspace 'linux\flutter\ephemeral'),
  (Join-Path $workspace 'windows\flutter\ephemeral')
)

foreach ($path in $pathsToRemove) {
  Remove-WorkspacePath -Path $path
}

$generatedFiles = @(
  (Join-Path $workspace 'ios\Flutter\Generated.xcconfig'),
  (Join-Path $workspace 'ios\Flutter\flutter_export_environment.sh'),
  (Join-Path $workspace 'macos\Flutter\Flutter-Generated.xcconfig')
)

if ($symlinkSupported) {
  $generatedFiles = @(
    (Join-Path $workspace '.flutter-plugins-dependencies')
  ) + $generatedFiles
} else {
  Write-Host 'Keeping any existing .flutter-plugins-dependencies file because Flutter cannot regenerate plugin symlinks in this terminal.'
}

foreach ($file in $generatedFiles) {
  Remove-WorkspacePath -Path $file
}

& $flutterCommand clean
if ($LASTEXITCODE -ne 0) {
  throw 'flutter clean failed.'
}

if (-not $SkipPubGet) {
  if ($symlinkSupported) {
    & $flutterCommand pub get
    if ($LASTEXITCODE -ne 0) {
      Write-Host 'flutter pub get failed. If the error mentions symlinks, enable Developer Mode and rerun the script.'
      Invoke-DartPubGetFallback
    }
  } else {
    Write-Host 'Skipping flutter pub get until symlink support is enabled.'
    Invoke-DartPubGetFallback
  }
}

Write-Host 'Flutter workspace repair completed.'
