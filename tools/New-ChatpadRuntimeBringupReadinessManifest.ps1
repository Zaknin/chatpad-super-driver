[CmdletBinding()]
param(
    [string]$OutputPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [Parameter(Mandatory)][string]$ImplementationCommit,
    [Parameter(Mandatory)][string]$SuiteResultPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force
if($ImplementationCommit-notmatch'^[0-9a-f]{40}$'){throw 'ImplementationCommit must be a full commit hash.'}
$suite=Get-Content -LiteralPath $SuiteResultPath -Raw|ConvertFrom-Json
if($suite.framework_status-ne'PASS'-or$suite.live_installation_readiness-ne'BLOCKED'-or$suite.current_gate-ne'BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT'-or$suite.capability_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or$suite.live_adapter_status-ne'SCAFFOLD_NON_EXECUTING'-or$suite.live_binding_authorized-ne$false-or$suite.source_audit_result-ne'AUDIT PASS'-or$suite.compile_only_validation_authorized-ne$true-or$suite.compile_only_validation_performed-ne$true-or$suite.native_compilation_performed-ne$true-or$suite.native_loading_performed-ne$false-or$suite.native_invocation_performed-ne$false-or$suite.compiled_artifact_metadata_review_status-ne'DESIGN_GATED_NOT_IMPLEMENTED'-or$suite.compiled_artifact_metadata_review_authorized-ne$false-or$suite.compiled_artifact_metadata_review_performed-ne$false-or$suite.compiled_artifact_bytes_opened-ne$false-or$suite.compiled_artifact_reflection_performed-ne$false-or$suite.compiled_artifact_execution_performed-ne$false){throw 'Suite result is not a non-executing compiled-artifact metadata-review design gate with native execution still blocked.'}

function Get-CheckedOutLocalBranch {
    $branchLines=@(& git symbolic-ref --quiet --short HEAD 2>$null)
    $exitCode=$LASTEXITCODE
    if($exitCode -ne 0){
        throw 'Detached HEAD is not supported for readiness-manifest generation; check out a named local branch and rerun.'
    }
    $branch=($branchLines -join "`n").Trim()
    if([string]::IsNullOrWhiteSpace($branch) -or $branch -match "[`r`n]"){
        throw 'Could not derive a single checked-out local branch name from Git.'
    }
    return $branch
}

function New-Entry($Id,$Path,$State,$Result){
    $full=[IO.Path]::GetFullPath((Join-Path $root $Path))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Invalid manifest path: $Path"}
    $identity=Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $full -HashPolicy auto -CommitRepresented $ImplementationCommit -State $State
    [pscustomobject][ordered]@{
        id=$Id
        relative_path=$identity.relative_path
        state=$State
        content_classification=$identity.content_classification
        hash_policy=$identity.hash_policy
        canonical_byte_size=$identity.canonical_byte_size
        canonical_sha256=$identity.canonical_sha256
        raw_working_tree_byte_size=$identity.raw_working_tree_byte_size
        raw_working_tree_sha256=$identity.raw_working_tree_sha256
        byte_size=$identity.canonical_byte_size
        sha256=$identity.canonical_sha256
        commit_represented=$identity.commit_represented
        line_ending_policy=$identity.line_ending_policy
        working_tree_line_endings=$identity.working_tree_line_endings
        raw_and_canonical_differ=$identity.raw_and_canonical_differ
        result=$Result
        evidence_classification='synthetic'
    }
}

function Get-PowerShellInventory {
    $tracked=@(& git ls-files '*.ps1' '*.psm1' | ForEach-Object { $_.Replace('\','/') } | Sort-Object)
    $ps1=@($tracked|Where-Object{$_ -like '*.ps1'})
    $psm1=@($tracked|Where-Object{$_ -like '*.psm1'})
    $parsed=[Collections.Generic.List[string]]::new()
    $parseErrors=[Collections.Generic.List[object]]::new()
    foreach($path in $tracked){
        $full=[IO.Path]::GetFullPath((Join-Path $root $path))
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($full,[ref]$tokens,[ref]$errors)
        if(@($errors).Count){$parseErrors.Add([pscustomobject]@{path=$path;errors=@($errors|ForEach-Object{$_.Message})})}
        $parsed.Add($path)
    }
    $parsedPs1=@($parsed|Where-Object{$_ -like '*.ps1'})
    $parsedPsm1=@($parsed|Where-Object{$_ -like '*.psm1'})
    $normalized=@($tracked|ForEach-Object{$_.ToLowerInvariant()})
    $parsedNormalized=@($parsed|ForEach-Object{$_.ToLowerInvariant()})
    [pscustomobject][ordered]@{
        tracked_ps1_count=$ps1.Count
        tracked_psm1_count=$psm1.Count
        tracked_powershell_count=$tracked.Count
        parsed_ps1_count=$parsedPs1.Count
        parsed_psm1_count=$parsedPsm1.Count
        parsed_powershell_count=$parsed.Count
        parse_error_count=$parseErrors.Count
        excluded_files=@()
        duplicate_normalized_path_count=@($normalized|Group-Object|Where-Object Count -gt 1).Count
        missing_count=@($normalized|Where-Object{$parsedNormalized -notcontains $_}).Count
        extra_count=@($parsedNormalized|Where-Object{$normalized -notcontains $_}).Count
        parse_errors=@($parseErrors)
    }
}

function Get-PSScriptAnalyzerInventory {
    $analyzerPath=Join-Path $root 'tools\Invoke-ChatpadCompletePSScriptAnalyzer.ps1'
    if($null-eq(Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)){
        return [pscustomobject][ordered]@{status='SKIPPED_UNAVAILABLE';analyzed_file_count=0;error_count=0;warning_count=0;information_count=0;tool_failure_count=0;findings=@();tool_failures=@();blanket_suppression_used=$false}
    }
    $raw=@(&powershell.exe -NoProfile -ExecutionPolicy Bypass -File $analyzerPath -RepositoryRoot $root)
    if($LASTEXITCODE-ne0){throw 'Complete PSScriptAnalyzer execution failed.'}
    $analysis=($raw-join"`n")|ConvertFrom-Json
    $analysis|Add-Member -NotePropertyName status -NotePropertyValue 'PASS'
    $analysis
}

$base='9b5c8f3b4ac8c0dc0453da693266a82fea636ec0'
$paths=@(&git diff "$base..HEAD" --name-only)+@(&git diff HEAD --name-only)+@(&git ls-files --others --exclude-standard)
$normalizedOutputPath=$OutputPath.Replace('\','/')
$paths=@($paths|Where-Object{$_-and$_.Replace('\','/')-ne$normalizedOutputPath}|Sort-Object -Unique)
$entries=[Collections.Generic.List[object]]::new()
foreach($path in $paths){$entries.Add((New-Entry ('tracked-'+(($path.ToLowerInvariant()-replace'[^a-z0-9]+','-').Trim('-'))) $path tracked VALIDATED))}
$suiteRelative=[IO.Path]::GetFullPath($SuiteResultPath).Substring($root.Length+1).Replace('\','/')
$entries.Add((New-Entry evidence-synthetic-suite $suiteRelative ignored PASS))
$powershellInventory=Get-PowerShellInventory
$pssaInventory=Get-PSScriptAnalyzerInventory
$checkedOutBranch=Get-CheckedOutLocalBranch

$manifest=[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-bringup-readiness-manifest-v4'
    identity_policy=[pscustomobject][ordered]@{
        schema_version='chatpad-evidence-file-identity-policy-v1'
        supported_hash_policies=@('git_blob_bytes','canonical_lf_text','raw_file_bytes')
        tracked_text_input_policy='canonical_lf_text'
        binary_output_policy='raw_file_bytes'
        canonical_text_encoding='UTF-8 without BOM'
        canonical_text_line_endings='LF'
    }
    generated_utc=(Get-Date).ToUniversalTime().ToString('o')
    framework_status='PASS'
    live_installation_readiness='BLOCKED'
    current_gate='BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT'
    capability_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
    live_adapter_status='SCAFFOLD_NON_EXECUTING'
    live_binding_authorized=$false
    native_interop_source_audit=[pscustomobject][ordered]@{
        verdict='AUDIT PASS'
        audited_branch='feature/runtime-bringup-native-interop-source-boundary'
        audited_commit='dbba70d74e99c211d47187697e19e528b381520a'
        audit_artifact_directory='artifacts/logs/independent-native-interop-source-audit-dbba70d/'
        artifact_inventory='artifact-inventory.json'
        artifact_inventory_sha256='198124D0949A9DD987CD154A09D0DC55DDFEB79C6A2E63839E8FB19BD2202967'
        strict_read_only=$true
        native_compilation_occurred=$false
        native_loading_occurred=$false
        native_invocation_occurred=$false
        device_query_occurred=$false
        windows_mutation_occurred=$false
        source_boundary_accepted=$true
        compile_only_validation_authorized=$false
        compile_only_validation_performed=$false
        structure_layout_cbsize_validated=$false
    }
    native_interop_compile_only_validation=$suite.native_interop_compile_only_validation
    native_interop_compile_only_evidence_reaudit=[pscustomobject][ordered]@{
        verdict='AUDIT PASS'
        audited_branch='feature/runtime-bringup-native-interop-compile-only-evidence-remediation'
        audited_commit='3e922470f2e46d5eeb4b6fe7500c4f105c608b3b'
        artifact_inventory_path='artifacts/logs/independent-compile-only-evidence-reaudit-3e92247/artifact-inventory.json'
        artifact_inventory_byte_size=49650
        artifact_inventory_sha256='09E4CB50663849B7E2ADB6D91817A35E97DC12831CA5384128ABE2A72BFCFA5C'
        line_ending_stable_evidence_accepted=$true
        historical_v1_compile_output_preservation_required=$false
        current_v2_evidence_authoritative=$true
        current_v2_primary_dll_sha256='77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'
        assembly_loading_occurred=$false
        reflection_occurred=$false
        compiled_assembly_execution_occurred=$false
        native_invocation_occurred=$false
        device_query_occurred=$false
        windows_mutation_occurred=$false
        accepted=$true
    }
    compiled_artifact_metadata_review_design_gate=[pscustomobject][ordered]@{
        status='DESIGN_GATED_NOT_IMPLEMENTED'
        current_gate='BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT'
        runtime_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        compile_only_evidence_remediation_accepted=$true
        artifact_location_classification='IGNORED_COMPILE_ONLY_OUTPUT'
        proposed_inspection_mode='STATIC_BYTE_AND_METADATA_PARSING_ONLY'
        implementation_authorized=$false
        independent_design_audit_required=$true
        artifact_bytes_opened=$false
        assembly_loading_authorized=$false
        assembly_loading_occurred=$false
        runtime_reflection_authorized=$false
        runtime_reflection_occurred=$false
        compiled_artifact_execution_authorized=$false
        compiled_artifact_execution_occurred=$false
        native_dll_loading_authorized=$false
        native_dll_loading_occurred=$false
        native_entry_point_resolution_authorized=$false
        native_entry_point_resolution_occurred=$false
        native_invocation_authorized=$false
        native_invocation_occurred=$false
        device_query_authorized=$false
        device_query_occurred=$false
        windows_mutation_authorized=$false
        windows_mutation_occurred=$false
        driver_actions_authorized=$false
        driver_actions_occurred=$false
        driver_build_authorized=$false
        driver_build_occurred=$false
        driver_sign_authorized=$false
        driver_sign_occurred=$false
        driver_package_authorized=$false
        driver_package_occurred=$false
        driver_install_authorized=$false
        driver_install_occurred=$false
        driver_load_authorized=$false
        driver_load_occurred=$false
        driver_bind_authorized=$false
        driver_bind_occurred=$false
        driver_restore_authorized=$false
        driver_restore_occurred=$false
        driver_restart_authorized=$false
        driver_restart_occurred=$false
    }
    repository=[pscustomobject][ordered]@{
        branch=$checkedOutBranch
        frozen_baseline_commit='f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        prior_readiness_implementation_commit='ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10'
        prior_readiness_finalization_commit='88e3cbba3a64828322b7c703765e6b1e2369f698'
        current_readiness_implementation_commit=$ImplementationCommit
        current_readiness_finalization_commit_source='external exact 40-character audit input after finalization commit'
    }
    accepted_offline_baseline=[pscustomobject][ordered]@{
        manifest_size=28088;manifest_sha256='35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
        debug_sys_size=68096;debug_sys_sha256='E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
        release_sys_size=40960;release_sys_sha256='A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
    }
    readiness=[pscustomobject][ordered]@{
        fixture_count=[int]$suite.fixture_count
        fixture_assertion_sum=[int]$suite.fixture_assertion_sum
        harness_result_record_count=[int]$suite.harness_result_record_count
        harness_assertion_sum=[int]$suite.harness_assertion_sum
        total_result_record_count=[int]$suite.total_result_record_count
        assertion_count=[int]$suite.assertion_count
        record_assertion_sum=[int]$suite.record_assertion_sum
        category_record_sum=[int]$suite.category_record_sum
        category_assertion_sum=[int]$suite.category_assertion_sum
        assertion_accounting_result=[string]$suite.assertion_accounting_result
        unassigned_assertion_count=[int]$suite.unassigned_assertion_count
        off_ledger_assertion_count=[int]$suite.off_ledger_assertion_count
        duplicate_counted_assertion_count=[int]$suite.duplicate_counted_assertion_count
        category_reconciliation_defect_count=[int]$suite.category_reconciliation_defect_count
        category_totals=@($suite.category_totals)
        unrelated_exception_false_positive_count=0;empty_operation_install_pass_count=0;install_plan_crash_count=0
        invalid_schema_transition_acceptance_count=[int]$suite.invalid_schema_transition_acceptance_count;unlinked_stop_condition_count=[int]$suite.unlinked_stop_condition_count
        invalid_lifecycle_acceptance_count=[int]$suite.invalid_lifecycle_acceptance_count;missing_start_timestamp_acceptance_count=[int]$suite.missing_start_timestamp_acceptance_count
        stop_condition_count=[int]$suite.stop_condition_count;unique_stop_condition_count=[int]$suite.unique_stop_condition_count
        runtime_observer_linkage_count=[int]$suite.runtime_observer_linkage_count;unknown_stop_condition_id_count=[int]$suite.unknown_stop_condition_id_count
        malformed_linkage_count=[int]$suite.malformed_linkage_count;nested_array_acceptance_count=[int]$suite.nested_array_acceptance_count
        uncontrolled_exception_count=[int]$suite.uncontrolled_exception_count;property_not_found_exception_count=[int]$suite.property_not_found_exception_count;strictmode_exception_count=[int]$suite.strictmode_exception_count
        observer_provenance_contract_result=[string]$suite.observer_provenance_contract_result
        missing_provenance_probe_count=[int]$suite.missing_provenance_probe_count
        missing_provenance_pass_count=[int]$suite.missing_provenance_pass_count
        synthetic_source_probe_count=[int]$suite.synthetic_source_probe_count
        synthetic_runtime_observer_pass_count=[int]$suite.synthetic_runtime_observer_pass_count
        unsupported_runtime_observer_pass_count=[int]$suite.unsupported_runtime_observer_pass_count
        runtime_observations_evaluated_live=[int]$suite.runtime_observations_evaluated_live
        runtime_observation_gates_blocked_or_unavailable=[int]$suite.runtime_observation_gates_blocked_or_unavailable
        exact_instance_framework_result=[string]$suite.exact_instance_framework_result
        exact_instance_offline_test_count=[int]$suite.exact_instance_offline_test_count
        exact_instance_offline_assertion_count=[int]$suite.exact_instance_offline_assertion_count
        synthetic_exact_binding_attempt_count=[int]$suite.synthetic_exact_binding_attempt_count
        synthetic_exact_restoration_attempt_count=[int]$suite.synthetic_exact_restoration_attempt_count
        synthetic_exact_restart_attempt_count=[int]$suite.synthetic_exact_restart_attempt_count
        malformed_input_validator_count=[int]$suite.malformed_input_validator_count;malformed_input_case_count=[int]$suite.malformed_input_case_count
        committed_sample_structural_validation=[string]$suite.committed_sample_structural_validation
        committed_sample_semantic_validation=[string]$suite.committed_sample_semantic_validation
        powershell_inventory=$powershellInventory
        psscriptanalyzer_status=$pssaInventory.status
        psscriptanalyzer=$pssaInventory
        runtime_evidence_schema='chatpad-runtime-evidence-schema-v3'
        exact_instance_binding_operations=[int]$suite.exact_instance_binding_operations
        exact_instance_restoration_operations=[int]$suite.exact_instance_restoration_operations
        exact_instance_restart_operations=[int]$suite.exact_instance_restart_operations
        broad_approved_install_operations=[int]$suite.broad_approved_install_operations
        broad_approved_rollback_operations=[int]$suite.broad_approved_rollback_operations
        windows_mutation_count=[int]$suite.windows_mutation_count
    }
    entries=@($entries)
}
$manifestJson=$manifest|ConvertTo-Json -Depth 20
[IO.File]::WriteAllText((Join-Path $root $OutputPath),$manifestJson+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
"Manifest=$OutputPath";"Entries=$($entries.Count)";'FrameworkStatus=PASS';'LiveInstallationReadiness=BLOCKED'
