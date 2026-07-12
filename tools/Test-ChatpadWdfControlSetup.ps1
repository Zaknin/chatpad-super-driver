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

function Get-FileSha256Hash {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
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

function Test-FormatterSourceAndProjects {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $formatterRoot = Join-Path $RepositoryRoot 'src\transport\ChatpadWdfControlSetup'
    $filterRoot = Join-Path $RepositoryRoot 'src\driver\ChatpadFilter'
    $compileCheckRoot = Join-Path $RepositoryRoot 'tests\kernel\ChatpadWdfControlSetupCompileCheck'
    $formatterProjectPath = Join-Path $formatterRoot 'ChatpadWdfControlSetup.vcxproj'
    $filterProjectPath = Join-Path $filterRoot 'ChatpadFilter.vcxproj'
    $preparationHeaderPath = Join-Path $filterRoot 'ChatpadActivationPreparation.h'
    $preparationSourcePath = Join-Path $filterRoot 'ChatpadActivationPreparation.c'
    $compileCheckProjectPath = Join-Path $compileCheckRoot 'ChatpadWdfControlSetupCompileCheck.vcxproj'
    $guardedFiles = @(
        (Join-Path $formatterRoot 'ChatpadWdfControlSetupFormatter.h'),
        (Join-Path $formatterRoot 'ChatpadWdfControlSetupFormatter.c'),
        $preparationHeaderPath,
        $preparationSourcePath,
        $formatterProjectPath,
        (Join-Path $compileCheckRoot 'ChatpadWdfControlSetupCompileCheck.c'),
        $compileCheckProjectPath)
    $prohibitedNames = @(
        'WDFDEVICE', 'WDFIOTARGET', 'WDFUSBDEVICE', 'WDFREQUEST', 'WDFMEMORY',
        'WdfRequestCreate', 'WdfMemoryCreate', 'WdfUsbTargetDeviceCreate',
        'WdfUsbTargetDeviceFormatRequestForControlTransfer',
        'WdfIoTargetFormatRequestForInternalIoctlOthers', 'WdfRequestSend',
        'WdfRequestSetCompletionRoutine', 'WdfRequestReuse',
        'WdfRequestCancelSentRequest', 'WdfIoTargetStart', 'WdfIoTargetStop',
        'WdfIoQueueCreate', 'WdfDeviceCreateDeviceInterface', 'WdfTimerCreate',
        'WdfWorkItemCreate', 'IoCallDriver', 'IoBuildDeviceIoControlRequest',
        'KeDelayExecutionThread', 'KeWaitForSingleObject', 'IOCTL', 'URB',
        'DriverEntry')
    $prohibitedPattern = '(?i)\b(?:WDFDEVICE|WDFIOTARGET|WDFUSBDEVICE|WDFREQUEST|WDFMEMORY|WdfRequestCreate|WdfMemoryCreate|WdfUsbTargetDeviceCreate|WdfUsbTargetDeviceFormatRequestForControlTransfer|WdfIoTargetFormatRequestForInternalIoctlOthers|WdfRequestSend|WdfRequestSetCompletionRoutine|WdfRequestReuse|WdfRequestCancelSentRequest|WdfIoTargetStart|WdfIoTargetStop|WdfIoQueueCreate|WdfDeviceCreateDeviceInterface|WdfTimerCreate|WdfWorkItemCreate|IoCallDriver|IoBuildDeviceIoControlRequest|KeDelayExecutionThread|KeWaitForSingleObject|IOCTL[A-Za-z0-9_]*|URB[A-Za-z0-9_]*|DriverEntry)\b'

    foreach ($file in $guardedFiles) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Required formatter source or project file is missing: $file"
        }
        $matches = @(Select-String -LiteralPath $file -Pattern $prohibitedPattern -AllMatches)
        if ($matches.Count -ne 0) {
            throw "Prohibited runtime surface found in guarded file ${file}: $($matches.Line.Trim() -join '; ')"
        }
    }

    [xml]$formatterProject = Get-Content -LiteralPath $formatterProjectPath -Raw
    $formatterNamespace = New-Object System.Xml.XmlNamespaceManager($formatterProject.NameTable)
    $formatterNamespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $formatterCompileItems = @($formatterProject.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $formatterNamespace) | ForEach-Object { $_.Include })
    $formatterReferences = @($formatterProject.SelectNodes('//msb:ItemGroup/msb:ProjectReference[@Include]', $formatterNamespace))
    if ($formatterCompileItems.Count -ne 1 -or $formatterCompileItems[0] -ne 'ChatpadWdfControlSetupFormatter.c') {
        throw 'Formatter project must compile only ChatpadWdfControlSetupFormatter.c.'
    }
    if ($formatterReferences.Count -ne 0) {
        throw 'Formatter project must have no project references.'
    }
    $formatterConfigurationTypes = @($formatterProject.SelectNodes('//msb:PropertyGroup/msb:ConfigurationType', $formatterNamespace) | ForEach-Object { $_.InnerText })
    if ($formatterConfigurationTypes.Count -ne 2 -or @($formatterConfigurationTypes | Where-Object { $_ -ne 'StaticLibrary' }).Count -ne 0) {
        throw 'Formatter project must produce only a static library.'
    }

    [xml]$compileCheckProject = Get-Content -LiteralPath $compileCheckProjectPath -Raw
    $compileCheckNamespace = New-Object System.Xml.XmlNamespaceManager($compileCheckProject.NameTable)
    $compileCheckNamespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $compileCheckItems = @($compileCheckProject.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $compileCheckNamespace) | ForEach-Object { $_.Include })
    $compileCheckReferences = @($compileCheckProject.SelectNodes('//msb:ItemGroup/msb:ProjectReference[@Include]', $compileCheckNamespace))
    $expectedCompileCheckItems = @(
        'ChatpadWdfControlSetupCompileCheck.c',
        '..\..\..\src\driver\ChatpadFilter\ChatpadActivationPreparation.c',
        '..\..\..\src\protocol\ChatpadProtocol\ChatpadActivationRequests.c',
        '..\..\..\src\protocol\ChatpadProtocol\ChatpadActivationSequence.c',
        '..\..\..\src\transport\ChatpadControlSetup\ChatpadControlSetup.c',
        '..\..\..\src\transport\ChatpadWdfControlSetup\ChatpadWdfControlSetupFormatter.c')
    if ($compileCheckItems.Count -ne $expectedCompileCheckItems.Count -or
        @($expectedCompileCheckItems | Where-Object { $compileCheckItems -notcontains $_ }).Count -ne 0) {
        throw 'Compile-check project must compile only the integration check and exact shared activation-preparation sources.'
    }
    if ($compileCheckReferences.Count -ne 1 -or
        $compileCheckReferences[0].Include -notmatch 'ChatpadWdfControlSetup\.vcxproj$' -or
        [string]$compileCheckReferences[0].LinkLibraryDependencies -ne 'false') {
        throw 'Compile-check project must reference only the formatter with library linkage disabled.'
    }

    [xml]$filterProject = Get-Content -LiteralPath $filterProjectPath -Raw
    $filterNamespace = New-Object System.Xml.XmlNamespaceManager($filterProject.NameTable)
    $filterNamespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $filterCompileItems = @($filterProject.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $filterNamespace) | ForEach-Object { $_.Include })
    $filterReferences = @($filterProject.SelectNodes('//msb:ItemGroup/msb:ProjectReference[@Include]', $filterNamespace))
    $expectedFilterCompileItems = @(
        'ChatpadActivationPreparation.c',
        'ChatpadFilterLifecycle.c',
        'ChatpadLiveRuntime.c',
        '..\..\protocol\ChatpadProtocol\ChatpadKeyboardHid.c',
        '..\..\protocol\ChatpadProtocol\ChatpadFailOpenPolicy.c',
        '..\..\protocol\ChatpadProtocol\ChatpadKeyboardParser.c',
        '..\..\protocol\ChatpadProtocol\ChatpadLiveTransferPolicy.c',
        '..\..\protocol\ChatpadProtocol\ChatpadActivationRequests.c',
        '..\..\protocol\ChatpadProtocol\ChatpadActivationSequence.c',
        '..\..\transport\ChatpadControlSetup\ChatpadControlSetup.c',
        '..\..\transport\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.c',
        '..\..\transport\ChatpadWdfControlSetup\ChatpadWdfControlSetupFormatter.c',
        'driver.c',
        'device.c')
    if ($filterCompileItems.Count -ne $expectedFilterCompileItems.Count -or
        @($expectedFilterCompileItems | Where-Object { $filterCompileItems -notcontains $_ }).Count -ne 0) {
        throw 'ChatpadFilter must compile only the authorized lifecycle, live-runtime, protocol, setup, and request-owner sources.'
    }
    if ($filterReferences.Count -ne 1 -or
        $filterReferences[0].Include -cne '..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj') {
        throw 'ChatpadFilter must contain only the authorized request-owner context static-library project reference.'
    }
    $filterReferenceGuid = $filterReferences[0].SelectSingleNode('msb:Project', $filterNamespace)
    $filterReferenceGlobalPropertiesToRemove = $filterReferences[0].SelectSingleNode('msb:GlobalPropertiesToRemove', $filterNamespace)
    $filterReferenceAdditionalProperties = $filterReferences[0].SelectSingleNode('msb:AdditionalProperties', $filterNamespace)
    $expectedFilterReferenceAdditionalProperties = 'OutDir=$(RepoRoot)\artifacts\bin\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\;IntDir=$(RepoRoot)\artifacts\obj\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\'
    if ($null -eq $filterReferenceGuid -or
        $filterReferenceGuid.InnerText -cne '{421C7E3A-5B02-4D07-A37D-4B45D3755694}' -or
        $null -eq $filterReferenceGlobalPropertiesToRemove -or
        $filterReferenceGlobalPropertiesToRemove.InnerText -cne 'OutDir;IntDir' -or
        $null -eq $filterReferenceAdditionalProperties -or
        $filterReferenceAdditionalProperties.InnerText -cne $expectedFilterReferenceAdditionalProperties) {
        throw 'ChatpadFilter request-owner context project reference metadata is not exact.'
    }
    if ((Get-Content -LiteralPath $filterProjectPath -Raw) -match '(?i)ChatpadTransportAdapter\.c|ChatpadTransport\.vcxproj') {
        throw 'ChatpadFilter must not compile or reference the transport adapter.'
    }

    $preparationSource = Get-Content -LiteralPath $preparationSourcePath -Raw
    foreach ($requiredCall in @(
        'ChatpadGetActivationSequenceStep',
        'ChatpadTranslateActivationRequest',
        'ChatpadFormatWdfControlSetupPacket')) {
        if ($preparationSource -notmatch [regex]::Escape($requiredCall)) {
            throw "Activation preparation does not call required authoritative API: $requiredCall"
        }
    }
    if ($preparationSource -match '(?i)0x90|90\s*,\s*00') {
        throw 'Unconfirmed 90 00 data appeared in activation preparation.'
    }

    foreach ($runtimeFileName in @('driver.c', 'device.c', 'driver.h')) {
        $runtimePath = Join-Path $filterRoot $runtimeFileName
        if ((Get-Content -LiteralPath $runtimePath -Raw) -match '\bChatpadPrepareActivationStep\b') {
            throw "Runtime callback surface invokes dormant activation preparation: $runtimePath"
        }
    }

    Write-Output "Prohibition guard tokens: $($prohibitedNames -join ', ')"
    Write-Output 'Source/project prohibition guard: PASS (no prohibited runtime surfaces found).'
    Write-Output 'Formatter project guard: PASS (one source, static library, no project references).'
    Write-Output 'Compile-check project guard: PASS (exact shared activation-preparation sources; formatter dependency remains non-linking).'
    Write-Output 'ChatpadFilter integration guard: PASS (exact shared sources, only authorized request-owner context project reference, no transport adapter).'
    Write-Output 'Dormancy guard: PASS (no runtime callback invokes ChatpadPrepareActivationStep).'
    Write-Output 'Authoritative API guard: PASS (sequence, translation, and WDF formatter calls present; 90 00 absent).'
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

