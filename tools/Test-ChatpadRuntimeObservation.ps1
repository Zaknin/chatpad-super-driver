[CmdletBinding()]
param([Parameter(Mandatory)][string]$ObservationPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$observation = Read-ChatpadJson $ObservationPath
Test-ChatpadRuntimeObservationContract $observation | ConvertTo-Json -Depth 12
