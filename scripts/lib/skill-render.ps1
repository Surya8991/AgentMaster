# Shared PowerShell extraction and rendering. Keep output byte-identical to
# skill-render.sh: LF, UTF-8 without BOM, no timestamps.
function Get-Field([string]$file, [string]$field) {
  $inFm = $false
  foreach ($line in Get-Content -LiteralPath $file -Encoding utf8) {
    if ($line -eq '---') { if ($inFm) { break } else { $inFm = $true; continue } }
    if ($inFm -and $line -match "^$([regex]::Escape($field)):\s*(.*)$") {
      return ($matches[1] -replace '^"(.*)"$', '$1')
    }
  }
  return ''
}

function Get-Body([string]$file) {
  $c = 0; $out = New-Object System.Collections.Generic.List[string]
  foreach ($line in Get-Content -LiteralPath $file -Encoding utf8) {
    if ($line -eq '---') { $c++; continue }
    if ($c -ge 2) { $out.Add($line) }
  }
  # Bash command substitution strips trailing newlines from skill_body.
  return ($out -join "`n").TrimEnd([char]10)
}

function WriteFile([string]$path, [string]$content, [switch]$Append) {
  $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
  $dir = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $encoding = New-Object System.Text.UTF8Encoding $false
  if ($Append) { [System.IO.File]::AppendAllText($fullPath, $content, $encoding) }
  else { [System.IO.File]::WriteAllText($fullPath, $content, $encoding) }
}

function Render-Skill([string]$format, [string]$name, [string]$desc, [string]$body) {
  $yamlName = $name.Replace('"', '\"')
  $yamlDesc = $desc.Replace('"', '\"')
  switch ($format) {
    'cursor' { return "---`ndescription: `"$yamlDesc`"`nglobs:`nalwaysApply: false`n---`n$body`n" }
    'windsurf' { return "---`nname: `"$yamlName`"`ndescription: `"$yamlDesc`"`ntrigger: always_on`n---`n$body`n" }
    'cline' { return "$body`n" }
    'antigravity' { return "---`nname: `"$yamlName`"`ndescription: `"$yamlDesc`"`nrisk: low`nsource: community`n---`n$body`n" }
    'opencode' { return "---`nname: `"$yamlName`"`ndescription: `"$yamlDesc`"`ncompatibility: opencode`n---`n$body`n" }
    'augment' { return "---`ntype: auto`ndescription: `"$yamlDesc`"`n---`n$body`n" }
    'aider' { return "`n---`n`n## $name`n> $desc`n`n$body`n" }
    'copilot' { return "`n## $name`n$desc`n`n$body`n" }
    default { throw "Unknown render format: $format" }
  }
}
