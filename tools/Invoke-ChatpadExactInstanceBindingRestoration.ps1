[CmdletBinding()]
param(
    [ValidateSet('Plan','Apply','Restore','Verify')][string]$Mode='Plan',
    [string]$PlanPath='',
    [string]$ExpectedPlanSha256='',
    [string]$OperationId='',
    [string]$AuthorizationValue='',
    [switch]$AllowWindowsMutation
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ExactInstance\ChatpadExactInstance.Contracts.psm1') -Force

$base=[ordered]@{
    schema_version='chatpad-exact-instance-public-entrypoint-v1'
    selected_mode=$Mode
    default_mode=($Mode-eq'Plan')
    mutation_invoked=$false
    live_exact_binding_operations=0
    live_exact_restoration_operations=0
    live_restart_operations=0
    broad_installation_operations=0
    broad_rollback_operations=0
    windows_mutations=0
    live_installation_readiness='BLOCKED'
    current_gate='BLOCKED_PENDING_INDEPENDENT_AUDIT'
    capability_blocker='BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED'
    live_binding_authorized=$false
}
if($Mode-eq'Plan'){
    $base.result='PASS'
    $base.result_code='PLAN_MODE_SELECTED'
    $base.reason='Planning is non-mutating. A device-query adapter and explicit request are required to create a target-bound plan.'
} elseif($Mode-eq'Verify'){
    if(-not$PlanPath){$base.result='BLOCKED';$base.result_code='PLAN_PATH_REQUIRED'}
    else {
        $document=Test-ChatpadExactJsonDocument (Get-Content -LiteralPath $PlanPath -Raw)
        if($document.result-ne'PASS'){$base.result='FAIL';$base.result_code=$document.result_code;$base.validation=$document}
        else {
            $validation=Test-ChatpadExactInstancePlan $document.value -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId
            $base.result=$validation.result;$base.result_code=$validation.result_code;$base.validation=$validation
        }
    }
} else {
    $base.result='BLOCKED'
    $base.result_code='LIVE_ADAPTER_NOT_IMPLEMENTED'
    $base.reason='The production composition root contains no native SetupAPI/Newdev adapter or trusted live capability.'
    if($PlanPath){
        $document=Test-ChatpadExactJsonDocument (Get-Content -LiteralPath $PlanPath -Raw)
        if($document.result-eq'PASS'){
            $base.execution_gate=Test-ChatpadRealExecutionAuthorization -Mode $Mode -Plan $document.value -ExpectedPlanSha256 $ExpectedPlanSha256 -OperationId $OperationId -AuthorizationValue $AuthorizationValue -AllowWindowsMutation:$AllowWindowsMutation -IsElevated $false -AdapterIdentity 'untrusted-caller-input' -SyntheticAdapter $false -CleanPreflight $false -ValidationTimeUtc ([datetimeoffset]::UtcNow.ToString('o')
            )
        } else {$base.plan_document_validation=$document}
    }
}
[pscustomobject]$base|ConvertTo-Json -Depth 20
if($base.result-eq'FAIL'){exit 1}
