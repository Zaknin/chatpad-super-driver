[CmdletBinding()]
param(
    [string]$ProviderGuid = '{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}',
    [string]$TraceOutputPath = '<EVIDENCE_DIRECTORY>\chatpad-first-load.etl',
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

Test-ChatpadWppPlanContract -Plan ([pscustomobject]@{ provider_guid = $ProviderGuid; output_path = $TraceOutputPath; reuses_stale_output = $false }) | Out-Null
if ($ExecuteAuthorizedRuntimeStep) { throw 'Starting WPP/ETW tracing is prohibited by this preparation task.' }
@(
    New-ChatpadRenderedCommand 'start-wpp-session' "logman start ChatpadFirstLoad -p `"$ProviderGuid`" 0xFFFFFFFF 0xFF -ets -o `"$TraceOutputPath`""
    New-ChatpadRenderedCommand 'stop-wpp-session' 'logman stop ChatpadFirstLoad -ets'
    New-ChatpadRenderedCommand 'hash-wpp-output' "Get-FileHash -Algorithm SHA256 -LiteralPath `"$TraceOutputPath`""
) | ConvertTo-Json -Depth 5
