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

$repoRoot = Split-Path -Parent $PSScriptRoot
$solutionPath = Join-Path $repoRoot 'ChatpadWin11.sln'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$environmentDirectory = Join-Path $artifactsRoot 'environment'
$logsDirectory = Join-Path $artifactsRoot 'logs'
$environmentReport = Join-Path $environmentDirectory 'driver-build-environment.txt'
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$logPath = Join-Path $logsDirectory ("build-{0}-{1}-{2}.log" -f $Configuration.ToLowerInvariant(), $Platform.ToLowerInvariant(), $timestamp)

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
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$logPath;Verbosity=diagnostic;Encoding=UTF-8"
)

Write-Output "Building $Configuration|$Platform with MSBuild."
& $msbuildPath @arguments
$msbuildExitCode = $LASTEXITCODE
Write-Output "MSBuild exit code: $msbuildExitCode"
Write-Output "Log: $logPath"
exit $msbuildExitCode
