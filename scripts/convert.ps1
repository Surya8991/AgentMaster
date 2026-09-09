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

function Get-Field([string]$file, [string]$field) {
  $inFm = $false
  foreach ($line in Get-Content $file) {
    if ($line -eq "---") { if ($inFm) { break } else { $inFm = $true; continue } }
    if ($inFm -and $line -match "^$([regex]::Escape($field)):\s*(.*)$") {
      return ($matches[1] -replace '^"(.*)"$', '$1')
    }
  }
  return ""
}
function Get-Body([string]$file) {
  $c = 0; $out = New-Object System.Collections.Generic.List[string]
  foreach ($line in Get-Content $file) {
    if ($line -eq "---") { $c++; continue }
    if ($c -ge 2) { $out.Add($line) }
  }
  return ($out -join "`n")
}
function Want([string]$t) { return ($Tool -eq $t -or $Tool -eq "all") }
function WriteFile([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -Path $path -Value $content -Encoding utf8 -NoNewline
}

# Reset aggregate files
if (Want "aider")   { WriteFile (Join-Path $RepoDir "CONVENTIONS.md") "" }
if (Want "copilot") { WriteFile (Join-Path $RepoDir ".github\copilot-instructions.md") "" }

$today = Get-Date -Format "yyyy-MM-dd"

Get-ChildItem -Directory $SkillsDir | ForEach-Object {
  $skillFile = Join-Path $_.FullName "SKILL.md"
  if (-not (Test-Path $skillFile)) { return }
  $sk   = $_.Name
  $name = Get-Field $skillFile "name"
  $desc = Get-Field $skillFile "description"
  $body = Get-Body  $skillFile
  Write-Output "Converting: $sk"

  if (Want "cursor") {
    WriteFile (Join-Path $RepoDir ".cursor\rules\$sk.mdc") "---`ndescription: `"$desc`"`nglobs:`nalwaysApply: false`n---`n$body`n"
    Write-Output "  + .cursor/rules/$sk.mdc"
  }
  if (Want "windsurf") {
    WriteFile (Join-Path $RepoDir ".windsurf\skills\$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`ntrigger: always_on`n---`n$body`n"
    Write-Output "  + .windsurf/skills/$sk/SKILL.md"
  }
  if (Want "cline") {
    WriteFile (Join-Path $RepoDir ".clinerules\$sk.md") "$body`n"
    Write-Output "  + .clinerules/$sk.md"
  }
  if (Want "codex") {
    WriteFile (Join-Path $RepoDir ".codex\skills\$sk\SKILL.md") ((Get-Content $skillFile -Raw))
    Write-Output "  + .codex/skills/$sk/SKILL.md"
  }
  if (Want "gemini") {
    WriteFile (Join-Path $RepoDir ".gemini\skills\$sk\SKILL.md") ((Get-Content $skillFile -Raw))
    Write-Output "  + .gemini/skills/$sk/SKILL.md"
  }
  if (Want "antigravity") {
    WriteFile (Join-Path $RepoDir ".antigravity\skills\$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`nrisk: low`nsource: community`ndate_added: $today`n---`n$body`n"
    Write-Output "  + .antigravity/skills/$sk/SKILL.md"
  }
  if (Want "opencode") {
    WriteFile (Join-Path $RepoDir ".opencode\skills\$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`ncompatibility: opencode`n---`n$body`n"
    Write-Output "  + .opencode/skills/$sk/SKILL.md"
  }
  if (Want "augment") {
    WriteFile (Join-Path $RepoDir ".augment\rules\$sk.md") "---`ntype: auto`ndescription: `"$desc`"`n---`n$body`n"
    Write-Output "  + .augment/rules/$sk.md"
  }
  if (Want "aider") {
    Add-Content -Path (Join-Path $RepoDir "CONVENTIONS.md") -Encoding utf8 -Value "`n---`n`n## $name`n> $desc`n`n$body"
    Write-Output "  + CONVENTIONS.md (appended $sk)"
  }
  if (Want "copilot") {
    Add-Content -Path (Join-Path $RepoDir ".github\copilot-instructions.md") -Encoding utf8 -Value "`n## $name`n$desc`n`n$body"
    Write-Output "  + .github/copilot-instructions.md (appended $sk)"
  }
}

Write-Output ""
Write-Output "Conversion complete for: $Tool"
