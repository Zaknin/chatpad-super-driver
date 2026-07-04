Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'NativeInterop\ChatpadNativeInteropSourceBoundary.psm1') -Force
$script:NativeCompileOnlyEvidenceCache = $null

function Get-NativeScaffoldConstants {
    [pscustomobject][ordered]@{
        design_schema = 'chatpad-native-adapter-design-gate-v2'
        adapter_contract_schema = 'chatpad-native-adapter-contract-v1'
        composition_schema = 'chatpad-native-adapter-composition-root-v1'
        operation_evidence_schema = 'chatpad-native-adapter-operation-evidence-v1'
        production_adapter_id = 'chatpad-windows-exact-instance-adapter-v1'
        synthetic_adapter_id = 'chatpad-fake-exact-instance-adapter-v1'
        execution_blocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        prior_compile_only_gate = 'BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED'
        compile_only_evidence_gate = 'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT'
        scaffold_gate = 'BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT'
        source_audit_result = 'AUDIT PASS'
        source_audit_branch = 'feature/runtime-bringup-native-interop-source-boundary'
        source_audit_commit = 'dbba70d74e99c211d47187697e19e528b381520a'
        source_audit_artifact_directory = 'artifacts/logs/independent-native-interop-source-audit-dbba70d/'
        source_audit_artifact_inventory = 'artifact-inventory.json'
        source_audit_artifact_inventory_sha256 = '198124D0949A9DD987CD154A09D0DC55DDFEB79C6A2E63839E8FB19BD2202967'
        supported_operations = @('Apply', 'Restore', 'Restart')
    }
}

function Get-NativeCompileOnlyValidationEvidencePath {
    param([string]$RepositoryRoot = '')
    if (-not $RepositoryRoot) {
        $RepositoryRoot = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    }
    Join-Path $RepositoryRoot 'docs\evidence\native-interop-compile-only-validation.json'
}

function Get-AuthorizedNativeCompileOnlyHarnessProjectPath {
    'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj'
}

function ConvertTo-AuthorizedNativeSourceBoundaryResult {
    param([Parameter(Mandatory)][object]$SourceBoundary)

    $compileOnlyHarnessProject = Get-AuthorizedNativeCompileOnlyHarnessProjectPath
    $defects = @($SourceBoundary.defects | Where-Object {
        -not ([string]$_.id -eq 'declaration-referenced-by-build-file' -and [string]$_.path -eq $compileOnlyHarnessProject)
    })

    [pscustomobject][ordered]@{
        result = if ($defects.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($defects.Count) { 'NATIVE_INTEROP_SOURCE_BOUNDARY_INVALID' } else { 'NATIVE_INTEROP_SOURCE_BOUNDARY_VALID' }
        declaration_relative_path = $SourceBoundary.declaration_relative_path
        declaration_sha256 = $SourceBoundary.declaration_sha256
        declared_api_count = $SourceBoundary.declared_api_count
        declared_structure_count = $SourceBoundary.declared_structure_count
        dllimport_count = $SourceBoundary.dllimport_count
        build_reference_file_count = $SourceBoundary.build_reference_file_count
        authorized_compile_only_build_references = @($compileOnlyHarnessProject)
        native_interop_binary_count = $SourceBoundary.native_interop_binary_count
        defects = @($defects)
    }
}

function Test-ChatpadNativeInteropSourceBoundary {
    param([string]$RepositoryRoot = '')
    if (-not $RepositoryRoot) {
        $RepositoryRoot = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    }
    ConvertTo-AuthorizedNativeSourceBoundaryResult -SourceBoundary (
        ChatpadNativeInteropSourceBoundary\Test-ChatpadNativeInteropSourceBoundary -RepositoryRoot $RepositoryRoot
    )
}

function Read-NativeCompileOnlyValidationEvidence {
    param([string]$EvidencePath = '')
    if (-not $EvidencePath) {
        $EvidencePath = Get-NativeCompileOnlyValidationEvidencePath
    }
    Get-Content -LiteralPath $EvidencePath -Raw | ConvertFrom-Json
}

function Get-NativeCanonicalTextIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $rawBytes=[IO.File]::ReadAllBytes($Path)
    $text=[Text.UTF8Encoding]::new($false,$true).GetString($rawBytes)
    if($text.Length -gt 0-and$text[0]-eq[char]0xFEFF){$text=$text.Substring(1)}
    $canonicalBytes=[Text.UTF8Encoding]::new($false).GetBytes($text.Replace("`r`n","`n").Replace("`r","`n"))
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$hash=(($sha.ComputeHash($canonicalBytes)|ForEach-Object{$_.ToString('X2')})-join'')}finally{$sha.Dispose()}
    [pscustomobject]@{canonical_sha256=$hash;canonical_byte_size=[long]$canonicalBytes.Length}
}

