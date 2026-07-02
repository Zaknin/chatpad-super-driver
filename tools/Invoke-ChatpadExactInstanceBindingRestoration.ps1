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
    blocker='BLOCKED_PENDING_INDEPENDENT_AUDIT'
}
if($Mode-eq'Plan'){
    $base.result='PASS'
    $base.result_code='PLAN_MODE_SELECTED'
    $base.reason='Planning is non-mutating. A device-query adapter and explicit request are required to create a target-bound plan.'
} elseif($Mode-eq'Verify'){
    if(-not$PlanPath){$base.result='BLOCKED';$base.result_code='PLAN_PATH_REQUIRED'}
    else {
        $plan=Get-Content -LiteralPath $PlanPath -Raw|ConvertFrom-Json
        $validation=Test-ChatpadExactInstancePlan $plan -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId
        $base.result=$validation.result;$base.result_code=$validation.result_code;$base.validation=$validation
    }
} else {
    if(-not$PlanPath){
        $base.result='BLOCKED';$base.result_code='PLAN_PATH_REQUIRED'
    } else {
        $plan=Get-Content -LiteralPath $PlanPath -Raw|ConvertFrom-Json
        $gate=Test-ChatpadRealExecutionAuthorization -Mode $Mode -Plan $plan -ExpectedPlanSha256 $ExpectedPlanSha256 -OperationId $OperationId -AuthorizationValue $AuthorizationValue -AllowWindowsMutation:$AllowWindowsMutation -IsElevated $false -AdapterIdentity 'unavailable' -SyntheticAdapter $false -CleanPreflight $false -ValidationTimeUtc ([datetimeoffset]::UtcNow.ToString('o'))
        $base.result='BLOCKED'
        $base.result_code='LIVE_ADAPTER_UNAVAILABLE_PENDING_INDEPENDENT_AUDIT'
        $base.execution_gate=$gate
    }
}
[pscustomobject]$base|ConvertTo-Json -Depth 20
if($base.result-eq'FAIL'){exit 1}