Test-FormatterSourceAndProjects -RepositoryRoot $repoRoot

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath 2>&1)
$detectorExitCode = $LASTEXITCODE
$detectorOutput | ForEach-Object { Write-Output $_.ToString() }
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) {
    exit $detectorExitCode
}

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswherePath = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1
if (-not $vswherePath) {
    throw 'vswhere.exe was not found.'
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
    throw 'No VS 2022 MSBuild installation with x64 WDK integration was found.'
}

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$formatterOutDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadWdfControlSetup'))
$formatterIntDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadWdfControlSetup'))
$compileCheckOutDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadWdfControlSetupCompileCheck'))
$compileCheckIntDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadWdfControlSetupCompileCheck'))
$logsDirectory = Join-Path $artifactsRoot 'logs'
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
foreach ($path in @($formatterOutDir, $formatterIntDir, $compileCheckOutDir, $compileCheckIntDir)) {
    Remove-SelectedArtifactDirectory -Path $path -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
}
New-Item -ItemType Directory -Path $logsDirectory -Force | Out-Null

$prohibitedBefore = @(Get-ProhibitedOutputPaths -RepositoryRoot $repoRoot)
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$logPath = Join-Path $logsDirectory "chatpad-wdf-control-setup-$Configuration-$timestamp.log"
$projectPath = Join-Path $repoRoot 'tests\kernel\ChatpadWdfControlSetupCompileCheck\ChatpadWdfControlSetupCompileCheck.vcxproj'
$msbuildArguments = @(
    $projectPath,
    '/nologo',
    '/m',
    '/t:Clean;Build',
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    '/p:PreferredToolArchitecture=x64',
    "/p:RepoRoot=$repoRoot",
    '/verbosity:minimal',
    '/fileLogger',
    "/fileLoggerParameters:LogFile=$logPath;Verbosity=diagnostic;Encoding=UTF-8")

