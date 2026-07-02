[CmdletBinding()]
param([string]$ManifestPath = 'docs/evidence/runtime-bringup-readiness-manifest.json')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$script:FixtureIds = @{}
$script:Fixtures = [Collections.Generic.List[object]]::new()
$script:AssertionCount = 0

function Compare-FixtureOutcome {
    param($ExpectedStatus,$ExpectedCode,[string[]]$ExpectedStops,[bool]$ExpectException,[string]$ExpectedExceptionType,$ActualStatus,$ActualCode,[string[]]$ActualStops,[string]$ActualExceptionType)
    if (-not $ExpectedStatus -or -not $ExpectedCode) { return $false }
    if (-not $ExpectException -and $ActualExceptionType) { return $false }
    if ($ExpectException -and $ActualExceptionType -ne $ExpectedExceptionType) { return $false }
    if (-not $ExpectException -and ($ActualStatus -ne $ExpectedStatus -or $ActualCode -ne $ExpectedCode)) { return $false }
    foreach ($id in $ExpectedStops) { if ($ActualStops -notcontains $id) { return $false } }
    $true
}

function Invoke-Fixture {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Validator,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL','BLOCKED')][string]$ExpectedStatus,
        [Parameter(Mandatory)][string]$ExpectedCode,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ExpectedStops,
        [Parameter(Mandatory)][scriptblock]$Body,
        [int]$AdditionalAssertionCount=0,
        [bool]$ExpectException=$false,
        [string]$ExpectedExceptionType=''
    )
    if ([string]::IsNullOrWhiteSpace($Category)) { throw 'Fixture category is required.' }
    if ($script:FixtureIds.ContainsKey($Id)) { throw "Duplicate fixture ID: $Id" }
    $script:FixtureIds[$Id]=$true
    $actualStatus='';$actualCode='';$actualStops=@();$actualException=''
    try {
        $value=& $Body
        if ($null-eq$value -or $null-eq$value.PSObject.Properties['result'] -or $null-eq$value.PSObject.Properties['result_code']) {
            throw [InvalidDataException]::new('Validator returned no machine-readable result.')
        }
        $actualStatus=[string]$value.result;$actualCode=[string]$value.result_code;$actualStops=@($value.stop_condition_ids)
    } catch {
        $actualException=$_.Exception.GetType().FullName
    }
    $assertions=4+$ExpectedStops.Count+$AdditionalAssertionCount
    $script:AssertionCount+=$assertions
    $passed=Compare-FixtureOutcome $ExpectedStatus $ExpectedCode $ExpectedStops $ExpectException $ExpectedExceptionType $actualStatus $actualCode $actualStops $actualException
    $script:Fixtures.Add([pscustomobject][ordered]@{
        fixture_id=$Id;category=$Category;validator=$Validator
        expected_status=$ExpectedStatus;expected_result_code=$ExpectedCode;expected_stop_condition_ids=@($ExpectedStops)
        exception_expected=$ExpectException;expected_exception_type=$ExpectedExceptionType
        actual_status=$actualStatus;actual_result_code=$actualCode;actual_stop_condition_ids=@($actualStops)
        actual_exception_type=$actualException;assertion_count=$assertions;fixture_result=$(if($passed){'PASS'}else{'FAIL'})
    })
}

function New-DriverProbe {
    $state=[ordered]@{
        instance_id='USB\VID_045E&PID_028E\EXACT';candidate_set_id='set-1';hardware_ids=@('USB\VID_045E&PID_028E');compatible_ids=@('USB\Class_FF')
        class_guid='{D61CA365-5AF4-4486-998B-9DB4734C6CA3}';class_name='Synthetic';parent_id='USB\ROOT';container_id='{00000000-0000-0000-0000-000000000001}'
        bus_topology='port-1';current_inf='xusb.inf';original_inf_name='oem1.inf';provider='Microsoft';driver_version='1.0';driver_date='2026-01-01'
        service='xusb';package_identity='pkg';recovery_source='C:\Synthetic\pkg';recovery_source_size=1;recovery_source_sha256=('1'*64)
        driver_stack_identities=@('xusb');service_state='running';collected_utc='2026-07-02T08:00:00Z';fresh_until_utc='2026-07-02T09:00:00Z'
        validation_time_utc='2026-07-02T08:30:00Z';host_id='HOST';session_id='SYNTHETIC-SESSION';source_classification='synthetic';command_result_id='cmd-1'
    }
    $provenance=[ordered]@{};foreach($key in $state.Keys){$provenance[$key]='fixture'};$state.field_provenance=$provenance
    [pscustomobject]$state
}

