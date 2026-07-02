[CmdletBinding()]
param(
    [string]$PreviousInf = '<PREVIOUS_INF_NAME>',
    [string]$TargetInstanceId = '<EXACT_INSTANCE_ID>',
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep,
    [string]$EvidenceDirectory,
    [string]$ApprovedOperationId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if ($ExecuteAuthorizedRuntimeStep) {
    Assert-ChatpadPlanAuthorization -ExecuteAuthorizedRuntimeStep -EvidenceDirectory $EvidenceDirectory -TargetInstanceId $TargetInstanceId -ApprovedOperationId $ApprovedOperationId | Out-Null
    throw 'Rollback execution is not implemented in this preparation scaffold.'
}
@(
    New-ChatpadRenderedCommand 'capture-current-state-before-rollback' "pnputil /enum-devices /instanceid `"$TargetInstanceId`" /drivers"
    New-ChatpadRenderedCommand 'restore-previous-driver' "pnputil /add-driver `"$PreviousInf`" /install"
    New-ChatpadRenderedCommand 'rescan-target' "pnputil /scan-devices"
    New-ChatpadRenderedCommand 'verify-restored-target' "pnputil /enum-devices /instanceid `"$TargetInstanceId`" /drivers"
) | ConvertTo-Json -Depth 5
