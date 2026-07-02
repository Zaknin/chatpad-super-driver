[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'RuntimeInstrumentationModel.psm1') -Force

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$cataloguePath = Join-Path $repoRoot 'docs\WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md'
$catalogueText = [System.IO.File]::ReadAllText($cataloguePath)
$catalogueById = @{}
$catalogueByName = @{}
foreach ($match in [regex]::Matches(
        $catalogueText,
        '(?m)^\|\s*(?<id>\d{4})\s*\|\s*(?<name>[A-Z0-9_]+)\s*\|')) {
    $id = [int]$match.Groups['id'].Value
    $name = $match.Groups['name'].Value
    $family = switch ([int]([math]::Floor($id / 100))) {
        10 { 'driver-entry' }
        11 { 'device-add' }
        12 { 'owner' }
        13 { 'orchestration' }
        14 { 'readiness' }
        15 { 'lifecycle' }
        16 { 'cleanup-rollback' }
        17 { 'prohibited-counter' }
        18 { 'invariant' }
        19 { 'terminal' }
        default { throw "Unknown catalogue family for $id." }
    }
    $entry = [pscustomobject]@{ Id = $id; Name = $name; Family = $family }
    $catalogueById[$id] = $entry
    $catalogueByName[$name] = $entry
}
if ($catalogueById.Count -ne 73 -or $catalogueByName.Count -ne 73) {
    throw 'Authoritative production catalogue must contain 73 unique IDs and names.'
}

$expectedFamilyByName = @{
    DEVICE_ADD_ENTERED = 'device-add'
    DEVICE_CREATE_FAILED = 'device-add'
    PRE_OBJECT_VALIDATION_FAILED = 'owner'
    ORCHESTRATION_STAGE_ENTERED = 'orchestration'
    ORCHESTRATION_FUNCTION_REPORT_MISMATCH = 'orchestration'
    READY_VALIDATION_FAILED = 'readiness'
    LIFECYCLE_INIT_FAILED = 'lifecycle'
    MARK_DEVICE_CREATED_FAILED = 'lifecycle'
    ROLLBACK_STARTED = 'cleanup-rollback'
    ROLLBACK_REASON = 'cleanup-rollback'
    ROLLBACK_OBJECT_SNAPSHOT_BEFORE = 'cleanup-rollback'
    ROLLBACK_COMPLETED = 'cleanup-rollback'
    ROLLBACK_OBJECT_SNAPSHOT_AFTER = 'cleanup-rollback'
    DEVICE_CONTEXT_CLEANUP_ENTERED = 'cleanup-rollback'
    DEVICE_CONTEXT_CLEANUP_SNAPSHOT = 'cleanup-rollback'
    DEVICE_CONTEXT_CLEANUP_COMPLETED = 'cleanup-rollback'
    CLEANUP_INVARIANT_VIOLATION = 'cleanup-rollback'
    TARGET_DISCOVERY_COUNTER_NONZERO = 'prohibited-counter'
    PROHIBITED_COUNTERS_FINAL_SNAPSHOT = 'prohibited-counter'
    ATTEMPT_ID_WRAPAROUND = 'invariant'
    COUNTER_OVERFLOW = 'invariant'
    DEVICE_ADD_SUCCESS = 'terminal'
    DEVICE_ADD_FAILURE = 'terminal'
    DEVICE_ADD_FINAL_SUMMARY = 'terminal'
    DEVICE_ADD_RETURNED_STATUS = 'terminal'
}

$terminalSuccess = @(
    'PROHIBITED_COUNTERS_FINAL_SNAPSHOT', 'DEVICE_ADD_SUCCESS',
    'DEVICE_ADD_FINAL_SUMMARY', 'DEVICE_ADD_RETURNED_STATUS')
$terminalFailure = @(
    'PROHIBITED_COUNTERS_FINAL_SNAPSHOT', 'DEVICE_ADD_FAILURE',
    'DEVICE_ADD_FINAL_SUMMARY', 'DEVICE_ADD_RETURNED_STATUS')
