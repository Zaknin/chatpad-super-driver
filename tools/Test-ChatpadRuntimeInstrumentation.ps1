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

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Get-DesignEvents([string]$Text) {
    $events = @{}
    foreach ($match in [regex]::Matches(
        $Text,
        '(?m)^\|\s*(?<id>\d{4})\s*\|\s*(?<name>[A-Z0-9_]+)\s*\|')) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Get-HeaderEvents([string]$Text) {
    $events = @{}
    foreach ($match in [regex]::Matches(
        $Text,
        '(?m)^\s*CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)\s*=\s*(?<id>\d{4})')) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Assert-SameMapping($Expected, $Actual, [string]$Description) {
    Assert-True ($Expected.Count -eq $Actual.Count) "$Description count mismatch."
    foreach ($key in $Expected.Keys) {
        Assert-True $Actual.Contains($key) "$Description is missing semantic ID $key."
        Assert-True ($Expected[$key] -ceq $Actual[$key]) "$Description name mismatch for $key."
    }
}

function Get-FunctionBody {
    param([string]$Text, [string]$FunctionName)
    $signature = [regex]::Match(
        $Text,
        '(?m)^\s*' + [regex]::Escape($FunctionName) + '\s*\(')
    if (-not $signature.Success) { return $null }
    $open = $Text.IndexOf('{', $signature.Index + $signature.Length)
    if ($open -lt 0) { return $null }
    $depth = 0
    for ($index = $open; $index -lt $Text.Length; ++$index) {
        if ($Text[$index] -eq '{') { $depth += 1 }
        elseif ($Text[$index] -eq '}') {
            $depth -= 1
            if ($depth -eq 0) {
                return $Text.Substring($open, $index - $open + 1)
            }
        }
    }
    return $null
}

function Get-TraceInvocations([string]$Text) {
    $calls = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Text, '(?m)\bChatpadTrace\s*\(')) {
        $start = $match.Index
        $open = $Text.IndexOf('(', $start)
        $depth = 0
        $inString = $false
        $escape = $false
        for ($index = $open; $index -lt $Text.Length; ++$index) {
            $character = $Text[$index]
            if ($inString) {
                if ($escape) { $escape = $false; continue }
                if ($character -eq '\') { $escape = $true; continue }
                if ($character -eq '"') { $inString = $false }
                continue
            }
            if ($character -eq '"') { $inString = $true; continue }
            if ($character -eq '(') { $depth += 1 }
            elseif ($character -eq ')') {
                $depth -= 1
                if ($depth -eq 0) {
                    $calls.Add($Text.Substring($start, $index - $start + 1))
                    break
                }
            }
        }
    }
    return @($calls)
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$designPath = Join-Path $repoRoot 'docs\WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md'
$headerPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadRuntimeDiagnostics.h'
$driverPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\driver.c'
$devicePath = Join-Path $repoRoot 'src\driver\ChatpadFilter\device.c'
$contextPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.c'
$filterProjectPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
$contextProjectPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj'
$inventoryPath = Join-Path $repoRoot 'docs\evidence\runtime-instrumentation-event-sites.csv'
$modelRunnerPath = Join-Path $repoRoot 'tests\offline\RuntimeInstrumentationModel\Test-RuntimeInstrumentationModel.ps1'
$modelModulePath = Join-Path $repoRoot 'tests\offline\RuntimeInstrumentationModel\RuntimeInstrumentationModel.psm1'
$orchestrationGuardPath = Join-Path $repoRoot 'tools\Test-ChatpadProductionOrchestrationInvocation.ps1'
$ownerGuardPath = Join-Path $repoRoot 'tools\Test-ChatpadProductionOwnerInitialization.ps1'

foreach ($path in @(
    $designPath, $headerPath, $driverPath, $devicePath, $contextPath,
    $filterProjectPath, $contextProjectPath, $inventoryPath,
    $modelRunnerPath, $modelModulePath, $orchestrationGuardPath, $ownerGuardPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Required path missing: $path"
}

$designEvents = Get-DesignEvents (Get-Text $designPath)
$headerText = Get-Text $headerPath
$headerEvents = Get-HeaderEvents $headerText
Assert-True ($designEvents.Count -eq 73) 'Design catalogue must contain 73 events.'
Assert-SameMapping $designEvents $headerEvents 'C catalogue'
Assert-True ($headerText -match '\{1B3D3598-9D78-4F3E-9DB2-95BB9344A731\}') 'Provider GUID string changed.'
Assert-True ($headerText -match '\(1B3D3598,9D78,4F3E,9DB2,95BB9344A731\)') 'Provider GUID tuple changed.'
Assert-True ($headerText -match 'CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION \(\(ULONG\)1u\)') 'Trace schema version changed.'

$inventory = @(Import-Csv -LiteralPath $inventoryPath)
Assert-True ($inventory.Count -eq 73) 'Event-site inventory must contain 73 rows.'
$inventoryIds = @($inventory | ForEach-Object { [int]$_.event_id })
Assert-True (($inventoryIds | Sort-Object -Unique).Count -eq 73) 'Inventory IDs must be unique.'

$sourceByRelativePath = @{
    'src/driver/ChatpadFilter/driver.c' = Get-Text $driverPath
    'src/driver/ChatpadFilter/device.c' = Get-Text $devicePath
    'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c' = Get-Text $contextPath
}
$phantomSites = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $inventory) {
    $id = [string]$entry.event_id
    Assert-True $designEvents.Contains($id) "Inventory contains unknown ID $id."
    Assert-True ([string]$entry.symbolic_name -ceq $designEvents[$id]) "Inventory name mismatch for $id."
    if (-not $sourceByRelativePath.ContainsKey([string]$entry.source_path)) {
        $phantomSites.Add("${id}:bad-path")
        continue
    }
    $body = Get-FunctionBody $sourceByRelativePath[[string]$entry.source_path] ([string]$entry.function)
    if ($null -eq $body -or
        $body -notmatch ('CHATPAD_RUNTIME_EVENT_' + [regex]::Escape([string]$entry.symbolic_name)) -or
        $body -notmatch 'Chatpad[A-Za-z0-9_]*Trace') {
        $phantomSites.Add("${id}:$($entry.function)")
    }
}
Assert-True ($phantomSites.Count -eq 0) "Phantom inventory sites: $($phantomSites -join ', ')"

$allSource = ($sourceByRelativePath.Values -join [Environment]::NewLine)
$sourceEventNames = @([regex]::Matches(
    $allSource,
    'CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)') |
    ForEach-Object { $_.Groups['name'].Value } |
    Sort-Object -Unique)
$missingInventoryCalls = @($sourceEventNames | Where-Object {
    $name = $_
    -not ($inventory | Where-Object { $_.symbolic_name -ceq $name })
})
Assert-True ($missingInventoryCalls.Count -eq 0) "Source events absent from inventory: $($missingInventoryCalls -join ', ')"

$traceCalls = @()
foreach ($text in $sourceByRelativePath.Values) {
    $traceCalls += Get-TraceInvocations $text
}
Assert-True ($traceCalls.Count -gt 0) 'No actual trace invocations were parsed.'
$sideEffectCalls = @($traceCalls | Where-Object {
    $argumentText = [regex]::Replace($_, '"(?:\\.|[^"])*"', '""')
    $argumentText -match '\+\+|--|(?<![=!<>])=(?!=)|\b(?:Interlocked[A-Za-z0-9_]*|Wdf[A-Za-z0-9_]*|ChatpadNextDeviceTraceSequence|ChatpadKmdfNextOwnerTraceSequence)\s*\('
})
Assert-True ($sideEffectCalls.Count -eq 0) 'A trace argument expression mutates state or invokes a prohibited operation.'
$unsafeFormatCalls = @($traceCalls | Where-Object { $_ -match '%(?:p|ws|wZ|Z|!)' })
Assert-True ($unsafeFormatCalls.Count -eq 0) 'Unsafe WPP field format detected.'

$spinlockTraceCount = 0
foreach ($match in [regex]::Matches(
    $allSource,
    '(?s)WdfSpinLockAcquire\s*\([^;]+;(?<region>.*?)WdfSpinLockRelease\s*\([^;]+;')) {
    if ($match.Groups['region'].Value -match 'ChatpadTrace') { $spinlockTraceCount += 1 }
}
Assert-True ($spinlockTraceCount -eq 0) 'Tracing occurs while an owner spinlock is held.'

$counterNames = @(
    'TargetDiscovery','TargetOpen','TargetAssignment','RequestFormat',
    'RequestReuse','RequestSend','Completion','Cancellation','ProtocolTraffic',
    'KeyboardInjection','D0OwnerObservation','RemovalRundownObservation')
$terminalBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTraceDeviceTerminal'
$cleanupBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadEvtDeviceContextCleanup'
foreach ($name in $counterNames) {
    Assert-True ($headerText -match [regex]::Escape($name)) "Counter field missing: $name"
    Assert-True ($cleanupBody -match [regex]::Escape($name)) "Cleanup snapshot omits $name."
}
Assert-True ($terminalBody -match 'ChatpadValidateProhibitedCounters' -and $terminalBody -match 'ChatpadEmitCounterSnapshot') 'Terminal counter validation/snapshot missing.'
Assert-True ($cleanupBody -match 'ChatpadValidateProhibitedCounters' -and
    $cleanupBody -match 'FirstTransitionMask' -and
    $cleanupBody -match 'CounterOverflowMask' -and
    $cleanupBody -match 'FinalSnapshotState' -and
    $cleanupBody -match 'StructuralReady') 'Cleanup counter/final/structural snapshot evidence missing.'

$counterEmitterBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadEmitProhibitedCounterEvent'
foreach ($id in 1701..1712) {
    $name = $designEvents[[string]$id]
    Assert-True ($counterEmitterBody -match ('CHATPAD_RUNTIME_EVENT_' + [regex]::Escape($name))) "Counter event $id has no real emitter."
}
foreach ($id in @(1308, 1310, 1801, 1802, 1804)) {
    $name = $designEvents[[string]$id]
    Assert-True ($allSource -match ('CHATPAD_RUNTIME_EVENT_' + [regex]::Escape($name))) "Required real source site missing for $id."
}

$summaryBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTraceOrchestrationReportSummary'
foreach ($field in @(
    'FunctionResult','ReportResult','FunctionReportMismatch','TerminalStage','FailedStage',
    'TerminalCategory','FirstFailureClass','MappedStatusClass','RollbackAttempted',
    'RollbackCompleted','SpinlockPresent','ReusableRequestPresent',
    'OutboundMemoryPresent','InboundMemoryPresent','ReadyAttempted','ReadyPublished',
    'ObjectGraphComplete','StructuralReady','FinalInitializationMaskClass')) {
    Assert-True ($summaryBody -match [regex]::Escape($field)) "Event 1308 field missing: $field"
}

$preContextBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTracePreContextTerminal'
Assert-True ($preContextBody -match 'CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT') 'Pre-context terminal omits event 1713.'
Assert-True (([regex]::Matches($sourceByRelativePath['src/driver/ChatpadFilter/device.c'], 'ChatpadTracePreContextTerminal\s*\(').Count -ge 3)) 'Pre-context terminal helper is not used by every pre-context failure path.'

$modelRunnerText = Get-Text $modelRunnerPath
$modelModuleText = Get-Text $modelModulePath
Assert-True (([regex]::Matches($modelRunnerText, "@\{ Name = '").Count -eq 19)) 'Executable model runner must define nineteen scenarios.'
Assert-True ($modelRunnerText -match 'Invoke-RuntimeInstrumentationScenario' -and
    $modelRunnerText -match 'Assert-Model' -and
    $modelModuleText -match 'Add-RuntimeProhibitedCounter') 'Pure-model tests are not executable state-transition tests.'

[xml]$filterProject = Get-Content -LiteralPath $filterProjectPath -Raw
[xml]$contextProject = Get-Content -LiteralPath $contextProjectPath -Raw
$filterDefinitions = @($filterProject.Project.ItemDefinitionGroup)
$contextDefinitions = @($contextProject.Project.ItemDefinitionGroup)
foreach ($config in @('Debug', 'Release')) {
    $filterNode = @($filterDefinitions | Where-Object { $_.Condition -match [regex]::Escape($config + '|x64') })
    $contextNode = @($contextDefinitions | Where-Object { $_.Condition -match [regex]::Escape($config + '|x64') })
    Assert-True ($filterNode.Count -eq 1 -and $filterNode[0].ClCompile.WppEnabled -ceq 'true') "$config filter WPP configuration missing."
    Assert-True ($contextNode.Count -eq 1 -and $contextNode[0].ClCompile.WppEnabled -ceq 'true') "$config context WPP configuration missing."
    Assert-True ([string]$filterNode[0].ClCompile.WppScanConfigurationData -match 'ChatpadRuntimeDiagnostics\.h') "$config filter WPP source missing."
    Assert-True ([string]$contextNode[0].ClCompile.WppScanConfigurationData -match 'ChatpadRuntimeDiagnostics\.h') "$config context WPP source missing."
}

$orchestrationGuardText = Get-Text $orchestrationGuardPath
$ownerGuardText = Get-Text $ownerGuardPath
Assert-True ($orchestrationGuardText -notmatch "\`$InspectionMode\s*=\s*'SourceOnly'") 'Production orchestration guard still downgrades Full mode.'
Assert-True ($orchestrationGuardText -match 'Tracked contract/inventory SHA-256 mismatch' -and
    $orchestrationGuardText -match '\$wrapperInput\.entries' -and
    $orchestrationGuardText -match '\$frozenInput\.entries') 'Production orchestration guard does not cross-bind both tracked-input contracts to retained inventory SHA-256 evidence.'
Assert-True ($sourceByRelativePath['src/driver/ChatpadFilter/device.c'] -match 'orchestrationEnumsValid\s*==\s*0u\s*\|\|\s*\r?\n\s*orchestrationResult\s*!=') 'Unexpected orchestration taxonomy does not enter the fail-closed terminal branch.'
Assert-True ($ownerGuardText -notmatch 'Instrumented final driver size or SHA-256 evidence is invalid') 'Owner guard still accepts an unbound arbitrary binary.'

$forbiddenSource = '(?i)\b(?:WdfIoTargetOpen|WdfUsbTargetDeviceCreate|WdfRequestSend|WdfRequestReuse|WdfRequestCancelSentRequest|WdfUsbTargetDeviceFormatRequestForControlTransfer|WdfRequestComplete)\b'
$prohibitedOperationCalls = @([regex]::Matches($allSource, $forbiddenSource))
Assert-True ($prohibitedOperationCalls.Count -eq 0) 'A prohibited target/request operation exists in production source.'

Write-Output 'RUNTIME INSTRUMENTATION GUARD: PASS'
Write-Output "Configuration=$Configuration"
Write-Output "Platform=$Platform"
Write-Output "ProviderGuid={1B3D3598-9D78-4F3E-9DB2-95BB9344A731}"
Write-Output 'TraceSchemaVersion=1'
Write-Output "AcceptedEventCount=$($designEvents.Count)"
Write-Output "HeaderEventCount=$($headerEvents.Count)"
Write-Output "ActualSourceSiteCount=$($inventory.Count)"
Write-Output "PhantomSiteCount=$($phantomSites.Count)"
Write-Output "TraceInvocationCount=$($traceCalls.Count)"
Write-Output "SideEffectfulTraceArgumentCount=$($sideEffectCalls.Count)"
Write-Output "TraceUnderSpinlockCount=$spinlockTraceCount"
Write-Output 'MissingCounterEventCount=0'
Write-Output 'MissingPreContextTerminalSnapshotCount=0'
Write-Output 'MissingCleanupCounterFieldCount=0'
Write-Output 'MissingReportSummaryFieldCount=0'
Write-Output 'WeakenedAcceptedGuardCount=0'
Write-Output "ProhibitedOperationCallCount=$($prohibitedOperationCalls.Count)"
Write-Output "ConfigurationCatalogueSource=$Configuration project WPP configuration plus actual production source"
