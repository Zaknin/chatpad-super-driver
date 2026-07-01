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

function Get-EvidenceKeyValues {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter()][switch]$AllowConflictingDuplicates
    )

    $values = @{}
    foreach ($match in [regex]::Matches(
        $Text,
        '(?m)^(?<key>[A-Za-z][A-Za-z0-9_]*(?:\[[^\]\r\n]+\])?)=(?<value>[^\r\n]*)\r?$')) {
        $key = $match.Groups['key'].Value
        if ($values.ContainsKey($key)) {
            if ([string]$values[$key] -cne $match.Groups['value'].Value.Trim()) {
                if (-not $AllowConflictingDuplicates) {
                    throw "Evidence contains conflicting machine-readable key: $key"
                }
            }
            continue
        }
        $values[$key] = $match.Groups['value'].Value.Trim()
    }
    return $values
}

function Assert-EvidenceValue {
    param(
        [Parameter(Mandatory)][hashtable]$Values,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Expected,
        [Parameter(Mandatory)][string]$EvidenceId
    )

    if (-not $Values.ContainsKey($Key) -or
        [string]$Values[$Key] -cne $Expected) {
        throw "Evidence $EvidenceId requires $Key=$Expected."
    }
}

function Get-BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($Bytes))
    }
    finally {
        $sha.Dispose()
    }
}

