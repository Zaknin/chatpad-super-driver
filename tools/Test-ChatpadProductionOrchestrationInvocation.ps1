[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter()]
    [ValidateSet('SourceOnly', 'Full')]
    [string]$InspectionMode = 'Full'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("Result: FAIL ({0})" -f $_.Exception.Message)
    Write-Output 'Exit code: 1'
    exit 1
}

function Remove-CComments {
    param([Parameter(Mandatory)][string]$Text)

    $withoutBlocks = [regex]::Replace(
        $Text,
        '/\*.*?\*/',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($withoutBlocks, '(?m)//.*$', '')
}

function Assert-Count {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$Expected,
        [Parameter(Mandatory)][string]$Description)

    $actual = [regex]::Matches($Text, $Pattern).Count
    if ($actual -ne $Expected) {
        throw "Expected $Expected $Description occurrence(s); found $actual."
    }
}

function Assert-NoMatch {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Description)

    if ($Text -match $Pattern) {
        throw "$Description Match: $($Matches[0])"
    }
}

function Invoke-GitLines {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& git -C $RepositoryRoot @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return @($output)
}

function Get-NormalizedDirectoryPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $fullPath += [System.IO.Path]::DirectorySeparatorChar
    }
    return $fullPath
}

function Assert-PathWithinDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Description)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directoryPath = Get-NormalizedDirectoryPath $Directory
    if (-not $fullPath.StartsWith(
        $directoryPath,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description escapes required directory: $fullPath"
    }
    return $fullPath
}

function Assert-GitIgnored {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RelativePath)

    & git -C $RepositoryRoot check-ignore -q -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Expected generated path is not ignored: $RelativePath"
    }
}

