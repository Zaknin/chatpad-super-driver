[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CandidateInventoryPath,
    [Parameter(Mandatory)][string]$TargetContractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$inventory = Read-ChatpadJson $CandidateInventoryPath
$contract = Read-ChatpadJson $TargetContractPath
Test-ChatpadTargetSelectionContract -Candidates @($inventory.candidates) -Contract $contract | ConvertTo-Json -Depth 8
