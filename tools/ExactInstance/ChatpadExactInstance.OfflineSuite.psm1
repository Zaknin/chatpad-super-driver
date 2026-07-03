Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.FakeAdapter.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Orchestrator.psm1') -Force

$script:Generated='2026-07-03T00:00:00Z'
$script:Validation='2026-07-03T00:05:00Z'
$script:Expires='2026-07-03T01:00:00Z'
$script:Branch='feature/runtime-bringup-exact-instance-contract-remediation'

function New-ChatpadExactSuiteEnvironment {
    param([hashtable]$Behavior=@{},[switch]$DuplicateTargetPackage,[switch]$WithoutPriorPackage,[switch]$WithoutTargetPackage)
    $prior=New-ChatpadFakeDriverIdentity -NodeId 'prior-node-v1' -PublishedInf 'oem10.inf' -Provider 'Microsoft' -Version '10.0.26100.1' -CanonicalInfPath 'C:\Synthetic\DriverStore\xusb22.inf' -InfSha256 ('1'*64) -CatalogSha256 ('2'*64)
    $target=New-ChatpadFakeDriverIdentity -NodeId 'chatpad-node-v1' -PublishedInf 'oem42.inf' -Provider 'Chatpad Project' -Version '1.0.0.0' -Service 'ChatpadFilter' -DriverKey '{FAKE}\0042' -OriginalInf 'ChatpadFilter.inf' -Description 'Synthetic Chatpad exact-instance driver' -CanonicalInfPath 'C:\Synthetic\Package\ChatpadFilter.inf' -InfSha256 ('a'*64) -CatalogSha256 ('b'*64) -CatalogIdentity 'ChatpadFilter.cat' -ModelId 'chatpad-exact-model' -InstallSection 'Chatpad_Install'
    $targetId='USB\VID_045E&PID_028E\TARGET-0001'
    $peerId='USB\VID_045E&PID_028E\PEER-0002'
    $siblingId='USB\VID_045E&PID_028E&MI_01\SIBLING-0001'
    $devices=@(
        (New-ChatpadFakeDevice $targetId $prior -ContainerId '{11111111-1111-1111-1111-111111111111}' -LocationPaths @('PCIROOT(0)#USBROOT(0)#USB(1)')),
        (New-ChatpadFakeDevice $peerId $prior -ContainerId '{22222222-2222-2222-2222-222222222222}' -LocationPaths @('PCIROOT(0)#USBROOT(0)#USB(2)')),
        (New-ChatpadFakeDevice $siblingId $prior -ContainerId '{11111111-1111-1111-1111-111111111111}' -LocationPaths @('PCIROOT(0)#USBROOT(0)#USB(1)#USBMI(1)'))
    )
    $packages=@()
    if(-not$WithoutPriorPackage){$packages+=$prior}
    if(-not$WithoutTargetPackage){$packages+=$target;if($DuplicateTargetPackage){$packages+=Copy-ChatpadExactObject $target}}
    [pscustomobject]@{
        adapter=New-ChatpadFakeExactInstanceAdapter $devices $packages $Behavior
        prior=$prior
        target=$target
        target_id=$targetId
        peer_id=$peerId
        sibling_id=$siblingId
    }
}

function New-ChatpadExactSuitePlan {
    param(
        [Parameter(Mandatory)][object]$Environment,
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][string]$ImplementationCommit,
        [string]$RequestedInstanceId='',
        [ValidateSet('bind','restore')][string]$OperationType='bind',
        [object]$RestorationSnapshot=$null,
        [string]$ExpiresUtc=''
    )
    if(-not$RequestedInstanceId){$RequestedInstanceId=$Environment.target_id}
    if(-not$ExpiresUtc){$ExpiresUtc=$script:Expires}
    New-ChatpadExactSyntheticPlan -Adapter $Environment.adapter -OperationId $OperationId -OperationType $OperationType -RequestedInstanceId $RequestedInstanceId -TargetDriverIdentity $Environment.target -GeneratedUtc $script:Generated -ExpiresUtc $ExpiresUtc -RepositoryBranch $script:Branch -ImplementationCommit $ImplementationCommit -RestorationSnapshot $RestorationSnapshot
}

function Test-ChatpadAllChecks {
    param([object[]]$Checks)
    @($Checks|Where-Object{$_-ne$true}).Count-eq0
}

function New-ChatpadExactTestRecord {
    param([string]$Id,[string]$Title,[object[]]$Checks,[object]$Details,[string]$ExceptionType='')
    [pscustomobject][ordered]@{
        record_type='fixture'
        fixture_id=$Id
        category='exact-instance-offline'
        validator='ChatpadExactInstanceOfflineSuite'
        title=$Title
        expected_status='PASS'
        actual_status=if((Test-ChatpadAllChecks $Checks)-and-not$ExceptionType){'PASS'}else{'FAIL'}
        expected_result_code='EXACT_INSTANCE_CASE_VALID'
        actual_result_code=if((Test-ChatpadAllChecks $Checks)-and-not$ExceptionType){'EXACT_INSTANCE_CASE_VALID'}else{'EXACT_INSTANCE_CASE_INVALID'}
        assertion_count=@($Checks).Count
        fixture_result=if((Test-ChatpadAllChecks $Checks)-and-not$ExceptionType){'PASS'}else{'FAIL'}
        actual_exception_type=$ExceptionType
        details=$Details
    }
}

function Invoke-ChatpadExactCase {
    param([string]$Id,[string]$Title,[scriptblock]$Body)
    try {
        $out=&$Body
        New-ChatpadExactTestRecord $Id $Title @($out.checks) $out.details
    } catch {
        New-ChatpadExactTestRecord $Id $Title @($false) ([pscustomobject]@{message=$_.Exception.Message}) $_.Exception.GetType().FullName
    }
}