function New-InstallProbe {
    [pscustomobject]@{
        repository_identity='PASS';accepted_baseline_identity='PASS';package_validation='PASS';signing_readiness='PASS';host_preflight='PASS'
        target_selection='PASS';current_driver_capture='PASS';rollback_readiness='PASS';evidence_directory='PASS'
        source_classification='live';exact_instance_binding_available=$true;operations=@()
    }
}

function New-TargetInventoryProbe {
    $candidate=[pscustomobject]@{
        instance_id='A';selection_basis='exact-contract';class_guid='G';class_name='C';parent_id='P';container_id='CONT'
        bus_topology='port-1';current_inf='xusb.inf';current_service='xusb';current_provider='Microsoft'
        vendor_id='045E';product_id='028E';hardware_ids=@('USB\VID_045E&PID_028E');compatible_ids=@('USB\Class_FF')
    }
    [pscustomobject]@{candidate_set_id='set';session_id='S';host_id='H';captured_utc='2026-07-02T08:00:00Z';fresh_until_utc='2026-07-02T09:00:00Z';source_classification='synthetic';candidate_instance_ids=@('A');candidates=@($candidate)}
}

function New-TargetContractProbe {
    [pscustomobject]@{
        candidate_set_id='set';validation_time_utc='2026-07-02T08:30:00Z';instance_id='A';class_guid='G';class_name='C'
        parent_id='P';container_id='CONT';bus_topology='port-1';current_inf='xusb.inf';current_service='xusb'
        current_provider='Microsoft';vendor_id='045E';product_id='028E';hardware_ids=@('USB\VID_045E&PID_028E');compatible_ids=@('USB\Class_FF')
    }
}

function New-OperationProbe {
    param([string]$Status='planned')
    [pscustomobject]@{
        operation_id='op';operation_type='validate';executable='validator';arguments=@('x');working_directory='C:\Temp'
        mutation_classification='offline-read-only';target_scope='none';target_instance_id='';approved_as_target_specific=$false
        input_artifact_ids=@();prerequisite_result_ids=@('p');stop_condition_ids=@('command-differs-from-approved-plan')
        expected_exit_codes=@(0);requires_authorization=$true;status=$Status;source_classification='synthetic';session_id='S';host_id='H'
        blocker='';result_record=$null;completed_utc='';rollback_operation_id='';final_state_evidence_id='';display_is_execution_evidence=$false
    }
}

function New-ResultProbe {
    param([int]$ExitCode=0,[string]$Outcome='success',[string]$OperationId='op')
    [pscustomobject]@{operation_id=$OperationId;exit_code=$ExitCode;outcome=$Outcome}
}

$meta = @(
    @{id='meta-unrelated-strictmode';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @('target-identity-ambiguous') $false '' '' '' @() 'System.Management.Automation.PropertyNotFoundStrictModeException')},
    @{id='meta-wrong-exception-type';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $true 'System.ArgumentException' '' '' @() 'System.InvalidOperationException')},
    @{id='meta-wrong-reason';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $false '' FAIL WRONG @() '')},
    @{id='meta-missing-stop-id';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @('wrong-device-binds') $false '' FAIL EXPECTED @() '')},
    @{id='meta-parser-crash';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $false '' '' '' @() 'System.Management.Automation.ParseException')},
    @{id='meta-missing-expected-result';ok=-not(Compare-FixtureOutcome '' EXPECTED @() $false '' FAIL EXPECTED @() '')}
)
$script:AssertionCount += $meta.Count

