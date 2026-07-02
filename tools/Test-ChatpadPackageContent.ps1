[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageIdentityPath,
    [Parameter(Mandatory)][string]$ApprovedPackageContractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$package = Read-ChatpadJson $PackageIdentityPath
$approved = Read-ChatpadJson $ApprovedPackageContractPath
Test-ChatpadPackageContract -Package $package -Approved $approved | ConvertTo-Json -Depth 8
