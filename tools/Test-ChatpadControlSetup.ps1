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
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    if (-not $fullPath.EndsWith($separator)) {
        $fullPath += $separator
    }
    return $fullPath
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

function Invoke-NativeLoggedStep {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogPath)

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $outputLines = @($output | ForEach-Object { if ($null -eq $_) { '' } else { $_.ToString() } })
    $outputText = $outputLines -join [Environment]::NewLine
    [System.IO.File]::AppendAllText(
        $LogPath,
        "Step: $Name`nExit code: $exitCode`n$outputText`n",
        [System.Text.Encoding]::UTF8)
    return [pscustomobject]@{ ExitCode = $exitCode; OutputText = $outputText }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-PureLayerGuard {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $sourceRoot = Join-Path $RepositoryRoot 'src\transport\ChatpadControlSetup'
    $projectPath = Join-Path $sourceRoot 'ChatpadControlSetup.vcxproj'
    $sourceFiles = @(
        (Join-Path $sourceRoot 'ChatpadControlSetup.h'),
        (Join-Path $sourceRoot 'ChatpadControlSetup.c'))
    $prohibitedPattern = '(?i)#\s*include\s*[<"](?:windows|ntddk|wdm|wdf|wdfusb|usb|usbdlib|hidsdi|setupapi)|\b(?:WDF[A-Z_]|Wdf[A-Za-z]|URB[A-Z_]|IOCTL[A-Z_]|CreateFile|DeviceIoControl|SetupDi[A-Za-z]|CM_[A-Za-z]|WinUsb[A-Za-z]|HidD_[A-Za-z]|DriverEntry)\b'

    foreach ($file in $sourceFiles) {
        $matches = @(Select-String -LiteralPath $file -Pattern $prohibitedPattern -AllMatches)
        if ($matches.Count -ne 0) {
            throw "Pure-layer guard found a platform/runtime dependency in $file."
        }
    }

    [xml]$project = Get-Content -LiteralPath $projectPath -Raw
    $namespace = New-Object System.Xml.XmlNamespaceManager($project.NameTable)
    $namespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $compileItems = @($project.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $namespace) | ForEach-Object { $_.Include })
    $references = @($project.SelectNodes('//msb:ItemGroup/msb:ProjectReference[@Include]', $namespace) | ForEach-Object { $_.Include })
    if ($compileItems.Count -ne 1 -or $compileItems[0] -ne 'ChatpadControlSetup.c') {
        throw 'Pure-layer project must compile only ChatpadControlSetup.c.'
    }
    if ($references.Count -ne 1 -or $references[0] -notmatch 'ChatpadProtocol\.vcxproj$') {
        throw 'Pure-layer project must reference only ChatpadProtocol.'
    }
    if ((Get-Content -LiteralPath $projectPath -Raw) -match '(?i)ChatpadFilter|WindowsKernelModeDriver|DriverType|SignMode') {
        throw 'Pure-layer project contains a driver, kernel-toolset, or signing dependency.'
    }
    Write-Output 'Source/project guard: PASS (portable source only; protocol is the only project dependency).'
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

Test-PureLayerGuard -RepositoryRoot $repoRoot

$detectorOutput = @(& (Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1') 2>&1)
$detectorExitCode = $LASTEXITCODE
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) {
    $detectorOutput | ForEach-Object { Write-Output $_.ToString() }
    exit $detectorExitCode
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$libraryObjRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadControlSetup'))
$libraryBinRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadControlSetup'))
$testObjRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadControlSetupTests'))
$testBinRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadControlSetupTests'))
$logRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'logs'))

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory $libraryObjRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $libraryBinRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $testObjRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $testBinRoot $repoRoot $artifactsRoot
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot "chatpad-control-setup-build-$Configuration-$timestamp.log"
$testLogPath = Join-Path $logRoot "chatpad-control-setup-test-$Configuration-$timestamp.log"
[System.IO.File]::WriteAllText($buildLogPath, '', (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($testLogPath, '', (New-Object System.Text.UTF8Encoding($false)))

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vsWherePath = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $vsWherePath) { throw 'vswhere.exe was not found.' }
$msbuildPaths = @(& $vsWherePath -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\Current\Bin\MSBuild.exe')
if ($LASTEXITCODE -ne 0 -or $msbuildPaths.Count -eq 0) { throw 'MSBuild.exe was not found.' }
$msbuildPath = [string]$msbuildPaths[0]

$testProject = Join-Path $repoRoot 'tests\transport\ChatpadControlSetupTests\ChatpadControlSetupTests.vcxproj'
$buildArguments = @($testProject, '/nologo', '/m', '/t:Clean;Build', "/p:Configuration=$Configuration", "/p:Platform=$Platform", '/p:PreferredToolArchitecture=x64', "/p:RepoRoot=$repoRoot", '/verbosity:minimal')
$build = Invoke-NativeLoggedStep 'MSBuild control-setup tests' $msbuildPath $buildArguments $buildLogPath
$build.OutputText | Write-Output
Write-Output "MSBuild exit code: $($build.ExitCode)"
if ($build.ExitCode -ne 0) { Write-Output "Build log: $buildLogPath"; exit $build.ExitCode }

$libraryPath = Join-Path $libraryBinRoot 'ChatpadControlSetup.lib'
$executablePath = Join-Path $testBinRoot 'ChatpadControlSetupTests.exe'
if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) { throw "Expected library not found: $libraryPath" }
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) { throw "Expected executable not found: $executablePath" }

$test = Invoke-NativeLoggedStep 'Native control-setup tests' $executablePath @() $testLogPath
$test.OutputText | Write-Output
$totalMatch = [regex]::Matches($test.OutputText, '(?m)^Total: ([0-9]+)\r?$')
$passedMatch = [regex]::Matches($test.OutputText, '(?m)^Passed: ([0-9]+)\r?$')
$failedMatch = [regex]::Matches($test.OutputText, '(?m)^Failed: ([0-9]+)\r?$')
if ($totalMatch.Count -ne 1 -or $passedMatch.Count -ne 1 -or $failedMatch.Count -ne 1) {
    throw 'Test output did not contain one deterministic Total, Passed, and Failed line.'
}
$totalCount = [int]$totalMatch[0].Groups[1].Value
$passedCount = [int]$passedMatch[0].Groups[1].Value
$failedCount = [int]$failedMatch[0].Groups[1].Value

Write-Output "Test executable exit code: $($test.ExitCode)"
Write-Output "Total assertions: $totalCount"
Write-Output "Passed assertions: $passedCount"
Write-Output "Failed assertions: $failedCount"
Write-Output "Control-setup library: $libraryPath"
Write-Output "Control-setup library SHA-256: $(Get-Sha256 $libraryPath)"
Write-Output "Executable: $executablePath"
Write-Output "Executable SHA-256: $(Get-Sha256 $executablePath)"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

if ($test.ExitCode -ne 0) { exit $test.ExitCode }
if ($totalCount -ne ($passedCount + $failedCount) -or $failedCount -ne 0) { throw 'Test counts are inconsistent with success.' }

$artifactsPrefix = (Resolve-Path -LiteralPath $artifactsRoot).ProviderPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$generated = @(Get-ChildItem -LiteralPath $libraryObjRoot, $libraryBinRoot, $testObjRoot, $testBinRoot -Recurse -File -ErrorAction SilentlyContinue)
foreach ($file in $generated) {
    if (-not $file.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated output escaped artifacts/: $($file.FullName)"
    }
}
Write-Output 'Artifact containment: PASS (all control-setup outputs are beneath artifacts/).'
exit 0