function Test-ChatpadNativeInteropCompileOnlyValidationEvidence {
    [CmdletBinding(PositionalBinding = $false)]
    param([string]$EvidencePath = '')

    $constants = Get-NativeScaffoldConstants
    $defects = [Collections.Generic.List[object]]::new()
    $root = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    if (-not $EvidencePath) {
        $EvidencePath = Get-NativeCompileOnlyValidationEvidencePath -RepositoryRoot $root
    }
    $fullEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
    $isDefaultEvidence = [string]::Equals($fullEvidencePath, [IO.Path]::GetFullPath((Get-NativeCompileOnlyValidationEvidencePath -RepositoryRoot $root)), [StringComparison]::OrdinalIgnoreCase)
    if ($isDefaultEvidence -and (Test-Path -LiteralPath $fullEvidencePath -PathType Leaf)) {
        $evidenceHashForCache = (Get-FileHash -LiteralPath $fullEvidencePath -Algorithm SHA256).Hash
        if ($script:NativeCompileOnlyEvidenceCache -and
            $script:NativeCompileOnlyEvidenceCache.path -eq $fullEvidencePath -and
            $script:NativeCompileOnlyEvidenceCache.hash -eq $evidenceHashForCache) {
            return $script:NativeCompileOnlyEvidenceCache.result
        }
    }
    if (-not $fullEvidencePath.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $defects.Add([pscustomobject][ordered]@{ id = 'evidence-path-outside-repository'; value = $EvidencePath })
    }
    if (-not (Test-Path -LiteralPath $fullEvidencePath -PathType Leaf)) {
        $defects.Add([pscustomobject][ordered]@{ id = 'compile-evidence-missing'; value = $EvidencePath })
        return [pscustomobject][ordered]@{
            result = 'FAIL'
            result_code = 'NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_INVALID'
            defect_count = $defects.Count
            defects = @($defects)
            evidence_path = $EvidencePath
            evidence = $null
        }
    }
    try {
        $evidence = Get-Content -LiteralPath $fullEvidencePath -Raw | ConvertFrom-Json
    } catch {
        $defects.Add([pscustomobject][ordered]@{ id = 'compile-evidence-json-invalid'; value = $_.Exception.Message })
        $evidence = $null
    }
    if ($null -eq $evidence) {
        return [pscustomobject][ordered]@{
            result = 'FAIL'
            result_code = 'NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_INVALID'
            defect_count = $defects.Count
            defects = @($defects)
            evidence_path = $EvidencePath
            evidence = $null
        }
    }

    if ([string]$evidence.schema_version -ne 'chatpad-native-interop-compile-only-validation-v2') { $defects.Add([pscustomobject][ordered]@{ id = 'schema-version-invalid'; value = [string]$evidence.schema_version }) }
    if ([string]$evidence.build_result.result -ne 'PASS' -or [int]$evidence.build_result.compiler_exit_code -ne 0 -or [int]$evidence.build_result.warning_count -ne 0 -or [int]$evidence.build_result.error_count -ne 0) {
        $defects.Add([pscustomobject][ordered]@{ id = 'compile-result-not-clean-pass'; value = $evidence.build_result })
    }
    if ([string]$evidence.readiness_transition.previous_gate -ne $constants.prior_compile_only_gate -or [string]$evidence.readiness_transition.resulting_readiness_gate -ne $constants.compile_only_evidence_gate -or [string]$evidence.readiness_transition.remaining_blocker -ne $constants.execution_blocker -or [bool]$evidence.readiness_transition.transition_allowed -ne $true) {
        $defects.Add([pscustomobject][ordered]@{ id = 'gate-transition-invalid'; value = $evidence.readiness_transition })
    }
    if ([string]$evidence.scope.harness_project_path -ne 'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj' -or [string]$evidence.scope.target_framework -ne 'net9.0-windows10.0.26100.0' -or [string]$evidence.scope.platform -ne 'x64' -or [string]$evidence.scope.output_type -ne 'Library' -or [bool]$evidence.scope.warnings_as_errors -ne $true -or [string]$evidence.scope.nullable -ne 'enable') {
        $defects.Add([pscustomobject][ordered]@{ id = 'harness-scope-invalid'; value = $evidence.scope })
    }
    if ([bool]$evidence.msbuild_graph.inspected_before_build -ne $true -or [int]$evidence.msbuild_graph.project_forbidden_pattern_count -ne 0 -or [int]$evidence.msbuild_graph.preprocessed_forbidden_pattern_count -ne 0 -or [bool]$evidence.msbuild_graph.test_project_detected -ne $false -or [bool]$evidence.msbuild_graph.executable_entry_point_declared -ne $false) {
        $defects.Add([pscustomobject][ordered]@{ id = 'msbuild-graph-inspection-invalid'; value = $evidence.msbuild_graph })
    }
    $identityPolicy=if($null-ne$evidence.PSObject.Properties['identity_policy']){$evidence.identity_policy}else{$null}
    if($null-eq$identityPolicy-or
        [string]$identityPolicy.schema_version-ne'chatpad-evidence-file-identity-policy-v1'-or
        [string]$identityPolicy.tracked_text_input_policy-ne'canonical_lf_text'-or
        [string]$identityPolicy.compile_output_policy-ne'raw_file_bytes'-or
        @($identityPolicy.supported_hash_policies)-notcontains'git_blob_bytes'-or
        @($identityPolicy.supported_hash_policies)-notcontains'canonical_lf_text'-or
        @($identityPolicy.supported_hash_policies)-notcontains'raw_file_bytes'){
        $defects.Add([pscustomobject][ordered]@{id='identity-policy-invalid';value=$identityPolicy})
    }

    $requiredInputHashes = @{
        'tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs' = '127EA58993862CCE865E3D73B0F1A99513932ABDF1BEA615812966EB5C14BEAA'
        'tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1' = '3E7E3119A467330A413280658503B294C0FFB38271A9CA847056BAF6B2E778D3'
        'tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj' = ''
        'tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs' = ''
        'tools/ExactInstance/CompileOnlyValidation/Directory.Build.props' = ''
    }
    $inputFiles = @($evidence.input_files)
    $inputPaths = @($inputFiles | ForEach-Object { [string]$_.relative_path })
    if ($inputFiles.Count -ne $requiredInputHashes.Count -or @($inputPaths | Group-Object | Where-Object Count -gt 1).Count) {
        $defects.Add([pscustomobject][ordered]@{ id = 'input-file-set-invalid'; value = $inputPaths })
    }
    foreach ($requiredPath in $requiredInputHashes.Keys) {
        $records = @($inputFiles | Where-Object { [string]$_.relative_path -eq $requiredPath })
        if ($records.Count -ne 1) {
            $defects.Add([pscustomobject][ordered]@{ id = 'input-file-missing-or-duplicate'; value = $requiredPath })
            continue
        }
        $full = [IO.Path]::GetFullPath((Join-Path $root $requiredPath))
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $defects.Add([pscustomobject][ordered]@{ id = 'input-file-not-found'; value = $requiredPath })
            continue
        }
        $record=$records[0]
        if($null-eq$record.PSObject.Properties['hash_policy']-or[string]$record.hash_policy-ne'canonical_lf_text'){
            $defects.Add([pscustomobject][ordered]@{id='input-file-hash-policy-invalid';value=$requiredPath})
            continue
        }
        if($null-eq$record.PSObject.Properties['content_classification']-or$null-eq$record.PSObject.Properties['tracked']-or$null-eq$record.PSObject.Properties['line_ending_policy']-or[string]$record.content_classification-ne'text'-or[bool]$record.tracked-ne$true-or[string]$record.line_ending_policy-ne'utf8_no_bom_lf'){
            $defects.Add([pscustomobject][ordered]@{id='input-file-classification-invalid';value=$requiredPath})
        }
        if($null-eq$record.PSObject.Properties['commit_represented']-or[string]$record.commit_represented-notmatch'^[0-9a-f]{40}$'){
            $defects.Add([pscustomobject][ordered]@{id='input-file-commit-invalid';value=$requiredPath})
            continue
        }
        $actualIdentity=Get-NativeCanonicalTextIdentity -Path $full
        $actualHash=$actualIdentity.canonical_sha256
        if($null-eq$record.PSObject.Properties['canonical_sha256']-or$null-eq$record.PSObject.Properties['canonical_byte_size']-or[string]$record.canonical_sha256-cne$actualHash-or[long]$record.canonical_byte_size-ne[long]$actualIdentity.canonical_byte_size){
            $defects.Add([pscustomobject][ordered]@{id='input-file-canonical-identity-mismatch';value=$requiredPath})
        }
        if($null-eq$record.PSObject.Properties['sha256']-or$null-eq$record.PSObject.Properties['byte_size']-or[string]$record.sha256-cne[string]$record.canonical_sha256-or[long]$record.byte_size-ne[long]$record.canonical_byte_size){
            $defects.Add([pscustomobject][ordered]@{id='input-file-identity-alias-mismatch';value=$requiredPath})
        }
        if($null-eq$record.PSObject.Properties['raw_working_tree_sha256']-or$null-eq$record.PSObject.Properties['raw_working_tree_byte_size']-or[string]$record.raw_working_tree_sha256-notmatch'^[A-F0-9]{64}$'-or[long]$record.raw_working_tree_byte_size-lt0-or$null-eq$record.PSObject.Properties['raw_and_canonical_differ']){
            $defects.Add([pscustomobject][ordered]@{id='input-file-raw-identity-invalid';value=$requiredPath})
        }
        $expectedHash = $requiredInputHashes[$requiredPath]
        if ($expectedHash -and $actualHash -cne $expectedHash) {
            $defects.Add([pscustomobject][ordered]@{ id = 'audited-input-hash-mismatch'; value = $requiredPath })
        }
    }
    if ([bool]$evidence.expected_native_source_hashes.matched_before_compile -ne $true -or [bool]$evidence.expected_native_source_hashes.matched_after_compile -ne $true) {
        $defects.Add([pscustomobject][ordered]@{ id = 'audited-source-hash-prepost-invalid'; value = $evidence.expected_native_source_hashes })
    }

    $prohibited = $evidence.prohibited_actions
    foreach ($name in @('assemblyLoaded','managedCodeExecuted','nativeInvocationOccurred','deviceQueryOccurred','exactInstanceAccessed','windowsMutationOccurred','producedAssemblyExecuted','testHostExecuted','reflectionInspectionUsed','postBuildExecutionOccurred')) {
        if ($null -eq $prohibited.PSObject.Properties[$name] -or [bool]$prohibited.$name -ne $false) {
            $defects.Add([pscustomobject][ordered]@{ id = 'prohibited-action-claim-invalid'; value = $name })
        }
    }
    if (-not $evidence.toolchain.PSObject.Properties['dotnet_info_path'] -or -not $evidence.toolchain.PSObject.Properties['msbuild_version_path'] -or -not $evidence.toolchain.PSObject.Properties['roslyn_version'] -or [string]::IsNullOrWhiteSpace([string]$evidence.toolchain.os_architecture)) {
        $defects.Add([pscustomobject][ordered]@{ id = 'toolchain-identity-incomplete'; value = $evidence.toolchain })
    }
    $commandLines = @($evidence.commands_executed | ForEach-Object { [string]$_.command_line })
    if (@($commandLines | Where-Object { $_ -match '\bdotnet\s+(test|run)\b|vstest|Add-Type|Assembly\.Load' }).Count) {
        $defects.Add([pscustomobject][ordered]@{ id = 'prohibited-command-recorded'; value = $commandLines })
    }
    if (@($commandLines | Where-Object { $_ -match '/t:Restore,Build' }).Count -ne 1) {
        $defects.Add([pscustomobject][ordered]@{ id = 'compile-command-missing'; value = $commandLines })
    }

    $producedFiles = @($evidence.build_result.produced_files)
    if ([int]$evidence.build_result.produced_file_count -ne $producedFiles.Count -or $producedFiles.Count -lt 1) {
        $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-count-invalid'; value = $evidence.build_result.produced_file_count })
    }
    $declaredOutputRoot=[IO.Path]::GetFullPath((Join-Path $root ([string]$evidence.scope.output_artifact_root)))
    $allowedArtifactRoot=[IO.Path]::GetFullPath((Join-Path $root 'artifacts'))
    if(-not$declaredOutputRoot.StartsWith($allowedArtifactRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not @(&git -C $root check-ignore -- $declaredOutputRoot 2>$null).Count){
        $defects.Add([pscustomobject][ordered]@{id='output-root-invalid';value=$evidence.scope.output_artifact_root})
    }
    foreach ($file in $producedFiles) {
        $relative = [string]$file.relative_path
        $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $full.StartsWith($declaredOutputRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-outside-isolated-artifacts'; value = $relative })
            continue
        }
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-missing'; value = $relative })
            continue
        }
        $item = Get-Item -LiteralPath $full
        $rawHash=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
        if($null-eq$file.PSObject.Properties['hash_policy']-or$null-eq$file.PSObject.Properties['content_classification']-or$null-eq$file.PSObject.Properties['ignored']-or[string]$file.hash_policy-ne'raw_file_bytes'-or[string]$file.content_classification-ne'compile-output-artifact'-or[bool]$file.ignored-ne$true){
            $defects.Add([pscustomobject][ordered]@{id='produced-file-policy-invalid';value=$relative})
        }
        if($null-eq$file.PSObject.Properties['byte_size']-or$null-eq$file.PSObject.Properties['sha256']-or$null-eq$file.PSObject.Properties['raw_file_byte_size']-or$null-eq$file.PSObject.Properties['raw_file_sha256']-or[long]$file.byte_size -ne [long]$item.Length -or [string]$file.sha256 -cne $rawHash -or [long]$file.raw_file_byte_size-ne[long]$item.Length-or[string]$file.raw_file_sha256-cne$rawHash) {
            $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-identity-mismatch'; value = $relative })
        }
        foreach($flag in @('assembly_loaded','reflection_inspection_used','managed_code_executed','native_api_invoked')){
            if($null-eq$file.PSObject.Properties[$flag]-or[bool]$file.$flag-ne$false){$defects.Add([pscustomobject][ordered]@{id='produced-file-prohibited-action-invalid';value="$relative::$flag"})}
        }
    }

    $resultRecord = [pscustomobject][ordered]@{
        result = if ($defects.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($defects.Count) { 'NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_INVALID' } else { 'NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_VALID' }
        defect_count = $defects.Count
        defects = @($defects)
        evidence_path = $EvidencePath
        evidence = $evidence
    }
    if ($isDefaultEvidence) {
        $script:NativeCompileOnlyEvidenceCache = [pscustomobject][ordered]@{
            path = $fullEvidencePath
            hash = (Get-FileHash -LiteralPath $fullEvidencePath -Algorithm SHA256).Hash
            result = $resultRecord
        }
    }
    $resultRecord
}

