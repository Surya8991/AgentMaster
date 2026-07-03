# AgentMaster Uninstaller for Windows — removes only custom skills (agent-master, codereview, devops, security-audit, repomix-pack)
# Does NOT remove third-party skills (caveman, superpowers, claude-skills, claude-mem)

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"

Write-Host "Removing AgentMaster custom skills..."
foreach ($skill in @("agent-master", "codereview", "devops", "security-audit", "repomix-pack")) {
    if (Test-Path "$SkillsDir\$skill") {
        Remove-Item "$SkillsDir\$skill" -Recurse -Force
        Write-Host "  - $skill"
    }
}

Write-Host ""
Write-Host "AgentMaster custom skills removed."
Write-Host "Third-party skills (caveman, superpowers, claude-skills, claude-mem) left intact."
Write-Host "To remove everything: Remove-Item -Recurse -Force $SkillsDir\*"
