[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateInventoryPath,
    [Parameter(Mandatory)][string]$TargetContractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

try {
    $inventory = Read-ChatpadJson $CandidateInventoryPath
    $contract = Read-ChatpadJson $TargetContractPath
    Test-ChatpadTargetSelectionContract -Inventory $inventory -Contract $contract | ConvertTo-Json -Depth 12
} catch {
    New-ChatpadValidatorInternalError -Check target-selection -Exception $_.Exception | ConvertTo-Json -Depth 12
    exit 1
}
