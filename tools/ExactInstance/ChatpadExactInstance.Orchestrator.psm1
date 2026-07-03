Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.FakeAdapter.psm1') -Force

function New-ChatpadExactEvidence {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][Collections.Generic.List[object]]$Transitions,
        [Parameter(Mandatory)][string]$FinalClassification,
        [Parameter(Mandatory)][string]$ResultCode,
        [object]$BeforeState=$null,
        [object]$AfterState=$null,
        [string]$StopCondition='',
        [string]$RestorationOutcome='not-attempted',
        [int]$UncontrolledExceptions=0,
        [string]$ExceptionType=''
    )
    $c=$Adapter.counters
    $snapshotIdentity=Get-ChatpadExactProperty (Get-ChatpadExactProperty $Plan 'restoration_snapshot' $null) 'driver_identity' $null
    $planIdentity=Get-ChatpadExactProperty $Plan 'exact_restoration_driver_identity' $null
    $restoreCall=@($Adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'}|Select-Object -Last 1)
    $adapterArgument=if($restoreCall.Count){[string](Get-ChatpadExactProperty $restoreCall[0].arguments 'driver_node_id' '')}else{''}
    $mutationMayHaveOccurred=@($Transitions|Where-Object{$_.state-in@('BIND_STARTED','BIND_API_SUCCEEDED','BIND_FAILED_AFTER_MUTATION','RESTORE_STARTED','RESTORE_API_SUCCEEDED')}).Count-gt0
    $uncertaintyStatus=if($UncontrolledExceptions-gt0-or@($Transitions|Where-Object{$_.state-eq'RESTORE_FAILED'}).Count){'active'}elseif($mutationMayHaveOccurred-and$RestorationOutcome-eq'RESTORED'){'recovered'}else{'none'}
    [pscustomobject][ordered]@{
        schema_id=(Get-ChatpadExactInstanceConstants).evidence_schema
        canonical_json_version=(Get-ChatpadExactInstanceConstants).canonical_json_version
        producer='tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1'
        evidence_mode='offline-synthetic'
        operation_id=[string]$Plan.operation_id
        plan_sha256=[string]$Plan.plan_sha256
        implementation_commit=[string]$Plan.implementation_commit
        adapter_identity=[string]$Adapter.adapter_identity
        adapter_mode=[string]$Adapter.adapter_mode
        synthetic=[bool]$Adapter.synthetic
        source_classification='synthetic'
        target_instance_id=[string]$Plan.canonical_instance_id
        preconditions=[pscustomobject][ordered]@{
            precondition_fingerprint=[string]$Plan.precondition_fingerprint
            restoration_snapshot_fingerprint=[string]$Plan.restoration_snapshot_fingerprint
            plan_expiration=[string]$Plan.expires_utc
        }
        state_transitions=@($Transitions)
        adapter_calls=@($Adapter.call_log)
        before_driver_identity=if($null-eq$BeforeState){$null}else{Copy-ChatpadExactObject $BeforeState.driver_identity}
        after_driver_identity=if($null-eq$AfterState){$null}else{Copy-ChatpadExactObject $AfterState.driver_identity}
        restart_required=if($null-eq$AfterState){$false}else{[bool]$AfterState.restart_required}
        reboot_required=if($null-eq$AfterState){$false}else{[bool]$AfterState.reboot_required}
        mutation_attempt_count=[int]($c.synthetic_exact_binding_attempts+$c.synthetic_exact_restoration_attempts)
        synthetic_exact_binding_attempt_count=[int]$c.synthetic_exact_binding_attempts
        synthetic_exact_successful_binding_count=[int]$c.synthetic_exact_successful_bindings
        synthetic_exact_restoration_attempt_count=[int]$c.synthetic_exact_restoration_attempts
        synthetic_exact_successful_restoration_count=[int]$c.synthetic_exact_successful_restorations
        synthetic_restart_attempt_count=[int]$c.synthetic_exact_restart_attempts
        live_exact_binding_operation_count=[int]$c.live_exact_binding_operations
        live_exact_restoration_operation_count=[int]$c.live_exact_restoration_operations
        live_restart_operation_count=[int]$c.live_restart_operations
        broad_installation_attempt_count=[int]$c.broad_installation_attempts
        broad_rollback_attempt_count=[int]$c.broad_rollback_attempts
        live_operation_count=[int]$c.live_operations
        windows_mutation_count=[int]$c.windows_mutations
        controlled_failure_count=[int]$c.controlled_failures
        uncontrolled_exception_count=$UncontrolledExceptions
        exception_type=$ExceptionType
        verification_result=$FinalClassification
        result_code=$ResultCode
        stop_condition=$StopCondition
        restoration_outcome=$RestorationOutcome
        restoration_identity=[pscustomobject][ordered]@{
            snapshot_prior_driver_identity=if($null-eq$snapshotIdentity){$null}else{Copy-ChatpadExactObject $snapshotIdentity}
            plan_restoration_driver_identity=if($null-eq$planIdentity){$null}else{Copy-ChatpadExactObject $planIdentity}
            effective_restoration_driver_identity=if($null-eq$snapshotIdentity){$null}else{Copy-ChatpadExactObject $snapshotIdentity}
            exact_equality=(Test-ChatpadExactDeepEqual $snapshotIdentity $planIdentity)
            restoration_adapter_argument=$adapterArgument
        }
        mutation_may_have_occurred=$mutationMayHaveOccurred
        uncertainty_status=$uncertaintyStatus
        final_classification=$FinalClassification
        live_readiness_satisfied=$false
        readiness='BLOCKED'
        current_gate=(Get-ChatpadExactInstanceConstants).pending_audit_blocker
        capability_blocker=(Get-ChatpadExactInstanceConstants).live_adapter_blocker
    }
}

