# AgentMaster Platform Installer (PowerShell) — mirror of install-platform.sh.
# Installs skills to a platform's on-disk location. aider/copilot use aggregate
# files instead — run convert.ps1 -Tool aider|copilot for those.
#
# Usage:
#   powershell -File scripts\install-platform.ps1                    # auto-detect
#   powershell -File scripts\install-platform.ps1 -Platform cursor
#   powershell -File scripts\install-platform.ps1 -Platform all
param([string]$Platform = "")
$ErrorActionPreference = "Stop"

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
function WriteFile([string]$path, [string]$content) {
  $dir = Split-Path -Parent $path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Set-Content -Path $path -Value $content -Encoding utf8 -NoNewline
}

function Detect-Platforms {
  $found = @()
  if (Test-Path (Join-Path $HOME ".claude"))      { $found += "claude-code" }
  if ((Test-Path (Join-Path $HOME ".cursor"))     -or (Test-Path ".cursor"))     { $found += "cursor" }
  if ((Test-Path (Join-Path $HOME ".windsurf"))   -or (Test-Path ".windsurf"))   { $found += "windsurf" }
  if ((Test-Path (Join-Path $HOME ".cline"))      -or (Test-Path ".clinerules")) { $found += "cline" }
  if (Test-Path (Join-Path $HOME ".codex"))       { $found += "codex" }
  if (Test-Path (Join-Path $HOME ".gemini"))      { $found += "gemini" }
  if (Test-Path (Join-Path $HOME ".antigravity")) { $found += "antigravity" }
  if (Test-Path (Join-Path $HOME ".opencode"))    { $found += "opencode" }
  if (Test-Path (Join-Path $HOME ".augment"))     { $found += "augment" }
  return $found
}

function Install-Skills([string]$platform) {
  $today = Get-Date -Format "yyyy-MM-dd"
  switch ($platform) {
    "claude-code" { $target = Join-Path $HOME ".claude\skills";      $fmt = "copy" }
    "codex"       { $target = Join-Path $HOME ".codex\skills";       $fmt = "copy" }
    "gemini"      { $target = Join-Path $HOME ".gemini\skills";      $fmt = "copy" }
    "antigravity" { $target = Join-Path $HOME ".antigravity\skills"; $fmt = "antigravity" }
    "opencode"    { $target = Join-Path $HOME ".opencode\skills";    $fmt = "opencode" }
    "cursor"      { $target = ".cursor\rules";    $fmt = "cursor" }
    "windsurf"    { $target = ".windsurf\skills"; $fmt = "windsurf" }
    "cline"       { $target = ".clinerules";      $fmt = "cline" }
    "augment"     { $target = ".augment\rules";   $fmt = "augment" }
    { $_ -in @("aider","copilot") } {
      Write-Output "  ! '$platform' uses aggregate files. Use: convert.ps1 -Tool $platform"; return }
    default { Write-Output "  ! Unknown platform: $platform"; return }
  }

  Get-ChildItem -Directory $SkillsDir | ForEach-Object {
    $skillFile = Join-Path $_.FullName "SKILL.md"
    if (-not (Test-Path $skillFile)) { return }
    $sk = $_.Name
    $name = Get-Field $skillFile "name"
    $desc = Get-Field $skillFile "description"
    $body = Get-Body  $skillFile
    switch ($fmt) {
      "copy"        { WriteFile (Join-Path $target "$sk\SKILL.md") ((Get-Content $skillFile -Raw)) }
      "cursor"      { WriteFile (Join-Path $target "$sk.mdc") "---`ndescription: `"$desc`"`nglobs:`nalwaysApply: false`n---`n$body`n" }
      "windsurf"    { WriteFile (Join-Path $target "$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`ntrigger: always_on`n---`n$body`n" }
      "cline"       { WriteFile (Join-Path $target "$sk.md") "$body`n" }
      "antigravity" { WriteFile (Join-Path $target "$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`nrisk: low`nsource: community`ndate_added: $today`n---`n$body`n" }
      "opencode"    { WriteFile (Join-Path $target "$sk\SKILL.md") "---`nname: `"$name`"`ndescription: `"$desc`"`ncompatibility: opencode`n---`n$body`n" }
      "augment"     { WriteFile (Join-Path $target "$sk.md") "---`ntype: auto`ndescription: `"$desc`"`n---`n$body`n" }
    }
    Write-Output "  + $sk -> $target"
  }
}

Write-Output "AgentMaster Platform Installer"
Write-Output "=============================="
Write-Output ""

if (-not $Platform) {
  $detected = Detect-Platforms
  if (-not $detected) {
    Write-Output "No supported platforms detected. Use -Platform <name>."
    exit 1
  }
  Write-Output "Found: $($detected -join ' ')"
  foreach ($p in $detected) { Write-Output "[$p]"; Install-Skills $p; Write-Output "" }
} elseif ($Platform -eq "all") {
  foreach ($p in @("claude-code","cursor","windsurf","cline","codex","gemini","antigravity","opencode","augment")) {
    Write-Output "[$p]"; Install-Skills $p; Write-Output ""
  }
} else {
  Write-Output "[$Platform]"; Install-Skills $Platform
}

Write-Output "=============================="
Write-Output "Done! Restart your IDE/agent to load skills."
