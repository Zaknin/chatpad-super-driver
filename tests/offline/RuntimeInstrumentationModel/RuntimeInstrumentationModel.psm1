Set-StrictMode -Version Latest

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
        Add-RuntimeEvent $State 1804
        return
    }
    $prior = $State.Counters[$Kind]
    $State.Counters[$Kind] = $prior + 1
    if ($prior -eq 0) {
        $State.FirstTransitionMask = $State.FirstTransitionMask -bor $mask
        Add-RuntimeEvent $State (1701 + $Kind)
    }
}

function Start-RuntimeRollback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$State)

    $State.RollbackStarted = $true
    Add-RuntimeEvent $State 1500
    Add-RuntimeEvent $State 1501
}

function Complete-RuntimeRollback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$State)

    if (-not $State.RollbackStarted) {
        Add-RuntimeEvent $State 1801
    }
    $State.RollbackCompleted = $true
    Add-RuntimeEvent $State 1503
}

function Complete-RuntimeTerminal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][bool]$Success,
        [Parameter(Mandatory)][int]$StatusClass)

    if ($State.Terminal -or ($Success -and $State.Failed)) {
        Add-RuntimeEvent $State 1801
    }
    if (-not $Success) {
        $State.Failed = $true
    }
    Add-RuntimeEvent $State 1713
    $State.CounterSnapshot = $true
    Add-RuntimeEvent $State ($(if ($Success) { 1900 } else { 1901 }))
    Add-RuntimeEvent $State 1902
    $State.ObjectSnapshot = $true
    $State.FinalSnapshot = $true
    Add-RuntimeEvent $State 1903
    $State.ReturnedStatusClass = $StatusClass
    $State.Terminal = $true
}

function Complete-RuntimeCleanup {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$State)

    Add-RuntimeEvent $State 1600
    Add-RuntimeEvent $State 1601
    $State.Cleanup = $true
    Add-RuntimeEvent $State 1602
}

function Invoke-RuntimeInstrumentationScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][int]$FailureEvent = 0,
        [Parameter()][switch]$Rollback,
        [Parameter()][switch]$Counter,
        [Parameter()][switch]$Overflow,
        [Parameter()][switch]$Invariant,
        [Parameter()][switch]$Mismatch,
        [Parameter()][switch]$AttemptWrap,
        [Parameter()][switch]$Success)

    $state = New-RuntimeInstrumentationModel
    Add-RuntimeEvent $state 1100
    if ($AttemptWrap) {
        Add-RuntimeEvent $state 1800
    }
    if ($Mismatch) {
        Add-RuntimeEvent $state 1307
    }
    if ($Invariant) {
        Add-RuntimeEvent $state 1603
    }
    if ($Counter) {
        Add-RuntimeProhibitedCounter $state 0
    }
    if ($Overflow) {
        Add-RuntimeProhibitedCounter $state 1 -ForceOverflow
    }
    if ($Rollback) {
        Start-RuntimeRollback $state
        Complete-RuntimeRollback $state
    }
    if ($FailureEvent -ne 0) {
        Add-RuntimeEvent $state $FailureEvent
    }

    $scenarioSuccess = $Success -and
        -not $Counter -and
        -not $Overflow -and
        -not $Invariant -and
        -not $Mismatch -and
        -not $AttemptWrap -and
        $FailureEvent -eq 0
    Complete-RuntimeTerminal $state $scenarioSuccess ($(if ($scenarioSuccess) { 1 } else { 3 }))
    Complete-RuntimeCleanup $state
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