function New-ChatpadExactSyntheticPlan {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$OperationId,
        [ValidateSet('bind','restore')][string]$OperationType='bind',
        [Parameter(Mandatory)][string]$RequestedInstanceId,
        [Parameter(Mandatory)][object]$TargetDriverIdentity,
        [Parameter(Mandatory)][string]$GeneratedUtc,
        [Parameter(Mandatory)][string]$ExpiresUtc,
        [Parameter(Mandatory)][string]$RepositoryBranch,
        [Parameter(Mandatory)][string]$ImplementationCommit,
        [string]$HostId='SYNTHETIC-HOST',
        [string]$SessionId='SYNTHETIC-SESSION',
        [object]$RestorationSnapshot=$null
    )
    $Adapter.counters.plan_operations++;$Adapter.counters.synthetic_operations++
    try {
        [void](ConvertTo-ChatpadCanonicalInstanceId $RequestedInstanceId)
    } catch {
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return [pscustomobject]@{result='BLOCKED';result_code=$_.Exception.Message;plan=$null}
    }
    $opened=Invoke-ChatpadFakeOpenExactDevice $Adapter $RequestedInstanceId
    if($opened.result-ne'PASS'){return [pscustomobject]@{result='BLOCKED';result_code=$opened.result_code;plan=$null}}
    $canonical=[string]$opened.device.canonical_instance_id
    if(-not(Test-ChatpadCanonicalInstanceIdEqual $RequestedInstanceId $canonical)){
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return [pscustomobject]@{result='BLOCKED';result_code='TARGET_CANONICAL_ID_MISMATCH';plan=$null}
    }
    if($null-eq$RestorationSnapshot){$RestorationSnapshot=New-ChatpadRestorationSnapshot $opened.device $GeneratedUtc}
    $actions=if($OperationType-eq'bind'){@('query-exact-device','verify-package','bind-exact-device','verify-exact-device')}else{@('query-exact-device','verify-package','restore-exact-device','verify-exact-device')}
    $plan=New-ChatpadExactInstancePlan -OperationId $OperationId -OperationType $OperationType -GeneratedUtc $GeneratedUtc -ExpiresUtc $ExpiresUtc -RepositoryBranch $RepositoryBranch -ImplementationCommit $ImplementationCommit -HostId $HostId -SessionId $SessionId -AuthorizationContext ([pscustomobject]@{source='offline-synthetic-suite';synthetic=$true}) -RequestedInstanceId $RequestedInstanceId -DeviceState $opened.device -TargetDriverIdentity $TargetDriverIdentity -RestorationSnapshot $RestorationSnapshot -AuthorizedActions $actions -RestartPolicy exact-device-separate-authorization
    [pscustomobject]@{result='PASS';result_code='PLAN_CREATED';plan=$plan;snapshot=$RestorationSnapshot}
}