function Get-NativeSourceAuditAcceptanceRecord {
    $constants = Get-NativeScaffoldConstants
    [pscustomobject][ordered]@{
        verdict = $constants.source_audit_result
        audited_branch = $constants.source_audit_branch
        audited_commit = $constants.source_audit_commit
        audit_artifact_directory = $constants.source_audit_artifact_directory
        artifact_inventory = $constants.source_audit_artifact_inventory
        artifact_inventory_sha256 = $constants.source_audit_artifact_inventory_sha256
        strict_read_only = $true
        native_compilation_occurred = $false
        native_loading_occurred = $false
        native_invocation_occurred = $false
        device_query_occurred = $false
        windows_mutation_occurred = $false
        source_boundary_accepted = $true
        compile_only_validation_authorized = $false
        compile_only_validation_performed = $false
        structure_layout_cbsize_validated = $false
    }
}

function Add-NativeAuditAcceptanceFields {
    param([Parameter(Mandatory)][object]$Record)
    $constants = Get-NativeScaffoldConstants
    $audit = Get-NativeSourceAuditAcceptanceRecord
    $compileValidation = Test-ChatpadNativeInteropCompileOnlyValidationEvidence
    if ($Record.PSObject.Properties['current_gate']) {
        $Record.current_gate = $constants.scaffold_gate
    }
    foreach ($entry in @(
        @{ Name='source_audit_result'; Value=$constants.source_audit_result },
        @{ Name='source_audit_accepted'; Value=$true },
        @{ Name='source_audit_commit'; Value=$constants.source_audit_commit },
        @{ Name='compile_only_validation_authorized'; Value=$true },
        @{ Name='compile_only_validation_performed'; Value=($compileValidation.result -eq 'PASS') },
        @{ Name='native_compilation_performed'; Value=($compileValidation.result -eq 'PASS') },
        @{ Name='native_loading_performed'; Value=$false },
        @{ Name='native_invocation_performed'; Value=$false },
        @{ Name='structure_layout_cbsize_validated'; Value=($compileValidation.result -eq 'PASS') },
        @{ Name='source_audit'; Value=$audit },
        @{ Name='compile_only_validation'; Value=$compileValidation }
    )) {
        if ($Record.PSObject.Properties[$entry.Name]) {
            $Record.($entry.Name) = $entry.Value
        } else {
            $Record | Add-Member -NotePropertyName $entry.Name -NotePropertyValue $entry.Value
        }
    }
    $Record
}

