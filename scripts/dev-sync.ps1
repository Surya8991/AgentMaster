# AgentMaster Dev Sync (PowerShell) — push the LOCAL working tree straight to the
# live install, bypassing git, while iterating on skills/scripts.
#
# Usage:
#   powershell -File scripts\dev-sync.ps1          # sync working tree -> live, dev mode on
#   powershell -File scripts\dev-sync.ps1 -Off     # remove the .dev marker (resume auto-update)
param([switch]$Off)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir   = Split-Path -Parent $ScriptDir
$SkillsDir = Join-Path $HOME ".claude\skills"
$CacheDir  = Join-Path $HOME ".claude\.agentmaster-cache"
$AmCache   = Join-Path $CacheDir "agent-master"
$DevMarker = Join-Path $CacheDir ".dev"

if ($Off) {
  Remove-Item -Force -ErrorAction SilentlyContinue $DevMarker
  Write-Output "Dev mode OFF — the auto-updater will resume pulling remote on the next session."
  exit 0
}

New-Item -ItemType Directory -Force -Path $SkillsDir, $AmCache | Out-Null

# 1. Local skills -> live install
$count = 0
Get-ChildItem -Directory (Join-Path $RepoDir "skills") | ForEach-Object {
  if (Test-Path (Join-Path $_.FullName "SKILL.md")) {
    $dst = Join-Path $SkillsDir $_.Name
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    Copy-Item -Recurse -Force $_.FullName $dst
    $count++
  }
}
Write-Output "Synced $count AgentMaster skill(s) -> $SkillsDir"

# 2. Local repo -> self-update cache
foreach ($item in @("skills","scripts","repos.manifest","profiles.manifest","repos.pins","agents.md")) {
  $src = Join-Path $RepoDir $item
  if (Test-Path $src) {
    $dst = Join-Path $AmCache $item
    if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
    Copy-Item -Recurse -Force $src $dst
  }
}
Write-Output "Synced working tree -> $AmCache"

# 3. Enable dev mode
[string][int][double]::Parse((Get-Date -UFormat %s)) | Set-Content -Path $DevMarker -Encoding utf8
Write-Output "Dev mode ON (.dev marker written) — the auto-updater will NOT overwrite local edits."
Write-Output "Run 'powershell -File scripts\dev-sync.ps1 -Off' to resume normal auto-update."
