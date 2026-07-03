# AgentMaster Installer for Windows
# Clones dependency repos (from repos.manifest) into the auto-update cache
# and copies skills to ~/.claude/skills/

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manifest = "$ScriptDir\repos.manifest"
$OwnersFile = "$CacheDir\.skill-owners"

Write-Host "AgentMaster Installer v1.3" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
if (-not (Test-Path $OwnersFile)) { New-Item -ItemType File -Path $OwnersFile | Out-Null }

# git writes progress to stderr, which $ErrorActionPreference=Stop turns into a
# terminating error on PS 5.1 — so pipe everything and check the exit code instead.
function Invoke-Clone($Url, $Dest) {
    git clone --depth 1 --quiet $Url $Dest 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ! clone failed: $Url" -ForegroundColor Red
        return $false
    }
    return $true
}

# Track which repo installed each skill; report collisions (last writer wins)
function Record-Owner($Skill, $Repo) {
    $lines = @(Get-Content $OwnersFile -ErrorAction SilentlyContinue)
    $existing = $lines | Where-Object { $_ -match "^$([regex]::Escape($Skill))=" } | Select-Object -First 1
    if (-not $existing) {
        Add-Content -Path $OwnersFile -Value "$Skill=$Repo"
    } else {
        $prev = ($existing -split '=', 2)[1]
        if ($prev -ne $Repo) {
            Write-Host "  ! collision: skill '$Skill' was owned by $prev, overwritten by $Repo" -ForegroundColor Yellow
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

# Clone into the auto-update cache (if needed) and copy skills from there, so the
# installer and updater share one clone per repo and the first update is instant.
function Install-FromCache($Name, $Url, $SkillSource) {
    $cachePath = "$CacheDir\$Name"
    if (-not (Test-Path "$cachePath\.git")) {
        if (Test-Path $cachePath) { Remove-Item $cachePath -Recurse -Force }
        if (-not (Invoke-Clone $Url $cachePath)) { return }
    }
    $src = "$cachePath\$SkillSource"
    if (-not (Test-Path $src)) {
        Write-Host "  ! skill source missing: $src" -ForegroundColor Red
        return
    }
    $count = 0
    Get-ChildItem $src -Directory | ForEach-Object {
        if ((Test-Path "$($_.FullName)\SKILL.md") -or ($SkillSource -eq "skills")) {
            Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
            Record-Owner $_.Name $Name
            $count++
        }
    }
    Write-Host "  + ${Name}: $count skills" -ForegroundColor Green
}

# 1. Install custom skills
Write-Host "[1/4] Installing custom skills..." -ForegroundColor Yellow
Get-ChildItem "$ScriptDir\skills" -Directory | ForEach-Object {
    if (Test-Path "$($_.FullName)\SKILL.md") {
        Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
        Record-Owner $_.Name "agent-master"
        Write-Host "  + $($_.Name)" -ForegroundColor Green
    }
}

# 2. Install dependency repos from the manifest
Write-Host ""
Write-Host "[2/4] Installing dependency repos (repos.manifest)..." -ForegroundColor Yellow
foreach ($entry in Read-Manifest) {
    $parts = $entry -split '\|'
    if ($parts.Count -lt 3) { continue }
    Install-FromCache $parts[0].Trim() $parts[1].Trim() $parts[2].Trim()
}

# 3. Repomix CLI (for repomix-pack skill)
Write-Host ""
Write-Host "[3/4] Installing repomix CLI..." -ForegroundColor Yellow
$repomixOk = $false
try { & repomix --version 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { $repomixOk = $true } } catch {}
if ($repomixOk) {
    Write-Host "  ~ repomix already installed" -ForegroundColor DarkGray
} else {
    try {
        & npm install -g repomix 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  + repomix installed globally" -ForegroundColor Green
        } else {
            Write-Host "  ! repomix install failed. Run manually: npm install -g repomix" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ! npm not found. Install Node.js then run: npm install -g repomix" -ForegroundColor Yellow
    }
}

# 4. Set up self-update cache (agent-master itself; dependency repos were cached in step 2)
Write-Host ""
Write-Host "[4/4] Setting up auto-update cache..." -ForegroundColor Yellow
$amCache = "$CacheDir\agent-master"
if (Test-Path "$amCache\.git") {
    Write-Host "  ~ cache already exists" -ForegroundColor DarkGray
} else {
    if (Test-Path $amCache) { Remove-Item $amCache -Recurse -Force }
    if (Invoke-Clone "https://github.com/Surya8991/AgentMaster.git" $amCache) {
        Write-Host "  + auto-update cache initialized" -ForegroundColor Green
    } elseif (Test-Path "$ScriptDir\.git") {
        # Offline fallback: copy the local clone (including .git so the updater can pull)
        Copy-Item -Path $ScriptDir -Destination $amCache -Recurse -Force
        Write-Host "  + auto-update cache copied from local clone" -ForegroundColor Green
    } else {
        Write-Host "  ! could not initialize cache; the auto-updater will retry" -ForegroundColor Yellow
    }
}

# Done
$count = (Get-ChildItem $SkillsDir -Directory).Count
Write-Host ""
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "AgentMaster installed!" -ForegroundColor Green
Write-Host ""
Write-Host "Skills installed to: $SkillsDir"
Write-Host "Total skills: $count"
Write-Host ""
Write-Host "Usage:"
Write-Host "  /agent-master              - invoke orchestrator"
Write-Host "  /agent-master route <task> - dry-run routing"
Write-Host "  /agent-master status       - show current state + last sync"
Write-Host "  /agent-master update       - force update all repos"
Write-Host "  /agent-master doctor       - health-check installed skills"
Write-Host "  /agent-master list         - list skills grouped by source repo"
Write-Host "  /codereview                - blunt code review"
Write-Host "  /caveman                   - enable token compression"
Write-Host ""
Write-Host "Auto-update: skills sync from repos every 6 hours on first invoke."
Write-Host "Add repos via repos.manifest (or ~/.claude/.agentmaster-cache/repos.local)."
Write-Host "Pin repos to exact commits via repos.pins."
Write-Host "Start a new Claude Code session to load all skills."
