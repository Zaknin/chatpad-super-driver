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
    $inventory | ConvertTo-Json -Depth 8
    exit 0
}
if (-not $ExecuteAuthorizedRuntimeStep) {
    [pscustomobject]@{
        result = 'BLOCKED'
        reason = 'Live device enumeration is prohibited in this preparation task.'
        planned_future_commands = @(
            'Get-PnpDevice -PresentOnly',
            'Get-PnpDeviceProperty -InstanceId <EXACT_INSTANCE_ID>'
        )
    } | ConvertTo-Json -Depth 5
    exit 0
}
throw 'Live device enumeration requires a separately audited runtime session and is not implemented in this preparation scaffold.'