function Test-ChatpadSyntheticExecutionGate {
    param([Parameter(Mandatory)][object]$Adapter,[switch]$OfflineSyntheticAuthorization)
    if(-not$Adapter.synthetic-or$Adapter.adapter_identity-ne'chatpad-fake-exact-instance-adapter-v1'-or-not$OfflineSyntheticAuthorization){
        return [pscustomobject]@{result='BLOCKED';result_code='SYNTHETIC_EXECUTION_GATE_MISSING'}
    }
    [pscustomobject]@{result='PASS';result_code='SYNTHETIC_EXECUTION_GATE_VALID'}
}

function Add-ChatpadBlockedTransition {
    param([Collections.Generic.List[object]]$Transitions,[string]$Timestamp,[string]$Reason)
    if($Transitions.Count-and(Test-ChatpadExactTransition ([string]$Transitions[$Transitions.Count-1].state) 'BLOCKED')){
        Add-ChatpadExactTransition $Transitions BLOCKED $Timestamp $Reason
    }
}

function Invoke-ChatpadSyntheticExactApply {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][string]$ExpectedPlanSha256,
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][string]$ValidationTimeUtc,
        [switch]$OfflineSyntheticAuthorization,
        [switch]$AutoRestoreOnFailure
    )
    $transitions=[Collections.Generic.List[object]]::new()
    Add-ChatpadExactTransition $transitions PLAN_CREATED $ValidationTimeUtc
    $before=$null;$after=$null;$restorationOutcome='not-attempted'
    if($Adapter.transactions.ContainsKey($OperationId)){
        Add-ChatpadBlockedTransition $transitions $ValidationTimeUtc 'operation-id-replay'
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED REPLAY_REJECTED -StopCondition 'operation-id-replay'
    }
    $planValidation=Test-ChatpadExactInstancePlan $Plan -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId -ValidationTimeUtc $ValidationTimeUtc
    if($planValidation.result-ne'PASS'){
        Add-ChatpadBlockedTransition $transitions $ValidationTimeUtc $planValidation.result_code
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $planValidation.result_code -StopCondition $planValidation.result_code
    }
    Add-ChatpadExactTransition $transitions PLAN_VALIDATED $ValidationTimeUtc
    $gate=Test-ChatpadSyntheticExecutionGate $Adapter -OfflineSyntheticAuthorization:$OfflineSyntheticAuthorization
    if($gate.result-ne'PASS'){
        Add-ChatpadBlockedTransition $transitions $ValidationTimeUtc $gate.result_code
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $gate.result_code -StopCondition $gate.result_code
    }
    $Adapter.transactions[$OperationId]='in-progress'
    Add-ChatpadExactTransition $transitions PREFLIGHT_STARTED $ValidationTimeUtc
    $opened=Invoke-ChatpadFakeOpenExactDevice $Adapter ([string]$Plan.canonical_instance_id)
    if($opened.result-ne'PASS'){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc $opened.result_code
        $Adapter.transactions[$OperationId]='blocked'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $opened.result_code -StopCondition 'target-instance-missing'
    }
    Add-ChatpadExactTransition $transitions TARGET_OPENED $ValidationTimeUtc
    if(-not(Test-ChatpadCanonicalInstanceIdEqual $opened.device.canonical_instance_id $Plan.canonical_instance_id)){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc 'canonical-instance-drift'
        $Adapter.transactions[$OperationId]='blocked'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED TARGET_IDENTITY_DRIFT -StopCondition 'target-identity-drift'
    }
    Add-ChatpadExactTransition $transitions TARGET_IDENTITY_VERIFIED $ValidationTimeUtc
    $before=Copy-ChatpadExactObject $opened.device
    if((Get-ChatpadDevicePreconditionFingerprint $opened.device)-cne[string]$Plan.precondition_fingerprint){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc 'precondition-fingerprint-drift'
        $Adapter.transactions[$OperationId]='blocked'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED PRECONDITION_DRIFT -BeforeState $before -StopCondition 'target-identity-drift'
    }
    Add-ChatpadExactTransition $transitions SNAPSHOT_CAPTURED $ValidationTimeUtc
    $package=Invoke-ChatpadFakeResolvePackage $Adapter $Plan.target_driver_identity target
    if($package.result-ne'PASS'){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc $package.result_code
        $Adapter.transactions[$OperationId]='blocked'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $package.result_code -BeforeState $before -StopCondition 'package-identity-ambiguous'
    }
    Add-ChatpadExactTransition $transitions PACKAGE_IDENTITY_VERIFIED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions READY_TO_BIND $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions BIND_STARTED $ValidationTimeUtc
    try {
        $bind=Invoke-ChatpadFakeBindExactDevice $Adapter $Plan.canonical_instance_id $Plan.target_driver_identity
    } catch {
        $Adapter.counters.uncontrolled_exceptions++
        $mutationPossible=[bool](Get-ChatpadExactProperty $Adapter.behavior 'bind_throw_after_mutation' $false)
        if($mutationPossible){
            Add-ChatpadExactTransition $transitions BIND_FAILED_AFTER_MUTATION $ValidationTimeUtc $_.Exception.GetType().FullName
            Add-ChatpadExactTransition $transitions RESTORE_REQUIRED $ValidationTimeUtc 'mutation-state-uncertain'
            if($AutoRestoreOnFailure){
                $restore=Invoke-ChatpadSyntheticInlineRestore $Adapter $Plan $transitions $ValidationTimeUtc
                $restorationOutcome=$restore.restoration_outcome
                $after=$restore.after
            }
        } else {
            Add-ChatpadExactTransition $transitions BIND_FAILED_AFTER_MUTATION $ValidationTimeUtc 'adapter-exception-after-call-boundary'
            Add-ChatpadExactTransition $transitions RESTORE_REQUIRED $ValidationTimeUtc 'mutation-state-uncertain'
        }
        $Adapter.transactions[$OperationId]='uncertain'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED ADAPTER_EXCEPTION_UNCERTAIN -BeforeState $before -AfterState $after -StopCondition 'manual-recovery-required' -RestorationOutcome $restorationOutcome -UncontrolledExceptions 1 -ExceptionType $_.Exception.GetType().FullName
    }
    if($bind.result-ne'PASS'){
        Add-ChatpadExactTransition $transitions BIND_FAILED_AFTER_MUTATION $ValidationTimeUtc $bind.result_code
        Add-ChatpadExactTransition $transitions RESTORE_REQUIRED $ValidationTimeUtc 'bind-api-failure-after-possible-mutation'
        if($AutoRestoreOnFailure){
            $restore=Invoke-ChatpadSyntheticInlineRestore $Adapter $Plan $transitions $ValidationTimeUtc
            $restorationOutcome=$restore.restoration_outcome
            $after=$restore.after
        }
        $Adapter.transactions[$OperationId]='failed-after-mutation'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED BIND_FAILED_AFTER_MUTATION -BeforeState $before -AfterState $after -StopCondition 'manual-recovery-required' -RestorationOutcome $restorationOutcome
    }
    Add-ChatpadExactTransition $transitions BIND_API_SUCCEEDED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions POST_BIND_VERIFY_STARTED $ValidationTimeUtc
    $post=Invoke-ChatpadFakeOpenExactDevice $Adapter $Plan.canonical_instance_id
    $after=if($post.result-eq'PASS'){Copy-ChatpadExactObject $post.device}else{$null}
    if($post.result-ne'PASS'-or-not(Test-ChatpadFakeDriverIdentityMatch $post.device.driver_identity $Plan.expected_post_bind_driver_identity)){
        Add-ChatpadExactTransition $transitions RESTORE_REQUIRED $ValidationTimeUtc 'post-bind-identity-unproven'
        if($AutoRestoreOnFailure){
            $restore=Invoke-ChatpadSyntheticInlineRestore $Adapter $Plan $transitions $ValidationTimeUtc
            $restorationOutcome=$restore.restoration_outcome
            $after=$restore.after
        }
        $Adapter.transactions[$OperationId]='restoration-required'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED POST_BIND_VERIFICATION_FAILED -BeforeState $before -AfterState $after -StopCondition 'postcondition-unproven' -RestorationOutcome $restorationOutcome
    }
    Add-ChatpadExactTransition $transitions BIND_VERIFIED $ValidationTimeUtc
    if([bool]$after.reboot_required){
        Add-ChatpadExactTransition $transitions REBOOT_REQUIRED $ValidationTimeUtc
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc 'automatic-reboot-prohibited'
        $Adapter.transactions[$OperationId]='pending-reboot'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED REBOOT_REQUIRED -BeforeState $before -AfterState $after -StopCondition 'reboot-required'
    }
    if([bool]$after.restart_required){
        Add-ChatpadExactTransition $transitions RESTART_REQUIRED $ValidationTimeUtc
    }
    Add-ChatpadExactTransition $transitions COMPLETED $ValidationTimeUtc
    $Adapter.transactions[$OperationId]='completed'
    New-ChatpadExactEvidence $Adapter $Plan $transitions PASS BIND_VERIFIED -BeforeState $before -AfterState $after
}