function Get-ChatpadNativeInteropCallPlan {
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory)][ValidateSet('Apply','Restore','Restart')][string]$Operation)
    $plan = ChatpadNativeInteropSourceBoundary\Get-ChatpadNativeInteropCallPlan -Operation $Operation
    Add-NativeAuditAcceptanceFields -Record $plan
}

function Get-ChatpadNativeInteropSourceBoundaryContract {
    $contract = ChatpadNativeInteropSourceBoundary\Get-ChatpadNativeInteropSourceBoundaryContract
    [void](Add-NativeAuditAcceptanceFields -Record $contract)
    foreach ($plan in @($contract.call_plans)) {
        [void](Add-NativeAuditAcceptanceFields -Record $plan)
    }
    $contract
}

function ConvertTo-NativeIdentifierRecord {
    param([AllowNull()][object]$Value)

    if ([object]::ReferenceEquals($null, $Value)) {
        return [pscustomobject][ordered]@{ valid = $false; missing = $true; value = '' }
    }
    if ($Value -isnot [string]) {
        return [pscustomobject][ordered]@{ valid = $false; missing = $false; value = '' }
    }
    $normalized = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return [pscustomobject][ordered]@{ valid = $false; missing = $true; value = '' }
    }
    [pscustomobject][ordered]@{ valid = $true; missing = $false; value = $normalized }
}

function Get-ChatpadNativeSupportedOperationIdentifiers {
    @('Apply', 'Restore', 'Restart')
}

function New-ChatpadNativeZeroCounters {
    [pscustomobject][ordered]@{
        windows_mutations_performed = 0
        live_device_queries_performed = 0
        native_operations_performed = 0
        live_binding_authorized = $false
        live_restoration_authorized = $false
        live_restart_authorized = $false
    }
}

function New-ChatpadProductionNativeAdapter {
    $constants = Get-NativeScaffoldConstants
    $interop = Get-ChatpadNativeInteropSourceBoundaryContract
    [pscustomobject][ordered]@{
        schema_version = $constants.adapter_contract_schema
        adapter_identity = $constants.production_adapter_id
        adapter_implementation_kind = 'production-native-interop-source-boundary'
        adapter_mode = 'windows-native-nonexecuting'
        contract_version = '1'
        evidence_contract_version = $constants.operation_evidence_schema
        result_code_contract_version = 'chatpad-native-adapter-result-codes-v1'
        supported_operation_identifiers = @('Apply', 'Restore', 'Restart')
        execution_state = 'non-executing-scaffold'
        native_execution_status = 'NOT_IMPLEMENTED'
        live_execution_available = $false
        native_interop_implemented = $false
        native_source_declarations_present = [bool]$interop.native_source_declarations_present
        native_source_boundary_status = [string]$interop.source_boundary_status
        native_declaration_api_count = [int]$interop.declaration_inventory.api_count
        native_compilation_permitted = $false
        native_loading_permitted = $false
        native_invocation_permitted = $false
        native_compilation_performed = $true
        native_loading_performed = $false
        native_invocation_performed = $false
        source_audit_result = $constants.source_audit_result
        source_audit_accepted = $true
        source_audit_commit = $constants.source_audit_commit
        compile_only_validation_authorized = $true
        compile_only_validation_performed = $true
        structure_layout_cbsize_validated = $true
        compile_only_validation = Test-ChatpadNativeInteropCompileOnlyValidationEvidence
        device_queries_available = $false
        windows_mutation_available = $false
        future_elevation_required = $true
        synthetic = $false
        production = $true
        fail_closed = $true
        mutation_counter_fields = @('windows_mutations_performed')
        device_query_counter_fields = @('live_device_queries_performed')
        native_operation_counter_fields = @('native_operations_performed')
        current_gate = $constants.scaffold_gate
        capability_blocker = $constants.execution_blocker
        compatibility_capability_api_authorizes_mutation = $false
    }
}

function New-ChatpadSyntheticAdapterMetadata {
    $constants = Get-NativeScaffoldConstants
    [pscustomobject][ordered]@{
        schema_version = $constants.adapter_contract_schema
        adapter_identity = $constants.synthetic_adapter_id
        adapter_implementation_kind = 'offline-synthetic-test-adapter'
        adapter_mode = 'offline-fake'
        contract_version = '1'
        supported_operation_identifiers = @('Apply', 'Restore')
        execution_state = 'offline-synthetic-only'
        live_execution_available = $false
        native_interop_implemented = $false
        device_queries_available = $false
        windows_mutation_available = $false
        future_elevation_required = $false
        synthetic = $true
        production = $false
        fail_closed = $false
        current_gate = $constants.scaffold_gate
        capability_blocker = $constants.execution_blocker
    }
}

function Resolve-ChatpadNativeAdapter {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$AdapterName = $null,
        [switch]$Synthetic,
        [switch]$RequireExplicitSelection
    )
    $constants = Get-NativeScaffoldConstants
    $identifier = ConvertTo-NativeIdentifierRecord -Value $AdapterName
    if ($identifier.missing) {
        return [pscustomobject][ordered]@{
            schema_version = $constants.composition_schema
            result = 'BLOCKED'
            result_code = 'NATIVE_ADAPTER_SELECTION_REQUIRED'
            reason = 'An explicit native adapter identifier is required; no implicit production or synthetic fallback is allowed.'
            adapter_identity = ''
            selected_adapter = $null
            synthetic_requested = [bool]$Synthetic
            fallback_used = $false
            counters = New-ChatpadNativeZeroCounters
        }
    }
    if (-not $identifier.valid) {
        return [pscustomobject][ordered]@{
            schema_version = $constants.composition_schema
            result = 'BLOCKED'
            result_code = 'INVALID_NATIVE_ADAPTER_IDENTIFIER'
            reason = 'Native adapter identifiers must be primitive strings.'
            adapter_identity = ''
            selected_adapter = $null
            synthetic_requested = [bool]$Synthetic
            fallback_used = $false
            counters = New-ChatpadNativeZeroCounters
        }
    }
    if ([string]::Equals($identifier.value, $constants.production_adapter_id, [StringComparison]::OrdinalIgnoreCase)) {
        if ($Synthetic) {
            return [pscustomobject][ordered]@{
                schema_version = $constants.composition_schema
                result = 'BLOCKED'
                result_code = 'PRODUCTION_ADAPTER_REQUIRES_NON_SYNTHETIC_MODE'
                reason = 'The production native scaffold cannot be selected as a synthetic adapter.'
                adapter_identity = $constants.production_adapter_id
                selected_adapter = $null
                synthetic_requested = [bool]$Synthetic
                fallback_used = $false
                counters = New-ChatpadNativeZeroCounters
            }
        }
        return [pscustomobject][ordered]@{
            schema_version = $constants.composition_schema
            result = 'PASS'
            result_code = 'NATIVE_ADAPTER_SELECTED'
            reason = 'Production native adapter scaffold selected without enabling execution.'
            adapter_identity = $constants.production_adapter_id
            selected_adapter = New-ChatpadProductionNativeAdapter
            synthetic_requested = $false
            fallback_used = $false
            counters = New-ChatpadNativeZeroCounters
        }
    }
    if ([string]::Equals($identifier.value, $constants.synthetic_adapter_id, [StringComparison]::OrdinalIgnoreCase)) {
        if (-not $Synthetic) {
            return [pscustomobject][ordered]@{
                schema_version = $constants.composition_schema
                result = 'BLOCKED'
                result_code = 'SYNTHETIC_ADAPTER_REQUIRES_EXPLICIT_SYNTHETIC_MODE'
                reason = 'Synthetic adapters require explicit synthetic selection and are never substituted for production.'
                adapter_identity = $constants.synthetic_adapter_id
                selected_adapter = $null
                synthetic_requested = [bool]$Synthetic
                fallback_used = $false
                counters = New-ChatpadNativeZeroCounters
            }
        }
        return [pscustomobject][ordered]@{
            schema_version = $constants.composition_schema
            result = 'PASS'
            result_code = 'SYNTHETIC_ADAPTER_SELECTED'
            reason = 'Offline synthetic adapter metadata selected explicitly.'
            adapter_identity = $constants.synthetic_adapter_id
            selected_adapter = New-ChatpadSyntheticAdapterMetadata
            synthetic_requested = $true
            fallback_used = $false
            counters = New-ChatpadNativeZeroCounters
        }
    }
    [pscustomobject][ordered]@{
        schema_version = $constants.composition_schema
        result = 'BLOCKED'
        result_code = 'UNKNOWN_NATIVE_ADAPTER_IDENTIFIER'
        reason = 'Unknown native adapter identifier rejected without fallback.'
        adapter_identity = $identifier.value
        selected_adapter = $null
        synthetic_requested = [bool]$Synthetic
        fallback_used = $false
        counters = New-ChatpadNativeZeroCounters
    }
}

