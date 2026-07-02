[CmdletBinding()]
param([Parameter(Mandatory)][string]$EventLogPlanPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $EventLogPlanPath
$check = Test-ChatpadEventLogPlanContract -Plan $plan
$operations = @()
foreach ($channel in @($plan.required_channels)) {
    $safeName = ([string]$channel -replace '[^A-Za-z0-9_-]','-').Trim('-')
    $operations += New-ChatpadOperationPlan `
        -OperationId "eventlog-$($plan.capture_phase)-$safeName" `
        -Executable 'wevtutil.exe' `
        -Arguments @('epl',[string]$channel,"<EVIDENCE_DIRECTORY>\$safeName-$($plan.capture_phase).evtx") `
        -InputArtifactIds @('host-preflight','runtime-session') `
        -PrerequisiteResultIds @('evidence-directory','host-preflight') `
        -StopConditionIds @('runtime-evidence-write-failed') `
        -MutationClassification 'live-host-read-only' `
        -ExecutionStatus 'blocked'
}
$check.data = [pscustomobject]@{ plan = $plan; operations = $operations }
$check | ConvertTo-Json -Depth 14
