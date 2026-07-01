[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'RuntimeInstrumentationModel.psm1') -Force

$script:AssertionCount = 0
function Assert-Model {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message)
    $script:AssertionCount += 1
    if (-not $Condition) {
        throw $Message
    }
}

$scenarios = @(
    @{ Name = 'successful dormant load'; Success = $true },
    @{ Name = 'device creation failure'; FailureEvent = 1102 },
    @{ Name = 'prevalidation failure'; FailureEvent = 1204 },
    @{ Name = 'spinlock creation failure'; FailureEvent = 1312; Rollback = $true },
    @{ Name = 'request creation failure'; FailureEvent = 1313; Rollback = $true },
    @{ Name = 'outbound-memory creation failure'; FailureEvent = 1314; Rollback = $true },
    @{ Name = 'inbound-memory creation failure'; FailureEvent = 1315; Rollback = $true },
    @{ Name = 'rollback after one object'; FailureEvent = 1313; Rollback = $true },
    @{ Name = 'rollback after multiple objects'; FailureEvent = 1315; Rollback = $true },
    @{ Name = 'function/report mismatch'; Mismatch = $true },
    @{ Name = 'readiness failure'; FailureEvent = 1402 },
    @{ Name = 'lifecycle failure'; FailureEvent = 1407 },
    @{ Name = 'mark-device-created failure'; FailureEvent = 1410 },
    @{ Name = 'cleanup invariant violation'; Invariant = $true },
    @{ Name = 'nonzero prohibited counter'; Counter = $true },
    @{ Name = 'counter overflow'; Overflow = $true },
    @{ Name = 'attempt-ID wraparound'; AttemptWrap = $true },
    @{ Name = 'terminal success'; Success = $true },
    @{ Name = 'terminal failure'; FailureEvent = 1303 }
)

$results = [System.Collections.Generic.List[object]]::new()
foreach ($scenario in $scenarios) {
    $arguments = @{}
    foreach ($key in $scenario.Keys) {
        $arguments[$key] = $scenario[$key]
    }
    $state = Invoke-RuntimeInstrumentationScenario @arguments
    $events = @($state.Events)
    $expectsRollback = $scenario.ContainsKey('Rollback') -and [bool]$scenario.Rollback
    $expectsOverflow = $scenario.ContainsKey('Overflow') -and [bool]$scenario.Overflow
    $expectsCounter = $scenario.ContainsKey('Counter') -and [bool]$scenario.Counter
    $expectsSuccess = $scenario.ContainsKey('Success') -and [bool]$scenario.Success
    $terminalId = if ($state.ReturnedStatusClass -eq 1) { 1900 } else { 1901 }
    $terminalIndex = [array]::IndexOf($events, $terminalId)
    $returnedIndex = [array]::IndexOf($events, 1903)
    $cleanupEnteredIndex = [array]::IndexOf($events, 1600)
    $cleanupCompletedIndex = [array]::IndexOf($events, 1602)

    $expectedEvents = [System.Collections.Generic.List[int]]::new()
    $expectedEvents.Add(1100)
    if ($scenario.ContainsKey('AttemptWrap') -and [bool]$scenario.AttemptWrap) { $expectedEvents.Add(1800) }
    if ($scenario.ContainsKey('Mismatch') -and [bool]$scenario.Mismatch) { $expectedEvents.Add(1307) }
    if ($scenario.ContainsKey('Invariant') -and [bool]$scenario.Invariant) { $expectedEvents.Add(1603) }
    if ($expectsCounter) { $expectedEvents.Add(1701) }
    if ($expectsOverflow) { $expectedEvents.Add(1804) }
    if ($expectsRollback) {
        $expectedEvents.Add(1500)
        $expectedEvents.Add(1501)
        $expectedEvents.Add(1503)
    }
    if ($scenario.ContainsKey('FailureEvent') -and [int]$scenario.FailureEvent -ne 0) {
        $expectedEvents.Add([int]$scenario.FailureEvent)
    }
    $expectedEvents.Add(1713)
    $expectedEvents.Add($terminalId)
    $expectedEvents.Add(1902)
    $expectedEvents.Add(1903)
    $expectedEvents.Add(1600)
    $expectedEvents.Add(1601)
    $expectedEvents.Add(1602)

    Assert-Model (($events -join ',') -ceq ($expectedEvents -join ',')) "$($scenario.Name): emitted semantic ID sequence mismatch"
    Assert-Model ($terminalIndex -ge 0) "$($scenario.Name): terminal event missing"
    Assert-Model ($returnedIndex -gt $terminalIndex) "$($scenario.Name): returned-status ordering invalid"
    Assert-Model (-not ($state.Failed -and ($events -contains 1900))) "$($scenario.Name): success followed failure"
    Assert-Model (($expectsRollback -and $events -contains 1500 -and $events -contains 1503 -and $state.RollbackCompleted) -or
        (-not $expectsRollback -and $events -notcontains 1500 -and $events -notcontains 1503 -and -not $state.RollbackCompleted)) "$($scenario.Name): rollback evidence mismatch"
    Assert-Model ($cleanupEnteredIndex -gt $returnedIndex -and $cleanupCompletedIndex -gt $cleanupEnteredIndex) "$($scenario.Name): cleanup ordering invalid"
    Assert-Model ($state.ObjectSnapshot -and $state.FinalSnapshot) "$($scenario.Name): object/final snapshot missing"
    Assert-Model ($state.CounterSnapshot -and $state.Counters.Count -eq 12) "$($scenario.Name): twelve-counter snapshot missing"
    Assert-Model (($expectsOverflow -and $events -contains 1804 -and $state.OverflowMask -ne 0) -or
        (-not $expectsOverflow -and $events -notcontains 1804 -and $state.OverflowMask -eq 0)) "$($scenario.Name): overflow behavior mismatch"
    Assert-Model (($expectsCounter -and $events -contains 1701 -and $state.FirstTransitionMask -ne 0) -or
        (-not $expectsCounter -and $events -notcontains 1701 -and $state.FirstTransitionMask -eq 0)) "$($scenario.Name): first-transition behavior mismatch"
    Assert-Model ($state.ReturnedStatusClass -eq $(if ($expectsSuccess) { 1 } else { 3 })) "$($scenario.Name): returned status class incorrect"
    Assert-Model ($events[-1] -eq 1602) "$($scenario.Name): cleanup completion is not final"

    $results.Add([pscustomobject]@{
        Name = $scenario.Name
        EventCount = $events.Count
        TerminalId = $terminalId
        StatusClass = $state.ReturnedStatusClass
    })
}

Write-Output 'RUNTIME INSTRUMENTATION PURE MODEL: PASS'
Write-Output "ScenarioCount=$($results.Count)"
Write-Output "PassedScenarios=$($results.Count)"
Write-Output "AssertionCount=$script:AssertionCount"
Write-Output "FailedAssertions=0"
$results | ForEach-Object {
    Write-Output ("Scenario={0};Events={1};Terminal={2};StatusClass={3}" -f
        $_.Name, $_.EventCount, $_.TerminalId, $_.StatusClass)
}