function Invoke-ChatpadNativeAdapterOperation {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Operation = $null,
        [AllowNull()][object]$AdapterName = $null,
        [switch]$Synthetic,
        [AllowNull()][object]$AdapterObject = $null,
        [AllowNull()][object]$Evidence = $null
    )
    $constants = Get-NativeScaffoldConstants
    $selection = Resolve-ChatpadNativeAdapter -AdapterName $AdapterName -Synthetic:$Synthetic -RequireExplicitSelection
    $interop = Get-ChatpadNativeInteropSourceBoundaryContract
    $operationIdentifier = ConvertTo-NativeIdentifierRecord -Value $Operation
    $canonicalOperation = ''
    if ($operationIdentifier.valid) {
        foreach ($supported in @('Apply', 'Restore', 'Restart')) {
            if ([string]::Equals($operationIdentifier.value, $supported, [StringComparison]::OrdinalIgnoreCase)) {
                $canonicalOperation = $supported
                break
            }
        }
    }
    $knownOperation = -not [string]::IsNullOrEmpty($canonicalOperation)
    if ($selection.result -ne 'PASS') {
        $resultCode = $selection.result_code
        $resultReason = $selection.reason
    } elseif ($operationIdentifier.missing) {
        $resultCode = 'NATIVE_ADAPTER_OPERATION_REQUIRED'
        $resultReason = 'An explicit native adapter operation identifier is required.'
    } elseif (-not $operationIdentifier.valid) {
        $resultCode = 'INVALID_NATIVE_ADAPTER_OPERATION_IDENTIFIER'
        $resultReason = 'Native adapter operation identifiers must be primitive strings.'
    } elseif (-not $knownOperation) {
        $resultCode = 'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'
        $resultReason = 'Requested operation identifier is not supported by the native adapter scaffold.'
    } else {
        $resultCode = $constants.execution_blocker
        $resultReason = 'Native SetupAPI/Newdev execution is not implemented in this non-live production scaffold.'
    }
    $counters = New-ChatpadNativeZeroCounters
    [pscustomobject][ordered]@{
        schema_version = $constants.operation_evidence_schema
        result = 'BLOCKED'
        result_code = $resultCode
        operation = if ($knownOperation) { $canonicalOperation } elseif ($operationIdentifier.valid) { $operationIdentifier.value } else { '' }
        operation_known = $knownOperation
        adapter_identity = [string]$selection.adapter_identity
        selected_adapter_identity = if ($null -eq $selection.selected_adapter) { '' } else { [string]$selection.selected_adapter.adapter_identity }
        adapter_implementation_kind = if ($null -eq $selection.selected_adapter) { '' } else { [string]$selection.selected_adapter.adapter_implementation_kind }
        synthetic_requested = [bool]$Synthetic
        synthetic = if ($null -eq $selection.selected_adapter) { $false } else { [bool]$selection.selected_adapter.synthetic }
        production = if ($null -eq $selection.selected_adapter) { $false } else { [bool]$selection.selected_adapter.production }
        fallback_used = $false
        execution_state = if ($null -eq $selection.selected_adapter) { 'not-selected' } else { [string]$selection.selected_adapter.execution_state }
        live_execution_available = $false
        native_interop_implemented = $false
        native_source_declarations_present = [bool]$interop.native_source_declarations_present
        native_source_boundary_status = [string]$interop.source_boundary_status
        native_declaration_api_count = [int]$interop.declaration_inventory.api_count
        native_compilation_permitted = $false
        native_loading_permitted = $false
        native_invocation_permitted = $false
        native_compilation_performed = $true
        native_loading_performed = $false
        native_invocation_performed = $false
        source_audit_result = $constants.source_audit_result
        source_audit_accepted = $true
        source_audit_commit = $constants.source_audit_commit
        compile_only_validation_authorized = $true
        compile_only_validation_performed = $true
        structure_layout_cbsize_validated = $true
        compile_only_validation = Test-ChatpadNativeInteropCompileOnlyValidationEvidence
        device_queries_available = $false
        windows_mutation_available = $false
        execution_attempted = $false
        device_found = $false
        device_bound = $false
        device_updated = $false
        device_restored = $false
        device_restarted = $false
        device_installed = $false
        live_binding_authorized = $false
        live_restoration_authorized = $false
        live_restart_authorized = $false
        caller_supplied_capability_accepted = $false
        caller_object_trusted = $false
        evidence_trusted = $false
        live_capability_present = $false
        live_device_queries_performed = $counters.live_device_queries_performed
        windows_mutations_performed = $counters.windows_mutations_performed
        native_operations_performed = $counters.native_operations_performed
        current_gate = $constants.scaffold_gate
        capability_blocker = $constants.execution_blocker
        reason = $resultReason
        composition = $selection
        details = [pscustomobject][ordered]@{
            caller_adapter_object_supplied = -not [object]::ReferenceEquals($null, $AdapterObject)
            caller_evidence_supplied = -not [object]::ReferenceEquals($null, $Evidence)
            caller_inputs_authoritative = $false
            native_call_plan = if ($knownOperation) { Get-ChatpadNativeInteropCallPlan -Operation $canonicalOperation } else { $null }
        }
    }
}

function Test-ChatpadNativeMutationCapability {
    $constants = Get-NativeScaffoldConstants
    [pscustomobject][ordered]@{
        result = 'BLOCKED'
        result_code = $constants.execution_blocker
        capability_present = $false
        caller_supplied_capability_accepted = $false
        capability_serializable = $false
        capability_source = 'none'
        reason = 'Native mutation authorization is not represented by any public or caller-supplied PowerShell object.'
    }
}

