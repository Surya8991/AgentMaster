# Internal dependencies.py apply interface. Never fall back to local pins.
function Get-LockedPin([string]$Name) {
    $result = @()
    foreach ($line in ($env:AGENTMASTER_LOCK_PINS -split "`r?`n")) {
        if (-not $line) { continue }
        if ($line -notmatch '^([a-zA-Z0-9._-]+)=([a-fA-F0-9]{40}|[a-fA-F0-9]{64})$') {
            throw 'Invalid locked dependency pin'
        }
        if ($matches[1] -in @('.', '..')) { throw 'Invalid locked repo name' }
        if ($matches[1] -eq $Name) { $result += $matches[2].ToLowerInvariant() }
    }
    if ($result.Count -ne 1) { throw "Missing or duplicate locked pin: $Name" }
    return $result[0]
}

function Invoke-LockedGit([string[]]$GitArguments) {
    $previous = $ErrorActionPreference
    try {
        # Windows PowerShell treats native stderr as ErrorRecord; inspect exit code.
        $ErrorActionPreference = 'Continue'
        $output = & git @GitArguments 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Locked Git operation failed: $($output -join ' ')" }
        return $output
    } finally { $ErrorActionPreference = $previous }
}

function Set-LockedCheckout([string]$Name, [string]$Url, [string]$Path) {
    $pin = Get-LockedPin $Name
    foreach ($candidate in @($Path, (Join-Path $Path '.git'))) {
        $item = Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Locked cache must not be a reparse point: $Name" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path '.git'))) {
        if (Test-Path -LiteralPath $Path) { throw "Locked cache is not a Git repo: $Name" }
        Invoke-LockedGit @('clone', '--no-checkout', '--quiet', $Url, $Path) | Out-Null
    }
    Invoke-LockedGit @('-C', $Path, 'fetch', '--depth', '1', '--quiet', $Url, $pin) | Out-Null
    Invoke-LockedGit @('-C', $Path, 'checkout', '--detach', '--force', '--quiet', $pin) | Out-Null
    Invoke-LockedGit @('-C', $Path, 'clean', '-fdxq') | Out-Null
    Assert-LockedCheckout $Name $Path
    Invoke-LockedGit @('-C', $Path, 'remote', 'set-url', 'origin', $Url) | Out-Null
}

function Assert-LockedCheckout([string]$Name, [string]$Path) {
    $pin = Get-LockedPin $Name
    $actual = Invoke-LockedGit @('-C', $Path, 'rev-parse', 'HEAD')
    if ($actual -ne $pin) { throw "Locked HEAD mismatch: $Name" }
}

function Initialize-LockedDependencies {
    foreach ($entry in Read-Manifest) {
        $parts = $entry -split '\|'
        if (Test-RepoInProfile $parts[0]) { Get-LockedPin $parts[0] | Out-Null }
    }
    foreach ($entry in Read-Manifest) {
        $parts = $entry -split '\|'
        if (-not (Test-RepoInProfile $parts[0])) { continue }
        $path = Join-Path $CacheDir $parts[0]
        Set-LockedCheckout $parts[0] $parts[1] $path
        if (-not (Test-Path -LiteralPath (Join-Path $path $parts[2]))) { throw "Locked skill source missing: $($parts[0])/$($parts[2])" }
    }
}
