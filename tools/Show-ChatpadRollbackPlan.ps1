[CmdletBinding()]
param([Parameter(Mandatory)][string]$RollbackPlanContractPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$contract = Read-ChatpadJson $RollbackPlanContractPath
$target = [string]$contract.target_instance_id
$sessionId=[string](Get-ChatpadProperty $contract session_id 'SYNTHETIC-ROLLBACK-PLAN');$hostId=[string](Get-ChatpadProperty $contract host_id 'SYNTHETIC-HOST');$source=[string](Get-ChatpadProperty $contract source_classification 'synthetic')
$operations = @(
    New-ChatpadOperationPlan `
        -OperationId 'verify-target-before-rollback' `
        -OperationType 'verify' `
        -TargetScope 'exact-device' `
        -Executable 'ChatpadRuntimeExactDeviceBindingHelper.exe' `
        -Arguments @('--verify-instance','<EXACT_INSTANCE_ID>','--session-id','<SESSION_ID>') `
        -TargetInstanceId $target `
        -InputArtifactIds @('pre-test-driver-state') `
        -PrerequisiteResultIds @('rollback-readiness') `
        -StopConditionIds @('wrong-device-binds','rollback-cannot-be-guaranteed') `
        -MutationClassification 'exact-target-mutation' `
        -Status 'blocked' -SourceClassification $source -SessionId $sessionId -HostId $hostId -ApprovedAsTargetSpecific:$true -Blocker 'BLOCKED_NOT_IMPLEMENTED'
    New-ChatpadOperationPlan `
        -OperationId 'restore-exact-previous-driver-blocked' `
        -OperationType 'restore' `
        -TargetScope 'exact-device' `
        -Executable 'ChatpadRuntimeExactDeviceBindingHelper.exe' `
        -Arguments @('--restore-instance','<EXACT_INSTANCE_ID>','--previous-package','<PREVIOUS_PACKAGE_IDENTITY>','--session-id','<SESSION_ID>') `
        -TargetInstanceId $target `
        -InputArtifactIds @('pre-test-driver-state','previous-package-identity') `
        -PrerequisiteResultIds @('rollback-readiness') `
        -StopConditionIds @('rollback-cannot-be-guaranteed','wrong-device-binds') `
        -MutationClassification 'exact-target-mutation' `
        -Status 'blocked' -SourceClassification $source -SessionId $sessionId -HostId $hostId -ApprovedAsTargetSpecific:$true -Blocker 'BLOCKED_NOT_IMPLEMENTED'
    New-ChatpadOperationPlan `
        -OperationId 'optional-broad-rescan-requires-separate-authorization' `
        -OperationType 'rescan' `
        -Executable 'pnputil.exe' `
        -Arguments @('/scan-devices') `
        -InputArtifactIds @('operator-recovery-authorization') `
        -PrerequisiteResultIds @('rollback-readiness') `
        -StopConditionIds @('device-disappears-without-recovery-path','unplanned-reboot-required') `
        -MutationClassification 'broad-host-mutation' `
        -Status 'blocked' -SourceClassification $source -SessionId $sessionId -HostId $hostId -Blocker 'SEPARATE_AUTHORIZATION_REQUIRED'
)

[pscustomobject]@{
    schema_version = 'chatpad-rollback-plan-v2'
    result = 'BLOCKED'
    reason = 'Exact-instance rollback helper is designed but not implemented; broad rescan is separately classified and blocked.'
    stop_condition_ids = @('rollback-cannot-be-guaranteed')
    operations = $operations
} | ConvertTo-Json -Depth 14
