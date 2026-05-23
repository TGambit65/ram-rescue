# ram-rescue-ctl.ps1 - user-facing CLI (Windows)

$Version = '0.4.0'
$Prefix = Join-Path $env:LOCALAPPDATA 'ram-rescue'
$ConfigDir = $Prefix
$ConfigFile = Join-Path $ConfigDir 'config.ps1'
$StateDir = Join-Path $Prefix 'state'
$QuietUntilFile = Join-Path $StateDir 'quiet-until'
$TaskName = 'ram-rescue'

function Show-Usage {
  @"
ram-rescue $Version - low-RAM alerter (Windows)

Usage: ram-rescue <command>

Commands:
  status              Show current memory state and scheduled task status
  apps                Show top apps grouped by name (no notification)
  test                Force a low-memory alert
  open                Launch Task Manager
  snooze [SECONDS]    Suppress alerts for N seconds (default: 1800)
  unsnooze            Clear any active snooze
  logs [N]            Show last N entries from the Windows Event Log
  version             Print version
  uninstall           Remove ram-rescue scheduled task and files
  help                This message
"@ | Write-Output
}

function Get-MemAvailKB {
  $availMB = [int](Get-Counter -Counter '\Memory\Available MBytes' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
  if (-not $availMB) {
    $availMB = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
  }
  return $availMB * 1024
}

function Cmd-Status {
  $os = Get-CimInstance Win32_OperatingSystem
  $totalKB = [int]$os.TotalVisibleMemorySize
  $availKB = Get-MemAvailKB
  $pct = [Math]::Floor($availKB * 100 / $totalKB)
  Write-Output "Memory:         $pct% available ($availKB kB / $totalKB kB)"

  $threshold = 15
  if (Test-Path $ConfigFile) {
    . $ConfigFile
    if ($Global:THRESHOLD_PCT) { $threshold = $Global:THRESHOLD_PCT }
  }
  Write-Output "Threshold:      $threshold%"

  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($task) {
    Write-Output "Task:           $($task.State)"
  } else {
    Write-Output "Task:           not registered"
  }

  if (Test-Path $QuietUntilFile) {
    $until = [int64](Get-Content $QuietUntilFile)
    $now = [int64](Get-Date -UFormat %s)
    $remaining = $until - $now
    if ($remaining -gt 0) {
      $untilDate = (Get-Date '1970-01-01').AddSeconds($until).ToLocalTime()
      Write-Output ("Snoozed:        {0}s remaining (until {1:HH:mm:ss})" -f $remaining, $untilDate)
    } else {
      Write-Output "Snoozed:        no"
    }
  } else {
    Write-Output "Snoozed:        no"
  }
}

function Cmd-Test {
  Write-Output "Firing test alert (MEMAVAILABLE_OVERRIDE=100000)..."
  $env:MEMAVAILABLE_OVERRIDE = '100000'
  & (Join-Path $Prefix 'ram-rescue.ps1')
  Remove-Item Env:\MEMAVAILABLE_OVERRIDE
}

function Cmd-Apps {
  & (Join-Path $Prefix 'ram-rescue.ps1') '--apps'
}

function Cmd-Open { Start-Process taskmgr }

function Cmd-Snooze {
  param([int]$DurationSec = 1800)
  if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
  $until = [int64](Get-Date -UFormat %s) + $DurationSec
  Set-Content -Path $QuietUntilFile -Value $until
  Write-Output "Snoozed for ${DurationSec}s."
}

function Cmd-Unsnooze {
  Remove-Item $QuietUntilFile -ErrorAction SilentlyContinue
  Write-Output "Snooze cleared."
}

function Cmd-Logs {
  param([int]$N = 20)
  Get-WinEvent -LogName Application -MaxEvents 200 -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -eq 'ram-rescue' } |
    Select-Object -First $N |
    Format-Table TimeCreated, LevelDisplayName, Message -AutoSize
}

function Cmd-Uninstall {
  Write-Output "Uninstalling ram-rescue..."
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Remove-Item -Recurse -Force $Prefix -ErrorAction SilentlyContinue
  Write-Output "Removed scheduled task and scripts."
  Write-Output "State files at $StateDir preserved if any remain."
}

switch ($args[0]) {
  'status'    { Cmd-Status }
  'apps'      { Cmd-Apps }
  'test'      { Cmd-Test }
  'open'      { Cmd-Open }
  'snooze'    { Cmd-Snooze -DurationSec ([int]($args[1] | ForEach-Object { if ($_) { $_ } else { 1800 } })) }
  'unsnooze'  { Cmd-Unsnooze }
  'logs'      { Cmd-Logs -N ([int]($args[1] | ForEach-Object { if ($_) { $_ } else { 20 } })) }
  'version'   { Write-Output "ram-rescue $Version" }
  '--version' { Write-Output "ram-rescue $Version" }
  'uninstall' { Cmd-Uninstall }
  'help'      { Show-Usage }
  '--help'    { Show-Usage }
  '-h'        { Show-Usage }
  $null       { Show-Usage }
  default     { Write-Error "Unknown command: $($args[0])"; Show-Usage; exit 1 }
}
