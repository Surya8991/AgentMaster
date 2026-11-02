$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'scripts/lib/skill-lifecycle.ps1')
$taskRoot = Join-Path ([IO.Path]::GetTempPath()) ('agentmaster-lifecycle-' + [guid]::NewGuid())
$CacheDir = Join-Path $taskRoot 'cache'; $SkillsDir = Join-Path $taskRoot 'skills'
$OwnersFile = Join-Path $CacheDir '.skill-owners'; $source = Join-Path $taskRoot 'source'
New-Item -ItemType Directory -Path $CacheDir, $SkillsDir, (Join-Path $source 'scripts') -Force | Out-Null
[IO.File]::WriteAllText($OwnersFile, '')
function Add-Report($Line) { Write-Host $Line }
function Record-Owner($Skill, $Repo) {
    $lines = @(Get-Content -LiteralPath $OwnersFile | Where-Object { -not $_.StartsWith("$Skill=") }) + "$Skill=$Repo"
    [IO.File]::WriteAllText($OwnersFile, ($lines -join "`n") + "`n")
}
function Assert-Fails([scriptblock]$Action) {
    $failed = $false
    try { & $Action } catch { $failed = $true }
    if (-not $failed) { throw 'Expected failure' }
}
$valid = "---`nname: sample`ndescription: test`n---`nbody"
try {
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), $valid)
    [IO.File]::WriteAllText((Join-Path $source 'scripts/old'), 'old')
    Install-LifecycleSkill $source sample alpha
    if (-not (Test-Path (Join-Path $CacheDir '.provenance/sample.txt'))) { throw 'Missing provenance' }
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    if ([IO.File]::ReadAllText($OwnersFile).Trim() -ne 'sample=alpha') { throw 'Collision changed ownership' }
    [IO.File]::WriteAllText((Join-Path $CacheDir 'collisions.local'), 'sample=beta')
    Install-LifecycleSkill $source sample beta
    Remove-Item -LiteralPath (Join-Path $source 'scripts/old')
    [IO.File]::WriteAllText((Join-Path $source 'scripts/new'), 'new')
    Install-LifecycleSkill $source sample beta
    if (Test-Path (Join-Path $SkillsDir 'sample/scripts/old')) { throw 'Stale support file remains' }
    [IO.File]::WriteAllText((Join-Path $SkillsDir 'sample/scripts/new'), 'preserved')
    $previousMetadata = [IO.File]::ReadAllText((Join-Path $CacheDir '.provenance/sample.txt'))
    function Move-Item {
        [CmdletBinding()]
        param([string]$LiteralPath, [string]$Destination, [switch]$Force)
        if ($LiteralPath -like '*.am-stage-sample.*' -and $LiteralPath -notlike '*.previous' -and $Destination -eq (Join-Path $SkillsDir 'sample')) { throw 'Injected rename failure' }
        Microsoft.PowerShell.Management\Move-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force
    }
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    Remove-Item Function:\Move-Item
    if ([IO.File]::ReadAllText((Join-Path $SkillsDir 'sample/scripts/new')) -ne 'preserved') { throw 'Rollback lost previous skill' }
    if ([IO.File]::ReadAllText((Join-Path $CacheDir '.provenance/sample.txt')) -ne $previousMetadata) { throw 'Failure changed provenance' }
    $savedOwner = (Get-Item Function:\Record-Owner).ScriptBlock
    function Record-Owner { [IO.File]::WriteAllText($OwnersFile, 'corrupt'); throw 'Injected ownership failure' }
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    Set-Item Function:\Record-Owner -Value $savedOwner
    if ([IO.File]::ReadAllText((Join-Path $SkillsDir 'sample/scripts/new')) -ne 'preserved') { throw 'Ownership failure lost previous skill' }
    if ([IO.File]::ReadAllText($OwnersFile).Trim() -ne 'sample=beta') { throw 'Ownership failure corrupted registry' }
    if ([IO.File]::ReadAllText((Join-Path $CacheDir '.provenance/sample.txt')) -ne $previousMetadata) { throw 'Ownership failure changed provenance' }
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), 'invalid')
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), "---`nother: value`n---`nname: sample`ndescription: body only")
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), "---`nname: sample`ndescription: missing closing delimiter")
    Assert-Fails { Install-LifecycleSkill $source sample beta }
    if ([IO.File]::ReadAllText((Join-Path $SkillsDir 'sample/scripts/new')) -ne 'preserved') { throw 'Malformed header changed installed skill' }
    Add-LifecycleRepo beta
    Invoke-LifecyclePrune $true
    if (-not (Test-Path (Join-Path $SkillsDir 'sample'))) { throw 'Pruned modified skill' }
    [IO.File]::WriteAllText((Join-Path $source 'SKILL.md'), $valid)
    Install-LifecycleSkill $source sample beta
    Invoke-LifecyclePrune $false
    if (-not (Test-Path (Join-Path $SkillsDir 'sample'))) { throw 'Pruned without opt-in' }
    Add-LifecycleSeen beta sample
    Invoke-LifecyclePrune $true
    if (-not (Test-Path (Join-Path $SkillsDir 'sample'))) { throw 'Pruned skill seen in another subset' }
    $script:LifecycleSeen = @{}
    Invoke-LifecyclePrune $true
    if (Test-Path (Join-Path $SkillsDir 'sample')) { throw 'Did not prune unchanged removed skill' }
    $unicodeDir = Join-Path $taskRoot 'unicode'
    New-Item -ItemType Directory -Path $unicodeDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $unicodeDir ([string][char]0xE000 + '.txt')), 'one')
    [IO.File]::WriteAllText((Join-Path $unicodeDir ([char]::ConvertFromUtf32(0x10000) + '.txt')), 'two')
    if ((Get-LifecycleHash $unicodeDir) -ne '9fa6732b91070cc091259c2467561c884bbfa5b6') { throw 'Unicode provenance hash differs from Bash' }
    Write-Host 'PASS: PowerShell staged replacement, rollback, collisions, provenance, and safe opt-in prune'
} finally {
    $resolved = [IO.Path]::GetFullPath($taskRoot)
    if ((Split-Path $resolved -Parent) -ne ([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
