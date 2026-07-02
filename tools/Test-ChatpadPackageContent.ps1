[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageContractPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$package = Read-ChatpadJson $PackageContractPath
Test-ChatpadPackageContract -Package $package | ConvertTo-Json -Depth 12
