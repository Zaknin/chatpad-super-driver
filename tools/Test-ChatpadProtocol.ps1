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

function Set-MsvcX64Environment {
    param(
        [Parameter(Mandatory)]
        [string]$VsWherePath
    )

    $installationPaths = @(& $VsWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
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

function Get-MsBuildPath {
    $vswherePath = $null
    $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    $vswhereCandidates = @(
        (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
    ) | Select-Object -Unique

    foreach ($candidate in $vswhereCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $vswherePath = $candidate
            break
        }
    }

    if (-not $vswherePath) {
        return $null
    }

    $installationPaths = @(& $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    if ($LASTEXITCODE -ne 0 -or $installationPaths.Count -eq 0) {
        return $null
    }

    $msbuildPath = Join-Path ([string]$installationPaths[0]) 'MSBuild\Current\Bin\MSBuild.exe'
    if (-not (Test-Path -LiteralPath $msbuildPath -PathType Leaf)) {
        return $null
    }

    return $msbuildPath
}

function Get-FileSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 'N/A'
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    return [System.BitConverter]::ToString($sha256.ComputeHash($bytes)).Replace('-', '')
}

function Invoke-MsBuildStep {
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

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$objRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadProtocol'))
$binRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadProtocol'))
$testObjRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadProtocolTests'))
$testBinRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadProtocolTests'))
$logRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'logs'))

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory -Path $objRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $binRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $testObjRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $testBinRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
New-Item -ItemType Directory -Path $objRoot -Force | Out-Null
New-Item -ItemType Directory -Path $binRoot -Force | Out-Null
New-Item -ItemType Directory -Path $testObjRoot -Force | Out-Null
New-Item -ItemType Directory -Path $testBinRoot -Force | Out-Null
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot ("chatpad-protocol-integrated-build-$Configuration-$timestamp.log")
$testLogPath = Join-Path $logRoot ("chatpad-protocol-integrated-test-$Configuration-$timestamp.log")
[System.IO.File]::WriteAllText($buildLogPath, '', [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($testLogPath, '', [System.Text.UTF8Encoding]::new($false))

# Find MSBuild
$msbuildPath = Get-MsBuildPath
if (-not $msbuildPath) {
    Write-Error 'msbuild.exe was not found in any Visual Studio installation.'
    exit 1
}
Write-Output "MSBuild: $msbuildPath"

# Build ChatpadProtocol (static library) first — it is the dependency for the test executable
$protocolProjectPath = Join-Path $repoRoot 'src\protocol\ChatpadProtocol\ChatpadProtocol.vcxproj'
$protocolArguments = @(
    $protocolProjectPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:RepoRoot=$repoRoot",
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$buildLogPath;Verbosity=diagnostic;Encoding=UTF-8"
)

Write-Output "Building dependency project ChatpadProtocol ($Configuration|$Platform) with MSBuild."
$protocolResult = Invoke-MsBuildStep -Name 'MSBuild build (ChatpadProtocol)' -FilePath $msbuildPath -Arguments $protocolArguments -LogPath $buildLogPath
$protocolResult.Output | Write-Output
if ($protocolResult.ExitCode -ne 0) {
    exit $protocolResult.ExitCode
}
Write-Output 'ChatpadProtocol dependency build: PASS'

# Build ChatpadProtocolTests (test executable)
$testProjectPath = Join-Path $repoRoot 'tests\protocol\ChatpadProtocolTests.vcxproj'
$testArguments = @(
    $testProjectPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:RepoRoot=$repoRoot",
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$buildLogPath;Verbosity=diagnostic;Encoding=UTF-8"
)

Write-Output "Building test project ChatpadProtocolTests ($Configuration|$Platform) with MSBuild."
$testBuildResult = Invoke-MsBuildStep -Name 'MSBuild build (ChatpadProtocolTests)' -FilePath $msbuildPath -Arguments $testArguments -LogPath $buildLogPath
$testBuildResult.Output | Write-Output
$msbuildExitCode = $testBuildResult.ExitCode
if ($msbuildExitCode -ne 0) {
    exit $msbuildExitCode
}
Write-Output 'MSBuild exit code: 0'

# Verify expected outputs exist
$staticLibPath = Join-Path $binRoot "ChatpadProtocol.lib"
if (-not (Test-Path -LiteralPath $staticLibPath -PathType Leaf)) {
    Write-Error "Expected static library not found: $staticLibPath"
    exit 1
}
Write-Output "Static library: $staticLibPath"
Write-Output "SHA-256: $(Get-FileSha256 -Path $staticLibPath)"

$testExePath = Join-Path $testBinRoot "ChatpadProtocolTests.exe"
if (-not (Test-Path -LiteralPath $testExePath -PathType Leaf)) {
    Write-Error "Expected test executable not found: $testExePath"
    exit 1
}
Write-Output "Test executable: $testExePath"
Write-Output "SHA-256: $(Get-FileSha256 -Path $testExePath)"

# Run tests
$testArguments = @()
$testResult = Invoke-MsBuildStep -Name 'Native tests' -FilePath $testExePath -Arguments $testArguments -LogPath $testLogPath
$testResult.Output | Write-Output
$testExitCode = $testResult.ExitCode

$testLines = @($testResult.Output | ForEach-Object { [string]$_ })
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

Write-Output "Test executable exit code: $testExitCode"
Write-Output "Total assertions: $totalCount"
Write-Output "Passed assertions: $passedCount"
Write-Output "Failed assertions: $failedCount"
Write-Output "Executable: $testExePath"
Write-Output "SHA-256: $(Get-FileSha256 -Path $testExePath)"
Write-Output "Static library: $staticLibPath"
Write-Output "SHA-256: $(Get-FileSha256 -Path $staticLibPath)"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

if ($testExitCode -ne 0) {
    exit $testExitCode
}
if ($totalCount -ne ($passedCount + $failedCount) -or $failedCount -ne 0) {
    Write-Error 'Native test counts are inconsistent with a successful test run.'
    exit 1
}

# Verify no output outside artifacts
$forbiddenPatterns = @(
    '^\x64$', '^\Debug$', '^\Release$', '^bin$', '^obj$', '^build$', '^out$',
    '^src/[^/]+/[^/]+/(x64|Debug|Release|bin|obj)',
    '^tests/[^/]+/(x64|Debug|Release|bin|obj)'
)
$forbiddenOutputs = @()
Get-ChildItem -LiteralPath $repoRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '\.(sys|exe|dll|obj|pdb|lib|ilk|idb|tlog)$' } |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $firstSegment = ($relativePath -split '/', 2)[0]
        if ($firstSegment -notin @('.git', '.vs', 'artifacts', 'legacy-source')) {
            $forbiddenOutputs += $relativePath
        }
    }
if ($forbiddenOutputs.Count -gt 0) {
    Write-Error "Generated output found outside artifacts/: $($forbiddenOutputs -join ', ')"
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
