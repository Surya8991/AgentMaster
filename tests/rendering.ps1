# No-network integration tests. All generated files stay in an isolated temp repo.
param([string]$Bash = 'bash')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('agentmaster-render-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$encoding = New-Object System.Text.UTF8Encoding $false

function Get-OutputHashes {
  $result = @{}
  foreach ($path in @('.cursor', '.windsurf', '.clinerules', '.codex', '.gemini', '.antigravity', '.opencode', '.augment', 'CONVENTIONS.md', '.github')) {
    Get-ChildItem -LiteralPath (Join-Path $testRoot $path) -Recurse -File -Force | ForEach-Object {
      $result[$_.FullName.Substring($testRoot.Length)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
  }
  return $result
}

function Assert-Hashes($expected, $actual, [string]$label) {
  if ($expected.Count -ne $actual.Count) { throw "$label file count differs" }
  foreach ($key in $expected.Keys) {
    if ($expected[$key] -ne $actual[$key]) { throw "${label}: output differs: $key" }
  }
  Write-Output "PASS $label ($($actual.Count) files)"
}

try {
  Copy-Item -LiteralPath (Join-Path $repo 'scripts') -Destination $testRoot -Recurse
  Copy-Item -LiteralPath (Join-Path $repo 'skills') -Destination $testRoot -Recurse
  $fixtureDir = Join-Path $testRoot 'skills/render-fixture'
  New-Item -ItemType Directory -Path $fixtureDir | Out-Null
  # Quotes, Unicode, trailing blank lines and multiple aggregate entries catch
  # escaping, BOM, encoding and newline differences between Windows and Linux.
  $fixture = '---' + "`n" + 'name: render-fixture' + "`n" + 'description: Say "hello" to caf' + [char]0xe9 + "`n---`n`n# Fixture`n`nBody`n`n`n"
  [System.IO.File]::WriteAllText((Join-Path $fixtureDir 'SKILL.md'), $fixture, $encoding)
  Push-Location $testRoot
  try {
    & $Bash scripts/convert.sh --all | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Bash converter failed' }
    $baseline = Get-OutputHashes
    & (Join-Path $testRoot 'scripts/convert.ps1') -All | Out-Null
    Assert-Hashes $baseline (Get-OutputHashes) 'Bash/PowerShell byte parity'
    & (Join-Path $testRoot 'scripts/convert.ps1') -All | Out-Null
    Assert-Hashes $baseline (Get-OutputHashes) 'PowerShell determinism'
    # Project-local installer paths only; never touch the real user profile.
    foreach ($platform in @('cursor', 'windsurf', 'cline', 'augment')) {
      & (Join-Path $testRoot 'scripts/install-platform.ps1') -Platform $platform | Out-Null
    }
    Assert-Hashes $baseline (Get-OutputHashes) 'Installer/converter parity'
  } finally { Pop-Location }
} finally {
  # Only remove the exact unique temp directory allocated by this test.
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  if ((Split-Path $resolved -Parent).TrimEnd('\', '/') -ne ([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')) {
    throw "Unsafe test cleanup path: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
