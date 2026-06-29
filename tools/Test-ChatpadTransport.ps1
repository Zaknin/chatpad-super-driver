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

trap {
    Write-Output ("FAIL: {0}" -f $_.Exception.Message)
    exit 1
}

function Get-DirectoryPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    if (-not $fullPath.EndsWith($separator)) {
        $fullPath += $separator
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
        throw "Refusing to remove a directory outside artifacts/: $resolvedPath"
    }

    $relativePath = $resolvedPath.Substring($resolvedRepositoryRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $trackedFiles = @(& git -C $resolvedRepositoryRoot ls-files -- $relativePath)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect tracked files beneath $resolvedPath."
    }
    if ($trackedFiles.Count -gt 0) {
        throw "Refusing to remove tracked files beneath $resolvedPath."
    }

    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Invoke-NativeLoggedStep {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [string]$LogPath
    )

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $outputLines = @($output | ForEach-Object {
        $item = $_
        if ($null -eq $item) { '' } else { $item.ToString() }
    })
    $outputText = $outputLines -join [Environment]::NewLine
    $section = "Step: $Name`nExit code: $exitCode`n$outputText`n"
    [System.IO.File]::AppendAllText($LogPath, $section, [System.Text.Encoding]::UTF8)
    return [pscustomobject]@{
        ExitCode = $exitCode
        OutputLines = $outputLines
        OutputText = $outputText
    }
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
    catch {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $bytes = $sha.ComputeHash($stream)
            return -join ($bytes | ForEach-Object { $_.ToString('x2') })
        }
        finally {
            $stream.Close()
        }
    }
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

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath 2>&1)
$detectorExitCode = $LASTEXITCODE
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) {
    $detectorOutput | ForEach-Object { Write-Output $_.ToString() }
    exit $detectorExitCode
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$transportObjRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadTransport'))
$transportBinRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadTransport'))
$testObjRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadTransportTests'))
$testBinRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadTransportTests'))
$logRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'logs'))

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory -Path $transportObjRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $transportBinRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $testObjRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $testBinRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot ("chatpad-transport-build-$Configuration-$timestamp.log")
$testLogPath = Join-Path $logRoot ("chatpad-transport-test-$Configuration-$timestamp.log")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($buildLogPath, '', $utf8NoBom)
[System.IO.File]::WriteAllText($testLogPath, '', $utf8NoBom)

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vsWhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
) | Select-Object -Unique
$vsWherePath = $vsWhereCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $vsWherePath) {
    throw 'vswhere.exe was not found.'
}

$msbuildPaths = @(
    & $vsWherePath -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\Current\Bin\MSBuild.exe'
)
if ($LASTEXITCODE -ne 0 -or $msbuildPaths.Count -eq 0) {
    throw 'MSBuild.exe was not found.'
}
$msbuildPath = [string]$msbuildPaths[0]

$testProjectPath = [System.IO.Path]::Combine($repoRoot, 'tests', 'transport', 'ChatpadTransportTests.vcxproj')
$buildArguments = @(
    $testProjectPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:RepoRoot=$repoRoot",
    '/verbosity:minimal'
)
$build = Invoke-NativeLoggedStep -Name 'MSBuild transport tests' -FilePath $msbuildPath -Arguments $buildArguments -LogPath $buildLogPath
$build.OutputText | Write-Output
Write-Output "MSBuild exit code: $($build.ExitCode)"
if ($build.ExitCode -ne 0) {
    Write-Output "Build log: $buildLogPath"
    exit $build.ExitCode
}

$transportLibrary = [System.IO.Path]::Combine($transportBinRoot, 'ChatpadTransport.lib')
$testExecutable = [System.IO.Path]::Combine($testBinRoot, 'ChatpadTransportTests.exe')
if (-not (Test-Path -LiteralPath $transportLibrary -PathType Leaf)) {
    throw "Transport library was not produced: $transportLibrary"
}
if (-not (Test-Path -LiteralPath $testExecutable -PathType Leaf)) {
    throw "Transport test executable was not produced: $testExecutable"
}

$executables = @(Get-ChildItem -LiteralPath $testBinRoot -Recurse -File -Filter '*.exe')
if ($executables.Count -ne 1 -or
    -not $executables[0].FullName.Equals($testExecutable, [System.StringComparison]::OrdinalIgnoreCase)) {
    $actualExecutables = @($executables | ForEach-Object { $_.FullName })
    throw ("Expected exactly one test executable at $testExecutable; found: {0}" -f ($actualExecutables -join ', '))
}

$testRun = Invoke-NativeLoggedStep -Name 'Native transport tests' -FilePath $testExecutable -Arguments @() -LogPath $testLogPath
$testRun.OutputText | Write-Output
$testExitCode = $testRun.ExitCode

$testOutputText = $testRun.OutputText
$testLines = @($testOutputText -split [Environment]::NewLine)
$totalLines = @($testLines | Where-Object { $_ -match '^Total: [0-9]+$' })
$passedLines = @($testLines | Where-Object { $_ -match '^Passed: [0-9]+$' })
$failedLines = @($testLines | Where-Object { $_ -match '^Failed: [0-9]+$' })
if ($totalLines.Count -ne 1 -or $passedLines.Count -ne 1 -or $failedLines.Count -ne 1) {
    throw 'Native test output did not contain one deterministic Total, Passed, and Failed line.'
}

$totalCount = [int]([regex]::Match($totalLines[0], '[0-9]+').Value)
$passedCount = [int]([regex]::Match($passedLines[0], '[0-9]+').Value)
$failedCount = [int]([regex]::Match($failedLines[0], '[0-9]+').Value)
$libraryHash = Get-Sha256 -Path $transportLibrary
$executableHash = Get-Sha256 -Path $testExecutable

Write-Output "Test executable exit code: $testExitCode"
Write-Output "Total assertions: $totalCount"
Write-Output "Passed assertions: $passedCount"
Write-Output "Failed assertions: $failedCount"
Write-Output "Transport library: $transportLibrary"
Write-Output "Transport library SHA-256: $libraryHash"
Write-Output "Executable: $testExecutable"
Write-Output "Executable SHA-256: $executableHash"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

if ($testExitCode -ne 0) {
    exit $testExitCode
}
if ($totalCount -ne ($passedCount + $failedCount) -or $failedCount -ne 0) {
    throw 'Native test counts are inconsistent with a successful test run.'
}

$approvedPrefix = (Resolve-Path -LiteralPath $artifactsRoot).ProviderPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$generated = @(
    Get-ChildItem -LiteralPath $transportObjRoot, $transportBinRoot, $testObjRoot, $testBinRoot -Recurse -File -ErrorAction SilentlyContinue
)
foreach ($file in $generated) {
    if (-not $file.FullName.StartsWith($approvedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated output escaped artifacts/: $($file.FullName)"
    }
}
Write-Output 'Output containment: PASS'

exit 0
