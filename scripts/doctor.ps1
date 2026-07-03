# AgentMaster Doctor — health-check installed skills, caches, and pins.
# Exit code: 0 if no FAILs, 1 otherwise. Missing files degrade to WARN.
#
# Usage: .\scripts\doctor.ps1

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$PinsFile = "$CacheDir\agent-master\repos.pins"
$Manifest = "$CacheDir\agent-master\repos.manifest"
$OwnersFile = "$CacheDir\.skill-owners"
$LastUpdateFile = "$CacheDir\.last-update"

$script:Pass = 0; $script:Warn = 0; $script:Fail = 0

function Test-Pass($msg) { Write-Host "  PASS  $msg" -ForegroundColor Green; $script:Pass++ }
function Test-Warn($msg) { Write-Host "  WARN  $msg" -ForegroundColor Yellow; $script:Warn++ }
function Test-Fail($msg) { Write-Host "  FAIL  $msg" -ForegroundColor Red; $script:Fail++ }
function Test-Note($msg) { Write-Host "  NOTE  $msg" -ForegroundColor DarkGray }

Write-Host "AgentMaster Doctor"
Write-Host "=================="

# --- Skills directory ---
Write-Host ""
Write-Host "Skills:"
if (-not (Test-Path $SkillsDir)) {
    Test-Fail "skills directory missing: $SkillsDir - run install"
} else {
    $badMd = 0; $badName = 0; $badDesc = 0; $total = 0
    foreach ($dir in Get-ChildItem $SkillsDir -Directory) {
        $total++
        $md = "$($dir.FullName)\SKILL.md"
        if (-not (Test-Path $md)) {
            Test-Fail "$($dir.Name): no SKILL.md"
            $badMd++
            continue
        }
        $content = Get-Content $md -TotalCount 30
        $nameLine = $content | Where-Object { $_ -match '^name:' } | Select-Object -First 1
        if (-not $nameLine) {
            Test-Warn "$($dir.Name): SKILL.md has no 'name:' frontmatter"
            $badName++
        } else {
            $fmName = ($nameLine -replace '^name:\s*', '').Trim('"', "'", ' ')
            if ($fmName -ne $dir.Name) {
                Test-Warn "$($dir.Name): frontmatter name is '$fmName' (mismatch)"
                $badName++
            }
        }
        if (-not ($content | Where-Object { $_ -match '^description:' })) {
            Test-Warn "$($dir.Name): SKILL.md has no 'description:' frontmatter"
            $badDesc++
        }
    }
    if ($badMd -eq 0) { Test-Pass "$total skills all have SKILL.md" }
    if ($badName -eq 0) { Test-Pass "all frontmatter names match directory names" }
    if ($badDesc -eq 0) { Test-Pass "all skills have descriptions" }
}

# --- Cache repos ---
Write-Host ""
Write-Host "Caches:"
$manifestNames = @()
if (-not (Test-Path $Manifest)) {
    Test-Warn "manifest not cached yet: $Manifest - run /agent-master update"
} else {
    $entries = @(Get-Content $Manifest | Where-Object { $_ -notmatch '^\s*(#|$)' })
    if (Test-Path "$CacheDir\repos.local") {
        $entries += Get-Content "$CacheDir\repos.local" | Where-Object { $_ -notmatch '^\s*(#|$)' }
    }
    foreach ($entry in $entries) {
        $parts = $entry -split '\|'
        if ($parts.Count -lt 3) { continue }
        $name = $parts[0].Trim()
        $manifestNames += $name
        if (Test-Path "$CacheDir\$name\.git") {
            $sha = git -C "$CacheDir\$name" rev-parse --short HEAD 2>$null
            if (-not $sha) { $sha = "?" }
            Test-Pass "$name cached ($sha)"
        } else {
            Test-Warn "$name not cached - run /agent-master update"
        }
    }
}
if (Test-Path "$CacheDir\agent-master\.git") {
    Test-Pass "agent-master self-update cache healthy"
} else {
    Test-Warn "agent-master cache missing .git - self-update will re-clone"
}

# --- Pins ---
Write-Host ""
Write-Host "Pins:"
if (-not (Test-Path $PinsFile)) {
    Test-Note "no repos.pins - all repos track upstream HEAD"
} else {
    $pinCount = 0; $pinBad = 0
    foreach ($line in Get-Content $PinsFile | Where-Object { $_ -notmatch '^\s*(#|$)' }) {
        $kv = $line -split '=', 2
        if ($kv.Count -lt 2) { continue }
        $pinCount++
        $pname = $kv[0].Trim(); $psha = $kv[1].Trim()
        if ($manifestNames -notcontains $pname) {
            Test-Warn "pin '$pname' not in repos.manifest"
            $pinBad++
        }
        if ($psha -notmatch '^[0-9a-f]{40}$') {
            Test-Warn "pin '$pname' sha is not 40-char hex: $psha"
            $pinBad++
        }
    }
    if ($pinCount -eq 0) {
        Test-Note "repos.pins present but no pins set - all repos track upstream HEAD"
    } elseif ($pinBad -eq 0) {
        Test-Pass "$pinCount pins valid"
    }
}

# --- Ownership ---
Write-Host ""
Write-Host "Ownership:"
if (-not (Test-Path $OwnersFile)) {
    Test-Warn "no ownership records - run /agent-master update to build them"
} else {
    $owners = @(Get-Content $OwnersFile -ErrorAction SilentlyContinue)
    $orphans = 0
    foreach ($dir in Get-ChildItem $SkillsDir -Directory -ErrorAction SilentlyContinue) {
        $match = $owners | Where-Object { $_ -match "^$([regex]::Escape($dir.Name))=" } | Select-Object -First 1
        if (-not $match) {
            Test-Note "orphan skill (no recorded owner, probably yours): $($dir.Name)"
            $orphans++
        }
    }
    Test-Pass "$($owners.Count) skills have recorded owners ($orphans orphans)"
}

# --- Tooling & freshness ---
Write-Host ""
Write-Host "Tooling:"
$repomixOk = $false
try { & repomix --version 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $repomixOk = $true } } catch {}
if ($repomixOk) {
    Test-Pass "repomix on PATH"
} else {
    Test-Warn "repomix not on PATH - repomix-pack skill won't work (npm install -g repomix)"
}
if (Test-Path $LastUpdateFile) {
    $last = [int](Get-Content $LastUpdateFile -ErrorAction SilentlyContinue)
    $ageDays = [math]::Floor(([int](Get-Date -UFormat %s) - $last) / 86400)
    if ($ageDays -gt 7) {
        Test-Warn "last sync was ${ageDays}d ago - updates may be failing silently"
    } else {
        Test-Pass "last sync ${ageDays}d ago"
    }
} else {
    Test-Warn "never synced - run /agent-master update"
}

# --- Summary ---
Write-Host ""
Write-Host "=================="
Write-Host "Summary: $script:Pass pass, $script:Warn warn, $script:Fail fail"
if ($script:Fail -eq 0) { exit 0 } else { exit 1 }
