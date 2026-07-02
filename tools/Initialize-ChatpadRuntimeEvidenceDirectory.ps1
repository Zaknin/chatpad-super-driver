[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDirectoryStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$state = Read-ChatpadJson $EvidenceDirectoryStatePath
Test-ChatpadEvidenceDirectoryContract -State $state | ConvertTo-Json -Depth 12
