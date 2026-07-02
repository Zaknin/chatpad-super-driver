Set-StrictMode -Version Latest

# This is the executable model's production-transition mapping.  The test
# runner intentionally does not consume this table: its expected sequences are
# semantic names resolved independently through the authoritative catalogue.
$script:ModelEventIds = @{
    DeviceAddEntered = 1100
    DeviceCreateFailed = 1102
    PreObjectValidationFailed = 1204
    OrchestrationStageEntered = 1301
    FunctionReportMismatch = 1307
    ReadinessFailed = 1402
    LifecycleFailed = 1502
    MarkDeviceCreatedFailed = 1505
    RollbackStarted = 1600
    RollbackReason = 1601
    RollbackSnapshotBefore = 1602
    RollbackCompleted = 1603
    RollbackSnapshotAfter = 1604
    CleanupEntered = 1605
    CleanupSnapshot = 1606
    CleanupCompleted = 1607
    CleanupInvariantViolation = 1608
    TargetDiscoveryCounterNonzero = 1701
    CounterFinalSnapshot = 1713
    AttemptIdWraparound = 1800
    SequenceGap = 1801
    CounterOverflow = 1804
    DeviceAddSuccess = 1900
    DeviceAddFailure = 1901
    DeviceAddFinalSummary = 1902
    DeviceAddReturnedStatus = 1903
}

function New-RuntimeInstrumentationModel {
    [CmdletBinding()]
    param()

    return @{
        Events = [System.Collections.Generic.List[int]]::new()
        Counters = [uint32[]]::new(12)
        FirstTransitionMask = [uint32]0
        OverflowMask = [uint32]0
        Failed = $false
        RollbackStarted = $false
        RollbackCompleted = $false
        Terminal = $false
        Cleanup = $false
        ObjectSnapshot = $false
        CounterSnapshot = $false
        FinalSnapshot = $false
        ReturnedStatusClass = 0
        FailureStage = 0
    }
}

function Add-RuntimeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][int]$SemanticId)

    $State.Events.Add($SemanticId)
}

function Add-RuntimeProhibitedCounter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][ValidateRange(0, 11)][int]$Kind,
        [Parameter()][switch]$ForceOverflow)

    $mask = [uint32](1 -shl $Kind)
    if ($ForceOverflow -or $State.Counters[$Kind] -eq [uint32]::MaxValue) {
        $State.Counters[$Kind] = [uint32]::MaxValue
        $State.OverflowMask = $State.OverflowMask -bor $mask
        Add-RuntimeEvent $State $script:ModelEventIds.CounterOverflow
        return
    }
    $prior = $State.Counters[$Kind]
    $State.Counters[$Kind] = $prior + 1
    if ($prior -eq 0) {
        $State.FirstTransitionMask = $State.FirstTransitionMask -bor $mask
        Add-RuntimeEvent $State ($script:ModelEventIds.TargetDiscoveryCounterNonzero + $Kind)
    }
}

function Start-RuntimeRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][ValidateRange(1, 9)][int]$FailureStage)

    $State.FailureStage = $FailureStage
    $State.RollbackStarted = $true
    Add-RuntimeEvent $State $script:ModelEventIds.RollbackStarted
    Add-RuntimeEvent $State $script:ModelEventIds.RollbackReason
    Add-RuntimeEvent $State $script:ModelEventIds.RollbackSnapshotBefore
}

function Complete-RuntimeRollback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$State)

    if (-not $State.RollbackStarted) {
        Add-RuntimeEvent $State $script:ModelEventIds.SequenceGap
    }
    $State.RollbackCompleted = $true
    Add-RuntimeEvent $State $script:ModelEventIds.RollbackCompleted
    Add-RuntimeEvent $State $script:ModelEventIds.RollbackSnapshotAfter
}

function Complete-RuntimeTerminal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][bool]$Success,
        [Parameter(Mandatory)][int]$StatusClass)

    if ($State.Terminal -or ($Success -and $State.Failed)) {
        Add-RuntimeEvent $State $script:ModelEventIds.SequenceGap
    }
    if (-not $Success) {
        $State.Failed = $true
    }
    Add-RuntimeEvent $State $script:ModelEventIds.CounterFinalSnapshot
    $State.CounterSnapshot = $true
    Add-RuntimeEvent $State $(if ($Success) {
        $script:ModelEventIds.DeviceAddSuccess
    } else {
        $script:ModelEventIds.DeviceAddFailure
    })
    Add-RuntimeEvent $State $script:ModelEventIds.DeviceAddFinalSummary
    $State.ObjectSnapshot = $true
    $State.FinalSnapshot = $true
    Add-RuntimeEvent $State $script:ModelEventIds.DeviceAddReturnedStatus
    $State.ReturnedStatusClass = $StatusClass
    $State.Terminal = $true
}

