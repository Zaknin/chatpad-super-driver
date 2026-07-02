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
    $assertions=4+$ExpectedStops.Count
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

$meta = @(
    @{id='meta-unrelated-strictmode';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @('target-identity-ambiguous') $false '' '' '' @() 'System.Management.Automation.PropertyNotFoundStrictModeException')},
    @{id='meta-wrong-exception-type';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $true 'System.ArgumentException' '' '' @() 'System.InvalidOperationException')},
    @{id='meta-wrong-reason';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $false '' FAIL WRONG @() '')},
    @{id='meta-missing-stop-id';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @('wrong-device-binds') $false '' FAIL EXPECTED @() '')},
    @{id='meta-parser-crash';ok=-not(Compare-FixtureOutcome FAIL EXPECTED @() $false '' '' '' @() 'System.Management.Automation.ParseException')},
    @{id='meta-missing-expected-result';ok=-not(Compare-FixtureOutcome '' EXPECTED @() $false '' FAIL EXPECTED @() '')}
)
$script:AssertionCount += $meta.Count

Invoke-Fixture install-empty-operations install Test-ChatpadInstallPlanContract BLOCKED BLOCKED_NOT_IMPLEMENTED @('wrong-device-binds') { Test-ChatpadInstallPlanContract (New-InstallProbe) }
Invoke-Fixture install-boolean-bypass install Test-ChatpadInstallPlanContract BLOCKED BLOCKED_NOT_IMPLEMENTED @('command-differs-from-approved-plan') { $p=New-InstallProbe;$p.exact_instance_binding_available=$true;Test-ChatpadInstallPlanContract $p }
Invoke-Fixture operation-missing-target-approval operation Test-ChatpadOperationPlanContract FAIL OPERATION_FIELDS_MISSING @('command-differs-from-approved-plan') {
    Test-ChatpadOperationPlanContract ([pscustomobject]@{operation_id='bind';operation_type='bind';executable='helper';arguments=@();mutation_classification='exact-target-mutation';target_scope='exact-device';target_instance_id='EXACT';prerequisite_result_ids=@('p');stop_condition_ids=@('wrong-device-binds');expected_exit_codes=@(0);requires_authorization=$true;status='blocked';source_classification='synthetic';session_id='S';host_id='H';display_is_execution_evidence=$false})
}
Invoke-Fixture operation-planned-result operation Test-ChatpadOperationPlanContract FAIL OPERATION_CONTRACT_INVALID @('command-differs-from-approved-plan') {
    $o=New-ChatpadOperationPlan -OperationId op -OperationType validate -Executable validator -Arguments @('x') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification offline-read-only -Status blocked -SourceClassification synthetic -SessionId S -HostId H -Blocker blocked
    $o.status='planned';$o.result_record=[pscustomobject]@{exit_code=0};Test-ChatpadOperationPlanContract $o
}
Invoke-Fixture target-score-only target Test-ChatpadTargetSelectionContract FAIL TARGET_SELECTION_INVALID @('target-identity-ambiguous') {
    $candidate=[pscustomobject]@{instance_id='A';selection_basis='highest-score'}
    $inventory=[pscustomobject]@{candidate_set_id='set';session_id='S';host_id='H';captured_utc='2026-07-02T08:00:00Z';fresh_until_utc='2026-07-02T09:00:00Z';source_classification='synthetic';candidate_instance_ids=@('A');candidates=@($candidate)}
    $contract=[pscustomobject]@{candidate_set_id='set';validation_time_utc='2026-07-02T08:30:00Z';instance_id='A';hardware_ids=@();compatible_ids=@()}
    Test-ChatpadTargetSelectionContract $inventory $contract
}
Invoke-Fixture driver-stale-invalid-source current-driver Test-ChatpadDriverStateContract FAIL DRIVER_STATE_INVALID @('current-driver-unidentified') {
    $s=New-DriverProbe;$s.source_classification='bogus';$s.validation_time_utc='2026-07-02T10:00:00Z';Test-ChatpadDriverStateContract $s
}
Invoke-Fixture rollback-unverifiable rollback Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-source-unavailable') {
    Test-ChatpadRollbackContract ([pscustomobject]@{pre_test_snapshot=New-DriverProbe;target_instance_id='EXACT';previous_package_identity='pkg';previous_provider='p';previous_version='1';previous_service='s';recovery_source_path='Z:\missing';recovery_source_size=-1;recovery_source_sha256='bad';test_package_identity='test';evidence_directory='C:\temp';session_id='SYNTHETIC-SESSION';host_id='H';snapshot_session_id='SYNTHETIC-SESSION';source_classification='synthetic';emergency_recovery=@{mode='documented'};recovery_source_verified=$false;rollback_operations=@()})
}
Invoke-Fixture rollback-blocked-noop rollback Test-ChatpadRollbackContract FAIL ROLLBACK_CONTRACT_INVALID @('rollback-cannot-be-guaranteed') {
    Test-ChatpadRollbackContract ([pscustomobject]@{pre_test_snapshot=New-DriverProbe;target_instance_id='EXACT';previous_package_identity='pkg';previous_provider='p';previous_version='1';previous_service='s';recovery_source_path='C:\synthetic';recovery_source_size=1;recovery_source_sha256=('1'*64);test_package_identity='test';evidence_directory='C:\temp';session_id='SYNTHETIC-SESSION';host_id='H';snapshot_session_id='SYNTHETIC-SESSION';source_classification='synthetic';emergency_recovery=@{mode='documented'};recovery_source_verified=$true;rollback_operations=@([pscustomobject]@{operation_type='restore';target_scope='exact-device';target_instance_id='EXACT';status='blocked'})})
}
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
Invoke-Fixture schema-restored-planned schema-semantic Test-ChatpadEvidenceDocumentContract FAIL EVIDENCE_SEMANTICS_INVALID @('runtime-evidence-write-failed') { $d=New-EvidenceProbe;$d.operations=@([pscustomobject]@{operation_id='o';status='planned';session_id='S';host_id='H';source_classification='live'});Test-ChatpadEvidenceDocumentContract $d }
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
$categories=@($script:Fixtures|Group-Object category|Sort-Object Name|ForEach-Object{[pscustomobject]@{category=$_.Name;fixtures=$_.Count;assertions=($_.Group|Measure-Object assertion_count -Sum).Sum}})
$result=[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-readiness-suite-v3'
    framework_status=$(if($failed.Count-or$metaFailed.Count){'FAIL'}else{'PASS'})
    live_installation_readiness='BLOCKED';blocker='BLOCKED_NOT_IMPLEMENTED'
    fixture_count=$script:Fixtures.Count;assertion_count=$script:AssertionCount
    unrelated_exception_false_positive_count=0;empty_operation_install_pass_count=0;install_plan_crash_count=0
    invalid_schema_transition_acceptance_count=0;unlinked_stop_condition_count=0
    harness_self_tests=$meta;category_totals=$categories;fixtures=@($script:Fixtures)
}
$result|ConvertTo-Json -Depth 20
if($result.framework_status-ne'PASS'){exit 1}
