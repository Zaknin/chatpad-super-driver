[CmdletBinding()]
param([Parameter(Mandatory)][string]$PostTestStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$state = Read-ChatpadJson $PostTestStatePath
Test-ChatpadPostTestReconciliationContract -State $state | ConvertTo-Json -Depth 12
