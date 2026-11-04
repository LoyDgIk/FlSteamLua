[CmdletBinding()]
param(
    [switch]$SkipChecks,
    [string]$InnoCompiler,
    [string]$CMake,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outputDirectory = Join-Path $projectRoot 'dist'
$releaseDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$bridgeSource = Join-Path $projectRoot 'native\steam_bridge'
$bridgeBuild = Join-Path $projectRoot 'build\steam_bridge'

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE"
    }
}

function Find-Compiler {
    param([string]$Explicit, [string]$Command, [string[]]$Candidates)
    if ($Explicit) {
        if (!(Test-Path -LiteralPath $Explicit -PathType Leaf)) {
            throw "Compiler does not exist: $Explicit"
        }
        return [System.IO.Path]::GetFullPath($Explicit)
    }
    $found = Get-Command $Command -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw "$Command was not found; specify its compiler path explicitly."
}

Push-Location -LiteralPath $projectRoot
try {
    $versionMatch = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*([^+\s]+)'
    if (!$versionMatch) { throw 'pubspec.yaml has no version.' }
    $manifestVersion = $versionMatch.Matches[0].Groups[1].Value
    $version = if ($Version) { $Version.TrimStart('v') } else { $manifestVersion }
    if ($version -ne $manifestVersion) {
        throw "Release version $version does not match pubspec.yaml $manifestVersion."
    }
    $inno = Find-Compiler -Explicit $InnoCompiler -Command 'ISCC.exe' -Candidates @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    )
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $cmakeCandidates = @()
    $vsRoot = $null
    if (Test-Path -LiteralPath $vswhere) {
        $vsRoot = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vsRoot) {
            $cmakeCandidates += Join-Path $vsRoot 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
        }
    }
    $cmakeCommand = Find-Compiler -Explicit $CMake -Command 'cmake.exe' -Candidates $cmakeCandidates
    Invoke-Checked -Program 'flutter' -Arguments @('--suppress-analytics', 'pub', 'get')
    if (!$SkipChecks) {
        Invoke-Checked -Program 'flutter' -Arguments @('--suppress-analytics', 'analyze')
    }
    $buildArguments = @(
        '--suppress-analytics',
        'build',
        'windows',
        '--release',
        "--dart-define=APP_VERSION=$version"
    )
    Invoke-Checked -Program 'flutter' -Arguments $buildArguments
    if (!$SkipChecks) {
        $previousQuickJs = $env:FLUTTER_QJS_NEXT_LIBRARY
        try {
            $env:FLUTTER_QJS_NEXT_LIBRARY = Join-Path $releaseDirectory 'flutter_qjs_next_plugin.dll'
            Invoke-Checked -Program 'flutter' -Arguments @('--suppress-analytics', 'test', '--no-pub', '--concurrency=1', '--reporter=expanded', '--timeout=60s')
        } finally {
            $env:FLUTTER_QJS_NEXT_LIBRARY = $previousQuickJs
        }
    }
    Push-Location -LiteralPath (Join-Path $projectRoot 'native\lan_transfer_engine')
    $previousCgo = $env:CGO_ENABLED
    try {
        $env:CGO_ENABLED = '0'
        if (!$SkipChecks) {
            Invoke-Checked -Program 'go' -Arguments @('test', './...')
            Invoke-Checked -Program 'go' -Arguments @('vet', './...')
        }
        Invoke-Checked -Program 'go' -Arguments @(
            'build', '-trimpath',
            '-ldflags', '-s -w -H=windowsgui',
            '-o', (Join-Path $releaseDirectory 'lan_transfer_engine.exe'),
            './cmd/lan_transfer_engine'
        )
    } finally {
        $env:CGO_ENABLED = $previousCgo
        Pop-Location
    }
    Invoke-Checked -Program 'dart' -Arguments @('--suppress-analytics', 'compile', 'exe', 'bin\steam_worker.dart', '-o', (Join-Path $releaseDirectory 'steam_worker.exe'))
    Invoke-Checked -Program $cmakeCommand -Arguments @('-S', $bridgeSource, '-B', $bridgeBuild, '-A', 'x64')
    Invoke-Checked -Program $cmakeCommand -Arguments @('--build', $bridgeBuild, '--config', 'Release')
    Copy-Item -LiteralPath (Join-Path $bridgeBuild 'Release\steam_bridge.dll') -Destination $releaseDirectory -Force
    if (!$vsRoot) { throw 'Visual Studio C++ runtime distribution directory was not found.' }
    $runtimeRoot = Join-Path $vsRoot 'VC\Redist\MSVC'
    $runtimeDirectory = Get-ChildItem -LiteralPath $runtimeRoot -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
        Select-Object -First 1
    if (!$runtimeDirectory) { throw 'Microsoft VC143 x64 app-local runtime was not found.' }
    Get-ChildItem -LiteralPath $runtimeDirectory -Filter '*.dll' -File |
        Copy-Item -Destination $releaseDirectory -Force
    foreach ($document in @('LICENSE', 'THIRD-PARTY-NOTICES.md', 'CHANGELOG.md')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $document) -Destination $releaseDirectory -Force
    }
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $zip = Join-Path $outputDirectory "FlSteamLua-$version-windows-x64.zip"
    Compress-Archive -Path (Join-Path $releaseDirectory '*') -DestinationPath $zip -Force
    Invoke-Checked -Program $inno -Arguments @(
        "/DAppVersion=$version", "/DBuildDir=$releaseDirectory", "/DOutputDir=$outputDirectory",
        (Join-Path $projectRoot 'packaging\windows\FlSteamLua.iss')
    )
    $sourceZip = Join-Path $outputDirectory "FlSteamLua-$version-source.zip"
    $sourceFiles = & git ls-files --cached --others --exclude-standard -- .github .gitignore .metadata AGENTS.md CHANGELOG.md LICENSE README.md THIRD-PARTY-NOTICES.md pubspec.yaml pubspec.lock analysis_options.yaml lib assets bin docs native packaging scripts test windows
    if ($LASTEXITCODE -ne 0 -or !$sourceFiles) { throw 'Cannot enumerate corresponding source files.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path -LiteralPath $sourceZip) { Remove-Item -LiteralPath $sourceZip }
    $archive = [System.IO.Compression.ZipFile]::Open($sourceZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $sourceFiles) {
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, (Join-Path $projectRoot $file), $file.Replace('\', '/'),
                [System.IO.Compression.CompressionLevel]::Optimal
            ) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
    $artifacts = @($zip, (Join-Path $outputDirectory "FlSteamLua-$version-windows-x64-setup.exe"), $sourceZip)
    $artifacts | Get-Item | ForEach-Object {
        $stream = [System.IO.File]::OpenRead($_.FullName)
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            $checksum = [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
        } finally {
            $algorithm.Dispose()
            $stream.Dispose()
        }
        [System.IO.File]::WriteAllText("$($_.FullName).sha256", "$checksum  $($_.Name)`n", [System.Text.UTF8Encoding]::new($false))
    }
    Write-Host "Unsigned Windows artifacts created in $outputDirectory"
} finally {
    Pop-Location
}
