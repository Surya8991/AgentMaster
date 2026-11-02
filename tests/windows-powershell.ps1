# Real Windows PowerShell 5.1 execution, using isolated projects/install roots.
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSEdition -ne 'Desktop') {
  throw 'Run this suite with Windows PowerShell 5.1 (powershell.exe).'
}
$repo = Split-Path -Parent $PSScriptRoot
$engine = (Get-Process -Id $PID).Path
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('agentmaster-windows-' + [guid]::NewGuid().ToString('N'))
$utf8 = New-Object System.Text.UTF8Encoding $false
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Assert([bool]$condition, [string]$message) {
  if (-not $condition) { throw $message }
}

function Run-Script([string]$path, [string[]]$scriptArguments = @()) {
  & $engine -NoProfile -ExecutionPolicy Bypass -File $path @scriptArguments | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "$path failed with exit code $LASTEXITCODE" }
}

try {
  # Parse from disk with the legacy decoder: reading UTF-8 explicitly before
  # parsing would hide the BOM-free script encoding regression this catches.
  $sources = @(Get-ChildItem -LiteralPath $repo -Filter '*.ps1' -File)
  foreach ($dir in @('scripts', 'tests')) {
    $sources += Get-ChildItem -LiteralPath (Join-Path $repo $dir) -Filter '*.ps1' -File -Recurse
  }
  foreach ($source in $sources) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($source.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) { throw "$($source.Name): $($errors -join '; ')" }
  }
  Write-Output "PASS Windows PowerShell parses $($sources.Count) source scripts"

  $project = Join-Path $testRoot 'project'
  New-Item -ItemType Directory -Path $project | Out-Null
  $scaffold = Join-Path $repo 'scripts/scaffold.ps1'
  Push-Location $project
  try {
    Run-Script $scaffold
    Assert ((Get-ChildItem -Force | Measure-Object).Count -eq 0) 'Scaffold report mode wrote files'
    $projectName = 'caf' + [char]0xe9
    [System.IO.File]::WriteAllText((Join-Path $project 'package.json'), ('{"name":"' + $projectName + '","dependencies":{"react":"*"}}'), $utf8)
    Run-Script $scaffold @('apply', '-WithRules')
    foreach ($file in @('README.md', 'AGENTS.md', 'CLAUDE.md', 'PROJECTLOG.md', 'RULES.md')) {
      Assert (Test-Path -LiteralPath $file) "Scaffold did not create $file"
    }
    $agents = [System.IO.File]::ReadAllText((Join-Path $project 'AGENTS.md'), $utf8)
    Assert ($agents.Contains('# ' + $projectName + ' ' + [char]0x2014 + ' Agent Context')) 'Scaffold corrupted UTF-8 project/template text'
    Assert ($agents.Contains('Node.js / React')) 'Scaffold missed stack detection'
    Assert (([System.IO.File]::ReadAllText((Join-Path $project 'CLAUDE.md'), $utf8)).Trim() -eq '@AGENTS.md') 'Scaffold produced invalid CLAUDE pointer'
    $before = (Get-FileHash -LiteralPath 'AGENTS.md').Hash
    Run-Script $scaffold @('apply')
    Assert ((Get-FileHash -LiteralPath 'AGENTS.md').Hash -eq $before) 'Scaffold overwrote existing content'
  } finally { Pop-Location }
  Write-Output 'PASS scaffold report/apply, UTF-8 preservation, stack detection and no-overwrite'

  $fixtureRepo = Join-Path $testRoot 'repo'
  $install = Join-Path $testRoot 'install'
  New-Item -ItemType Directory -Path $fixtureRepo | Out-Null
  foreach ($item in @('scripts', 'skills', 'repos.manifest', 'profiles.manifest', 'repos.pins', 'AGENTS.md')) {
    Copy-Item -LiteralPath (Join-Path $repo $item) -Destination $fixtureRepo -Recurse
  }
  $devSync = Join-Path $fixtureRepo 'scripts/dev-sync.ps1'
  Run-Script $devSync @('-InstallRoot', $install)
  $marker = Join-Path $install '.agentmaster-cache/.dev'
  Assert (Test-Path -LiteralPath $marker) 'Dev sync did not enable dev mode'
  $installedSkill = Join-Path $install 'skills/agent-master/SKILL.md'
  $sourceSkill = Join-Path $fixtureRepo 'skills/agent-master/SKILL.md'
  Assert ((Get-FileHash -LiteralPath $installedSkill).Hash -eq (Get-FileHash -LiteralPath $sourceSkill).Hash) 'Dev sync changed skill bytes'
  Assert (Test-Path -LiteralPath (Join-Path $install '.agentmaster-cache/agent-master/scripts/lib/skill-render.ps1')) 'Dev sync omitted shared renderer'
  $stale = Join-Path $install 'skills/agent-master/obsolete.txt'
  [System.IO.File]::WriteAllText($stale, 'old', $utf8)
  Run-Script $devSync @('-InstallRoot', $install)
  Assert (-not (Test-Path -LiteralPath $stale)) 'Dev sync retained obsolete skill content'
  Run-Script $devSync @('-Off', '-InstallRoot', $install)
  Assert (-not (Test-Path -LiteralPath $marker)) 'Dev sync -Off retained its marker'
  Assert (Test-Path -LiteralPath $installedSkill) 'Dev sync -Off deleted installed skills'
  Write-Output 'PASS isolated dev sync, repeat sync and dev mode off'
} finally {
  $resolved = [System.IO.Path]::GetFullPath($testRoot)
  if ((Split-Path $resolved -Parent).TrimEnd('\', '/') -ne ([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')) {
    throw "Unsafe test cleanup path: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
