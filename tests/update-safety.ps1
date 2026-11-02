# Focused updater helpers, extracted without running the entry point.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$taskRoot = Join-Path ([IO.Path]::GetTempPath()) ('agentmaster-update-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $taskRoot | Out-Null
try {
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $repo 'scripts/update.ps1'), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
    foreach ($name in @('Remove-OwnedLock', 'Get-UpdateLock', 'Copy-Skill')) {
        $functionAst = $ast.FindAll({param($item) $item -is [Management.Automation.Language.FunctionDefinitionAst]}, $true) | Where-Object Name -eq $name
        Invoke-Expression $functionAst.Extent.Text
    }
    . (Join-Path $repo 'scripts/lib/skill-lifecycle.ps1')
    $CacheDir = Join-Path $taskRoot 'cache'
    New-Item -ItemType Directory -Path $CacheDir | Out-Null
    $OwnersFile = Join-Path $CacheDir '.skill-owners'
    [IO.File]::WriteAllText($OwnersFile, '')
    $LockFile = Join-Path $taskRoot 'lock'
    $LockOwner = "powershell:$PID"
    if (-not (Get-UpdateLock)) { throw 'Cannot acquire empty lock' }
    (Get-Item $LockFile).LastWriteTime = [datetime]'2000-01-01'
    if (Get-UpdateLock) { throw 'Took a live lock' }
    Remove-OwnedLock
    # Start a short-lived process, then use its known exited PID.
    $startArgs = @{ FilePath = (Get-Process -Id $PID).Path; ArgumentList = @('-NoProfile', '-Command', 'exit 0'); PassThru = $true }
    if ($env:OS -eq 'Windows_NT') { $startArgs.WindowStyle = 'Hidden' }
    $process = Start-Process @startArgs
    $process.WaitForExit()
    [IO.File]::WriteAllText($LockFile, "powershell:$($process.Id)")
    if (-not (Get-UpdateLock)) { throw 'Cannot reclaim dead owner' }
    Remove-OwnedLock
    [IO.File]::WriteAllText($LockFile, 'bash:123')
    if (Get-UpdateLock) { throw 'Took a foreign lock' }
    [IO.File]::WriteAllText($LockFile, '')
    if (Get-UpdateLock) { throw 'Took a legacy lock' }
    Remove-Item -LiteralPath $LockFile
    $source = Join-Path $taskRoot 'source'
    $SkillsDir = Join-Path $taskRoot 'installed'
    New-Item -ItemType Directory -Path $source, $SkillsDir | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $source 'scripts') | Out-Null
    [IO.File]::WriteAllText((Join-Path $source 'scripts/helper'), 'helper')
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), "---`nname: sample`ndescription: test`n---`nnew")
    [IO.File]::WriteAllText((Join-Path $source '.hidden'), 'hidden')
    $script:SyncFailures = 0
    $script:owners = @()
    function Record-Owner($Skill, $Repo) { $script:owners += "$Skill=$Repo"; Add-Content -LiteralPath $OwnersFile -Value "$Skill=$Repo" }
    function Add-Report($Line) { Write-Host $Line }
    if (-not (Copy-Skill $source sample repo)) { throw 'Initial copy failed' }
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), "---`nname: sample`ndescription: test`n---`nchanged")
    if (-not (Copy-Skill $source sample repo)) { throw 'Repeat copy failed' }
    if ([IO.File]::ReadAllText((Join-Path $SkillsDir 'sample/SKILL.md')) -notmatch 'changed$') { throw 'Repeat copy did not update root' }
    if (-not (Test-Path (Join-Path $SkillsDir 'sample/.hidden'))) { throw 'Lost hidden file' }
    if (Test-Path (Join-Path $SkillsDir 'sample/source')) { throw 'Nested copy' }
    if ([IO.File]::ReadAllText((Join-Path $SkillsDir 'sample/scripts/helper')) -ne 'helper') { throw 'Lost support file' }
    if (Test-Path (Join-Path $SkillsDir 'sample/scripts/scripts')) { throw 'Nested support directory' }
    $ownerCount = $script:owners.Count
    [IO.File]::WriteAllText((Join-Path $SkillsDir 'broken'), 'blocked')
    if (Copy-Skill $source broken other) { throw 'Copy unexpectedly succeeded' }
    if ($script:SyncFailures -ne 1 -or $script:owners.Count -ne $ownerCount) { throw 'Failure changed ownership/count' }
    Write-Host 'PASS: PowerShell updater locks, repeat copies, and failed-copy ownership'
    # Exercise the real completion path, replacing only machine paths and network self-update.
    $fixture = Join-Path $taskRoot 'full'
    $fixtureCache = Join-Path $fixture 'cache'
    $fixtureSkills = Join-Path $fixture 'skills'
    $brokenSource = Join-Path $fixtureCache 'agent-master/skills/broken'
    New-Item -ItemType Directory -Path $brokenSource, $fixtureSkills -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $brokenSource 'SKILL.md'), "---`nname: broken`ndescription: test`n---`nskill body")
    [IO.File]::WriteAllText((Join-Path $fixtureSkills 'broken'), 'blocked')
    [IO.File]::WriteAllText((Join-Path $fixtureCache 'agent-master/repos.manifest'), '')
    $entry = [IO.File]::ReadAllText((Join-Path $repo 'scripts/update.ps1'))
    $entry = [regex]::Replace($entry, '(?m)^\$SkillsDir = .*$', {param($match) '$SkillsDir = ' + "'" + $fixtureSkills.Replace("'", "''") + "'"})
    $entry = [regex]::Replace($entry, '(?m)^\$CacheDir = .*$', {param($match) '$CacheDir = ' + "'" + $fixtureCache.Replace("'", "''") + "'"})
    $networkStart = $entry.IndexOf('    # Self-update first')
    $networkEnd = $entry.IndexOf('    # Unknown-profile guard', $networkStart)
    $entry = $entry.Substring(0, $networkStart) + '    $amCache = Join-Path $CacheDir "agent-master"' + "`n" + $entry.Substring($networkEnd)
    New-Item -ItemType Directory -Path (Join-Path $fixture 'lib') | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'scripts/lib/skill-lifecycle.ps1') -Destination (Join-Path $fixture 'lib')
    $entryPath = Join-Path $fixture 'update.ps1'
    [IO.File]::WriteAllText($entryPath, $entry)
    $engine = (Get-Process -Id $PID).Path
    & $engine -NoProfile -ExecutionPolicy Bypass -File $entryPath -Quiet
    if ($LASTEXITCODE -ne 1) { throw 'Full update must fail on copy failure' }
    if ([IO.File]::ReadAllText((Join-Path $fixtureCache 'last-sync-report.txt')) -notmatch 'Sync incomplete: 1 copy failures') { throw 'Missing failure report' }
    if (Test-Path (Join-Path $fixtureCache '.last-update')) { throw 'Failure advanced cooldown' }
    if ((Get-Item (Join-Path $fixtureCache '.skill-owners')).Length) { throw 'Failure recorded ownership' }
    if (Test-Path (Join-Path $fixtureCache '.update-lock')) { throw 'Failure leaked lock' }
    Remove-Item -LiteralPath (Join-Path $fixtureSkills 'broken')
    & $engine -NoProfile -ExecutionPolicy Bypass -File $entryPath -Quiet
    if ($LASTEXITCODE -ne 0) { throw 'Retry failed' }
    if (-not (Test-Path (Join-Path $fixtureCache '.last-update'))) { throw 'Success did not advance cooldown' }
    Write-Host 'PASS: full PowerShell updater failure report, exit status, cooldown, and retry'

} finally {
    $resolved = [IO.Path]::GetFullPath($taskRoot)
    if ((Split-Path $resolved -Parent) -ne ([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
