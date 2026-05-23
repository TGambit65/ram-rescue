# ram-rescue uninstaller (Windows)

$ErrorActionPreference = 'Continue'

$Prefix = Join-Path $env:LOCALAPPDATA 'ram-rescue'
$BinDir = Join-Path $env:LOCALAPPDATA 'Programs\ram-rescue'
$TaskName = 'ram-rescue'

Write-Host "==> Unregistering scheduled task..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "==> Removing scripts..." -ForegroundColor Cyan
Remove-Item -Recurse -Force $Prefix -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $BinDir -ErrorAction SilentlyContinue

# Optionally remove from PATH.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -like "*$BinDir*") {
  $newPath = ($userPath -split ';' | Where-Object { $_ -ne $BinDir }) -join ';'
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  Write-Host "==> Removed $BinDir from user PATH." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Uninstalled." -ForegroundColor Green
Write-Host ""
Write-Host "Config preserved if present. Delete manually if desired."
