# AgentMaster List — installed skills grouped by source repo.
#
# Usage: .\scripts\list.ps1

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$CacheDir = "$env:USERPROFILE\.claude\.agentmaster-cache"
$OwnersFile = "$CacheDir\.skill-owners"

if (-not (Test-Path $SkillsDir)) {
    Write-Host "No skills directory at $SkillsDir - run install first."
    exit 1
}

$owners = @{}
if (Test-Path $OwnersFile) {
    foreach ($line in Get-Content $OwnersFile) {
        $kv = $line -split '=', 2
        if ($kv.Count -eq 2) { $owners[$kv[0]] = $kv[1] }
    }
}

$rows = foreach ($dir in Get-ChildItem $SkillsDir -Directory) {
    $owner = if ($owners.ContainsKey($dir.Name)) { $owners[$dir.Name] } else { "(unmanaged)" }
    $desc = ""
    $md = "$($dir.FullName)\SKILL.md"
    if (Test-Path $md) {
        $content = Get-Content $md -TotalCount 30
        for ($i = 0; $i -lt $content.Count; $i++) {
            if ($content[$i] -match '^description:') {
                $desc = ($content[$i] -replace '^description:\s*', '').Trim('"', "'", ' ')
                if ($desc -match '^[>|][-+]?$') {
                    # YAML block scalar — the text starts on the next indented line
                    for ($j = $i + 1; $j -lt $content.Count; $j++) {
                        if ($content[$j].Trim()) { $desc = $content[$j].Trim(); break }
                    }
                }
                if ($desc.Length -gt 80) { $desc = $desc.Substring(0, 77) + "..." }
                break
            }
        }
    }
    [pscustomobject]@{ Owner = $owner; Skill = $dir.Name; Desc = $desc }
}

Write-Host "Installed skills ($($rows.Count))"
Write-Host "======================================"

foreach ($group in $rows | Sort-Object Owner, Skill | Group-Object Owner) {
    Write-Host ""
    Write-Host "[$($group.Name)]" -ForegroundColor Cyan
    foreach ($row in $group.Group) {
        if ($row.Desc) {
            Write-Host ("  {0,-32} {1}" -f $row.Skill, $row.Desc)
        } else {
            Write-Host "  $($row.Skill)"
        }
    }
}