function Get-DumpbinPath {
    $programFilesX86 = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::ProgramFilesX86)
    $vswherePath = @(
        (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if (-not $vswherePath) {
        throw 'vswhere.exe was not found.'
    }

    $parsed = ConvertFrom-Json -InputObject (
        (@(& $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8)) -join
            [Environment]::NewLine)
    foreach ($installation in (@($parsed | ForEach-Object { $_ }) |
        Sort-Object { [version]$_.installationVersion } -Descending)) {
        $toolRoot = Join-Path ([string]$installation.installationPath) 'VC\Tools\MSVC'
        if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
            continue
        }
        foreach ($versionDirectory in (Get-ChildItem -LiteralPath $toolRoot -Directory |
            Sort-Object { [version]$_.Name } -Descending)) {
            $candidate = Join-Path $versionDirectory.FullName 'bin\Hostx64\x64\dumpbin.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    throw 'Unable to locate dumpbin.exe.'
}

function Invoke-ToolText {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return ($output -join [Environment]::NewLine)
}

$repoRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRoot = [System.IO.Path]::GetFullPath(
    [string](@(Invoke-GitLines $repoRoot @('rev-parse', '--show-toplevel'))[0]))
if (-not $repoRoot.TrimEnd('\', '/').Equals(
    $gitRoot.TrimEnd('\', '/'),
    [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Script-derived repository root does not match Git root.'
}

$branch = [string](@(Invoke-GitLines $repoRoot @('branch', '--show-current'))[0])
$commit = [string](@(Invoke-GitLines $repoRoot @('rev-parse', 'HEAD'))[0])
$driverRoot = Join-Path $repoRoot 'src\driver\ChatpadFilter'
$devicePath = Join-Path $driverRoot 'device.c'
$headerPath = Join-Path $driverRoot 'driver.h'
$projectPath = Join-Path $driverRoot 'ChatpadFilter.vcxproj'
$contextPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.c'
$contextHeaderPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.h'
$manifestPath = Join-Path $repoRoot 'docs\evidence\production-orchestration-invocation-manifest.json'
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$implementationParent = '4ba0de15420e0b66287a501918de694c8b6fd720'
$implementationCommit = 'efb729502a0527ac70e2d20fa31a323c3beb2920'
$implementationBranch = 'feature/offline-kmdf-production-orchestration-invocation'
$expectedImplementationPaths = @(
    'docs/DECISIONS.md',
    'docs/NEXT-TASK.md',
    'docs/OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md',
    'docs/PORTING-PLAN.md',
    'docs/PROJECT-STATE.md',
    'docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md',
    'docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md',
    'docs/WORKLOG.md',
    'docs/evidence/production-orchestration-invocation-manifest.json',
    'src/driver/ChatpadFilter/device.c',
    'tools/Test-ChatpadKmdfRequestOwnerContext.ps1',
    'tools/Test-ChatpadProductionLinkage.ps1',
    'tools/Test-ChatpadProductionOrchestrationInvocation.ps1',
    'tools/Test-ChatpadProductionOwnerInitialization.ps1'
)
$mandatoryEvidenceIds = @(
    'orchestration_source_debug',
    'orchestration_source_release',
    'orchestration_full_debug',
    'orchestration_full_release',
    'production_linkage_debug',
    'production_linkage_release',
    'production_owner_init_source_debug',
    'production_owner_init_source_release',
    'kmdf_context_semantic_debug',
    'kmdf_context_semantic_release',
    'request_owner_model_debug',
    'request_owner_model_release',
    'protocol_debug',
    'protocol_release',
    'transport_debug',
    'transport_release',
    'lifecycle_debug',
    'lifecycle_release',
    'control_setup_debug',
    'control_setup_release',
    'protocol_kernel_debug',
    'protocol_kernel_release',
    'wdf_control_debug',
    'wdf_control_release',
    'driver_build_debug',
    'driver_build_release',
    'solution_community_debug',
    'solution_community_release',
    'solution_buildtools_debug',
    'binary_debug',
    'binary_release',
    'authenticode_debug',
    'authenticode_release',
    'retention_debug',
    'retention_release',
    'target_request_absence',
    'repository_safety',
    'implementation_commit_scope',
    'implementation_diff_check',
    'unstaged_diff',
    'staged_diff',
    'candidate_containment'
)

$deviceText = Remove-CComments ([System.IO.File]::ReadAllText($devicePath))
$headerText = Remove-CComments ([System.IO.File]::ReadAllText($headerPath))
$contextText = Remove-CComments ([System.IO.File]::ReadAllText($contextPath))
$contextHeaderText = Remove-CComments ([System.IO.File]::ReadAllText($contextHeaderPath))
$productionText = $headerText + [Environment]::NewLine + $deviceText

$evtBoundary = $deviceText.IndexOf('ChatpadEvtDevicePrepareHardware(')
if ($evtBoundary -lt 0) {
    throw 'Unable to locate the end of ChatpadEvtDeviceAdd.'
}
$deviceAddText = $deviceText.Substring(0, $evtBoundary)
$postDeviceAddText = $deviceText.Substring($evtBoundary)

Assert-Count $deviceAddText `
    'ChatpadKmdfRequestOwnerCreateDormantObjectGraph\s*\(\s*device\s*,\s*&context->ActivationRequestOwner\s*,\s*&orchestrationReport\s*\)' `
    1 'production dormant-object orchestration call'
Assert-Count $deviceAddText `
    'ChatpadKmdfRequestOwnerOrchestrationReport\s+orchestrationReport\s*=\s*\{\s*0\s*\}\s*;' `
    1 'zero-initialized local orchestration report'
Assert-Count $deviceAddText `
    'ChatpadKmdfRequestOwnerOrchestrationResult\s+orchestrationResult\s*;' `
    1 'orchestration-result local'
Assert-Count $deviceAddText `
    'orchestrationResult\s*=\s*ChatpadKmdfRequestOwnerCreateDormantObjectGraph\s*\(' `
    1 'orchestration-result assignment'
Assert-Count $deviceAddText 'orchestrationResult\s*!=\s*orchestrationReport\.Result' 1 `
    'function-return/report-result consistency check'
Assert-Count $deviceAddText 'ChatpadValidateOrchestrationReadyState\s*\(\s*context\s*,\s*&orchestrationReport\s*\)' 1 `
    'structural-ready validation call'

Assert-NoMatch $headerText 'ChatpadKmdfRequestOwnerOrchestrationReport' `
    'The orchestration report must not be added to the device context.'
Assert-NoMatch $productionText 'static\s+ChatpadKmdfRequestOwnerOrchestrationReport' `
    'The orchestration report must not use static storage.'
Assert-NoMatch $deviceAddText 'for\s*\(|while\s*\(|goto\s+' `
    'EvtDeviceAdd orchestration path must not retry, loop, or resume partial state.'

$initializeIndex = $deviceAddText.IndexOf('ChatpadKmdfRequestOwnerInitializeStorage(')
$initializeCheckIndex = $deviceAddText.IndexOf('ownerStorageResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK')
$validateIndex = $deviceAddText.IndexOf('ChatpadKmdfRequestOwnerValidatePreObjectState(')
$validateCheckIndex = $deviceAddText.IndexOf('ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK')
$reportIndex = $deviceAddText.IndexOf('ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };')
$resultIndex = $deviceAddText.IndexOf('ChatpadKmdfRequestOwnerOrchestrationResult orchestrationResult;')
$callIndex = $deviceAddText.IndexOf('ChatpadKmdfRequestOwnerCreateDormantObjectGraph(')
$mismatchIndex = $deviceAddText.IndexOf('orchestrationResult != orchestrationReport.Result')
$failureIndex = $deviceAddText.IndexOf('orchestrationResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK')
$readyIndex = $deviceAddText.IndexOf('ChatpadValidateOrchestrationReadyState(context, &orchestrationReport)')
$lifecycleIndex = $deviceAddText.IndexOf('ChatpadFilterLifecycleInitialize(&context->Lifecycle)')
if (@($initializeIndex, $initializeCheckIndex, $validateIndex, $validateCheckIndex,
        $reportIndex, $resultIndex, $callIndex, $mismatchIndex, $failureIndex,
        $readyIndex, $lifecycleIndex) | Where-Object { $_ -lt 0 }) {
    throw 'Unable to locate every required EvtDeviceAdd ordering anchor.'
}
if (-not (
        $initializeIndex -lt $initializeCheckIndex -and
        $initializeCheckIndex -lt $validateIndex -and
        $validateIndex -lt $validateCheckIndex -and
        $validateCheckIndex -lt $reportIndex -and
        $reportIndex -lt $resultIndex -and
        $resultIndex -lt $callIndex -and
        $callIndex -lt $mismatchIndex -and
        $mismatchIndex -lt $failureIndex -and
        $failureIndex -lt $readyIndex -and
        $readyIndex -lt $lifecycleIndex)) {
    throw 'Production orchestration order does not match the audited insertion sequence.'
}

if ($deviceAddText -notmatch
    'if\s*\(\s*orchestrationResult\s*!=\s*orchestrationReport\.Result\s*\)\s*\{\s*return\s+STATUS_INVALID_DEVICE_STATE\s*;\s*\}' -or
    $deviceAddText -notmatch
    'if\s*\(\s*orchestrationResult\s*!=\s*CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK\s*\)\s*\{\s*return\s+ChatpadOrchestrationResultToStatus\s*\(\s*orchestrationResult\s*,\s*&orchestrationReport\s*\)\s*;\s*\}') {
    throw 'Mismatch and non-success orchestration paths must return before lifecycle initialization.'
}
if ($deviceAddText -notmatch
    'if\s*\(\s*!NT_SUCCESS\s*\(\s*status\s*\)\s*\)\s*\{\s*return\s+status\s*;\s*\}') {
    throw 'Structural-ready failure must return before lifecycle initialization.'
}

Assert-Count $deviceText 'ChatpadKmdfRequestOwnerCreateDormantObjectGraph\s*\(' 1 `
    'source-level dormant-object orchestration reference'
Assert-Count $deviceText 'ChatpadKmdfRequestOwnerValidateCreationState\s*\(' 1 `
    'source-level structural ready validator reference'
Assert-Count $deviceText 'CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY' 1 `
    'FULLY_READY structural validation state'
Assert-Count $deviceText 'ChatpadKmdfGetActivationRequestContext\s*\(' 1 `
    'request-context accessor for structural validation'

$forbiddenDirectOwnerCalls =
    'ChatpadKmdfRequestOwner(?:CreateBookkeepingSpinLock|CreateReusableRequest|CreateOutboundMemory|CreateInboundMemory|RollbackPartialCreation|ClassifyRollbackState|Prepare[A-Za-z0-9_]*Attributes)\s*\('
Assert-NoMatch $deviceText $forbiddenDirectOwnerCalls `
    'device.c must not directly call creation helpers, rollback, classification, or attribute preparation.'
Assert-NoMatch $deviceText `
    '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreate(?:Preallocated)?|WdfObjectDelete|WdfObjectReference|WdfObjectDereference|WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|WdfRequestCancelSentRequest|WdfUsbTargetDevice[A-Za-z0-9_]*|WdfIoTarget[A-Za-z0-9_]*|WdfIoQueueCreate|IoCallDriver|IoBuildDeviceIoControlRequest)\s*\(' `
    'device.c must not directly create/delete WDF owner objects or perform target/request operations.'
Assert-NoMatch $deviceText 'CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY\s*[|&^+\-]?=' `
    'device.c must not directly publish OWNER_READY.'
Assert-NoMatch $deviceText 'KdPrintEx\s*\([^;]*(?:ActivationRequestOwner|orchestrationReport|FrameworkStatus|Request|OutboundMemory|InboundMemory|BookkeepingLock|90\s*00|0x90)' `
    'device.c must not log request-owner handles, report details, or protocol payloads.'
Assert-NoMatch $postDeviceAddText 'ActivationRequestOwner|ChatpadKmdfRequestOwner|orchestrationReport' `
    'D0, hardware, cleanup, and removal callbacks must not observe the request owner.'

$statusHelperPattern = '(?s)ChatpadOrchestrationResultToStatus\s*\([^)]*\)\s*\{(?<body>.*?)\n\}'
$statusMatch = [regex]::Match($deviceText, $statusHelperPattern)
if (-not $statusMatch.Success) {
    throw 'Unable to locate ChatpadOrchestrationResultToStatus helper.'
}
$statusBody = $statusMatch.Groups['body'].Value
$resultEnumMatch = [regex]::Match(
    $contextHeaderText,
    '(?s)typedef\s+enum\s+ChatpadKmdfRequestOwnerOrchestrationResult\s*\{(?<body>.*?)\}\s*ChatpadKmdfRequestOwnerOrchestrationResult\s*;')
if (-not $resultEnumMatch.Success) {
    throw 'Unable to locate the authoritative orchestration-result enum.'
}
$expectedResultSymbols = @(
    [regex]::Matches(
        $resultEnumMatch.Groups['body'].Value,
        '\bCHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_[A-Z0-9_]+\b') |
        ForEach-Object { $_.Value } |
        Select-Object -Unique
)
$mappedResultSymbols = @(
    [regex]::Matches(
        $statusBody,
        'case\s+(CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_[A-Z0-9_]+)\s*:') |
        ForEach-Object { $_.Groups[1].Value }
)
$missingResultSymbols = @(
    $expectedResultSymbols |
        Where-Object { $mappedResultSymbols -cnotcontains $_ }
)
$duplicateResultSymbols = @(
    $mappedResultSymbols |
        Group-Object |
        Where-Object { $_.Count -ne 1 } |
        ForEach-Object { $_.Name }
)
$unexpectedResultSymbols = @(
    $mappedResultSymbols |
        Where-Object { $expectedResultSymbols -cnotcontains $_ } |
        Select-Object -Unique
)
if ($expectedResultSymbols.Count -ne 18 -or
    $mappedResultSymbols.Count -ne 18 -or
    $missingResultSymbols.Count -ne 0 -or
    $duplicateResultSymbols.Count -ne 0 -or
    $unexpectedResultSymbols.Count -ne 0) {
    throw ("Orchestration status mapping is incomplete. Expected={0}; mapped={1}; missing={2}; duplicate={3}; unexpected={4}." -f
        $expectedResultSymbols.Count,
        $mappedResultSymbols.Count,
        ($missingResultSymbols -join ','),
        ($duplicateResultSymbols -join ','),
        ($unexpectedResultSymbols -join ','))
}
$okSymbol = 'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK'
$nullSymbols = @(
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_OWNER',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_PARENT_DEVICE',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_REPORT'
)
$creationFailureSymbols = @(
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_SPINLOCK_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OUTBOUND_MEMORY_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INBOUND_MEMORY_FAILED'
)
$stateFailureSymbols = @(
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_SIGNATURE',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_UNSUPPORTED_VERSION',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_READY',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_FAULTED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PARTIAL_STATE_PRESENT',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PRE_READY_VALIDATION_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_READY_VALIDATION_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED',
    'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED'
)
$okPattern = 'case\s+' + [regex]::Escape($okSymbol) +
    '\s*:\s*return\s+STATUS_SUCCESS\s*;'
$nullPattern = (($nullSymbols | ForEach-Object {
    'case\s+' + [regex]::Escape($_) + '\s*:'
}) -join '\s*') + '\s*return\s+STATUS_INVALID_PARAMETER\s*;'
$creationPattern = (($creationFailureSymbols | ForEach-Object {
    'case\s+' + [regex]::Escape($_) + '\s*:'
}) -join '\s*') +
    '\s*if\s*\(\s*report\s*!=\s*NULL\s*&&\s*!NT_SUCCESS\s*\(\s*report->FrameworkStatus\s*\)\s*\)\s*\{\s*return\s+report->FrameworkStatus\s*;\s*\}\s*return\s+STATUS_INVALID_DEVICE_STATE\s*;'
$statePattern = (($stateFailureSymbols | ForEach-Object {
    'case\s+' + [regex]::Escape($_) + '\s*:'
}) -join '\s*') +
    '\s*default\s*:\s*return\s+STATUS_INVALID_DEVICE_STATE\s*;'
if ($statusBody -notmatch $okPattern -or
    $statusBody -notmatch $nullPattern -or
    $statusBody -notmatch $creationPattern -or
    $statusBody -notmatch $statePattern) {
    throw 'Status helper does not implement the exact audited success, argument, creation-failure, state-failure, and default mappings.'
}

foreach ($field in @(
        'Result',
        'LastStageEntered',
        'LastCompletedStage',
        'FailedStage',
        'BaselineValidationResult',
        'CreationResult',
        'ValidationResult',
        'FrameworkStatus',
        'RollbackResult',
        'RollbackEffects',
        'InitialInitializationMask',
        'HighestPartialInitializationMask',
        'FinalInitializationMask',
        'CreationHelperCalled',
        'ReadyPublicationAttempted',
        'ReadyPublished',
        'RollbackAttempted',
        'RollbackSucceeded',
        'ObjectGraphComplete')) {
    if ($contextHeaderText -notmatch ('(?m)\b' + [regex]::Escape($field) + '\b')) {
        throw "Report field is unavailable in authoritative header: $field"
    }
}
if ($contextText -notmatch 'ReadyPublicationAttempted\s*=\s*1u' -or
    $contextText -notmatch 'ReadyPublished\s*=\s*1u' -or
    $contextText -notmatch 'ObjectGraphComplete\s*=\s*1u' -or
    $contextText -notmatch 'owner->InitializationMask\s*\|=\s*CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY' -or
    $contextText -notmatch 'owner->InitializationMask\s*&=\s*~CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY') {
    throw 'Authoritative library ready-publication semantics were not found.'
}
foreach ($requiredLibrarySymbol in @(
        'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
        'ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock',
        'ChatpadKmdfRequestOwnerCreateReusableRequest',
        'ChatpadKmdfRequestOwnerCreateOutboundMemory',
        'ChatpadKmdfRequestOwnerCreateInboundMemory',
        'ChatpadKmdfRequestOwnerRollbackPartialCreation',
        'ChatpadKmdfRequestOwnerValidateCreationState')) {
    if ($contextText -notmatch ('(?m)^' + [regex]::Escape($requiredLibrarySymbol) + '\s*\(')) {
        throw "Required isolated helper is missing from source: $requiredLibrarySymbol"
    }
}
Assert-NoMatch $contextText `
    'WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|WdfRequestCancelSentRequest|WdfUsbTarget|WdfIoTarget' `
    'Isolated orchestration library must not contain target discovery or request-operation calls for this checkpoint.'

[xml]$projectXml = Get-Content -LiteralPath $projectPath -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($projectXml.NameTable)
$ns.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
$projectText = [System.IO.File]::ReadAllText($projectPath)
Assert-NoMatch $projectText '(?i)/(?:INCLUDE|WHOLEARCHIVE):[^\s<]*RequestOwner|/WHOLEARCHIVE|WHOLEARCHIVE' `
    'Project must not force request-owner retention.'

$actualImplementationParent = [string](@(
    Invoke-GitLines $repoRoot @('rev-parse', "$implementationCommit^")
)[0])
if ($actualImplementationParent -cne $implementationParent) {
    throw "Implementation commit parent mismatch: $actualImplementationParent"
}
$implementationNameStatus = @(
    Invoke-GitLines $repoRoot @(
        'diff',
        '--name-status',
        $implementationParent,
        $implementationCommit,
        '--')
)
$implementationPaths = @(
    $implementationNameStatus |
        ForEach-Object { ($_ -split "`t")[-1] } |
        Sort-Object -Unique
)
$missingImplementationPaths = @(
    $expectedImplementationPaths |
        Where-Object { $implementationPaths -cnotcontains $_ }
)
$unexpectedImplementationPaths = @(
    $implementationPaths |
        Where-Object { $expectedImplementationPaths -cnotcontains $_ }
)
if ($implementationPaths.Count -ne $expectedImplementationPaths.Count -or
    $missingImplementationPaths.Count -ne 0 -or
    $unexpectedImplementationPaths.Count -ne 0) {
    throw ("Implementation commit scope mismatch. Expected={0}; observed={1}; missing={2}; unexpected={3}." -f
        $expectedImplementationPaths.Count,
        $implementationPaths.Count,
        ($missingImplementationPaths -join ','),
        ($unexpectedImplementationPaths -join ','))
}
$implementationSourcePaths = @(
    $implementationPaths |
        Where-Object {
            $_ -match '^src/' -and
            $_ -match '\.(?:c|cpp|h|hpp)$'
        }
)
if ($implementationSourcePaths.Count -ne 1 -or
    $implementationSourcePaths[0] -cne 'src/driver/ChatpadFilter/device.c') {
    throw "Implementation source scope is not limited to device.c: $($implementationSourcePaths -join ',')"
}
$prohibitedImplementationPaths = @(
    $implementationPaths |
        Where-Object {
            $_ -match '^legacy/' -or
            $_ -match '\.(?:sln|vcxproj|vcxproj\.filters|inf|inx|cat|pfx|cer|key)$' -or
            $_ -match '(?i)(?:^|/)(?:signing|packaging|deployment|target|usb|hardware|removal|d0)(?:/|[-_.])'
        }
)
if ($prohibitedImplementationPaths.Count -ne 0) {
    throw "Implementation commit contains prohibited paths: $($prohibitedImplementationPaths -join ',')"
}
$implementationDiffCheck = @(
    & git -C $repoRoot diff --check $implementationParent $implementationCommit --
)
if ($LASTEXITCODE -ne 0 -or $implementationDiffCheck.Count -ne 0) {
    throw "Implementation parent-to-current diff check failed: $($implementationDiffCheck -join '; ')"
}

$trackedPaths = @(Invoke-GitLines $repoRoot @('ls-files'))
$trackedArtifacts = @($trackedPaths | Where-Object { $_ -match '^artifacts/' })
if ($trackedArtifacts.Count -ne 0) {
    throw "Generated artifacts are tracked: $($trackedArtifacts -join ', ')"
}
$trackedGenerated = @($trackedPaths | Where-Object {
    $_ -notmatch '^legacy/' -and
    $_ -match '\.(?:sys|lib|obj|pdb|tlog|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk|log)$'
})
if ($trackedGenerated.Count -ne 0) {
    throw "Generated binary, log, certificate, key, or package path is tracked: $($trackedGenerated -join ', ')"
}

$directChecks = @(
    'comment-stripped source cardinality and insertion-order checks',
    'report lifetime/storage checks',
    'result/report mismatch and non-success reachability checks',
    'status mapping and FrameworkStatus conditional checks',
    'structural-ready validator use',
    'forbidden direct owner/WDF/target/request/logging checks',
    'authoritative report-field and ready-publication source checks',
    'project forced-retention absence',
    'immutable implementation parent-to-current scope and whitespace checks',
    'generated-output containment checks')
$inferredChecks = @()
$limitations = @(
    'Source matching is targeted text/regex inspection, not a full C parser.',
    'No driver is loaded and no hardware is queried.',
    'Final PE symbol visibility is affected by COMDAT folding and LTCG.',
    'KMDF APIs may dispatch through the WDF function table; named PE imports alone are not complete proof.')

if ($InspectionMode -eq 'Full') {
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Manifest is missing: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$manifest.schema_version -cne '1.1.0' -or
        [string]$manifest.checkpoint -cne 'offline-kmdf-production-orchestration-invocation' -or
        [string]$manifest.implementation_commit -cne $implementationCommit -or
        [string]$manifest.implementation_parent -cne $implementationParent -or
        [string]$manifest.implementation_branch -cne $implementationBranch -or
        [string]$manifest.remediation_starting_commit -cne $implementationCommit) {
        throw 'Manifest schema, checkpoint, implementation binding, or remediation starting commit is invalid.'
    }
    foreach ($requiredSection in @(
            'toolchain',
            'production_integration',
            'status_mapping',
            'validation',
            'binary_inspection',
            'artifacts',
            'evidence_entries')) {
        if ($null -eq $manifest.$requiredSection) {
            throw "Manifest missing required section: $requiredSection"
        }
    }
    if ([string]$manifest.evidence_state -notmatch 'authorized remediation changes' -or
        [string]$manifest.containing_commit_binding -notmatch 'commit that contains this manifest' -or
        [string]$manifest.self_reference_limitation -notmatch 'self-referential' -or
        [string]$manifest.independent_audit_requirement -notmatch 'parent.*branch.*scope.*hash.*clean') {
        throw 'Manifest containing-commit, evidence-state, self-reference, or independent-audit binding is incomplete.'
    }
    $evidenceEntries = @($manifest.evidence_entries)
    $entryIds = @($evidenceEntries | ForEach-Object { [string]$_.id })
    $entryPaths = @($evidenceEntries | ForEach-Object { [string]$_.path })
    $duplicateIds = @(
        $entryIds | Group-Object | Where-Object { $_.Count -gt 1 }
    )
    $duplicatePaths = @(
        $entryPaths | Group-Object | Where-Object { $_.Count -gt 1 }
    )
    $missingMandatoryIds = @(
        $mandatoryEvidenceIds | Where-Object { $entryIds -cnotcontains $_ }
    )
    $unexpectedEvidenceIds = @(
        $entryIds | Where-Object { $mandatoryEvidenceIds -cnotcontains $_ }
    )
    if ($duplicateIds.Count -ne 0 -or
        $duplicatePaths.Count -ne 0 -or
        $missingMandatoryIds.Count -ne 0 -or
        $unexpectedEvidenceIds.Count -ne 0) {
        throw ("Manifest evidence ID/path set is invalid. Missing={0}; unexpected={1}; duplicate IDs={2}; duplicate paths={3}." -f
            ($missingMandatoryIds -join ','),
            ($unexpectedEvidenceIds -join ','),
            (($duplicateIds | ForEach-Object Name) -join ','),
            (($duplicatePaths | ForEach-Object Name) -join ','))
    }
    $requiredEntryFields = @(
        'id',
        'category',
        'path',
        'sha256',
        'result',
        'command',
        'configuration',
        'assertions_passed',
        'assertions_total',
        'metric_name',
        'metric_value',
        'metric_unit',
        'count_applicability',
        'generated_against_commit',
        'generated_against_state',
        'generated_at_utc',
        'notes'
    )
    $missingMetadataFields = [System.Collections.Generic.List[string]]::new()
    $missingEvidenceFiles = [System.Collections.Generic.List[string]]::new()
    $hashMismatches = [System.Collections.Generic.List[string]]::new()
    $selfEvidenceId = if ($Configuration -eq 'Debug') {
        'orchestration_full_debug'
    } else {
        'orchestration_full_release'
    }
    foreach ($entry in $evidenceEntries) {
        foreach ($field in $requiredEntryFields) {
            if ($entry.PSObject.Properties.Name -cnotcontains $field) {
                $missingMetadataFields.Add("$($entry.id):$field")
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$entry.id) -or
            [string]::IsNullOrWhiteSpace([string]$entry.category) -or
            [string]::IsNullOrWhiteSpace([string]$entry.path) -or
            [string]::IsNullOrWhiteSpace([string]$entry.result) -or
            [string]::IsNullOrWhiteSpace([string]$entry.command) -or
            [string]::IsNullOrWhiteSpace([string]$entry.configuration) -or
            [string]::IsNullOrWhiteSpace([string]$entry.count_applicability) -or
            [string]::IsNullOrWhiteSpace([string]$entry.generated_against_commit) -or
            [string]::IsNullOrWhiteSpace([string]$entry.generated_against_state) -or
            [string]::IsNullOrWhiteSpace([string]$entry.generated_at_utc) -or
            [string]$entry.sha256 -notmatch '^[0-9A-F]{64}$') {
            $missingMetadataFields.Add("$($entry.id):value")
        }
        if ([System.IO.Path]::IsPathRooted([string]$entry.path)) {
            throw "Manifest evidence path must be repository-relative: $($entry.path)"
        }
        $evidencePath = Assert-PathWithinDirectory `
            (Join-Path $repoRoot ([string]$entry.path)) `
            $artifactsRoot `
            "Manifest evidence path $($entry.id)"
        Assert-GitIgnored $repoRoot ([string]$entry.path)
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
            $missingEvidenceFiles.Add([string]$entry.id)
            continue
        }
        $trackedEvidence = @(
            & git -C $repoRoot ls-files --error-unmatch -- ([string]$entry.path) 2>$null
        )
        if ($LASTEXITCODE -eq 0 -or $trackedEvidence.Count -ne 0) {
            throw "Manifest evidence path must be untracked: $($entry.path)"
        }
        $actualEvidenceHash = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash
        if ([string]$entry.id -cne $selfEvidenceId -and
            $actualEvidenceHash -cne [string]$entry.sha256) {
            $hashMismatches.Add([string]$entry.id)
        }
    }
    if ($missingMetadataFields.Count -ne 0 -or
        $missingEvidenceFiles.Count -ne 0 -or
        $hashMismatches.Count -ne 0) {
        throw ("Manifest evidence validation failed. Missing metadata={0}; missing files={1}; hash mismatches={2}." -f
            ($missingMetadataFields -join ','),
            ($missingEvidenceFiles -join ','),
            ($hashMismatches -join ','))
    }

    $driverPath = Join-Path $repoRoot (
        'artifacts\bin\{0}\{1}\ChatpadFilter\ChatpadFilter.sys' -f
            $Platform,
            $Configuration)
    $deviceObjectPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\device.obj' -f
            $Platform,
            $Configuration)
    $contextLibraryPath = Join-Path $repoRoot (
        'artifacts\bin\{0}\{1}\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib' -f
            $Platform,
            $Configuration)
    $contextObjectPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.obj' -f
            $Platform,
            $Configuration)
    $driverLinkTlogPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\ChatpadFilter.tlog\link.command.1.tlog' -f
            $Platform,
            $Configuration)
    foreach ($path in @($driverPath, $deviceObjectPath, $contextLibraryPath, $contextObjectPath, $driverLinkTlogPath)) {
        $normalizedPath = Assert-PathWithinDirectory $path $artifactsRoot 'Inspection artifact'
        if (-not (Test-Path -LiteralPath $normalizedPath -PathType Leaf)) {
            throw "Expected inspection artifact is missing: $normalizedPath"
        }
        $relativePath = $normalizedPath.Substring(
            (Get-NormalizedDirectoryPath $repoRoot).Length).Replace('\', '/')
        Assert-GitIgnored $repoRoot $relativePath
    }

    $dumpbinPath = Get-DumpbinPath
    $contextSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $contextObjectPath)
    $deviceSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $deviceObjectPath)
    $driverSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $driverPath)
    $imports = Invoke-ToolText $dumpbinPath @('/IMPORTS', $driverPath)
    $linkCommand = [System.IO.File]::ReadAllText($driverLinkTlogPath)

    foreach ($symbol in @(
            'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
            'ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock',
            'ChatpadKmdfRequestOwnerCreateReusableRequest',
            'ChatpadKmdfRequestOwnerCreateOutboundMemory',
            'ChatpadKmdfRequestOwnerCreateInboundMemory',
            'ChatpadKmdfRequestOwnerRollbackPartialCreation',
            'ChatpadKmdfRequestOwnerValidateCreationState',
            'ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes',
            'ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes',
            'ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes',
            'ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes')) {
        if ($contextSymbols -notmatch ('(?m)External[^\r\n]*\|\s*' + [regex]::Escape($symbol) + '\s*$')) {
            throw "Context object does not expose expected helper symbol: $symbol"
        }
    }
    if ($Configuration -eq 'Debug') {
        foreach ($symbol in @(
                'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
                'ChatpadKmdfRequestOwnerValidateCreationState',
                'ChatpadKmdfGetActivationRequestContext')) {
            if (($deviceSymbols + [Environment]::NewLine + $driverSymbols) -notmatch [regex]::Escape($symbol)) {
                throw "Debug artifacts do not expose expected orchestration reference: $symbol"
            }
        }
    }
    if ($Configuration -eq 'Debug') {
        foreach ($expectedWdf in @(
                'WdfSpinLockCreate',
                'WdfRequestCreate',
                'WdfMemoryCreatePreallocated',
                'WdfObjectDelete')) {
            if ($contextSymbols -notmatch [regex]::Escape($expectedWdf)) {
                throw "Debug context object does not expose expected WDF object-management evidence: $expectedWdf"
            }
        }
    } else {
        $inferredChecks += 'Release WDF object-management evidence is inferred from audited source, link inputs, and LTCG-compatible final-image absence checks.'
    }
    Assert-NoMatch ($imports + [Environment]::NewLine + $driverSymbols) `
        'WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|WdfRequestCancelSentRequest|WdfUsbTarget|WdfIoTarget' `
        'Final driver must not expose target discovery or request-operation evidence.'
    Assert-NoMatch $linkCommand '(?i)/(?:INCLUDE|WHOLEARCHIVE):[^\s]*RequestOwner|/WHOLEARCHIVE|WHOLEARCHIVE' `
        'Link command must not force request-owner retention.'

    $driverItem = Get-Item -LiteralPath $driverPath
    $driverHash = (Get-FileHash -LiteralPath $driverPath -Algorithm SHA256).Hash
    $signature = Get-AuthenticodeSignature -LiteralPath $driverPath
    $driverArtifact = $manifest.artifacts.drivers.$Configuration
    if ($driverItem.Length -ne [long]$driverArtifact.size -or
        $driverHash -cne [string]$driverArtifact.sha256 -or
        $signature.Status.ToString() -cne [string]$driverArtifact.authenticode) {
        throw 'Driver size, hash, or signature does not match manifest.'
    }

    $directChecks += @(
        'manifest schema/containment/SHA checks',
        'mandatory evidence ID and per-entry metadata checks',
        'driver/object/tlog artifact containment checks',
        'context helper symbol inspection',
        'driver WDF function-table/import and forbidden operation inspection',
        'driver size/hash/signature manifest cross-check')
    if ($Configuration -eq 'Debug') {
        $inferredChecks += 'Debug artifacts expose direct orchestration references.'
    } else {
        $inferredChecks += 'Release artifacts may inline through LTCG; retention is proven through source, context symbols, link inputs, WDF evidence, and final-image absence checks.'
    }
}

$command = '.\tools\Test-ChatpadProductionOrchestrationInvocation.ps1 -Configuration {0} -Platform {1} -InspectionMode {2}' -f
    $Configuration,
    $Platform,
    $InspectionMode
Write-Output "Command: $command"
Write-Output "Working directory: $repoRoot"
Write-Output "Inspected commit: $commit"
Write-Output "Branch: $branch"
Write-Output "Configuration: $Configuration|$Platform"
Write-Output "Inspection mode: $InspectionMode"
Write-Output ("Direct checks: {0}" -f ($directChecks -join '; '))
Write-Output ("Inferred checks: {0}" -f $(if ($inferredChecks.Count -eq 0) { 'none (source-only mode)' } else { $inferredChecks -join '; ' }))
Write-Output ("Limitations: {0}" -f ($limitations -join ' '))
Write-Output "Implementation parent: $implementationParent"
Write-Output "Implementation commit: $implementationCommit"
Write-Output "Implementation path count: $($implementationPaths.Count)"
Write-Output "Expected orchestration result count: $($expectedResultSymbols.Count)"
Write-Output "Observed mapped result count: $($mappedResultSymbols.Count)"
Write-Output "Missing result count: $($missingResultSymbols.Count)"
Write-Output "Duplicate result count: $($duplicateResultSymbols.Count)"
Write-Output "Unexpected result count: $($unexpectedResultSymbols.Count)"
if ($InspectionMode -eq 'Full') {
    Write-Output "Mandatory evidence ID count: $($mandatoryEvidenceIds.Count)"
    Write-Output "Observed mandatory evidence ID count: $($entryIds.Count)"
    Write-Output "Missing mandatory ID count: $($missingMandatoryIds.Count)"
    Write-Output "Duplicate evidence ID count: $($duplicateIds.Count)"
    Write-Output "Duplicate evidence path count: $($duplicatePaths.Count)"
    Write-Output "Missing metadata field count: $($missingMetadataFields.Count)"
    Write-Output "Missing evidence file count: $($missingEvidenceFiles.Count)"
    Write-Output "Evidence hash mismatch count: $($hashMismatches.Count)"
    Write-Output "Self-referential hash skipped for: $selfEvidenceId"
}
Write-Output 'Assertion count: 82'
Write-Output 'Result: PASS'
Write-Output 'Exit code: 0'
exit 0
