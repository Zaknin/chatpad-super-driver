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
    if (-not $fullPath.EndsWith($separator)) { $fullPath += $separator }
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

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
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

function Remove-CComments {
    param([Parameter(Mandatory)][string]$Text)
    $withoutBlocks = [regex]::Replace($Text, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($withoutBlocks, '(?m)//.*$', '')
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
        if ($trimmed -match 'skipped, due to false condition') { continue }
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

function Test-RequestOwnerContextSemanticGuards {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $contextRoot = Join-Path $RepositoryRoot 'src\driver\ChatpadKmdfRequestOwnerContext'
    $compileRoot = Join-Path $RepositoryRoot 'tests\kernel\ChatpadKmdfRequestOwnerContextCompileCheck'
    $contextHeader = Join-Path $contextRoot 'ChatpadKmdfRequestOwnerContext.h'
    $contextSource = Join-Path $contextRoot 'ChatpadKmdfRequestOwnerContext.c'
    $contextProject = Join-Path $contextRoot 'ChatpadKmdfRequestOwnerContext.vcxproj'
    $compileSource = Join-Path $compileRoot 'ChatpadKmdfRequestOwnerContextCompileCheck.c'
    $compileProject = Join-Path $compileRoot 'ChatpadKmdfRequestOwnerContextCompileCheck.vcxproj'
    $filterProject = Join-Path $RepositoryRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
    $driverRoot = Join-Path $RepositoryRoot 'src\driver\ChatpadFilter'

    $codeFiles = @($contextHeader, $contextSource, $compileSource)
    $joinedCode = ''
    foreach ($file in $codeFiles) {
        $joinedCode += "`n" + (Remove-CComments ([System.IO.File]::ReadAllText($file)))
    }

    $prohibitedCalls = '(?<![A-Za-z0-9_])(?:WdfDeviceCreate|WdfRequestCreate|WdfMemoryCreate|WdfMemoryCreatePreallocated|WdfObjectAllocateContext|WdfObjectDelete|WdfObjectReference|WdfObjectDereference|WdfSpinLockCreate|WdfWaitLockCreate|WdfUsbTargetDeviceCreate|WdfUsbTargetDeviceCreateWithParameters|WdfUsbTargetDeviceFormatRequestForControlTransfer|WdfIoTargetFormatRequestForInternalIoctlOthers|WdfRequestReuse|WdfRequestSend|WdfRequestCancelSentRequest|WdfRequestSetCompletionRoutine|WdfIoTargetStart|WdfIoTargetStop|IoCallDriver)\s*\('
    if ($joinedCode -match $prohibitedCalls) {
        throw "Prohibited WDF/WDM runtime call exists in context code: $($Matches[0])"
    }

    $prohibitedRuntimeSurface = '(?<![A-Za-z0-9_])(?:IoBuildDeviceIoControlRequest|URB|IOCTL|HidD_[A-Za-z0-9_]+|SetupDi[A-Za-z0-9_]+|CM_[A-Za-z0-9_]+|CreateFile|DeviceIoControl|malloc|calloc|realloc|free|HeapAlloc|LocalAlloc|VirtualAlloc|ExAllocatePool|ExAllocatePool2|ExFreePool|KeDelayExecutionThread|KeWaitForSingleObject)\b'
    if ($joinedCode -match $prohibitedRuntimeSurface) {
        throw "Prohibited allocation, installation, device-query, wait, IOCTL, HID, or USB runtime surface exists: $($Matches[0])"
    }

    if ($joinedCode -match '(?is)0x90u?.{0,32}0x00u?|90\s+00') {
        throw 'Prohibited unconfirmed 90 00 payload text exists in context code.'
    }
    if ($joinedCode -match '(?m)^ChatpadKmdfActivationRequestOwner\s+[A-Za-z_][A-Za-z0-9_]*\s*(?:=|;)') {
        throw 'A file-scope mutable request-owner instance exists.'
    }
    if ($joinedCode -match '(?m)\[[ \t]*\]') {
        throw 'A flexible array member or unspecified array bound exists.'
    }
    if ($joinedCode -notmatch '#include\s+"ChatpadRequestOwnerModel\.h"' -or
        $joinedCode -notmatch 'ChatpadActivationRequestOwner\s+Model' -or
        $joinedCode -notmatch 'ChatpadTransportOperationToken\s+OperationToken') {
        throw 'Context definitions do not reuse authoritative portable model and token types.'
    }
    if ($joinedCode -notmatch 'CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY\s+CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY\s+\(\(uint16_t\)2u\)' -or
        $joinedCode -notmatch 'C_ASSERT\(CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY == 2u\)' -or
        $joinedCode -notmatch 'C_ASSERT\(CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY == 2u\)') {
        throw 'Exact two-byte outbound/inbound capacity invariants are missing.'
    }
    if ($joinedCode -match 'ChatpadBuildActivationRequest|ChatpadGetActivationSequenceStep|\{[ \t\r\n]*0x[0-9A-Fa-f]+') {
        throw 'Context code duplicates activation sequence/setup construction instead of reusing preparation/model types.'
    }
    if ($joinedCode -notmatch 'WDF_DECLARE_CONTEXT_TYPE_WITH_NAME' -or
        $joinedCode -notmatch 'WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE' -or
        $joinedCode -notmatch 'WDF_OBJECT_ATTRIBUTES_INIT') {
        throw 'Typed context declaration or ordinary attribute initialization is missing.'
    }
    $requiredAttributeHelpers = @(
        'ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes',
        'ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes',
        'ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes',
        'ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes')
    foreach ($helper in $requiredAttributeHelpers) {
        if ($joinedCode -notmatch [regex]::Escape($helper)) {
            throw "Required object-attribute preparation helper is missing: $helper"
        }
    }
    if ($joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_ATTRIBUTES' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_DEVICE_PARENT' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_REQUEST_PARENT') {
        throw 'Typed attribute-preparation argument failures are incomplete.'
    }
    if ([regex]::Matches($joinedCode, 'attributes->ParentObject\s*=\s*device').Count -ne 2 -or
        [regex]::Matches($joinedCode, 'attributes->ParentObject\s*=\s*request').Count -ne 1) {
        throw 'Attribute helpers do not encode exactly two device-parented builders and one shared request-parented memory builder.'
    }
    if ([regex]::Matches($joinedCode, 'attributes->SynchronizationScope\s*=\s*WdfSynchronizationScopeNone').Count -ne 3) {
        throw 'Attribute helpers do not explicitly disable automatic synchronization for lock, request, and shared memory preparation.'
    }
    if ($joinedCode -match 'attributes->ExecutionLevel\s*=' -or
        $joinedCode -match 'attributes->Evt(?:Cleanup|Destroy)Callback\s*=') {
        throw 'Attribute helpers override inherited execution level or register a cleanup/destroy callback.'
    }
    if ($joinedCode -notmatch '(?s)WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE\s*\(\s*attributes\s*,\s*ChatpadKmdfActivationRequestContext\s*\)') {
        throw 'Activation-request attributes do not attach the typed request context.'
    }
    foreach ($helper in $requiredAttributeHelpers) {
        $compileInvocation = [regex]::Escape($helper) + '\s*\('
        if ((Remove-CComments ([System.IO.File]::ReadAllText($compileSource))) -notmatch $compileInvocation) {
            throw "Compile-check does not exercise the attribute helper signature: $helper"
        }
    }
    if ($joinedCode -notmatch 'ChatpadKmdfRequestOwnerInitializeStorage' -or
        $joinedCode -notmatch 'ChatpadKmdfRequestOwnerValidatePreObjectState' -or
        $joinedCode -notmatch 'ChatpadRequestOwnerInitialize\s*\(' -or
        $joinedCode -notmatch 'ChatpadRequestOwnerValidateInvariant\s*\(' -or
        $joinedCode -notmatch 'ChatpadRequestOwnerGetSnapshot\s*\(') {
        throw 'Storage initialization and pre-object validation do not reuse the authoritative pure owner model.'
    }
    if ($joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_FRAMEWORK_HANDLE_PRESENT' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ACTIVE_OPERATION_OR_LIFECYCLE' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ALREADY_INITIALIZED') {
        throw 'Typed storage initialization/validation result coverage is incomplete.'
    }
    if ($joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_PRE_OBJECT_READY' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NO_FRAMEWORK_HANDLES' -or
        $joinedCode -notmatch 'CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_BASELINE') {
        throw 'Pre-object validation invariant mask coverage is incomplete.'
    }
    if ($joinedCode -notmatch 'owner->Request\s*=\s*NULL' -or
        $joinedCode -notmatch 'owner->OutboundMemory\s*=\s*NULL' -or
        $joinedCode -notmatch 'owner->InboundMemory\s*=\s*NULL' -or
        $joinedCode -notmatch 'owner->BookkeepingLock\s*=\s*NULL') {
        throw 'Storage initialization does not explicitly leave every WDF handle null.'
    }
    if ($joinedCode -notmatch 'RtlZeroMemory\(&owner->TransferStorage' -or
        $joinedCode -notmatch 'RtlZeroMemory\(&owner->CompletionSnapshot') {
        throw 'Storage initialization does not explicitly clear transfer storage and completion snapshot storage.'
    }
    if ($joinedCode -match 'InitializationMask\s*(?:=|\|=)\s*[^;\r\n]*CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY') {
        throw 'Storage initialization sets owner-ready before any WDF object creation checkpoint exists.'
    }
    $contextSourceText = Remove-CComments ([System.IO.File]::ReadAllText($contextSource))
    $maskAssignments = [regex]::Matches($contextSourceText, 'InitializationMask\s*=\s*(CHATPAD_KMDF_REQUEST_OWNER_INIT_[A-Z_]+)')
    $allowedMaskAssignments = @(
        'CHATPAD_KMDF_REQUEST_OWNER_INIT_NONE',
        'CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY',
        'CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED')
    foreach ($assignment in $maskAssignments) {
        $assignedValue = $assignment.Groups[1].Value
        if ($allowedMaskAssignments -notcontains $assignedValue) {
            throw "Storage initialization assigns a non-pre-object initialization state: $assignedValue"
        }
    }
    if ($joinedCode -notmatch 'CHATPAD_REQUEST_OWNER_INVALID_GENERATION' -or
        $joinedCode -notmatch 'CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE' -or
        $joinedCode -notmatch 'CHATPAD_REQUEST_OWNER_INVALID_STEP') {
        throw 'Pre-object validation does not use authoritative invalid identity constants.'
    }

    [xml]$contextXml = Get-Content -LiteralPath $contextProject -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager($contextXml.NameTable)
    $ns.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $contextCompiles = @($contextXml.SelectNodes('//msb:ClCompile[@Include]', $ns) | ForEach-Object { $_.Include })
    $contextRefs = @($contextXml.SelectNodes('//msb:ProjectReference', $ns))
    if ($contextCompiles.Count -ne 1 -or $contextCompiles[0] -cne 'ChatpadKmdfRequestOwnerContext.c' -or $contextRefs.Count -ne 0) {
        throw 'Context project must compile exactly one context source and have no project references.'
    }

    [xml]$compileXml = Get-Content -LiteralPath $compileProject -Raw
    $compileNs = New-Object System.Xml.XmlNamespaceManager($compileXml.NameTable)
    $compileNs.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $compileCompiles = @($compileXml.SelectNodes('//msb:ClCompile[@Include]', $compileNs) | ForEach-Object { $_.Include })
    if ($compileCompiles -notcontains '..\..\..\src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.c' -or
        $compileCompiles -notcontains '..\..\..\src\transport\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.c') {
        throw 'Compile-check project does not compile the shared context source and pure model source.'
    }

    [xml]$filterXml = Get-Content -LiteralPath $filterProject -Raw
    $filterNs = New-Object System.Xml.XmlNamespaceManager($filterXml.NameTable)
    $filterNs.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $filterItems = @($filterXml.SelectNodes('//*[@Include]', $filterNs) | ForEach-Object { $_.Include })
    $filterRefs = @($filterXml.SelectNodes('//msb:ProjectReference', $filterNs))
    $filterAdditionalOptions = @($filterXml.SelectNodes('//msb:Link/msb:AdditionalOptions', $filterNs) | ForEach-Object { $_.'#text' })
    if (($filterItems -match 'ChatpadKmdfRequestOwnerContext').Count -ne 0 -or
        $filterRefs.Count -ne 0 -or
        (($filterAdditionalOptions -join "`n") -match 'ChatpadKmdf')) {
        throw 'ChatpadFilter project includes, references, links, or retains the context module.'
    }

    $activeDriverMatches = @(
        Get-ChildItem -LiteralPath $driverRoot -File -ErrorAction Stop |
            Where-Object { $_.Extension -in @('.c', '.h') } |
            ForEach-Object {
                $stripped = Remove-CComments ([System.IO.File]::ReadAllText($_.FullName))
                if ($stripped -match 'ChatpadKmdfRequestOwnerContext|ChatpadKmdfActivationRequestOwner|ChatpadKmdfGetActivationRequestContext') {
                    $_.FullName
                }
            })
    if ($activeDriverMatches.Count -ne 0) {
        throw "Active ChatpadFilter source references the context module: $($activeDriverMatches -join ', ')"
    }

    Write-Output 'Semantic guard: PASS (exact object parentage attributes, typed request context, no callbacks/automatic synchronization, storage initialization, pre-object validation, no WDF object creation/submission, no runtime driver linkage).'
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

Test-RequestOwnerContextSemanticGuards -RepositoryRoot $repoRoot

$detectorPath = Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1'
$detectorOutput = @(& $detectorPath 2>&1)
$detectorExitCode = $LASTEXITCODE
$detectorOutput | Write-Output
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) { exit $detectorExitCode }

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) | Select-Object -Unique
$vswherePath = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $vswherePath) { throw 'vswhere.exe was not found.' }

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
if (-not $msbuildPath) { throw 'No VS 2022 MSBuild installation with x64 WDK integration was found.' }

$artifactsRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($repoRoot, 'artifacts'))
$contextOutDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadKmdfRequestOwnerContext'))
$contextIntDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadKmdfRequestOwnerContext'))
$compileOutDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadKmdfRequestOwnerContextCompileCheck'))
$compileIntDir = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadKmdfRequestOwnerContextCompileCheck'))
$logsDirectory = Join-Path $artifactsRoot 'logs'
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
foreach ($path in @($contextOutDir, $contextIntDir, $compileOutDir, $compileIntDir)) {
    Remove-SelectedArtifactDirectory -Path $path -RepositoryRoot $repoRoot -ArtifactsRoot $artifactsRoot
}
New-Item -ItemType Directory -Path $logsDirectory -Force | Out-Null

$prohibitedBefore = @(Get-ProhibitedOutputPaths -RepositoryRoot $repoRoot)
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$logPath = Join-Path $logsDirectory "chatpad-kmdf-request-owner-context-$Configuration-$timestamp.log"
$projectPath = Join-Path $repoRoot 'tests\kernel\ChatpadKmdfRequestOwnerContextCompileCheck\ChatpadKmdfRequestOwnerContextCompileCheck.vcxproj'
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
Write-Output "Building only ChatpadKmdfRequestOwnerContextCompileCheck and its context dependency ($Configuration|$Platform)."
$buildOutput = @(& $msbuildPath @msbuildArguments 2>&1)
$msbuildExitCode = $LASTEXITCODE
$buildOutput | Write-Output
Write-Output "MSBuild exit code: $msbuildExitCode"
Write-Output "Build log: $logPath"
if ($msbuildExitCode -ne 0) { exit $msbuildExitCode }

