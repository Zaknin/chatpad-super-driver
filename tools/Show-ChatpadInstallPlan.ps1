[CmdletBinding()]
param(
    [string]$PackageInfPath = '<ABSOLUTE_PACKAGE_INF_PATH>',
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
    throw 'Install execution is not implemented in this preparation scaffold.'
}
@(
    New-ChatpadRenderedCommand 'inspect-package' "pnputil /enum-drivers"
    New-ChatpadRenderedCommand 'stage-package' "pnputil /add-driver `"$PackageInfPath`""
    New-ChatpadRenderedCommand 'update-exact-device' "pnputil /add-driver `"$PackageInfPath`" /install"
    New-ChatpadRenderedCommand 'confirm-exact-device' "pnputil /enum-devices /instanceid `"$TargetInstanceId`" /drivers"
) | ConvertTo-Json -Depth 5
