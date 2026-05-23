# ram-rescue.ps1 - low-memory alerter for Windows
# Invoked by the "ram-rescue" Scheduled Task every minute.

$ErrorActionPreference = 'Stop'

$Version = '0.2.0'

# ---------------------------------------------------------------- config defaults
$Global:THRESHOLD_PCT = 15
$Global:COOLDOWN_SEC = 600
$Global:SNOOZE_DURATION = 1800

$ConfigDir = Join-Path $env:LOCALAPPDATA 'ram-rescue'
$ConfigFile = Join-Path $ConfigDir 'config.ps1'
$StateDir = Join-Path $env:LOCALAPPDATA 'ram-rescue\state'
$QuietUntilFile = Join-Path $StateDir 'quiet-until'

if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
if (Test-Path $ConfigFile) { . $ConfigFile }

# ---------------------------------------------------------------- helpers
function Read-Memory {
  $os = Get-CimInstance Win32_OperatingSystem
  $totalKB = [int]$os.TotalVisibleMemorySize

  # Available MBytes counter approximates Linux MemAvailable.
  $availMB = [int](Get-Counter -Counter '\Memory\Available MBytes' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
  if (-not $availMB) { $availMB = [int]($os.FreePhysicalMemory / 1024) }

  $availKB = if ($env:MEMAVAILABLE_OVERRIDE) { [int]$env:MEMAVAILABLE_OVERRIDE } else { $availMB * 1024 }
  $pct = [Math]::Floor($availKB * 100 / $totalKB)

  return [PSCustomObject]@{
    TotalKB = $totalKB
    AvailKB = $availKB
    Pct = $pct
  }
}

function In-QuietWindow {
  if (-not (Test-Path $QuietUntilFile)) { return $false }
  $until = [int64](Get-Content $QuietUntilFile)
  $now = [int64](Get-Date -UFormat %s)
  return $until -gt $now
}

function Set-QuietWindow {
  param([int]$DurationSec)
  $until = [int64](Get-Date -UFormat %s) + $DurationSec
  Set-Content -Path $QuietUntilFile -Value $until
}

function Get-TopConsumers {
  Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5 | ForEach-Object {
    "  {0,-22} {1,5} MB" -f $_.Name, [int]($_.WorkingSet / 1MB)
  }
}

function Fire-Alert {
  param($Mem)

  $top = (Get-TopConsumers) -join "`n"
  $body = "Available: $($Mem.Pct)% ($([int]($Mem.AvailKB / 1024)) MB)`n`nTop consumers:`n$top`n`nRun 'ram-rescue open' to launch Task Manager."

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  try {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    $notifyIcon.BalloonTipTitle = "ram-rescue: Low memory ($($Mem.Pct)% available)"
    $notifyIcon.BalloonTipText = $body
    $notifyIcon.BalloonTipIcon = 'Warning'
    $notifyIcon.Visible = $true
    # On Windows 10+, balloon tips auto-promote to toast notifications.
    $notifyIcon.ShowBalloonTip(15000)
    # Keep the notifyIcon alive long enough for the toast to display.
    Start-Sleep -Seconds 16
  } finally {
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
  }

  Set-QuietWindow -DurationSec $Global:COOLDOWN_SEC
  # Write to Windows Event Log (Applications log, source "ram-rescue").
  try {
    if (-not [System.Diagnostics.EventLog]::SourceExists('ram-rescue')) {
      # Source creation requires admin; if not allowed, skip silently.
    }
    Write-EventLog -LogName Application -Source 'ram-rescue' -EntryType Warning -EventId 1 `
      -Message "alert pct=$($Mem.Pct) avail=$($Mem.AvailKB)kB" -ErrorAction SilentlyContinue
  } catch { }
}

# ---------------------------------------------------------------- main
function Main {
  $mem = Read-Memory
  if ($mem.Pct -ge $Global:THRESHOLD_PCT) { return }
  if (In-QuietWindow) { return }
  Fire-Alert -Mem $mem
}

switch ($args[0]) {
  '--version' { Write-Output "ram-rescue $Version" }
  '--help'    { Write-Output "ram-rescue $Version (Windows). Invoked by Scheduled Task. Use ram-rescue-ctl.ps1 for CLI." }
  default     { Main }
}
