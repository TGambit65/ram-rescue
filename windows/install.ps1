# ram-rescue installer (Windows)
# Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1
# Or:    iwr -useb https://raw.githubusercontent.com/TGambit65/ram-rescue/main/windows/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoUrl = 'https://github.com/TGambit65/ram-rescue'
$Branch = if ($env:RAM_RESCUE_BRANCH) { $env:RAM_RESCUE_BRANCH } else { 'main' }

$Prefix = Join-Path $env:LOCALAPPDATA 'ram-rescue'
$ConfigDir = $Prefix
$ConfigFile = Join-Path $ConfigDir 'config.ps1'
$TaskName = 'ram-rescue'

function Say { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Warn { param($Msg) Write-Host "WARN: $Msg" -ForegroundColor Yellow }
function Die { param($Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- preflight
Say "Preflight checks..."
if ($PSVersionTable.PSVersion.Major -lt 5) {
  Die "PowerShell 5.0 or later required. Found $($PSVersionTable.PSVersion)."
}

# ---------------------------------------------------------------- locate source
$SrcDir = $null
$ScriptDir = Split-Path -Parent $PSCommandPath
if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir 'ram-rescue.ps1'))) {
  $SrcDir = $ScriptDir
} else {
  # curl|iex mode — clone the repo.
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "git not found. Install Git for Windows from https://git-scm.com/ or clone the repo manually."
  }
  $Tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "ram-rescue-install-$([guid]::NewGuid())")
  Say "Cloning $RepoUrl@$Branch..."
  git clone --depth=1 --branch $Branch $RepoUrl (Join-Path $Tmp 'ram-rescue') | Out-Null
  $SrcDir = Join-Path $Tmp 'ram-rescue\windows'
}

# ---------------------------------------------------------------- install files
Say "Installing to $Prefix..."
if (-not (Test-Path $Prefix)) { New-Item -ItemType Directory -Force -Path $Prefix | Out-Null }

Copy-Item (Join-Path $SrcDir 'ram-rescue.ps1') (Join-Path $Prefix 'ram-rescue.ps1') -Force
Copy-Item (Join-Path $SrcDir 'ram-rescue-ctl.ps1') (Join-Path $Prefix 'ram-rescue-ctl.ps1') -Force

# Seed config if missing.
if (-not (Test-Path $ConfigFile)) {
  @"
# ram-rescue config (PowerShell - dot-sourced)
`$Global:THRESHOLD_PCT = 15
`$Global:COOLDOWN_SEC = 600
`$Global:SNOOZE_DURATION = 1800
"@ | Set-Content -Path $ConfigFile -Encoding UTF8
  Say "Seeded default config at $ConfigFile"
} else {
  Say "Existing config preserved at $ConfigFile"
}

# Wrapper batch file so users can run `ram-rescue` from any shell.
$BinDir = Join-Path $env:LOCALAPPDATA 'Programs\ram-rescue'
if (-not (Test-Path $BinDir)) { New-Item -ItemType Directory -Force -Path $BinDir | Out-Null }
$WrapperBat = Join-Path $BinDir 'ram-rescue.bat'
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "$Prefix\ram-rescue-ctl.ps1" %*
"@ | Set-Content -Path $WrapperBat -Encoding ASCII

# Ensure $BinDir is on user PATH.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$BinDir*") {
  Say "Adding $BinDir to user PATH..."
  [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
  Warn "Restart your shell for PATH change to take effect, or use full path: $WrapperBat"
}

# ---------------------------------------------------------------- register scheduled task
Say "Registering Scheduled Task '$TaskName'..."

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Prefix\ram-rescue.ps1`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
  -RepetitionInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force | Out-Null

# ---------------------------------------------------------------- verify
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) { Die "Scheduled task failed to register." }
Say "Task registered. First run in ~1 minute, then every minute."

Write-Host ""
Write-Host "Installed." -ForegroundColor Green
Write-Host ""
Write-Host "Quick test:   ram-rescue test"
Write-Host "Show status:  ram-rescue status"
Write-Host "Configure:    notepad $ConfigFile"
Write-Host "Uninstall:    ram-rescue uninstall"
Write-Host ""
Write-Host "NOTE: First alert may be silenced by Windows 'Focus Assist' if active."
Write-Host "Check Settings -> System -> Focus Assist if notifications don't appear."
