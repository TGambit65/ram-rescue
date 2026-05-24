# ram-rescue.ps1 - low-memory alerter for Windows
# Invoked by the "ram-rescue" Scheduled Task every minute.

$ErrorActionPreference = 'Stop'

$Version = '0.5.1'

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

function Severity-Emoji {
  param([int]$Pct)
  if ($Pct -lt 5) { return '🔴' }
  if ($Pct -lt 10) { return '🟠' }
  return '🟡'
}

# ---------------------------------------------------------------- app classifier
# Returns @{ Name = ...; Emoji = ...; Desc = ...; Category = ... }
function Classify-App {
  param([string]$Comm)
  switch -Regex ($Comm) {
    '^(chrome|GoogleChrome)$' { return @{ Name='Chrome'; Emoji='🌐'; Desc='Web browser'; Category='browser' } }
    '^(msedge|MicrosoftEdge)' { return @{ Name='Edge'; Emoji='🔷'; Desc='Web browser'; Category='browser' } }
    '^firefox$' { return @{ Name='Firefox'; Emoji='🦊'; Desc='Web browser'; Category='browser' } }
    '^brave$' { return @{ Name='Brave'; Emoji='🦁'; Desc='Web browser'; Category='browser' } }
    '^(Code|Code - Insiders)$' { return @{ Name='VS Code'; Emoji='📝'; Desc='Code editor'; Category='editor' } }
    '^Cursor$' { return @{ Name='Cursor'; Emoji='✨'; Desc='AI code editor'; Category='editor' } }
    '^claude$' { return @{ Name='Claude Code'; Emoji='🤖'; Desc='Anthropic AI agent'; Category='ai' } }
    '^aider$' { return @{ Name='Aider'; Emoji='🤖'; Desc='AI pair programmer'; Category='ai' } }
    '^slack$' { return @{ Name='Slack'; Emoji='💬'; Desc='Team chat'; Category='chat' } }
    '^Discord$' { return @{ Name='Discord'; Emoji='🎮'; Desc='Chat app'; Category='chat' } }
    '^Telegram' { return @{ Name='Telegram'; Emoji='✈️'; Desc='Chat app'; Category='chat' } }
    '^Spotify$' { return @{ Name='Spotify'; Emoji='🎵'; Desc='Music streaming'; Category='media' } }
    '^Zoom$' { return @{ Name='Zoom'; Emoji='🎥'; Desc='Video calls'; Category='media' } }
    '^obs(64)?$' { return @{ Name='OBS Studio'; Emoji='📹'; Desc='Streaming/recording'; Category='media' } }
    '^vlc$' { return @{ Name='VLC'; Emoji='🎬'; Desc='Media player'; Category='media' } }
    '^node$' { return @{ Name='Node.js'; Emoji='⚙️'; Desc='JavaScript runtime'; Category='runtime' } }
    '^npm$' { return @{ Name='npm'; Emoji='📦'; Desc='npm-managed Node process'; Category='runtime' } }
    '^python(3)?$' { return @{ Name='Python'; Emoji='🐍'; Desc='Python interpreter'; Category='runtime' } }
    '^java(w)?$' { return @{ Name='Java'; Emoji='☕'; Desc='JVM application'; Category='runtime' } }
    '^ruby$' { return @{ Name='Ruby'; Emoji='💎'; Desc='Ruby interpreter'; Category='runtime' } }
    '^(cargo|rustc|rust)$' { return @{ Name='Rust'; Emoji='🦀'; Desc='Rust toolchain'; Category='runtime' } }
    '^(docker|com\.docker)' { return @{ Name='Docker'; Emoji='🐳'; Desc='Container runtime'; Category='system' } }
    '^postgres$' { return @{ Name='PostgreSQL'; Emoji='🐘'; Desc='Database'; Category='server' } }
    '^mysqld$' { return @{ Name='MySQL'; Emoji='🐬'; Desc='Database'; Category='server' } }
    '^redis-server$' { return @{ Name='Redis'; Emoji='📕'; Desc='In-memory database'; Category='server' } }
    '^mongod$' { return @{ Name='MongoDB'; Emoji='🍃'; Desc='Document database'; Category='server' } }
    '^nginx$' { return @{ Name='nginx'; Emoji='🚀'; Desc='Web server'; Category='server' } }
    '^(System|svchost|csrss|wininit|services|lsass|smss|winlogon|dwm|explorer|RuntimeBroker|sihost|fontdrvhost|ctfmon|searchindexer|searchapp|ShellExperienceHost|StartMenuExperienceHost|TextInputHost|ApplicationFrameHost)' {
      return @{ Name='Windows system'; Emoji='⚙️'; Desc='OS services (keep alive)'; Category='system' }
    }
    '^(pwsh|powershell|cmd|WindowsTerminal|wt)$' { return @{ Name='Terminal/Shell'; Emoji='🐚'; Desc='Shell or terminal'; Category='shell' } }
    default { return @{ Name=$Comm; Emoji='📦'; Desc='Process'; Category='other' } }
  }
}