function Test-ChatpadNativeReadOnlyCapability {
    param([AllowNull()][object]$Probe)
    $present = ($Probe -is [string] -and
        [string]::Equals($Probe, 'chatpad-native-read-only-design-probe-v1', [StringComparison]::Ordinal))
    [pscustomobject][ordered]@{
        result = if ($present) { 'PASS' } else { 'BLOCKED' }
        result_code = if ($present) { 'READ_ONLY_DESIGN_PROBE_PRESENT' } else { 'READ_ONLY_DESIGN_PROBE_ABSENT' }
        read_only_probe_present = $present
        mutation_capability_present = $false
        authorizes_mutation = $false
    }
}

function New-ChatpadNativeReadOnlyDesignProbe {
    'chatpad-native-read-only-design-probe-v1'
}

function New-ChatpadNativeMutationCapability {
    throw 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
}

function Test-ChatpadNativeAdapterOperationGate {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Operation,
        [AllowNull()][object]$AdapterName = $null,
        [AllowNull()][object]$Mode = $null,
        [switch]$Synthetic,
        [AllowNull()][object]$IsElevated = $false,
        [AllowNull()][object]$AllowWindowsMutation = $false,
        [AllowNull()][object]$AdapterObject = $null,
        [AllowNull()][object]$Evidence = $null
    )
    $capability = Test-ChatpadNativeMutationCapability
    $operationResult = Invoke-ChatpadNativeAdapterOperation -Operation $Operation -AdapterName $AdapterName -Synthetic:$Synthetic -AdapterObject $AdapterObject -Evidence $Evidence
    [pscustomobject][ordered]@{
        result = 'BLOCKED'
        result_code = $operationResult.result_code
        operation = $Operation
        adapter_name_trusted = $false
        public_mode_trusted = $false
        public_synthetic_flag_trusted = $false
        elevation_trusted = $false
        mutation_switch_trusted = $false
        caller_object_trusted = $false
        evidence_trusted = $false
        fake_adapter_trusted = $false
        live_capability_present = $false
        caller_supplied_capability_accepted = $false
        live_binding_authorized = $false
        live_restoration_authorized = $false
        live_restart_authorized = $false
        live_device_queries_performed = 0
        windows_mutations_performed = 0
        native_operations_performed = 0
        capability_boundary = $capability
        operation_evidence = $operationResult
        details = [pscustomobject][ordered]@{
            adapter_selection_explicit = ($AdapterName -is [string] -and -not [string]::IsNullOrWhiteSpace($AdapterName))
            mode_is_primitive_string = $Mode -is [string]
            synthetic = [bool]$Synthetic
            elevation_claim_accepted = $false
            mutation_switch_accepted = $false
            caller_adapter_object_supplied = -not [object]::ReferenceEquals($null, $AdapterObject)
            caller_evidence_supplied = -not [object]::ReferenceEquals($null, $Evidence)
        }
    }
}

