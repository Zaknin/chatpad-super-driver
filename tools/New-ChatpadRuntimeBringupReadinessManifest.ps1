[CmdletBinding()]
param(
    [string]$OutputPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [Parameter(Mandatory)][string]$ImplementationCommit,
    [Parameter(Mandatory)][string]$SuiteResultPath,
    [string]$ParserEvidencePath='artifacts/logs/static-metadata-parser-preflight-output-remediation/static-metadata-parser-synthetic-validation.json',
    [switch]$NoArtifactOpenDesignGateAudit
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force
if($ImplementationCommit-notmatch'^[0-9a-f]{40}$'){throw 'ImplementationCommit must be a full commit hash.'}

function Test-ChatpadApprovedParserEvidencePath {
    param([AllowNull()][AllowEmptyString()][string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)-or[IO.Path]::IsPathRooted($Path)){return $false}
    $normalized=$Path.Replace('\','/')
    if($normalized.Contains('//')-or$normalized.Contains(':')){return $false}
    $segments=@($normalized.Split('/')|Where-Object{$_-ne''})
    if($segments.Count-lt4-or$segments[0]-cne'artifacts'-or$segments[1]-cne'logs'){return $false}
    if(@($segments|Where-Object{$_-in@('.','..')}).Count){return $false}
    $rootSegment=$segments[2]
    if($rootSegment -cne 'static-parser-real-artifact-authorization-plumbing' -and $rootSegment -cne 'static-parser-status-boundary-remediation' -and $rootSegment-notmatch'(?i)^(static-metadata-parser-[a-z0-9][a-z0-9-]*|independent-static-metadata-parser-[a-z0-9][a-z0-9-]*|independent-static-parser-real-artifact-authorization-plumbing-(audit|remediation|remediation-audit)-[a-f0-9]{7,40})$'){return $false}
    $tail=($segments|Select-Object -Skip 3) -join '/'
    if($normalized-match'(?i)(artifacts/compile-only|chatpad\.nativeinterop\.compileonlyvalidation\.dll|compiled-artifact|native-interop|metadata-review|/legacy/)'){return $false}
    if($tail-match'(?i)real-artifact'){return $false}
    return $segments[-1]-ceq'static-metadata-parser-synthetic-validation.json'
}

if(-not(Test-ChatpadApprovedParserEvidencePath -Path $ParserEvidencePath)){
    throw 'ParserEvidencePath is outside approved parser-specific ignored evidence roots.'
}

$suite=Get-Content -LiteralPath $SuiteResultPath -Raw|ConvertFrom-Json
$suiteNativeExecutionProperty=$suite.PSObject.Properties['native_execution_status']
$suiteNativeExecutionAccepted=if($NoArtifactOpenDesignGateAudit){
    $null-eq$suiteNativeExecutionProperty-or$suiteNativeExecutionProperty.Value-eq'NOT_IMPLEMENTED'
}else{
    $null-ne$suiteNativeExecutionProperty-and$suiteNativeExecutionProperty.Value-eq'NOT_IMPLEMENTED'
}
$acceptedSuiteGates=if($NoArtifactOpenDesignGateAudit){
    @(
        'BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT',
        'BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_IMPLEMENTATION_AUTHORIZATION',
        'BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_DESIGN_AUDIT',
        'BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION',
        'BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT',
        'BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION',
        'BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT',
        'BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT',
        'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED',
        'BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
    )
}else{
    @('BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION','BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT','BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION','BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT','BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT','BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED','BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT')
}
$acceptedSuiteMetadataStatuses=if($NoArtifactOpenDesignGateAudit){
    @(
        'DESIGN_GATED_NOT_IMPLEMENTED',
        'STATIC_METADATA_PARSER_IMPLEMENTATION_DESIGN_PENDING_AUDIT',
        'STATIC_METADATA_PARSER_IMPLEMENTATION_DESIGN_ACCEPTED',
        'STATIC_METADATA_PARSER_IMPLEMENTED_PENDING_AUDIT',
        'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY',
        'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT',
        'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED',
        'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_PENDING_AUDIT',
        'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED'
    )
}else{
    @('STATIC_METADATA_PARSER_IMPLEMENTATION_DESIGN_ACCEPTED','STATIC_METADATA_PARSER_IMPLEMENTED_PENDING_AUDIT','STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY','STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT','STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED','STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_PENDING_AUDIT','STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED')
}
if($suite.framework_status-ne'PASS'-or$suite.live_installation_readiness-ne'BLOCKED'-or$suite.current_gate-notin$acceptedSuiteGates-or$suite.capability_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or$suite.live_adapter_status-ne'SCAFFOLD_NON_EXECUTING'-or$suite.live_binding_authorized-ne$false-or$suite.source_audit_result-ne'AUDIT PASS'-or$suite.compile_only_validation_authorized-ne$true-or$suite.compile_only_validation_performed-ne$true-or$suite.native_compilation_performed-ne$true-or$suite.native_loading_performed-ne$false-or$suite.native_invocation_performed-ne$false-or-not$suiteNativeExecutionAccepted-or$suite.compiled_artifact_metadata_review_status-notin$acceptedSuiteMetadataStatuses-or$suite.compiled_artifact_metadata_review_authorized-ne$false-or$suite.compiled_artifact_metadata_review_performed-ne$false-or$suite.compiled_artifact_bytes_opened-ne$false-or$suite.compiled_artifact_reflection_performed-ne$false-or$suite.compiled_artifact_execution_performed-ne$false){throw 'Suite result is not a non-executing static-metadata-parser design gate with native execution still blocked.'}

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
$canonicalManifestPath='docs/evidence/runtime-bringup-readiness-manifest.json'
$paths=@($paths|Where-Object{
    if(-not$_){return $false}
    $normalized=$_.Replace('\','/')
    return $normalized-ne$normalizedOutputPath-and$normalized-ne$canonicalManifestPath
}|Sort-Object -Unique)
$entries=[Collections.Generic.List[object]]::new()
foreach($path in $paths){$entries.Add((New-Entry ('tracked-'+(($path.ToLowerInvariant()-replace'[^a-z0-9]+','-').Trim('-'))) $path tracked VALIDATED))}
$suiteRelative=[IO.Path]::GetFullPath($SuiteResultPath).Substring($root.Length+1).Replace('\','/')
$entries.Add((New-Entry evidence-synthetic-suite $suiteRelative ignored PASS))
$parserEvidenceRelative=[IO.Path]::GetFullPath($ParserEvidencePath).Substring($root.Length+1).Replace('\','/')
$entries.Add((New-Entry evidence-static-metadata-parser-synthetic-validation $parserEvidenceRelative ignored PASS))
$parserEvidence=Get-Content -LiteralPath ([IO.Path]::GetFullPath($ParserEvidencePath)) -Raw|ConvertFrom-Json
if($parserEvidence.schema_version-ne'chatpad-static-metadata-parser-synthetic-validation-v1'-or$parserEvidence.result-ne'PASS'-or$parserEvidence.parser_schema_version-ne'chatpad-static-metadata-parser-evidence-v1'-or$parserEvidence.parser_execution_scope-ne'SYNTHETIC_FIXTURES_AND_REAL_ARTIFACT_PREFLIGHT_ONLY'-or$parserEvidence.allowed_input_scope-ne'SYNTHETIC_FIXTURES_ONLY_AND_MANIFEST_AUTHORIZED_REAL_ARTIFACT_PREFLIGHT'-or$parserEvidence.allowed_expected_scope-ne'SYNTHETIC_FIXTURES_ONLY_OR_REAL_ARTIFACT_REVIEW_EVIDENCE_ROOT'-or$parserEvidence.allowed_output_scope-ne'PARSER_EVIDENCE_ROOTS_ONLY_OR_REAL_ARTIFACT_REVIEW_EVIDENCE_ROOT'-or$parserEvidence.real_artifact_path_gate_status-ne'STATUS_BOUNDARY_PENDING_AUDIT'-or$parserEvidence.all_file_bearing_options_centrally_scoped-ne$true-or$parserEvidence.expected_path_gate_status-ne'IMPLEMENTED_PENDING_AUDIT'-or$parserEvidence.output_path_gate_status-ne'IMPLEMENTED_PENDING_AUDIT'-or$parserEvidence.preflight_rejection_output_suppression-ne'IMPLEMENTED_PENDING_AUDIT'-or$parserEvidence.rejection_evidence_transport-ne'TEST_HARNESS_FROM_CONSOLE_DIAGNOSTIC'-or$parserEvidence.pre_io_rejection_tests-ne'PASS'-or$parserEvidence.pre_read_rejection_tests-ne'PASS'-or$parserEvidence.safety_policy_mode-ne'IMMUTABLE_STATIC_ONLY'-or$parserEvidence.safety_policy_enforced-ne$true-or[int]$parserEvidence.real_artifact_preflight_only_count-ne17-or[int]$parserEvidence.failed_real_artifact_preflight_only_count-ne0-or[int]$parserEvidence.authorization_manifest_malformed_case_count-ne14-or[int]$parserEvidence.failed_authorization_manifest_malformed_case_count-ne0-or$parserEvidence.original_stop_condition_reproduction.result-ne'PASS'-or$parserEvidence.real_compile_only_artifact_opened-ne$false-or$parserEvidence.real_compile_only_artifact_parsed-ne$false-or$parserEvidence.real_compile_only_artifact_hash_computed-ne$false-or$parserEvidence.real_compile_only_artifact_write_attempted-ne$false-or$parserEvidence.real_compile_only_artifact_write_completed-ne$false-or$parserEvidence.metadata_review_performed-ne$false){
    throw 'Parser synthetic-fixture evidence is not a passing no-real-artifact parser implementation validation record.'
}
$parserEvidenceIdentity=Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path ([IO.Path]::GetFullPath($ParserEvidencePath)) -HashPolicy auto -CommitRepresented $ImplementationCommit -State ignored
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
    real_artifact_static_metadata_review_completed=$true
    framework_status='PASS'
    live_installation_readiness='BLOCKED'
    current_gate='BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
    capability_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
    native_execution_status='NOT_IMPLEMENTED'
    manifest_generation_mode=if($NoArtifactOpenDesignGateAudit){'NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT'}else{'STANDARD_READINESS_RESULT'}
    live_adapter_status='SCAFFOLD_NON_EXECUTING'
    live_binding_authorized=$false
    native_adapter_execution_design_gate=[pscustomobject][ordered]@{
        schema_version='chatpad-native-adapter-execution-design-gate-v1'
        status='NATIVE_ADAPTER_EXECUTION_DESIGN_DEFINED_PENDING_INDEPENDENT_AUDIT'
        current_gate='BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
        opened_from_commit='cb80939a862d33efb1abf26a14d5c75d43a77b30'
        design_document_path='docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md'
        implementation_status='NOT_IMPLEMENTED'
        execution_authorized=$false
        independent_audit_required=$true
        live_installation_readiness='BLOCKED'
        capability_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        static_metadata_lane_status='ACCEPTED_CLOSED'
        supported_operations=@('Apply','Restore','Restart')
        native_api_families=@('SetupAPI','Newdev')
        required_evidence=@(
            'EXACT_INSTANCE_BINDING',
            'APPROVED_DEVICE_INSTANCE_IDENTITY',
            'APPROVED_ARTIFACT_IDENTITY',
            'APPROVED_ROLLBACK_RECOVERY_PLAN'
        )
        required_future_authorizations=@(
            'NATIVE_ADAPTER_IMPLEMENTATION',
            'WINDOWS_MUTATION',
            'DRIVER_PACKAGE_SIGNING_STAGING_WHEN_APPLICABLE',
            'LIVE_EXECUTION'
        )
        safety_counters=[pscustomobject][ordered]@{
            native_library_load_attempts=0
            entry_point_resolution_attempts=0
            setupapi_newdev_invocation_attempts=0
            device_query_attempts=0
            windows_mutation_attempts=0
            driver_action_attempts=0
            authorization_rejections=0
            uncertain_state_events=0
        }
    }
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
        status='STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED'
        native_execution_status='NOT_IMPLEMENTED'
        current_gate='BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
        real_artifact_review_authorization_transition_commit='baab23aece902cbb06e11a308d9092fdc0f9ce0d'
        runtime_blocker='BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        status_boundary_audit_acceptance=[pscustomobject][ordered]@{
            verdict='AUDIT PASS'
            accepted_audit_target='83eb4acf44d50d8c43a09f7827728763e726e9c2'
            initial_git_status_empty=$true
            final_git_status_empty=$true
            evidence_inventory_path='artifacts/logs/real-artifact-static-metadata-review/evidence-inventory.json'
            evidence_inventory_self_reference_policy='excluded_from_authoritative_size_hash'
            evidence_inventory_physical_file_count=16
            evidence_inventory_authoritative_file_count=15
            evidence_inventory_authoritative_validation='15/15'
            evidence_inventory_self_entry_authoritative=$false
            evidence_inventory_preflight_subtree_file_count=14
            review_evidence_path='artifacts/logs/real-artifact-static-metadata-review/static-metadata-parser-real-artifact-review.json'
            review_evidence_sha256='024693B23AA26C42CD2F9D5AB995956CEB202A76FBA5481264EF828AAEDF0875'
            review_evidence_result='STATIC_METADATA_VALIDATED'
            approved_real_artifact_path='artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll'
            approved_real_artifact_sha256='77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'
            parser_source_net_change_from_eedf2a5='NONE'
            premature_transition_from_6372adf_reverted=$true
            parser_rerun_occurred=$false
            real_dll_access_occurred=$false
            runtime_native_device_windows_driver_actions_occurred=$false
            static_metadata_lane_closed=$true
        }
        authorization_plumbing_audit=[pscustomobject][ordered]@{
            verdict='AUDIT PASS'
            accepted_remediation_commit='dca0a9d794b4442de86d53a90e4aab74dfe68971'
            base_commit='2d7a721ce3172b338df0de56853a256b1170fb4a'
            audit_summary_path='artifacts/logs/independent-static-parser-auth-plumbing-audit-root-remediation-audit-dca0a9d/audit-summary.json'
            audit_summary_byte_size=2666
            audit_summary_sha256='FAB4EC641663902C779A65721EED1C481F7CD0FF5410E0E38D23B43A475403A5'
            audit_inventory_path='artifacts/logs/independent-static-parser-auth-plumbing-audit-root-remediation-audit-dca0a9d/evidence-inventory.json'
            audit_inventory_byte_size=7462
            audit_inventory_sha256='DF6FB3F45689D231F77E4C53B18E0B7B5D099B93BC90F8847460DB5033E2761F'
            accepted=$true
        }
        compile_only_evidence_remediation_accepted=$true
        artifact_location_classification='IGNORED_COMPILE_ONLY_OUTPUT'
        proposed_inspection_mode='STATIC_BYTE_AND_METADATA_PARSING_ONLY'
        implementation_authorized=$false
        independent_design_audit_required=$false
        independent_design_audit_verdict='AUDIT PASS'
        independent_design_audit_branch='feature/runtime-bringup-compiled-artifact-metadata-review-design-gate-remediation'
        independent_design_audit_commit='49b41dad087a3d7e6f4db7f52cd51a0c17eed222'
        independent_design_audit_artifact_inventory_path='artifacts/logs/independent-metadata-review-design-gate-remediation-audit-49b41da/artifact-inventory.json'
        independent_design_audit_artifact_inventory_byte_size=22305
        independent_design_audit_artifact_inventory_sha256='2EED833A5CF5948126A766FFAAA87FD267E548DD32B2237E1DA5644BF7355A3B'
        static_metadata_parser_implementation_design=[pscustomobject][ordered]@{
            status='DESIGN_AUDIT_ACCEPTED_PENDING_IMPLEMENTATION_AUTHORIZATION'
            current_gate='BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
            real_artifact_review_authorization_transition_commit='baab23aece902cbb06e11a308d9092fdc0f9ce0d'
            transition_base_commit='382aa85980408939a93043583b48e942ebfbf018'
            design_document_path='docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md'
            preferred_technology='SYSTEM_REFLECTION_METADATA_PEREADER'
            target_framework='net9.0'
            independent_design_audit_verdict='AUDIT PASS'
            independent_design_audit_branch='feature/runtime-bringup-static-metadata-parser-implementation-design'
            independent_design_audit_commit='468e8679388481e923a37a985055046f72480921'
            independent_design_audit_artifact_inventory_path='artifacts/logs/independent-static-metadata-parser-design-audit-468e867/artifact-inventory.json'
            independent_design_audit_artifact_inventory_byte_size=54161
            independent_design_audit_artifact_inventory_sha256='D43213A552CF61E793BABD2792D6B3329706EF9F2DB3DC46D401B66307725B6F'
            independent_design_audit_summary_path='artifacts/logs/independent-static-metadata-parser-design-audit-468e867/audit-summary.json'
            independent_design_audit_summary_byte_size=14996
            independent_design_audit_summary_sha256='A1A83F8C7A818B45D2A19A2C10C9206FE0C38CB8335485E17E2124BCEFCDB2C5'
            input_identity_source='REFERENCE_ONLY_ACCEPTED_COMPILE_ONLY_V2_EVIDENCE'
            referenced_primary_dll_sha256='77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'
            parser_implementation_status='STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED'
            parser_execution_status='STATIC_METADATA_VALIDATED'
            metadata_review_status='STATIC_METADATA_VALIDATED'
            artifact_opening_status='NOT_PERFORMED'
            artifact_parsing_status='NOT_PERFORMED'
            artifact_hash_verification_status='NOT_PERFORMED'
            artifact_write_status='NOT_PERFORMED'
            assembly_loading_status='NOT_PERFORMED'
            runtime_reflection_status='NOT_PERFORMED'
            compiled_artifact_execution_status='NOT_PERFORMED'
            native_invocation_status='NOT_PERFORMED'
            device_query_status='NOT_PERFORMED'
            windows_mutation_status='NOT_PERFORMED'
            driver_actions_status='NOT_PERFORMED'
        }
        static_metadata_parser_implementation=[pscustomobject][ordered]@{
            status='ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED'
            current_gate='BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
            real_artifact_review_authorization_transition_commit='baab23aece902cbb06e11a308d9092fdc0f9ce0d'
            independent_implementation_audit_verdict='AUDIT PASS'
            independent_implementation_audit_branch='feature/runtime-bringup-static-metadata-parser-preflight-output-remediation'
            independent_implementation_audit_commit='f0be4746ad4cc548334336c1e66f07007b71859f'
            independent_implementation_audit_summary_path='artifacts/logs/independent-static-metadata-parser-preflight-output-audit-f0be474/audit-summary.json'
            independent_implementation_audit_summary_byte_size=5706
            independent_implementation_audit_summary_sha256='E28834B3B307DE1782CEF1C2E0F9BCD497BD1A856A1AB745DA5E6D4060F5279A'
            independent_implementation_audit_artifact_inventory_path='artifacts/logs/independent-static-metadata-parser-preflight-output-audit-f0be474/artifact-inventory.json'
            independent_implementation_audit_artifact_inventory_byte_size=5553
            independent_implementation_audit_artifact_inventory_sha256='2F0BEF0D246F6F52F2090E4214EA284B6D4321E8B2E5BADF91842B7AF26E603B'
            parser_tool_name='Chatpad.StaticMetadataParser'
            parser_project_path='tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj'
            parser_source_path='tools/StaticMetadataParser/Program.cs'
            parser_evidence_schema_path='docs/evidence/static-metadata-parser-evidence-schema-v1.md'
            parser_synthetic_validation_path=$parserEvidenceRelative
            parser_synthetic_validation_byte_size=[long]$parserEvidenceIdentity.canonical_byte_size
            parser_synthetic_validation_sha256=$parserEvidenceIdentity.canonical_sha256
            parser_evidence_schema_version='chatpad-static-metadata-parser-evidence-v1'
            synthetic_fixture_count=[int]$parserEvidence.fixture_count
            synthetic_assertion_count=[int]$parserEvidence.assertion_count
            failed_fixture_count=[int]$parserEvidence.failed_fixture_count
            real_artifact_path_gate_status='STATUS_BOUNDARY_ACCEPTED'
            all_file_bearing_options_centrally_scoped=[bool]$parserEvidence.all_file_bearing_options_centrally_scoped
            expected_path_gate_status='ACCEPTED_STATIC_ONLY'
            output_path_gate_status='ACCEPTED_STATIC_ONLY'
            preflight_rejection_output_suppression='ACCEPTED_STATIC_ONLY'
            rejection_evidence_transport=[string]$parserEvidence.rejection_evidence_transport
            approved_parser_evidence_root_validation='ACCEPTED_STATIC_ONLY'
            allowed_input_scope=[string]$parserEvidence.allowed_input_scope
            allowed_expected_scope=[string]$parserEvidence.allowed_expected_scope
            allowed_output_scope=[string]$parserEvidence.allowed_output_scope
            pre_io_rejection_tests=[string]$parserEvidence.pre_io_rejection_tests
            pre_read_rejection_tests=[string]$parserEvidence.pre_read_rejection_tests
            real_artifact_like_rejection_count=[int]$parserEvidence.real_artifact_like_rejection_count
            real_artifact_like_rejection_not_run_count=[int]$parserEvidence.real_artifact_like_rejection_not_run_count
            failed_real_artifact_like_rejection_count=[int]$parserEvidence.failed_real_artifact_like_rejection_count
            expected_path_rejection_count=[int]$parserEvidence.expected_path_rejection_count
            failed_expected_path_rejection_count=[int]$parserEvidence.failed_expected_path_rejection_count
            output_path_rejection_count=[int]$parserEvidence.output_path_rejection_count
            failed_output_path_rejection_count=[int]$parserEvidence.failed_output_path_rejection_count
            safety_policy_mode=[string]$parserEvidence.safety_policy_mode
            safety_policy_enforced=[bool]$parserEvidence.safety_policy_enforced
            safety_option_rejection_count=[int]$parserEvidence.safety_option_rejection_count
            failed_safety_option_rejection_count=[int]$parserEvidence.failed_safety_option_rejection_count
            real_artifact_preflight_only_count=[int]$parserEvidence.real_artifact_preflight_only_count
            failed_real_artifact_preflight_only_count=[int]$parserEvidence.failed_real_artifact_preflight_only_count
            authorization_manifest_malformed_case_count=[int]$parserEvidence.authorization_manifest_malformed_case_count
            failed_authorization_manifest_malformed_case_count=[int]$parserEvidence.failed_authorization_manifest_malformed_case_count
            original_stop_condition_reproduction_result=[string]$parserEvidence.original_stop_condition_reproduction.result
            parser_execution_status='STATIC_METADATA_VALIDATED'
            metadata_review_status='STATIC_METADATA_VALIDATED'
            real_artifact_open_parse_hash_write_status='PERFORMED'
            real_compile_only_artifact_opened=$true
            real_compile_only_artifact_parsed=$true
            real_compile_only_artifact_hash_computed=$true
            real_compile_only_artifact_write_attempted=$false
            real_compile_only_artifact_write_completed=$false
            real_artifact_review_completed=$true
            static_metadata_review_result='STATIC_METADATA_VALIDATED'
            assembly_loading_occurred=$false
            runtime_reflection_occurred=$false
            compiled_artifact_execution_occurred=$false
            native_invocation_occurred=$false
            device_query_occurred=$false
            windows_mutation_occurred=$false
            driver_actions_occurred=$false
        }
        artifact_opening_authorized=$false
        artifact_bytes_opened=$false
        artifact_parsing_authorized=$false
        artifact_parsing_performed=$false
        artifact_writing_authorized=$false
        artifact_writing_occurred=$false
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
        setupapi_newdev_invocation_authorized=$false
        setupapi_newdev_invocation_occurred=$false
        device_query_authorized=$false
        device_query_occurred=$false
        hardware_access_authorized=$false
        hardware_access_occurred=$false
        windows_mutation_authorized=$false
        windows_mutation_occurred=$false
        registry_mutation_authorized=$false
        registry_mutation_occurred=$false
        service_mutation_authorized=$false
        service_mutation_occurred=$false
        certificate_mutation_authorized=$false
        certificate_mutation_occurred=$false
        key_mutation_authorized=$false
        key_mutation_occurred=$false
        credential_mutation_authorized=$false
        credential_mutation_occurred=$false
        driver_actions_authorized=$false
        driver_actions_occurred=$false
        driver_build_authorized=$false
        driver_build_occurred=$false
        driver_link_authorized=$false
        driver_link_occurred=$false
        driver_sign_authorized=$false
        driver_sign_occurred=$false
        driver_cat_generation_authorized=$false
        driver_cat_generation_occurred=$false
        driver_package_authorized=$false
        driver_package_occurred=$false
        driver_stage_authorized=$false
        driver_stage_occurred=$false
        driver_install_authorized=$false
        driver_install_occurred=$false
        driver_load_authorized=$false
        driver_load_occurred=$false
        driver_unload_authorized=$false
        driver_unload_occurred=$false
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
