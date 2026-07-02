[CmdletBinding()]
param([Parameter(Mandatory)][string]$EventLogPlanPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $EventLogPlanPath
$check = Test-ChatpadEventLogPlanContract -Plan $plan
$sessionId=[string](Get-ChatpadProperty $plan session_id 'SYNTHETIC-EVENT-PLAN');$hostId=[string](Get-ChatpadProperty $plan host_id 'SYNTHETIC-HOST');$source=[string](Get-ChatpadProperty $plan source_classification 'synthetic')
$operations = @()
foreach ($channel in @($plan.required_channels)) {
    $safeName = ([string]$channel -replace '[^A-Za-z0-9_-]','-').Trim('-')
    $operations += New-ChatpadOperationPlan `
        -OperationId "eventlog-$($plan.capture_phase)-$safeName" `
        -OperationType 'event-export' `
        -Executable 'wevtutil.exe' `
        -Arguments @('epl',[string]$channel,"<EVIDENCE_DIRECTORY>\$safeName-$($plan.capture_phase).evtx") `
        -InputArtifactIds @('host-preflight','runtime-session') `
        -PrerequisiteResultIds @('evidence-directory','host-preflight') `
        -StopConditionIds @('runtime-evidence-write-failed') `
        -MutationClassification 'live-host-read-only' `
        -Status 'blocked' -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker 'BLOCKED_NOT_IMPLEMENTED'
}
$check.data = [pscustomobject]@{ plan = $plan; operations = $operations }
$check | ConvertTo-Json -Depth 14