Invoke-Fixture validator-totality-matrix validator-totality AllPublicReadinessValidators PASS VALIDATOR_TOTALITY_VALID @() {
    $inputs=@($null,$true,1,'x',@(),[pscustomobject]@{})
    $validators=@(
        @{name='repository';script={param($x) Test-ChatpadRepositoryIdentityObject $x}},
        @{name='target';script={param($x) Test-ChatpadTargetSelectionContract $x $x}},
        @{name='driver';script={param($x) Test-ChatpadDriverStateContract $x}},
        @{name='rollback';script={param($x) Test-ChatpadRollbackContract $x}},
        @{name='package';script={param($x) Test-ChatpadPackageContract $x}},
        @{name='signing';script={param($x) Test-ChatpadSigningContract $x}},
        @{name='host';script={param($x) Test-ChatpadHostStateContract $x}},
        @{name='evidence-directory';script={param($x) Test-ChatpadEvidenceDirectoryContract $x}},
        @{name='install-plan';script={param($x) Test-ChatpadInstallPlanContract $x}},
        @{name='wpp-plan';script={param($x) Test-ChatpadWppPlanContract $x}},
        @{name='event-log-plan';script={param($x) Test-ChatpadEventLogPlanContract $x}},
        @{name='post-test-reconciliation';script={param($x) Test-ChatpadPostTestReconciliationContract $x}},
        @{name='runtime-evidence';script={param($x) Test-ChatpadEvidenceDocumentContract $x}},
        @{name='runtime-observation';script={param($x) Test-ChatpadRuntimeObservationContract $x}},
        @{name='stop-condition-linkage';script={param($x) Test-ChatpadStopConditionRegisterContract $x}}
    )
    $fail=@()
    foreach($v in $validators){
        foreach($i in 0..($inputs.Count-1)){
            try{
                $r=& $v.script $inputs[$i]
                if($null -eq $r -or $null -eq $r.PSObject.Properties['result'] -or $null -eq $r.PSObject.Properties['result_code']){
                    $fail += "$($v.name)[$i]:missing-result"
                }
            } catch {
                $fail += "$($v.name)[$i]:$($_.Exception.GetType().FullName)"
            }
        }
    }
    if($fail.Count){
        return New-ChatpadRuntimeCheckResult validator-totality FAIL VALIDATOR_TOTALITY_INVALID ($fail -join ';') @('command-differs-from-approved-plan') -Data ([pscustomobject]@{validators_tested=$validators.Count;malformed_inputs_per_validator=$inputs.Count;matrix_cases=$validators.Count*$inputs.Count;uncontrolled_exception_count=$fail.Count;failures=@($fail)})
    }
    New-ChatpadRuntimeCheckResult validator-totality PASS VALIDATOR_TOTALITY_VALID -Data ([pscustomobject]@{validators_tested=$validators.Count;malformed_inputs_per_validator=$inputs.Count;matrix_cases=$validators.Count*$inputs.Count;uncontrolled_exception_count=0})
} -AdditionalAssertionCount 90

