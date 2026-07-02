[CmdletBinding()]
param([Parameter(Mandatory)][string]$WppPlanPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $WppPlanPath
$check = Test-ChatpadWppPlanContract -Plan $plan
$target = if ($plan.target_instance_id) { [string]$plan.target_instance_id } else { '<EXACT_INSTANCE_ID>' }
$operations = @(
    New-ChatpadOperationPlan -OperationId 'start-wpp-session' -Executable 'logman.exe' -Arguments @('start',[string]$plan.session_name,'-p',[string]$plan.provider_guid,'0xFFFFFFFF','0xFF','-ets','-o','<TRACE_OUTPUT_PATH>') -TargetInstanceId $target -InputArtifactIds @('host-preflight','target-selection') -PrerequisiteResultIds @('evidence-directory','host-preflight') -StopConditionIds @('trace-provider-wrong','runtime-evidence-write-failed') -MutationClassification 'live-host-read-only' -ExecutionStatus 'blocked'
    New-ChatpadOperationPlan -OperationId 'stop-wpp-session' -Executable 'logman.exe' -Arguments @('stop',[string]$plan.session_name,'-ets') -TargetInstanceId $target -InputArtifactIds @('wpp-session-start') -PrerequisiteResultIds @('wpp-started') -StopConditionIds @('runtime-evidence-write-failed') -MutationClassification 'live-host-read-only' -ExecutionStatus 'blocked'
    New-ChatpadOperationPlan -OperationId 'hash-wpp-output' -Executable 'powershell-filehash' -Arguments @('-Algorithm','SHA256','-LiteralPath','<TRACE_OUTPUT_PATH>') -TargetInstanceId $target -InputArtifactIds @('wpp-output') -PrerequisiteResultIds @('wpp-stopped') -StopConditionIds @('runtime-evidence-write-failed') -MutationClassification 'offline-read-only' -ExecutionStatus 'blocked'
)
$check.data = [pscustomobject]@{ plan = $plan; operations = $operations }
$check | ConvertTo-Json -Depth 14
