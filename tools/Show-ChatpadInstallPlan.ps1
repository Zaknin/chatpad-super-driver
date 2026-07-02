[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanContractPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$plan = Read-ChatpadJson $PlanContractPath

$operations = @(
    New-ChatpadOperationPlan `
        -OperationId 'validate-package-before-staging' `
        -Executable 'powershell-validator' `
        -Arguments @('Test-ChatpadPackageContent.ps1','-PackageContractPath','<PACKAGE_CONTRACT>') `
        -InputArtifactIds @('package-contract') `
        -PrerequisiteResultIds @('repository-identity','accepted-baseline-identity') `
        -StopConditionIds @('package-validation-failed') `
        -MutationClassification 'offline-read-only' `
        -RequiresAuthorization:$false
    New-ChatpadOperationPlan `
        -OperationId 'stage-package-without-binding' `
        -Executable 'pnputil.exe' `
        -Arguments @('/add-driver','<ABSOLUTE_PACKAGE_INF_PATH>') `
        -InputArtifactIds @('validated-package') `
        -PrerequisiteResultIds @('repository-identity','package-validation','signing-readiness','host-preflight','evidence-directory') `
        -StopConditionIds @('package-validation-failed','signing-identity-wrong','runtime-evidence-write-failed') `
        -MutationClassification 'broad-host-mutation' `
        -ExecutionStatus 'blocked'
    New-ChatpadOperationPlan `
        -OperationId 'exact-instance-binding-blocked' `
        -Executable 'ChatpadRuntimeExactDeviceBindingHelper.exe' `
        -Arguments @('--instance-id','<EXACT_INSTANCE_ID>','--driver-inf','<PUBLISHED_INF_NAME>','--session-id','<SESSION_ID>') `
        -TargetInstanceId '<EXACT_INSTANCE_ID>' `
        -InputArtifactIds @('pre-test-driver-state','validated-package') `
        -PrerequisiteResultIds @('target-selection','current-driver-state','rollback-readiness') `
        -StopConditionIds @('wrong-device-binds','command-differs-from-approved-plan') `
        -MutationClassification 'exact-target-mutation' `
        -ExecutionStatus 'blocked'
)

$plan.operations = $operations
Test-ChatpadInstallPlanContract -Plan $plan | ConvertTo-Json -Depth 14