function Invoke-ChatpadSyntheticInlineRestore {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][Collections.Generic.List[object]]$Transitions,
        [Parameter(Mandatory)][string]$Timestamp
    )
    $snapshotIdentity=Get-ChatpadExactProperty (Get-ChatpadExactProperty $Plan 'restoration_snapshot' $null) 'driver_identity' $null
    $planIdentity=Get-ChatpadExactProperty $Plan 'exact_restoration_driver_identity' $null
    if(-not(Test-ChatpadExactDeepEqual $snapshotIdentity $planIdentity)){
        Add-ChatpadExactTransition $Transitions BLOCKED $Timestamp 'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'
        return [pscustomobject]@{restoration_outcome='RESTORATION_IDENTITY_SNAPSHOT_MISMATCH';after=$null}
    }
    Add-ChatpadExactTransition $Transitions RESTORE_STARTED $Timestamp
    $package=Invoke-ChatpadFakeResolvePackage $Adapter $snapshotIdentity restoration
    if($package.result-ne'PASS'){
        Add-ChatpadExactTransition $Transitions RESTORE_FAILED $Timestamp $package.result_code
        Add-ChatpadExactTransition $Transitions BLOCKED $Timestamp 'manual-recovery-required'
        return [pscustomobject]@{restoration_outcome=$package.result_code;after=$null}
    }
    $restore=Invoke-ChatpadFakeRestoreExactDevice $Adapter $Plan.canonical_instance_id $snapshotIdentity
    if($restore.result-ne'PASS'){
        Add-ChatpadExactTransition $Transitions RESTORE_FAILED $Timestamp $restore.result_code
        Add-ChatpadExactTransition $Transitions BLOCKED $Timestamp 'manual-recovery-required'
        return [pscustomobject]@{restoration_outcome=$restore.result_code;after=$null}
    }
    Add-ChatpadExactTransition $Transitions RESTORE_API_SUCCEEDED $Timestamp
    Add-ChatpadExactTransition $Transitions POST_RESTORE_VERIFY_STARTED $Timestamp
    $post=Invoke-ChatpadFakeOpenExactDevice $Adapter $Plan.canonical_instance_id
    $after=if($post.result-eq'PASS'){Copy-ChatpadExactObject $post.device}else{$null}
    if($post.result-ne'PASS'-or-not(Test-ChatpadFakeDriverIdentityMatch $post.device.driver_identity $snapshotIdentity)){
        Add-ChatpadExactTransition $Transitions RESTORE_FAILED $Timestamp 'post-restoration-verification-failed'
        Add-ChatpadExactTransition $Transitions BLOCKED $Timestamp 'manual-recovery-required'
        return [pscustomobject]@{restoration_outcome='RESTORE_VERIFICATION_FAILED';after=$after}
    }
    Add-ChatpadExactTransition $Transitions RESTORED $Timestamp
    Add-ChatpadExactTransition $Transitions COMPLETED $Timestamp
    [pscustomobject]@{restoration_outcome='RESTORED';after=$after}
}

