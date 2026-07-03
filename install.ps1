# AgentMaster Installer for Windows
# Clones dependency repos into the auto-update cache and copies skills to ~/.claude/skills/

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "AgentMaster Installer v1.2" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null

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

# Clone into the auto-update cache (if needed) and copy skills from there, so the
# installer and updater share one clone per repo and the first update is instant.
function Install-FromCache($Name, $Url, $SkillSource, $Summary) {
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
    Get-ChildItem $src -Directory | ForEach-Object {
        if ((Test-Path "$($_.FullName)\SKILL.md") -or ($SkillSource -eq "skills")) {
            Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
        }
    }
    Write-Host "  + $Summary" -ForegroundColor Green
}

# 1. Install custom skills
Write-Host "[1/7] Installing custom skills..." -ForegroundColor Yellow
Get-ChildItem "$ScriptDir\skills" -Directory | ForEach-Object {
    if (Test-Path "$($_.FullName)\SKILL.md") {
        Copy-Item -Path $_.FullName -Destination "$SkillsDir\$($_.Name)" -Recurse -Force
        Write-Host "  + $($_.Name)" -ForegroundColor Green
    }
}

# 2. Caveman
Write-Host ""
Write-Host "[2/7] Installing caveman (token compression)..." -ForegroundColor Yellow
Install-FromCache "caveman" "https://github.com/JuliusBrussee/caveman.git" "skills" `
    "caveman, caveman-commit, caveman-review, caveman-help, compress"

# 3. Superpowers
Write-Host ""
Write-Host "[3/7] Installing superpowers (dev workflow)..." -ForegroundColor Yellow
Install-FromCache "superpowers" "https://github.com/obra/superpowers.git" "skills" `
    "brainstorming, writing-plans, test-driven-development, ..."

# 4. Claude-skills
Write-Host ""
Write-Host "[4/7] Installing claude-skills (domain expertise)..." -ForegroundColor Yellow
Install-FromCache "claude-skills" "https://github.com/alirezarezvani/claude-skills.git" "." `
    "engineering-team, marketing-skill, product-team, c-level-advisor, ..."

# 5. Claude-mem skills
Write-Host ""
Write-Host "[5/7] Installing claude-mem skills (session memory)..." -ForegroundColor Yellow
Install-FromCache "claude-mem" "https://github.com/thedotmack/claude-mem.git" "plugin\skills" `
    "mem-search, smart-explore, knowledge-agent, make-plan, do, timeline-report"

# 6. Repomix CLI (for repomix-pack skill)
Write-Host ""
Write-Host "[6/7] Installing repomix CLI..." -ForegroundColor Yellow
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

# 7. Set up self-update cache (agent-master itself; dependency repos were cached in steps 2-5)
Write-Host ""
Write-Host "[7/7] Setting up auto-update cache..." -ForegroundColor Yellow
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
Write-Host "  /agent-master status       - show current state"
Write-Host "  /agent-master update       - force update all repos"
Write-Host "  /codereview                - blunt code review"
Write-Host "  /caveman                   - enable token compression"
Write-Host ""
Write-Host "Auto-update: skills sync from repos every 6 hours on first invoke."
Write-Host "Pin dependency repos to exact commits via repos.pins (see repo root)."
Write-Host "Start a new Claude Code session to load all skills."
