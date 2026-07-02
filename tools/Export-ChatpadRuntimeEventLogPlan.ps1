[CmdletBinding()]
param(
    [string]$EvidenceDirectory = '<EVIDENCE_DIRECTORY>',
    [switch]$PostTest,
    [switch]$PlanOnly = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$phase = if ($PostTest) { 'post-test' } else { 'baseline' }
@(
    New-ChatpadRenderedCommand "eventlog-$phase-system" "wevtutil epl System `"$EvidenceDirectory\system-$phase.evtx`""
    New-ChatpadRenderedCommand "eventlog-$phase-codeintegrity" "wevtutil epl Microsoft-Windows-CodeIntegrity/Operational `"$EvidenceDirectory\codeintegrity-$phase.evtx`""
    New-ChatpadRenderedCommand "eventlog-$phase-kernelpnp" "wevtutil epl Microsoft-Windows-Kernel-PnP/Configuration `"$EvidenceDirectory\kernelpnp-$phase.evtx`""
) | ConvertTo-Json -Depth 5
