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
        [Parameter(Mandatory)][string]$ArtifactsRoot
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
        [Parameter(Mandatory)][string]$LogPath
    )

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $outputLines = @($output | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    $section = "Step: $Name`nExit code: $exitCode`n$($outputLines -join [Environment]::NewLine)`n"
    [System.IO.File]::AppendAllText($LogPath, $section, [System.Text.Encoding]::UTF8)
    return [pscustomobject]@{
        ExitCode = $exitCode
        OutputLines = $outputLines
    }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)

    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
    catch {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try {
                $bytes = $sha.ComputeHash($stream)
                return -join ($bytes | ForEach-Object { $_.ToString('x2') })
            }
            finally {
                $sha.Dispose()
            }
        }
        finally {
            $stream.Dispose()
        }
    }
}

function Test-SourceAndProjectGuards {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $coreFiles = @(
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadFilterLifecycle.h'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadFilterLifecycle.c')
    )
    $coreProhibited = '(?i)\b(Wdf|WDF|WDM|USB|HID|IOCTL|URB|CreateFile|DeviceIoControl|malloc|calloc|realloc|free|fopen|fread|fwrite)\b'
    foreach ($file in $coreFiles) {
        $matches = @(Select-String -LiteralPath $file -Pattern $coreProhibited)
        if ($matches.Count -ne 0) {
            throw "Lifecycle core contains prohibited runtime surface text in ${file}: $($matches[0].Line.Trim())"
        }
    }

    $filterFiles = @(
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadActivationPreparation.h'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadActivationPreparation.c'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\driver.h'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\driver.c'),
        (Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\device.c')
    )
    $runtimeProhibited = '(?i)\b(WdfUsbTargetDevice\w*|WDFUSB\w*|URB\w*|IOCTL_INTERNAL_USB\w*|WdfIoQueueCreate|WdfDeviceCreateDeviceInterface|WdfTimerCreate|WdfWorkItemCreate|CreateFile|DeviceIoControl)\b'
    foreach ($file in $filterFiles) {
        $matches = @(Select-String -LiteralPath $file -Pattern $runtimeProhibited)
        if ($matches.Count -ne 0) {
            throw "ChatpadFilter source/project contains prohibited runtime surface text in ${file}: $($matches[0].Line.Trim())"
        }
    }

    $filterProject = Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
    [xml]$filterXml = Get-Content -LiteralPath $filterProject
    $namespace = New-Object System.Xml.XmlNamespaceManager($filterXml.NameTable)
    $namespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')

    $projectReferences = @($filterXml.SelectNodes('//msb:ProjectReference', $namespace))
    if ($projectReferences.Count -ne 1 -or
        $projectReferences[0].Include -cne '..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj') {
        throw 'ChatpadFilter.vcxproj must contain only the authorized request-owner context static-library project reference.'
    }
    $projectReferenceGuid = $projectReferences[0].SelectSingleNode('msb:Project', $namespace)
    $projectReferenceGlobalPropertiesToRemove = $projectReferences[0].SelectSingleNode('msb:GlobalPropertiesToRemove', $namespace)
    $projectReferenceAdditionalProperties = $projectReferences[0].SelectSingleNode('msb:AdditionalProperties', $namespace)
    $expectedAdditionalProperties = 'OutDir=$(RepoRoot)\artifacts\bin\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\;IntDir=$(RepoRoot)\artifacts\obj\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\'
    if ($null -eq $projectReferenceGuid -or
        $projectReferenceGuid.InnerText -cne '{421C7E3A-5B02-4D07-A37D-4B45D3755694}' -or
        $null -eq $projectReferenceGlobalPropertiesToRemove -or
        $projectReferenceGlobalPropertiesToRemove.InnerText -cne 'OutDir;IntDir' -or
        $null -eq $projectReferenceAdditionalProperties -or
        $projectReferenceAdditionalProperties.InnerText -cne $expectedAdditionalProperties) {
        throw 'ChatpadFilter.vcxproj request-owner context project reference metadata is not exact.'
    }

    $compileItems = @($filterXml.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $namespace) | ForEach-Object { $_.Include })
    $requiredSharedItems = @(
        'ChatpadActivationPreparation.c',
        '..\..\protocol\ChatpadProtocol\ChatpadActivationRequests.c',
        '..\..\protocol\ChatpadProtocol\ChatpadActivationSequence.c',
        '..\..\transport\ChatpadControlSetup\ChatpadControlSetup.c',
        '..\..\transport\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.c',
        '..\..\transport\ChatpadWdfControlSetup\ChatpadWdfControlSetupFormatter.c')
    if (@($requiredSharedItems | Where-Object { $compileItems -notcontains $_ }).Count -ne 0) {
        throw 'ChatpadFilter.vcxproj is missing an exact authorized activation-preparation shared source.'
    }

    $filterText = [System.IO.File]::ReadAllText($filterProject)
    if ($filterText -match '(?i)ChatpadTransportAdapter\.c|ChatpadTransport\.vcxproj') {
        throw 'ChatpadFilter.vcxproj must not compile or reference the transport adapter.'
    }
    foreach ($runtimeFileName in @('driver.h', 'driver.c', 'device.c')) {
        $runtimePath = Join-Path $RepositoryRoot "src\driver\ChatpadFilter\$runtimeFileName"
        if ((Get-Content -LiteralPath $runtimePath -Raw) -match '\bChatpadPrepareActivationStep\b') {
            throw "Runtime callback surface invokes dormant activation preparation: $runtimePath"
        }
    }

    $modernDriverProhibited = @(
        Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'src\driver') -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '(?i)^\.(inf|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk)$' -or $_.Name -match '(?i)(package|install|deploy)' } |
            ForEach-Object { $_.FullName }
    )
    if ($modernDriverProhibited.Count -ne 0) {
        throw "Prohibited driver package/sign/install/deploy file exists: $($modernDriverProhibited -join ', ')"
    }

    Write-Output 'Source/project guard: PASS'
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

