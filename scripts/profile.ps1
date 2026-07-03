# AgentMaster Profile — show or switch the active install profile.
#
# Usage:
#   .\scripts\profile.ps1              # show active + available profiles
#   .\scripts\profile.ps1 <name>       # switch: prune excluded skills, resync

param([string]$Name)

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$ProfileFile = "$CacheDir\.profile"
$OwnersFile = "$CacheDir\.skill-owners"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-AllLines {
    $files = @()
    if (Test-Path "$CacheDir\agent-master\profiles.manifest") {
        $files += "$CacheDir\agent-master\profiles.manifest"
    } elseif (Test-Path "$ScriptDir\..\profiles.manifest") {
        $files += "$ScriptDir\..\profiles.manifest"
    }
    if (Test-Path "$CacheDir\profiles.local") { $files += "$CacheDir\profiles.local" }
    $lines = @()
    foreach ($f in $files) {
        $lines += Get-Content $f | Where-Object { $_ -notmatch '^\s*(#|$)' }
    }
    return $lines
}

function Test-SkillInProfile($TargetProfile, $Repo, $Skill) {
    if ($TargetProfile -eq "full") { return $true }
    if ($Skill -eq "agent-master") { return $true }  # the orchestrator always stays
    foreach ($line in Get-AllLines) {
        $parts = $line -split '\|'
        if ($parts.Count -lt 3) { continue }
        if ($parts[0].Trim() -eq $TargetProfile -and $parts[1].Trim() -eq $Repo -and $Skill -like $parts[2].Trim()) {
            return $true
        }
    }
    return $false
}

$active = "full"
if (Test-Path $ProfileFile) {
    $p = (Get-Content $ProfileFile -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($p) { $active = $p.Trim() }
}

# --- Show mode ---
if (-not $Name) {
    Write-Host "AgentMaster Profiles"
    Write-Host "===================="
    Write-Host ""
    Write-Host "Active profile: $active"
    Write-Host ""
    Write-Host "Available profiles:"
    Write-Host "  full - everything (no filtering)"
    $allLines = Get-AllLines
    foreach ($p in ($allLines | ForEach-Object { ($_ -split '\|')[0].Trim() } | Sort-Object -Unique)) {
        Write-Host "  ${p}:"
        foreach ($line in $allLines) {
            $parts = $line -split '\|'
            if ($parts.Count -ge 3 -and $parts[0].Trim() -eq $p) {
                Write-Host "    $($parts[1].Trim()): $($parts[2].Trim())"
            }
        }
    }
    Write-Host ""
    Write-Host "Switch with: /agent-master profile <name>"
    exit 0
}

# --- Switch mode ---
$known = @(Get-AllLines | ForEach-Object { ($_ -split '\|')[0].Trim() } | Sort-Object -Unique)
if ($Name -ne "full" -and $known -notcontains $Name) {
    Write-Host "Unknown profile: $Name"
    Write-Host "Available: full $($known -join ' ')"
    exit 1
}

Write-Host "Switching profile: $active -> $Name"
Set-Content -Path $ProfileFile -Value $Name

# Prune installed skills the new profile excludes.
# Only skills with a recorded owner are ever touched — orphans/user skills stay.
$pruned = 0
if (Test-Path $OwnersFile) {
    $owners = @(Get-Content $OwnersFile | Where-Object { $_ -match '=' })
    $kept = @()
    foreach ($line in $owners) {
        $kv = $line -split '=', 2
        $skill = $kv[0]; $repo = $kv[1]
        if (Test-SkillInProfile $Name $repo $skill) {
            $kept += $line
        } else {
            if (Test-Path "$SkillsDir\$skill") { Remove-Item "$SkillsDir\$skill" -Recurse -Force }
            Write-Host "  - pruned: $skill ($repo)"
            $pruned++
        }
    }
    Set-Content -Path $OwnersFile -Value $kept
}
Write-Host "Pruned $pruned skills."

# Resync immediately (clear the cooldown so the update actually runs)
Remove-Item "$CacheDir\.last-update" -Force -ErrorAction SilentlyContinue
Write-Host ""
& "$ScriptDir\update.ps1"
Write-Host ""
Write-Host "Profile '$Name' active. Restart your Claude Code session to reload skills."
