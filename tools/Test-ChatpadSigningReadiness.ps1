[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SigningStatePath,
    [ValidateSet('LocalTestCertificate','TrustedInternalCertificate','AttestationOrProduction')]
    [string]$Method = 'LocalTestCertificate'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$state = Read-ChatpadJson $SigningStatePath
Test-ChatpadSigningContract -State $state -Method $Method | ConvertTo-Json -Depth 8
