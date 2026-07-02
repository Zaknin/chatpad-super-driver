[CmdletBinding()]
param([Parameter(Mandatory)][string]$SigningStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$state = Read-ChatpadJson $SigningStatePath
Test-ChatpadSigningContract -State $state | ConvertTo-Json -Depth 12