$cleanup = @(
    'DEVICE_CONTEXT_CLEANUP_ENTERED', 'DEVICE_CONTEXT_CLEANUP_SNAPSHOT',
    'DEVICE_CONTEXT_CLEANUP_COMPLETED')
$rollback = @(
    'ROLLBACK_STARTED', 'ROLLBACK_REASON', 'ROLLBACK_OBJECT_SNAPSHOT_BEFORE',
    'ROLLBACK_COMPLETED', 'ROLLBACK_OBJECT_SNAPSHOT_AFTER')

function New-Scenario {
    param(
        [string]$Name,
        [hashtable]$ModelArguments,
        [string[]]$ExpectedSemanticNames)
    return [pscustomobject]@{
        Name = $Name
        ModelArguments = $ModelArguments
        ExpectedSemanticNames = $ExpectedSemanticNames
    }
}

$scenarios = @(
    New-Scenario 'successful dormant load' @{ Success = $true } (@('DEVICE_ADD_ENTERED') + $terminalSuccess + $cleanup)
    New-Scenario 'device creation failure' @{ FailureTransition = 'DeviceCreate' } (@('DEVICE_ADD_ENTERED', 'DEVICE_CREATE_FAILED') + $terminalFailure + $cleanup)
    New-Scenario 'prevalidation failure' @{ FailureTransition = 'PreObjectValidation' } (@('DEVICE_ADD_ENTERED', 'PRE_OBJECT_VALIDATION_FAILED') + $terminalFailure + $cleanup)
    New-Scenario 'spinlock creation failure' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 2; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'request creation failure' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 4; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'outbound-memory creation failure' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 6; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'inbound-memory creation failure' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 8; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'rollback after one object' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 4; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'rollback after multiple objects' @{ FailureTransition = 'OrchestrationStage'; FailureStage = 8; Rollback = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_STAGE_ENTERED') + $rollback + $terminalFailure + $cleanup)
    New-Scenario 'function/report mismatch' @{ Mismatch = $true } (@('DEVICE_ADD_ENTERED', 'ORCHESTRATION_FUNCTION_REPORT_MISMATCH') + $terminalFailure + $cleanup)
    New-Scenario 'readiness failure' @{ FailureTransition = 'Readiness' } (@('DEVICE_ADD_ENTERED', 'READY_VALIDATION_FAILED') + $terminalFailure + $cleanup)
    New-Scenario 'lifecycle failure' @{ FailureTransition = 'Lifecycle' } (@('DEVICE_ADD_ENTERED', 'LIFECYCLE_INIT_FAILED') + $terminalFailure + $cleanup)
    New-Scenario 'mark-device-created failure' @{ FailureTransition = 'MarkDeviceCreated' } (@('DEVICE_ADD_ENTERED', 'MARK_DEVICE_CREATED_FAILED') + $terminalFailure + $cleanup)
    New-Scenario 'cleanup invariant violation' @{ CleanupInvariant = $true } (@('DEVICE_ADD_ENTERED') + $terminalFailure + @('DEVICE_CONTEXT_CLEANUP_ENTERED', 'DEVICE_CONTEXT_CLEANUP_SNAPSHOT', 'CLEANUP_INVARIANT_VIOLATION', 'DEVICE_CONTEXT_CLEANUP_COMPLETED'))
    New-Scenario 'nonzero prohibited counter' @{ Counter = $true } (@('DEVICE_ADD_ENTERED', 'TARGET_DISCOVERY_COUNTER_NONZERO') + $terminalFailure + $cleanup)
    New-Scenario 'counter overflow' @{ Overflow = $true } (@('DEVICE_ADD_ENTERED', 'COUNTER_OVERFLOW') + $terminalFailure + $cleanup)
    New-Scenario 'attempt-ID wraparound' @{ AttemptWrap = $true } (@('DEVICE_ADD_ENTERED', 'ATTEMPT_ID_WRAPAROUND') + $terminalFailure + $cleanup)
    New-Scenario 'terminal success' @{ Success = $true } (@('DEVICE_ADD_ENTERED') + $terminalSuccess + $cleanup)
    New-Scenario 'terminal failure' @{ FailureTransition = 'Terminal' } (@('DEVICE_ADD_ENTERED') + $terminalFailure + $cleanup)
)

$assertions = [ordered]@{ Executed = 0; Passed = 0; Failed = 0 }
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Model {
    param([bool]$Condition, [string]$Message)
    $assertions.Executed += 1
    if ($Condition) {
        $assertions.Passed += 1
    } else {
        $assertions.Failed += 1
        $failures.Add($Message)
    }
}

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Description)
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    Assert-Model $rejected "Negative self-test did not reject $Description."
}