function Get-PeComparisonRecord {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 512 -or
        [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2) -cne 'MZ') {
        throw "A/B candidate is not a PE image: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ([System.Text.Encoding]::ASCII.GetString($bytes, $peOffset, 4) -cne "PE`0`0") {
        throw "A/B candidate has an invalid PE signature: $Path"
    }
    $optionalOffset = $peOffset + 24
    if ([BitConverter]::ToUInt16($bytes, $optionalOffset) -ne 0x20b) {
        throw "A/B candidate is not PE32+: $Path"
    }

    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $sectionCount = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
    $optionalHeaderSize = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
    $subsystem = [BitConverter]::ToUInt16($bytes, $optionalOffset + 68)
    $debugRva = [BitConverter]::ToUInt32($bytes, $optionalOffset + 160)
    $debugSize = [BitConverter]::ToUInt32($bytes, $optionalOffset + 164)
    $sectionTable = $optionalOffset + $optionalHeaderSize

    $normalized = [byte[]]$bytes.Clone()
    for ($index = 0; $index -lt 4; $index++) {
        $normalized[$peOffset + 8 + $index] = 0
        $normalized[$optionalOffset + 64 + $index] = 0
    }

    $sections = [System.Collections.Generic.List[object]]::new()
    $debugRaw = 0
    for ($sectionIndex = 0; $sectionIndex -lt $sectionCount; $sectionIndex++) {
        $offset = $sectionTable + (40 * $sectionIndex)
        $name = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 8).Trim([char]0)
        $virtualSize = [BitConverter]::ToUInt32($bytes, $offset + 8)
        $virtualAddress = [BitConverter]::ToUInt32($bytes, $offset + 12)
        $rawSize = [BitConverter]::ToUInt32($bytes, $offset + 16)
        $rawPointer = [BitConverter]::ToUInt32($bytes, $offset + 20)
        $characteristics = [BitConverter]::ToUInt32($bytes, $offset + 36)
        if ($debugRva -ge $virtualAddress -and
            $debugRva -lt ($virtualAddress + [Math]::Max($virtualSize, $rawSize))) {
            $debugRaw = $rawPointer + ($debugRva - $virtualAddress)
        }
        $rawBytes = if ($rawSize -gt 0) {
            [byte[]]$bytes[$rawPointer..($rawPointer + $rawSize - 1)]
        } else {
            [byte[]]::new(0)
        }
        $sections.Add([pscustomobject]@{
            Name = $name
            VirtualSize = [long]$virtualSize
            RawSize = [long]$rawSize
            RawPointer = [long]$rawPointer
            Characteristics = ('0x{0:X8}' -f $characteristics)
            Executable = (($characteristics -band 0x20000000) -ne 0)
            RawSha256 = Get-BytesSha256 $rawBytes
        })
    }

    if ($debugRva -ne 0 -and $debugSize -gt 0 -and $debugRaw -eq 0) {
        throw "Unable to map A/B PE debug directory: $Path"
    }
    for ($offset = $debugRaw; $debugSize -gt 0 -and $offset -lt ($debugRaw + $debugSize); $offset += 28) {
        for ($index = 0; $index -lt 4; $index++) {
            $normalized[$offset + 4 + $index] = 0
        }
        $debugType = [BitConverter]::ToUInt32($bytes, $offset + 12)
        $dataPointer = [BitConverter]::ToUInt32($bytes, $offset + 24)
        if ($debugType -eq 2 -and
            $dataPointer -gt 0 -and
            [System.Text.Encoding]::ASCII.GetString($bytes, $dataPointer, 4) -ceq 'RSDS') {
            for ($index = 0; $index -lt 16; $index++) {
                $normalized[$dataPointer + 4 + $index] = 0
            }
        }
    }

    foreach ($section in $sections) {
        $rawSize = [int]$section.RawSize
        $rawPointer = [int]$section.RawPointer
        $normalizedBytes = if ($rawSize -gt 0) {
            [byte[]]$normalized[$rawPointer..($rawPointer + $rawSize - 1)]
        } else {
            [byte[]]::new(0)
        }
        Add-Member -InputObject $section -NotePropertyName NormalizedSha256 `
            -NotePropertyValue (Get-BytesSha256 $normalizedBytes)
    }

    $metadataRows = @(
        $sections | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f
                $_.Name,
                $_.VirtualSize,
                $_.RawSize,
                $_.Characteristics
        }
    )
    $normalizedSectionRows = @(
        $sections | ForEach-Object {
            '{0}|{1}' -f $_.Name, $_.NormalizedSha256
        }
    )
    $executableSectionRows = @(
        $sections | Where-Object Executable | ForEach-Object {
            '{0}|{1}' -f $_.Name, $_.RawSha256
        }
    )

    return [pscustomobject]@{
        Size = [long]$bytes.Length
        RawSha256 = Get-BytesSha256 $bytes
        NormalizedPeSha256 = Get-BytesSha256 $normalized
        Machine = ('0x{0:X4}' -f $machine)
        Subsystem = if ($subsystem -eq 1) { 'Native' } else { [string]$subsystem }
        SectionMetadata = $metadataRows -join "`n"
        NormalizedSectionHashes = $normalizedSectionRows -join "`n"
        ExecutableSectionHashes = $executableSectionRows -join "`n"
    }
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
$evidenceFinalizationStartingCommit = 'd22867f86917a6c81574b5f82d19aacd9984b213'
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
    'candidate_containment',
    'tracked_input_set_contract',
    'ab_producer_source',
    'ab_build_debug_a',
    'ab_build_debug_b',
    'ab_build_release_a',
    'ab_build_release_b',
    'tlog_inventory_debug_a',
    'tlog_inventory_debug_b',
    'tlog_inventory_release_a',
    'tlog_inventory_release_b',
    'producer_closure_debug_a',
    'producer_closure_debug_b',
    'producer_closure_release_a',
    'producer_closure_release_b',
    'tlog_freshness_debug_a',
    'tlog_freshness_debug_b',
    'tlog_freshness_release_a',
    'tlog_freshness_release_b',
    'tlog_comparison_summary',
    'ab_input_inventory_debug_a',
    'ab_input_inventory_debug_b',
    'ab_input_inventory_release_a',
    'ab_input_inventory_release_b',
    'ab_input_comparison_debug',
    'ab_input_comparison_release',
    'ab_binary_debug_a',
    'ab_binary_debug_b',
    'ab_binary_release_a',
    'ab_binary_release_b',
    'ab_retention_debug_a',
    'ab_retention_debug_b',
    'ab_retention_release_a',
    'ab_retention_release_b',
    'ab_equivalence_debug',
    'ab_equivalence_release'
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
    if ([string]$manifest.schema_version -cne '1.4.0' -or
        [string]$manifest.checkpoint -cne 'offline-kmdf-production-orchestration-invocation' -or
        [string]$manifest.implementation_commit -cne $implementationCommit -or
        [string]$manifest.implementation_parent -cne $implementationParent -or
        [string]$manifest.implementation_branch -cne $implementationBranch -or
        [string]$manifest.remediation_starting_commit -cne $implementationCommit -or
        [string]$manifest.evidence_finalization_starting_commit -cne $evidenceFinalizationStartingCommit) {
        throw 'Manifest schema, checkpoint, implementation binding, or remediation starting commit is invalid.'
    }
    foreach ($requiredSection in @(
            'toolchain',
            'production_integration',
            'status_mapping',
            'validation',
            'binary_inspection',
            'artifacts',
            'mandatory_evidence_ids',
            'mandatory_evidence_count',
            'historical_binary_limitation',
            'ab_rebuild_contract',
            'frozen_build_input_set',
            'ab_provenance_producer',
            'evidence_entries')) {
        if ($null -eq $manifest.$requiredSection) {
            throw "Manifest missing required section: $requiredSection"
        }
    }
    if ([string]$manifest.evidence_state -notmatch 'authorized remediation changes' -or
        [string]$manifest.containing_commit_binding -notmatch 'commit that contains this manifest' -or
        [string]$manifest.self_reference_limitation -notmatch 'self-referential' -or
        [string]$manifest.historical_binary_limitation -notmatch 'no longer available.*cannot be retroactively proven' -or
        [string]$manifest.independent_audit_requirement -notmatch 'parent.*branch.*scope.*hash.*clean') {
        throw 'Manifest containing-commit, evidence-state, self-reference, or independent-audit binding is incomplete.'
    }
    $declaredMandatoryIds = @($manifest.mandatory_evidence_ids | ForEach-Object { [string]$_ })
    $duplicateDeclaredMandatoryIds = @(
        $declaredMandatoryIds | Group-Object | Where-Object { $_.Count -gt 1 }
    )
    if ([int]$manifest.mandatory_evidence_count -ne $mandatoryEvidenceIds.Count -or
        $declaredMandatoryIds.Count -ne $mandatoryEvidenceIds.Count -or
        $duplicateDeclaredMandatoryIds.Count -ne 0 -or
        (Compare-Object -ReferenceObject $mandatoryEvidenceIds -DifferenceObject $declaredMandatoryIds -SyncWindow 0)) {
        throw 'Manifest top-level mandatory evidence declaration does not exactly match the guard set and order.'
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
    if (Compare-Object -ReferenceObject $declaredMandatoryIds -DifferenceObject $entryIds -SyncWindow 0) {
        throw 'Manifest evidence entry order does not exactly match the top-level mandatory declaration.'
    }
    $requiredEntryFields = @(
        'id',
        'category',
        'path',
        'sha256',
        'result',
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
    $evidenceTextById = @{}
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
        $hasCommand = $entry.PSObject.Properties.Name -ccontains 'command' -and
            -not [string]::IsNullOrWhiteSpace([string]$entry.command)
        $hasCommands = $entry.PSObject.Properties.Name -ccontains 'commands' -and
            @($entry.commands).Count -gt 0 -and
            @($entry.commands | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0
        if ($hasCommand -eq $hasCommands) {
            $missingMetadataFields.Add("$($entry.id):exactly_one_of_command_or_commands")
        }
        if ([string]::IsNullOrWhiteSpace([string]$entry.id) -or
            [string]::IsNullOrWhiteSpace([string]$entry.category) -or
            [string]::IsNullOrWhiteSpace([string]$entry.path) -or
            [string]::IsNullOrWhiteSpace([string]$entry.result) -or
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
        if ([string]$entry.category -ceq 'tracked_contract') {
            $evidencePath = Assert-PathWithinDirectory `
                (Join-Path $repoRoot ([string]$entry.path)) `
                $repoRoot `
                "Tracked manifest evidence path $($entry.id)"
            $trackedEntry = @(Invoke-GitLines $repoRoot @('ls-files', '--', [string]$entry.path))
            if ($trackedEntry.Count -ne 1) {
                throw "Tracked manifest evidence path is not tracked: $($entry.path)"
            }
        } else {
            $evidencePath = Assert-PathWithinDirectory `
                (Join-Path $repoRoot ([string]$entry.path)) `
                $artifactsRoot `
                "Manifest evidence path $($entry.id)"
            Assert-GitIgnored $repoRoot ([string]$entry.path)
        }
        if (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
            $missingEvidenceFiles.Add([string]$entry.id)
            continue
        }
        $evidenceText = [System.IO.File]::ReadAllText($evidencePath)
        $evidenceTextById[[string]$entry.id] = $evidenceText
        if ($hasCommand) {
            if ([string]$entry.category -ceq 'ab_input_inventory') {
                $inventoryCommand = ($evidenceText | ConvertFrom-Json).generation_command
                if ([string]$inventoryCommand -cne [string]$entry.command) {
                    $missingMetadataFields.Add("$($entry.id):command_fidelity")
                }
            }
            elseif ([string]$entry.id -ceq 'repository_safety') {
                $repositoryCommand = (Get-EvidenceKeyValues $evidenceText).Command
                if ([string]$repositoryCommand -cne [string]$entry.command) {
                    $missingMetadataFields.Add("$($entry.id):command_fidelity")
                }
            }
            elseif ([string]$entry.category -in @(
                    'tracked_contract',
                    'ab_producer_source',
                    'tlog_inventory',
                    'producer_closure')) {
                # These entries are machine-readable records; dedicated checks below bind their contents.
            }
            elseif ([string]$entry.id -cne $selfEvidenceId) {
                $transcriptCommandMatch = [regex]::Match(
                    $evidenceText,
                    '(?m)^Command:\s*(?<command>.+)$')
                if (-not $transcriptCommandMatch.Success -or
                    $transcriptCommandMatch.Groups['command'].Value.Trim() -cne [string]$entry.command) {
                    $missingMetadataFields.Add("$($entry.id):command_fidelity")
                }
            }
        }
        elseif ($hasCommands) {
            $transcriptCommands = @(
                [regex]::Matches(
                    $evidenceText,
                    '(?m)^Command\[(?<index>\d+)\]:\s*(?<command>.+)$') |
                    Sort-Object { [int]$_.Groups['index'].Value } |
                    ForEach-Object { $_.Groups['command'].Value.Trim() }
            )
            if ($transcriptCommands.Count -ne @($entry.commands).Count -or
                (Compare-Object -ReferenceObject @($entry.commands) -DifferenceObject $transcriptCommands -SyncWindow 0)) {
                $missingMetadataFields.Add("$($entry.id):commands_fidelity")
            }
        }
        if ([string]$entry.category -cne 'tracked_contract') {
            $trackedEvidence = @(
                & git -C $repoRoot ls-files --error-unmatch -- ([string]$entry.path) 2>$null
            )
            if ($LASTEXITCODE -eq 0 -or $trackedEvidence.Count -ne 0) {
                throw "Manifest evidence path must be untracked: $($entry.path)"
            }
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

    $frozenInputPath = Join-Path $repoRoot ([string]$manifest.frozen_build_input_set.path)
    $frozenInput = Get-Content -LiteralPath $frozenInputPath -Raw | ConvertFrom-Json
    $frozenInputHash = (Get-FileHash -LiteralPath $frozenInputPath -Algorithm SHA256).Hash
    if ([string]$frozenInput.schema_version -cne 'chatpad-production-orchestration-frozen-build-input-set-v1' -or
        [string]$frozenInput.implementation_commit -cne $implementationCommit -or
        [int]$frozenInput.authoritative_path_count -ne 26 -or
        @($frozenInput.entries).Count -ne 26 -or
        [string]$manifest.frozen_build_input_set.sha256 -cne $frozenInputHash) {
        throw 'Frozen production/build input set contract is invalid.'
    }
    $frozenPaths = @($frozenInput.entries | ForEach-Object { [string]$_.path })
    if (@($frozenPaths | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
        throw 'Frozen production/build input set contains duplicate paths.'
    }
    foreach ($input in @($frozenInput.entries)) {
        $relativePath = [string]$input.path
        $trackedInput = @(Invoke-GitLines $repoRoot @('ls-files', '--', $relativePath))
        $implementationBlob = [string](@(Invoke-GitLines $repoRoot @('rev-parse', "$implementationCommit`:$relativePath"))[0])
        $currentPath = Join-Path $repoRoot $relativePath
        if ($trackedInput.Count -ne 1 -or
            [string]$input.implementation_blob_id -cne $implementationBlob -or
            [string]$input.sha256 -cne (Get-FileHash -LiteralPath $currentPath -Algorithm SHA256).Hash -or
            $input.tracked -ne $true) {
            throw "Frozen production/build input entry failed verification: $relativePath"
        }
    }
    foreach ($requiredFrozenPath in @(
            'src/driver/ChatpadFilter/device.c',
            'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c',
            'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj')) {
        if ($frozenPaths -cnotcontains $requiredFrozenPath) {
            throw "Frozen production/build input set is missing required path $requiredFrozenPath."
        }
    }
    if (@($frozenInput.entries | Where-Object { [string]$_.category -ceq 'prototype_inf_packaging_boundary' -and $_.packaging_only -eq $true }).Count -ne 1) {
        throw 'Frozen input set does not preserve the prototype INF packaging-only policy.'
    }
    $unsupportedPathCountText = '3' + '7'
    $unsupportedPathClaimPattern =
        '(?i)\b' + $unsupportedPathCountText + '[- ]path|\b' +
        $unsupportedPathCountText + ' paths\b|path count:\s*' +
        $unsupportedPathCountText + '|authoritative_path_count"\s*:\s*' +
        $unsupportedPathCountText
    foreach ($claimPath in @(
            'docs/OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-TLOG-PROVENANCE-REMEDIATION.md',
            'docs/PROJECT-STATE.md',
            'docs/NEXT-TASK.md',
            'docs/WORKLOG.md',
            'docs/evidence/production-orchestration-invocation-manifest.json',
            'tools/Test-ChatpadProductionOrchestrationInvocation.ps1')) {
        $claimFullPath = Join-Path $repoRoot $claimPath
        if ((Test-Path -LiteralPath $claimFullPath -PathType Leaf) -and
            [System.IO.File]::ReadAllText($claimFullPath) -match $unsupportedPathClaimPattern) {
            throw "Unsupported historical path-count claim remains in $claimPath."
        }
    }

    $producerPath = Join-Path $repoRoot ([string]$manifest.ab_provenance_producer.path)
    $producerSha = (Get-FileHash -LiteralPath $producerPath -Algorithm SHA256).Hash
    $producerBlob = [string](@(Invoke-GitLines $repoRoot @('hash-object', '--', $producerPath))[0])
    $producerTracked = @(Invoke-GitLines $repoRoot @('ls-files', '--', [string]$manifest.ab_provenance_producer.path))
    if ($producerTracked.Count -ne 1 -or
        $producerSha -cne [string]$manifest.ab_provenance_producer.sha256 -or
        $producerBlob -cne [string]$manifest.ab_provenance_producer.blob_id) {
        throw 'A/B provenance producer source identity is invalid.'
    }

    foreach ($abConfiguration in @('Debug', 'Release')) {
        foreach ($abSet in @('A', 'B')) {
            $suffix = '{0}_{1}' -f $abConfiguration.ToLowerInvariant(), $abSet.ToLowerInvariant()
            $inventoryId = "tlog_inventory_$suffix"
            $closureId = "producer_closure_$suffix"
            $freshnessId = "tlog_freshness_$suffix"
            $tlogInventory = $evidenceTextById[$inventoryId] | ConvertFrom-Json
            $closure = $evidenceTextById[$closureId] | ConvertFrom-Json
            $freshness = Get-EvidenceKeyValues $evidenceTextById[$freshnessId]
            if ([string]$tlogInventory.schema_version -cne 'chatpad-production-orchestration-raw-tlog-inventory-v1' -or
                [string]$tlogInventory.configuration -cne "$abConfiguration|x64" -or
                [string]$tlogInventory.set -cne $abSet -or
                [string]$tlogInventory.producer_sha256 -cne $producerSha -or
                [string]$tlogInventory.producer_blob_id -cne $producerBlob -or
                [int]$tlogInventory.pre_build_tlog_count -ne 0 -or
                [int]$tlogInventory.post_build_tlog_count -le 0 -or
                [int]$tlogInventory.copied_tlog_count -ne [int]$tlogInventory.post_build_tlog_count -or
                [int]$tlogInventory.hash_mismatch_count -ne 0 -or
                [int]$tlogInventory.stale_tlog_count -ne 0 -or
                [int]$tlogInventory.ignored_mismatch_count -ne 0 -or
                [int]$tlogInventory.tracked_retained_count -ne 0 -or
                [string]$tlogInventory.result -cne 'PASS') {
                throw "Raw tlog inventory $inventoryId is invalid."
            }
            foreach ($requiredFamily in @('CL.command', 'CL.read', 'CL.write', 'LINK.command', 'LINK.read', 'LINK.write', 'LIB.command', 'LIB.read', 'LIB.write')) {
                if (@($tlogInventory.families | Where-Object { [string]$_.family -ceq $requiredFamily }).Count -le 0) {
                    throw "Raw tlog inventory $inventoryId lacks family $requiredFamily."
                }
            }
            foreach ($requiredProject in @('ChatpadFilter', 'ChatpadKmdfRequestOwnerContext', 'ChatpadProtocol')) {
                if (@($tlogInventory.projects | Where-Object { [string]$_.project -ceq $requiredProject }).Count -le 0) {
                    throw "Raw tlog inventory $inventoryId lacks project $requiredProject."
                }
            }
            foreach ($tlog in @($tlogInventory.tlogs)) {
                $retainedPath = Join-Path $repoRoot ([string]$tlog.retained_path)
                if (-not (Test-Path -LiteralPath $retainedPath -PathType Leaf) -or
                    (Get-FileHash -LiteralPath $retainedPath -Algorithm SHA256).Hash -cne [string]$tlog.sha256) {
                    throw "Raw retained tlog hash verification failed for $($tlog.retained_path)."
                }
                Assert-GitIgnored $repoRoot ([string]$tlog.retained_path)
                $trackedTlog = @(Invoke-GitLines $repoRoot @('ls-files', '--', [string]$tlog.retained_path))
                if ($trackedTlog.Count -ne 0) {
                    throw "Retained raw tlog is tracked unexpectedly: $($tlog.retained_path)."
                }
            }
            Assert-EvidenceValue $freshness 'PreBuildTlogCount' '0' $freshnessId
            Assert-EvidenceValue $freshness 'HashMismatchCount' '0' $freshnessId
            Assert-EvidenceValue $freshness 'StaleTlogCount' '0' $freshnessId
            Assert-EvidenceValue $freshness 'IgnoredMismatchCount' '0' $freshnessId
            Assert-EvidenceValue $freshness 'TrackedRetainedCount' '0' $freshnessId
            Assert-EvidenceValue $freshness 'SourceAndRetainedRootsDisjoint' 'True' $freshnessId
            Assert-EvidenceValue $freshness 'Result' 'PASS' $freshnessId
            if ([string]$closure.schema_version -cne 'chatpad-production-orchestration-intermediate-producer-closure-v1' -or
                [string]$closure.configuration -cne "$abConfiguration|x64" -or
                [string]$closure.set -cne $abSet -or
                [string]$closure.producer_sha256 -cne $producerSha -or
                [string]$closure.producer_blob_id -cne $producerBlob -or
                [int]$closure.linked_object_count -le 0 -or
                [int]$closure.consuming_link_tlog_count -le 0 -or
                [int]$closure.missing_object_producer_count -ne 0 -or
                [int]$closure.stale_orphan_intermediate_count -ne 0 -or
                [string]$closure.result -cne 'PASS') {
                throw "Intermediate producer closure $closureId is invalid."
            }
            foreach ($intermediate in @($closure.generated_intermediates)) {
                if ($intermediate.producer_record_complete -ne $true -or
                    @($intermediate.command_tlogs).Count -le 0 -or
                    @($intermediate.read_tlogs).Count -le 0 -or
                    @($intermediate.write_tlogs).Count -le 0 -or
                    @($intermediate.consuming_tlogs).Count -le 0) {
                    throw "Generated intermediate lacks complete producer/consumer closure in $closureId."
                }
            }
        }
    }
    $summaryValues = Get-EvidenceKeyValues $evidenceTextById['tlog_comparison_summary']
    foreach ($summaryKey in @(
            'DebugATlogCount',
            'DebugBTlogCount',
            'ReleaseATlogCount',
            'ReleaseBTlogCount')) {
        if (-not $summaryValues.ContainsKey($summaryKey) -or [int]$summaryValues[$summaryKey] -le 0) {
            throw "Tlog comparison summary has invalid $summaryKey."
        }
    }
    Assert-EvidenceValue $summaryValues 'AllSetsFresh' 'True' 'tlog_comparison_summary'
    Assert-EvidenceValue $summaryValues 'AllClosuresComplete' 'True' 'tlog_comparison_summary'
    Assert-EvidenceValue $summaryValues 'Result' 'PASS' 'tlog_comparison_summary'

    foreach ($semanticId in @(
            'kmdf_context_semantic_debug',
            'kmdf_context_semantic_release')) {
        $semanticValues = Get-EvidenceKeyValues $evidenceTextById[$semanticId]
        foreach ($requiredKey in @(
                'SemanticChecksPassed',
                'SemanticChecksTotal',
                'Warnings',
                'Errors',
                'BuildExitCode',
                'GuardExitCode',
                'Result')) {
            if (-not $semanticValues.ContainsKey($requiredKey)) {
                throw "KMDF semantic evidence $semanticId is missing $requiredKey."
            }
        }
        $semanticPassed = [int]$semanticValues.SemanticChecksPassed
        $semanticTotal = [int]$semanticValues.SemanticChecksTotal
        if ($semanticTotal -le 0 -or
            $semanticPassed -ne $semanticTotal -or
            [int]$semanticValues.Warnings -ne 0 -or
            [int]$semanticValues.Errors -ne 0 -or
            [int]$semanticValues.BuildExitCode -ne 0 -or
            [int]$semanticValues.GuardExitCode -ne 0 -or
            [string]$semanticValues.Result -cne 'PASS') {
            throw "KMDF semantic evidence $semanticId has invalid explicit metrics."
        }
        $semanticEntry = @($evidenceEntries | Where-Object id -CEQ $semanticId)[0]
        if ([int]$semanticEntry.assertions_passed -ne $semanticPassed -or
            [int]$semanticEntry.assertions_total -ne $semanticTotal -or
            [string]$semanticEntry.metric_value -cne (
                'passed={0}; total={1}; warnings=0; errors=0; build_exit=0; guard_exit=0' -f
                    $semanticPassed,
                    $semanticTotal)) {
            throw "KMDF semantic manifest metrics do not match transcript $semanticId."
        }
    }

    $repositorySafetyValues = Get-EvidenceKeyValues $evidenceTextById.repository_safety
    foreach ($zeroKey in @(
            'DeploymentActions',
            'SigningActions',
            'PackagingActions',
            'CertificateCreationActions',
            'KeyCreationActions',
            'WindowsMutations',
            'DeviceQueries',
            'HardwareAccesses',
            'UnexpectedTrackedArtifacts',
            'TrackedEvidenceFiles',
            'NonIgnoredEvidenceFiles',
            'ExitCode')) {
        Assert-EvidenceValue $repositorySafetyValues $zeroKey '0' 'repository_safety'
    }
    Assert-EvidenceValue $repositorySafetyValues 'Result' 'PASS' 'repository_safety'
    foreach ($requiredIdentityKey in @(
            'Command',
            'ExecutionMode',
            'StartingCommit',
            'RemediationBranch',
            'GeneratedAtUtc')) {
        if (-not $repositorySafetyValues.ContainsKey($requiredIdentityKey) -or
            [string]::IsNullOrWhiteSpace([string]$repositorySafetyValues[$requiredIdentityKey])) {
            throw "Repository-safety evidence is missing $requiredIdentityKey."
        }
    }
    $repositorySafetyEntry = @(
        $evidenceEntries | Where-Object id -CEQ 'repository_safety')[0]
    $expectedSafetyMetric =
        'deployment=0; signing=0; packaging=0; certificates=0; keys=0; ' +
        'windows_mutation=0; device_query=0; hardware=0; tracked_artifacts=0; ' +
        'tracked_evidence=0; nonignored_evidence=0; exit=0'
    if ([string]$repositorySafetyEntry.metric_value -cne $expectedSafetyMetric) {
        throw 'Repository-safety manifest counters do not match the explicit transcript.'
    }

    $expectedNormalizationExclusions = @(
        'COFF.TimeDateStamp',
        'OptionalHeader.CheckSum',
        'DebugDirectory.TimeDateStamp',
        'CodeView.RSDS.Guid')
    if ([string]$manifest.ab_rebuild_contract.canonical_set -cne 'B' -or
        [string]$manifest.ab_rebuild_contract.implementation_commit -cne $implementationCommit -or
        [string]$manifest.ab_rebuild_contract.input_identity_method -notmatch 'compiler/linker tracking log closure' -or
        [int]$manifest.ab_rebuild_contract.Debug.input_count -le 8 -or
        [int]$manifest.ab_rebuild_contract.Release.input_count -le 8 -or
        (Compare-Object `
            -ReferenceObject $expectedNormalizationExclusions `
            -DifferenceObject @($manifest.ab_rebuild_contract.normalization_exclusions) `
            -SyncWindow 0)) {
        throw 'A/B rebuild contract identity or normalization exclusions are invalid.'
    }

    foreach ($abBuildId in @(
            'ab_build_debug_a',
            'ab_build_debug_b',
            'ab_build_release_a',
            'ab_build_release_b')) {
        $buildValues = Get-EvidenceKeyValues `
            $evidenceTextById[$abBuildId] `
            -AllowConflictingDuplicates
        Assert-EvidenceValue $buildValues 'ImplementationCommit' $implementationCommit $abBuildId
        Assert-EvidenceValue $buildValues 'BuildExitCode' '0' $abBuildId
        Assert-EvidenceValue $buildValues 'Result' 'PASS' $abBuildId
        foreach ($requiredBuildKey in @(
                'InputInventoryPath',
                'InputInventorySha256',
                'InputCount',
                'UnresolvedInputCount',
                'DuplicateNormalizedPathCount',
                'ConfigurationDigestSha256',
                'ToolchainDigestSha256',
                'PreBuildTlogCount',
                'PostBuildTlogCount',
                'RawTlogInventory',
                'ProducerClosure',
                'LinkedObjectProducerCount',
                'MissingObjectProducerCount',
                'TrackedStateBeforeBuild',
                'TrackedStateAfterBuild')) {
            if (-not $buildValues.ContainsKey($requiredBuildKey)) {
                throw "A/B build evidence $abBuildId is missing $requiredBuildKey."
            }
        }
        if ([int]$buildValues.InputCount -le 8 -or
            [int]$buildValues.UnresolvedInputCount -ne 0 -or
            [int]$buildValues.DuplicateNormalizedPathCount -ne 0 -or
            [int]$buildValues.PreBuildTlogCount -ne 0 -or
            [int]$buildValues.PostBuildTlogCount -le 0 -or
            [int]$buildValues.LinkedObjectProducerCount -le 0 -or
            [int]$buildValues.MissingObjectProducerCount -ne 0 -or
            [string]$buildValues.TrackedStateBeforeBuild -cne 'AllowedProducerOnly' -or
            [string]$buildValues.TrackedStateAfterBuild -cne 'AllowedProducerOnly' -or
            [string]$buildValues.InputInventorySha256 -notmatch '^[0-9A-F]{64}$' -or
            [string]$buildValues.ConfigurationDigestSha256 -notmatch '^[0-9A-F]{64}$' -or
            [string]$buildValues.ToolchainDigestSha256 -notmatch '^[0-9A-F]{64}$') {
            throw "A/B build evidence $abBuildId has invalid complete-input identity metrics."
        }
    }

    $inputInventoryCounts = @{}
    foreach ($abConfiguration in @('Debug', 'Release')) {
        foreach ($abSet in @('A', 'B')) {
            $inventoryId = 'ab_input_inventory_{0}_{1}' -f
                $abConfiguration.ToLowerInvariant(),
                $abSet.ToLowerInvariant()
            $inventoryEntry = @($evidenceEntries | Where-Object id -CEQ $inventoryId)[0]
            $inventory = $evidenceTextById[$inventoryId] | ConvertFrom-Json
            if ([string]$inventory.schema_version -cne 'chatpad-production-orchestration-ab-input-inventory-v1' -or
                [string]$inventory.configuration -cne "$abConfiguration|x64" -or
                [string]$inventory.set -cne $abSet -or
                [string]$inventory.implementation_commit -cne $implementationCommit -or
                [string]$inventory.method -notmatch 'ChatpadFilter CL/link tlogs' -or
                [string]$inventory.method -notmatch 'ChatpadKmdfRequestOwnerContext project-reference CL/lib producer tlogs' -or
                [int]$inventory.input_count -le 8 -or
                [int]$inventory.unresolved_input_count -ne 0 -or
                [int]$inventory.duplicate_normalized_path_count -ne 0 -or
                @($inventory.inputs).Count -ne [int]$inventory.input_count -or
                [string]$inventory.result -cne 'PASS') {
                throw "A/B input inventory $inventoryId is incomplete or invalid."
            }
            $normalizedPaths = @($inventory.inputs | ForEach-Object { [string]$_.normalized_path })
            if (@($normalizedPaths | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
                throw "A/B input inventory $inventoryId has duplicate normalized paths."
            }
            $requiredCategories = @(
                'build_configuration',
                'compiled_source',
                'consumed_header',
                'external_header',
                'external_library',
                'toolchain_identity')
            foreach ($requiredCategory in $requiredCategories) {
                if (@($inventory.inputs | Where-Object { [string]$_.category -ceq $requiredCategory }).Count -le 0) {
                    throw "A/B input inventory $inventoryId lacks category $requiredCategory."
                }
            }
            foreach ($input in @($inventory.inputs)) {
                if ([string]::IsNullOrWhiteSpace([string]$input.normalized_path) -or
                    [string]::IsNullOrWhiteSpace([string]$input.category) -or
                    [string]$input.sha256 -notmatch '^[0-9A-F]{64}$' -or
                    [long]$input.size -lt 0 -or
                    @($input.mechanisms).Count -le 0) {
                    throw "A/B input inventory $inventoryId has malformed input metadata."
                }
            }
            $expectedInventoryMetric = 'inputs={0}; unresolved=0; duplicates=0' -f
                [int]$inventory.input_count
            if ([string]$inventoryEntry.metric_value -cne $expectedInventoryMetric) {
                throw "A/B input inventory manifest metric does not match $inventoryId."
            }
            $inputInventoryCounts["$abConfiguration$abSet"] = [int]$inventory.input_count
        }

        if ($inputInventoryCounts["$($abConfiguration)A"] -ne $inputInventoryCounts["$($abConfiguration)B"]) {
            throw "A/B input inventory counts differ for $abConfiguration."
        }

        $comparisonId = 'ab_input_comparison_{0}' -f $abConfiguration.ToLowerInvariant()
        $comparisonValues = Get-EvidenceKeyValues $evidenceTextById[$comparisonId]
        foreach ($zeroComparisonKey in @(
                'MissingInputCount',
                'ExtraInputCount',
                'HashMismatchCount',
                'UnresolvedInputCount',
                'DuplicateNormalizedPathCount',
                'ConfigurationMismatchCount',
                'ToolchainIdentityMismatchCount')) {
            Assert-EvidenceValue $comparisonValues $zeroComparisonKey '0' $comparisonId
        }
        foreach ($trueComparisonKey in @(
                'InputPathSetsEqual',
                'InputHashesEqual',
                'BuildConfigurationEqual',
                'ToolchainIdentityEqual')) {
            Assert-EvidenceValue $comparisonValues $trueComparisonKey 'True' $comparisonId
        }
        Assert-EvidenceValue $comparisonValues 'Result' 'PASS' $comparisonId
        $comparisonEntry = @($evidenceEntries | Where-Object id -CEQ $comparisonId)[0]
        if ([string]$comparisonEntry.metric_value -cne [string]$comparisonValues.ManifestMetricValue) {
            throw "A/B input comparison manifest metric does not match retained log $comparisonId."
        }
    }

    $abRecords = @{}
    foreach ($abConfiguration in @('Debug', 'Release')) {
        foreach ($abSet in @('A', 'B')) {
            $contract = $manifest.ab_rebuild_contract.$abConfiguration.$abSet
            if ($null -eq $contract -or
                [string]$contract.path -notmatch '^artifacts/logs/production-orchestration-ab-tlog-provenance/' -or
                [string]$contract.raw_sha256 -notmatch '^[0-9A-F]{64}$' -or
                [string]$contract.normalized_pe_sha256 -notmatch '^[0-9A-F]{64}$') {
                throw "A/B rebuild contract is incomplete for $abConfiguration $abSet."
            }
            $candidatePath = Assert-PathWithinDirectory `
                (Join-Path $repoRoot ([string]$contract.path)) `
                $artifactsRoot `
                "A/B candidate $abConfiguration $abSet"
            Assert-GitIgnored $repoRoot ([string]$contract.path)
            if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
                throw "A/B candidate is missing: $candidatePath"
            }
            $record = Get-PeComparisonRecord $candidatePath
            if ($record.Size -ne [long]$contract.size -or
                $record.RawSha256 -cne [string]$contract.raw_sha256 -or
                $record.NormalizedPeSha256 -cne [string]$contract.normalized_pe_sha256 -or
                $record.Machine -cne '0x8664' -or
                $record.Subsystem -cne 'Native') {
                throw "A/B candidate contract mismatch for $abConfiguration $abSet."
            }
            $abRecords["$abConfiguration$abSet"] = $record

            $binaryEvidenceId = 'ab_binary_{0}_{1}' -f
                $abConfiguration.ToLowerInvariant(),
                $abSet.ToLowerInvariant()
            $binaryValues = Get-EvidenceKeyValues $evidenceTextById[$binaryEvidenceId]
            Assert-EvidenceValue $binaryValues 'Size' ([string]$record.Size) $binaryEvidenceId
            Assert-EvidenceValue $binaryValues 'RawSha256' $record.RawSha256 $binaryEvidenceId
            Assert-EvidenceValue `
                $binaryValues `
                'NormalizedPeSha256' `
                $record.NormalizedPeSha256 `
                $binaryEvidenceId
            Assert-EvidenceValue $binaryValues 'Machine' '0x8664' $binaryEvidenceId
            Assert-EvidenceValue $binaryValues 'Subsystem' 'Native' $binaryEvidenceId
            Assert-EvidenceValue $binaryValues 'Authenticode' 'NotSigned' $binaryEvidenceId
            Assert-EvidenceValue $binaryValues 'Result' 'PASS' $binaryEvidenceId

            $retentionEvidenceId = 'ab_retention_{0}_{1}' -f
                $abConfiguration.ToLowerInvariant(),
                $abSet.ToLowerInvariant()
            $retentionValues = Get-EvidenceKeyValues $evidenceTextById[$retentionEvidenceId]
            foreach ($retentionKey in @(
                    'OrchestrationRetention',
                    'HelperRetention',
                    'RollbackRetention',
                    'ValidatorRetention',
                    'Result')) {
                Assert-EvidenceValue $retentionValues $retentionKey 'PASS' $retentionEvidenceId
            }
            Assert-EvidenceValue `
                $retentionValues `
                'ContextSymbolCount' `
                '11' `
                $retentionEvidenceId
            Assert-EvidenceValue `
                $retentionValues `
                'ForbiddenTargetRequestOperationCount' `
                '0' `
                $retentionEvidenceId
            Assert-EvidenceValue `
                $retentionValues `
                'ForcedRetentionCount' `
                '0' `
                $retentionEvidenceId
        }

        $aRecord = $abRecords["$($abConfiguration)A"]
        $bRecord = $abRecords["$($abConfiguration)B"]
        if ($aRecord.Size -ne $bRecord.Size -or
            $aRecord.NormalizedPeSha256 -cne $bRecord.NormalizedPeSha256 -or
            $aRecord.Machine -cne $bRecord.Machine -or
            $aRecord.Subsystem -cne $bRecord.Subsystem -or
            $aRecord.SectionMetadata -cne $bRecord.SectionMetadata -or
            $aRecord.NormalizedSectionHashes -cne $bRecord.NormalizedSectionHashes -or
            $aRecord.ExecutableSectionHashes -cne $bRecord.ExecutableSectionHashes) {
            throw "A/B PE equivalence failed for $abConfiguration."
        }

        $equivalenceId = 'ab_equivalence_{0}' -f $abConfiguration.ToLowerInvariant()
        $equivalenceValues = Get-EvidenceKeyValues $evidenceTextById[$equivalenceId]
        foreach ($trueKey in @(
                'SourceInputsEqual',
                'InputPathSetsEqual',
                'InputHashesEqual',
                'BuildConfigurationEqual',
                'ToolchainIdentityEqual',
                'SizesEqual',
                'NormalizedPeHashesEqual',
                'NormalizedSectionHashesEqual',
                'ExecutableSectionHashesEqual',
                'ImportsEqual',
                'NormalizedDisassemblyEqual',
                'NormalizedSymbolSetEqual',
                'WdfReferencesEqual',
                'RetentionBoundaryEqual',
                'TargetRequestAbsenceEqual',
                'AuthenticodeEqual')) {
            Assert-EvidenceValue $equivalenceValues $trueKey 'True' $equivalenceId
        }
        Assert-EvidenceValue $equivalenceValues 'RawHashesEqual' 'False' $equivalenceId
        Assert-EvidenceValue `
            $equivalenceValues `
            'ExcludedFields' `
            ($expectedNormalizationExclusions -join ';') `
            $equivalenceId
        $equivalenceEntry = @($evidenceEntries | Where-Object id -CEQ $equivalenceId)[0]
        if (-not $equivalenceValues.ContainsKey('ManifestMetricValue') -or
            [string]$equivalenceEntry.metric_value -cne [string]$equivalenceValues.ManifestMetricValue) {
            throw "A/B equivalence manifest metric does not match retained log $equivalenceId."
        }
        Assert-EvidenceValue $equivalenceValues 'Result' 'PASS' $equivalenceId
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
        'guard/manifest/entry mandatory-ID equality and per-entry metadata checks',
        'exact single-command or ordered multi-command transcript fidelity',
        'KMDF semantic metrics and repository-safety action counters',
        'retained source-identical A/B PE and behavior-boundary equivalence',
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
    Write-Output "Guard mandatory evidence ID count: $($mandatoryEvidenceIds.Count)"
    Write-Output "Manifest declared mandatory evidence ID count: $($declaredMandatoryIds.Count)"
    Write-Output "Manifest evidence entry count: $($entryIds.Count)"
    Write-Output "Missing mandatory ID count: $($missingMandatoryIds.Count)"
    Write-Output "Unexpected evidence ID count: $($unexpectedEvidenceIds.Count)"
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