function Count-ChromeTabs {
  try {
    $chromeProcs = Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue
    if (-not $chromeProcs) { return 0 }
    return @($chromeProcs | Where-Object { $_.CommandLine -match '--type=renderer' -and $_.CommandLine -notmatch 'extension-process' }).Count
  } catch { return 0 }
}

function Get-TopApps {
  $apps = @{}
  $procs = Get-Process -ErrorAction SilentlyContinue
  foreach ($p in $procs) {
    if ($p.WorkingSet64 -le 0) { continue }
    $info = Classify-App -Comm $p.Name
    $name = $info.Name
    if (-not $apps.ContainsKey($name)) {
      $apps[$name] = [PSCustomObject]@{
        Name = $name
        Emoji = $info.Emoji
        Desc = $info.Desc
        Category = $info.Category
        RSS = 0
        Count = 0
      }
    }
    $apps[$name].RSS += $p.WorkingSet64
    $apps[$name].Count += 1
  }

  $sorted = $apps.Values | Sort-Object RSS -Descending | Select-Object -First 5
  $chromeTabs = -1
  $lines = foreach ($app in $sorted) {
    $mb = [int]($app.RSS / 1MB)
    $sizeDisp = if ($mb -ge 1024) { '{0:N1} GB' -f ($mb / 1024) } else { "$mb MB" }

    $extra = $app.Desc
    if ($app.Name -eq 'Chrome') {
      if ($chromeTabs -lt 0) { $chromeTabs = Count-ChromeTabs }
      if ($chromeTabs -gt 0) { $extra = "~$chromeTabs tabs" }
    }

    "{0} {1} · {2} · {3}" -f $app.Emoji, $app.Name, $sizeDisp, $extra
  }
  return ($lines -join "`n")
}

function Fire-Alert {
  param($Mem)

  $apps = Get-TopApps
  $severity = Severity-Emoji -Pct $Mem.Pct
  $title = "$severity Low memory · $($Mem.Pct)% available"
  $body = "$([int]($Mem.AvailKB / 1024)) MB free of $([int]($Mem.TotalKB / 1024)) MB · Top apps:`n`n$apps`n`nRun 'ram-rescue open' to launch Task Manager."

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
  try {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    $notifyIcon.BalloonTipTitle = $title
    $notifyIcon.BalloonTipText = $body
    $notifyIcon.BalloonTipIcon = 'Warning'
    $notifyIcon.Visible = $true
    $notifyIcon.ShowBalloonTip(15000)
    Start-Sleep -Seconds 16
  } finally {
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
  }

  Set-QuietWindow -DurationSec $Global:COOLDOWN_SEC
  try {
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
  '--apps' {
    $mem = Read-Memory
    $severity = Severity-Emoji -Pct $mem.Pct
    Write-Output "$severity Memory: $($mem.Pct)% available ($([int]($mem.AvailKB / 1024)) MB free of $([int]($mem.TotalKB / 1024)) MB)"
    Write-Output ""
    Write-Output "Top apps:"
    Write-Output ""
    Write-Output (Get-TopApps)
  }
  '--help'    { Write-Output "ram-rescue $Version (Windows). Use ram-rescue-ctl.ps1 for the CLI. Flags: --apps, --version, --help" }
  default     { Main }
}