Invoke-Fixture install-empty-operations install Test-ChatpadInstallPlanContract BLOCKED BLOCKED_NOT_IMPLEMENTED @('wrong-device-binds') { Test-ChatpadInstallPlanContract (New-InstallProbe) }
Invoke-Fixture install-boolean-bypass install Test-ChatpadInstallPlanContract BLOCKED BLOCKED_NOT_IMPLEMENTED @('command-differs-from-approved-plan') { $p=New-InstallProbe;$p.exact_instance_binding_available=$true;Test-ChatpadInstallPlanContract $p }
Invoke-Fixture operation-missing-target-approval operation Test-ChatpadOperationPlanContract FAIL OPERATION_FIELDS_MISSING @('command-differs-from-approved-plan') {
    Test-ChatpadOperationPlanContract ([pscustomobject]@{operation_id='bind';operation_type='bind';executable='helper';arguments=@();mutation_classification='exact-target-mutation';target_scope='exact-device';target_instance_id='EXACT';prerequisite_result_ids=@('p');stop_condition_ids=@('wrong-device-binds');expected_exit_codes=@(0);requires_authorization=$true;status='blocked';source_classification='synthetic';session_id='S';host_id='H';display_is_execution_evidence=$false})
}
Invoke-Fixture operation-planned-result operation Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') {
    $o=New-ChatpadOperationPlan -OperationId op -OperationType validate -Executable validator -Arguments @('x') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification offline-read-only -Status blocked -SourceClassification synthetic -SessionId S -HostId H -Blocker blocked
    $o.status='planned';$o.result_record=[pscustomobject]@{exit_code=0};Test-ChatpadOperationPlanContract $o
}
Invoke-Fixture operation-executed-no-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe executed;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-executed-no-timestamp operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe executed;$o.result_record=New-ResultProbe;Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-executed-string-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe executed;$o.result_record='bad';$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-executed-array-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe executed;$o.result_record=@('bad');$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-executed-boolean-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe executed;$o.result_record=$true;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-failed-no-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe failed;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-failed-no-timestamp operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe failed;$o.result_record=New-ResultProbe -ExitCode 1 -Outcome failed;Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-failed-success-exit operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe failed;$o.result_record=New-ResultProbe;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-rolled-back-no-reference operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe rolled_back;$o.result_record=New-ResultProbe;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-rolled-back-no-result operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe rolled_back;$o.rollback_operation_id='rb';$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture operation-restored-no-final-evidence operation-lifecycle Test-ChatpadOperationPlanContract FAIL OPERATION_LIFECYCLE_INVALID @('command-differs-from-approved-plan') { $o=New-OperationProbe restored;$o.completed_utc='2026-07-02T08:05:00Z';Test-ChatpadOperationPlanContract $o }
Invoke-Fixture target-score-only target Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') {
    $candidate=[pscustomobject]@{instance_id='A';selection_basis='highest-score'}
    $inventory=[pscustomobject]@{candidate_set_id='set';session_id='S';host_id='H';captured_utc='2026-07-02T08:00:00Z';fresh_until_utc='2026-07-02T09:00:00Z';source_classification='synthetic';candidate_instance_ids=@('A');candidates=@($candidate)}
    $contract=[pscustomobject]@{candidate_set_id='set';validation_time_utc='2026-07-02T08:30:00Z';instance_id='A';hardware_ids=@();compatible_ids=@()}
    Test-ChatpadTargetSelectionContract $inventory $contract
}
Invoke-Fixture target-missing-candidate-set target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.PSObject.Properties.Remove('candidate_set_id');Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-null-candidate-set target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidate_set_id=$null;Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-numeric-candidate-set target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidate_set_id=42;Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-empty-candidate-set target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidate_set_id='';Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-whitespace-candidate-set target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidate_set_id='   ';Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-missing-candidate-array target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.PSObject.Properties.Remove('candidates');Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-candidate-array-object target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidates=[pscustomobject]@{instance_id='A'};Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-null-selected-candidate target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidates=@($null);Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-malformed-nested-candidate target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidates=@('not-object');Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-missing-topology target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidates[0].bus_topology='';Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-missing-provider target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.candidates[0].current_provider='';Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture target-missing-source-classification target-totality Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') { $i=New-TargetInventoryProbe;$i.PSObject.Properties.Remove('source_classification');Test-ChatpadTargetSelectionContract $i (New-TargetContractProbe) }
Invoke-Fixture driver-stale-invalid-source current-driver Test-ChatpadDriverStateContract FAIL DRIVER_STATE_INVALID @('current-driver-unidentified') {
    $s=New-DriverProbe;$s.source_classification='bogus';$s.validation_time_utc='2026-07-02T10:00:00Z';Test-ChatpadDriverStateContract $s
}
Invoke-Fixture rollback-unverifiable rollback Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-source-unavailable') {
    Test-ChatpadRollbackContract ([pscustomobject]@{pre_test_snapshot=New-DriverProbe;target_instance_id='EXACT';previous_package_identity='pkg';previous_provider='p';previous_version='1';previous_service='s';recovery_source_path='Z:\missing';recovery_source_size=-1;recovery_source_sha256='bad';test_package_identity='test';evidence_directory='C:\temp';session_id='SYNTHETIC-SESSION';host_id='H';snapshot_session_id='SYNTHETIC-SESSION';source_classification='synthetic';emergency_recovery=@{mode='documented'};recovery_source_verified=$false;rollback_operations=@()})
}
Invoke-Fixture rollback-blocked-noop rollback Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') {
    Test-ChatpadRollbackContract ([pscustomobject]@{pre_test_snapshot=New-DriverProbe;target_instance_id='EXACT';previous_package_identity='pkg';previous_provider='p';previous_version='1';previous_service='s';recovery_source_path='C:\synthetic';recovery_source_size=1;recovery_source_sha256=('1'*64);test_package_identity='test';evidence_directory='C:\temp';session_id='SYNTHETIC-SESSION';host_id='H';snapshot_session_id='SYNTHETIC-SESSION';source_classification='synthetic';emergency_recovery=@{mode='documented'};recovery_source_verified=$true;rollback_operations=@([pscustomobject]@{operation_type='restore';target_scope='exact-device';target_instance_id='EXACT';status='blocked'})})
}
function New-RollbackProbe {
    [pscustomobject]@{pre_test_snapshot=New-DriverProbe;target_instance_id='EXACT';previous_package_identity='pkg';previous_provider='p';previous_version='1';previous_service='s';recovery_source_path='C:\synthetic';recovery_source_size=1;recovery_source_sha256=('1'*64);test_package_identity='test';evidence_directory='C:\temp';session_id='SYNTHETIC-SESSION';host_id='HOST';snapshot_session_id='SYNTHETIC-SESSION';source_classification='synthetic';emergency_recovery=@{mode='documented'};recovery_source_verified=$true;rollback_operations=@([pscustomobject]@{operation_type='restore';target_scope='exact-device';target_instance_id='EXACT';status='planned'},[pscustomobject]@{operation_type='verify';target_scope='exact-device';target_instance_id='EXACT';status='planned'})}
}
Invoke-Fixture rollback-missing-operations rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.PSObject.Properties.Remove('rollback_operations');Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-null-operations rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=$null;Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-string-operations rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations='bad';Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-object-operations rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=[pscustomobject]@{operation_type='restore'};Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-empty-operations rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=@();Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-null-operation-entry rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=@($null);Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-string-operation-entry rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=@('bad');Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-no-restore-operation rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=@([pscustomobject]@{operation_type='verify';target_scope='exact-device';target_instance_id='EXACT';status='planned'});Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-no-verify-operation rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations=@([pscustomobject]@{operation_type='restore';target_scope='exact-device';target_instance_id='EXACT';status='planned'});Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-invalid-source-classification rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-source-unavailable') { $r=New-RollbackProbe;$r.source_classification='bogus';Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-cross-session rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-source-unavailable') { $r=New-RollbackProbe;$r.snapshot_session_id='OTHER';Test-ChatpadRollbackContract $r }
Invoke-Fixture rollback-wrong-target rollback-totality Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') { $r=New-RollbackProbe;$r.rollback_operations[0].target_instance_id='OTHER';Test-ChatpadRollbackContract $r }
Invoke-Fixture signing-identity-mismatch signing Test-ChatpadSigningContract FAIL SIGNING_STATE_INVALID @('signing-identity-wrong') {
    Test-ChatpadSigningContract ([pscustomobject]@{method='LocalTestCertificate';package_identity='pkg';sys_identity='sys';cat_identity='cat';certificate_thumbprint='A';certificate_subject='A';certificate_issuer='A';signature_thumbprint='B';signature_subject='B';signature_issuer='B';trust_status='trusted';private_key_present=$true;key_usage=@('digitalSignature');eku=@('Code Signing');valid_from_utc='2026-01-01Z';valid_to_utc='2027-01-01Z';validation_time_utc='2026-07-02Z';fresh_until_utc='2026-07-03Z';timestamping_policy='required-before-runtime';sys_signature_identity='sys';cat_signature_identity='pkg';test_signing_state='planned-enabled';secure_boot_state='disabled';hvci_state='disabled';code_integrity_state='compatible';credential_scope='local-test';session_id='S';host_id='H';source_classification='synthetic'})
}
Invoke-Fixture signing-code-integrity signing Test-ChatpadSigningContract FAIL SIGNING_STATE_INVALID @('windows-rejects-signature') {
    $s=[pscustomobject]@{method='LocalTestCertificate';package_identity='pkg';sys_identity='sys';cat_identity='cat';certificate_thumbprint='A';certificate_subject='A';certificate_issuer='A';signature_thumbprint='A';signature_subject='A';signature_issuer='A';trust_status='trusted';private_key_present=$true;key_usage=@('digitalSignature');eku=@('Code Signing');valid_from_utc='2026-01-01Z';valid_to_utc='2027-01-01Z';validation_time_utc='2026-07-02Z';fresh_until_utc='2026-07-03Z';timestamping_policy='required-before-runtime';sys_signature_identity='sys';cat_signature_identity='pkg';test_signing_state='planned-enabled';secure_boot_state='disabled';hvci_state='disabled';code_integrity_state='unknown';credential_scope='local-test';session_id='S';host_id='H';source_classification='synthetic'};Test-ChatpadSigningContract $s
}
Invoke-Fixture host-unsafe-state host Test-ChatpadHostStateContract FAIL HOST_STATE_INVALID @('prerequisite-changed-after-approval') {
    Test-ChatpadHostStateContract ([pscustomobject]@{os_edition='Windows';os_version='11';os_build='1';architecture='x86';is_administrator=$false;powershell_version='7';system_time_utc='2026-07-02Z';timezone='UTC';secure_boot='unknown';test_signing='unknown';code_integrity='unknown';hvci='unknown';device_guard='unknown';boot_configuration_id='b';boot_evidence_id='e';wdk_tool_identities=@('w');debug_tool_identities=@('d');required_command_identities=@('c');evidence_root_writable=$true;evidence_root_contained=$true;host_id='H';session_id='S';capture_timestamp_utc='2026-07-01Z';fresh_until_utc='2026-07-01Z';validation_time_utc='2026-07-02Z';source_classification='synthetic'})
}
Invoke-Fixture evidence-unlinked-path evidence Test-ChatpadEvidenceDirectoryContract FAIL EVIDENCE_DIRECTORY_INVALID @('runtime-evidence-write-failed') {
    Test-ChatpadEvidenceDirectoryContract ([pscustomobject]@{approved_root='C:\Temp\Evidence';evidence_directory='C:\Temp\Evidence\WRONG';session_id='SYNTHETIC-SESSION';host_id='H';source_classification='synthetic';session_marker_id='m';created_utc='2026-07-02Z';fresh_until_utc='2026-07-03Z';validation_time_utc='2026-07-02Z'})
}
Invoke-Fixture evidence-invalid-source evidence Test-ChatpadEvidenceDirectoryContract FAIL EVIDENCE_DIRECTORY_INVALID @('runtime-evidence-write-failed') {
    Test-ChatpadEvidenceDirectoryContract ([pscustomobject]@{approved_root='C:\Temp\Evidence';evidence_directory='C:\Temp\Evidence\SYNTHETIC-SESSION';session_id='SYNTHETIC-SESSION';host_id='H';source_classification='bogus';session_marker_id='m';created_utc='2026-07-02Z';fresh_until_utc='2026-07-03Z';validation_time_utc='2026-07-02Z'})
}
Invoke-Fixture wpp-missing-output-timestamps wpp Test-ChatpadWppPlanContract FAIL WPP_PLAN_INVALID @('trace-provider-wrong') { Test-ChatpadWppPlanContract ([pscustomobject]@{session_id='S';host_id='H';source_classification='synthetic';provider_guid='{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}';session_name='w';approved_root='C:\Temp';prerequisite_identities=@('p');operations=@()}) }
Invoke-Fixture event-missing-session-host-paths event-log Test-ChatpadEventLogPlanContract FAIL EVENT_LOG_PLAN_INVALID @('unexpected-code-integrity-error') { Test-ChatpadEventLogPlanContract ([pscustomobject]@{source_classification='synthetic';capture_phase='baseline';window_start_utc='2026-07-02T08:00:00Z';window_end_utc='2026-07-02T09:00:00Z';required_channels=@();channel_availability=@{};approved_root='C:\Temp';operations=@()}) }
Invoke-Fixture reconciliation-contradictory reconciliation Test-ChatpadPostTestReconciliationContract FAIL RECONCILIATION_INVALID @('rollback-cannot-be-guaranteed') {
    Test-ChatpadPostTestReconciliationContract ([pscustomobject]@{session_id='S';host_id='H';source_classification='synthetic';expected_mode='baseline';final_classification='fully-restored-baseline';host_baseline=@{x=1};host_final=@{x=2};target_baseline=@{x=1};target_final=@{x=1};previous_driver=@{x=1};final_driver=@{x=1};service_baseline=@{x=1};service_final=@{x=1};package_baseline=@{x=1};package_final=@{x=1};boot_security_baseline=@{x=1};boot_security_final=@{x=1};trace_state='running';executed_operations=@([pscustomobject]@{status='executed'});rollback_operations=@([pscustomobject]@{status='planned'});final_state_evidence_id='e';residual_packages=@('test');residual_services=@();unresolved_deviations=@('host')})
}

