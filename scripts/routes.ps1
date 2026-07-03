# AgentMaster Routes — routing log, active overrides, and unrouted skills.
#
# Usage: .\scripts\routes.ps1

$ErrorActionPreference = "Stop"

$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$LogFile = "$CacheDir\routing-log.txt"
$OverridesFile = "$CacheDir\routing-overrides.md"
$UnroutedFile = "$CacheDir\unrouted-skills.txt"

Write-Host "AgentMaster Routing"
Write-Host "==================="

Write-Host ""
Write-Host "Recent routes (last 15):"
if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 0) {
    Get-Content $LogFile -Tail 15 | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  (no routing log yet - entries appear as /agent-master routes tasks)"
}

Write-Host ""
Write-Host "Active overrides (take precedence over the routing table):"
$overrides = @()
if (Test-Path $OverridesFile) {
    $overrides = @(Get-Content $OverridesFile | Where-Object { $_ -notmatch '^\s*(#|$)' })
}
if ($overrides.Count -gt 0) {
    $overrides | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  (none - corrections to misroutes will be recorded here)"
}

Write-Host ""
Write-Host "Unrouted skills (installed but not in the routing table):"
if ((Test-Path $UnroutedFile) -and (Get-Item $UnroutedFile).Length -gt 0) {
    Get-Content $UnroutedFile | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  (none - or run /agent-master update to regenerate)"
}
