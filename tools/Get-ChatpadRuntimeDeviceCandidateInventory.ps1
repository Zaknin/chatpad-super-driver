[CmdletBinding()]
param(
    [string]$SyntheticInventoryPath,
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if ($SyntheticInventoryPath) {
    $inventory = Read-ChatpadJson $SyntheticInventoryPath
    if ([string]$inventory.source_classification -ne 'synthetic') {
        throw 'Synthetic inventory mode requires source_classification=synthetic.'
    }
    $inventory | ConvertTo-Json -Depth 12
    exit 0
}

if (-not $ExecuteAuthorizedRuntimeStep) {
    New-ChatpadRuntimeCheckResult `
        -Check 'device-candidate-inventory' `
        -Result BLOCKED `
        -ResultCode 'BLOCKED_NOT_IMPLEMENTED' `
        -Reason 'Live device enumeration is prohibited in this preparation task.' `
        -StopConditionIds @('target-identity-ambiguous') `
        -Data ([pscustomobject]@{
            planned_future_operation = New-ChatpadOperationPlan `
                -OperationId 'future-device-inventory' `
                -Executable 'Get-PnpDevice' `
                -Arguments @('-PresentOnly') `
                -StopConditionIds @('target-identity-ambiguous') `
                -MutationClassification 'live-device-query' `
                -Status 'blocked' `
                -SourceClassification 'synthetic' `
                -SessionId 'SYNTHETIC-INVENTORY-PLAN' `
                -HostId 'SYNTHETIC-HOST' `
                -Blocker 'BLOCKED_NOT_IMPLEMENTED'
        }) | ConvertTo-Json -Depth 12
    exit 0
}

throw 'Live device enumeration requires a separately audited runtime session and is not implemented in this remediation commit.'
