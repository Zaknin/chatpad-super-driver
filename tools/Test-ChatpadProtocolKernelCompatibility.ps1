[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DirectoryPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    if (-not $fullPath.EndsWith($separator)) {
        $fullPath += $separator
    }
    return $fullPath
}

function Get-FileSha256Hash {
    param([Parameter(Mandatory)][string]$Path)

    $stream = New-Object System.IO.FileStream(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read)
    try {
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try {
            return [System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '')
        }
        finally {
            $hasher.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Remove-SelectedArtifactDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$ArtifactsRoot)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    $resolvedRepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath.TrimEnd('\', '/')
    $resolvedArtifactsRoot = (Resolve-Path -LiteralPath $ArtifactsRoot).ProviderPath.TrimEnd('\', '/')
    $artifactsPrefix = $resolvedArtifactsRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedPath.Equals($resolvedRepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resolvedPath.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a directory outside artifacts/: $resolvedPath"
    }

    $relativePath = $resolvedPath.Substring($resolvedRepositoryRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $trackedFiles = @(& git -C $resolvedRepositoryRoot ls-files -- $relativePath)
    if ($LASTEXITCODE -ne 0 -or $trackedFiles.Count -ne 0) {
        throw "Refusing to remove a directory that may contain tracked files: $resolvedPath"
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Get-ProhibitedOutputPaths {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $prohibitedExtensions = @(
        '.sys', '.inf', '.cat', '.cer', '.crt', '.pfx', '.p12', '.pvk',
        '.snk', '.msi', '.msix', '.appx', '.cab', '.deploy', '.zip')
    return @(
        Get-ChildItem -LiteralPath $RepositoryRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $prohibitedExtensions -contains $_.Extension.ToLowerInvariant() } |
            ForEach-Object { $_.FullName }
    )
}

function Test-SigningExecution {
    param([Parameter(Mandatory)][string]$LogPath)

    foreach ($line in [System.IO.File]::ReadLines($LogPath)) {
        $trimmed = $line.Trim()
        if ($trimmed -match 'skipped, due to false condition') {
            continue
        }
        if ($trimmed -match '^Target "(?:DriverTestSign|DriverProductionSign|PackageTestSign|PackageProductionSign|TestSign|ProductionSign)"' -or
            $trimmed -match '^(Task|Using)\s+"?SignTask"?' -or
            $trimmed -match '\bSIGNTASK\s*:' -or
            $trimmed -match '(?i)Task Parameter:ToolExe\s*=\s*signtool\.exe' -or
            $trimmed -match '(?i)^[A-Z]:\\[^\"]*\\signtool\.exe\s') {
            return $false
        }
    }
    return $true
}

$repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRootOutput = @(& git -C $repoRoot rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or $gitRootOutput.Count -ne 1) {
    throw "Unable to locate the repository root from $PSScriptRoot."
}
$gitRoot = [System.IO.Path]::GetFullPath([string]$gitRootOutput[0])
if (-not $repoRoot.TrimEnd('\', '/').Equals($gitRoot.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Script-derived repository root does not match Git root: $repoRoot vs $gitRoot"
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$outDir = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadProtocolKernelCompileCheck'))
$intDir = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadProtocolKernelCompileCheck'))
$logsDirectory = Join-Path $artifactsRoot 'logs'
$environmentDirectory = Join-Path $artifactsRoot 'environment'
$environmentReport = Join-Path $environmentDirectory 'driver-build-environment.txt'
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$logPath = Join-Path $logsDirectory ("chatpad-protocol-kernel-compatibility-$Configuration-$timestamp.log")

New-Item -ItemType Directory -Path $logsDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $environmentDirectory -Force | Out-Null

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath -OutputPath $environmentReport 2>&1)
$detectorExitCode = $LASTEXITCODE
$detectorOutput | Write-Output
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) {
    exit $detectorExitCode
}

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) | Select-Object -Unique
$vswherePath = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $vswherePath) {
    Write-Error 'vswhere.exe was not found.'
    exit 1
}

$parsedInstallations = ConvertFrom-Json -InputObject ((@(& $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8)) -join [Environment]::NewLine)
$installations = @($parsedInstallations | ForEach-Object { $_ })
$msbuildPath = $null
foreach ($installation in ($installations | Sort-Object { [version]$_.installationVersion } -Descending)) {
    $candidate = Join-Path ([string]$installation.installationPath) 'MSBuild\Current\Bin\MSBuild.exe'
    $driverToolset = Join-Path ([string]$installation.installationPath) 'MSBuild\Microsoft\VC\v170\Platforms\x64\PlatformToolsets\WindowsKernelModeDriver10.0'
    if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and (Test-Path -LiteralPath $driverToolset -PathType Container)) {
        $msbuildPath = $candidate
        break
    }
}
if (-not $msbuildPath) {
    Write-Error 'No VS 2022 MSBuild installation with x64 WDK integration was found.'
    exit 1
}

Remove-SelectedArtifactDirectory -Path $outDir -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $intDir -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
$prohibitedBefore = @(Get-ProhibitedOutputPaths -RepositoryRoot $repoRoot)

$projectPath = Join-Path $repoRoot 'tests\kernel\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.vcxproj'
$msbuildArguments = @(
    $projectPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:RepoRoot=$repoRoot",
    "/p:OutDir=$outDir",
    "/p:IntDir=$intDir",
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$logPath;Verbosity=diagnostic;Encoding=UTF-8")

Write-Output "MSBuild: $msbuildPath"
Write-Output "Building only ChatpadProtocolKernelCompileCheck ($Configuration|$Platform)."
$buildOutput = @(& $msbuildPath @msbuildArguments 2>&1)
$msbuildExitCode = $LASTEXITCODE
$buildOutput | Write-Output
Write-Output "MSBuild exit code: $msbuildExitCode"
Write-Output "Build log: $logPath"
if ($msbuildExitCode -ne 0) {
    exit $msbuildExitCode
}

$expectedLibraryPath = Join-Path $outDir 'ChatpadProtocolKernelCompileCheck.lib'
if (-not (Test-Path -LiteralPath $expectedLibraryPath -PathType Leaf)) {
    Write-Error "Expected compatibility library not found: $expectedLibraryPath"
    exit 1
}

$artifactsPrefix = Get-DirectoryPath -Path $artifactsRoot
$generatedFiles = @(Get-ChildItem -LiteralPath @($outDir, $intDir) -Recurse -File -ErrorAction SilentlyContinue)
$escapedFiles = @($generatedFiles | Where-Object {
    -not $_.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($escapedFiles.Count -ne 0) {
    Write-Error "Compatibility output escaped artifacts/: $($escapedFiles.FullName -join ', ')"
    exit 1
}

$prohibitedAfter = @(Get-ProhibitedOutputPaths -RepositoryRoot $repoRoot)
$newProhibited = @($prohibitedAfter | Where-Object { $prohibitedBefore -notcontains $_ })
$prohibitedInProjectOutput = @($generatedFiles | Where-Object {
    $_.Extension.ToLowerInvariant() -in @('.sys', '.inf', '.cat', '.cer', '.crt', '.pfx', '.p12', '.pvk', '.snk', '.msi', '.msix', '.appx', '.cab', '.deploy', '.zip')
})
if ($newProhibited.Count -ne 0 -or $prohibitedInProjectOutput.Count -ne 0) {
    Write-Error "Prohibited driver, signing, package, installer, or deployment output was created: $(@($newProhibited + $prohibitedInProjectOutput.FullName) -join ', ')"
    exit 1
}

if (-not (Test-SigningExecution -LogPath $logPath)) {
    Write-Error 'Active signing execution was detected in the compatibility build log.'
    exit 1
}

Write-Output "Compatibility library: $expectedLibraryPath"
Write-Output "SHA-256: $(Get-FileSha256Hash -Path $expectedLibraryPath)"
Write-Output 'Signing execution scan: PASS (no SignTool or active signing task execution found).'
Write-Output 'Prohibited output scan: PASS (no .sys, INF, CAT, certificate, package, installer, or deployment output created).'
Write-Output 'Artifact containment: PASS (all compatibility outputs are beneath artifacts/).'
exit 0
