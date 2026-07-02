[CmdletBinding()]
param([string]$HostStatePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if ($HostStatePath) {
    $state = Read-ChatpadJson $HostStatePath
    Test-ChatpadHostStateContract -State $state | ConvertTo-Json -Depth 12
    exit 0
}

New-ChatpadRuntimeCheckResult `
    -Check 'host-preflight' `
    -Result BLOCKED `
    -Reason 'Complete host preflight requires a future approved host-state capture or a synthetic fixture; no live security, boot, service, device, or registry mutation is performed.' `
    -StopConditionIds @('prerequisite-changed-after-approval','runtime-evidence-write-failed') |
    ConvertTo-Json -Depth 12
