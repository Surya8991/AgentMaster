# AgentMaster Multi-Platform Converter (PowerShell)
# Converts skills/*/SKILL.md into platform-specific formats. Mirror of convert.sh
# for Windows users without bash.
#
# Usage:
#   powershell -File scripts\convert.ps1 -Tool cursor|windsurf|cline|codex|gemini|antigravity|opencode|augment|aider|copilot|all
#   powershell -File scripts\convert.ps1 -All
param(
  [string]$Tool = "all",
  [switch]$All
)
$ErrorActionPreference = "Stop"
if ($All) { $Tool = "all" }

$valid = @("cursor","windsurf","cline","codex","gemini","antigravity","opencode","augment","aider","copilot","all")
if ($valid -notcontains $Tool) {
  Write-Error "unknown -Tool value: '$Tool'. Valid: $($valid -join ' ')"; exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir   = Split-Path -Parent $ScriptDir
$SkillsDir = Join-Path $RepoDir "skills"

. (Join-Path $ScriptDir "lib/skill-render.ps1")

function Want([string]$t) { return ($Tool -eq $t -or $Tool -eq "all") }

# Reset aggregate files
if (Want "aider")   { WriteFile (Join-Path $RepoDir "CONVENTIONS.md") "" }
if (Want "copilot") { WriteFile (Join-Path $RepoDir ".github\copilot-instructions.md") "" }

Get-ChildItem -Directory $SkillsDir | Sort-Object Name | ForEach-Object {
  $skillFile = Join-Path $_.FullName "SKILL.md"
  if (-not (Test-Path $skillFile)) { return }
  $sk   = $_.Name
  $name = Get-Field $skillFile "name"
  $desc = Get-Field $skillFile "description"
  $body = Get-Body  $skillFile
  Write-Output "Converting: $sk"

  if (Want "cursor") {
    WriteFile (Join-Path $RepoDir ".cursor\rules\$sk.mdc") (Render-Skill "cursor" $name $desc $body)
    Write-Output "  + .cursor/rules/$sk.mdc"
  }
  if (Want "windsurf") {
    WriteFile (Join-Path $RepoDir ".windsurf\skills\$sk\SKILL.md") (Render-Skill "windsurf" $name $desc $body)
    Write-Output "  + .windsurf/skills/$sk/SKILL.md"
  }
  if (Want "cline") {
    WriteFile (Join-Path $RepoDir ".clinerules\$sk.md") (Render-Skill "cline" $name $desc $body)
    Write-Output "  + .clinerules/$sk.md"
  }
  if (Want "codex") {
    WriteFile (Join-Path $RepoDir ".codex\skills\$sk\SKILL.md") ((Get-Content -LiteralPath $skillFile -Raw -Encoding utf8))
    Write-Output "  + .codex/skills/$sk/SKILL.md"
  }
  if (Want "gemini") {
    WriteFile (Join-Path $RepoDir ".gemini\skills\$sk\SKILL.md") ((Get-Content -LiteralPath $skillFile -Raw -Encoding utf8))
    Write-Output "  + .gemini/skills/$sk/SKILL.md"
  }
  if (Want "antigravity") {
    WriteFile (Join-Path $RepoDir ".antigravity\skills\$sk\SKILL.md") (Render-Skill "antigravity" $name $desc $body)
    Write-Output "  + .antigravity/skills/$sk/SKILL.md"
  }
  if (Want "opencode") {
    WriteFile (Join-Path $RepoDir ".opencode\skills\$sk\SKILL.md") (Render-Skill "opencode" $name $desc $body)
    Write-Output "  + .opencode/skills/$sk/SKILL.md"
  }
  if (Want "augment") {
    WriteFile (Join-Path $RepoDir ".augment\rules\$sk.md") (Render-Skill "augment" $name $desc $body)
    Write-Output "  + .augment/rules/$sk.md"
  }
  if (Want "aider") {
    WriteFile (Join-Path $RepoDir "CONVENTIONS.md") (Render-Skill "aider" $name $desc $body) -Append
    Write-Output "  + CONVENTIONS.md (appended $sk)"
  }
  if (Want "copilot") {
    WriteFile (Join-Path $RepoDir ".github\copilot-instructions.md") (Render-Skill "copilot" $name $desc $body) -Append
    Write-Output "  + .github/copilot-instructions.md (appended $sk)"
  }
}

Write-Output ""
Write-Output "Conversion complete for: $Tool"
