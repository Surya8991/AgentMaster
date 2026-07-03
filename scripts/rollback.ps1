# AgentMaster Rollback — restore a repo's skills to the version before its
# last sync, and pin the repo locally so auto-updates hold the rollback.
#
# Usage:
#   .\scripts\rollback.ps1             # list available backups + active local pins
#   .\scripts\rollback.ps1 <repo>      # roll <repo> back (restore + pin)
#
# Undo: remove the repo's line from ~/.claude/.agentmaster-cache/pins.local —
# the next sync returns to tracking upstream HEAD.

param([string]$Repo)

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$OwnersFile = "$CacheDir\.skill-owners"
$BackupsDir = "$CacheDir\backups"
$PinsLocal = "$CacheDir\pins.local"

function Get-Meta($Dir, $Key) {
    $line = Get-Content "$Dir\.meta" -ErrorAction SilentlyContinue | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
    if ($line) { return ($line -split '=', 2)[1] }
    return ""
}

# --- List mode ---
if (-not $Repo) {
    Write-Host "AgentMaster Rollback"
    Write-Host "===================="
    Write-Host ""
    Write-Host "Available backups (the version before each repo's last change):"
    $found = $false
    if (Test-Path $BackupsDir) {
        foreach ($bdir in Get-ChildItem $BackupsDir -Directory) {
            if (-not (Test-Path "$($bdir.FullName)\.meta")) { continue }
            $sha = Get-Meta $bdir.FullName "sha"
            $when = Get-Meta $bdir.FullName "date"
            $count = Get-Meta $bdir.FullName "skills"
            Write-Host "  $($bdir.Name) - restores to $($sha.Substring(0, [Math]::Min(7, $sha.Length))) ($count skills, backed up $when)"
            $found = $true
        }
    }
    if (-not $found) { Write-Host "  (none yet - backups are taken automatically when a sync changes a repo)" }
    Write-Host ""
    Write-Host "Active local pins (rollbacks / manual pins):"
    $pins = @()
    if (Test-Path $PinsLocal) {
        $pins = @(Get-Content $PinsLocal | Where-Object { $_ -notmatch '^\s*(#|$)' })
    }
    if ($pins.Count -gt 0) { $pins | ForEach-Object { Write-Host "  $_" } }
    else { Write-Host "  (none - repos track upstream HEAD)" }
    Write-Host ""
    Write-Host "Roll back with: /agent-master rollback <repo>"
    exit 0
}

# --- Rollback mode ---
$bdir = "$BackupsDir\$Repo"
if (-not (Test-Path "$bdir\.meta")) {
    Write-Host "No backup available for '$Repo'."
    $available = @()
    if (Test-Path $BackupsDir) { $available = (Get-ChildItem $BackupsDir -Directory).Name }
    Write-Host "Backups exist for: $($available -join ' ')"
    exit 1
}

$sha = Get-Meta $bdir "sha"
$when = Get-Meta $bdir "date"
$shortSha = $sha.Substring(0, [Math]::Min(7, $sha.Length))
Write-Host "Rolling back '$Repo' to $shortSha (backed up $when)..."

# 1. Remove the repo's currently installed skills (owned ones only)
$removed = 0
$kept = @()
if (Test-Path $OwnersFile) {
    foreach ($line in @(Get-Content $OwnersFile | Where-Object { $_ -match '=' })) {
        $kv = $line -split '=', 2
        if ($kv[1] -eq $Repo) {
            if (Test-Path "$SkillsDir\$($kv[0])") { Remove-Item "$SkillsDir\$($kv[0])" -Recurse -Force }
            $removed++
        } else {
            $kept += $line
        }
    }
}

# 2. Restore the backed-up versions and re-record ownership
$restored = 0
foreach ($dir in Get-ChildItem $bdir -Directory) {
    Copy-Item -Path $dir.FullName -Destination "$SkillsDir\$($dir.Name)" -Recurse -Force
    $kept += "$($dir.Name)=$Repo"
    $restored++
}
Set-Content -Path $OwnersFile -Value $kept
Write-Host "  restored $restored skills (removed $removed current)"

# 3. Check the cache out at the rolled-back commit (best effort)
$cachePath = "$CacheDir\$Repo"
if (Test-Path "$cachePath\.git") {
    git -C $cachePath fetch --depth 1 --quiet origin $sha 2>&1 | Out-Null
    git -C $cachePath checkout --quiet $sha 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  cache checked out at $shortSha" }
    else { Write-Host "  ! could not check out $sha in the cache (skills restored anyway)" }
}

# 4. Pin locally so the next auto-sync holds this version
$pinLines = @()
if (Test-Path $PinsLocal) {
    $pinLines = @(Get-Content $PinsLocal | Where-Object { $_ -notmatch "^$([regex]::Escape($Repo))=" })
}
$pinLines += "$Repo=$sha"
Set-Content -Path $PinsLocal -Value $pinLines
Write-Host "  pinned in pins.local"

Write-Host ""
Write-Host "Done. '$Repo' is rolled back to $shortSha and will stay there."
Write-Host "To resume tracking upstream: remove the '$Repo=' line from $PinsLocal"
Write-Host "Restart your Claude Code session to reload skills."