function Invoke-ChatpadExactInstanceOfflineSuite {
    param([Parameter(Mandatory)][string]$ImplementationCommit)
    if($ImplementationCommit-notmatch'^[0-9a-f]{40}$'){throw 'ImplementationCommit must be a full lowercase commit hash.'}
    $results=[Collections.Generic.List[object]]::new()
    $script:CrossRuntimeMatrix=$null

    $results.Add((Invoke-ChatpadExactCase T1 'two devices with identical hardware IDs' {
        $e=New-ChatpadExactSuiteEnvironment
        $peerBefore=Get-ChatpadFakeDeviceBytes (@($e.adapter.devices|Where-Object{$_.canonical_instance_id-eq$e.peer_id})[0])
        $p=New-ChatpadExactSuitePlan $e '10000000-0000-0000-0000-000000000001' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $peerAfter=Get-ChatpadFakeDeviceBytes (@($e.adapter.devices|Where-Object{$_.canonical_instance_id-eq$e.peer_id})[0])
        $bindCalls=@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'})
        [pscustomobject]@{checks=@(($r.final_classification-eq'PASS'),($bindCalls.Count-eq1),($bindCalls[0].canonical_instance_id-ceq$e.target_id),([Convert]::ToBase64String($peerBefore)-ceq[Convert]::ToBase64String($peerAfter)),(@($e.adapter.call_log|Where-Object{$_.operation-match'broad|hardware'}).Count-eq0));details=[pscustomobject]@{bind_calls=$bindCalls;peer_before_sha256=Get-ChatpadExactSha256Text ([Convert]::ToBase64String($peerBefore));peer_after_sha256=Get-ChatpadExactSha256Text ([Convert]::ToBase64String($peerAfter));evidence=$r}}
    }))

    $results.Add((Invoke-ChatpadExactCase T2 'exact instance absent' {
        $e=New-ChatpadExactSuiteEnvironment
        $p=New-ChatpadExactSuitePlan $e '20000000-0000-0000-0000-000000000002' $ImplementationCommit -RequestedInstanceId 'USB\VID_045E&PID_028E\MISSING'
        [pscustomobject]@{checks=@(($p.result-eq'BLOCKED'),($p.result_code-eq'TARGET_INSTANCE_NOT_FOUND'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),(@($e.adapter.call_log|Where-Object{$_.operation-match'search|enumerate'}).Count-eq0));details=$p}
    }))

    $results.Add((Invoke-ChatpadExactCase T3 'partial instance IDs rejected' {
        $variants=@('USB\VID_045E&PID_028E','TARGET-0001','USB\VID_045E&PID_028E\*','Chatpad Controller','USB\VID_045E&PID_028E\TAR?')
        $codes=@();$binds=0
        foreach($variant in $variants){$e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '30000000-0000-0000-0000-000000000003' $ImplementationCommit -RequestedInstanceId $variant;$codes+=$p.result_code;$binds+=@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count}
        [pscustomobject]@{checks=@((@($codes|Where-Object{$_-notmatch'INSTANCE_ID_'}).Count-eq0),($binds-eq0),($codes.Count-eq$variants.Count));details=[pscustomobject]@{variants=$variants;result_codes=$codes;binding_calls=$binds}}
    }))

    $results.Add((Invoke-ChatpadExactCase T4 'sibling composite interface cannot replace target' {
        $e=New-ChatpadExactSuiteEnvironment
        $p=New-ChatpadExactSuitePlan $e '40000000-0000-0000-0000-000000000004' $ImplementationCommit
        $target=@($e.adapter.devices|Where-Object{$_.canonical_instance_id-eq$e.target_id})[0];[void]$e.adapter.devices.Remove($target)
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.final_classification-eq'BLOCKED'),($r.result_code-eq'TARGET_INSTANCE_NOT_FOUND'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),(@($e.adapter.call_log|Where-Object{$_.canonical_instance_id-eq$e.sibling_id-and$_.operation-match'bind|restore'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T5 'stale precondition snapshot' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '50000000-0000-0000-0000-000000000005' $ImplementationCommit
        (@($e.adapter.devices|Where-Object{$_.canonical_instance_id-eq$e.target_id})[0]).device_status='stopped'
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'PRECONDITION_DRIFT'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),($r.stop_condition-eq'target-identity-drift'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T6 'target package identity mismatch' {
        $e=New-ChatpadExactSuiteEnvironment -WithoutTargetPackage;$p=New-ChatpadExactSuitePlan $e '60000000-0000-0000-0000-000000000006' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'TARGET_DRIVER_NOT_AVAILABLE'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),($r.final_classification-eq'BLOCKED'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T7 'ambiguous target driver nodes' {
        $e=New-ChatpadExactSuiteEnvironment -DuplicateTargetPackage;$p=New-ChatpadExactSuitePlan $e '70000000-0000-0000-0000-000000000007' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'TARGET_DRIVER_IDENTITY_AMBIGUOUS'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),(@($e.adapter.call_log|Where-Object{$_.operation-match'first|best'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T8 'successful synthetic exact bind' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '80000000-0000-0000-0000-000000000008' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.final_classification-eq'PASS'),[bool]$r.synthetic,($r.synthetic_exact_binding_attempt_count-eq1),($r.live_exact_binding_operation_count-eq0),($r.windows_mutation_count-eq0),(Test-ChatpadFakeDriverIdentityMatch $r.after_driver_identity $e.target));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T9 'API success with failed postcondition' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{bind_postcondition_mismatch=$true};$p=New-ChatpadExactSuitePlan $e '90000000-0000-0000-0000-000000000009' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'POST_BIND_VERIFICATION_FAILED'),($r.final_classification-ne'PASS'),(@($r.state_transitions|Where-Object{$_.state-eq'RESTORE_REQUIRED'}).Count-eq1),(@($r.state_transitions|Where-Object{$_.state-eq'COMPLETED'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T10 'exact restoration' {
        $e=New-ChatpadExactSuiteEnvironment;$bindPlan=New-ChatpadExactSuitePlan $e 'a0000000-0000-0000-0000-000000000010' $ImplementationCommit
        $snapshot=$bindPlan.snapshot;$bind=Invoke-ChatpadSyntheticExactApply $e.adapter $bindPlan.plan $bindPlan.plan.plan_sha256 $bindPlan.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $restorePlan=New-ChatpadExactSuitePlan $e 'a0000000-0000-0000-0000-000000000011' $ImplementationCommit -OperationType restore -RestorationSnapshot $snapshot
        $restore=Invoke-ChatpadSyntheticExactRestore $e.adapter $restorePlan.plan $restorePlan.plan.plan_sha256 $restorePlan.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $calls=@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'})
        [pscustomobject]@{checks=@(($bind.final_classification-eq'PASS'),($restore.final_classification-eq'PASS'),($calls.Count-eq1),($calls[0].canonical_instance_id-ceq$e.target_id),(Test-ChatpadFakeDriverIdentityMatch $restore.after_driver_identity $e.prior),($restore.restoration_identity.exact_equality-eq$true),(Test-ChatpadFakeDriverIdentityMatch $restore.restoration_identity.effective_restoration_driver_identity $snapshot.driver_identity),($restore.restoration_identity.restoration_adapter_argument-eq$snapshot.driver_identity.driver_node_id));details=[pscustomobject]@{restore_calls=$calls;evidence=$restore}}
    }))

    $results.Add((Invoke-ChatpadExactCase T11 'prior driver unavailable' {
        $e=New-ChatpadExactSuiteEnvironment;$bindPlan=New-ChatpadExactSuitePlan $e 'b0000000-0000-0000-0000-000000000011' $ImplementationCommit;$snapshot=$bindPlan.snapshot
        [void](Invoke-ChatpadSyntheticExactApply $e.adapter $bindPlan.plan $bindPlan.plan.plan_sha256 $bindPlan.plan.operation_id $script:Validation -OfflineSyntheticAuthorization)
        $priorPackage=@($e.adapter.packages|Where-Object{$_.driver_node_id-eq'prior-node-v1'})[0];[void]$e.adapter.packages.Remove($priorPackage)
        $rp=New-ChatpadExactSuitePlan $e 'b0000000-0000-0000-0000-000000000012' $ImplementationCommit -OperationType restore -RestorationSnapshot $snapshot
        $r=Invoke-ChatpadSyntheticExactRestore $e.adapter $rp.plan $rp.plan.plan_sha256 $rp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'RESTORE_DRIVER_NOT_AVAILABLE'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'}).Count-eq0),(@($e.adapter.call_log|Where-Object{$_.operation-match'broad|best'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T12 'instance changes before restoration' {
        $e=New-ChatpadExactSuiteEnvironment;$bp=New-ChatpadExactSuitePlan $e 'c0000000-0000-0000-0000-000000000012' $ImplementationCommit;$snapshot=$bp.snapshot
        [void](Invoke-ChatpadSyntheticExactApply $e.adapter $bp.plan $bp.plan.plan_sha256 $bp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization)
        $rp=New-ChatpadExactSuitePlan $e 'c0000000-0000-0000-0000-000000000013' $ImplementationCommit -OperationType restore -RestorationSnapshot $snapshot
        $target=@($e.adapter.devices|Where-Object{$_.canonical_instance_id-eq$e.target_id})[0];[void]$e.adapter.devices.Remove($target)
        $r=Invoke-ChatpadSyntheticExactRestore $e.adapter $rp.plan $rp.plan.plan_sha256 $rp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'TARGET_INSTANCE_NOT_FOUND'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'}).Count-eq0),(@($e.adapter.call_log|Where-Object{$_.operation-match'search|enumerate'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T13 'failure after possible mutation restores same instance' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{bind_api_failure_after_mutation=$true};$p=New-ChatpadExactSuitePlan $e 'd0000000-0000-0000-0000-000000000013' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization -AutoRestoreOnFailure
        $restoreCalls=@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'})
        [pscustomobject]@{checks=@(($r.result_code-eq'BIND_FAILED_AFTER_MUTATION'),($restoreCalls.Count-eq1),($restoreCalls[0].canonical_instance_id-ceq$e.target_id),($r.restoration_outcome-eq'RESTORED'),($r.final_classification-ne'PASS'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T14 'restoration failure retains manual recovery blocker' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{bind_api_failure_after_mutation=$true;restore_failure=$true};$p=New-ChatpadExactSuitePlan $e 'e0000000-0000-0000-0000-000000000014' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization -AutoRestoreOnFailure
        [pscustomobject]@{checks=@(($r.final_classification-eq'BLOCKED'),($r.restoration_outcome-eq'RESTORE_API_FAILED'),($r.stop_condition-eq'manual-recovery-required'),(@($r.state_transitions|Where-Object{$_.state-eq'RESTORE_FAILED'}).Count-eq1),($r.mutation_may_have_occurred-eq$true),($r.uncertainty_status-eq'active'),(@($r.state_transitions|Where-Object{$_.state-eq'COMPLETED'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T15 'replayed apply rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e 'f0000000-0000-0000-0000-000000000015' $ImplementationCommit
        $first=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $second=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($first.final_classification-eq'PASS'),($second.result_code-eq'REPLAY_REJECTED'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq1));details=$second}
    }))

    $results.Add((Invoke-ChatpadExactCase T16 'replayed restoration rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$bp=New-ChatpadExactSuitePlan $e '11000000-0000-0000-0000-000000000016' $ImplementationCommit;$snapshot=$bp.snapshot
        [void](Invoke-ChatpadSyntheticExactApply $e.adapter $bp.plan $bp.plan.plan_sha256 $bp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization)
        $rp=New-ChatpadExactSuitePlan $e '11000000-0000-0000-0000-000000000017' $ImplementationCommit -OperationType restore -RestorationSnapshot $snapshot
        $first=Invoke-ChatpadSyntheticExactRestore $e.adapter $rp.plan $rp.plan.plan_sha256 $rp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $second=Invoke-ChatpadSyntheticExactRestore $e.adapter $rp.plan $rp.plan.plan_sha256 $rp.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($first.final_classification-eq'PASS'),($second.result_code-eq'RESTORE_REPLAY_REJECTED'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'}).Count-eq1));details=$second}
    }))

    $results.Add((Invoke-ChatpadExactCase T17 'expired plan blocked' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '12000000-0000-0000-0000-000000000017' $ImplementationCommit -ExpiresUtc '2026-07-03T00:01:00Z'
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'PLAN_EXPIRED'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),($r.final_classification-eq'BLOCKED'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T18 'plan hash mismatch blocked' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '13000000-0000-0000-0000-000000000018' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan ('f'*64) $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $traversal=Copy-ChatpadExactObject $p.plan;$traversal.target_package_path='C:\Synthetic\..\evil.inf';$traversal.plan_sha256=Get-ChatpadExactObjectHash $traversal -ExcludedProperties @('plan_sha256')
        $traversalResult=Test-ChatpadExactInstancePlan $traversal -ExpectedPlanSha256 $traversal.plan_sha256 -ExpectedOperationId $traversal.operation_id -ValidationTimeUtc $script:Validation
        $ads=Copy-ChatpadExactObject $p.plan;$ads.target_package_path='C:\Synthetic\driver.inf:payload';$ads.plan_sha256=Get-ChatpadExactObjectHash $ads -ExcludedProperties @('plan_sha256')
        $adsResult=Test-ChatpadExactInstancePlan $ads -ExpectedPlanSha256 $ads.plan_sha256 -ExpectedOperationId $ads.operation_id -ValidationTimeUtc $script:Validation
        $snapshotTamper=Copy-ChatpadExactObject $p.plan;$snapshotTamper.restoration_snapshot.driver_identity.driver_node_id='tampered';$snapshotTamper.plan_sha256=Get-ChatpadExactObjectHash $snapshotTamper -ExcludedProperties @('plan_sha256')
        $snapshotResult=Test-ChatpadExactInstancePlan $snapshotTamper -ExpectedPlanSha256 $snapshotTamper.plan_sha256 -ExpectedOperationId $snapshotTamper.operation_id -ValidationTimeUtc $script:Validation
        [pscustomobject]@{checks=@(($r.result_code-eq'PLAN_HASH_MISMATCH'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0),($traversalResult.defects-contains'PATH_TRAVERSAL_INVALID'),($adsResult.defects-contains'PATH_ALTERNATE_DATA_STREAM_INVALID'),($snapshotResult.defects-contains'snapshot-hash-mismatch'));details=[pscustomobject]@{hash_mismatch=$r;traversal=$traversalResult;alternate_data_stream=$adsResult;snapshot_tamper=$snapshotResult}}
    }))

    $results.Add((Invoke-ChatpadExactCase T19 'operation ID mismatch blocked' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '14000000-0000-0000-0000-000000000019' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 '14000000-0000-0000-0000-000000000099' $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'OPERATION_ID_MISMATCH'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T20 'restart required remains separately authorized' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{restart_required=$true};$p=New-ChatpadExactSuitePlan $e '15000000-0000-0000-0000-000000000020' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@([bool]$r.restart_required,($r.synthetic_restart_attempt_count-eq0),($r.live_restart_operation_count-eq0),(@($r.state_transitions|Where-Object{$_.state-eq'RESTART_REQUIRED'}).Count-eq1));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T21 'reboot required never reboots automatically' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{reboot_required=$true};$p=New-ChatpadExactSuitePlan $e '16000000-0000-0000-0000-000000000021' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'REBOOT_REQUIRED'),($r.final_classification-eq'BLOCKED'),(@($e.adapter.call_log|Where-Object{$_.operation-match'reboot'}).Count-eq0),($r.windows_mutation_count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T22 'broad operation guard' {
        $e=New-ChatpadExactSuiteEnvironment;$r=Invoke-ChatpadFakeBroadOperation $e.adapter install-all-matching
        [pscustomobject]@{checks=@(($r.result_code-eq'BROAD_OPERATION_PROHIBITED'),($e.adapter.counters.broad_installation_attempts-eq1),($e.adapter.counters.synthetic_exact_successful_bindings-eq0),(@($e.adapter.call_log|Where-Object{$_.operation-eq'bind-exact-device'}).Count-eq0));details=[pscustomobject]@{result=$r;calls=@($e.adapter.call_log);counters=$e.adapter.counters}}
    }))

    $results.Add((Invoke-ChatpadExactCase T23 'default behavior is planning only' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '17000000-0000-0000-0000-000000000023' $ImplementationCommit
        [pscustomobject]@{checks=@(($p.result-eq'PASS'),($p.plan.schema_id-eq'chatpad-exact-instance-operation-plan-v1'),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0),($e.adapter.counters.windows_mutations-eq0));details=[pscustomobject]@{plan=$p.plan;calls=@($e.adapter.call_log)}}
    }))

    $results.Add((Invoke-ChatpadExactCase T24 'fake evidence cannot satisfy live readiness' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '18000000-0000-0000-0000-000000000024' $ImplementationCommit
        $auth=Get-ChatpadExactSha256Text ("$($p.plan.operation_id)|$($p.plan.plan_sha256)|Apply")
        $spoof=Test-ChatpadRealExecutionAuthorization Apply $p.plan $p.plan.plan_sha256 $p.plan.operation_id $auth -AllowWindowsMutation -IsElevated $true -AdapterIdentity 'chatpad-fake-exact-instance-adapter-v1' -SyntheticAdapter $true -CleanPreflight $true -ValidationTimeUtc $script:Validation
        $evidence=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $valid=Test-ChatpadExactInstanceEvidence $evidence
        $fakeAsLive=Copy-ChatpadExactObject $evidence;$fakeAsLive.adapter_identity='chatpad-windows-exact-instance-adapter-v1';$fakeAsLive.adapter_mode='windows-exact-instance';$fakeAsLive.synthetic=$false;$fakeAsLive.source_classification='live';$fakeAsLive.producer='trusted-live-producer';$fakeAsLive.evidence_mode='live'
        $wrongAdapter=Copy-ChatpadExactObject $evidence;$wrongAdapter.adapter_identity='chatpad-windows-exact-instance-adapter-v1'
        $fakeAsLiveResult=Test-ChatpadExactInstanceEvidence $fakeAsLive
        $wrongAdapterResult=Test-ChatpadExactInstanceEvidence $wrongAdapter
        [pscustomobject]@{checks=@(($spoof.result-eq'BLOCKED'),($spoof.result_code-eq'LIVE_ADAPTER_NOT_IMPLEMENTED'),($spoof.defects-contains'BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED'),($valid.result-eq'PASS'),($fakeAsLiveResult.result-eq'FAIL'),($wrongAdapterResult.result-eq'FAIL'),($evidence.live_readiness_satisfied-eq$false));details=[pscustomobject]@{execution_gate=$spoof;evidence=$evidence;fake_as_live_validation=$fakeAsLiveResult;wrong_adapter_validation=$wrongAdapterResult}}
    }))

    $results.Add((Invoke-ChatpadExactCase T25 'uncontrolled adapter exception remains visible' {
        $e=New-ChatpadExactSuiteEnvironment -Behavior @{bind_throw_after_mutation=$true};$p=New-ChatpadExactSuitePlan $e '19000000-0000-0000-0000-000000000025' $ImplementationCommit
        $r=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        [pscustomobject]@{checks=@(($r.result_code-eq'ADAPTER_EXCEPTION_UNCERTAIN'),($r.uncontrolled_exception_count-eq1),($r.final_classification-eq'BLOCKED'),(@($r.state_transitions|Where-Object{$_.state-eq'RESTORE_REQUIRED'}).Count-eq1),($r.stop_condition-eq'manual-recovery-required'),($r.mutation_may_have_occurred-eq$true),($r.uncertainty_status-eq'active'),(@($r.state_transitions|Where-Object{$_.state-eq'COMPLETED'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T26 'restoration identity changed and plan rehashed' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '26000000-0000-0000-0000-000000000026' $ImplementationCommit -OperationType restore
        $tampered=Copy-ChatpadExactObject $p.plan
        $tampered.exact_restoration_driver_identity=Copy-ChatpadExactObject $e.target
        $tampered.plan_sha256=Get-ChatpadExactObjectHash $tampered -ExcludedProperties @('plan_sha256')
        $r=Invoke-ChatpadSyntheticExactRestore $e.adapter $tampered $tampered.plan_sha256 $tampered.operation_id $script:Validation -OfflineSyntheticAuthorization
        $calls=@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'})
        [pscustomobject]@{checks=@(($r.result_code-eq'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'),($calls.Count-eq0),($r.final_classification-ne'PASS'),($r.restoration_identity.exact_equality-eq$false));details=[pscustomobject]@{evidence=$r;restore_calls=$calls}}
    }))

    $results.Add((Invoke-ChatpadExactCase T27 'nested restoration identity changed' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '27000000-0000-0000-0000-000000000027' $ImplementationCommit -OperationType restore
        $tampered=Copy-ChatpadExactObject $p.plan
        $tampered.exact_restoration_driver_identity.inf_sha256='f'*64
        $tampered.plan_sha256=Get-ChatpadExactObjectHash $tampered -ExcludedProperties @('plan_sha256')
        $r=Test-ChatpadExactInstancePlan $tampered -ExpectedPlanSha256 $tampered.plan_sha256 -ExpectedOperationId $tampered.operation_id -ValidationTimeUtc $script:Validation
        [pscustomobject]@{checks=@(($r.result_code-eq'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'),($r.defects-contains'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'),(@($e.adapter.call_log|Where-Object{$_.operation-eq'restore-exact-device'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T28 'coordinated synthetic-to-live spoof rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '28000000-0000-0000-0000-000000000028' $ImplementationCommit
        $evidence=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $spoof=Copy-ChatpadExactObject $evidence
        $spoof.adapter_identity='chatpad-windows-exact-instance-adapter-v1';$spoof.adapter_mode='windows-exact-instance';$spoof.synthetic=$false;$spoof.source_classification='live';$spoof.producer='trusted-live-producer';$spoof.evidence_mode='live'
        $r=Test-ChatpadExactInstanceEvidence $spoof
        [pscustomobject]@{checks=@(($r.result-eq'FAIL'),($r.defects-contains'UNTRUSTED_EVIDENCE_ORIGIN'),($spoof.live_readiness_satisfied-eq$false),($evidence.source_classification-eq'synthetic'));details=[pscustomobject]@{validation=$r;spoof=$spoof}}
    }))

    $results.Add((Invoke-ChatpadExactCase T29 'caller-controlled real gate spoof rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '29000000-0000-0000-0000-000000000029' $ImplementationCommit
        $auth=Get-ChatpadExactSha256Text ("$($p.plan.operation_id)|$($p.plan.plan_sha256)|Apply")
        $r=Test-ChatpadRealExecutionAuthorization Apply $p.plan $p.plan.plan_sha256 $p.plan.operation_id $auth -AllowWindowsMutation -IsElevated $true -AdapterIdentity 'chatpad-windows-exact-instance-adapter-v1' -SyntheticAdapter $false -CleanPreflight $true -ValidationTimeUtc $script:Validation
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq'LIVE_ADAPTER_NOT_IMPLEMENTED'),($r.live_adapter_capability_present-eq$false),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T30 'Windows PowerShell plan validates in both runtimes' {
        $matrixPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'Test-ChatpadExactInstanceCrossRuntime.ps1'
        $raw=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $matrixPath -ImplementationCommit $ImplementationCommit)
        if($LASTEXITCODE-ne0){throw 'Cross-runtime matrix failed.'}
        $script:CrossRuntimeMatrix=($raw -join"`n")|ConvertFrom-Json
        $directions=@($script:CrossRuntimeMatrix.matrix|Where-Object{$_.producer_runtime-eq'windows-powershell'})
        [pscustomobject]@{checks=@(($script:CrossRuntimeMatrix.result-eq'PASS'),($directions.Count-eq2),(@($directions|Where-Object{$_.result-ne'PASS'-or-not$_.hashes_identical}).Count-eq0));details=$script:CrossRuntimeMatrix}
    }))

    $results.Add((Invoke-ChatpadExactCase T31 'PowerShell 7 plan validates in both runtimes' {
        if($null-eq$script:CrossRuntimeMatrix){throw 'T30 cross-runtime matrix unavailable.'}
        $directions=@($script:CrossRuntimeMatrix.matrix|Where-Object{$_.producer_runtime-eq'powershell-7'})
        [pscustomobject]@{checks=@(($script:CrossRuntimeMatrix.result-eq'PASS'),($directions.Count-eq2),(@($directions|Where-Object{$_.result-ne'PASS'-or-not$_.hashes_identical}).Count-eq0));details=$script:CrossRuntimeMatrix}
    }))

    $results.Add((Invoke-ChatpadExactCase T32 'duplicate JSON root property rejected' {
        $r=Test-ChatpadExactJsonDocument '{"operation_type":"bind","operation_type":"bind"}'
        $case=Test-ChatpadExactJsonDocument '{"operation_type":"bind","Operation_Type":"bind"}'
        [pscustomobject]@{checks=@(($r.result_code-eq'DUPLICATE_JSON_PROPERTY'),($case.result_code-eq'DUPLICATE_JSON_PROPERTY'),($r.defects[0].Contains('path=$.operation_type')));details=[pscustomobject]@{equal_value=$r;case_variant=$case}}
    }))

    $results.Add((Invoke-ChatpadExactCase T33 'duplicate nested restoration property rejected' {
        $equal=Test-ChatpadExactJsonDocument '{"restoration_snapshot":{"driver_identity":{"driver_node_id":"prior","driver_node_id":"prior"}}}'
        $different=Test-ChatpadExactJsonDocument '{"restoration_snapshot":{"driver_identity":{"driver_node_id":"prior","driver_node_id":"target"}}}'
        [pscustomobject]@{checks=@(($equal.result_code-eq'DUPLICATE_JSON_PROPERTY'),($different.result_code-eq'DUPLICATE_JSON_PROPERTY'),($different.defects[0]-match'restoration_snapshot.driver_identity.driver_node_id'));details=[pscustomobject]@{equal=$equal;different=$different}}
    }))

    $results.Add((Invoke-ChatpadExactCase T34 'required host identity deletion remains invalid after rehash' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '34000000-0000-0000-0000-000000000034' $ImplementationCommit
        $tampered=Copy-ChatpadExactObject $p.plan;$tampered.PSObject.Properties.Remove('host_identity');$tampered.plan_sha256=Get-ChatpadExactObjectHash $tampered -ExcludedProperties @('plan_sha256')
        $r=Test-ChatpadExactInstancePlan $tampered -ExpectedPlanSha256 $tampered.plan_sha256 -ExpectedOperationId $tampered.operation_id -ValidationTimeUtc $script:Validation
        [pscustomobject]@{checks=@(($r.result_code-eq'PLAN_SCHEMA_INVALID'),($r.defects-contains'schema-required-missing:plan.host_identity'),($r.result-ne'PASS'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase T35 'required nested driver identity deletion rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '35000000-0000-0000-0000-000000000035' $ImplementationCommit
        $tampered=Copy-ChatpadExactObject $p.plan
        $tampered.restoration_snapshot.driver_identity.PSObject.Properties.Remove('driver_node_id')
        $tampered.restoration_snapshot.snapshot_sha256=Get-ChatpadExactObjectHash $tampered.restoration_snapshot -ExcludedProperties @('snapshot_sha256')
        $tampered.restoration_snapshot_fingerprint=$tampered.restoration_snapshot.snapshot_sha256
        $tampered.plan_sha256=Get-ChatpadExactObjectHash $tampered -ExcludedProperties @('plan_sha256')
        $r=Test-ChatpadExactInstancePlan $tampered -ExpectedPlanSha256 $tampered.plan_sha256 -ExpectedOperationId $tampered.operation_id -ValidationTimeUtc $script:Validation
        $root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim());$schema=Get-Content (Join-Path $root 'docs\evidence\exact-instance-operation-plan-schema-v1.json') -Raw|ConvertFrom-Json
        $planNames=@($p.plan.PSObject.Properties.Name|Sort-Object);$schemaNames=@($schema.required|Sort-Object)
        $snapshotNames=@($p.plan.restoration_snapshot.PSObject.Properties.Name|Sort-Object);$schemaSnapshotNames=@($schema.'$defs'.restorationSnapshot.required|Sort-Object)
        $parity=@(Compare-Object $planNames $schemaNames).Count-eq0-and@(Compare-Object $snapshotNames $schemaSnapshotNames).Count-eq0
        [pscustomobject]@{checks=@(($r.result-ne'PASS'),(@($r.defects|Where-Object{$_-match'driver_node_id'}).Count-gt0),($parity-and@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore'}).Count-eq0));details=[pscustomobject]@{validation=$r;schema_runtime_parity=$parity}}
    }))

    $results.Add((Invoke-ChatpadExactCase T36 'hidden Unicode and non-ASCII instance IDs rejected' {
        $characters=@([char]0x200B,[char]0x00A0,[char]0x200C,[char]0x200D,[char]0x202E,[char]0x2066,[char]0x2067,[char]0x2068,[char]0x2069,[char]0xFEFF,"`t","`n",[char]0xFF3C,[char]0x0410)
        $codes=@();$adapterCalls=0
        foreach($character in $characters){$e=New-ChatpadExactSuiteEnvironment;$id="USB\VID_045E&PID_028E\TARGET$character-0001";$p=New-ChatpadExactSuitePlan $e '36000000-0000-0000-0000-000000000036' $ImplementationCommit -RequestedInstanceId $id;$codes+=$p.result_code;$adapterCalls+=$e.adapter.call_log.Count}
        [pscustomobject]@{checks=@(($codes.Count-eq$characters.Count),(@($codes|Where-Object{$_-ne'INSTANCE_ID_CHARACTER_INVALID'}).Count-eq0),($adapterCalls-eq0));details=[pscustomobject]@{case_count=$characters.Count;result_codes=$codes;adapter_call_count=$adapterCalls}}
    }))

    $results.Add((Invoke-ChatpadExactCase T37 'fake adapter property spoof cannot acquire live capability' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '37000000-0000-0000-0000-000000000037' $ImplementationCommit
        $e.adapter.adapter_identity='chatpad-windows-exact-instance-adapter-v1';$e.adapter.adapter_mode='windows-exact-instance';$e.adapter.synthetic=$false
        $gate=Test-ChatpadRealExecutionAuthorization Apply $p.plan $p.plan.plan_sha256 $p.plan.operation_id 'caller-value' -AllowWindowsMutation -IsElevated $true -AdapterIdentity $e.adapter.adapter_identity -SyntheticAdapter $false -CleanPreflight $true -ValidationTimeUtc $script:Validation
        [pscustomobject]@{checks=@(($gate.result_code-eq'LIVE_ADAPTER_NOT_IMPLEMENTED'),($gate.caller_execution_claims_trusted-eq$false),($gate.live_adapter_capability_present-eq$false),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0));details=$gate}
    }))

    $results.Add((Invoke-ChatpadExactCase T38 'canonical serialization stability' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '38000000-0000-0000-0000-000000000038' $ImplementationCommit
        $bytes=@();$hashes=@()
        1..4|ForEach-Object{$canonical=ConvertTo-ChatpadExactCanonicalJson $p.plan;$bytes+=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes($canonical));$hashes+=Get-ChatpadExactObjectHash $p.plan -ExcludedProperties @('plan_sha256')}
        $parsed=(Test-ChatpadExactJsonDocument (ConvertTo-ChatpadExactCanonicalJson $p.plan)).value
        [pscustomobject]@{checks=@((@($bytes|Select-Object -Unique).Count-eq1),(@($hashes|Select-Object -Unique).Count-eq1),((Get-ChatpadExactObjectHash $parsed -ExcludedProperties @('plan_sha256'))-ceq$p.plan.plan_sha256));details=[pscustomobject]@{unique_byte_sequence_count=@($bytes|Select-Object -Unique).Count;unique_hash_count=@($hashes|Select-Object -Unique).Count;plan_sha256=$p.plan.plan_sha256}}
    }))

    $results.Add((Invoke-ChatpadExactCase T39 'complete PSScriptAnalyzer scope' {
        $root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
        if($PSVersionTable.PSEdition-eq'Core'){
            $modulePath=Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1'
            $command="Import-Module '$($modulePath.Replace("'","''"))' -Force; Get-ChatpadTrackedScriptAnalyzerResult '$($root.Replace("'","''"))'|ConvertTo-Json -Depth 10 -Compress"
            $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            $raw=@(&powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded)
            if($LASTEXITCODE-ne0){throw 'Supported-runtime PSScriptAnalyzer child process failed.'}
            $analysis=($raw-join"`n")|ConvertFrom-Json
        } else {$analysis=Get-ChatpadTrackedScriptAnalyzerResult $root}
        [pscustomobject]@{checks=@(($analysis.tracked_total-eq@(&git ls-files '*.ps1' '*.psm1').Count),($analysis.tool_failure_count-eq0),($analysis.error_count-eq0),(@($analysis.findings|Where-Object{$_.rule_name-eq'PSAvoidAssignmentToAutomaticVariable'-and$_.file-like'*ChatpadRuntimeBringup.Common.psm1'}).Count-eq0));details=$analysis}
    }))

    $failed=@($results|Where-Object{$_.fixture_result-ne'PASS'})
    $assertions=[int](($results|Measure-Object assertion_count -Sum).Sum)
    $critical=@($results|Where-Object{$_.fixture_id-in@('T1','T4','T8','T10','T13','T25')})
    $evidenceRecords=@()
    foreach($test in $results){
        if([string](Get-ChatpadExactProperty $test.details 'schema_id' '')-eq'chatpad-exact-instance-operation-evidence-v1'){$evidenceRecords+=$test.details}
        elseif([string](Get-ChatpadExactProperty (Get-ChatpadExactProperty $test.details 'evidence' $null) 'schema_id' '')-eq'chatpad-exact-instance-operation-evidence-v1'){$evidenceRecords+=(Get-ChatpadExactProperty $test.details 'evidence' $null)}
    }
    $syntheticBindAttempts=[int](($evidenceRecords|Measure-Object synthetic_exact_binding_attempt_count -Sum).Sum)
    $syntheticRestoreAttempts=[int](($evidenceRecords|Measure-Object synthetic_exact_restoration_attempt_count -Sum).Sum)
    $syntheticRestartAttempts=[int](($evidenceRecords|Measure-Object synthetic_restart_attempt_count -Sum).Sum)
    $constants=Get-ChatpadExactInstanceConstants
    $allowedEdgeCount=0;$allowedEdgeFailures=0
    foreach($source in @($constants.allowed_transitions.Keys)){
        foreach($destination in @($constants.allowed_transitions[$source])){
            if([string]::IsNullOrEmpty([string]$destination)){continue}
            $allowedEdgeCount++
            if(-not(Test-ChatpadExactTransition ([string]$source) ([string]$destination))){$allowedEdgeFailures++}
        }
    }
    $invalidEdges=@(
        @('PLAN_CREATED','BIND_STARTED'),
        @('COMPLETED','BIND_STARTED'),
        @('RESTORED','BIND_STARTED'),
        @('BIND_FAILED_BEFORE_MUTATION','COMPLETED'),
        @('BLOCKED','READY_TO_BIND')
    )
    $invalidEdgeAcceptances=0
    foreach($edge in $invalidEdges){if(Test-ChatpadExactTransition $edge[0] $edge[1]){$invalidEdgeAcceptances++}}
    $staticGuardPaths=@(
        (Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1'),
        (Join-Path $PSScriptRoot 'ChatpadExactInstance.Orchestrator.psm1'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'Invoke-ChatpadExactInstanceBindingRestoration.ps1')
    )
    $staticGuardPatterns=@(
        'pnputil(?:\.exe)?\s+/add-driver.+/install',
        'UpdateDriverForPlugAndPlayDevices',
        'remove-package-globally',
        'hardware-id-wide',
        'compatible-id-wide',
        'class-wide-mutation',
        'Select-Object\s+-First\s+1'
    )
    $staticGuardMatches=[Collections.Generic.List[object]]::new()
    foreach($path in $staticGuardPaths){
        $text=[IO.File]::ReadAllText($path)
        foreach($pattern in $staticGuardPatterns){if($text-match$pattern){$staticGuardMatches.Add([pscustomobject]@{path=$path;pattern=$pattern})}}
    }
    $contractPass=($allowedEdgeFailures-eq0-and$invalidEdgeAcceptances-eq0-and$staticGuardMatches.Count-eq0)
    [pscustomobject][ordered]@{
        schema_version='chatpad-exact-instance-offline-suite-v1'
        canonical_json_version='chatpad-canonical-json-v1'
        producer='tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1'
        implementation_commit=$ImplementationCommit
        branch=$script:Branch
        adapter_identity='chatpad-fake-exact-instance-adapter-v1'
        synthetic=$true
        result=if($failed.Count-or-not$contractPass){'FAIL'}else{'PASS'}
        test_count=$results.Count
        passed_test_count=$results.Count-$failed.Count
        failed_test_count=$failed.Count
        assertion_count=$assertions
        category_totals=@([pscustomobject]@{category='exact-instance-offline';record_count=$results.Count;assertion_count=$assertions})
        tests=@($results)
        cross_runtime_hash_matrix=$script:CrossRuntimeMatrix
        psscriptanalyzer_scope=($results|Where-Object fixture_id -eq T39|Select-Object -ExpandProperty details)
        critical_call_traces=@($critical|ForEach-Object{[pscustomobject]@{test_id=$_.fixture_id;details=$_.details}})
        state_machine_contract=[pscustomobject][ordered]@{
            result=if($allowedEdgeFailures-or$invalidEdgeAcceptances){'FAIL'}else{'PASS'}
            allowed_transition_count=$allowedEdgeCount
            allowed_transition_failures=$allowedEdgeFailures
            prohibited_transition_probe_count=$invalidEdges.Count
            prohibited_transition_acceptance_count=$invalidEdgeAcceptances
        }
        broad_operation_static_guard=[pscustomobject][ordered]@{
            result=if($staticGuardMatches.Count){'FAIL'}else{'PASS'}
            scanned_paths=@($staticGuardPaths)
            pattern_count=$staticGuardPatterns.Count
            match_count=$staticGuardMatches.Count
            matches=@($staticGuardMatches)
        }
        accounting=[pscustomobject][ordered]@{
            live_exact_binding_operations=0
            live_exact_restoration_operations=0
            live_restart_operations=0
            broad_successful_installations=0
            broad_successful_rollbacks=0
            live_observations=0
            windows_mutations=0
            synthetic_exact_binding_attempts=$syntheticBindAttempts
            synthetic_exact_restoration_attempts=$syntheticRestoreAttempts
            synthetic_exact_restart_attempts=$syntheticRestartAttempts
            broad_operation_attempts=1
            synthetic_test_records=$results.Count
            expected_adapter_exception_coverage=1
            unexpected_harness_exceptions=@($results|Where-Object{$_.actual_exception_type}).Count
            off_ledger_assertion_count=0
            duplicate_counted_assertion_count=0
            zero_assertion_pass_count=@($results|Where-Object{$_.fixture_result-eq'PASS'-and$_.assertion_count-eq0}).Count
            skipped_as_pass_count=0
        }
        live_installation_readiness='BLOCKED'
        current_gate='BLOCKED_PENDING_INDEPENDENT_AUDIT'
        capability_blocker='BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED'
        live_adapter_status='NOT_IMPLEMENTED'
        live_binding_authorized=$false
    }
}

Export-ModuleMember -Function *-Chatpad*
