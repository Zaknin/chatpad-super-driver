[CmdletBinding()]
param([Parameter(Mandatory)][string]$SigningStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

try {
    $state = Read-ChatpadJson $SigningStatePath
    Test-ChatpadSigningContract -State $state | ConvertTo-Json -Depth 12
} catch {
    New-ChatpadValidatorInternalError -Check signing-readiness -Exception $_.Exception | ConvertTo-Json -Depth 12
    exit 1
}