Write-Output "MSBuild: $msbuildPath"
Write-Output "Building only ChatpadWdfControlSetupCompileCheck and its formatter dependency ($Configuration|$Platform)."
$buildOutput = @(& $msbuildPath @msbuildArguments 2>&1)
$msbuildExitCode = $LASTEXITCODE
$buildOutput | Write-Output
Write-Output "MSBuild exit code: $msbuildExitCode"
Write-Output "Build log: $logPath"
if ($msbuildExitCode -ne 0) {
    exit $msbuildExitCode
}

$formatterLibraryPath = Join-Path $formatterOutDir 'ChatpadWdfControlSetup.lib'
$compileCheckLibraryPath = Join-Path $compileCheckOutDir 'ChatpadWdfControlSetupCompileCheck.lib'
foreach ($expectedPath in @($formatterLibraryPath, $compileCheckLibraryPath)) {
    if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
        throw "Expected static library not found: $expectedPath"
    }
}

$artifactsPrefix = Get-DirectoryPath -Path $artifactsRoot
$generatedFiles = @(Get-ChildItem -LiteralPath @($formatterOutDir, $formatterIntDir, $compileCheckOutDir, $compileCheckIntDir) -Recurse -File -ErrorAction SilentlyContinue)
$escapedFiles = @($generatedFiles | Where-Object {
    -not $_.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($escapedFiles.Count -ne 0) {
    throw "Formatter output escaped artifacts/: $($escapedFiles.FullName -join ', ')"
}

$prohibitedAfter = @(Get-ProhibitedOutputPaths -RepositoryRoot $repoRoot)
$newProhibited = @($prohibitedAfter | Where-Object { $prohibitedBefore -notcontains $_ })
$prohibitedInProjectOutput = @($generatedFiles | Where-Object {
    $_.Extension.ToLowerInvariant() -in @('.sys', '.inf', '.cat', '.cer', '.crt', '.pfx', '.p12', '.pvk', '.snk', '.msi', '.msix', '.appx', '.cab', '.deploy', '.zip')
})
if ($newProhibited.Count -ne 0 -or $prohibitedInProjectOutput.Count -ne 0) {
    throw "Prohibited driver, signing, package, installer, or deployment output was created: $(@($newProhibited + $prohibitedInProjectOutput.FullName) -join ', ')"
}

if (-not (Test-SigningExecution -LogPath $logPath)) {
    throw 'Active signing execution was detected in the formatter build log.'
}

Write-Output "Formatter library: $formatterLibraryPath"
Write-Output "Formatter SHA-256: $(Get-FileSha256Hash -Path $formatterLibraryPath)"
Write-Output "Compile-check library: $compileCheckLibraryPath"
Write-Output "Compile-check SHA-256: $(Get-FileSha256Hash -Path $compileCheckLibraryPath)"
Write-Output 'Signing execution scan: PASS (no SignTool or active signing task execution found).'
Write-Output 'Prohibited output scan: PASS (no .sys, INF, CAT, certificate, package, installer, or deployment output created).'
Write-Output 'Artifact containment: PASS (all formatter and compile-check outputs are beneath artifacts/).'
Write-Output 'WDF control-setup formatter guard: PASS.'
exit 0
