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

if ($SyntheticDriverStatePath) { Read-ChatpadJson $SyntheticDriverStatePath | ConvertTo-Json -Depth 8; exit 0 }
if (-not $ExecuteAuthorizedRuntimeStep) {
    [pscustomobject]@{
        result = 'PLANNED_NOT_EXECUTED'
        required_target_instance_id = '<EXACT_INSTANCE_ID>'
        commands = @(
            'Get-PnpDeviceProperty -InstanceId <EXACT_INSTANCE_ID>',
            'pnputil /enum-devices /instanceid <EXACT_INSTANCE_ID> /drivers',
            'driverquery /v /fo csv'
        )
    } | ConvertTo-Json -Depth 5
    exit 0
}
Assert-ChatpadPlanAuthorization -ExecuteAuthorizedRuntimeStep:$ExecuteAuthorizedRuntimeStep -EvidenceDirectory $EvidenceDirectory -TargetInstanceId $TargetInstanceId -ApprovedOperationId 'capture-current-driver-state' | Out-Null
throw 'Future live capture is intentionally not implemented in the preparation commit.'