Test-SourceAndProjectGuards -RepositoryRoot $repoRoot

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath 2>&1)
$detectorExitCode = $LASTEXITCODE
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) {
    $detectorOutput | ForEach-Object { Write-Output $_.ToString() }
    exit $detectorExitCode
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$testObjRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadFilterLifecycleTests'))
$testBinRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadFilterLifecycleTests'))
$logRoot = Get-DirectoryPath -Path ([System.IO.Path]::Combine($artifactsRoot, 'logs'))

New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory -Path $testObjRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
Remove-SelectedArtifactDirectory -Path $testBinRoot -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot ("chatpad-filter-lifecycle-build-$Configuration-$timestamp.log")
$testLogPath = Join-Path $logRoot ("chatpad-filter-lifecycle-test-$Configuration-$timestamp.log")
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($buildLogPath, '', $utf8NoBom)
[System.IO.File]::WriteAllText($testLogPath, '', $utf8NoBom)

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vsWhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
) | Select-Object -Unique
$vsWherePath = $vsWhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $vsWherePath) {
    throw 'vswhere.exe was not found.'
}

$parsedInstallations = ConvertFrom-Json -InputObject ((@(& $vsWherePath -all -products * -version '[17.0,18.0)' -format json -utf8)) -join [Environment]::NewLine)
$installations = @($parsedInstallations | ForEach-Object { $_ })
$msbuildPath = $null
foreach ($installation in ($installations | Sort-Object { [version]$_.installationVersion } -Descending)) {
    $candidate = Join-Path ([string]$installation.installationPath) 'MSBuild\Current\Bin\MSBuild.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $msbuildPath = $candidate
        break
    }
}
if (-not $msbuildPath) {
    throw 'No VS 2022 MSBuild installation was found.'
}

$testProject = Join-Path $repoRoot 'tests\driver\ChatpadFilterLifecycleTests\ChatpadFilterLifecycleTests.vcxproj'
$buildArguments = @(
    $testProject,
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

Write-Output "Building ChatpadFilterLifecycleTests ($Configuration|$Platform)."
$buildResult = Invoke-NativeLoggedStep -Name 'MSBuild lifecycle tests' -FilePath $msbuildPath -Arguments $buildArguments -LogPath $buildLogPath
$buildResult.OutputLines | Write-Output
Write-Output "MSBuild exit code: $($buildResult.ExitCode)"
if ($buildResult.ExitCode -ne 0) {
    exit $buildResult.ExitCode
}

$testExePath = Join-Path $testBinRoot 'ChatpadFilterLifecycleTests.exe'
if (-not (Test-Path -LiteralPath $testExePath -PathType Leaf)) {
    throw "Expected lifecycle test executable not found: $testExePath"
}

$testResult = Invoke-NativeLoggedStep -Name 'Native lifecycle tests' -FilePath $testExePath -Arguments @() -LogPath $testLogPath
$testResult.OutputLines | Write-Output

$totalLines = @($testResult.OutputLines | Where-Object { $_ -match '^Total: [0-9]+$' })
$passedLines = @($testResult.OutputLines | Where-Object { $_ -match '^Passed: [0-9]+$' })
$failedLines = @($testResult.OutputLines | Where-Object { $_ -match '^Failed: [0-9]+$' })
if ($totalLines.Count -ne 1 -or $passedLines.Count -ne 1 -or $failedLines.Count -ne 1) {
    throw 'Native lifecycle test output did not contain one deterministic Total, Passed, and Failed line.'
}

$totalCount = [int]([regex]::Match($totalLines[0], '[0-9]+').Value)
$passedCount = [int]([regex]::Match($passedLines[0], '[0-9]+').Value)
$failedCount = [int]([regex]::Match($failedLines[0], '[0-9]+').Value)

Write-Output "Test executable exit code: $($testResult.ExitCode)"
Write-Output "Lifecycle assertions: $totalCount"
Write-Output "Passed assertions: $passedCount"
Write-Output "Failed assertions: $failedCount"
Write-Output "Executable: $testExePath"
Write-Output "Executable SHA-256: $(Get-Sha256 -Path $testExePath)"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

if ($testResult.ExitCode -ne 0) {
    exit $testResult.ExitCode
}
if ($totalCount -ne ($passedCount + $failedCount) -or $failedCount -ne 0) {
    throw 'Native lifecycle test counts are inconsistent with a successful test run.'
}

$artifactsPrefix = Get-DirectoryPath -Path $artifactsRoot
$generatedFiles = @(Get-ChildItem -LiteralPath @($testObjRoot, $testBinRoot) -Recurse -File -ErrorAction SilentlyContinue)
$escapedFiles = @($generatedFiles | Where-Object {
    -not $_.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($escapedFiles.Count -ne 0) {
    throw "Lifecycle output escaped artifacts/: $($escapedFiles.FullName -join ', ')"
}
Write-Output 'Output containment: PASS'

exit 0
