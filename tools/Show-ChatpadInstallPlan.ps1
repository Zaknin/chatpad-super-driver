[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanContractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $PlanContractPath
$sessionId = [string](Get-ChatpadProperty $plan session_id 'SYNTHETIC-INSTALL-PLAN')
$hostId = [string](Get-ChatpadProperty $plan host_id 'SYNTHETIC-HOST')
$source = [string](Get-ChatpadProperty $plan source_classification 'synthetic')
if ($source -notin @('synthetic','live')) { $source = 'synthetic' }

$operations = @(
    New-ChatpadOperationPlan `
        -OperationId 'validate-package-before-staging' `
        -OperationType 'validate' `
        -Executable 'powershell-validator' `
        -Arguments @('Test-ChatpadPackageContent.ps1','-PackageContractPath','<PACKAGE_CONTRACT>') `
        -InputArtifactIds @('package-contract') `
        -PrerequisiteResultIds @('repository-identity','accepted-baseline-identity') `
        -StopConditionIds @('package-validation-failed') `
        -MutationClassification 'offline-read-only' `
        -RequiresAuthorization:$false `
        -Status 'blocked' `
        -SourceClassification $source `
        -SessionId $sessionId `
        -HostId $hostId `
        -Blocker 'BLOCKED_NOT_IMPLEMENTED'
    New-ChatpadOperationPlan `
        -OperationId 'stage-package-without-binding' `
        -OperationType 'stage' `
        -Executable 'pnputil.exe' `
        -Arguments @('/add-driver','<ABSOLUTE_PACKAGE_INF_PATH>') `
        -InputArtifactIds @('validated-package') `
        -PrerequisiteResultIds @('repository-identity','package-validation','signing-readiness','host-preflight','evidence-directory') `
        -StopConditionIds @('package-validation-failed','signing-identity-wrong','runtime-evidence-write-failed') `
        -MutationClassification 'broad-host-mutation' `
        -Status 'blocked' `
        -SourceClassification $source `
        -SessionId $sessionId `
        -HostId $hostId `
        -Blocker 'BLOCKED_NOT_IMPLEMENTED'
    New-ChatpadOperationPlan `
        -OperationId 'exact-instance-binding-blocked' `
        -OperationType 'bind' `
        -TargetScope 'exact-device' `
        -Executable 'ChatpadRuntimeExactDeviceBindingHelper.exe' `
        -Arguments @('--instance-id','<EXACT_INSTANCE_ID>','--driver-inf','<PUBLISHED_INF_NAME>','--session-id','<SESSION_ID>') `
        -TargetInstanceId '<EXACT_INSTANCE_ID>' `
        -InputArtifactIds @('pre-test-driver-state','validated-package') `
        -PrerequisiteResultIds @('target-selection','current-driver-state','rollback-readiness') `
        -StopConditionIds @('wrong-device-binds','command-differs-from-approved-plan') `
        -MutationClassification 'exact-target-mutation' `
        -Status 'blocked' `
        -SourceClassification $source `
        -SessionId $sessionId `
        -HostId $hostId `
        -ApprovedAsTargetSpecific:$true `
        -Blocker 'BLOCKED_NOT_IMPLEMENTED'
)

if($null-eq$plan.PSObject.Properties['operations']){$plan|Add-Member -NotePropertyName operations -NotePropertyValue $operations}else{$plan.operations=$operations}
Test-ChatpadInstallPlanContract -Plan $plan | ConvertTo-Json -Depth 14