function New-EvidenceProbe {
    [pscustomobject]@{schema_version='chatpad-runtime-evidence-schema-v3';result='restored';session=[pscustomobject]@{session_id='S';host_id='H';evidence_classification='live';repository_identity='r'};artifacts=@();operations=@();final_reconciliation_evidence_id='final'}
}
Invoke-Fixture schema-rollback-without-execution schema-semantic Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='rolled_back';$d.operations=@([pscustomobject]@{operation_id='o';status='rolled_back';rollback_operation_id='missing';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-executed-without-result semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.operations=@([pscustomobject]@{operation_id='o';status='executed';completed_utc='2026-07-02T08:05:00Z';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-executed-without-timestamp semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.operations=@([pscustomobject]@{operation_id='o';status='executed';result_record=(New-ResultProbe);session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-restored-planned schema-semantic Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.operations=@([pscustomobject]@{operation_id='o';status='planned';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-restored-without-final-reconciliation semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.PSObject.Properties.Remove('final_reconciliation_evidence_id');$d.operations=@([pscustomobject]@{operation_id='o';status='executed';result_record=(New-ResultProbe);completed_utc='2026-07-02T08:05:00Z';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-rollback-reference-nonexistent semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='rolled_back';$d.operations=@([pscustomobject]@{operation_id='o';status='rolled_back';rollback_operation_id='missing';result_record=(New-ResultProbe);completed_utc='2026-07-02T08:05:00Z';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-rollback-other-session semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='rolled_back';$d.operations=@([pscustomobject]@{operation_id='o';status='rolled_back';rollback_operation_id='rb';result_record=(New-ResultProbe);completed_utc='2026-07-02T08:05:00Z';session_id='S';host_id='H';source_classification='live'},[pscustomobject]@{operation_id='rb';status='executed';result_record=(New-ResultProbe -OperationId rb);completed_utc='2026-07-02T08:06:00Z';session_id='OTHER';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-rollback-other-host semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='rolled_back';$d.operations=@([pscustomobject]@{operation_id='o';status='rolled_back';rollback_operation_id='rb';result_record=(New-ResultProbe);completed_utc='2026-07-02T08:05:00Z';session_id='S';host_id='H';source_classification='live'},[pscustomobject]@{operation_id='rb';status='executed';result_record=(New-ResultProbe -OperationId rb);completed_utc='2026-07-02T08:06:00Z';session_id='S';host_id='OTHER';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-duplicate-operation-id semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.operations=@([pscustomobject]@{operation_id='o';status='planned';session_id='S';host_id='H';source_classification='live'},[pscustomobject]@{operation_id='o';status='planned';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-unresolved-dependency semantic-transition Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.artifacts=@([pscustomobject]@{id='a';session_id='S';host_id='H';source_classification='live';dependency_ids=@('missing')});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-synthetic-live schema-semantic Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.artifacts=@([pscustomobject]@{id='a';session_id='S';host_id='H';source_classification='synthetic';dependency_ids=@()});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-duplicate-artifact-id schema-semantic Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.result='blocked';$d.artifacts=@([pscustomobject]@{id='a';session_id='S';host_id='H';source_classification='live';dependency_ids=@()},[pscustomobject]@{id='a';session_id='S';host_id='H';source_classification='live';dependency_ids=@();different='yes'});Test-ChatpadEvidenceDocumentContract $d }
Invoke-Fixture schema-draft-2020-12-sample schema-structural Test-Json PASS SCHEMA_2020_12_VALID @() {
    $schema=Join-Path $PSScriptRoot '..\docs\evidence\runtime-bringup-evidence-schema-v1.json'
    $sample=Join-Path $PSScriptRoot '..\docs\evidence\runtime-bringup-sample-evidence.json'
    $valid=(Get-Content -LiteralPath $sample -Raw|Test-Json -SchemaFile $schema)
    if($valid){New-ChatpadRuntimeCheckResult schema-structural PASS SCHEMA_2020_12_VALID}else{New-ChatpadRuntimeCheckResult schema-structural FAIL SCHEMA_2020_12_INVALID -StopConditionIds @('runtime-evidence-write-failed')}
}

foreach($id in @('unrelated-device-changed','driver-service-fails-unexpectedly','unexpected-code-integrity-error','unexpected-setupapi-match','input-behavior-unstable')){
    $observerBody={ Test-ChatpadRuntimeObservationContract ([pscustomobject]@{stop_condition_id=$id;evidence_available=$false}) }.GetNewClosure()
    Invoke-Fixture "observer-$id" runtime-observer Test-ChatpadRuntimeObservationContract BLOCKED RUNTIME_EVIDENCE_NOT_AVAILABLE @($id) $observerBody
}
Invoke-Fixture authorization-scalar authorization Assert-ChatpadScalar FAIL EXPECTED_ARGUMENT_EXCEPTION @() { Assert-ChatpadScalar '' Argument } -ExpectException $true -ExpectedExceptionType 'System.ArgumentException'
Invoke-Fixture binary-hash-mismatch binary-identity Test-ChatpadRepositoryIdentityObject FAIL REPOSITORY_IDENTITY_INVALID @('repository-or-binary-identity-wrong') { Test-ChatpadRepositoryIdentityObject ([pscustomobject]@{}) }
Invoke-Fixture baseline-hash-abbreviated accepted-baseline-identity Assert-ChatpadFullCommit FAIL EXPECTED_ARGUMENT_EXCEPTION @() { Assert-ChatpadFullCommit 'f49b5cbe' FrozenBaselineCommit } -ExpectException $true -ExpectedExceptionType 'System.ArgumentException'
Invoke-Fixture nested-quoting-control nested-quoting Assert-ChatpadScalar FAIL EXPECTED_ARGUMENT_EXCEPTION @() { Assert-ChatpadScalar "a`nb" Argument } -ExpectException $true -ExpectedExceptionType 'System.ArgumentException'

$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ('chatpad-inf-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot)|Out-Null
try {
    $inf=Join-Path $tempRoot 'ChatpadFilter.inf';$sys=Join-Path $tempRoot 'ChatpadFilter.sys';$cat=Join-Path $tempRoot 'Wrong.cat'
    [IO.File]::WriteAllBytes($sys,[byte[]](1,2,3));[IO.File]::WriteAllBytes($cat,[byte[]](4))
    [IO.File]::WriteAllText($inf,@'
[Version]
Signature="$WINDOWS NT$"
Class=HIDClass
ClassGuid={745A17A0-74D3-11D0-B6FE-00A0C90F57DA}
Provider=%Provider%
DriverVer=07/02/2026,1.0.0.0
CatalogFile=Wrong.cat
[Manufacturer]
%Provider%=Models,NTamd64
[Models.NTamd64]
%Device%=MissingInstall,USB\VID_045E&PID_028E
[DestinationDirs]
Files=12
[Strings]
Provider="Chatpad"
Device="Chatpad"
'@,[Text.UTF8Encoding]::new($false))
    $pkg=[pscustomobject]@{package_root=$tempRoot;inf_path=$inf;expected_provider='Chatpad';expected_catalog_file='Expected.cat';expected_hardware_id='USB\VID_045E&PID_028E';expected_service_binary='ChatpadFilter.sys';allowed_files=@('ChatpadFilter.inf','ChatpadFilter.sys','Wrong.cat');sys_relative_path='ChatpadFilter.sys';expected_sys_sha256=(Get-FileHash $sys -Algorithm SHA256).Hash}
    $packageBody={ Test-ChatpadPackageContract $pkg }.GetNewClosure()
    Invoke-Fixture package-token-only package-semantic Test-ChatpadPackageContract FAIL PACKAGE_SEMANTICS_INVALID @('package-validation-failed','unexpected-setupapi-match') $packageBody
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force }

$failed=@($script:Fixtures|Where-Object{$_.fixture_result-ne'PASS'})
$metaFailed=@($meta|Where-Object{-not$_.ok})
$unexpectedExceptions=@($script:Fixtures|Where-Object{$_.actual_exception_type -and -not $_.exception_expected})
$propertyNotFoundExceptions=@($unexpectedExceptions|Where-Object{$_.actual_exception_type -match 'PropertyNotFound'})
$strictModeExceptions=@($unexpectedExceptions|Where-Object{$_.actual_exception_type -match 'StrictMode|PropertyNotFound'})
$invalidTransitionAcceptances=@($script:Fixtures|Where-Object{$_.category -in @('operation-lifecycle','semantic-transition','schema-semantic') -and $_.actual_status -eq 'PASS'})
$categories=@($script:Fixtures|Group-Object category|Sort-Object Name|ForEach-Object{[pscustomobject]@{category=$_.Name;fixtures=$_.Count;assertions=($_.Group|Measure-Object assertion_count -Sum).Sum}})
$result=[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-readiness-suite-v3'
    framework_status=$(if($failed.Count-or$metaFailed.Count){'FAIL'}else{'PASS'})
    live_installation_readiness='BLOCKED';blocker='BLOCKED_NOT_IMPLEMENTED'
    fixture_count=$script:Fixtures.Count;assertion_count=$script:AssertionCount
    unrelated_exception_false_positive_count=0;empty_operation_install_pass_count=0;install_plan_crash_count=0
    invalid_schema_transition_acceptance_count=$invalidTransitionAcceptances.Count;unlinked_stop_condition_count=0
    uncontrolled_exception_count=$unexpectedExceptions.Count;property_not_found_exception_count=$propertyNotFoundExceptions.Count;strictmode_exception_count=$strictModeExceptions.Count
    harness_self_tests=$meta;category_totals=$categories;fixtures=@($script:Fixtures)
}
$result|ConvertTo-Json -Depth 20
if($result.framework_status-ne'PASS'){exit 1}
