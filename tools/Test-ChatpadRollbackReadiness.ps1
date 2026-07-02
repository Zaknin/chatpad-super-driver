[CmdletBinding()]
param([Parameter(Mandatory)][string]$RollbackStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$state = Read-ChatpadJson $RollbackStatePath
Test-ChatpadRollbackContract -State $state | ConvertTo-Json -Depth 12
