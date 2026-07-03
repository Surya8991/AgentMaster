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

    # Read an optional commit pin for a repo (name=sha lines).
    # pins.local (machine-local, written by rollback) wins over repos.pins.
    function Get-Pin($Name) {
        foreach ($f in @("$CacheDir\pins.local", $PinsFile)) {
            if (-not (Test-Path $f)) { continue }
            $line = Select-String -Path $f -Pattern "^$Name=" | Select-Object -First 1
            if ($line) { return ($line.Line -split '=', 2)[1].Trim() }
        }
        return $null
    }

    function Restore-DefaultBranch($CachePath) {
        # A prior pin/rollback leaves the cache on a detached HEAD, where pull
        # fails. Re-attach to the remote default branch before pulling.
        $head = git -C $CachePath rev-parse --abbrev-ref HEAD 2>$null
        if ($head -eq "HEAD") {
            $def = git -C $CachePath symbolic-ref --short refs/remotes/origin/HEAD 2>$null
            if ($def) { $def = $def -replace '^origin/', '' } else { $def = "main" }
            git -C $CachePath checkout --quiet $def 2>&1 | Out-Null
        }
    }

    function Backup-RepoSkills($Repo, $PrevSha) {
        # Back up the currently installed skills owned by $Repo before they
        # are overwritten. One generation.
        $bdir = "$CacheDir\backups\$Repo"
        if (Test-Path $bdir) { Remove-Item $bdir -Recurse -Force }
        New-Item -ItemType Directory -Path $bdir -Force | Out-Null
        $found = 0
        foreach ($line in @(Get-Content $OwnersFile -ErrorAction SilentlyContinue | Where-Object { $_ -match '=' })) {
            $kv = $line -split '=', 2
            if ($kv[1] -ne $Repo) { continue }
            if (Test-Path "$SkillsDir\$($kv[0])") {
                Copy-Item -Path "$SkillsDir\$($kv[0])" -Destination "$bdir\$($kv[0])" -Recurse -Force
                $found++
            }
        }
        if ($found -gt 0) {
            Set-Content -Path "$bdir\.meta" -Value @(
                "sha=$PrevSha",
                "date=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
                "skills=$found"
            )
        } else {
            Remove-Item $bdir -Recurse -Force  # nothing previous to keep (first install)
        }
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

    # --- Profiles: filter which repos/skills sync (see profiles.manifest) ---
    $script:ActiveProfile = "full"
    if (Test-Path "$CacheDir\.profile") {
        $p = (Get-Content "$CacheDir\.profile" -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($p) { $script:ActiveProfile = $p.Trim() }
    }

    function Get-ProfileLines {
        # "profile|repo|glob" lines for the active profile (manifest + profiles.local)
        $lines = @()
        foreach ($f in @("$CacheDir\agent-master\profiles.manifest", "$CacheDir\profiles.local")) {
            if (Test-Path $f) {
                $lines += Get-Content $f | Where-Object { $_ -notmatch '^\s*(#|$)' }
            }
        }
        return @($lines | Where-Object { ($_ -split '\|')[0].Trim() -eq $script:ActiveProfile })
    }

    function Test-RepoInProfile($Repo) {
        if ($script:ActiveProfile -eq "full") { return $true }
        foreach ($line in Get-ProfileLines) {
            if (($line -split '\|')[1].Trim() -eq $Repo) { return $true }
        }
        return $false
    }

    function Test-SkillInProfile($Repo, $Skill) {
        if ($script:ActiveProfile -eq "full") { return $true }
        if ($Skill -eq "agent-master") { return $true }  # the orchestrator always installs
        foreach ($line in Get-ProfileLines) {
            $parts = $line -split '\|'
            if ($parts.Count -lt 3) { continue }
            if ($parts[1].Trim() -eq $Repo -and $Skill -like $parts[2].Trim()) { return $true }
        }
        return $false
    }

    function Sync-Skills($Name, $Src, $SkillSource) {
        $count = 0
        if (Test-Path $Src) {
            Get-ChildItem $Src -Directory | ForEach-Object {
                if ((Test-Path "$($_.FullName)\SKILL.md") -or ($SkillSource -eq "skills")) {
                    if (Test-SkillInProfile $Name $_.Name) {
                        Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
                        Record-Owner $_.Name $Name
                        $count++
                    }
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
            $beforeFull = git -C $cachePath rev-parse HEAD 2>$null
            if ($pin) {
                # Pinned: fetch and check out the exact commit, never track HEAD
                git -C $cachePath fetch --depth 1 --quiet origin $pin 2>&1 | Out-Null
                git -C $cachePath checkout --quiet $pin 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Add-Report "${Name}: pin $pin not found, keeping current"
                } else {
                    $afterFull = git -C $cachePath rev-parse HEAD 2>$null
                    if ($beforeFull -and $afterFull -and $beforeFull -ne $afterFull) {
                        Backup-RepoSkills $Name $beforeFull
                    }
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
            Restore-DefaultBranch $cachePath
            git -C $cachePath pull --ff-only --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Add-Report "${Name}: pull failed, keeping current ($before)"; return }
            $after = git -C $cachePath rev-parse --short HEAD 2>$null
            if ($before -eq $after) {
                # Still sync: copies are idempotent and this keeps ownership
                # records complete even when nothing changed upstream.
                Sync-Skills $Name "$cachePath\$SkillSource" $SkillSource | Out-Null
                Add-Report "${Name}: up to date ($after)"
                return
            }
            # Back up the outgoing versions before overwriting (enables rollback)
            if ($beforeFull) { Backup-RepoSkills $Name $beforeFull }
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
        $amBeforeFull = git -C $amCache rev-parse HEAD 2>$null
        # Caches are machine-managed mirrors — discard any local edits that
        # would block the pull (e.g. left behind by older installers).
        git -C $amCache reset --hard --quiet 2>&1 | Out-Null
        git -C $amCache clean -fdq 2>&1 | Out-Null
        $amPin = Get-Pin "agent-master"
        if ($amPin) {
            # Self-rollback support: honor an agent-master pin instead of pulling
            git -C $amCache fetch --depth 1 --quiet origin $amPin 2>&1 | Out-Null
            git -C $amCache checkout --quiet $amPin 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Add-Report "agent-master: pin $amPin not found, keeping current ($amBefore)"
            } else {
                $amAfterFull = git -C $amCache rev-parse HEAD 2>$null
                if ($amBeforeFull -and $amAfterFull -and $amBeforeFull -ne $amAfterFull) {
                    Backup-RepoSkills "agent-master" $amBeforeFull
                }
                Add-Report "agent-master: pinned to $($amPin.Substring(0,7))"
            }
        } else {
            Restore-DefaultBranch $amCache
            git -C $amCache pull --ff-only --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Add-Report "agent-master: pull failed, keeping current ($amBefore)"
            } else {
                $amAfter = git -C $amCache rev-parse --short HEAD 2>$null
                if ($amBefore -eq $amAfter) { Add-Report "agent-master: up to date ($amAfter)" }
                else {
                    # Back up the outgoing custom skills before overwriting (enables rollback)
                    if ($amBeforeFull) { Backup-RepoSkills "agent-master" $amBeforeFull }
                    Add-Report "agent-master: updated $amBefore -> $amAfter"
                }
            }
        }
    }
    # Unknown-profile guard AFTER self-update so a freshly pushed profiles.manifest counts.
    # A typo in .profile must never mass-uninstall — fall back to full.
    if ($script:ActiveProfile -ne "full" -and (Get-ProfileLines).Count -eq 0) {
        Add-Report "profile '$($script:ActiveProfile)' not found - using full"
        $script:ActiveProfile = "full"
    }
    if ($script:ActiveProfile -ne "full") { Add-Report "profile: $($script:ActiveProfile)" }

    if (Test-Path "$amCache\skills") {
        Get-ChildItem "$amCache\skills" -Directory | ForEach-Object {
            if (Test-SkillInProfile "agent-master" $_.Name) {
                Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
                Record-Owner $_.Name "agent-master"
            }
        }
    }

    # Update each dependency repo from the manifest
    if (-not (Test-Path $Manifest)) {
        Add-Report "manifest missing: $Manifest - no dependency repos synced"
    }
    foreach ($entry in Read-Manifest) {
        $parts = $entry -split '\|'
        if ($parts.Count -lt 3) { continue }
        $repoName = $parts[0].Trim()
        if (-not (Test-RepoInProfile $repoName)) {
            Add-Report "${repoName}: skipped (profile: $($script:ActiveProfile))"
            continue
        }
        Update-Repo -Name $repoName -RepoUrl $parts[1].Trim() -SkillSource $parts[2].Trim()
    }

    # Regenerate unrouted-skills.txt: installed skills never mentioned in the routing table
    $routingTable = "$amCache\skills\agent-master\SKILL.md"
    $unroutedFile = "$CacheDir\unrouted-skills.txt"
    if (Test-Path $routingTable) {
        $tableText = Get-Content $routingTable -Raw
        $unroutedLines = @()
        foreach ($dir in Get-ChildItem $SkillsDir -Directory) {
            if ($tableText -match "\b$([regex]::Escape($dir.Name))\b") { continue }
            $desc = ""
            $md = "$($dir.FullName)\SKILL.md"
            if (Test-Path $md) {
                $content = Get-Content $md -TotalCount 30
                for ($i = 0; $i -lt $content.Count; $i++) {
                    if ($content[$i] -match '^description:') {
                        $desc = ($content[$i] -replace '^description:\s*', '').Trim('"', "'", ' ')
                        if ($desc -match '^[>|][-+]?$') {
                            for ($j = $i + 1; $j -lt $content.Count; $j++) {
                                if ($content[$j].Trim()) { $desc = $content[$j].Trim(); break }
                            }
                        }
                        if ($desc.Length -gt 100) { $desc = $desc.Substring(0, 97) + "..." }
                        break
                    }
                }
            }
            $unroutedLines += "$($dir.Name) - $desc"
        }
        Set-Content -Path $unroutedFile -Value $unroutedLines
        Add-Report "unrouted skills: $($unroutedLines.Count) (not in routing table)"
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