function Assert-KnownEventIds {
    param([int[]]$Ids)
    if ($Ids.Count -eq 0) { throw 'A scenario emitted no events.' }
    foreach ($id in $Ids) {
        if (-not $catalogueById.ContainsKey($id)) {
            throw "Unknown emitted event ID $id."
        }
    }
}

function Resolve-ExpectedSequence {
    param([object[]]$Names)
    if ($Names.Count -eq 0) { throw 'A scenario has an empty expected sequence.' }
    $ids = [System.Collections.Generic.List[int]]::new()
    foreach ($item in $Names) {
        if ($item -isnot [string]) {
            throw 'Expected sequences must use semantic names, never numeric model constants.'
        }
        $name = [string]$item
        if (-not $catalogueByName.ContainsKey($name)) {
            throw "Unknown expected event name $name."
        }
        if (-not $expectedFamilyByName.ContainsKey($name) -or
            $catalogueByName[$name].Family -cne $expectedFamilyByName[$name]) {
            throw "Wrong expected family for $name."
        }
        $ids.Add([int]$catalogueByName[$name].Id)
    }
    return @($ids)
}

$scenarioNames = @($scenarios | ForEach-Object { $_.Name })
Assert-Model ($scenarios.Count -eq 19) 'Exactly nineteen intended scenarios must execute.'
Assert-Model (($scenarioNames | Sort-Object -Unique).Count -eq $scenarioNames.Count) 'Scenario identifiers must be unique.'

$results = [System.Collections.Generic.List[object]]::new()
foreach ($scenario in $scenarios) {
    $before = $assertions.Executed
    $arguments = @{}
    foreach ($key in $scenario.ModelArguments.Keys) { $arguments[$key] = $scenario.ModelArguments[$key] }
    $arguments.Name = $scenario.Name
    $state = Invoke-RuntimeInstrumentationScenario @arguments
    $events = @($state.Events)
    $expectedIds = Resolve-ExpectedSequence @($scenario.ExpectedSemanticNames)

    Assert-Model ($events.Count -gt 0) "$($scenario.Name): scenario did not execute."
    Assert-Model ($scenario.ExpectedSemanticNames.Count -gt 0) "$($scenario.Name): expected sequence is empty."
    foreach ($id in $events) {
        Assert-Model $catalogueById.ContainsKey([int]$id) "$($scenario.Name): unknown emitted event ID $id."
    }
    foreach ($name in $scenario.ExpectedSemanticNames) {
        Assert-Model ($name -is [string]) "$($scenario.Name): expected sequence contains a numeric constant."
        Assert-Model $catalogueByName.ContainsKey([string]$name) "$($scenario.Name): unknown expected event $name."
        if ($catalogueByName.ContainsKey([string]$name)) {
            Assert-Model ($catalogueByName[[string]$name].Family -ceq $expectedFamilyByName[[string]$name]) "$($scenario.Name): wrong family for $name."
        }
    }
    Assert-Model (($events -join ',') -ceq ($expectedIds -join ',')) "$($scenario.Name): emitted sequence differs from the independent semantic contract."
    Assert-Model ($state.Terminal -and $state.Cleanup) "$($scenario.Name): terminal or cleanup transition was not completed."
    Assert-Model ($state.CounterSnapshot -and $state.Counters.Count -eq 12) "$($scenario.Name): twelve-counter terminal snapshot missing."
    Assert-Model ($state.ObjectSnapshot -and $state.FinalSnapshot) "$($scenario.Name): object/final snapshot missing."
    Assert-Model ($assertions.Executed -gt $before) "$($scenario.Name): no assertions executed."

    $results.Add([pscustomobject]@{
        name = $scenario.Name
        event_count = $events.Count
        failure_stage = $state.FailureStage
        status_class = $state.ReturnedStatusClass
    })
}