function Invoke-ChatpadSyntheticExactRestore {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][string]$ExpectedPlanSha256,
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][string]$ValidationTimeUtc,
        [switch]$OfflineSyntheticAuthorization
    )
    $transitions=[Collections.Generic.List[object]]::new()
    Add-ChatpadExactTransition $transitions PLAN_CREATED $ValidationTimeUtc
    if($Adapter.transactions.ContainsKey($OperationId)){
        Add-ChatpadBlockedTransition $transitions $ValidationTimeUtc 'restoration-replay'
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED RESTORE_REPLAY_REJECTED -StopCondition 'operation-id-replay'
    }
    $validation=Test-ChatpadExactInstancePlan $Plan -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId -ValidationTimeUtc $ValidationTimeUtc
    $gate=Test-ChatpadSyntheticExecutionGate $Adapter -OfflineSyntheticAuthorization:$OfflineSyntheticAuthorization
    if($validation.result-ne'PASS'-or$gate.result-ne'PASS'){
        $code=if($validation.result-ne'PASS'){$validation.result_code}else{$gate.result_code}
        Add-ChatpadBlockedTransition $transitions $ValidationTimeUtc $code
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $code -StopCondition $code
    }
    Add-ChatpadExactTransition $transitions PLAN_VALIDATED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions PREFLIGHT_STARTED $ValidationTimeUtc
    $opened=Invoke-ChatpadFakeOpenExactDevice $Adapter $Plan.canonical_instance_id
    if($opened.result-ne'PASS'){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc $opened.result_code
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED $opened.result_code -StopCondition 'target-instance-missing'
    }
    Add-ChatpadExactTransition $transitions TARGET_OPENED $ValidationTimeUtc
    if(-not(Test-ChatpadCanonicalInstanceIdEqual $opened.device.canonical_instance_id $Plan.canonical_instance_id)-or(Get-ChatpadDevicePreconditionFingerprint $opened.device)-cne[string]$Plan.precondition_fingerprint){
        Add-ChatpadExactTransition $transitions BLOCKED $ValidationTimeUtc 'restoration-target-drift'
        return New-ChatpadExactEvidence $Adapter $Plan $transitions BLOCKED RESTORE_TARGET_IDENTITY_DRIFT -BeforeState $opened.device -StopCondition 'target-identity-drift'
    }
    Add-ChatpadExactTransition $transitions TARGET_IDENTITY_VERIFIED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions SNAPSHOT_CAPTURED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions PACKAGE_IDENTITY_VERIFIED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions READY_TO_BIND $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions BIND_STARTED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions BIND_API_SUCCEEDED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions POST_BIND_VERIFY_STARTED $ValidationTimeUtc
    Add-ChatpadExactTransition $transitions BIND_VERIFIED $ValidationTimeUtc
    $before=Copy-ChatpadExactObject $opened.device
    $restore=Invoke-ChatpadSyntheticInlineRestore $Adapter $Plan $transitions $ValidationTimeUtc
    $Adapter.transactions[$OperationId]=if($restore.restoration_outcome-eq'RESTORED'){'completed'}else{'manual-recovery'}
    $classification=if($restore.restoration_outcome-eq'RESTORED'){'PASS'}else{'BLOCKED'}
    $code=if($classification-eq'PASS'){'RESTORE_VERIFIED'}else{$restore.restoration_outcome}
    New-ChatpadExactEvidence $Adapter $Plan $transitions $classification $code -BeforeState $before -AfterState $restore.after -StopCondition $(if($classification-eq'PASS'){''}else{'manual-recovery-required'}) -RestorationOutcome $restore.restoration_outcome
}

Export-ModuleMember -Function *-Chatpad*
