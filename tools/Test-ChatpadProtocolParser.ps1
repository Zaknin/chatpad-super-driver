[CmdletBinding()]
param()

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

function Set-MsvcX64Environment {
    param(
        [Parameter(Mandatory)]
        [string]$VsWherePath
    )

    $installationPaths = @(
        & $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    )
    if ($LASTEXITCODE -ne 0 -or $installationPaths.Count -eq 0) {
        throw 'No Visual Studio 2022 installation with MSVC x64 tools was found.'
    }

    $vcVarsPath = Join-Path ([string]$installationPaths[0]) 'VC\Auxiliary\Build\vcvars64.bat'
    if (-not (Test-Path -LiteralPath $vcVarsPath -PathType Leaf)) {
        throw "vcvars64.bat was not found: $vcVarsPath"
    }

    # cmd.exe treats metacharacters in inherited PATH entries as syntax while
    # expanding vcvars internals. Remove those entries only for this process.
    $originalPath = $env:PATH
    $env:PATH = @(
        $originalPath -split ';' |
            Where-Object { $_ -ne '' -and $_ -notmatch '[&|<>^]' }
    ) -join ';'
    try {
        $environmentLines = @(& $env:ComSpec /d /c "call `"$vcVarsPath`" >nul && set" 2>&1)
        $vcVarsExitCode = $LASTEXITCODE
    }
    finally {
        $env:PATH = $originalPath
    }
    if ($vcVarsExitCode -ne 0) {
        throw "vcvars64.bat failed with exit code $vcVarsExitCode."
    }
    $vcVarsErrors = @($environmentLines | Where-Object { $_ -match '(?i)not recognized|cannot find|error:' })
    if ($vcVarsErrors.Count -gt 0) {
        throw ("vcvars64.bat emitted errors: {0}" -f ($vcVarsErrors -join ' '))
    }

    foreach ($line in $environmentLines) {
        if ($line -match '^([^=]+)=(.*)$') {
            Set-Item -LiteralPath ("Env:{0}" -f $Matches[1]) -Value $Matches[2]
        }
    }
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
    $outputText = @($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    $section = @(
        "Step: $Name",
        "Exit code: $exitCode",
        $outputText,
        ''
    ) -join [Environment]::NewLine
    [System.IO.File]::AppendAllText(
        $LogPath,
        $section,
        [System.Text.UTF8Encoding]::new($false))

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
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
    $detectorOutput | Write-Output
    exit $detectorExitCode
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$objRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', 'x64', 'Debug', 'ChatpadProtocolParser'))
$binRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', 'x64', 'Debug', 'ChatpadProtocolParser'))
$logRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'logs'))

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory -Path $objRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $binRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
New-Item -ItemType Directory -Path $objRoot -Force | Out-Null
New-Item -ItemType Directory -Path $binRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot ("chatpad-protocol-parser-build-$timestamp.log")
$testLogPath = Join-Path $logRoot ("chatpad-protocol-parser-test-$timestamp.log")
[System.IO.File]::WriteAllText($buildLogPath, '', [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($testLogPath, '', [System.Text.UTF8Encoding]::new($false))

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vsWhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
) | Select-Object -Unique
$vsWherePath = $vsWhereCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $vsWherePath) {
    Write-Error 'vswhere.exe was not found.'
    exit 1
}

Set-MsvcX64Environment -VsWherePath $vsWherePath
$clPath = (Get-Command cl.exe -CommandType Application -ErrorAction Stop).Source
$linkPath = (Get-Command link.exe -CommandType Application -ErrorAction Stop).Source

$sourceRoot = [System.IO.Path]::Combine($repoRoot, 'src', 'protocol', 'ChatpadProtocol')
$testRoot = [System.IO.Path]::Combine($repoRoot, 'tests', 'protocol')
$fixtureRoot = [System.IO.Path]::Combine($testRoot, 'fixtures')
$parserSource = [System.IO.Path]::Combine($sourceRoot, 'ChatpadKeyboardParser.c')
$testSource = [System.IO.Path]::Combine($testRoot, 'ChatpadProtocolParserTests.c')
$parserObject = [System.IO.Path]::Combine($objRoot, 'ChatpadKeyboardParser.obj')
$testObject = [System.IO.Path]::Combine($objRoot, 'ChatpadProtocolParserTests.obj')
$testExecutable = [System.IO.Path]::Combine($binRoot, 'ChatpadProtocolParserTests.exe')
$testPdb = [System.IO.Path]::Combine($binRoot, 'ChatpadProtocolParserTests.pdb')

$commonCompilerArguments = @(
    '/nologo',
    '/TC',
    '/std:c11',
    '/W4',
    '/WX',
    '/sdl',
    '/GS',
    '/Z7',
    '/Od',
    '/MDd',
    '/utf-8',
    '/c',
    "/I$sourceRoot",
    "/I$fixtureRoot"
)

$parserCompileArguments = @($commonCompilerArguments + @("/Fo$parserObject", $parserSource))
$parserCompile = Invoke-NativeLoggedStep -Name 'Parser compile' -FilePath $clPath -Arguments $parserCompileArguments -LogPath $buildLogPath
$parserCompile.Output | Write-Output
Write-Output "Parser compiler exit code: $($parserCompile.ExitCode)"
if ($parserCompile.ExitCode -ne 0) {
    Write-Output "Build log: $buildLogPath"
    exit $parserCompile.ExitCode
}

$testCompileArguments = @($commonCompilerArguments + @("/Fo$testObject", $testSource))
$testCompile = Invoke-NativeLoggedStep -Name 'Test compile' -FilePath $clPath -Arguments $testCompileArguments -LogPath $buildLogPath
$testCompile.Output | Write-Output
Write-Output "Test compiler exit code: $($testCompile.ExitCode)"
if ($testCompile.ExitCode -ne 0) {
    Write-Output "Build log: $buildLogPath"
    exit $testCompile.ExitCode
}

$linkArguments = @(
    '/NOLOGO',
    '/DEBUG',
    '/INCREMENTAL:NO',
    "/OUT:$testExecutable",
    "/PDB:$testPdb",
    $parserObject,
    $testObject
)
$link = Invoke-NativeLoggedStep -Name 'Test link' -FilePath $linkPath -Arguments $linkArguments -LogPath $buildLogPath
$link.Output | Write-Output
Write-Output "Linker exit code: $($link.ExitCode)"
if ($link.ExitCode -ne 0) {
    Write-Output "Build log: $buildLogPath"
    exit $link.ExitCode
}
Write-Output 'Compiler/linker exit code: 0'

$executables = @(Get-ChildItem -LiteralPath $binRoot -Recurse -File -Filter '*.exe')
if ($executables.Count -ne 1 -or
    -not $executables[0].FullName.Equals($testExecutable, [System.StringComparison]::OrdinalIgnoreCase)) {
    $actualExecutables = @($executables | ForEach-Object { $_.FullName })
    Write-Error ("Expected exactly one test executable at $testExecutable; found: {0}" -f ($actualExecutables -join ', '))
    exit 1
}

$testRun = Invoke-NativeLoggedStep -Name 'Native tests' -FilePath $testExecutable -Arguments @() -LogPath $testLogPath
$testRun.Output | Write-Output
$testExitCode = $testRun.ExitCode

$testLines = @($testRun.Output | ForEach-Object { [string]$_ })
$totalLines = @($testLines | Where-Object { $_ -match '^Total: [0-9]+$' })
$passedLines = @($testLines | Where-Object { $_ -match '^Passed: [0-9]+$' })
$failedLines = @($testLines | Where-Object { $_ -match '^Failed: [0-9]+$' })
if ($totalLines.Count -ne 1 -or $passedLines.Count -ne 1 -or $failedLines.Count -ne 1) {
    Write-Error 'Native test output did not contain one deterministic Total, Passed, and Failed line.'
    exit 1
}

$totalCount = [int]([regex]::Match($totalLines[0], '[0-9]+').Value)
$passedCount = [int]([regex]::Match($passedLines[0], '[0-9]+').Value)
$failedCount = [int]([regex]::Match($failedLines[0], '[0-9]+').Value)
$hash = (Get-FileHash -LiteralPath $testExecutable -Algorithm SHA256).Hash

Write-Output "Test executable exit code: $testExitCode"
Write-Output "Total assertions: $totalCount"
Write-Output "Passed assertions: $passedCount"
Write-Output "Failed assertions: $failedCount"
Write-Output "Executable: $testExecutable"
Write-Output "SHA-256: $hash"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

if ($testExitCode -ne 0) {
    exit $testExitCode
}
if ($totalCount -ne ($passedCount + $failedCount) -or $failedCount -ne 0) {
    Write-Error 'Native test counts are inconsistent with a successful test run.'
    exit 1
}

$safetyPath = Join-Path $PSScriptRoot 'Test-RepositorySafety.ps1'
$safetyOutput = @(& $safetyPath 2>&1)
$safetyExitCode = $LASTEXITCODE
$safetyOutput | Write-Output
if ($safetyExitCode -ne 0) {
    Write-Error "Repository safety validation failed with exit code $safetyExitCode."
    exit 1
}

exit 0