function Complete-RuntimeCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter()][switch]$InvariantViolation)

    Add-RuntimeEvent $State $script:ModelEventIds.CleanupEntered
    Add-RuntimeEvent $State $script:ModelEventIds.CleanupSnapshot
    if ($InvariantViolation) {
        Add-RuntimeEvent $State $script:ModelEventIds.CleanupInvariantViolation
    }
    $State.Cleanup = $true
    Add-RuntimeEvent $State $script:ModelEventIds.CleanupCompleted
}

function Invoke-RuntimeInstrumentationScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][ValidateSet(
            'None', 'DeviceCreate', 'PreObjectValidation',
            'OrchestrationStage', 'Readiness', 'Lifecycle',
            'MarkDeviceCreated', 'Terminal')]
        [string]$FailureTransition = 'None',
        [Parameter()][ValidateRange(0, 9)][int]$FailureStage = 0,
        [Parameter()][switch]$Rollback,
        [Parameter()][switch]$Counter,
        [Parameter()][switch]$Overflow,
        [Parameter()][switch]$CleanupInvariant,
        [Parameter()][switch]$Mismatch,
        [Parameter()][switch]$AttemptWrap,
        [Parameter()][switch]$Success)

    $state = New-RuntimeInstrumentationModel
    Add-RuntimeEvent $state $script:ModelEventIds.DeviceAddEntered
    if ($AttemptWrap) {
        Add-RuntimeEvent $state $script:ModelEventIds.AttemptIdWraparound
    }
    if ($Mismatch) {
        Add-RuntimeEvent $state $script:ModelEventIds.FunctionReportMismatch
    }
    if ($Counter) {
        Add-RuntimeProhibitedCounter $state 0
    }
    if ($Overflow) {
        Add-RuntimeProhibitedCounter $state 1 -ForceOverflow
    }

    switch ($FailureTransition) {
        'DeviceCreate' { Add-RuntimeEvent $state $script:ModelEventIds.DeviceCreateFailed }
        'PreObjectValidation' { Add-RuntimeEvent $state $script:ModelEventIds.PreObjectValidationFailed }
        'OrchestrationStage' {
            if ($FailureStage -eq 0) {
                throw 'An orchestration-stage failure requires a nonzero stage discriminator.'
            }
            Add-RuntimeEvent $state $script:ModelEventIds.OrchestrationStageEntered
        }
        'Readiness' { Add-RuntimeEvent $state $script:ModelEventIds.ReadinessFailed }
        'Lifecycle' { Add-RuntimeEvent $state $script:ModelEventIds.LifecycleFailed }
        'MarkDeviceCreated' { Add-RuntimeEvent $state $script:ModelEventIds.MarkDeviceCreatedFailed }
        'Terminal' { $state.Failed = $true }
    }

    if ($Rollback) {
        if ($FailureStage -eq 0) {
            throw 'Rollback evidence requires a nonzero failure-stage discriminator.'
        }
        Start-RuntimeRollback $state $FailureStage
        Complete-RuntimeRollback $state
    }

    $scenarioSuccess = $Success -and
        -not $Counter -and
        -not $Overflow -and
        -not $CleanupInvariant -and
        -not $Mismatch -and
        -not $AttemptWrap -and
        $FailureTransition -ceq 'None'
    Complete-RuntimeTerminal $state $scenarioSuccess $(if ($scenarioSuccess) { 1 } else { 3 })
    Complete-RuntimeCleanup $state -InvariantViolation:$CleanupInvariant
    return $state
}

Export-ModuleMember -Function @(
    'New-RuntimeInstrumentationModel',
    'Add-RuntimeEvent',
    'Add-RuntimeProhibitedCounter',
    'Start-RuntimeRollback',
    'Complete-RuntimeRollback',
    'Complete-RuntimeTerminal',
    'Complete-RuntimeCleanup',
    'Invoke-RuntimeInstrumentationScenario')
