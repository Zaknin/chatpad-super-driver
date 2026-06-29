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
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    $alternateSeparator = [System.IO.Path]::AltDirectorySeparatorChar.ToString()
    if (-not $fullPath.EndsWith($directorySeparator) -and -not $fullPath.EndsWith($alternateSeparator)) {
        $fullPath += $directorySeparator
    }
    return $fullPath
}

function Remove-SelectedArtifactDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$ArtifactsRoot
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    $resolvedRepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath.TrimEnd('\', '/')
    $resolvedArtifactsRoot = (Resolve-Path -LiteralPath $ArtifactsRoot).ProviderPath.TrimEnd('\', '/')
    $artifactsPrefix = $resolvedArtifactsRoot + [System.IO.Path]::DirectorySeparatorChar

    if ($resolvedPath.Equals($resolvedRepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resolvedPath.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a directory outside the repository artifacts root: $resolvedPath"
    }

    $relativePath = $resolvedPath.Substring($resolvedRepositoryRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $trackedFiles = @(& git -C $resolvedRepositoryRoot ls-files -- $relativePath)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify tracked files beneath $resolvedPath."
    }
    if ($trackedFiles.Count -gt 0) {
        throw "Refusing to remove tracked files beneath $resolvedPath."
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Get-SigningExecutionEvidence {
    param(
        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $evidence = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadLines($LogPath)) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -match 'skipped, due to false condition') {
            continue
        }

        if ($trimmedLine -match '^Target "(DriverTestSign|DriverProductionSign|PackageTestSign|PackageProductionSign|TestSign|ProductionSign)(:|")' -or
            $trimmedLine -match '^(Task|Using)\s+"?SignTask"?' -or
            $trimmedLine -match '\bSIGNTASK\s*:' -or
            $trimmedLine -match '(?i)Task Parameter:ToolExe\s*=\s*signtool\.exe' -or
            $trimmedLine -match '(?i)/c\s+"[^"]*\\signtool\.exe"' -or
            $trimmedLine -match '(?i)^"?[A-Z]:\\[^"\r\n]*\\signtool\.exe"?\s') {
            $evidence.Add($trimmedLine)
        }
    }
    return @($evidence)
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

$solutionPath = Join-Path $repoRoot 'ChatpadWin11.sln'
$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$environmentDirectory = Join-Path $artifactsRoot 'environment'
$logsDirectory = Join-Path $artifactsRoot 'logs'
$environmentReport = Join-Path $environmentDirectory 'driver-build-environment.txt'
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$logPath = Join-Path $logsDirectory ("build-{0}-{1}-{2}.log" -f $Configuration.ToLowerInvariant(), $Platform.ToLowerInvariant(), $timestamp)
$outDir = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadFilter'))
$intDir = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadFilter'))

New-Item -ItemType Directory -Path $environmentDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $logsDirectory -Force | Out-Null

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath -OutputPath $environmentReport 2>&1)
$detectorExitCode = $LASTEXITCODE

if ($detectorExitCode -ne 0) {
    $blockedLog = @(
        "Build blocked before MSBuild for $Configuration|$Platform.",
        "Environment detector exit code: $detectorExitCode",
        '',
        ($detectorOutput -join [Environment]::NewLine)
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($logPath, $blockedLog + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Output $blockedLog
    Write-Output "Log: $logPath"
    exit $detectorExitCode
}

Remove-SelectedArtifactDirectory -Path $outDir -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $intDir -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
) | Select-Object -Unique
$vswherePath = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $vswherePath) {
    [System.IO.File]::WriteAllText($logPath, 'Build blocked: vswhere.exe was not found.' + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Error 'Build blocked: vswhere.exe was not found.'
    exit 1
}

$vswhereJson = @(& $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8)
$parsedInstallations = ConvertFrom-Json -InputObject ($vswhereJson -join [Environment]::NewLine)
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
    [System.IO.File]::WriteAllText($logPath, 'Build blocked: no VS 2022 MSBuild installation with WDK integration was found.' + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    Write-Error 'Build blocked: no VS 2022 MSBuild installation with WDK integration was found.'
    exit 1
}

$arguments = @(
    $solutionPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:OutDir=$outDir",
    "/p:IntDir=$intDir",
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$logPath;Verbosity=diagnostic;Encoding=UTF-8"
)

Write-Output "Building $Configuration|$Platform with MSBuild."
& $msbuildPath @arguments
$msbuildExitCode = $LASTEXITCODE
Write-Output "MSBuild exit code: $msbuildExitCode"
Write-Output "Log: $logPath"
if ($msbuildExitCode -ne 0) {
    exit $msbuildExitCode
}

if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
    Write-Error "MSBuild returned success but the diagnostic build log does not exist: $logPath"
    exit 1
}

$signingEvidence = @(Get-SigningExecutionEvidence -LogPath $logPath)
if ($signingEvidence.Count -gt 0) {
    Write-Error ("Signing execution was detected in the build log: {0}" -f ($signingEvidence -join [Environment]::NewLine))
    exit 1
}
Write-Output 'Signing execution scan: PASS (no SignTool or active signing task execution found).'

$configurationBinRoot = [System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration)
$expectedDriverPath = [System.IO.Path]::Combine($outDir, 'ChatpadFilter.sys')
$driverOutputs = @(
    Get-ChildItem -LiteralPath $configurationBinRoot -Recurse -File -Filter 'ChatpadFilter.sys' -ErrorAction SilentlyContinue
)
if ($driverOutputs.Count -ne 1 -or
    -not $driverOutputs[0].FullName.Equals($expectedDriverPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    $actualDriverPaths = @($driverOutputs | ForEach-Object { $_.FullName })
    Write-Error ("Expected exactly one driver output at $expectedDriverPath; found: {0}" -f ($actualDriverPaths -join ', '))
    exit 1
}

$signature = Get-AuthenticodeSignature -LiteralPath $expectedDriverPath
if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::NotSigned) {
    Write-Error "Expected an unsigned driver, but Authenticode status was $($signature.Status): $expectedDriverPath"
    exit 1
}

$driverHash = Get-FileHash -LiteralPath $expectedDriverPath -Algorithm SHA256
Write-Output "Driver: $expectedDriverPath"
Write-Output "Authenticode status: $($signature.Status)"
Write-Output "SHA-256: $($driverHash.Hash)"

$safetyPath = Join-Path $PSScriptRoot 'Test-RepositorySafety.ps1'
$safetyOutput = @(& $safetyPath 2>&1)
$safetyExitCode = $LASTEXITCODE
$safetyOutput | Write-Output
if ($safetyExitCode -ne 0) {
    Write-Error "Post-build repository safety validation failed with exit code $safetyExitCode."
    exit 1
}

exit 0
