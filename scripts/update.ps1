# AgentMaster Auto-Updater for Windows
# Pulls latest from all dependency repos (repos.manifest) and syncs skills.
# Writes a sync report to ~/.claude/.agentmaster-cache/last-sync-report.txt
#
# Usage:
#   .\scripts\update.ps1              # foreground
#   .\scripts\update.ps1 -Quiet       # suppress output (background mode)

param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$LockFile = "$CacheDir\.update-lock"
$LastUpdateFile = "$CacheDir\.last-update"
$PinsFile = "$CacheDir\agent-master\repos.pins"
$Manifest = "$CacheDir\agent-master\repos.manifest"
$OwnersFile = "$CacheDir\.skill-owners"
$ReportFile = "$CacheDir\last-sync-report.txt"

$script:Report = @()
$script:Collisions = @()

function Log($msg) { if (-not $Quiet) { Write-Host $msg } }
function Add-Report($line) { Log "  $line"; $script:Report += $line }

New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
if (-not (Test-Path $OwnersFile)) { New-Item -ItemType File -Path $OwnersFile | Out-Null }

# Clear stale locks (crashed runs), then take the lock atomically:
# New-Item without -Force fails if the file already exists.
if (Test-Path $LockFile) {
    $lockAge = ((Get-Date) - (Get-Item $LockFile).LastWriteTime).TotalSeconds
    if ($lockAge -ge 300) { Remove-Item $LockFile -Force -ErrorAction SilentlyContinue }
}
try {
    New-Item -ItemType File -Path $LockFile -ErrorAction Stop | Out-Null
} catch {
    Log "Update already running. Skipping."
    exit 0
}