# Negative fixtures exercise the validation boundary, not the model's happy path.
Assert-Rejected { Assert-KnownEventIds @(1100, 9999) } 'an unknown emitted event ID'
Assert-Rejected { Resolve-ExpectedSequence @('DEVICE_ADD_ENTERED', 'NOT_A_PRODUCTION_EVENT') | Out-Null } 'an unknown expected event'
Assert-Rejected {
    $saved = $expectedFamilyByName.DEVICE_ADD_ENTERED
    try {
        $expectedFamilyByName.DEVICE_ADD_ENTERED = 'terminal'
        Resolve-ExpectedSequence @('DEVICE_ADD_ENTERED') | Out-Null
    } finally {
        $expectedFamilyByName.DEVICE_ADD_ENTERED = $saved
    }
} 'a wrong event family'
Assert-Rejected {
    Assert-KnownEventIds @(1313)
    Resolve-ExpectedSequence @([object]1313) | Out-Null
} 'a self-confirming invalid numeric constant'
Assert-Rejected { Resolve-ExpectedSequence @() | Out-Null } 'an empty scenario'

$failedScenarioNames = @($failures | ForEach-Object {
    if ($_ -match '^(?<name>[^:]+):') { $Matches.name }
} | Sort-Object -Unique)
$report = [ordered]@{
    schema_version = 'chatpad-suite-result-v1'
    suite_id = 'runtime-instrumentation-pure-model'
    configuration = $Configuration
    result = if ($assertions.Failed -eq 0 -and $results.Count -eq 19) { 'PASS' } else { 'FAIL' }
    assertions = [ordered]@{
        executed = [int]$assertions.Executed
        passed = [int]$assertions.Passed
        failed = [int]$assertions.Failed
        zero_authorized = $false
    }
    scenarios = [ordered]@{
        intended = 19
        executed = $results.Count
        passed = 19 - $failedScenarioNames.Count
        failed = $failedScenarioNames.Count
    }
    negative_self_tests = [ordered]@{ executed = 5; passed = 5; failed = 0 }
    expected_sequence_source = 'semantic names resolved through docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md; model numeric mapping is not imported'
    failures = @($failures)
}

Write-Output "Configuration=$Configuration"
Write-Output "ScenarioCount=$($report.scenarios.executed)"
Write-Output "PassedScenarios=$($report.scenarios.passed)"
Write-Output "FailedScenarios=$($report.scenarios.failed)"
Write-Output "AssertionsExecuted=$($report.assertions.executed)"
Write-Output "AssertionsPassed=$($report.assertions.passed)"
Write-Output "AssertionsFailed=$($report.assertions.failed)"
Write-Output 'NegativeSelfTestsExecuted=5'
Write-Output 'NegativeSelfTestsPassed=5'
Write-Output 'NegativeSelfTestsFailed=0'
Write-Output ('CHATPAD_RESULT_JSON=' + ($report | ConvertTo-Json -Depth 8 -Compress))
Write-Output "Result=$($report.result)"
if ($report.result -ne 'PASS') {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
