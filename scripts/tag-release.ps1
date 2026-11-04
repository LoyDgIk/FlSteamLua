[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [string]$Remote = 'origin',
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $projectRoot
try {
    $version = $Version.TrimStart('v')
    $manifest = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*([^+\s]+)'
    if (!$manifest) { throw 'pubspec.yaml has no version.' }
    if ($manifest.Matches[0].Groups[1].Value -ne $version) {
        throw "Tag version $version does not match pubspec.yaml."
    }
    & (Join-Path $PSScriptRoot 'get-release-notes.ps1') -Version $version | Out-Null
    if ((git status --porcelain).Length -gt 0) {
        throw 'Commit or discard working-tree changes before tagging a release.'
    }
    $tag = "v$version"
    git rev-parse --verify $tag 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "Tag $tag already exists." }
    git tag -a $tag -m "FlSteamLua $version"
    if ($LASTEXITCODE -ne 0) { throw "Could not create tag $tag." }
    if (!$NoPush) {
        git push $Remote $tag
        if ($LASTEXITCODE -ne 0) { throw "Could not push tag $tag to $Remote." }
    }
} finally {
    Pop-Location
}