try {
    # Skip if updated within last 6 hours
    if (Test-Path $LastUpdateFile) {
        $last = [int](Get-Content $LastUpdateFile -ErrorAction SilentlyContinue)
        $now = [int](Get-Date -UFormat %s)
        if (($now - $last) -lt 21600) {
            Log "Updated recently. Skipping (6h cooldown)."
            exit 0
        }
    }

    Log "AgentMaster: Checking for skill updates..."

    # Read an optional commit pin for a repo from repos.pins (name=sha lines).
    function Get-Pin($Name) {
        if (-not (Test-Path $PinsFile)) { return $null }
        $line = Select-String -Path $PinsFile -Pattern "^$Name=" | Select-Object -First 1
        if ($line) { return ($line.Line -split '=', 2)[1].Trim() }
        return $null
    }

    # Track which repo installed each skill; collect collisions for the report
    function Record-Owner($Skill, $Repo) {
        $lines = @(Get-Content $OwnersFile -ErrorAction SilentlyContinue)
        $existing = $lines | Where-Object { $_ -match "^$([regex]::Escape($Skill))=" } | Select-Object -First 1
        if (-not $existing) {
            Add-Content -Path $OwnersFile -Value "$Skill=$Repo"
        } else {
            $prev = ($existing -split '=', 2)[1]
            if ($prev -ne $Repo) {
                $script:Collisions += "  ${Skill}: $prev -> $Repo"
                $lines = $lines | ForEach-Object { if ($_ -eq $existing) { "$Skill=$Repo" } else { $_ } }
                Set-Content -Path $OwnersFile -Value $lines
            }
        }
    }

    # Emit name|url|source entries from the manifest plus personal repos.local
    function Read-Manifest {
        $entries = @()
        foreach ($f in @($Manifest, "$CacheDir\repos.local")) {
            if (Test-Path $f) {
                $entries += Get-Content $f | Where-Object { $_ -notmatch '^\s*(#|$)' }
            }
        }
        return $entries
    }

    function Sync-Skills($Name, $Src, $SkillSource) {
        $count = 0
        if (Test-Path $Src) {
            Get-ChildItem $Src -Directory | ForEach-Object {
                if ((Test-Path "$($_.FullName)\SKILL.md") -or ($SkillSource -eq "skills")) {
                    Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
                    Record-Owner $_.Name $Name
                    $count++
                }
            }
        }
        return $count
    }

    function Update-Repo {
        param($Name, $RepoUrl, $SkillSource)
        $cachePath = "$CacheDir\$Name"
        $pin = Get-Pin $Name

        if (Test-Path "$cachePath\.git") {
            if ($pin) {
                # Pinned: fetch and check out the exact commit, never track HEAD
                git -C $cachePath fetch --depth 1 --quiet origin $pin 2>&1 | Out-Null
                git -C $cachePath checkout --quiet $pin 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Add-Report "${Name}: pin $pin not found, keeping current"
                } else {
                    $n = Sync-Skills $Name "$cachePath\$SkillSource" $SkillSource
                    Add-Report "${Name}: pinned to $($pin.Substring(0,7)) ($n skills)"
                }
                return
            }
            $before = git -C $cachePath rev-parse --short HEAD 2>$null
            # Caches are machine-managed mirrors — discard any local edits that
            # would block the pull (e.g. left behind by older installers).
            git -C $cachePath reset --hard --quiet 2>&1 | Out-Null
            git -C $cachePath clean -fdq 2>&1 | Out-Null
            git -C $cachePath pull --ff-only --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Add-Report "${Name}: pull failed, keeping current ($before)"; return }
            $after = git -C $cachePath rev-parse --short HEAD 2>$null
            if ($before -eq $after) { Add-Report "${Name}: up to date ($after)"; return }
            $n = Sync-Skills $Name "$cachePath\$SkillSource" $SkillSource
            Add-Report "${Name}: updated $before -> $after ($n skills)"
            return
        }

        # Fresh clone (git refuses to clone into a non-empty dir, so reset first)
        Log "  ${Name}: cloning..."
        if (Test-Path $cachePath) { Remove-Item $cachePath -Recurse -Force }
        git clone --depth 1 --quiet $RepoUrl $cachePath 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Add-Report "${Name}: clone failed, skipping"; return }
        if ($pin) {
            git -C $cachePath fetch --depth 1 --quiet origin $pin 2>&1 | Out-Null
            git -C $cachePath checkout --quiet $pin 2>&1 | Out-Null
        }
        $n = Sync-Skills $Name "$cachePath\$SkillSource" $SkillSource
        if ($pin) {
            Add-Report "${Name}: cloned, pinned to $($pin.Substring(0,7)) ($n skills)"
        } else {
            Add-Report "${Name}: cloned ($n skills)"
        }
    }

    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null

    # Self-update first so a freshly pushed repos.manifest/repos.pins takes effect this run
    $amCache = "$CacheDir\agent-master"
    if (-not (Test-Path "$amCache\.git")) {
        # A cache dir without .git (e.g. from an old zip-based install) can't be
        # pulled — and git refuses to clone into a non-empty dir — so reset it.
        if (Test-Path $amCache) { Remove-Item $amCache -Recurse -Force }
        git clone --depth 1 --quiet "https://github.com/Surya8991/AgentMaster.git" $amCache 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Add-Report "agent-master: clone failed, skipping self-update" }
        else { Add-Report "agent-master: installed from remote" }
    } else {
        $amBefore = git -C $amCache rev-parse --short HEAD 2>$null
        # Caches are machine-managed mirrors — discard any local edits that
        # would block the pull (e.g. left behind by older installers).
        git -C $amCache reset --hard --quiet 2>&1 | Out-Null
        git -C $amCache clean -fdq 2>&1 | Out-Null
        git -C $amCache pull --ff-only --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Add-Report "agent-master: pull failed, keeping current ($amBefore)"
        } else {
            $amAfter = git -C $amCache rev-parse --short HEAD 2>$null
            if ($amBefore -eq $amAfter) { Add-Report "agent-master: up to date ($amAfter)" }
            else { Add-Report "agent-master: updated $amBefore -> $amAfter" }
        }
    }
    if (Test-Path "$amCache\skills") {
        Get-ChildItem "$amCache\skills" -Directory | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
            Record-Owner $_.Name "agent-master"
        }
    }

    # Update each dependency repo from the manifest
    if (-not (Test-Path $Manifest)) {
        Add-Report "manifest missing: $Manifest - no dependency repos synced"
    }
    foreach ($entry in Read-Manifest) {
        $parts = $entry -split '\|'
        if ($parts.Count -lt 3) { continue }
        Update-Repo -Name $parts[0].Trim() -RepoUrl $parts[1].Trim() -SkillSource $parts[2].Trim()
    }

    # Record timestamp
    [int](Get-Date -UFormat %s) | Out-File $LastUpdateFile -Force

    # Write sync report
    $reportLines = @("AgentMaster sync report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $reportLines += $script:Report
    if ($script:Collisions.Count -gt 0) {
        $reportLines += "Collisions (last writer wins):"
        $reportLines += $script:Collisions
    } else {
        $reportLines += "Collisions: none"
    }
    Set-Content -Path $ReportFile -Value $reportLines

    $count = (Get-ChildItem $SkillsDir -Directory).Count
    Log ""
    Log "All skills synced. Total: $count skills"
    Log "Report: $ReportFile"
} finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