function Get-ChatpadNativeAdapterDesignContract {
    $constants = Get-NativeScaffoldConstants
    $interop = Get-ChatpadNativeInteropSourceBoundaryContract
    $readOnlyCalls = @(
        @{ id='device-information-set-create'; dll='setupapi.dll'; entry_point='SetupDiCreateDeviceInfoList'; purpose='Create one transaction-scoped device information set'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDeviceInfoList' },
        @{ id='exact-device-open'; dll='setupapi.dll'; entry_point='SetupDiOpenDeviceInfoW'; purpose='Open one complete Plug and Play instance ID into the retained set'; read_only=$true; mutating=$false; cleanup='device-information-set owner' },
        @{ id='canonical-instance-query'; dll='setupapi.dll'; entry_point='SetupDiGetDeviceInstanceIdW'; purpose='Retrieve adapter-returned canonical instance ID for ordinal-ignore-case comparison'; read_only=$true; mutating=$false; cleanup='caller-owned Unicode buffer' },
        @{ id='device-property-query'; dll='setupapi.dll'; entry_point='SetupDiGetDevicePropertyW, SetupDiGetDeviceRegistryPropertyW'; purpose='Capture class, container, parent, location, IDs, and current driver identity without Configuration Manager declarations in this phase'; read_only=$true; mutating=$false; cleanup='caller-owned typed buffers' },
        @{ id='driver-list-build'; dll='setupapi.dll'; entry_point='SetupDiBuildDriverInfoList'; purpose='Build driver nodes only for the retained exact device element'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDriverInfoList' },
        @{ id='driver-node-enumeration'; dll='setupapi.dll'; entry_point='SetupDiEnumDriverInfoW, SetupDiGetDriverInfoDetailW, SetupDiGetDriverInstallParamsW'; purpose='Collect immutable candidate identity without first or best fallback'; read_only=$true; mutating=$false; cleanup='driver-list owner' }
    )
    $mutatingCalls = @(
        @{ id='selected-driver-association'; dll='setupapi.dll'; entry_point='SetupDiSetSelectedDriverW'; purpose='Associate the exact enumerated driver node with the retained exact device element'; read_only=$false; mutating=$true; cleanup='driver-list owner' },
        @{ id='exact-device-install'; dll='newdev.dll'; entry_point='DiInstallDevice'; purpose='Bind only the retained exact device element to the selected driver node'; read_only=$false; mutating=$true; cleanup='preserve NeedReboot and last-error' },
        @{ id='postcondition-query'; dll='setupapi.dll'; entry_point='property and driver identity queries'; purpose='Verify complete expected driver identity after API return'; read_only=$true; mutating=$false; cleanup='caller-owned buffers' },
        @{ id='driver-list-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDriverInfoList'; purpose='Destroy the device-specific SPDIT_COMPATDRIVER list exactly once'; read_only=$true; mutating=$false; cleanup='idempotent owner state' },
        @{ id='device-information-set-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDeviceInfoList'; purpose='Release HDEVINFO in deterministic cleanup'; read_only=$true; mutating=$false; cleanup='final HDEVINFO owner' },
        @{ id='exact-device-restart'; dll='future source audit'; entry_point='future exact-device restart sequence; no declaration in this phase'; purpose='Restart only the exact retained instance when separately authorized'; read_only=$false; mutating=$true; cleanup='preserve restart and reboot state' }
    )
    $structures = @(
        @{ name='HDEVINFO'; ownership='single transaction owner'; size_rule='opaque handle'; lifetime='destroy once through SetupDiDestroyDeviceInfoList' },
        @{ name='SP_DEVINFO_DATA'; ownership='paired with HDEVINFO'; size_rule='cbSize must be initialized to runtime marshaled structure size'; lifetime='valid while device information set is alive' },
        @{ name='SP_DEVINSTALL_PARAMS_W'; ownership='caller stack or pinned buffer'; size_rule='cbSize initialized before get or set'; lifetime='copied by SetupAPI according to API contract' },
        @{ name='SP_DRVINFO_DATA_W'; ownership='driver-list owner'; size_rule='cbSize initialized before enumeration and selected-driver association'; lifetime='valid until driver list destruction' },
        @{ name='SP_DRVINFO_DETAIL_DATA_W'; ownership='caller allocated variable-length buffer'; size_rule='two-call insufficient-buffer pattern; do not guess architecture-sensitive size'; lifetime='caller frees after identity capture' },
        @{ name='DEVPROPKEY/DEVPROPTYPE buffers'; ownership='caller allocated typed buffers'; size_rule='insufficient-buffer result controls allocation length'; lifetime='caller frees after typed conversion' },
        @{ name='BOOL NeedReboot'; ownership='caller variable'; size_rule='Win32 BOOL'; lifetime='preserved in evidence without automatic reboot' },
        @{ name='Win32 last-error'; ownership='captured immediately after native failure'; size_rule='DWORD'; lifetime='stored with native call record before cleanup can overwrite it' }
    )
    $errors = @(
        'EXACT_INSTANCE_NOT_FOUND',
        'CANONICAL_INSTANCE_MISMATCH',
        'INSTANCE_IDENTITY_DRIFT',
        'ACCESS_DENIED',
        'ELEVATION_REQUIRED',
        'UNSUPPORTED_OPERATING_SYSTEM',
        'UNSUPPORTED_ARCHITECTURE',
        'PROPERTY_UNAVAILABLE',
        'DRIVER_LIST_BUILD_FAILURE',
        'DRIVER_NODE_ENUMERATION_FAILURE',
        'TARGET_DRIVER_NOT_FOUND',
        'TARGET_DRIVER_AMBIGUOUS',
        'PRIOR_DRIVER_NOT_FOUND',
        'PRIOR_DRIVER_AMBIGUOUS',
        'SELECTED_DRIVER_ASSOCIATION_FAILURE',
        'BIND_API_FAILURE_BEFORE_POSSIBLE_MUTATION',
        'BIND_FAILURE_AFTER_POSSIBLE_MUTATION',
        'POST_BIND_VERIFICATION_FAILURE',
        'RESTORE_API_FAILURE',
        'POST_RESTORE_VERIFICATION_FAILURE',
        'RESTART_REQUIRED',
        'REBOOT_REQUIRED',
        'CLEANUP_FAILURE',
        'UNEXPECTED_NATIVE_EXCEPTION',
        'UNCERTAIN_DEVICE_STATE'
    )
    $operationGates = @(
        'supported-operating-system-and-architecture',
        'no-public-caller-supplied-mutation-capability',
        'exact-canonical-instance-id',
        'valid-unexpired-plan',
        'valid-plan-hash',
        'valid-authenticated-snapshot',
        'exact-restoration-identity-bound-to-snapshot',
        'exact-target-package-identity',
        'unambiguous-target-driver-node',
        'current-state-matches-precondition',
        'explicit-operation-authorization',
        'elevation',
        'mutation-switch',
        'no-conflicting-transaction',
        'no-replay',
        'no-pending-uncertainty-requiring-recovery',
        'live-evidence-producer-available',
        'audit-approved-implementation-version'
    )
    [pscustomobject][ordered]@{
        schema_version = $constants.design_schema
        live_adapter_status = 'SCAFFOLD_NON_EXECUTING'
        native_execution_status = 'NOT_IMPLEMENTED'
        current_gate = $constants.scaffold_gate
        capability_blocker = $constants.execution_blocker
        source_audit = Get-NativeSourceAuditAcceptanceRecord
        source_boundary = $interop
        module_state_introspectable_by_same_process_callers = $true
        caller_supplied_mutation_capability_accepted = $false
        production_adapter = New-ChatpadProductionNativeAdapter
        synthetic_adapter = New-ChatpadSyntheticAdapterMetadata
        exact_device_opening = [pscustomobject][ordered]@{
            accepts_one_canonical_instance_id = $true
            opens_complete_instance_id = $true
            compares_adapter_returned_canonical_id = $true
            rejects_zero_ambiguity_replacement_sibling_and_drift = $true
            retains_one_device_set_and_element = $true
            forbids_hardware_id_first_match = $true
        }
        read_only_interfaces = @('open-exact-instance','retrieve-canonical-identity','query-device-and-driver-state','enumerate-candidate-driver-nodes','verify-active-driver','close-resources')
        mutation_interfaces = @('select-authorized-driver-node','bind-selected-node','restore-selected-prior-node','restart-exact-device-when-separately-authorized')
        native_calls = @($readOnlyCalls + $mutatingCalls)
        native_structures = @($structures)
        error_taxonomy = @($errors | ForEach-Object {
            [pscustomobject][ordered]@{
                code = $_
                controlled_failure = $true
                restoration_required = ($_ -in @('BIND_FAILURE_AFTER_POSSIBLE_MUTATION','POST_BIND_VERIFICATION_FAILURE','UNCERTAIN_DEVICE_STATE'))
                manual_recovery_required = ($_ -in @('RESTORE_API_FAILURE','POST_RESTORE_VERIFICATION_FAILURE','CLEANUP_FAILURE','UNEXPECTED_NATIVE_EXCEPTION','UNCERTAIN_DEVICE_STATE'))
                retry_prohibited = $true
                restart_pending = ($_ -eq 'RESTART_REQUIRED')
                reboot_pending = ($_ -eq 'REBOOT_REQUIRED')
            }
        })
        evidence_fields = @('trusted_producer_identity','implementation_binary_identity','adapter_implementation_version','code_or_assembly_hash','operation_plan_hash','exact_canonical_instance_id','exact_target_driver_identity','exact_restoration_driver_identity','ordered_native_call_log','native_return_codes','win32_errors','before_state','after_state','restart_reboot_indication','cleanup_results','internal_authorization_provenance','synthetic_live_classification')
        operation_gates = @($operationGates)
        composition_root = [pscustomobject][ordered]@{
            permitted_future_location = 'tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1'
            present_in_this_task = $true
            arbitrary_module_or_class_name_selection = $false
            public_path_parameter_replacement = $false
            fake_adapter_satisfies = $false
            current_capability_creation_path = 'none'
            public_or_exported_caller_supplied_capability_parameter = $false
            module_private_object_trust_boundary = $false
            purpose = 'deterministic dependency selection and wiring, not authorization'
            production_adapter_identity = $constants.production_adapter_id
            synthetic_adapter_identity = $constants.synthetic_adapter_id
            implicit_synthetic_fallback = $false
            environment_variable_authorization = $false
            call_stack_authorization = $false
            caller_name_authorization = $false
            mutable_module_state_trusted = $false
            code_integrity_prerequisite = $true
        }
    }
}

function Test-ChatpadNativeDesignContractCompleteness {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $Contract = Get-ChatpadNativeAdapterDesignContract
    $requiredCalls = @(
        'device-information-set-create',
        'exact-device-open',
        'canonical-instance-query',
        'device-property-query',
        'driver-list-build',
        'driver-node-enumeration',
        'selected-driver-association',
        'exact-device-install',
        'postcondition-query',
        'driver-list-destroy',
        'device-information-set-destroy',
        'exact-device-restart'
    )
    $requiredErrors = @(
        'EXACT_INSTANCE_NOT_FOUND',
        'CANONICAL_INSTANCE_MISMATCH',
        'INSTANCE_IDENTITY_DRIFT',
        'ACCESS_DENIED',
        'ELEVATION_REQUIRED',
        'UNSUPPORTED_OPERATING_SYSTEM',
        'UNSUPPORTED_ARCHITECTURE',
        'PROPERTY_UNAVAILABLE',
        'DRIVER_LIST_BUILD_FAILURE',
        'DRIVER_NODE_ENUMERATION_FAILURE',
        'TARGET_DRIVER_NOT_FOUND',
        'TARGET_DRIVER_AMBIGUOUS',
        'PRIOR_DRIVER_NOT_FOUND',
        'PRIOR_DRIVER_AMBIGUOUS',
        'SELECTED_DRIVER_ASSOCIATION_FAILURE',
        'BIND_API_FAILURE_BEFORE_POSSIBLE_MUTATION',
        'BIND_FAILURE_AFTER_POSSIBLE_MUTATION',
        'POST_BIND_VERIFICATION_FAILURE',
        'RESTORE_API_FAILURE',
        'POST_RESTORE_VERIFICATION_FAILURE',
        'RESTART_REQUIRED',
        'REBOOT_REQUIRED',
        'CLEANUP_FAILURE',
        'UNEXPECTED_NATIVE_EXCEPTION',
        'UNCERTAIN_DEVICE_STATE'
    )
    $callIds = @($Contract.native_calls | ForEach-Object { [string]$_.id })
    $errorCodes = @($Contract.error_taxonomy | ForEach-Object { [string]$_.code })
    $missingCalls = @($requiredCalls | Where-Object { $callIds -notcontains $_ })
    $missingErrors = @($requiredErrors | Where-Object { $errorCodes -notcontains $_ })
    $gateCount = @($Contract.operation_gates).Count
    $production = $Contract.production_adapter
    $composition = $Contract.composition_root
    $sourceBoundary = $Contract.source_boundary
    $scaffoldComplete = (
        $null -ne $production -and
        [string]$production.adapter_identity -eq 'chatpad-windows-exact-instance-adapter-v1' -and
        [bool]$production.production -eq $true -and
        [bool]$production.synthetic -eq $false -and
        [bool]$production.native_interop_implemented -eq $false -and
        [bool]$production.native_source_declarations_present -eq $true -and
        [int]$production.native_declaration_api_count -eq 13 -and
        [bool]$production.device_queries_available -eq $false -and
        [bool]$production.windows_mutation_available -eq $false -and
        [string]$production.execution_state -eq 'non-executing-scaffold' -and
        [bool]$composition.present_in_this_task -eq $true -and
        [bool]$composition.implicit_synthetic_fallback -eq $false -and
        $null -ne $sourceBoundary -and
        [bool]$sourceBoundary.native_source_declarations_present -eq $true -and
        [bool]$sourceBoundary.native_invocation_permitted -eq $false
    )
    $result = ($missingCalls.Count -eq 0 -and $missingErrors.Count -eq 0 -and $gateCount -eq 18 -and [bool]$Contract.exact_device_opening.retains_one_device_set_and_element -and $scaffoldComplete)
    [pscustomobject][ordered]@{
        result = if ($result) { 'PASS' } else { 'FAIL' }
        result_code = if ($result) { 'NATIVE_DESIGN_CONTRACT_COMPLETE' } else { 'NATIVE_DESIGN_CONTRACT_INCOMPLETE' }
        required_call_count = $requiredCalls.Count
        missing_calls = @($missingCalls)
        required_error_count = $requiredErrors.Count
        missing_errors = @($missingErrors)
        operation_gate_count = $gateCount
        structure_count = @($Contract.native_structures).Count
        evidence_field_count = @($Contract.evidence_fields).Count
        production_scaffold_complete = $scaffoldComplete
    }
}

function Test-ChatpadNativeExecutableGuard {
    param([string]$RepositoryRoot = '')
    if (-not $RepositoryRoot) {
        $RepositoryRoot = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    }
    $RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    $constants = Get-ChatpadNativeInteropConstants
    $compileOnlyHarnessProject = Get-AuthorizedNativeCompileOnlyHarnessProjectPath
    $compileOnlyValidationScript = 'tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1'
    $paths = @(& git -C $RepositoryRoot ls-files '*.ps1' '*.psm1' '*.cs' '*.csproj' '*.vcxproj' '*.sln' '*.props' '*.targets')
    $declarationPatterns = @(
        '\[DllImport\s*\(',
        '\[LibraryImport\s*\(',
        ('DllImport' + 'Attribute'),
        ('Add-' + 'Type[\s\S]{0,400}(setupapi|newdev|cfgmgr32|DiInstallDevice|SetupDi|CM_)')
    )
    $invocationPatterns = @(
        '^\s*(&\s*)?pnputil(?:\.exe)?\s+/add-driver',
        '^\s*(&\s*)?devcon(?:\.exe)?\b',
        ('Start-' + 'Process\s+[''"]?(pnputil|devcon)'),
        'UpdateDriverForPlugAndPlayDevices\s*\(',
        'DiInstallDevice\s*\(',
        'SetupDiSetSelectedDriver\s*\(',
        'SetupDiCallClassInstaller\s*\(',
        'CM_Reenumerate_DevNode\s*\(',
        ('Remove-' + 'PnpDevice\b'),
        ('Disable-' + 'PnpDevice\b'),
        ('Enable-' + 'PnpDevice\b'),
        ('Set-' + 'Service\b'),
        ('New-' + 'Service\b'),
        'sc\.exe\s+(create|delete|start|stop|config)'
    )
    $guardMatches = [Collections.Generic.List[object]]::new()
    $approvedDeclarationMatches = [Collections.Generic.List[object]]::new()
    foreach ($relative in $paths) {
        $normalizedRelative = $relative.Replace('\','/')
        $isApprovedDeclarationPath = ($normalizedRelative -eq $constants.declaration_relative_path)
        $path = Join-Path $RepositoryRoot $relative
        $text = [IO.File]::ReadAllText($path)
        foreach ($pattern in $declarationPatterns) {
            if ($text -match $pattern) {
                if ($isApprovedDeclarationPath) {
                    $approvedDeclarationMatches.Add([pscustomobject][ordered]@{ relative_path = $relative; guard = 'approved-native-source-declaration'; pattern = $pattern })
                } elseif ($normalizedRelative -eq $compileOnlyValidationScript -and $pattern -match 'Add-' -and $text -notmatch '(?m)^\s*Add-Type\b') {
                    continue
                } else {
                    $guardMatches.Add([pscustomobject][ordered]@{ relative_path = $relative; guard = 'native-declaration-outside-allowlist'; pattern = $pattern })
                }
            }
        }
        $lines = [IO.File]::ReadAllLines($path)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            foreach ($pattern in $invocationPatterns) {
                if ($lines[$index] -match $pattern) {
                    if ($isApprovedDeclarationPath -and $lines[$index] -match '\bextern\b') {
                        continue
                    }
                    $guardMatches.Add([pscustomobject][ordered]@{ relative_path = $relative; line = $index + 1; guard = 'native-invocation'; pattern = $pattern })
                }
            }
        }
    }
    $sourceBoundary = Test-ChatpadNativeInteropSourceBoundary -RepositoryRoot $RepositoryRoot
    if ($sourceBoundary.result -ne 'PASS') {
        foreach ($defect in @($sourceBoundary.defects)) {
            $guardMatches.Add([pscustomobject][ordered]@{ relative_path = $sourceBoundary.declaration_relative_path; guard = 'native-source-boundary'; pattern = [string]$defect.id })
        }
    }
    [pscustomobject][ordered]@{
        result = if ($guardMatches.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($guardMatches.Count) { 'NATIVE_SOURCE_BOUNDARY_GUARD_FAILED' } else { 'NATIVE_SOURCE_BOUNDARY_GUARD_VALID' }
        scanned_file_count = $paths.Count
        approved_declaration_match_count = $approvedDeclarationMatches.Count
        forbidden_match_count = $guardMatches.Count
        match_count = $guardMatches.Count
        source_boundary = $sourceBoundary
        approved_declarations = @($approvedDeclarationMatches)
        matches = @($guardMatches)
    }
}

Export-ModuleMember -Function *-Chatpad*
