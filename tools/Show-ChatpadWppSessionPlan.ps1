[CmdletBinding()]
param([Parameter(Mandatory)][string]$WppPlanPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $WppPlanPath
$check = Test-ChatpadWppPlanContract -Plan $plan
$target = if ($plan.target_instance_id) { [string]$plan.target_instance_id } else { '<EXACT_INSTANCE_ID>' }
$sessionId=[string](Get-ChatpadProperty $plan session_id 'SYNTHETIC-WPP-PLAN');$hostId=[string](Get-ChatpadProperty $plan host_id 'SYNTHETIC-HOST');$source=[string](Get-ChatpadProperty $plan source_classification 'synthetic')
$operations = @(
    New-ChatpadOperationPlan -OperationId 'start-wpp-session' -OperationType trace-start -Executable 'logman.exe' -Arguments @('start',[string]$plan.session_name,'-p',[string]$plan.provider_guid,'0xFFFFFFFF','0xFF','-ets','-o','<TRACE_OUTPUT_PATH>') -InputArtifactIds @('host-preflight','target-selection') -PrerequisiteResultIds @('evidence-directory','host-preflight') -StopConditionIds @('trace-provider-wrong','runtime-evidence-write-failed') -MutationClassification 'live-host-read-only' -Status blocked -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker BLOCKED_NOT_IMPLEMENTED
    New-ChatpadOperationPlan -OperationId 'stop-wpp-session' -OperationType trace-stop -Executable 'logman.exe' -Arguments @('stop',[string]$plan.session_name,'-ets') -InputArtifactIds @('wpp-session-start') -PrerequisiteResultIds @('wpp-started') -StopConditionIds @('runtime-evidence-write-failed') -MutationClassification 'live-host-read-only' -Status blocked -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker BLOCKED_NOT_IMPLEMENTED
    New-ChatpadOperationPlan -OperationId 'preserve-wpp-output' -OperationType preserve -Executable 'preserve-artifact' -Arguments @('<TRACE_OUTPUT_PATH>') -InputArtifactIds @('wpp-output') -PrerequisiteResultIds @('wpp-stopped') -StopConditionIds @('runtime-evidence-write-failed') -MutationClassification 'render-only' -Status blocked -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker BLOCKED_NOT_IMPLEMENTED
    New-ChatpadOperationPlan -OperationId 'hash-wpp-output' -OperationType hash -Executable 'powershell-filehash' -Arguments @('-Algorithm','SHA256','-LiteralPath','<TRACE_OUTPUT_PATH>') -InputArtifactIds @('wpp-output') -PrerequisiteResultIds @('wpp-stopped') -StopConditionIds @('runtime-evidence-write-failed') -MutationClassification 'offline-read-only' -Status blocked -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker BLOCKED_NOT_IMPLEMENTED
)
$check.data = [pscustomobject]@{ plan = $plan; operations = $operations }
$check | ConvertTo-Json -Depth 14