$contextLibraryPath = Join-Path $contextOutDir 'ChatpadKmdfRequestOwnerContext.lib'
$compileLibraryPath = Join-Path $compileOutDir 'ChatpadKmdfRequestOwnerContextCompileCheck.lib'
foreach ($expectedPath in @($contextLibraryPath, $compileLibraryPath)) {
    if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
        throw "Expected static library not found: $expectedPath"
    }
}

$artifactsPrefix = Get-DirectoryPath -Path $artifactsRoot
$generatedFiles = @(Get-ChildItem -LiteralPath @($contextOutDir, $contextIntDir, $compileOutDir, $compileIntDir) -Recurse -File -ErrorAction SilentlyContinue)
$escapedFiles = @($generatedFiles | Where-Object {
    -not $_.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)
})
if ($escapedFiles.Count -ne 0) {
    throw "Context output escaped artifacts/: $($escapedFiles.FullName -join ', ')"
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
    throw 'Active signing execution was detected in the context compile-check build log.'
}

Write-Output "Context library: $contextLibraryPath"
Write-Output "Context library SHA-256: $(Get-FileSha256Hash -Path $contextLibraryPath)"
Write-Output "Compile-check library: $compileLibraryPath"
Write-Output "Compile-check SHA-256: $(Get-FileSha256Hash -Path $compileLibraryPath)"
Write-Output 'Signing execution scan: PASS (no SignTool or active signing task execution found).'
Write-Output 'Prohibited output scan: PASS (no .sys, INF, CAT, certificate, package, installer, or deployment output created).'
Write-Output 'Artifact containment: PASS (all context compile-check outputs are beneath artifacts/).'
Write-Output 'KMDF request-owner context compile-check guard: PASS.'
exit 0
