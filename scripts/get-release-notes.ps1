[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$changelog = Join-Path $projectRoot 'CHANGELOG.md'
$version = $Version.TrimStart('v')
$escaped = [Regex]::Escape($version)
$lines = Get-Content -LiteralPath $changelog -Encoding utf8
$start = -1
for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match "^##\s+\[?$escaped\]?(?:\s+-.*)?$") {
        $start = $index
        break
    }
}
if ($start -lt 0) {
    throw "CHANGELOG.md has no section for $version"
}
$end = $lines.Count
for ($index = $start + 1; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^##\s+') {
        $end = $index
        break
    }
}
$body = ($lines[($start + 1)..($end - 1)] -join "`n").Trim()
if (!$body) {
    throw "CHANGELOG.md section $version is empty"
}
if ($OutputPath) {
    $resolved = [System.IO.Path]::GetFullPath($OutputPath)
    [System.IO.File]::WriteAllText(
        $resolved,
        "$body`n",
        [System.Text.UTF8Encoding]::new($false)
    )
} else {
    Write-Output $body
}
