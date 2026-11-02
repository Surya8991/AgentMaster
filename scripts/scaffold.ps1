# AgentMaster Scaffold (PowerShell) - detect and offer the canonical project-doc spine.
#
# Spine: README.md | AGENTS.md | CLAUDE.md(@AGENTS.md) | PROJECTLOG.md
#
# Usage:
#   powershell -File scripts\scaffold.ps1                  # detect + report (no writes)
#   powershell -File scripts\scaffold.ps1 apply            # create missing files
#   powershell -File scripts\scaffold.ps1 apply -WithRules # also add RULES.md
#
# Never overwrites an existing file. Accepts variants (agents.md, PROJECT_LOG.md) as present.

param(
  [string]$Mode = "report",
  [switch]$WithRules
)

$ErrorActionPreference = "Stop"
$Utf8 = New-Object System.Text.UTF8Encoding $false

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TmplDir   = Join-Path $ScriptDir "templates"
$Target    = (Get-Location).Path
$Name      = Split-Path $Target -Leaf
$Date      = (Get-Date -Format "yyyy-MM-dd")

$pkg = Join-Path $Target "package.json"
if (Test-Path $pkg) {
  $m = Select-String -Path $pkg -Encoding utf8 -Pattern '"name"\s*:\s*"([^"]+)"' | Select-Object -First 1
  if ($m) { $Name = $m.Matches[0].Groups[1].Value }
}

function Present([string[]]$names) {
  foreach ($f in $names) { if (Test-Path (Join-Path $Target $f)) { return $f } }
  return ""
}

$R_README = Present @("README.md","readme.md")
$R_AGENTS = Present @("AGENTS.md","agents.md")
$R_CLAUDE = Present @("CLAUDE.md")
$R_PLOG   = Present @("PROJECTLOG.md","PROJECT_LOG.md","projectlog.md")

$isRepo = "no"
if ((Test-Path (Join-Path $Target ".git")) -or (Test-Path $pkg) -or `
    (Test-Path (Join-Path $Target "pyproject.toml")) -or `
    (Test-Path (Join-Path $Target "Cargo.toml")) -or `
    (Test-Path (Join-Path $Target "go.mod"))) { $isRepo = "yes" }

function Row([string]$label, [string]$found) {
  if ($found) { "  [x] {0,-14} {1}" -f $label, $found }
  else        { "  [ ] {0,-14} (missing)" -f $label }
}

Write-Output "AgentMaster Scaffold - $Name"
Write-Output "==============================================="
Write-Output "Directory: $Target   (code repo: $isRepo)"
Write-Output ""
Write-Output "Canonical doc spine:"
Write-Output (Row "README.md"     $R_README)
Write-Output (Row "AGENTS.md"     $R_AGENTS)
Write-Output (Row "CLAUDE.md"     $R_CLAUDE)
Write-Output (Row "PROJECTLOG.md" $R_PLOG)

$missing = @($R_README,$R_AGENTS,$R_CLAUDE,$R_PLOG | Where-Object { $_ -eq "" }).Count
Write-Output ""
if ($missing -eq 0) { Write-Output "All four canonical files present. Nothing to scaffold."; exit 0 }

function WriteTmpl([string]$tmpl, [string]$out) {
  $src = Join-Path $TmplDir $tmpl
  $dst = Join-Path $Target $out
  if (Test-Path $dst) { Write-Output "  skip $out (exists)"; return }
  if (-not (Test-Path $src)) { Write-Output "  ERR  template $tmpl not found"; return }
  $content = (Get-Content -LiteralPath $src -Raw -Encoding utf8).Replace("{{PROJECT_NAME}}", $Name).Replace("{{DATE}}", $Date)
  [System.IO.File]::WriteAllText($dst, $content, $Utf8)
  Write-Output "  +    $out"
}

if ($Mode -ne "apply") {
  Write-Output "$missing file(s) missing. To create them from templates (in your format):"
  Write-Output "    /agent-master scaffold apply"
  Write-Output "  (adds only what's missing; never overwrites. Add -WithRules for RULES.md.)"
  exit 0
}

function Detect-Stack {
  $pj = Join-Path $Target "package.json"
  if (Test-Path $pj) {
    $s = "Node.js"; $c = Get-Content -LiteralPath $pj -Raw -Encoding utf8
    if ($c -match '"next"')    { $s += " / Next.js" }
    if ($c -match '"react"')   { $s += " / React" }
    if ($c -match '"express"') { $s += " / Express" }
    if ($c -match '"vite"')    { $s += " / Vite" }
    return $s
  } elseif ((Test-Path (Join-Path $Target "pyproject.toml")) -or (Test-Path (Join-Path $Target "requirements.txt"))) { return "Python" }
  elseif (Test-Path (Join-Path $Target "go.mod"))    { return "Go" }
  elseif (Test-Path (Join-Path $Target "Cargo.toml")) { return "Rust" }
  return ""
}

Write-Output "Creating missing files..."
if (-not $R_AGENTS) { WriteTmpl "AGENTS.md.tmpl" "AGENTS.md" }
if (-not $R_CLAUDE) { WriteTmpl "CLAUDE.md.tmpl" "CLAUDE.md" }
if (-not $R_PLOG)   { WriteTmpl "PROJECTLOG.md.tmpl" "PROJECTLOG.md" }
if (-not $R_README) { WriteTmpl "README.md.tmpl" "README.md" }
if ($WithRules)     { WriteTmpl "RULES.md.tmpl" "RULES.md" }

# Pre-fill AGENTS.md's Stack with what we can infer.
$agentsPath = Join-Path $Target "AGENTS.md"
if (-not $R_AGENTS -and (Test-Path $agentsPath)) {
  $stack = Detect-Stack
  if ($stack) {
    $lines = Get-Content -LiteralPath $agentsPath -Encoding utf8
    $out = foreach ($l in $lines) {
      $l
      if ($l -eq "## Stack") { "- **Detected**: $stack  <!-- auto-detected from project files; verify & complete -->" }
    }
    [System.IO.File]::WriteAllText($agentsPath, (($out -join "`n") + "`n"), $Utf8)
    Write-Output "  ~    AGENTS.md Stack pre-filled: $stack"
  }
}
Write-Output ""
Write-Output "Done. Fill in the TODO sections - start with AGENTS.md and PROJECTLOG.md."
