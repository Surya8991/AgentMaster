# Shared installer/updater staged replacement and provenance.
# Two renames leave a brief visibility gap; rollback restores the old directory.
$script:LifecycleSeen = @{}
$script:LifecycleRepos = @{}
function Add-LifecycleSeen($Repo, $Skill) { $script:LifecycleSeen["$Repo=$Skill"] = $true }
function Add-LifecycleRepo($Repo) { $script:LifecycleRepos[$Repo] = $true }
function Get-LifecycleHash($Directory) {
    $root = [IO.Path]::GetFullPath($Directory).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $rows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
        $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
        $hash = & git hash-object -- $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Cannot hash $($file.FullName)" }
        # Hex UTF-8 keys match Bash LC_ALL=C byte ordering, including non-BMP names.
        $sortKey = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($relative)).Replace('-', '')
        $rows.Add("$sortKey`0$relative`0$hash")
    }
    $rows.Sort([StringComparer]::Ordinal)
    $text = (($rows | ForEach-Object { $parts = $_ -split "`0", 3; "$($parts[2])  $($parts[1])" }) -join "`n")
    if ($rows.Count) { $text += "`n" }
    $tempHashFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($tempHashFile, $text, (New-Object Text.UTF8Encoding($false)))
        $result = & git hash-object -- $tempHashFile
        if ($LASTEXITCODE -ne 0) { throw 'Cannot hash skill inventory' }
        return $result
    } finally { Remove-Item -LiteralPath $tempHashFile -Force }
}
function Install-LifecycleSkill($Source, $Skill, $Repo) {
    if ($Skill -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') { throw "Invalid skill name: $Skill" }
    $target = Join-Path $SkillsDir $Skill
    $ownerLine = Get-Content -LiteralPath $OwnersFile -ErrorAction SilentlyContinue | Where-Object { $_.StartsWith("$Skill=") } | Select-Object -First 1
    $previous = if ($ownerLine) { ($ownerLine -split '=', 2)[1] } else { '' }
    $overrideFile = Join-Path $CacheDir 'collisions.local'
    $override = if (Test-Path $overrideFile) { Get-Content -LiteralPath $overrideFile | Where-Object { $_ -eq "$Skill=$Repo" } } else { $null }
    if (((Test-Path -LiteralPath $target) -or $previous) -and $previous -ne $Repo -and -not $override) {
        throw "BLOCKED collision for $Skill (owner: '$previous'); override in collisions.local: $Skill=$Repo"
    }
    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Unsafe destination: $target" }
    }
    if ((Get-Item -LiteralPath $Source -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Symlink source: $Source" }
    if (Get-ChildItem -LiteralPath $Source -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw "Symlink in $Skill" }
    $stage = Join-Path $SkillsDir ('.am-stage-' + $Skill + '.' + [guid]::NewGuid())
    $backup = "$stage.previous"
    New-Item -ItemType Directory -Path $stage -ErrorAction Stop | Out-Null
    $published = $false
    try {
        Get-ChildItem -LiteralPath $Source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stage -Recurse -Force -ErrorAction Stop }
        $doc = Join-Path $stage 'SKILL.md'
        if (-not (Test-Path $doc)) { $doc = Join-Path $stage 'skill.md' }
        if (-not (Test-Path $doc)) { throw "Missing SKILL.md in $Skill" }
        $lines = @(Get-Content -LiteralPath $doc -Encoding UTF8)
        $header = @(); $closed = $false
        if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
            for ($index = 1; $index -lt $lines.Count; $index++) {
                if ($lines[$index] -eq '---') { $closed = $true; break }
                $header += $lines[$index]
            }
        }
        if (-not $closed -or -not ($header -match '^name:\s*\S') -or -not ($header -match '^description:\s*\S')) { throw "Invalid SKILL.md in $Skill" }
        $digest = Get-LifecycleHash $stage
        # Native git stderr must not become a terminating PS 5.1 error for local fixtures.
        $savedPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $url = (& git -C $Source config --get remote.origin.url 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { $url = 'local' }
        $commit = (& git -C $Source rev-parse HEAD 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { $commit = 'unknown' }
        $ErrorActionPreference = $savedPreference
        $provenanceDir = Join-Path $CacheDir '.provenance'
        New-Item -ItemType Directory -Path $provenanceDir -Force | Out-Null
        $metadata = "repo=$Repo`nurl=$url`ncommit=$commit`ninstalled_at=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))`nhash=$digest`n"
        [IO.File]::WriteAllText("$stage.provenance", $metadata, (New-Object Text.UTF8Encoding($false)))
        $oldOwners = [IO.File]::ReadAllBytes($OwnersFile)
        $provenancePath = Join-Path $provenanceDir "$Skill.txt"
        $oldMetadata = if (Test-Path -LiteralPath $provenancePath) { [IO.File]::ReadAllBytes($provenancePath) } else { $null }
        if (Test-Path -LiteralPath $target) { Move-Item -LiteralPath $target -Destination $backup -ErrorAction Stop }
        try { Move-Item -LiteralPath $stage -Destination $target -ErrorAction Stop }
        catch {
            if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $target -ErrorAction Stop }
            throw
        }
        $published = $true
        try {
            Move-Item -LiteralPath "$stage.provenance" -Destination $provenancePath -Force -ErrorAction Stop
            Record-Owner $Skill $Repo
        } catch {
            Remove-Item -LiteralPath $target -Recurse -Force
            if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $target }
            $published = $false
            [IO.File]::WriteAllBytes($OwnersFile, $oldOwners)
            if ($null -ne $oldMetadata) { [IO.File]::WriteAllBytes($provenancePath, $oldMetadata) }
            elseif (Test-Path -LiteralPath $provenancePath) { Remove-Item -LiteralPath $provenancePath -Force }
            throw
        }
    } finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
        if (Test-Path -LiteralPath "$stage.provenance") { Remove-Item -LiteralPath "$stage.provenance" -Force }
        if ($published -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Recurse -Force }
    }
}
function Invoke-LifecyclePrune([bool]$Apply) {
    foreach ($line in @(Get-Content -LiteralPath $OwnersFile)) {
        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) { continue }
        $skill = $parts[0]; $repo = $parts[1]
        if ($skill -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$' -or -not $script:LifecycleRepos.ContainsKey($repo) -or $script:LifecycleSeen.ContainsKey("$repo=$skill")) { continue }
        $target = Join-Path $SkillsDir $skill
        if (-not (Test-Path -LiteralPath $target -PathType Container)) { continue }
        $metadata = Join-Path $CacheDir ".provenance/$skill.txt"
        $expected = if (Test-Path $metadata) { (Get-Content -LiteralPath $metadata | Where-Object { $_ -like 'hash=*' }) -replace '^hash=', '' } else { '' }
        $links = (@(Get-Item -LiteralPath $target -Force) + @(Get-ChildItem -LiteralPath $target -Recurse -Force)) | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }
        $provenanceRepo = if (Test-Path $metadata) { (Get-Content -LiteralPath $metadata | Where-Object { $_ -like 'repo=*' }) -replace '^repo=', '' } else { '' }
        if (-not $expected -or $links -or $provenanceRepo -ne $repo) { Add-Report "${repo}: removed upstream: $skill (preserved: no trustworthy provenance)"; continue }
        if ((Get-LifecycleHash $target) -ne $expected) { Add-Report "${repo}: removed upstream: $skill (preserved: locally modified)"; continue }
        if (-not $Apply) { Add-Report "${repo}: removed upstream: $skill (use -Prune to remove)"; continue }
        Remove-Item -LiteralPath $target -Recurse -Force
        $remaining = @(Get-Content -LiteralPath $OwnersFile | Where-Object { -not $_.StartsWith("$skill=") })
        [IO.File]::WriteAllText($OwnersFile, (($remaining -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
        Remove-Item -LiteralPath $metadata -Force
        Add-Report "${repo}: pruned $skill"
    }
}
