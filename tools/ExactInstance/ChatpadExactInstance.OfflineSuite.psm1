Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.FakeAdapter.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Orchestrator.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadNativeAdapterDesignGate.psm1') -Force

$script:Generated='2026-07-03T00:00:00Z'
$script:Validation='2026-07-03T00:05:00Z'
$script:Expires='2026-07-03T01:00:00Z'

function Get-ChatpadExactSuiteBranch {
    $branch = (& git branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $branch -or -not $branch.Trim()) {
        throw 'Unable to derive current repository branch for exact-instance suite evidence.'
    }
    $branch.Trim()
}

function Invoke-ChatpadIsolatedIntegrityProbe {
    param([Parameter(Mandatory)][string]$Script)

    $executableName=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
    $executable=Join-Path $PSHOME $executableName
    if(-not(Test-Path -LiteralPath $executable -PathType Leaf)){
        $executable=(Get-Command $executableName -ErrorAction Stop).Source
    }
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Script))
    $raw=@(& $executable -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded)
    if($LASTEXITCODE-ne0){throw "Isolated native probe failed with exit code $LASTEXITCODE."}
    ($raw-join"`n")|ConvertFrom-Json
}

$script:Branch=Get-ChatpadExactSuiteBranch

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
    $nativeOperationBlocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
    $historicalCompileOnlyGate = 'BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED'
    $compileEvidenceAuditGate = 'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT'
    $scaffoldAuditGate = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'

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
        [pscustomobject]@{checks=@(($spoof.result-eq'BLOCKED'),($spoof.result_code-eq$nativeOperationBlocker),($spoof.defects-contains$nativeOperationBlocker),($valid.result-eq'PASS'),($fakeAsLiveResult.result-eq'FAIL'),($wrongAdapterResult.result-eq'FAIL'),($evidence.live_readiness_satisfied-eq$false));details=[pscustomobject]@{execution_gate=$spoof;evidence=$evidence;fake_as_live_validation=$fakeAsLiveResult;wrong_adapter_validation=$wrongAdapterResult}}
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
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq$nativeOperationBlocker),($r.live_adapter_capability_present-eq$false),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0));details=$r}
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
        [pscustomobject]@{checks=@(($gate.result_code-eq$nativeOperationBlocker),($gate.caller_execution_claims_trusted-eq$false),($gate.live_adapter_capability_present-eq$false),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0));details=$gate}
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
        $analyzerPath=Join-Path (Split-Path $PSScriptRoot -Parent) 'Invoke-ChatpadCompletePSScriptAnalyzer.ps1'
        $raw=@(&powershell.exe -NoProfile -ExecutionPolicy Bypass -File $analyzerPath -RepositoryRoot $root)
        if($LASTEXITCODE-ne0){throw 'Supported-runtime PSScriptAnalyzer child process failed.'}
        $analysis=($raw-join"`n")|ConvertFrom-Json
        [pscustomobject]@{checks=@(($analysis.tracked_total-eq@(&git ls-files '*.ps1' '*.psm1').Count),($analysis.tool_failure_count-eq0),($analysis.error_count-eq0),(@($analysis.findings|Where-Object{$_.rule_name-eq'PSAvoidAssignmentToAutomaticVariable'-and$_.file-like'*ChatpadRuntimeBringup.Common.psm1'}).Count-eq0));details=$analysis}
    }))

    $results.Add((Invoke-ChatpadExactCase G1 'current apply restore and restart lack executable native adapter' {
        $apply=Test-ChatpadNativeAdapterOperationGate Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        $restore=Test-ChatpadNativeAdapterOperationGate Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restore -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        $restart=Test-ChatpadNativeAdapterOperationGate Restart -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restart -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        [pscustomobject]@{checks=@(($apply.result_code-eq$nativeOperationBlocker),($restore.result_code-eq$nativeOperationBlocker),($restart.result_code-eq$nativeOperationBlocker),($apply.windows_mutations_performed+$restore.windows_mutations_performed+$restart.windows_mutations_performed-eq0));details=[pscustomobject]@{apply=$apply;restore=$restore;restart=$restart}}
    }))

    $results.Add((Invoke-ChatpadExactCase G2 'adapter name spoof cannot grant capability' {
        $r=Test-ChatpadNativeAdapterOperationGate Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq$nativeOperationBlocker),($r.adapter_name_trusted-eq$false),($r.live_capability_present-eq$false));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase G3 'mode boolean elevation and switch spoof cannot grant capability' {
        $r=Test-ChatpadNativeAdapterOperationGate Apply -AdapterName 'any' -Mode 'windows-exact-instance' -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        [pscustomobject]@{checks=@(($r.public_mode_trusted-eq$false),($r.public_synthetic_flag_trusted-eq$false),($r.elevation_trusted-eq$false),($r.mutation_switch_trusted-eq$false),($r.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase G4 'wrapped fake adapter remains synthetic and untrusted' {
        $e=New-ChatpadExactSuiteEnvironment
        $wrapper=[pscustomobject]@{inner=$e.adapter;adapter_identity='chatpad-windows-exact-instance-adapter-v1';synthetic=$false;mode='windows-exact-instance'}
        $r=Test-ChatpadNativeAdapterOperationGate Apply -AdapterObject $wrapper -AdapterName $wrapper.adapter_identity -Mode $wrapper.mode -Synthetic:$false
        [pscustomobject]@{checks=@(($r.fake_adapter_trusted-eq$false),($r.caller_object_trusted-eq$false),($r.live_capability_present-eq$false),(@($e.adapter.call_log|Where-Object{$_.operation-match'bind|restore|restart'}).Count-eq0));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase G5 'caller-created adapter object cannot satisfy trusted interface' {
        $caller=[pscustomobject]@{capability_present=$true;result='PASS';result_code='TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT'}
        $r=Test-ChatpadNativeAdapterOperationGate Restore -AdapterObject $caller -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restore -Synthetic:$false
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.caller_object_trusted-eq$false),($r.live_capability_present-eq$false),($r.live_restoration_authorized-eq$false),($r.caller_supplied_capability_accepted-eq$false));details=$r}
    }))

    $results.Add((Invoke-ChatpadExactCase G6 'serialized capability cannot be restored' {
        $probe=[pscustomobject]@{capability_present=$true;capability_source='future-internal-production-composition-root'}
        $restored=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($probe,8))
        $r=Test-ChatpadNativeMutationCapability
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq$nativeOperationBlocker),($r.capability_present-eq$false),($r.capability_serializable-eq$false));details=[pscustomobject]@{restored_type=$restored.GetType().FullName;validation=$r}}
    }))

    $results.Add((Invoke-ChatpadExactCase G7 'read-only capability cannot satisfy mutation interface' {
        $readOnly=New-ChatpadNativeReadOnlyDesignProbe
        $read=Test-ChatpadNativeReadOnlyCapability -Probe $readOnly
        $mutation=Test-ChatpadNativeMutationCapability
        [pscustomobject]@{checks=@(($read.result-eq'PASS'),($read.mutation_capability_present-eq$false),($read.authorizes_mutation-eq$false),($mutation.result-eq'BLOCKED'),($mutation.capability_present-eq$false));details=[pscustomobject]@{read_only=$read;mutation=$mutation}}
    }))

    $results.Add((Invoke-ChatpadExactCase G8 'composition root cannot construct live capability now' {
        $threw=$false;$message=''
        try{[void](New-ChatpadNativeMutationCapability)}catch{$threw=$true;$message=$_.Exception.Message}
        $contract=Get-ChatpadNativeAdapterDesignContract
        [pscustomobject]@{checks=@(($threw-eq$true),($message-eq$nativeOperationBlocker),($contract.composition_root.present_in_this_task-eq$true),($contract.composition_root.fake_adapter_satisfies-eq$false));details=[pscustomobject]@{message=$message;composition_root=$contract.composition_root}}
    }))

    $results.Add((Invoke-ChatpadExactCase G9 'native declaration guard' {
        $guard=Test-ChatpadNativeExecutableGuard
        $declarationMatches=@($guard.matches|Where-Object{$_.guard-eq'native-declaration'})
        [pscustomobject]@{checks=@(($guard.result-eq'PASS'),($declarationMatches.Count-eq0),($guard.scanned_file_count-gt0));details=$guard}
    }))

    $results.Add((Invoke-ChatpadExactCase G10 'native invocation guard' {
        $guard=Test-ChatpadNativeExecutableGuard
        $invocationMatches=@($guard.matches|Where-Object{$_.guard-eq'native-invocation'})
        [pscustomobject]@{checks=@(($guard.result-eq'PASS'),($invocationMatches.Count-eq0),($guard.scanned_file_count-gt0));details=$guard}
    }))

    $results.Add((Invoke-ChatpadExactCase G11 'exact API sequence completeness' {
        $contract=Get-ChatpadNativeAdapterDesignContract
        $complete=Test-ChatpadNativeDesignContractCompleteness
        [pscustomobject]@{checks=@(($complete.result-eq'PASS'),($complete.required_call_count-eq12),($complete.operation_gate_count-eq18),($complete.structure_count-ge8));details=[pscustomobject]@{contract=$contract;completeness=$complete}}
    }))

    $results.Add((Invoke-ChatpadExactCase G12 'restoration identity remains snapshot-derived' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '39000000-0000-0000-0000-000000000040' $ImplementationCommit -OperationType restore
        $snapshotIdentity=Get-ChatpadExactProperty $p.plan.restoration_snapshot 'driver_identity' $null
        $planIdentity=Get-ChatpadExactProperty $p.plan 'exact_restoration_driver_identity' $null
        [pscustomobject]@{checks=@((Test-ChatpadExactDeepEqual $snapshotIdentity $planIdentity),($snapshotIdentity.driver_node_id-eq$p.snapshot.driver_identity.driver_node_id),($p.plan.restoration_snapshot_fingerprint-eq$p.snapshot.snapshot_sha256));details=[pscustomobject]@{snapshot_identity=$snapshotIdentity;plan_identity=$planIdentity;fingerprint=$p.plan.restoration_snapshot_fingerprint}}
    }))

    $results.Add((Invoke-ChatpadExactCase G13 'uncertain native result cannot become ordinary failure or success' {
        $contract=Get-ChatpadNativeAdapterDesignContract
        $bindFailure=@($contract.error_taxonomy|Where-Object code -eq 'BIND_FAILURE_AFTER_POSSIBLE_MUTATION')[0]
        $uncertain=@($contract.error_taxonomy|Where-Object code -eq 'UNCERTAIN_DEVICE_STATE')[0]
        [pscustomobject]@{checks=@(($bindFailure.restoration_required-eq$true),($bindFailure.retry_prohibited-eq$true),($uncertain.manual_recovery_required-eq$true),($uncertain.controlled_failure-eq$true));details=[pscustomobject]@{bind_failure=$bindFailure;uncertain_state=$uncertain}}
    }))

    $results.Add((Invoke-ChatpadExactCase G14 'restart and reboot indications do not perform action' {
        $contract=Get-ChatpadNativeAdapterDesignContract
        $restart=@($contract.error_taxonomy|Where-Object code -eq 'RESTART_REQUIRED')[0]
        $reboot=@($contract.error_taxonomy|Where-Object code -eq 'REBOOT_REQUIRED')[0]
        $gate=Test-ChatpadNativeAdapterOperationGate Restart -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restart -Synthetic:$false
        [pscustomobject]@{checks=@(($restart.restart_pending-eq$true),($reboot.reboot_pending-eq$true),($gate.result_code-eq$nativeOperationBlocker),($gate.live_restart_authorized-eq$false),($gate.windows_mutations_performed-eq0));details=[pscustomobject]@{restart=$restart;reboot=$reboot;gate=$gate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G15 'live evidence remains unavailable and spoofing is rejected' {
        $e=New-ChatpadExactSuiteEnvironment;$p=New-ChatpadExactSuitePlan $e '3a000000-0000-0000-0000-000000000041' $ImplementationCommit
        $evidence=Invoke-ChatpadSyntheticExactApply $e.adapter $p.plan $p.plan.plan_sha256 $p.plan.operation_id $script:Validation -OfflineSyntheticAuthorization
        $spoof=Copy-ChatpadExactObject $evidence
        $spoof.synthetic=$false;$spoof.source_classification='live';$spoof.adapter_identity='chatpad-windows-exact-instance-adapter-v1';$spoof.adapter_mode='windows-exact-instance';$spoof.producer='future-live-producer';$spoof.evidence_mode='live'
        $validation=Test-ChatpadExactInstanceEvidence $spoof
        [pscustomobject]@{checks=@(($evidence.source_classification-eq'synthetic'),($validation.result-eq'FAIL'),($validation.defects-contains'UNTRUSTED_EVIDENCE_ORIGIN'),($evidence.live_exact_binding_operation_count-eq0),($evidence.windows_mutation_count-eq0));details=[pscustomobject]@{evidence=$evidence;spoof_validation=$validation}}
    }))

    $results.Add((Invoke-ChatpadExactCase G16 'former SessionState sentinel extraction cannot authorize gate' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $sentinelVariable=$module.SessionState.PSVariable.Get('TrustedMutationCapabilitySentinel')
        $legacyParameterRejected=$false;$legacyExceptionType=''
        try{[void](Test-ChatpadNativeAdapterOperationGate Apply -Capability $(if($null-eq$sentinelVariable){$null}else{$sentinelVariable.Value}) -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true)}catch{$legacyParameterRejected=$true;$legacyExceptionType=$_.Exception.GetType().FullName}
        $gate=Test-ChatpadNativeAdapterOperationGate Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        [pscustomobject]@{checks=@(($null-eq$sentinelVariable),($legacyParameterRejected-eq$true),($legacyExceptionType-match'ParameterBinding'),($gate.result-eq'BLOCKED'),($gate.live_capability_present-eq$false),($gate.windows_mutations_performed-eq0));details=[pscustomobject]@{sentinel_variable_present=($null-ne$sentinelVariable);legacy_exception_type=$legacyExceptionType;gate=$gate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G17 'module session-state enumeration exposes no mutation capability object' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $ampNames=@(& $module { Get-Variable -Name '*Capability*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name })
        $sessionNames=@($module.SessionState.InvokeCommand.InvokeScript('Get-Variable -Name *Capability* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name'))
        $trustedNames=@($ampNames+$sessionNames|Where-Object{$_ -match 'Trusted.*Mutation|Mutation.*Sentinel|CapabilitySentinel'})
        [pscustomobject]@{checks=@(($ampNames.Count-eq0),($sessionNames.Count-eq0),($trustedNames.Count-eq0));details=[pscustomobject]@{ampersand_module_variable_names=$ampNames;session_state_variable_names=$sessionNames;trusted_names=$trustedNames}}
    }))

    $results.Add((Invoke-ChatpadExactCase G18 'module-context invocation remains blocked' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $ampGate=& $module { Test-ChatpadNativeAdapterOperationGate Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true }
        $sessionGate=$module.SessionState.InvokeCommand.InvokeScript("Test-ChatpadNativeAdapterOperationGate Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restore -Synthetic:`$false -IsElevated `$true -AllowWindowsMutation `$true")
        [pscustomobject]@{checks=@(($ampGate.result-eq'BLOCKED'),($sessionGate.result-eq'BLOCKED'),($ampGate.live_capability_present-eq$false),($sessionGate.live_capability_present-eq$false),($ampGate.windows_mutations_performed+$sessionGate.windows_mutations_performed-eq0));details=[pscustomobject]@{ampersand_module_gate=$ampGate;session_state_gate=$sessionGate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G19 'non-exported and internal function discovery cannot produce authorization' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $exported=@(Get-Command -Module ChatpadNativeAdapterDesignGate)
        $allFunctions=@($module.SessionState.InvokeCommand.GetCommands('*Chatpad*','Function',$true))
        $nonExported=@($allFunctions|Where-Object{$exported.Name -notcontains $_.Name})
        $nonExportedNative=@($nonExported|Where-Object{$_.Name-match'Native|Mutation|Capability|OperationGate'})
        $mutationProbe=Test-ChatpadNativeMutationCapability
        $suspectParameters=@($allFunctions|Where-Object{$_.Name-match'Mutation|OperationGate'}|ForEach-Object{foreach($name in $_.Parameters.Keys){if($name-match'Capability|Token|Sentinel|Secret'){[pscustomobject]@{function=$_.Name;parameter=$name}}}})
        [pscustomobject]@{checks=@(($nonExportedNative.Count-eq0),($mutationProbe.result-eq'BLOCKED'),($mutationProbe.capability_present-eq$false),($suspectParameters.Count-eq0));details=[pscustomobject]@{all_function_names=@($allFunctions|ForEach-Object Name);non_exported_function_names=@($nonExported|ForEach-Object Name);non_exported_native_function_names=@($nonExportedNative|ForEach-Object Name);suspect_parameters=$suspectParameters;mutation_probe=$mutationProbe}}
    }))

    $results.Add((Invoke-ChatpadExactCase G20 'extracted references and wrappers cannot satisfy operation gate' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $extracted=$module.SessionState.PSVariable.Get('TrustedMutationCapabilitySentinel')
        $inner=if($null-eq$extracted){[object]::new()}else{$extracted.Value}
        $wrapper=[pscustomobject]@{inner=$inner;capability_present=$true;result='PASS';result_code='TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT'}
        $gate=Test-ChatpadNativeAdapterOperationGate Restore -AdapterObject $wrapper -Evidence $wrapper -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Restore -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true
        [pscustomobject]@{checks=@(($gate.result-eq'BLOCKED'),($gate.caller_object_trusted-eq$false),($gate.evidence_trusted-eq$false),($gate.live_restoration_authorized-eq$false),($gate.windows_mutations_performed-eq0));details=[pscustomobject]@{extracted_variable_present=($null-ne$extracted);wrapper=$wrapper;gate=$gate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G21 'PSCustomObject PSTypeNames and Add-Member cannot authorize mutation' {
        $candidate=[pscustomobject]@{capability_present=$true;result='PASS';result_code='TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT'}
        $candidate.PSTypeNames.Insert(0,'Chatpad.TrustedNativeMutationCapability')
        $candidate|Add-Member -NotePropertyName TrustedMutationCapabilitySentinel -NotePropertyValue ([object]::new())
        $legacyRejected=$false;$legacyExceptionType=''
        try{[void](Test-ChatpadNativeAdapterOperationGate Apply -Capability $candidate -AdapterObject $candidate -Evidence $candidate)}catch{$legacyRejected=$true;$legacyExceptionType=$_.Exception.GetType().FullName}
        $gate=Test-ChatpadNativeAdapterOperationGate Apply -AdapterObject $candidate -Evidence $candidate -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false
        [pscustomobject]@{checks=@(($legacyRejected-eq$true),($legacyExceptionType-match'ParameterBinding'),($gate.result-eq'BLOCKED'),($gate.live_binding_authorized-eq$false),($gate.windows_mutations_performed-eq0));details=[pscustomobject]@{legacy_exception_type=$legacyExceptionType;candidate=$candidate;gate=$gate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G22 'serialized scalars GUIDs and arbitrary objects cannot authorize mutation' {
        $values=@('TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT',42,$true,[guid]::NewGuid(),[object]::new())
        $legacyRejectCount=0
        foreach($value in $values){try{[void](Test-ChatpadNativeAdapterOperationGate Apply -Capability $value)}catch{if($_.Exception.GetType().FullName-match'ParameterBinding'){$legacyRejectCount++}}}
        $payload=[pscustomobject]@{capability_present=$true;nested=[pscustomobject]@{sentinel=[object]::new()}}
        $restored=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($payload,8))
        $gate=Test-ChatpadNativeAdapterOperationGate Apply -AdapterObject $restored -Evidence $restored -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode Apply -Synthetic:$false
        [pscustomobject]@{checks=@(($legacyRejectCount-eq$values.Count),($gate.result_code-eq$nativeOperationBlocker),($gate.live_capability_present-eq$false),($gate.windows_mutations_performed-eq0));details=[pscustomobject]@{legacy_reject_count=$legacyRejectCount;candidate_count=$values.Count;restored_type=$restored.GetType().FullName;gate=$gate}}
    }))

    $results.Add((Invoke-ChatpadExactCase G23 'exported mutation API accepts no caller-supplied capability parameter' {
        $exported=@(Get-Command -Module ChatpadNativeAdapterDesignGate)
        $suspect=@($exported|Where-Object{$_.Name-match'Mutation|OperationGate'}|ForEach-Object{foreach($name in $_.Parameters.Keys){if($name-match'Capability|Token|Sentinel|Secret'){[pscustomobject]@{function=$_.Name;parameter=$name}}}})
        $gateCommand=$exported|Where-Object Name -eq 'Test-ChatpadNativeAdapterOperationGate'|Select-Object -First 1
        [pscustomobject]@{checks=@(($null-ne$gateCommand),($gateCommand.Parameters.Keys-notcontains'Capability'),($suspect.Count-eq0));details=[pscustomobject]@{exported=@($exported|ForEach-Object{[pscustomobject]@{name=$_.Name;parameters=@($_.Parameters.Keys)}});suspect_parameters=$suspect}}
    }))

    $results.Add((Invoke-ChatpadExactCase G24 'design contract states PowerShell object possession is not a trust boundary' {
        $contract=Get-ChatpadNativeAdapterDesignContract
        [pscustomobject]@{checks=@(($contract.module_state_introspectable_by_same_process_callers-eq$true),($contract.caller_supplied_mutation_capability_accepted-eq$false),($contract.composition_root.module_private_object_trust_boundary-eq$false),($contract.composition_root.public_or_exported_caller_supplied_capability_parameter-eq$false),($contract.current_gate-eq$scaffoldAuditGate));details=$contract}
    }))

    $results.Add((Invoke-ChatpadExactCase G25 'all public mutation operations remain blocked with zero mutation counters' {
        $ops=@('Apply','Restore','Restart')
        $gates=@($ops|ForEach-Object{Test-ChatpadNativeAdapterOperationGate $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Mode $_ -Synthetic:$false -IsElevated $true -AllowWindowsMutation $true})
        [pscustomobject]@{checks=@((@($gates|Where-Object result -ne 'BLOCKED').Count-eq0),(@($gates|Where-Object live_capability_present -ne $false).Count-eq0),(@($gates|Where-Object live_binding_authorized -ne $false).Count-eq0),(@($gates|Where-Object live_restoration_authorized -ne $false).Count-eq0),(@($gates|Where-Object live_restart_authorized -ne $false).Count-eq0),([int](($gates|Measure-Object windows_mutations_performed -Sum).Sum)-eq0));details=[pscustomobject]@{gates=$gates}}
    }))

    $results.Add((Invoke-ChatpadExactCase G26 'production adapter resolves only by stable identifier' {
        $r=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -RequireExplicitSelection
        [pscustomobject]@{checks=@(($r.result-eq'PASS'),($r.result_code-eq'NATIVE_ADAPTER_SELECTED'),($r.selected_adapter.adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'),($r.selected_adapter.production-eq$true));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G27 'synthetic adapter resolves only when explicitly synthetic' {
        $blocked=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-fake-exact-instance-adapter-v1' -Synthetic:$false -RequireExplicitSelection
        $selected=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-fake-exact-instance-adapter-v1' -Synthetic:$true -RequireExplicitSelection
        [pscustomobject]@{checks=@(($blocked.result_code-eq'SYNTHETIC_ADAPTER_REQUIRES_EXPLICIT_SYNTHETIC_MODE'),($selected.result-eq'PASS'),($selected.selected_adapter.synthetic-eq$true),($selected.fallback_used-eq$false));details=[pscustomobject]@{blocked=$blocked;selected=$selected}}
    }))
    $results.Add((Invoke-ChatpadExactCase G28 'unknown adapter identifiers fail closed' {
        $r=Resolve-ChatpadNativeAdapter -AdapterName 'unknown-adapter' -Synthetic:$false -RequireExplicitSelection
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'),($r.selected_adapter-eq$null),($r.fallback_used-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G29 'production selection never falls back to synthetic' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'unknown-adapter' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'),($r.fallback_used-eq$false),($r.synthetic-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G30 'missing required adapter selection fails closed' {
        $resolver=Resolve-ChatpadNativeAdapter -AdapterName '' -RequireExplicitSelection
        $public=Invoke-ChatpadNativeAdapterOperation -Operation Apply
        [pscustomobject]@{checks=@(
            ($resolver.result-eq'BLOCKED'),
            ($resolver.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($public.result-eq'BLOCKED'),
            ($public.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($public.selected_adapter_identity-eq''),
            ($public.production-eq$false),
            ($public.synthetic-eq$false),
            ($public.native_operations_performed-eq0),
            ($public.live_device_queries_performed-eq0),
            ($public.windows_mutations_performed-eq0)
        );details=[pscustomobject]@{resolver=$resolver;public_entry=$public}}
    }))
    $results.Add((Invoke-ChatpadExactCase G31 'selected adapter identity appears in operation evidence' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'),($r.selected_adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'),($r.composition.adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G32 'repeated composition resolution is deterministic' {
        $a=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -RequireExplicitSelection
        $b=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -RequireExplicitSelection
        [pscustomobject]@{checks=@(($a.result_code-eq$b.result_code),($a.selected_adapter.adapter_identity-eq$b.selected_adapter.adapter_identity),($a.selected_adapter.execution_state-eq$b.selected_adapter.execution_state));details=[pscustomobject]@{first=$a;second=$b}}
    }))
    $results.Add((Invoke-ChatpadExactCase G33 'adapter contract completeness validates production scaffold' {
        $complete=Test-ChatpadNativeDesignContractCompleteness
        [pscustomobject]@{checks=@(($complete.result-eq'PASS'),($complete.production_scaffold_complete-eq$true),($complete.operation_gate_count-eq18));details=$complete}
    }))
    $results.Add((Invoke-ChatpadExactCase G34 'every recognized native operation returns scaffold blocked result' {
        $ops=Get-ChatpadNativeSupportedOperationIdentifiers
        $records=@($ops|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false})
        [pscustomobject]@{checks=@(($ops.Count-eq3),(@($records|Where-Object result_code -ne $nativeOperationBlocker).Count-eq0),(@($records|Where-Object execution_attempted -ne $false).Count-eq0));details=[pscustomobject]@{operations=$ops;records=$records}}
    }))
    $results.Add((Invoke-ChatpadExactCase G35 'unknown native operation returns unsupported operation' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation 'InstallPackage' -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'),($r.operation_known-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G36 'production scaffold leaves Windows mutation count zero' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.windows_mutations_performed-eq0),($r.windows_mutation_available-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G37 'production scaffold leaves device query count zero' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.live_device_queries_performed-eq0),($r.device_queries_available-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G38 'production scaffold leaves native operation count zero' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Restart -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.native_operations_performed-eq0),($r.native_interop_implemented-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G39 'production scaffold never claims execution occurred' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.execution_attempted-eq$false),($r.result-eq'BLOCKED'),($r.reason-match'not implemented'));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G40 'production scaffold never claims device state changed' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.device_found-eq$false),($r.device_bound-eq$false),($r.device_updated-eq$false),($r.device_restored-eq$false),($r.device_restarted-eq$false),($r.device_installed-eq$false));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G41 'production operation evidence is schema-tagged and deterministic' {
        $a=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        $b=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($a.schema_version-eq'chatpad-native-adapter-operation-evidence-v1'),($a.result_code-eq$b.result_code),($a.selected_adapter_identity-eq$b.selected_adapter_identity),($a.native_operations_performed-eq$b.native_operations_performed));details=[pscustomobject]@{first=$a;second=$b}}
    }))
    $results.Add((Invoke-ChatpadExactCase G42 'production metadata states native execution is not implemented' {
        $adapter=New-ChatpadProductionNativeAdapter
        [pscustomobject]@{checks=@(($adapter.native_interop_implemented-eq$false),($adapter.live_execution_available-eq$false),($adapter.execution_state-eq'non-executing-scaffold'));details=$adapter}
    }))
    $results.Add((Invoke-ChatpadExactCase G43 'production metadata states live readiness is blocked' {
        $adapter=New-ChatpadProductionNativeAdapter
        [pscustomobject]@{checks=@(($adapter.current_gate-eq$scaffoldAuditGate),($adapter.capability_blocker-eq$nativeOperationBlocker),($adapter.fail_closed-eq$true));details=$adapter}
    }))
    $results.Add((Invoke-ChatpadExactCase G44 'mutation-capability compatibility API output cannot alter production result' {
        $probe=Test-ChatpadNativeMutationCapability
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $probe -Evidence $probe
        [pscustomobject]@{checks=@(($probe.capability_present-eq$false),($r.result_code-eq$nativeOperationBlocker),($r.caller_supplied_capability_accepted-eq$false),($r.native_operations_performed-eq0));details=[pscustomobject]@{probe=$probe;result=$r}}
    }))
    $results.Add((Invoke-ChatpadExactCase G45 'arbitrary objects cannot authorize scaffold execution' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject ([object]::new())
        [pscustomobject]@{checks=@(($r.result_code-eq$nativeOperationBlocker),($r.caller_object_trusted-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G46 'module variable mutation cannot alter public composition or evidence' {
        $modulePath=(Join-Path $PSScriptRoot 'ChatpadNativeAdapterDesignGate.psm1').Replace("'","''")
        $probe=Invoke-ChatpadIsolatedIntegrityProbe @"
Import-Module '$modulePath' -Force
`$module=Get-Module ChatpadNativeAdapterDesignGate
foreach(`$name in @('ProductionNativeAdapterId','SyntheticAdapterId','SupportedNativeOperations','NativeExecutionBlocker','LiveAdapterBlocker','ScaffoldAuditGate','NativeDesignSchema','NativeAdapterContractSchema','NativeCompositionSchema','NativeOperationEvidenceSchema','AdapterKind','NativeInteropImplemented','SyntheticMode','WindowsMutationCount')){
    `$module.SessionState.PSVariable.Set(`$name,'PASS')
}
`$unknown=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'audit-controlled'
`$apply=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
`$install=Invoke-ChatpadNativeAdapterOperation -Operation InstallPackage -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
[pscustomobject]@{unknown=`$unknown;apply=`$apply;install=`$install}|ConvertTo-Json -Depth 20
"@
        [pscustomobject]@{checks=@(
            ($probe.unknown.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'),
            ($probe.unknown.selected_adapter_identity-eq''),
            ($probe.apply.result_code-eq$nativeOperationBlocker),
            ($probe.apply.current_gate-eq$scaffoldAuditGate),
            ($probe.apply.selected_adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'),
            ($probe.apply.native_operations_performed-eq0),
            ($probe.apply.live_device_queries_performed-eq0),
            ($probe.apply.windows_mutations_performed-eq0),
            ($probe.install.result_code-eq'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'),
            ($probe.install.operation_known-eq$false)
        );details=$probe}
    }))
    $results.Add((Invoke-ChatpadExactCase G47 'module-context invocation cannot authorize scaffold execution' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $r=& $module { Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false }
        [pscustomobject]@{checks=@(($r.result_code-eq$nativeOperationBlocker),($r.live_binding_authorized-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G48 'splatting capability-like names is rejected' {
        $rejected=$false;$type=''
        try{[void](Invoke-ChatpadNativeAdapterOperation @{'Operation'='Apply';'AdapterName'='chatpad-windows-exact-instance-adapter-v1';'Capability'=[object]::new()})}catch{$rejected=$true;$type=$_.Exception.GetType().FullName}
        [pscustomobject]@{checks=@(($rejected-eq$true),($type-match'ParameterBinding'));details=[pscustomobject]@{rejected=$rejected;exception_type=$type}}
    }))
    $results.Add((Invoke-ChatpadExactCase G49 'legacy capability parameter names are rejected' {
        $names=@('Capability','NativeCapability','MutationCapability','TrustedCapability','TrustedMutationCapability','TrustedMutationCapabilitySentinel','Sentinel','Token','Secret','TrustedContext','MutationAuthorization','Authorization','Options')
        $rejected=0
        foreach($name in $names){try{[void](Invoke-ChatpadNativeAdapterOperation @{'Operation'='Apply';'AdapterName'='chatpad-windows-exact-instance-adapter-v1';$name=[object]::new()})}catch{if($_.Exception.GetType().FullName-match'ParameterBinding'){$rejected++}}}
        [pscustomobject]@{checks=@(($rejected-eq$names.Count),($names.Count-ge13));details=[pscustomobject]@{names=$names;rejected=$rejected}}
    }))
    $results.Add((Invoke-ChatpadExactCase G50 'positional arguments cannot reach hidden authorization slot' {
        $rejected=$false;$type=''
        try{[void](Invoke-ChatpadNativeAdapterOperation Apply 'chatpad-windows-exact-instance-adapter-v1' $false ([object]::new()) 'extra')}catch{$rejected=$true;$type=$_.Exception.GetType().FullName}
        [pscustomobject]@{checks=@(($rejected-eq$true),($type-match'ParameterBinding'));details=[pscustomobject]@{rejected=$rejected;exception_type=$type}}
    }))
    $results.Add((Invoke-ChatpadExactCase G51 'pipeline input cannot authorize scaffold execution' {
        $candidate=[pscustomobject]@{Capability=[object]::new()}
        $rejected=$false;$type='';$r=$null
        try{$r=$candidate | Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false}catch{$rejected=$true;$type=$_.Exception.GetType().FullName}
        $blocked=($null-ne$r -and $r.result_code-eq$nativeOperationBlocker -and $r.caller_supplied_capability_accepted-eq$false -and $r.native_operations_performed-eq0)
        [pscustomobject]@{checks=@(($blocked-or($rejected-and$type-match'ParameterBinding')));details=[pscustomobject]@{rejected=$rejected;exception_type=$type;result=$r}}
    }))
    $results.Add((Invoke-ChatpadExactCase G52 'wrapped references cannot authorize scaffold execution' {
        $wrapper=[pscustomobject]@{inner=[object]::new();Capability=[object]::new()}
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $wrapper -Evidence $wrapper
        [pscustomobject]@{checks=@(($r.result_code-eq$nativeOperationBlocker),($r.caller_object_trusted-eq$false),($r.evidence_trusted-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G53 'serialized objects cannot authorize scaffold execution' {
        $payload=[pscustomobject]@{secret='TOKEN';inner=[object]::new()}
        $restored=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($payload,8))
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $restored
        [pscustomobject]@{checks=@(($r.result_code-eq$nativeOperationBlocker),($r.native_operations_performed-eq0),($r.windows_mutations_performed-eq0));details=[pscustomobject]@{restored_type=$restored.GetType().FullName;result=$r}}
    }))
    $results.Add((Invoke-ChatpadExactCase G54 'PSCustomObject PSTypeNames and Add-Member cannot authorize scaffold execution' {
        $candidate=[pscustomobject]@{result='PASS'}
        $candidate.PSTypeNames.Insert(0,'Chatpad.Native.Adapter.Authority')
        $candidate|Add-Member -NotePropertyName Authorization -NotePropertyValue ([object]::new())
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $candidate
        [pscustomobject]@{checks=@(($r.result_code-eq$nativeOperationBlocker),($r.caller_object_trusted-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G55 'scalar values cannot authorize scaffold execution' {
        $values=@('TOKEN',[guid]::NewGuid(),$true,42,3.14)
        $records=@($values|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $_})
        [pscustomobject]@{checks=@((@($records|Where-Object result_code -ne $nativeOperationBlocker).Count-eq0),([int](($records|Measure-Object native_operations_performed -Sum).Sum)-eq0));details=[pscustomobject]@{records=$records}}
    }))
    $results.Add((Invoke-ChatpadExactCase G56 'all adversarial scaffold attempts leave counters zero' {
        $objects=@([object]::new(),[pscustomobject]@{Capability=[object]::new()},'TOKEN',42,$true)
        $runs=@($objects|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $_ -Evidence $_})
        [pscustomobject]@{checks=@(([int](($runs|Measure-Object windows_mutations_performed -Sum).Sum)-eq0),([int](($runs|Measure-Object live_device_queries_performed -Sum).Sum)-eq0),([int](($runs|Measure-Object native_operations_performed -Sum).Sum)-eq0));details=[pscustomobject]@{runs=$runs}}
    }))
    $results.Add((Invoke-ChatpadExactCase G57 'exported functions and parameters match public scaffold API' {
        $exported=@(Get-Command -Module ChatpadNativeAdapterDesignGate)
        $suspect=@($exported|ForEach-Object{foreach($name in $_.Parameters.Keys){if($name-match'Capability|Sentinel|Token|Secret|Authorization|TrustedContext'){[pscustomobject]@{function=$_.Name;parameter=$name}}}})
        $operation=($exported|Where-Object Name -eq 'Invoke-ChatpadNativeAdapterOperation'|Select-Object -First 1)
        [pscustomobject]@{checks=@(($null-ne$operation),($operation.Parameters.Keys -contains 'Operation'),($operation.Parameters.Keys -contains 'AdapterName'),($suspect.Count-eq0));details=[pscustomobject]@{exported=@($exported|ForEach-Object{[pscustomobject]@{name=$_.Name;parameters=@($_.Parameters.Keys)}});suspect=$suspect}}
    }))
    $results.Add((Invoke-ChatpadExactCase G58 'no exported variable contains execution authority' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $vars=@($module.ExportedVariables.Keys)
        [pscustomobject]@{checks=@(($vars.Count-eq0));details=[pscustomobject]@{exported_variables=$vars}}
    }))
    $results.Add((Invoke-ChatpadExactCase G59 'module scope contains no authorization sentinel' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $names=@($module.SessionState.InvokeCommand.InvokeScript('Get-Variable | Select-Object -ExpandProperty Name'))
        $sentinels=@($names|Where-Object{$_ -match 'TrustedMutationCapabilitySentinel|CapabilitySentinel|Secret|Token'})
        [pscustomobject]@{checks=@(($sentinels.Count-eq0));details=[pscustomobject]@{sentinels=$sentinels;variable_count=$names.Count}}
    }))
    $results.Add((Invoke-ChatpadExactCase G60 'no callable internal function performs native execution' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $functions=@($module.SessionState.InvokeCommand.GetCommands('*Chatpad*','Function',$true))
        $nativeExec=@($functions|Where-Object{$_.Name-match'PnP|Setup|Newdev|Config|Executable'})
        [pscustomobject]@{checks=@(($nativeExec.Count-eq1),($nativeExec[0].Name-eq'Test-ChatpadNativeExecutableGuard'));details=[pscustomobject]@{native_named_functions=@($nativeExec|ForEach-Object Name)}}
    }))
    $results.Add((Invoke-ChatpadExactCase G61 'no executable native declaration is loaded or discoverable' {
        $guard=Test-ChatpadNativeExecutableGuard
        [pscustomobject]@{checks=@(($guard.result-eq'PASS'),($guard.match_count-eq0),($guard.scanned_file_count-gt0));details=$guard}
    }))
    $results.Add((Invoke-ChatpadExactCase G62 'generic object parameters cannot select mutation-authorized state' {
        $candidate=[pscustomobject]@{adapter_identity='chatpad-windows-exact-instance-adapter-v1';native_interop_implemented=$true;windows_mutation_available=$true}
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false -AdapterObject $candidate
        [pscustomobject]@{checks=@(($r.native_interop_implemented-eq$false),($r.windows_mutation_available-eq$false),($r.caller_object_trusted-eq$false),($r.native_operations_performed-eq0));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G63 'new scaffold fixtures have assertions' {
        $new=@($results|Where-Object{$_.fixture_id -match '^G(2[6-9]|[3-5][0-9]|6[0-2])$'})
        [pscustomobject]@{checks=@(($new.Count-eq37),(@($new|Where-Object assertion_count -le 0).Count-eq0));details=[pscustomobject]@{fixture_count=$new.Count}}
    }))
    $results.Add((Invoke-ChatpadExactCase G64 'new scaffold fixture identifiers are unique' {
        $newIds=@($results|Where-Object{$_.fixture_id -match '^G(2[6-9]|[3-5][0-9]|6[0-3])$'}|ForEach-Object fixture_id)
        [pscustomobject]@{checks=@(($newIds.Count-eq(@($newIds|Select-Object -Unique).Count)),($newIds.Count-ge38));details=[pscustomobject]@{ids=$newIds}}
    }))
    $results.Add((Invoke-ChatpadExactCase G65 'no new scaffold fixture passes with zero assertions' {
        $zero=@($results|Where-Object{$_.fixture_id -match '^G(2[6-9]|[3-5][0-9]|6[0-4])$' -and $_.fixture_result-eq'PASS' -and $_.assertion_count-eq0})
        [pscustomobject]@{checks=@(($zero.Count-eq0));details=[pscustomobject]@{zero_assertion_ids=@($zero|ForEach-Object fixture_id)}}
    }))
    $results.Add((Invoke-ChatpadExactCase G66 'runtime-equivalent scaffold result is semantic and deterministic' {
        $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Synthetic:$false
        [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq$nativeOperationBlocker),($r.current_gate-eq$scaffoldAuditGate));details=$r}
    }))
    $results.Add((Invoke-ChatpadExactCase G67 'final scaffold gate records compile-only validation is not authorized' {
        $contract=Get-ChatpadNativeAdapterDesignContract
        $adapter=New-ChatpadProductionNativeAdapter
        [pscustomobject]@{checks=@(($contract.current_gate-eq$scaffoldAuditGate),($adapter.current_gate-eq$scaffoldAuditGate),($contract.live_adapter_status-eq'SCAFFOLD_NON_EXECUTING'),($adapter.native_interop_implemented-eq$false));details=[pscustomobject]@{contract=$contract;adapter=$adapter}}
    }))

    $results.Add((Invoke-ChatpadExactCase G68 'public operation entry requires explicit primitive adapter selection' {
        $omitted=Invoke-ChatpadNativeAdapterOperation -Operation Apply
        $nullValue=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName $null
        $empty=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName ''
        $white=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName '   '
        $emptyArray=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName @()
        $object=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName ([pscustomobject]@{adapter_identity='chatpad-windows-exact-instance-adapter-v1'})
        $unknown=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'unknown-adapter'
        $production=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
        $synthetic=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-fake-exact-instance-adapter-v1' -Synthetic -RequireExplicitSelection
        $syntheticBlocked=Resolve-ChatpadNativeAdapter -AdapterName 'chatpad-fake-exact-instance-adapter-v1' -RequireExplicitSelection
        $invalid=@($omitted,$nullValue,$empty,$white,$emptyArray,$object,$unknown)
        [pscustomobject]@{checks=@(
            ($omitted.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($nullValue.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($empty.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($white.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($emptyArray.result_code-eq'INVALID_NATIVE_ADAPTER_IDENTIFIER'),
            ($object.result_code-eq'INVALID_NATIVE_ADAPTER_IDENTIFIER'),
            ($unknown.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'),
            (@($invalid|Where-Object selected_adapter_identity -ne '').Count-eq0),
            (@($invalid|Where-Object production -eq $true).Count-eq0),
            (@($invalid|Where-Object synthetic -eq $true).Count-eq0),
            ($production.result_code-eq$nativeOperationBlocker),
            ($production.production-eq$true),
            ($synthetic.result_code-eq'SYNTHETIC_ADAPTER_SELECTED'),
            ($synthetic.selected_adapter.synthetic-eq$true),
            ($syntheticBlocked.result_code-eq'SYNTHETIC_ADAPTER_REQUIRES_EXPLICIT_SYNTHETIC_MODE'),
            ([int](($invalid|Measure-Object native_operations_performed -Sum).Sum)-eq0),
            ([int](($invalid|Measure-Object live_device_queries_performed -Sum).Sum)-eq0),
            ([int](($invalid|Measure-Object windows_mutations_performed -Sum).Sum)-eq0)
        );details=[pscustomobject]@{invalid=$invalid;production=$production;synthetic=$synthetic;synthetic_blocked=$syntheticBlocked}}
    }))

    $results.Add((Invoke-ChatpadExactCase G69 'all legacy module-state mutation forms remain non-authoritative' {
        $modulePath=(Join-Path $PSScriptRoot 'ChatpadNativeAdapterDesignGate.psm1').Replace("'","''")
        $probe=Invoke-ChatpadIsolatedIntegrityProbe @"
Import-Module '$modulePath' -Force
`$module=Get-Module ChatpadNativeAdapterDesignGate
`$names=@('ProductionNativeAdapterId','SyntheticAdapterId','SupportedNativeOperations','NativeExecutionBlocker','LiveAdapterBlocker','ScaffoldAuditGate','NativeDesignSchema','NativeAdapterContractSchema','NativeCompositionSchema','NativeOperationEvidenceSchema','AdapterKind','NativeInteropImplemented','SyntheticMode','ExecutionPerformed','NativeOperationsPerformed','LiveDeviceQueriesPerformed','WindowsMutationsPerformed')
foreach(`$name in `$names){`$module.SessionState.PSVariable.Set(`$name,'PASS')}
`$variable=`$module.SessionState.PSVariable.Get('ProductionNativeAdapterId')
`$variable.Value='value-setter-controlled'
& `$module { Set-Variable -Scope Script -Name SupportedNativeOperations -Value @('InstallPackage'); Set-Variable -Scope Script -Name ScaffoldAuditGate -Value 'PASS' }
`$unknown=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'value-setter-controlled'
`$production=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
`$install=Invoke-ChatpadNativeAdapterOperation -Operation InstallPackage -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
[pscustomobject]@{unknown=`$unknown;production=`$production;install=`$install;mutated_names=`$names}|ConvertTo-Json -Depth 20
"@
        [pscustomobject]@{checks=@(
            ($probe.unknown.result_code-eq'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'),
            ($probe.production.result_code-eq$nativeOperationBlocker),
            ($probe.production.current_gate-eq$scaffoldAuditGate),
            ($probe.production.execution_attempted-eq$false),
            ($probe.production.production-eq$true),
            ($probe.production.synthetic-eq$false),
            ($probe.production.native_interop_implemented-eq$false),
            ($probe.production.native_operations_performed-eq0),
            ($probe.production.live_device_queries_performed-eq0),
            ($probe.production.windows_mutations_performed-eq0),
            ($probe.install.result_code-eq'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'),
            ($probe.install.operation_known-eq$false),
            (@($probe.mutated_names).Count-ge17)
        );details=$probe}
    }))

    $results.Add((Invoke-ChatpadExactCase G70 'caller-extensible values are rejected without invoking caller behavior' {
        $global:ChatpadNativeCallerSideEffects=0
        $candidate=[pscustomobject]@{}
        $candidate.PSTypeNames.Insert(0,'Chatpad.Native.Adapter.Authority')
        $candidate|Add-Member -MemberType ScriptMethod -Name ToString -Value {$global:ChatpadNativeCallerSideEffects++;'chatpad-windows-exact-instance-adapter-v1'} -Force
        $candidate|Add-Member -MemberType ScriptMethod -Name Equals -Value {$global:ChatpadNativeCallerSideEffects++;$true} -Force
        $candidate|Add-Member -MemberType ScriptMethod -Name GetType -Value {$global:ChatpadNativeCallerSideEffects++;[string]} -Force
        $candidate|Add-Member -MemberType ScriptMethod -Name GetEnumerator -Value {$global:ChatpadNativeCallerSideEffects++;@().GetEnumerator()} -Force
        $candidate|Add-Member -MemberType ScriptProperty -Name DangerousProperty -Value {$global:ChatpadNativeCallerSideEffects++;throw 'CALLER_PROPERTY_INVOKED'}
        $dictionary=[Collections.Generic.Dictionary[string,object]]::new()
        $dictionary['adapter_identity']='chatpad-windows-exact-instance-adapter-v1'
        $delegate=[Action]{$global:ChatpadNativeCallerSideEffects++}
        $serialized=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize([pscustomobject]@{adapter_identity='chatpad-windows-exact-instance-adapter-v1'},4))
        $values=@($candidate,@($candidate),[pscustomobject]@{inner=$candidate},@{adapter_identity='chatpad-windows-exact-instance-adapter-v1'},$dictionary,{ 'chatpad-windows-exact-instance-adapter-v1' },$delegate,$serialized)
        $adapterResults=@($values|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName $_})
        $operationResults=@($values|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1'})
        [pscustomobject]@{checks=@(
            ($global:ChatpadNativeCallerSideEffects-eq0),
            (@($adapterResults|Where-Object{$_.result_code-ne'INVALID_NATIVE_ADAPTER_IDENTIFIER'}).Count-eq0),
            (@($adapterResults|Where-Object{$_.selected_adapter_identity-ne''}).Count-eq0),
            (@($operationResults|Where-Object{$_.result_code-ne'INVALID_NATIVE_ADAPTER_OPERATION_IDENTIFIER'}).Count-eq0),
            (@($operationResults|Where-Object{$_.operation_known-ne$false}).Count-eq0),
            ([int](($adapterResults|Measure-Object native_operations_performed -Sum).Sum)-eq0),
            ([int](($operationResults|Measure-Object windows_mutations_performed -Sum).Sum)-eq0)
        );details=[pscustomobject]@{side_effect_count=$global:ChatpadNativeCallerSideEffects;adapter_results=$adapterResults;operation_results=$operationResults}}
        Remove-Variable ChatpadNativeCallerSideEffects -Scope Global -ErrorAction SilentlyContinue
    }))

    $results.Add((Invoke-ChatpadExactCase G71 'caller evidence cannot override authoritative operation evidence' {
        $conflict=[pscustomobject]@{
            adapter_identity='chatpad-fake-exact-instance-adapter-v1'
            adapter_implementation_kind='live-native'
            synthetic=$true
            production=$false
            result='PASS'
            result_code='PASS'
            current_gate='PASS'
            execution_attempted=$true
            native_interop_implemented=$true
            native_operations_performed=7
            live_device_queries_performed=8
            windows_mutations_performed=9
            nested=[pscustomobject]@{result_code='PASS';windows_mutations_performed=-1}
        }
        $result=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -AdapterObject $conflict -Evidence $conflict
        [pscustomobject]@{checks=@(
            ($result.adapter_identity-eq'chatpad-windows-exact-instance-adapter-v1'),
            ($result.adapter_implementation_kind-eq'production-native-interop-source-boundary'),
            ($result.synthetic-eq$false),
            ($result.production-eq$true),
            ($result.result-eq'BLOCKED'),
            ($result.result_code-eq$nativeOperationBlocker),
            ($result.current_gate-eq$scaffoldAuditGate),
            ($result.execution_attempted-eq$false),
            ($result.native_interop_implemented-eq$false),
            ($result.native_operations_performed-eq0),
            ($result.live_device_queries_performed-eq0),
            ($result.windows_mutations_performed-eq0),
            ($result.details.caller_inputs_authoritative-eq$false)
        );details=$result}
    }))

    $results.Add((Invoke-ChatpadExactCase G72 'supported operations and result mapping are code-local and canonical' {
        $operations=Get-ChatpadNativeSupportedOperationIdentifiers
        $records=@($operations|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1'})
        $caseVariant=Invoke-ChatpadNativeAdapterOperation -Operation 'apply' -AdapterName 'CHATPAD-WINDOWS-EXACT-INSTANCE-ADAPTER-V1'
        $padded=Invoke-ChatpadNativeAdapterOperation -Operation ' Restore ' -AdapterName ' chatpad-windows-exact-instance-adapter-v1 '
        $missing=Invoke-ChatpadNativeAdapterOperation -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
        $unknown=Invoke-ChatpadNativeAdapterOperation -Operation InstallPackage -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
        [pscustomobject]@{checks=@(
            ($operations.Count-eq3),
            ($operations[0]-ceq'Apply'),
            ($operations[1]-ceq'Restore'),
            ($operations[2]-ceq'Restart'),
            (@($records|Where-Object{$_.result_code-ne$nativeOperationBlocker}).Count-eq0),
            (@($records|Where-Object{$_.operation_known-ne$true}).Count-eq0),
            ($caseVariant.operation-ceq'Apply'),
            ($caseVariant.result_code-eq$nativeOperationBlocker),
            ($padded.operation-ceq'Restore'),
            ($padded.result_code-eq$nativeOperationBlocker),
            ($missing.result_code-eq'NATIVE_ADAPTER_OPERATION_REQUIRED'),
            ($unknown.result_code-eq'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'),
            ($unknown.operation_known-eq$false)
        );details=[pscustomobject]@{operations=$operations;records=$records;case_variant=$caseVariant;padded=$padded;missing=$missing;unknown=$unknown}}
    }))

    $results.Add((Invoke-ChatpadExactCase G73 'public native API exposes no default production or generic contract override' {
        $commands=@(Get-Command -Module ChatpadNativeAdapterDesignGate)
        $invoke=$commands|Where-Object{$_.Name-eq'Invoke-ChatpadNativeAdapterOperation'}|Select-Object -First 1
        $complete=$commands|Where-Object{$_.Name-eq'Test-ChatpadNativeDesignContractCompleteness'}|Select-Object -First 1
        $omitted=Invoke-ChatpadNativeAdapterOperation -Operation Apply
        $contractRejected=$false
        try{[void](Test-ChatpadNativeDesignContractCompleteness -Contract ([pscustomobject]@{result='PASS'}))}catch{$contractRejected=$_.Exception.GetType().FullName-match'ParameterBinding'}
        [pscustomobject]@{checks=@(
            ($null-ne$invoke),
            ($invoke.Parameters['AdapterName'].ParameterType-eq[object]),
            ($invoke.Parameters['Operation'].ParameterType-eq[object]),
            ($omitted.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),
            ($omitted.selected_adapter_identity-eq''),
            ($null-ne$complete),
            ($complete.Parameters.Keys -notcontains 'Contract'),
            ($contractRejected-eq$true)
        );details=[pscustomobject]@{invoke_parameters=@($invoke.Parameters.Keys);completeness_parameters=@($complete.Parameters.Keys);omitted=$omitted;contract_parameter_rejected=$contractRejected}}
    }))

    $results.Add((Invoke-ChatpadExactCase G74 'native module contains no trusted decision variables' {
        $module=Get-Module ChatpadNativeAdapterDesignGate
        $names=@($module.SessionState.InvokeCommand.InvokeScript('Get-Variable -Scope Script | Select-Object -ExpandProperty Name'))
        $trustedNames=@($names|Where-Object{$_-match'ProductionNativeAdapterId|SyntheticAdapterId|SupportedNativeOperations|NativeExecutionBlocker|LiveAdapterBlocker|ScaffoldAuditGate|NativeDesignSchema|NativeAdapterContractSchema|NativeCompositionSchema|NativeOperationEvidenceSchema|AdapterKind|NativeInteropImplemented|SyntheticMode|ExecutionPerformed|NativeOperationsPerformed|LiveDeviceQueriesPerformed|WindowsMutationsPerformed'})
        $contract=Get-ChatpadNativeAdapterDesignContract
        [pscustomobject]@{checks=@(
            ($trustedNames.Count-eq0),
            ($contract.module_state_introspectable_by_same_process_callers-eq$true),
            ($contract.composition_root.mutable_module_state_trusted-eq$false),
            ($contract.composition_root.code_integrity_prerequisite-eq$true)
        );details=[pscustomobject]@{trusted_names=$trustedNames;module_variable_count=$names.Count;composition_root=$contract.composition_root}}
    }))

    $results.Add((Invoke-ChatpadExactCase G75 'accepted scaffold remains blocked pending native execution implementation' {
        $adapter=New-ChatpadProductionNativeAdapter
        $operation=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'
        [pscustomobject]@{checks=@(
            ($adapter.current_gate-eq$scaffoldAuditGate),
            ($adapter.native_execution_status-eq'NOT_IMPLEMENTED'),
            ($adapter.native_interop_implemented-eq$false),
            ($operation.current_gate-eq$scaffoldAuditGate),
            ($operation.capability_blocker-eq$nativeOperationBlocker),
            ($operation.execution_attempted-eq$false),
            ($operation.native_operations_performed-eq0),
            ($operation.live_device_queries_performed-eq0),
            ($operation.windows_mutations_performed-eq0)
        );details=[pscustomobject]@{adapter=$adapter;operation=$operation}}
    }))

    $results.Add((Invoke-ChatpadExactCase G76 'integrity remediation fixtures have unique identifiers and assertions' {
        $new=@($results|Where-Object{$_.fixture_id-match'^G(6[8-9]|7[0-5])$'})
        $ids=@($new|ForEach-Object fixture_id)
        [pscustomobject]@{checks=@(
            ($new.Count-eq8),
            (@($new|Where-Object{$_.assertion_count-le0}).Count-eq0),
            ($ids.Count-eq@($ids|Select-Object -Unique).Count),
            (@($new|Where-Object{$_.fixture_result-ne'PASS'}).Count-eq0)
        );details=[pscustomobject]@{ids=$ids;assertion_sum=[int](($new|Measure-Object assertion_count -Sum).Sum)}}
    }))

    $results.Add((Invoke-ChatpadExactCase G77 'integrity remediation authoritative counters remain zero' {
        $records=@(
            (Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'),
            (Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1'),
            (Invoke-ChatpadNativeAdapterOperation -Operation Restart -AdapterName 'chatpad-windows-exact-instance-adapter-v1'),
            (Invoke-ChatpadNativeAdapterOperation -Operation InstallPackage -AdapterName 'chatpad-windows-exact-instance-adapter-v1'),
            (Invoke-ChatpadNativeAdapterOperation -Operation Apply)
        )
        [pscustomobject]@{checks=@(
            ([int](($records|Measure-Object native_operations_performed -Sum).Sum)-eq0),
            ([int](($records|Measure-Object live_device_queries_performed -Sum).Sum)-eq0),
            ([int](($records|Measure-Object windows_mutations_performed -Sum).Sum)-eq0),
            (@($records|Where-Object{$_.execution_attempted-ne$false}).Count-eq0),
            (@($records|Where-Object{$_.result-ne'BLOCKED'}).Count-eq0)
        );details=[pscustomobject]@{records=$records}}
    }))

    $nativeInteropCases = @(
        @{ id='G78'; title='native interop declaration source boundary validates'; body={ $b=Test-ChatpadNativeInteropSourceBoundary; [pscustomobject]@{checks=@(($b.result-eq'PASS'),($b.result_code-eq'NATIVE_INTEROP_SOURCE_BOUNDARY_VALID'),($b.declared_api_count-eq13),($b.declared_structure_count-eq6),($b.native_interop_binary_count-eq0));details=$b} } },
        @{ id='G79'; title='native interop declaration inventory is exact and minimal'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; [pscustomobject]@{checks=@(($i.api_count-eq13),($i.mutating_api_count-eq2),($i.read_only_api_count-eq11),($i.allowed_dlls.Count-eq2),($i.allowed_dlls-contains'setupapi.dll'),($i.allowed_dlls-contains'newdev.dll'));details=$i} } },
        @{ id='G80'; title='native interop declaration inventory excludes Configuration Manager'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); [pscustomobject]@{checks=@(($i.prohibited_native_dlls-contains'cfgmgr32.dll'),($text-notmatch'cfgmgr32'),($text-notmatch'CM_[A-Za-z0-9_]+'),(@($i.apis|Where-Object dll -eq 'cfgmgr32.dll').Count-eq0));details=[pscustomobject]@{inventory=$i;text_length=$text.Length}} } },
        @{ id='G81'; title='native interop SetupAPI entry points are declared with W suffix where required'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $names=@($i.apis|ForEach-Object entry_point); [pscustomobject]@{checks=@(($names-contains'SetupDiOpenDeviceInfoW'),($names-contains'SetupDiGetDeviceInstanceIdW'),($names-contains'SetupDiGetDevicePropertyW'),($names-contains'SetupDiGetDeviceRegistryPropertyW'),($names-contains'SetupDiEnumDriverInfoW'),($names-contains'SetupDiGetDriverInfoDetailW'),($names-contains'SetupDiGetDriverInstallParamsW'),($names-contains'SetupDiSetSelectedDriverW'));details=[pscustomobject]@{entry_points=$names}} } },
        @{ id='G82'; title='native interop mutating declarations are only selected-driver and DiInstallDevice'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $mutating=@($i.apis|Where-Object mutating); [pscustomobject]@{checks=@(($mutating.Count-eq2),($mutating[0].entry_point-eq'SetupDiSetSelectedDriverW'),($mutating[1].entry_point-eq'DiInstallDevice'),(@($mutating|Where-Object read_only).Count-eq0));details=$mutating} } },
        @{ id='G83'; title='native interop handle and structure declarations are represented'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $names=@($i.structures|ForEach-Object name); [pscustomobject]@{checks=@(($names-contains'ChatpadDeviceInfoSetHandleToken'),($names-contains'SP_DEVINFO_DATA'),($names-contains'SP_DEVINSTALL_PARAMS_W'),($names-contains'SP_DRVINFO_DATA_W'),($names-contains'SP_DRVINFO_DETAIL_DATA_W'),($names-contains'DEVPROPKEY'),(@($i.structures|Where-Object cb_size_required).Count-eq4));details=$i.structures} } },
        @{ id='G84'; title='native interop constants include driver-list and buffer sentinels'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; [pscustomobject]@{checks=@(($i.constants-contains'SPDIT_COMPATDRIVER'),($i.constants-contains'DIGCF_PRESENT'),($i.constants-contains'ERROR_INSUFFICIENT_BUFFER'),($i.constants-contains'ERROR_NO_MORE_ITEMS'),($i.constants-contains'INVALID_HANDLE_VALUE'));details=$i.constants} } },
        @{ id='G85'; title='native interop declaration file hash is stable full sha256'; body={ $b=Test-ChatpadNativeInteropSourceBoundary; [pscustomobject]@{checks=@(($b.declaration_sha256-match'^[A-F0-9]{64}$'),($b.declaration_relative_path-eq'tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'),($b.dllimport_count-eq13));details=$b} } },
        @{ id='G86'; title='native interop declarations use DllImport only and no source-generated import'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); $dllImportCount=([regex]::Matches($text,'\[DllImport\s*\(')).Count; [pscustomobject]@{checks=@(($dllImportCount-eq13),($text-notmatch'\[LibraryImport\s*\('),($text-notmatch('DllImport'+'Attribute')),($text-notmatch'GeneratedDllImport'));details=[pscustomobject]@{dllimport_count=$dllImportCount}} } },
        @{ id='G87'; title='native interop declarations require SetLastError'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); $setLastErrorCount=([regex]::Matches($text,'SetLastError\s*=\s*true')).Count; [pscustomobject]@{checks=@(($setLastErrorCount-eq13),($text-match'NeedReboot'),($text-match'ERROR_INSUFFICIENT_BUFFER'));details=[pscustomobject]@{set_last_error_count=$setLastErrorCount}} } },
        @{ id='G88'; title='native interop declarations pin Unicode signatures only where string input exists'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); [pscustomobject]@{checks=@(($text-match'CharSet\s*=\s*CharSet\.Unicode'),($text-match'StringBuilder DeviceInstanceId'),($text-match'\[StructLayout\(LayoutKind\.Sequential, CharSet = CharSet\.Unicode\)\]'),($text-notmatch'CharSet\.Ansi'));details=[pscustomobject]@{path=$i.declaration_relative_path}} } },
        @{ id='G89'; title='native interop declarations do not include public callable surface'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); [pscustomobject]@{checks=@(($text-notmatch'\bpublic\s+'),($text-match'\binternal\s+static\s+extern\b'),($text-match'internal static class SetupApiNewdevDeclarations'),($text-notmatch'Main\s*\('));details=[pscustomobject]@{path=$i.declaration_relative_path}} } },
        @{ id='G90'; title='native interop source boundary reports no generated binaries'; body={ $b=Test-ChatpadNativeInteropSourceBoundary; [pscustomobject]@{checks=@(($b.native_interop_binary_count-eq0),(@($b.defects).Count-eq0),($b.build_reference_file_count-ge0));details=$b} } },
        @{ id='G91'; title='native source boundary guard allows only approved declaration matches'; body={ $g=Test-ChatpadNativeExecutableGuard; [pscustomobject]@{checks=@(($g.result-eq'PASS'),($g.result_code-eq'NATIVE_SOURCE_BOUNDARY_GUARD_VALID'),($g.match_count-eq0),($g.approved_declaration_match_count-ge1),($g.source_boundary.result-eq'PASS'));details=$g} } },
        @{ id='G92'; title='native source boundary contract records compile-only validation without execution'; body={ $c=Get-ChatpadNativeInteropSourceBoundaryContract; [pscustomobject]@{checks=@(($c.native_compilation_permitted-eq$false),($c.native_loading_permitted-eq$false),($c.native_invocation_permitted-eq$false),($c.windows_device_query_permitted-eq$false),($c.windows_mutation_permitted-eq$false),($c.source_audit_result-eq'AUDIT PASS'),($c.compile_only_validation_authorized-eq$true),($c.compile_only_validation_performed-eq$true),($c.native_compilation_performed-eq$true));details=$c} } },
        @{ id='G93'; title='native source declaration is not referenced by build files'; body={ $b=Test-ChatpadNativeInteropSourceBoundary; [pscustomobject]@{checks=@(($b.result-eq'PASS'),(@($b.defects|Where-Object id -eq 'declaration-referenced-by-build-file').Count-eq0));details=$b} } },
        @{ id='G94'; title='native source boundary remains outside production driver sources'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; [pscustomobject]@{checks=@(($i.declaration_relative_path-like'tools/ExactInstance/NativeInterop/*'),($i.declaration_relative_path-notlike'src/*'),($i.declaration_relative_path-notlike'legacy/*'),($i.declaration_relative_path-notlike'package/*'));details=$i} } },
        @{ id='G95'; title='native source boundary contains no Add-Type or runtime compiler path'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); [pscustomobject]@{checks=@(($text-notmatch('Add-'+'Type')),($text-notmatch'CSharpCodeProvider'),($text-notmatch'csc\.exe'),($text-notmatch'DotNetCompilerPlatform'));details=[pscustomobject]@{path=$i.declaration_relative_path}} } },
        @{ id='G96'; title='native source boundary contains no shell driver tools'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() $i.declaration_relative_path); [pscustomobject]@{checks=@(($text-notmatch'pnputil'),($text-notmatch'devcon'),($text-notmatch'dpinst'),($text-notmatch'dism'));details=[pscustomobject]@{path=$i.declaration_relative_path}} } },
        @{ id='G97'; title='native source boundary contains no PnP PowerShell mutation cmdlets'; body={ $g=Test-ChatpadNativeExecutableGuard; [pscustomobject]@{checks=@(($g.result-eq'PASS'),(@($g.matches|Where-Object pattern -match 'PnpDevice').Count-eq0));details=$g} } },
        @{ id='G98'; title='native source boundary contains no service mutation cmdlets'; body={ $g=Test-ChatpadNativeExecutableGuard; [pscustomobject]@{checks=@(($g.result-eq'PASS'),(@($g.matches|Where-Object pattern -match 'Service').Count-eq0));details=$g} } },
        @{ id='G99'; title='native source boundary is tracked source not ignored evidence'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $tracked=@(git ls-files $i.declaration_relative_path); [pscustomobject]@{checks=@(($tracked.Count-eq1),($tracked[0].Replace('\','/')-eq$i.declaration_relative_path),($i.declaration_relative_path-notlike'artifacts/*'));details=[pscustomobject]@{tracked=$tracked}} } },
        @{ id='G100'; title='native interop approved dll list has no broad install technologies'; body={ $i=Get-ChatpadNativeInteropDeclarationInventory; $dlls=@($i.allowed_dlls); [pscustomobject]@{checks=@(($dlls-contains'setupapi.dll'),($dlls-contains'newdev.dll'),($dlls-notcontains'difxapi.dll'),($dlls-notcontains'advpack.dll'),($dlls.Count-eq2));details=$dlls} } },
        @{ id='G101'; title='native apply call plan is planned only'; body={ $p=Get-ChatpadNativeInteropCallPlan -Operation Apply; [pscustomobject]@{checks=@(($p.operation-eq'Apply'),($p.execution_allowed-eq$false),($p.native_invocation_available-eq$false),(@($p.ordered_steps|Where-Object invoked_in_this_phase).Count-eq0),(@($p.ordered_steps|Where-Object entry_point -eq 'DiInstallDevice').Count-eq1));details=$p} } },
        @{ id='G102'; title='native restore call plan is planned only'; body={ $p=Get-ChatpadNativeInteropCallPlan -Operation Restore; [pscustomobject]@{checks=@(($p.operation-eq'Restore'),($p.execution_allowed-eq$false),($p.native_invocation_available-eq$false),(@($p.ordered_steps|Where-Object invoked_in_this_phase).Count-eq0),(@($p.ordered_steps|Where-Object entry_point -eq 'SetupDiSetSelectedDriverW').Count-eq1));details=$p} } },
        @{ id='G103'; title='native restart call plan has no current restart declaration'; body={ $p=Get-ChatpadNativeInteropCallPlan -Operation Restart; [pscustomobject]@{checks=@(($p.operation-eq'Restart'),($p.execution_allowed-eq$false),(@($p.ordered_steps|Where-Object entry_point -eq 'future-exact-device-restart-sequence').Count-eq1),(@($p.ordered_steps|Where-Object entry_point -eq 'DiInstallDevice').Count-eq0));details=$p} } },
        @{ id='G104'; title='production operation exposes call plan but remains blocked'; body={ $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'; [pscustomobject]@{checks=@(($r.result-eq'BLOCKED'),($r.result_code-eq$nativeOperationBlocker),($r.details.native_call_plan.operation-eq'Apply'),($r.details.native_call_plan.execution_allowed-eq$false),($r.execution_attempted-eq$false));details=$r} } },
        @{ id='G105'; title='production operation exposes source declarations without native implementation'; body={ $r=Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1'; [pscustomobject]@{checks=@(($r.native_source_declarations_present-eq$true),($r.native_declaration_api_count-eq13),($r.native_interop_implemented-eq$false),($r.native_compilation_permitted-eq$false),($r.native_invocation_permitted-eq$false));details=$r} } },
        @{ id='G106'; title='native operation counters remain zero with source boundary present'; body={ $records=@(('Apply','Restore','Restart')|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1'}); [pscustomobject]@{checks=@(([int](($records|Measure-Object native_operations_performed -Sum).Sum)-eq0),([int](($records|Measure-Object live_device_queries_performed -Sum).Sum)-eq0),([int](($records|Measure-Object windows_mutations_performed -Sum).Sum)-eq0),(@($records|Where-Object execution_attempted).Count-eq0));details=$records} } },
        @{ id='G107'; title='unsupported native operation gets no call plan'; body={ $r=Invoke-ChatpadNativeAdapterOperation -Operation InstallPackage -AdapterName 'chatpad-windows-exact-instance-adapter-v1'; [pscustomobject]@{checks=@(($r.result_code-eq'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'),($r.operation_known-eq$false),($null-eq$r.details.native_call_plan),($r.native_operations_performed-eq0));details=$r} } },
        @{ id='G108'; title='missing adapter selection gets no native call plan'; body={ $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply; [pscustomobject]@{checks=@(($r.result_code-eq'NATIVE_ADAPTER_SELECTION_REQUIRED'),($r.selected_adapter_identity-eq''),($r.execution_attempted-eq$false),($r.native_operations_performed-eq0));details=$r} } },
        @{ id='G109'; title='native mutation capability remains unavailable'; body={ $c=Test-ChatpadNativeMutationCapability; [pscustomobject]@{checks=@(($c.result-eq'BLOCKED'),($c.result_code-eq$nativeOperationBlocker),($c.capability_present-eq$false),($c.caller_supplied_capability_accepted-eq$false));details=$c} } },
        @{ id='G110'; title='production adapter advertises source boundary but no execution'; body={ $a=New-ChatpadProductionNativeAdapter; [pscustomobject]@{checks=@(($a.adapter_implementation_kind-eq'production-native-interop-source-boundary'),($a.native_source_declarations_present-eq$true),($a.native_declaration_api_count-eq13),($a.native_execution_status-eq'NOT_IMPLEMENTED'),($a.current_gate-eq$scaffoldAuditGate));details=$a} } },
        @{ id='G111'; title='native design contract includes source boundary'; body={ $c=Get-ChatpadNativeAdapterDesignContract; [pscustomobject]@{checks=@(($c.source_boundary.schema_version-eq'chatpad-native-interop-source-boundary-v1'),($c.source_boundary.current_gate-eq$scaffoldAuditGate),($c.source_boundary.declaration_inventory.api_count-eq13),($c.source_boundary.native_invocation_permitted-eq$false));details=$c.source_boundary} } },
        @{ id='G112'; title='native design completeness accepts source boundary only when nonexecuting'; body={ $c=Test-ChatpadNativeDesignContractCompleteness; [pscustomobject]@{checks=@(($c.result-eq'PASS'),($c.result_code-eq'NATIVE_DESIGN_CONTRACT_COMPLETE'),($c.production_scaffold_complete-eq$true),($c.required_call_count-eq12));details=$c} } },
        @{ id='G113'; title='caller supplied adapter object cannot enable native source boundary'; body={ $fake=[pscustomobject]@{native_invocation_permitted=$true;native_operations_performed=99}; $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -AdapterObject $fake -Evidence $fake; [pscustomobject]@{checks=@(($r.caller_object_trusted-eq$false),($r.evidence_trusted-eq$false),($r.native_invocation_permitted-eq$false),($r.native_operations_performed-eq0));details=$r} } },
        @{ id='G114'; title='caller supplied evidence cannot override source boundary status'; body={ $fake=[pscustomobject]@{native_source_boundary_status='LIVE';result='PASS'}; $r=Invoke-ChatpadNativeAdapterOperation -Operation Restore -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -Evidence $fake; [pscustomobject]@{checks=@(($r.native_source_boundary_status-eq'SOURCE_DECLARATIONS_PRESENT_NON_EXECUTING'),($r.result-eq'BLOCKED'),($r.evidence_trusted-eq$false),($r.windows_mutations_performed-eq0));details=$r} } },
        @{ id='G115'; title='native source boundary command surface exports only Chatpad functions'; body={ $cmds=@(Get-Command -Module ChatpadNativeAdapterDesignGate,ChatpadNativeInteropSourceBoundary); [pscustomobject]@{checks=@(($cmds.Name-contains'Get-ChatpadNativeInteropSourceBoundaryContract'),($cmds.Name-contains'Test-ChatpadNativeInteropSourceBoundary'),($cmds.Name-contains'Test-ChatpadNativeInteropCompileOnlyValidationEvidence'),(@($cmds|Where-Object Name -match 'Invoke.*Native.*Dll|Load').Count-eq0));details=[pscustomobject]@{commands=@($cmds|Select-Object -ExpandProperty Name)}} } },
        @{ id='G116'; title='native module state still has no trusted mutable decision variables'; body={ $module=Get-Module ChatpadNativeAdapterDesignGate; $names=@($module.SessionState.InvokeCommand.InvokeScript('Get-Variable -Scope Script | Select-Object -ExpandProperty Name')); $trusted=@($names|Where-Object{$_-match'NativeInteropImplemented|NativeInvocationPermitted|WindowsMutationPermitted|ProductionNativeAdapterId'}); $contract=Get-ChatpadNativeAdapterDesignContract; [pscustomobject]@{checks=@(($trusted.Count-eq0),($contract.composition_root.mutable_module_state_trusted-eq$false));details=[pscustomobject]@{trusted=$trusted;count=$names.Count}} } },
        @{ id='G117'; title='source boundary contract is regenerated not mutable shared state'; body={ $a=Get-ChatpadNativeInteropSourceBoundaryContract; $a.current_gate='PASS'; $b=Get-ChatpadNativeInteropSourceBoundaryContract; [pscustomobject]@{checks=@(($b.current_gate-eq$scaffoldAuditGate),($b.native_invocation_permitted-eq$false),($b.declaration_inventory.api_count-eq13));details=[pscustomobject]@{first=$a;second=$b}} } },
        @{ id='G118'; title='native interop plans include cleanup obligations'; body={ $plans=@(('Apply','Restore','Restart')|ForEach-Object{Get-ChatpadNativeInteropCallPlan -Operation $_}); [pscustomobject]@{checks=@((@($plans[0].ordered_steps|Where-Object entry_point -eq 'SetupDiDestroyDriverInfoList').Count-eq1),(@($plans[0].ordered_steps|Where-Object entry_point -eq 'SetupDiDestroyDeviceInfoList').Count-eq1),(@($plans[2].ordered_steps|Where-Object entry_point -eq 'SetupDiDestroyDeviceInfoList').Count-eq1));details=$plans} } },
        @{ id='G119'; title='native interop plans preserve exact instance opening order'; body={ $p=Get-ChatpadNativeInteropCallPlan -Operation Apply; $steps=@($p.ordered_steps|ForEach-Object entry_point); [pscustomobject]@{checks=@(($steps[0]-eq'SetupDiCreateDeviceInfoList'),($steps[1]-eq'SetupDiOpenDeviceInfoW'),($steps[2]-eq'SetupDiGetDeviceInstanceIdW'),($steps.IndexOf('SetupDiSetSelectedDriverW')-gt$steps.IndexOf('SetupDiGetDriverInstallParamsW')));details=$steps} } },
        @{ id='G120'; title='native interop source boundary keeps live capability absent'; body={ $gate=Test-ChatpadNativeAdapterOperationGate -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1' -IsElevated $true -AllowWindowsMutation $true; [pscustomobject]@{checks=@(($gate.live_capability_present-eq$false),($gate.live_binding_authorized-eq$false),($gate.operation_evidence.native_invocation_permitted-eq$false),($gate.windows_mutations_performed-eq0));details=$gate} } },
        @{ id='G121'; title='native error mapping covers all design errors'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $codes=@($m|ForEach-Object code); [pscustomobject]@{checks=@(($codes.Count-eq25),($codes-contains'EXACT_INSTANCE_NOT_FOUND'),($codes-contains'BIND_FAILURE_AFTER_POSSIBLE_MUTATION'),($codes-contains'UNCERTAIN_DEVICE_STATE'),(@($m|Where-Object retry_prohibited -ne $true).Count-eq0));details=$m} } },
        @{ id='G122'; title='native error mapping separates before-mutation bind failure'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $before=@($m|Where-Object code -eq 'BIND_API_FAILURE_BEFORE_POSSIBLE_MUTATION')[0]; [pscustomobject]@{checks=@(($before.mutation_may_have_occurred-eq$false),($before.manual_recovery_required-eq$false),($before.controlled_failure-eq$true));details=$before} } },
        @{ id='G123'; title='native error mapping flags after-mutation bind uncertainty'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $after=@($m|Where-Object code -eq 'BIND_FAILURE_AFTER_POSSIBLE_MUTATION')[0]; [pscustomobject]@{checks=@(($after.mutation_may_have_occurred-eq$true),($after.manual_recovery_required-eq$true),($after.retry_prohibited-eq$true));details=$after} } },
        @{ id='G124'; title='native error mapping flags post-bind verification recovery'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $row=@($m|Where-Object code -eq 'POST_BIND_VERIFICATION_FAILURE')[0]; [pscustomobject]@{checks=@(($row.mutation_may_have_occurred-eq$true),($row.manual_recovery_required-eq$true),($row.win32_last_error_captured_before_cleanup-eq$true));details=$row} } },
        @{ id='G125'; title='native error mapping flags restore failures as manual recovery'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $rows=@($m|Where-Object code -in @('RESTORE_API_FAILURE','POST_RESTORE_VERIFICATION_FAILURE')); [pscustomobject]@{checks=@(($rows.Count-eq2),(@($rows|Where-Object manual_recovery_required -ne $true).Count-eq0),(@($rows|Where-Object retry_prohibited -ne $true).Count-eq0));details=$rows} } },
        @{ id='G126'; title='native error mapping distinguishes restart and reboot pending'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $restart=@($m|Where-Object restart_pending); $reboot=@($m|Where-Object reboot_pending); [pscustomobject]@{checks=@(($restart.Count-eq1),($restart[0].code-eq'RESTART_REQUIRED'),($reboot.Count-eq1),($reboot[0].code-eq'REBOOT_REQUIRED'));details=[pscustomobject]@{restart=$restart;reboot=$reboot}} } },
        @{ id='G127'; title='native error mapping records cleanup uncertainty'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $cleanup=@($m|Where-Object code -eq 'CLEANUP_FAILURE')[0]; [pscustomobject]@{checks=@(($cleanup.phase-eq'cleanup'),($cleanup.manual_recovery_required-eq$true),($cleanup.mutation_may_have_occurred-eq$true));details=$cleanup} } },
        @{ id='G128'; title='native error mapping records unexpected exception as controlled failure'; body={ $m=Get-ChatpadNativeInteropErrorMapping; $row=@($m|Where-Object code -eq 'UNEXPECTED_NATIVE_EXCEPTION')[0]; [pscustomobject]@{checks=@(($row.controlled_failure-eq$true),($row.manual_recovery_required-eq$true),($row.retry_prohibited-eq$true));details=$row} } },
        @{ id='G129'; title='native interop source boundary has stable fixture group cardinality'; body={ $new=@($results|Where-Object{$_.fixture_id-match'^G(7[8-9]|8[0-9]|9[0-9]|10[0-9]|11[0-9]|12[0-9]|13[0-2])$'}); [pscustomobject]@{checks=@(($new.Count-eq51),(@($new|Where-Object fixture_result -ne 'PASS').Count-eq0),(@($new|Where-Object assertion_count -le 0).Count-eq0));details=[pscustomobject]@{ids=@($new|ForEach-Object fixture_id);count=$new.Count}} } },
        @{ id='G130'; title='native interop source boundary accounting remains zero live operations'; body={ $ops=@(('Apply','Restore','Restart')|ForEach-Object{Invoke-ChatpadNativeAdapterOperation -Operation $_ -AdapterName 'chatpad-windows-exact-instance-adapter-v1'}); [pscustomobject]@{checks=@(([int](($ops|Measure-Object native_operations_performed -Sum).Sum)-eq0),([int](($ops|Measure-Object live_device_queries_performed -Sum).Sum)-eq0),([int](($ops|Measure-Object windows_mutations_performed -Sum).Sum)-eq0));details=$ops} } },
        @{ id='G131'; title='native interop source audit acceptance is recorded'; body={ $a=New-ChatpadProductionNativeAdapter; $c=Get-ChatpadNativeAdapterDesignContract; $r=Invoke-ChatpadNativeAdapterOperation -Operation Apply -AdapterName 'chatpad-windows-exact-instance-adapter-v1'; [pscustomobject]@{checks=@(($a.current_gate-eq$scaffoldAuditGate),($c.current_gate-eq$scaffoldAuditGate),($r.current_gate-eq$scaffoldAuditGate),($r.capability_blocker-eq$nativeOperationBlocker),($a.source_audit_result-eq'AUDIT PASS'),($c.source_audit.verdict-eq'AUDIT PASS'),($r.source_audit_result-eq'AUDIT PASS'));details=[pscustomobject]@{adapter=$a;contract=$c.current_gate;operation=$r.current_gate;source_audit=$c.source_audit}} } },
        @{ id='G132'; title='native interop continuation blocker is adapter execution not implemented'; body={ $c=Get-ChatpadNativeInteropSourceBoundaryContract; [pscustomobject]@{checks=@(($c.current_gate-eq$scaffoldAuditGate),($c.capability_blocker-eq$nativeOperationBlocker),($c.native_source_declarations_present-eq$true),($c.native_invocation_permitted-eq$false),($c.compile_only_validation_authorized-eq$true),($c.native_compilation_performed-eq$true),($c.native_loading_performed-eq$false),($c.native_invocation_performed-eq$false));details=$c} } }
    )
    foreach($case in $nativeInteropCases){
        $results.Add((Invoke-ChatpadExactCase $case.id $case.title $case.body))
    }

    $compileEvidenceMutation = {
        param([scriptblock]$Mutate)
        $repoRoot=(git rev-parse --show-toplevel).Trim()
        $source = Join-Path $repoRoot 'docs/evidence/native-interop-compile-only-validation.json'
        $tempRoot = Join-Path $repoRoot ('artifacts\temp\chatpad-native-compile-evidence-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($tempRoot) | Out-Null
        $copy = Join-Path $tempRoot 'evidence.json'
        try {
            $json = Get-Content -LiteralPath $source -Raw | ConvertFrom-Json
            & $Mutate $json
            [IO.File]::WriteAllText($copy, ($json | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
            Test-ChatpadNativeInteropCompileOnlyValidationEvidence -EvidencePath $copy
        } finally {
            if (Test-Path -LiteralPath $tempRoot) {
                Remove-Item -LiteralPath $tempRoot -Recurse -Force
            }
        }
    }

    $compileOnlyCases = @(
        @{ id='G133'; title='compile-only harness references approved source inputs'; body={ $p=Join-Path (git rev-parse --show-toplevel).Trim() 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj'; $text=Get-Content -LiteralPath $p -Raw; [pscustomobject]@{checks=@(($text-match'\.\.\\NativeInterop\\Chatpad\.NativeInterop\.SetupApiNewdev\.Declarations\.cs'),($text-match'CompileOnlyContracts\.cs'),($text-notmatch'\[DllImport'),($text-notmatch'Microsoft\.NET\.Test\.Sdk'));details=[pscustomobject]@{project=$p}} } },
        @{ id='G134'; title='compile-only harness does not copy declarations'; body={ $root=(git rev-parse --show-toplevel).Trim(); $contract=Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs') -Raw; [pscustomobject]@{checks=@(($contract-notmatch'\[DllImport'),($contract-notmatch'\bextern\b'),($contract-notmatch'struct\s+SP_DEVINFO_DATA'),($contract-match'BindNativeSignaturesForCompilerOnly'));details=[pscustomobject]@{contract_length=$contract.Length}} } },
        @{ id='G135'; title='compile-only harness has no executable entry point'; body={ $root=(git rev-parse --show-toplevel).Trim(); $project=Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj') -Raw; $contract=Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs') -Raw; [pscustomobject]@{checks=@(($project-match'<OutputType>Library</OutputType>'),($project-match'<GenerateProgramFile>false</GenerateProgramFile>'),($project-match'<IsTestProject>false</IsTestProject>'),($contract-notmatch'\bstatic\s+void\s+Main\s*\('));details=[pscustomobject]@{project='library'}} } },
        @{ id='G136'; title='compile-only harness has no post-build or test target'; body={ $root=(git rev-parse --show-toplevel).Trim(); $project=Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj') -Raw; [pscustomobject]@{checks=@(($project-notmatch'<Exec\b'),($project-notmatch'PostBuildEvent'),($project-notmatch'VSTest'),($project-notmatch'Microsoft\.NET\.Test\.Sdk'),($project-notmatch'<Target\b'));details=[pscustomobject]@{project_length=$project.Length}} } },
        @{ id='G137'; title='compile-only harness has no production runtime orchestration'; body={ $root=(git rev-parse --show-toplevel).Trim(); $text=((Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj') -Raw) + (Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs') -Raw)); [pscustomobject]@{checks=@(($text-notmatch'Invoke-ChatpadNativeAdapterOperation'),($text-notmatch'Resolve-ChatpadNativeAdapter'),($text-notmatch'ExactInstance\.Orchestrator'),($text-notmatch'FakeAdapter'));details=[pscustomobject]@{text_length=$text.Length}} } },
        @{ id='G138'; title='compile-only harness contains no device or shell tooling'; body={ $root=(git rev-parse --show-toplevel).Trim(); $text=((Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj') -Raw) + (Get-Content -LiteralPath (Join-Path $root 'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs') -Raw)); [pscustomobject]@{checks=@(($text-notmatch'pnputil'),($text-notmatch'devcon'),($text-notmatch'Add-Type'),($text-notmatch'Assembly\.Load'),($text-notmatch'\bdotnet\s+(test|run)\b'));details=[pscustomobject]@{text_length=$text.Length}} } },
        @{ id='G139'; title='compile-only evidence validates cleanly'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; [pscustomobject]@{checks=@(($v.result-eq'PASS'),($v.result_code-eq'NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_VALID'),($v.defect_count-eq0),($v.evidence.build_result.warning_count-eq0),($v.evidence.build_result.error_count-eq0));details=$v} } },
        @{ id='G140'; title='compile-only evidence input hashes match tracked files'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $inputs=@($v.evidence.input_files); [pscustomobject]@{checks=@(($inputs.Count-eq5),(@($inputs|Where-Object relative_path -eq 'tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs').Count-eq1),(@($inputs|Where-Object relative_path -eq 'tools/ExactInstance/CompileOnlyValidation/Directory.Build.props').Count-eq1),(@($inputs|Where-Object sha256 -eq '127EA58993862CCE865E3D73B0F1A99513932ABDF1BEA615812966EB5C14BEAA').Count-eq1));details=$inputs} } },
        @{ id='G141'; title='compile-only evidence output hashes match isolated artifacts'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $outputs=@($v.evidence.build_result.produced_files); [pscustomobject]@{checks=@(($outputs.Count-ge1),(@($outputs|Where-Object relative_path -like 'artifacts/compile-only/native-interop/*').Count-eq$outputs.Count),(@($outputs|Where-Object sha256 -notmatch '^[A-F0-9]{64}$').Count-eq0));details=[pscustomobject]@{count=$outputs.Count;outputs=$outputs}} } },
        @{ id='G142'; title='compile-only gate transitions only on successful compile'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; [pscustomobject]@{checks=@(($v.evidence.build_result.result-eq'PASS'),($v.evidence.readiness_transition.previous_gate-eq$historicalCompileOnlyGate),($v.evidence.readiness_transition.resulting_readiness_gate-eq$compileEvidenceAuditGate),($v.evidence.readiness_transition.transition_allowed-eq$true));details=$v.evidence.readiness_transition} } },
        @{ id='G143'; title='failed compile evidence does not validate as transitioned'; body={ $v=& $compileEvidenceMutation { param($x) $x.build_result.result='FAIL'; $x.build_result.compiler_exit_code=1; $x.readiness_transition.resulting_readiness_gate='BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED'; $x.readiness_transition.transition_allowed=$false }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -eq 'compile-result-not-clean-pass').Count-eq1));details=$v.defects} } },
        @{ id='G144'; title='compile-only remaining blocker is exact'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; [pscustomobject]@{checks=@(($v.evidence.readiness_transition.remaining_blocker-eq$nativeOperationBlocker),($v.evidence.readiness_transition.resulting_readiness_gate-eq$compileEvidenceAuditGate),($v.evidence.prohibited_actions.nativeInvocationOccurred-eq$false));details=$v.evidence.readiness_transition} } },
        @{ id='G145'; title='historical source audit remains read-only and separately classified'; body={ $c=Get-ChatpadNativeAdapterDesignContract; [pscustomobject]@{checks=@(($c.source_audit.native_compilation_occurred-eq$false),($c.source_audit.native_invocation_occurred-eq$false),($c.source_audit.device_query_occurred-eq$false),($c.source_audit.windows_mutation_occurred-eq$false),($c.production_adapter.compile_only_validation_performed-eq$true));details=[pscustomobject]@{source_audit=$c.source_audit;compile=$c.production_adapter.compile_only_validation}} } },
        @{ id='G146'; title='audited native source hashes remain unchanged after compile'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; [pscustomobject]@{checks=@(($v.evidence.expected_native_source_hashes.matched_before_compile-eq$true),($v.evidence.expected_native_source_hashes.matched_after_compile-eq$true),($v.evidence.expected_native_source_hashes.declaration_sha256-eq'127EA58993862CCE865E3D73B0F1A99513932ABDF1BEA615812966EB5C14BEAA'),($v.evidence.expected_native_source_hashes.source_boundary_record_sha256-eq'3E7E3119A467330A413280658503B294C0FFB38271A9CA847056BAF6B2E778D3'));details=$v.evidence.expected_native_source_hashes} } },
        @{ id='G147'; title='compile-only readiness keeps mutation and execution counters zero'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $p=$v.evidence.prohibited_actions; [pscustomobject]@{checks=@(($p.assemblyLoaded-eq$false),($p.managedCodeExecuted-eq$false),($p.nativeInvocationOccurred-eq$false),($p.deviceQueryOccurred-eq$false),($p.exactInstanceAccessed-eq$false),($p.windowsMutationOccurred-eq$false));details=$p} } },
        @{ id='G148'; title='missing compile input evidence is rejected'; body={ $v=& $compileEvidenceMutation { param($x) $x.input_files=@($x.input_files|Where-Object relative_path -ne 'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs') }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -match 'input-file').Count-ge1));details=$v.defects} } },
        @{ id='G149'; title='extra compile input evidence is rejected'; body={ $v=& $compileEvidenceMutation { param($x) $x.input_files+=([pscustomobject]@{role='input';relative_path='docs/PROJECT-STATE.md';byte_size=1;sha256=('A'*64)}) }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -eq 'input-file-set-invalid').Count-eq1));details=$v.defects} } },
        @{ id='G150'; title='duplicate compile input evidence is rejected'; body={ $v=& $compileEvidenceMutation { param($x) $x.input_files+=($x.input_files[0]) }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -eq 'input-file-set-invalid').Count-eq1));details=$v.defects} } },
        @{ id='G151'; title='compile-only toolchain identity is mandatory'; body={ $v=& $compileEvidenceMutation { param($x) $x.toolchain.PSObject.Properties.Remove('roslyn_version') }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -eq 'toolchain-identity-incomplete').Count-eq1));details=$v.defects} } },
        @{ id='G152'; title='compile-only execution and loading claims are mandatory'; body={ $v=& $compileEvidenceMutation { param($x) $x.prohibited_actions.PSObject.Properties.Remove('assemblyLoaded') }; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object id -eq 'prohibited-action-claim-invalid').Count-eq1));details=$v.defects} } },
        @{ id='G153'; title='compile-only evidence declares portable identity policy'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $p=$v.evidence.identity_policy; [pscustomobject]@{checks=@(($v.evidence.schema_version-eq'chatpad-native-interop-compile-only-validation-v2'),($p.tracked_text_input_policy-eq'canonical_lf_text'),($p.compile_output_policy-eq'raw_file_bytes'),(@($p.supported_hash_policies)-contains'git_blob_bytes'));details=$p} } },
        @{ id='G154'; title='all compile inputs use canonical LF text identity'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $i=@($v.evidence.input_files); [pscustomobject]@{checks=@(($i.Count-eq5),(@($i|Where-Object{$_.hash_policy-ne'canonical_lf_text'}).Count-eq0),(@($i|Where-Object{$_.content_classification-ne'text'}).Count-eq0),(@($i|Where-Object{$_.line_ending_policy-ne'utf8_no_bom_lf'}).Count-eq0),(@($i|Where-Object{$_.canonical_sha256-notmatch'^[A-F0-9]{64}$'}).Count-eq0));details=$i} } },
        @{ id='G155'; title='CRLF working tree validates against canonical LF identities'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $i=@($v.evidence.input_files); [pscustomobject]@{checks=@(($v.result-eq'PASS'),(@($i|Where-Object raw_and_canonical_differ).Count-ge5),(@($i|Where-Object{$_.raw_working_tree_sha256-ceq$_.canonical_sha256}).Count-eq0));details=[pscustomobject]@{differing_count=@($i|Where-Object raw_and_canonical_differ).Count}} } },
        @{ id='G156'; title='raw working tree identity is informational for canonical input policy'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].raw_working_tree_sha256=('A'*64);$x.input_files[0].raw_working_tree_byte_size=1;$x.input_files[0].raw_and_canonical_differ=$true}; [pscustomobject]@{checks=@(($v.result-eq'PASS'),($v.defect_count-eq0));details=$v.defects} } },
        @{ id='G157'; title='missing input hash policy is rejected'; body={ $v=&$compileEvidenceMutation{param($x)[void]$x.input_files[0].PSObject.Properties.Remove('hash_policy')}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-hash-policy-invalid'}).Count-eq1));details=$v.defects} } },
        @{ id='G158'; title='unknown input hash policy is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].hash_policy='unknown_policy'}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-hash-policy-invalid'}).Count-eq1));details=$v.defects} } },
        @{ id='G159'; title='canonical input hash mismatch is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].canonical_sha256=('0'*64);$x.input_files[0].sha256=('0'*64)}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-canonical-identity-mismatch'}).Count-eq1));details=$v.defects} } },
        @{ id='G160'; title='canonical input size mismatch is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].canonical_byte_size=[long]$x.input_files[0].canonical_byte_size+1;$x.input_files[0].byte_size=[long]$x.input_files[0].byte_size+1}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-canonical-identity-mismatch'}).Count-eq1));details=$v.defects} } },
        @{ id='G161'; title='raw policy on tracked text input is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].hash_policy='raw_file_bytes'}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-hash-policy-invalid'}).Count-eq1));details=$v.defects} } },
        @{ id='G162'; title='compile outputs retain raw file byte identity'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $o=@($v.evidence.build_result.produced_files); [pscustomobject]@{checks=@(($o.Count-ge1),(@($o|Where-Object{$_.hash_policy-ne'raw_file_bytes'}).Count-eq0),(@($o|Where-Object{$_.sha256-cne$_.raw_file_sha256-or$_.byte_size-ne$_.raw_file_byte_size}).Count-eq0));details=[pscustomobject]@{count=$o.Count}} } },
        @{ id='G163'; title='canonical text policy on compile output is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.build_result.produced_files[0].hash_policy='canonical_lf_text'}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'produced-file-policy-invalid'}).Count-eq1));details=$v.defects} } },
        @{ id='G164'; title='compile output loading claim is rejected'; body={ $v=&$compileEvidenceMutation{param($x)$x.build_result.produced_files[0].assembly_loaded=$true}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'produced-file-prohibited-action-invalid'}).Count-eq1));details=$v.defects} } },
        @{ id='G165'; title='compile runner exposes explicit audit output and no-action switches'; body={ $cmd=Get-Command (Join-Path (git rev-parse --show-toplevel).Trim() 'tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1'); [pscustomobject]@{checks=@(($cmd.Parameters.Keys-contains'OutputRoot'),($cmd.Parameters.Keys-contains'NoLoad'),($cmd.Parameters.Keys-contains'NoReflection'),($cmd.Parameters.Keys-contains'NoInvoke'));details=$cmd.Parameters.Keys} } },
        @{ id='G166'; title='compile runner audit root is artifacts-contained and ignored'; body={ $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() 'tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1'); [pscustomobject]@{checks=@(($text-match'OutputRoot must remain under the repository artifacts directory'),($text-match'OutputRoot must be ignored by Git'),($text-match'Explicit audit OutputRoot must differ'));details=[pscustomobject]@{length=$text.Length}} } },
        @{ id='G167'; title='compile runner audit mode requires all no-action switches'; body={ $text=Get-Content -Raw (Join-Path (git rev-parse --show-toplevel).Trim() 'tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1'); [pscustomobject]@{checks=@(($text-match'Audit output mode requires -NoLoad, -NoReflection, and -NoInvoke'),($text-notmatch'Assembly\\.LoadFrom|Assembly\\.LoadFile|NativeLibrary\\.Load'));details=[pscustomobject]@{length=$text.Length}} } },
        @{ id='G168'; title='accepted compile-only evidence preserves historical transition'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; [pscustomobject]@{checks=@(($v.evidence.readiness_transition.resulting_readiness_gate-eq$compileEvidenceAuditGate),($v.evidence.readiness_transition.remaining_blocker-eq$nativeOperationBlocker));details=$v.evidence.readiness_transition} } },
        @{ id='G169'; title='canonical aliases cannot silently claim raw identity'; body={ $v=&$compileEvidenceMutation{param($x)$x.input_files[0].sha256=$x.input_files[0].raw_working_tree_sha256}; [pscustomobject]@{checks=@(($v.result-eq'FAIL'),(@($v.defects|Where-Object{$_.id-eq'input-file-identity-alias-mismatch'}).Count-eq1));details=$v.defects} } },
        @{ id='G170'; title='compile input identity binds represented commit'; body={ $v=Test-ChatpadNativeInteropCompileOnlyValidationEvidence; $i=@($v.evidence.input_files); $commit=$v.evidence.repository.repository_commit_at_validation; [pscustomobject]@{checks=@(($i.Count-eq5),(@($i|Where-Object{$_.commit_represented-ne$commit}).Count-eq0));details=[pscustomobject]@{commit=$commit}} } }
    )
    foreach($case in $compileOnlyCases){
        $results.Add((Invoke-ChatpadExactCase $case.id $case.title $case.body))
    }

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
        current_gate='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        capability_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        live_adapter_status='SCAFFOLD_NON_EXECUTING'
        live_binding_authorized=$false
    }
}

Export-ModuleMember -Function *-Chatpad*
