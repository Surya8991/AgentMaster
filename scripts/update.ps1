# AgentMaster Auto-Updater for Windows
# Pulls latest from all 5 dependency repos and syncs skills
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

function Log($msg) { if (-not $Quiet) { Write-Host $msg } }

New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

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

    function Update-Repo {
        param($Name, $RepoUrl, $SkillSource)
        $cachePath = "$CacheDir\$Name"

        if (Test-Path "$cachePath\.git") {
            $pin = Get-Pin $Name
            if ($pin) {
                # Pinned: fetch and check out the exact commit, never track HEAD
                git -C $cachePath fetch --depth 1 --quiet origin $pin 2>&1 | Out-Null
                git -C $cachePath checkout --quiet $pin 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { Log "  ${Name}: pin $pin not found, keeping current"; }
                else { Log "  ${Name}: pinned to $($pin.Substring(0,7))" }
            } else {
                $before = git -C $cachePath rev-parse HEAD 2>$null
                git -C $cachePath pull --ff-only --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { Log "  ${Name}: pull failed, keeping current"; return }
                $after = git -C $cachePath rev-parse HEAD 2>$null
                if ($before -eq $after) { Log "  ${Name}: up to date"; return }
                Log "  ${Name}: updated"
            }
        } else {
            Log "  ${Name}: cloning..."
            if (Test-Path $cachePath) { Remove-Item $cachePath -Recurse -Force }
            git clone --depth 1 --quiet $RepoUrl $cachePath 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Log "  ${Name}: clone failed, skipping"; return }
            $pin = Get-Pin $Name
            if ($pin) {
                git -C $cachePath fetch --depth 1 --quiet origin $pin 2>&1 | Out-Null
                git -C $cachePath checkout --quiet $pin 2>&1 | Out-Null
            }
        }

        # Sync skills
        $src = "$cachePath\$SkillSource"
        if (Test-Path $src) {
            Get-ChildItem $src -Directory | ForEach-Object {
                if ((Test-Path "$($_.FullName)\SKILL.md") -or ($SkillSource -eq "skills")) {
                    Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
                }
            }
        }
    }

    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null

    # Self-update first so a freshly pushed repos.pins takes effect this run
    $amCache = "$CacheDir\agent-master"
    if (-not (Test-Path "$amCache\.git")) {
        # A cache dir without .git (e.g. from an old zip-based install) can't be
        # pulled — and git refuses to clone into a non-empty dir — so reset it.
        if (Test-Path $amCache) { Remove-Item $amCache -Recurse -Force }
        git clone --depth 1 --quiet "https://github.com/Surya8991/AgentMaster.git" $amCache 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Log "  agent-master: clone failed, skipping self-update" }
    } else {
        git -C $amCache pull --ff-only --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { Log "  agent-master: pull failed, keeping current" }
    }
    if (Test-Path "$amCache\skills") {
        Copy-Item -Path "$amCache\skills\*" -Destination $SkillsDir -Recurse -Force
        Log "  agent-master: synced"
    }

    Update-Repo -Name "caveman" -RepoUrl "https://github.com/JuliusBrussee/caveman.git" -SkillSource "skills"
    Update-Repo -Name "superpowers" -RepoUrl "https://github.com/obra/superpowers.git" -SkillSource "skills"
    Update-Repo -Name "claude-skills" -RepoUrl "https://github.com/alirezarezvani/claude-skills.git" -SkillSource "."
    Update-Repo -Name "claude-mem" -RepoUrl "https://github.com/thedotmack/claude-mem.git" -SkillSource "plugin\skills"

    # Record timestamp
    [int](Get-Date -UFormat %s) | Out-File $LastUpdateFile -Force

    $count = (Get-ChildItem $SkillsDir -Directory).Count
    Log ""
    Log "All skills synced. Total: $count skills"
} finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
