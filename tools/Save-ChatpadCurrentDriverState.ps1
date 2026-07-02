[CmdletBinding()]
param(
    [string]$SyntheticDriverStatePath,
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep,
    [string]$TargetInstanceId,
    [string]$EvidenceDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if ($SyntheticDriverStatePath) {
    $state = Read-ChatpadJson $SyntheticDriverStatePath
    Test-ChatpadDriverStateContract -State $state | ConvertTo-Json -Depth 12
    exit 0
}

if (-not $ExecuteAuthorizedRuntimeStep) {
    New-ChatpadRuntimeCheckResult `
        -Check 'current-driver-state' `
        -Result BLOCKED `
        -Reason 'Live current-driver capture is not implemented in this offline remediation.' `
        -StopConditionIds @('current-driver-unidentified') `
        -Data ([pscustomobject]@{
            required_target_instance_id = '<EXACT_INSTANCE_ID>'
            future_operations = @(
                New-ChatpadOperationPlan -OperationId 'future-driver-state-pnp-properties' -Executable 'Get-PnpDeviceProperty' -Arguments @('-InstanceId','<EXACT_INSTANCE_ID>') -TargetInstanceId '<EXACT_INSTANCE_ID>' -StopConditionIds @('current-driver-unidentified') -MutationClassification 'live-device-query' -ExecutionStatus 'blocked'
            )
        }) | ConvertTo-Json -Depth 12
    exit 0
}

throw 'Live current-driver capture requires a separately audited runtime session and is not implemented in this remediation commit.'
