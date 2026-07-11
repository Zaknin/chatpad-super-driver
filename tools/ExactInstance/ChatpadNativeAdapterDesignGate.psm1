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
        scaffold_gate = 'BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT'
        accepted_execution_gate = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        execution_design_status = 'NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO'
        fail_closed_scaffolding_status = 'NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO'
        non_live_plan_status = 'NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO'
        envelope_verifier_status = 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO'
        evidence_mode = 'EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO'
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
        declaration_raw_byte_size = $SourceBoundary.declaration_raw_byte_size
        declaration_canonical_sha256 = $SourceBoundary.declaration_canonical_sha256
        declaration_canonical_byte_size = $SourceBoundary.declaration_canonical_byte_size
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
        'tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs' = 'B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9'
        'tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1' = '663FB2CAB1259D301B4679100F407A56145BFD120C3882C5CF5F09F24221AA5E'
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
    if ([string]$evidence.expected_native_source_hashes.declaration_sha256 -cne 'B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9' -or
        [string]$evidence.expected_native_source_hashes.source_boundary_record_sha256 -cne '663FB2CAB1259D301B4679100F407A56145BFD120C3882C5CF5F09F24221AA5E') {
        $defects.Add([pscustomobject][ordered]@{ id = 'audited-source-hash-value-invalid'; value = $evidence.expected_native_source_hashes })
    }
    $static = $evidence.static_contract_validation
    $expectedApis = @('SetupDiCreateDeviceInfoList','SetupDiDestroyDeviceInfoList','SetupDiOpenDeviceInfoW','SetupDiGetDeviceInstanceIdW','SetupDiGetDevicePropertyW','SetupDiGetDeviceRegistryPropertyW','SetupDiBuildDriverInfoList','SetupDiDestroyDriverInfoList','SetupDiEnumDriverInfoW','SetupDiGetDriverInfoDetailW','SetupDiGetDriverInstallParamsW','SetupDiSetSelectedDriverW','DiInstallDevice')
    $expectedStructures = @('ChatpadDeviceInfoSetHandleToken','SP_DEVINFO_DATA','SP_DEVINSTALL_PARAMS_W','SP_DRVINSTALL_PARAMS','SP_DRVINFO_DATA_W','SP_DRVINFO_DETAIL_DATA_W','DEVPROPKEY')
    $expectedFields = @('uint cbSize','uint Rank','uint Flags','UIntPtr PrivateData','uint Reserved')
    $expectedHeaders = @('um/setupapi.h','um/newdev.h','shared/devpropdef.h','shared/devpkey.h')
    if ((@($static.native_api_inventory) -join '|') -cne ($expectedApis -join '|') -or
        (@($static.structure_inventory) -join '|') -cne ($expectedStructures -join '|') -or
        [string]$static.corrected_method_signature -cne 'bool SetupDiGetDriverInstallParamsW(IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DRVINFO_DATA_W DriverInfoData, ref SP_DRVINSTALL_PARAMS DriverInstallParams)' -or
        (@($static.driver_install_params_fields) -join '|') -cne ($expectedFields -join '|') -or
        [int]$static.driver_install_params_x86_byte_size -ne 20 -or [int]$static.driver_install_params_x64_byte_size -ne 32 -or
        [bool]$static.old_device_install_params_binding_absent -ne $true -or [string]$static.sdk_version -cne '10.0.26100.0' -or
        (@($static.sdk_headers) -join '|') -cne ($expectedHeaders -join '|')) {
        $defects.Add([pscustomobject][ordered]@{ id = 'corrected-static-contract-invalid'; value = $static })
    }
    $declaredOutputRoot=[IO.Path]::GetFullPath((Join-Path $root ([string]$evidence.scope.output_artifact_root)))
    $allowedArtifactRoot=[IO.Path]::GetFullPath((Join-Path $root 'artifacts'))
    if(-not$declaredOutputRoot.StartsWith($allowedArtifactRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not @(&git -C $root check-ignore -- $declaredOutputRoot 2>$null).Count){
        $defects.Add([pscustomobject][ordered]@{id='output-root-invalid';value=$evidence.scope.output_artifact_root})
    }
    $cleanup = $evidence.persistent_output_cleanup
    if ($null -eq $cleanup -or [bool]$cleanup.required -ne $true -or [bool]$cleanup.cleanup_performed -ne $true -or [bool]$cleanup.persistent_assembly_or_binary_present -ne $false) {
        $defects.Add([pscustomobject][ordered]@{ id='persistent-output-cleanup-invalid'; value=$cleanup })
    }
    foreach ($file in $producedFiles) {
        $relative = [string]$file.relative_path
        $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $full.StartsWith($declaredOutputRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-outside-isolated-artifacts'; value = $relative })
            continue
        }
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $defects.Add([pscustomobject][ordered]@{ id = 'persistent-produced-file-present'; value = $relative })
        }
        if($null-eq$file.PSObject.Properties['hash_policy']-or$null-eq$file.PSObject.Properties['content_classification']-or$null-eq$file.PSObject.Properties['ignored']-or[string]$file.hash_policy-ne'raw_file_bytes'-or[string]$file.content_classification-ne'compile-output-artifact'-or[bool]$file.ignored-ne$true){
            $defects.Add([pscustomobject][ordered]@{id='produced-file-policy-invalid';value=$relative})
        }
        if($null-eq$file.PSObject.Properties['byte_size']-or$null-eq$file.PSObject.Properties['sha256']-or$null-eq$file.PSObject.Properties['raw_file_byte_size']-or$null-eq$file.PSObject.Properties['raw_file_sha256']-or[long]$file.byte_size-lt1-or[string]$file.sha256-notmatch'^[A-F0-9]{64}$'-or[long]$file.raw_file_byte_size-ne[long]$file.byte_size-or[string]$file.raw_file_sha256-cne[string]$file.sha256) {
            $defects.Add([pscustomobject][ordered]@{ id = 'produced-file-recorded-identity-invalid'; value = $relative })
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

function Test-ChatpadNativeInteropCompileOnlyValidationEvidenceRecordOnly {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $constants = Get-NativeScaffoldConstants
    $defects = [Collections.Generic.List[object]]::new()
    $root = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    $evidenceRelativePath = 'docs/evidence/native-interop-compile-only-validation.json'
    $manifestRelativePath = 'docs/evidence/runtime-bringup-readiness-manifest.json'
    $evidencePath = Join-Path $root $evidenceRelativePath
    $manifestPath = Join-Path $root $manifestRelativePath

    foreach ($relativePath in @($evidenceRelativePath, $manifestRelativePath)) {
        $tracked = @(& git -C $root ls-files --error-unmatch -- $relativePath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 1 -or $tracked[0].Replace('\','/') -cne $relativePath) {
            $defects.Add([pscustomobject][ordered]@{ id = 'tracked-evidence-record-required'; value = $relativePath })
        }
    }

    try {
        $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
    } catch {
        $defects.Add([pscustomobject][ordered]@{ id = 'compile-evidence-record-invalid'; value = $_.Exception.Message })
        $evidence = $null
    }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    } catch {
        $defects.Add([pscustomobject][ordered]@{ id = 'readiness-manifest-record-invalid'; value = $_.Exception.Message })
        $manifest = $null
    }

    $primaryDllPath = 'artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll'
    if ($null -ne $evidence) {
        if ([string]$evidence.schema_version -ne 'chatpad-native-interop-compile-only-validation-v2' -or
            [string]$evidence.build_result.result -ne 'PASS' -or
            [int]$evidence.build_result.compiler_exit_code -ne 0 -or
            [int]$evidence.build_result.warning_count -ne 0 -or
            [int]$evidence.build_result.error_count -ne 0 -or
            [string]$evidence.readiness_transition.previous_gate -ne $constants.prior_compile_only_gate -or
            [string]$evidence.readiness_transition.resulting_readiness_gate -ne $constants.compile_only_evidence_gate -or
            [string]$evidence.readiness_transition.remaining_blocker -ne $constants.execution_blocker -or
            [bool]$evidence.readiness_transition.transition_allowed -ne $true) {
            $defects.Add([pscustomobject][ordered]@{ id = 'compile-evidence-record-status-invalid'; value = $evidence.readiness_transition })
        }
        $producedFiles = @($evidence.build_result.produced_files)
        $producedPaths = @($producedFiles | ForEach-Object { [string]$_.relative_path })
        if ([int]$evidence.build_result.produced_file_count -ne $producedFiles.Count -or
            $producedFiles.Count -lt 1 -or
            @($producedPaths | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
            $defects.Add([pscustomobject][ordered]@{ id = 'compile-output-record-set-invalid'; value = $producedPaths })
        }
        foreach ($file in $producedFiles) {
            $relative = [string]$file.relative_path
            if ($relative -notmatch '^artifacts/compile-only/native-interop/' -or
                $relative -match '(^|/)(\.|\.\.)(/|$)' -or
                [string]$file.hash_policy -ne 'raw_file_bytes' -or
                [string]$file.content_classification -ne 'compile-output-artifact' -or
                [bool]$file.ignored -ne $true -or
                [long]$file.byte_size -lt 0 -or
                [string]$file.sha256 -notmatch '^[A-F0-9]{64}$' -or
                [long]$file.raw_file_byte_size -ne [long]$file.byte_size -or
                [string]$file.raw_file_sha256 -cne [string]$file.sha256) {
                $defects.Add([pscustomobject][ordered]@{ id = 'compile-output-record-identity-invalid'; value = $relative })
            }
            foreach ($flag in @('assembly_loaded','reflection_inspection_used','managed_code_executed','native_api_invoked')) {
                if ($null -eq $file.PSObject.Properties[$flag] -or [bool]$file.$flag -ne $false) {
                    $defects.Add([pscustomobject][ordered]@{ id = 'compile-output-record-prohibited-action-invalid'; value = "$relative::$flag" })
                }
            }
        }
        foreach ($name in @('assemblyLoaded','managedCodeExecuted','nativeInvocationOccurred','deviceQueryOccurred','exactInstanceAccessed','windowsMutationOccurred','producedAssemblyExecuted','testHostExecuted','reflectionInspectionUsed','postBuildExecutionOccurred','driverBuildOccurred','driverSigningOccurred','driverPackagingOccurred','driverInstallationOccurred')) {
            if ($null -eq $evidence.prohibited_actions.PSObject.Properties[$name] -or [bool]$evidence.prohibited_actions.$name -ne $false) {
                $defects.Add([pscustomobject][ordered]@{ id = 'compile-evidence-record-prohibited-action-invalid'; value = $name })
            }
        }
    } else {
        $producedFiles = @()
    }

    $primaryRecords = @($producedFiles | Where-Object { [string]$_.relative_path -ceq $primaryDllPath })
    if ($primaryRecords.Count -ne 1) {
        $defects.Add([pscustomobject][ordered]@{ id = 'primary-dll-record-missing-or-duplicate'; value = $primaryDllPath })
    }
    if ($null -ne $manifest) {
        $manifestHash = [string]$manifest.native_interop_compile_only_evidence_reaudit.current_v2_primary_dll_sha256
        $acceptedPath = [string]$manifest.compiled_artifact_metadata_review_design_gate.status_boundary_audit_acceptance.approved_real_artifact_path
        $acceptedHash = [string]$manifest.compiled_artifact_metadata_review_design_gate.status_boundary_audit_acceptance.approved_real_artifact_sha256
        if ([string]$manifest.schema_version -ne 'chatpad-runtime-bringup-readiness-manifest-v4' -or
            [string]$manifest.current_gate -ne $constants.accepted_execution_gate -or
            [string]$manifest.capability_blocker -ne $constants.execution_blocker -or
            [string]$manifest.live_installation_readiness -ne 'BLOCKED' -or
            [string]$manifest.native_execution_status -ne 'NOT_IMPLEMENTED' -or
            $primaryRecords.Count -ne 1 -or
            $acceptedPath -cne $primaryDllPath -or
            $manifestHash -notmatch '^[A-F0-9]{64}$' -or
            $acceptedHash -cne $manifestHash -or
            [string]$primaryRecords[0].sha256 -cne $manifestHash) {
            $defects.Add([pscustomobject][ordered]@{ id = 'manifest-recorded-primary-dll-identity-mismatch'; value = $primaryDllPath })
        }
    }

    [pscustomobject][ordered]@{
        result = if ($defects.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($defects.Count) { 'NATIVE_INTEROP_COMPILE_ONLY_EVIDENCE_RECORD_INVALID' } else { 'NATIVE_INTEROP_COMPILE_ONLY_EVIDENCE_RECORD_VALID' }
        validation_mode = 'EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO'
        defect_count = $defects.Count
        defects = @($defects)
        evidence_path = $evidenceRelativePath
        manifest_path = $manifestRelativePath
        evidence = $evidence
        artifact_io_performed = $false
        compile_output_directory_scanned = $false
        real_dll_accessed = $false
    }
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
    $compileValidation = Test-ChatpadNativeInteropCompileOnlyValidationEvidenceRecordOnly
    if ($Record.PSObject.Properties['current_gate']) {
        $Record.current_gate = $constants.accepted_execution_gate
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
        native_invocation_count = 0
        native_library_load_count = 0
        entry_point_resolution_count = 0
        setupapi_newdev_invocation_count = 0
        device_query_count = 0
        hardware_access_count = 0
        windows_mutation_count = 0
        driver_action_count = 0
        artifact_io_performed = $false
        windows_mutations_performed = 0
        live_device_queries_performed = 0
        native_operations_performed = 0
        live_binding_authorized = $false
        live_restoration_authorized = $false
        live_restart_authorized = $false
    }
}

function Test-NativeEnvelopeRecordShape {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string[]]$RequiredProperties
    )

    if ([object]::ReferenceEquals($null, $Value) -or
        $Value -is [array] -or
        $Value -isnot [pscustomobject]) {
        return [pscustomobject][ordered]@{
            valid = $false
            missing = @($RequiredProperties)
            unexpected = @()
        }
    }
    $names = @($Value.PSObject.Properties.Name)
    $missing = @($RequiredProperties | Where-Object { $_ -notin $names })
    $unexpected = @($names | Where-Object { $_ -notin $RequiredProperties })
    [pscustomobject][ordered]@{
        valid = ($missing.Count -eq 0 -and $unexpected.Count -eq 0)
        missing = $missing
        unexpected = $unexpected
    }
}

function Get-NativeEnvelopePropertyValue {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Name
    )

    if ([object]::ReferenceEquals($null, $Value) -or $Value -is [array]) {
        return $null
    }
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    $property.Value
}

function Test-NativeEnvelopeText {
    param(
        [AllowNull()][object]$Value,
        [int]$MaximumLength = 512
    )

    if ($Value -isnot [string]) {
        return $false
    }
    $text = [string]$Value
    -not [string]::IsNullOrWhiteSpace($text) -and
        $text.Length -le $MaximumLength -and
        $text -notmatch "[`r`n]"
}

function Test-NativeEnvelopeIdentifier {
    param([AllowNull()][object]$Value)

    (Test-NativeEnvelopeText -Value $Value -MaximumLength 128) -and
        ([string]$Value -match '^[A-Za-z0-9][A-Za-z0-9_.:/\\&{}-]{0,127}$') -and
        ([string]$Value -notmatch '\*|\?')
}

function Test-NativeEnvelopeStringArray {
    param(
        [AllowNull()][object]$Value,
        [ValidateSet('Identifier','NativeName','EvidencePath')][string]$Kind = 'Identifier'
    )

    if ([object]::ReferenceEquals($null, $Value) -or $Value -is [string]) {
        return $false
    }
    $items = @($Value)
    if ($items.Count -eq 0) {
        return $false
    }
    $normalized = [Collections.Generic.List[string]]::new()
    foreach ($item in $items) {
        if ($item -isnot [string] -or -not (Test-NativeEnvelopeText -Value $item -MaximumLength 512)) {
            return $false
        }
        $text = [string]$item
        if ($Kind -eq 'Identifier') {
            if (-not (Test-NativeEnvelopeIdentifier -Value $text)) {
                return $false
            }
        } elseif ($Kind -eq 'NativeName') {
            if ($text -notmatch '^[A-Za-z][A-Za-z0-9_.-]{0,127}(/[A-Za-z][A-Za-z0-9_.-]{0,127})?$' -or
                $text -match '\*|\?') {
                return $false
            }
        } else {
            $path = $text.Replace('\','/')
            if (-not $path.StartsWith('docs/evidence/', [StringComparison]::Ordinal) -or
                $path.Contains('//') -or
                $path.Contains(':') -or
                @($path.Split('/') | Where-Object { $_ -in @('.','..') }).Count -ne 0) {
                return $false
            }
            $text = $path
        }
        if ($normalized.Contains($text)) {
            return $false
        }
        $normalized.Add($text)
    }
    $true
}

function Test-NativeEnvelopeInteger {
    param(
        [AllowNull()][object]$Value,
        [switch]$AllowZero
    )

    if ($Value -isnot [byte] -and
        $Value -isnot [int16] -and
        $Value -isnot [int32] -and
        $Value -isnot [int64] -and
        $Value -isnot [uint16] -and
        $Value -isnot [uint32]) {
        return $false
    }
    if ($AllowZero) {
        return [int64]$Value -ge 0
    }
    [int64]$Value -gt 0
}

function New-NativeEnvelopeVerificationResult {
    param(
        [Parameter(Mandatory)][string]$EnvelopeState,
        [Parameter(Mandatory)][string]$EnvelopeResultCode,
        [Parameter(Mandatory)][bool]$StructurallyValid,
        [string]$OperationClass = '',
        [string[]]$Defects = @()
    )

    $constants = Get-NativeScaffoldConstants
    $counters = New-ChatpadNativeZeroCounters
    [pscustomobject][ordered]@{
        SchemaVersion = 'chatpad-native-adapter-execution-envelope-verification-result-v1'
        VerifierStatus = $constants.envelope_verifier_status
        EnvelopeState = $EnvelopeState
        EnvelopeResultCode = $EnvelopeResultCode
        EnvelopeStructurallyValid = $StructurallyValid
        OperationClass = $OperationClass
        DefectCount = @($Defects).Count
        Defects = @($Defects)
        DeclaredFieldValidationOnly = $true
        ExecutionAuthorized = $false
        NativeExecution = 'NOT_IMPLEMENTED'
        LiveReadiness = 'BLOCKED'
        BlockedReason = $constants.execution_blocker
        ArtifactIoPerformed = $false
        CompileOutputIoPerformed = $false
        StaticMetadataParserInvoked = $false
        FilesystemInspected = $false
        DeviceStateInspected = $false
        RegistryInspected = $false
        ServiceStateInspected = $false
        CertificateStoreInspected = $false
        NativeLibraryLoadCount = $counters.native_library_load_count
        EntryPointResolutionCount = $counters.entry_point_resolution_count
        SetupApiNewdevInvocationCount = $counters.setupapi_newdev_invocation_count
        DeviceQueryCount = $counters.device_query_count
        HardwareAccessCount = $counters.hardware_access_count
        WindowsMutationCount = $counters.windows_mutation_count
        DriverActionCount = $counters.driver_action_count
    }
}

function Test-ChatpadNativeAdapterExecutionAuthorizationEnvelope {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Envelope = $null,
        [datetimeoffset]$EvaluationUtc = [datetimeoffset]::UtcNow
    )

    $constants = Get-NativeScaffoldConstants
    if ([object]::ReferenceEquals($null, $Envelope)) {
        return New-NativeEnvelopeVerificationResult `
            -EnvelopeState 'MISSING' `
            -EnvelopeResultCode 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_MISSING' `
            -StructurallyValid $false `
            -Defects @('envelope-missing')
    }
    $topProperties = @(
        'schema_version',
        'envelope_status',
        'operation_class',
        'authorization_statement',
        'approved_real_artifact_identity',
        'native_entry_point_allowlist',
        'setupapi_newdev_function_allowlist',
        'device_instance_binding',
        'dry_run_evidence',
        'rollback_restore_plan',
        'windows_mutation_classification',
        'operator_confirmation',
        'pre_implementation_audit_required',
        'post_implementation_audit_required',
        'current_state_denial',
        'current_execution_authorized',
        'native_execution_status',
        'live_readiness'
    )
    $shape = Test-NativeEnvelopeRecordShape -Value $Envelope -RequiredProperties $topProperties
    if (-not $shape.valid) {
        return New-NativeEnvelopeVerificationResult `
            -EnvelopeState 'MALFORMED' `
            -EnvelopeResultCode 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_MALFORMED' `
            -StructurallyValid $false `
            -Defects @(
                @($shape.missing | ForEach-Object { "missing:$($_)" })
                @($shape.unexpected | ForEach-Object { "unexpected:$($_)" })
            )
    }

    $defects = [Collections.Generic.List[string]]::new()
    $operation = [string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'operation_class')
    $envelopeStatus = [string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'envelope_status')
    $futureLiveRequested = $envelopeStatus -match '(?i)(AUTHORIZED[_-]?LIVE|LIVE[_-]?READY|EXECUTION[_-]?AUTHORIZED)'
    if ([string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'schema_version') -cne 'chatpad-native-adapter-execution-authorization-envelope-v1') {
        $defects.Add('schema-version-invalid')
    }
    if ($envelopeStatus -cne 'RECORD_ONLY_FUTURE_AUTHORIZATION_ENVELOPE') {
        $defects.Add('envelope-status-invalid')
    }
    if ($operation -notin $constants.supported_operations) {
        $defects.Add('operation-class-invalid')
    }
    if ((Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'pre_implementation_audit_required') -isnot [bool] -or
        (Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'pre_implementation_audit_required') -ne $true) {
        $defects.Add('pre-implementation-audit-required-invalid')
    }
    if ((Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'post_implementation_audit_required') -isnot [bool] -or
        (Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'post_implementation_audit_required') -ne $true) {
        $defects.Add('post-implementation-audit-required-invalid')
    }
    if ([string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'current_state_denial') -cne $constants.execution_blocker) {
        $defects.Add('current-state-denial-invalid')
    }
    if ((Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'current_execution_authorized') -isnot [bool] -or
        (Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'current_execution_authorized') -ne $false) {
        $defects.Add('current-execution-authorization-claim-rejected')
        $futureLiveRequested = $true
    }
    if ([string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'native_execution_status') -cne 'NOT_IMPLEMENTED') {
        $defects.Add('native-execution-status-invalid')
    }
    if ([string](Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'live_readiness') -cne 'BLOCKED') {
        $defects.Add('live-readiness-invalid')
    }

    $authorization = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'authorization_statement'
    $authorizationShape = Test-NativeEnvelopeRecordShape -Value $authorization -RequiredProperties @(
        'schema_version','status','implementation_commit','host_id','session_id',
        'expires_utc','evidence_root_id','envelope_hash'
    )
    $expires = [datetimeoffset]::MinValue
    $expiryValid = $false
    if (-not $authorizationShape.valid) {
        $defects.Add('authorization-statement-shape-invalid')
    } else {
        if ([string]$authorization.schema_version -cne 'chatpad-native-adapter-future-authorization-statement-v1') {
            $defects.Add('authorization-statement-schema-invalid')
        }
        if ([string]$authorization.status -cne 'DECLARED_FUTURE_AUTHORIZATION_NOT_CURRENT_AUTHORITY') {
            $defects.Add('authorization-statement-status-invalid')
            if ([string]$authorization.status -match '(?i)(AUTHORIZED[_-]?LIVE|LIVE[_-]?READY|EXECUTION[_-]?AUTHORIZED)') {
                $futureLiveRequested = $true
            }
        }
        if ([string]$authorization.implementation_commit -notmatch '^[0-9a-f]{40}$') {
            $defects.Add('authorization-implementation-commit-invalid')
        }
        foreach ($name in @('host_id','session_id','evidence_root_id')) {
            if (-not (Test-NativeEnvelopeIdentifier -Value $authorization.$name)) {
                $defects.Add("authorization-$($name.Replace('_','-'))-invalid")
            }
        }
        if ([string]$authorization.envelope_hash -notmatch '^[A-F0-9]{64}$') {
            $defects.Add('authorization-envelope-hash-invalid')
        }
        $expiryValid = [datetimeoffset]::TryParse(
            [string]$authorization.expires_utc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal,
            [ref]$expires
        )
        if (-not $expiryValid) {
            $defects.Add('authorization-expiry-invalid')
        }
    }

    $artifact = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'approved_real_artifact_identity'
    $artifactShape = Test-NativeEnvelopeRecordShape -Value $artifact -RequiredProperties @(
        'schema_version','path','size','sha256','origin_evidence_id'
    )
    if (-not $artifactShape.valid) {
        $defects.Add('artifact-identity-shape-invalid')
    } else {
        if ([string]$artifact.schema_version -cne 'chatpad-native-adapter-declared-artifact-identity-v1') {
            $defects.Add('artifact-identity-schema-invalid')
        }
        if (-not (Test-NativeEnvelopeText -Value $artifact.path -MaximumLength 1024)) {
            $defects.Add('artifact-path-invalid')
        }
        if (-not (Test-NativeEnvelopeInteger -Value $artifact.size)) {
            $defects.Add('artifact-size-invalid')
        }
        if ([string]$artifact.sha256 -notmatch '^[A-F0-9]{64}$') {
            $defects.Add('artifact-sha256-invalid')
        }
        if (-not (Test-NativeEnvelopeIdentifier -Value $artifact.origin_evidence_id)) {
            $defects.Add('artifact-origin-evidence-id-invalid')
        }
    }

    if (-not (Test-NativeEnvelopeStringArray -Value $Envelope.native_entry_point_allowlist -Kind NativeName)) {
        $defects.Add('native-entry-point-allowlist-invalid')
    }
    if (-not (Test-NativeEnvelopeStringArray -Value $Envelope.setupapi_newdev_function_allowlist -Kind NativeName)) {
        $defects.Add('setupapi-newdev-function-allowlist-invalid')
    }

    $device = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'device_instance_binding'
    $deviceShape = Test-NativeEnvelopeRecordShape -Value $device -RequiredProperties @(
        'schema_version','instance_id','snapshot_id','target_driver_identity',
        'prior_driver_identity','ordinal_reopen_required'
    )
    if (-not $deviceShape.valid) {
        $defects.Add('device-binding-shape-invalid')
    } else {
        if ([string]$device.schema_version -cne 'chatpad-native-adapter-declared-device-binding-v1') {
            $defects.Add('device-binding-schema-invalid')
        }
        foreach ($name in @('instance_id','snapshot_id','target_driver_identity','prior_driver_identity')) {
            if (-not (Test-NativeEnvelopeIdentifier -Value $device.$name)) {
                $defects.Add("device-$($name.Replace('_','-'))-invalid")
            }
        }
        if ($device.ordinal_reopen_required -isnot [bool] -or $device.ordinal_reopen_required -ne $true) {
            $defects.Add('device-ordinal-reopen-required-invalid')
        }
    }

    $dryRun = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'dry_run_evidence'
    $dryRunShape = Test-NativeEnvelopeRecordShape -Value $dryRun -RequiredProperties @(
        'schema_version','evidence_ids','evidence_paths','independently_audited','mutation_count'
    )
    if (-not $dryRunShape.valid) {
        $defects.Add('dry-run-evidence-shape-invalid')
    } else {
        if ([string]$dryRun.schema_version -cne 'chatpad-native-adapter-dry-run-evidence-prerequisite-v1') {
            $defects.Add('dry-run-evidence-schema-invalid')
        }
        if (-not (Test-NativeEnvelopeStringArray -Value $dryRun.evidence_ids -Kind Identifier)) {
            $defects.Add('dry-run-evidence-ids-invalid')
        }
        if (-not (Test-NativeEnvelopeStringArray -Value $dryRun.evidence_paths -Kind EvidencePath)) {
            $defects.Add('dry-run-evidence-paths-invalid')
        }
        if ($dryRun.independently_audited -isnot [bool] -or $dryRun.independently_audited -ne $true) {
            $defects.Add('dry-run-independent-audit-invalid')
        }
        if (-not (Test-NativeEnvelopeInteger -Value $dryRun.mutation_count -AllowZero) -or [int64]$dryRun.mutation_count -ne 0) {
            $defects.Add('dry-run-mutation-count-invalid')
        }
    }

    $rollback = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'rollback_restore_plan'
    $rollbackShape = Test-NativeEnvelopeRecordShape -Value $rollback -RequiredProperties @(
        'schema_version','plan_id','prior_driver_identity','ordered_steps',
        'independently_accepted','manual_recovery_documented'
    )
    if (-not $rollbackShape.valid) {
        $defects.Add('rollback-plan-shape-invalid')
    } else {
        if ([string]$rollback.schema_version -cne 'chatpad-native-adapter-rollback-restore-plan-v1') {
            $defects.Add('rollback-plan-schema-invalid')
        }
        if (-not (Test-NativeEnvelopeIdentifier -Value $rollback.plan_id) -or
            -not (Test-NativeEnvelopeIdentifier -Value $rollback.prior_driver_identity)) {
            $defects.Add('rollback-plan-identity-invalid')
        }
        if (-not (Test-NativeEnvelopeStringArray -Value $rollback.ordered_steps -Kind Identifier)) {
            $defects.Add('rollback-plan-steps-invalid')
        }
        if ($rollback.independently_accepted -isnot [bool] -or $rollback.independently_accepted -ne $true -or
            $rollback.manual_recovery_documented -isnot [bool] -or $rollback.manual_recovery_documented -ne $true) {
            $defects.Add('rollback-plan-acceptance-invalid')
        }
    }

    $mutation = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'windows_mutation_classification'
    $mutationShape = Test-NativeEnvelopeRecordShape -Value $mutation -RequiredProperties @(
        'schema_version','operation_class','classification','mutation_permitted_current_phase',
        'cleanup_required','failure_state','counter_names'
    )
    if (-not $mutationShape.valid) {
        $defects.Add('mutation-classification-shape-invalid')
    } else {
        if ([string]$mutation.schema_version -cne 'chatpad-native-adapter-windows-mutation-classification-v1' -or
            [string]$mutation.operation_class -cne $operation -or
            -not (Test-NativeEnvelopeIdentifier -Value $mutation.classification) -or
            -not (Test-NativeEnvelopeIdentifier -Value $mutation.failure_state)) {
            $defects.Add('mutation-classification-invalid')
        }
        if ($mutation.mutation_permitted_current_phase -isnot [bool] -or $mutation.mutation_permitted_current_phase -ne $false -or
            $mutation.cleanup_required -isnot [bool] -or $mutation.cleanup_required -ne $true) {
            $defects.Add('mutation-classification-authority-invalid')
        }
        if (-not (Test-NativeEnvelopeStringArray -Value $mutation.counter_names -Kind Identifier)) {
            $defects.Add('mutation-classification-counters-invalid')
        }
    }

    $confirmation = Get-NativeEnvelopePropertyValue -Value $Envelope -Name 'operator_confirmation'
    $confirmationShape = Test-NativeEnvelopeRecordShape -Value $confirmation -RequiredProperties @(
        'schema_version','confirmed','envelope_hash','operation_class','instance_id',
        'artifact_sha256','host_id','session_id','expires_utc'
    )
    if (-not $confirmationShape.valid) {
        $defects.Add('operator-confirmation-shape-invalid')
    } else {
        if ([string]$confirmation.schema_version -cne 'chatpad-native-adapter-operator-confirmation-v1' -or
            $confirmation.confirmed -isnot [bool] -or $confirmation.confirmed -ne $true) {
            $defects.Add('operator-confirmation-invalid')
        }
        if ($authorizationShape.valid -and (
            [string]$confirmation.envelope_hash -cne [string]$authorization.envelope_hash -or
            [string]$confirmation.host_id -cne [string]$authorization.host_id -or
            [string]$confirmation.session_id -cne [string]$authorization.session_id -or
            [string]$confirmation.expires_utc -cne [string]$authorization.expires_utc
        )) {
            $defects.Add('operator-confirmation-authorization-binding-invalid')
        }
        if ([string]$confirmation.operation_class -cne $operation) {
            $defects.Add('operator-confirmation-operation-binding-invalid')
        }
        if ($deviceShape.valid -and [string]$confirmation.instance_id -cne [string]$device.instance_id) {
            $defects.Add('operator-confirmation-device-binding-invalid')
        }
        if ($artifactShape.valid -and [string]$confirmation.artifact_sha256 -cne [string]$artifact.sha256) {
            $defects.Add('operator-confirmation-artifact-binding-invalid')
        }
    }

    if ($rollbackShape.valid -and $deviceShape.valid -and
        [string]$rollback.prior_driver_identity -cne [string]$device.prior_driver_identity) {
        $defects.Add('rollback-device-binding-invalid')
    }

    $stale = $expiryValid -and $expires -le $EvaluationUtc
    $structurallyValid = ($defects.Count -eq 0 -and -not $stale -and -not $futureLiveRequested)
    $state = if ($futureLiveRequested) {
        'FUTURE_LIVE_REJECTED'
    } elseif ($stale) {
        'STALE'
    } elseif ($defects.Count) {
        'MALFORMED'
    } else {
        'STRUCTURALLY_COMPLETE_STILL_BLOCKED'
    }
    $code = switch ($state) {
        'FUTURE_LIVE_REJECTED' { 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_FUTURE_LIVE_REJECTED' }
        'STALE' { 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_STALE' }
        'MALFORMED' { 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_MALFORMED' }
        default { 'NATIVE_ADAPTER_EXECUTION_ENVELOPE_COMPLETE_STILL_BLOCKED' }
    }
    New-NativeEnvelopeVerificationResult `
        -EnvelopeState $state `
        -EnvelopeResultCode $code `
        -StructurallyValid $structurallyValid `
        -OperationClass $operation `
        -Defects @($defects)
}

function New-ChatpadNativeAdapterExecutionRequest {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Operation = $null,
        [AllowNull()][object]$AdapterName = $null,
        [string]$TargetInstanceId = '',
        [AllowNull()][object]$TargetDriverIdentity = $null,
        [AllowNull()][object]$RestorationDriverIdentity = $null,
        [ValidateSet('none','exact-device-separate-authorization','reboot-never-automatic')][string]$RestartPolicy = 'none'
    )

    $constants = Get-NativeScaffoldConstants
    $operationIdentifier = ConvertTo-NativeIdentifierRecord -Value $Operation
    $adapterIdentifier = ConvertTo-NativeIdentifierRecord -Value $AdapterName
    $canonicalOperation = ''
    if ($operationIdentifier.valid) {
        foreach ($supported in $constants.supported_operations) {
            if ([string]::Equals($operationIdentifier.value, $supported, [StringComparison]::OrdinalIgnoreCase)) {
                $canonicalOperation = $supported
                break
            }
        }
    }
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-execution-request-v1'
        operation = $canonicalOperation
        requested_operation = if ($operationIdentifier.valid) { $operationIdentifier.value } else { '' }
        operation_known = -not [string]::IsNullOrEmpty($canonicalOperation)
        adapter_identity = if ($adapterIdentifier.valid) { $adapterIdentifier.value } else { '' }
        target_identity = [pscustomobject][ordered]@{
            canonical_instance_id = $TargetInstanceId
            target_driver_identity = $TargetDriverIdentity
            restoration_driver_identity = $RestorationDriverIdentity
            live_lookup_performed = $false
        }
        restart_policy = $RestartPolicy
        evidence_mode = $constants.evidence_mode
        current_gate = $constants.accepted_execution_gate
        design_status = $constants.execution_design_status
        fail_closed_scaffolding_status = $constants.fail_closed_scaffolding_status
        non_live_implementation_status = $constants.non_live_plan_status
        native_execution_status = 'NOT_IMPLEMENTED'
        live_readiness = 'BLOCKED'
    }
}

function Test-ChatpadNativeAdapterExecutionEvidence {
    [CmdletBinding(PositionalBinding = $false)]
    param([AllowNull()][object]$Evidence = $null)

    $constants = Get-NativeScaffoldConstants
    if ([object]::ReferenceEquals($null, $Evidence)) {
        return [pscustomobject][ordered]@{
            result = 'BLOCKED'
            result_code = 'NATIVE_ADAPTER_EXECUTION_EVIDENCE_MISSING'
            evidence_mode = $constants.evidence_mode
            trusted = $false
            artifact_io_performed = $false
        }
    }
    if (-not ($Evidence -is [pscustomobject]) -or
        $null -eq $Evidence.PSObject.Properties['schema_version'] -or
        [string]$Evidence.schema_version -ne 'chatpad-native-adapter-execution-evidence-record-v1' -or
        $null -eq $Evidence.PSObject.Properties['evidence_mode'] -or
        [string]$Evidence.evidence_mode -ne $constants.evidence_mode) {
        return [pscustomobject][ordered]@{
            result = 'BLOCKED'
            result_code = 'NATIVE_ADAPTER_EXECUTION_EVIDENCE_MALFORMED'
            evidence_mode = $constants.evidence_mode
            trusted = $false
            artifact_io_performed = $false
        }
    }
    [pscustomobject][ordered]@{
        result = 'BLOCKED'
        result_code = 'NATIVE_ADAPTER_EXECUTION_EVIDENCE_RECORD_ONLY_NOT_AUTHORIZATION'
        evidence_mode = $constants.evidence_mode
        trusted = $false
        artifact_io_performed = $false
    }
}

function Test-ChatpadNativeAdapterExecutionAuthorization {
    [CmdletBinding(PositionalBinding = $false)]
    param([AllowNull()][object]$AuthorizationState = $null)

    $constants = Get-NativeScaffoldConstants
    if ([object]::ReferenceEquals($null, $AuthorizationState)) {
        return [pscustomobject][ordered]@{
            result = 'BLOCKED'
            result_code = 'NATIVE_ADAPTER_EXECUTION_AUTHORIZATION_MISSING'
            current_gate = $constants.accepted_execution_gate
            native_execution_status = 'NOT_IMPLEMENTED'
            live_readiness = 'BLOCKED'
            authorizes_execution = $false
        }
    }
    if (-not ($AuthorizationState -is [pscustomobject]) -or
        $null -eq $AuthorizationState.PSObject.Properties['schema_version'] -or
        [string]$AuthorizationState.schema_version -ne 'chatpad-native-adapter-execution-authorization-v1' -or
        $null -eq $AuthorizationState.PSObject.Properties['status']) {
        return [pscustomobject][ordered]@{
            result = 'BLOCKED'
            result_code = 'NATIVE_ADAPTER_EXECUTION_AUTHORIZATION_MALFORMED'
            current_gate = $constants.accepted_execution_gate
            native_execution_status = 'NOT_IMPLEMENTED'
            live_readiness = 'BLOCKED'
            authorizes_execution = $false
        }
    }
    if ($AuthorizationState.PSObject.Properties['expires_utc']) {
        try {
            $expires = [datetimeoffset]::Parse([string]$AuthorizationState.expires_utc, [Globalization.CultureInfo]::InvariantCulture)
            if ($expires -lt [datetimeoffset]::Parse('2026-07-06T00:00:00Z', [Globalization.CultureInfo]::InvariantCulture)) {
                return [pscustomobject][ordered]@{
                    result = 'BLOCKED'
                    result_code = 'NATIVE_ADAPTER_EXECUTION_AUTHORIZATION_STALE'
                    current_gate = $constants.accepted_execution_gate
                    native_execution_status = 'NOT_IMPLEMENTED'
                    live_readiness = 'BLOCKED'
                    authorizes_execution = $false
                }
            }
        } catch {
            return [pscustomobject][ordered]@{
                result = 'BLOCKED'
                result_code = 'NATIVE_ADAPTER_EXECUTION_AUTHORIZATION_MALFORMED'
                current_gate = $constants.accepted_execution_gate
                native_execution_status = 'NOT_IMPLEMENTED'
                live_readiness = 'BLOCKED'
                authorizes_execution = $false
            }
        }
    }
    $status = [string]$AuthorizationState.status
    [pscustomobject][ordered]@{
        result = 'BLOCKED'
        result_code = if ($status -eq $constants.execution_design_status) { $constants.execution_blocker } else { 'NATIVE_ADAPTER_EXECUTION_AUTHORIZATION_REJECTED' }
        current_gate = $constants.accepted_execution_gate
        native_execution_status = 'NOT_IMPLEMENTED'
        live_readiness = 'BLOCKED'
        authorizes_execution = $false
    }
}

function Get-ChatpadNativeAdapterNonLiveAuthorizationDecision {
    [CmdletBinding(PositionalBinding = $false)]
    param([AllowNull()][object]$AuthorizationState = $null)

    $constants = Get-NativeScaffoldConstants
    $evaluation = Test-ChatpadNativeAdapterExecutionAuthorization -AuthorizationState $AuthorizationState
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-non-live-authorization-decision-v1'
        result = 'BLOCKED'
        result_code = $constants.execution_blocker
        source_result_code = [string]$evaluation.result_code
        phase_status = $constants.non_live_plan_status
        evidence_mode = $constants.evidence_mode
        current_gate = $constants.accepted_execution_gate
        native_execution_status = 'NOT_IMPLEMENTED'
        live_readiness = 'BLOCKED'
        authorizes_execution = $false
        accepts_future_live_authorization = $false
        would_invoke_native = $false
        would_touch_device = $false
        would_mutate_windows = $false
        would_access_artifact = $false
    }
}

function Test-ChatpadNativeAdapterNonLivePreconditions {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Request = $null,
        [AllowNull()][object]$Evidence = $null,
        [AllowNull()][object]$AuthorizationState = $null
    )

    $constants = Get-NativeScaffoldConstants
    $evidenceState = Test-ChatpadNativeAdapterExecutionEvidence -Evidence $Evidence
    $authorizationDecision = Get-ChatpadNativeAdapterNonLiveAuthorizationDecision -AuthorizationState $AuthorizationState
    $requestValid = (
        $Request -is [pscustomobject] -and
        $null -ne $Request.PSObject.Properties['schema_version'] -and
        [string]$Request.schema_version -eq 'chatpad-native-adapter-execution-request-v1'
    )
    $operationKnown = ($requestValid -and [bool]$Request.operation_known)
    $preconditionCode = if (-not $requestValid) {
        'NATIVE_ADAPTER_NON_LIVE_PLAN_REQUEST_MALFORMED'
    } elseif (-not $operationKnown) {
        'UNSUPPORTED_NATIVE_ADAPTER_OPERATION'
    } elseif ([string]$evidenceState.result_code -in @(
        'NATIVE_ADAPTER_EXECUTION_EVIDENCE_MISSING',
        'NATIVE_ADAPTER_EXECUTION_EVIDENCE_MALFORMED'
    )) {
        [string]$evidenceState.result_code
    } elseif ([string]$authorizationDecision.source_result_code -ne $constants.execution_blocker) {
        [string]$authorizationDecision.source_result_code
    } else {
        $constants.execution_blocker
    }

    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-non-live-precondition-result-v1'
        result = 'BLOCKED'
        result_code = $constants.execution_blocker
        precondition_result_code = $preconditionCode
        phase_status = $constants.non_live_plan_status
        request_valid = $requestValid
        operation_known = $operationKnown
        evidence_binding = $evidenceState
        authorization_decision = $authorizationDecision
        evidence_mode = $constants.evidence_mode
        all_preconditions_satisfied = $false
        execution_permitted = $false
        artifact_io_performed = $false
        compile_output_directory_scanned = $false
        live_device_lookup_performed = $false
    }
}

function New-ChatpadNativeAdapterNonLiveOperationPlan {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Operation = $null,
        [AllowNull()][object]$AdapterName = $null,
        [string]$TargetInstanceId = '',
        [AllowNull()][object]$TargetDriverIdentity = $null,
        [AllowNull()][object]$RestorationDriverIdentity = $null,
        [ValidateSet('none','exact-device-separate-authorization','reboot-never-automatic')][string]$RestartPolicy = 'none',
        [AllowNull()][object]$Evidence = $null,
        [AllowNull()][object]$AuthorizationState = $null
    )

    $constants = Get-NativeScaffoldConstants
    $request = New-ChatpadNativeAdapterExecutionRequest -Operation $Operation -AdapterName $AdapterName -TargetInstanceId $TargetInstanceId -TargetDriverIdentity $TargetDriverIdentity -RestorationDriverIdentity $RestorationDriverIdentity -RestartPolicy $RestartPolicy
    $preconditions = Test-ChatpadNativeAdapterNonLivePreconditions -Request $request -Evidence $Evidence -AuthorizationState $AuthorizationState
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-non-live-operation-plan-v1'
        phase_status = $constants.non_live_plan_status
        result = 'BLOCKED'
        result_code = $constants.execution_blocker
        operation = [string]$request.operation
        requested_operation = [string]$request.requested_operation
        operation_known = [bool]$request.operation_known
        adapter_identity = [string]$request.adapter_identity
        target_identity = $request.target_identity
        restart_policy = [string]$request.restart_policy
        request = $request
        preconditions = $preconditions
        authorization_decision = $preconditions.authorization_decision
        evidence_binding = $preconditions.evidence_binding
        evidence_mode = $constants.evidence_mode
        current_gate = $constants.accepted_execution_gate
        native_execution_status = 'NOT_IMPLEMENTED'
        live_readiness = 'BLOCKED'
        would_invoke_native = $false
        would_load_native_library = $false
        would_resolve_entry_point = $false
        would_invoke_setupapi_newdev = $false
        would_touch_device = $false
        would_access_hardware = $false
        would_mutate_windows = $false
        would_perform_driver_action = $false
        would_access_artifact = $false
    }
}

function New-ChatpadNativeAdapterNonLivePlanResult {
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory)][object]$Plan)

    $constants = Get-NativeScaffoldConstants
    $counters = New-ChatpadNativeZeroCounters
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-non-live-plan-result-v1'
        phase_status = $constants.non_live_plan_status
        result = 'BLOCKED'
        result_code = $constants.execution_blocker
        operation = if ($Plan.PSObject.Properties['operation']) { [string]$Plan.operation } else { '' }
        plan = $Plan
        evidence_mode = $constants.evidence_mode
        current_gate = $constants.accepted_execution_gate
        runtime_blocker = $constants.execution_blocker
        native_execution_status = 'NOT_IMPLEMENTED'
        live_readiness = 'BLOCKED'
        native_invocation_count = $counters.native_invocation_count
        native_library_load_count = $counters.native_library_load_count
        entry_point_resolution_count = $counters.entry_point_resolution_count
        setupapi_newdev_invocation_count = $counters.setupapi_newdev_invocation_count
        device_query_count = $counters.device_query_count
        hardware_access_count = $counters.hardware_access_count
        windows_mutation_count = $counters.windows_mutation_count
        driver_action_count = $counters.driver_action_count
        artifact_io_performed = $false
    }
}

function Invoke-ChatpadNativeAdapterFailClosedExecution {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)][object]$Request,
        [AllowNull()][object]$AdapterSelection = $null,
        [AllowNull()][object]$Evidence = $null,
        [AllowNull()][object]$AuthorizationState = $null,
        [string]$ResultCode = '',
        [string]$Reason = ''
    )

    $constants = Get-NativeScaffoldConstants
    $authorization = Test-ChatpadNativeAdapterExecutionAuthorization -AuthorizationState $AuthorizationState
    $evidenceState = Test-ChatpadNativeAdapterExecutionEvidence -Evidence $Evidence
    $compileValidation = Test-ChatpadNativeInteropCompileOnlyValidationEvidenceRecordOnly
    $counters = New-ChatpadNativeZeroCounters
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-adapter-fail-closed-execution-result-v1'
        result = 'BLOCKED'
        result_code = if ($ResultCode) { $ResultCode } else { $constants.execution_blocker }
        status = $constants.execution_blocker
        reason = if ($Reason) { $Reason } else { 'Native adapter execution is not implemented; fail-closed scaffolding returns blocked results only.' }
        request = $Request
        adapter_selection = $AdapterSelection
        authorization = $authorization
        execution_evidence = $evidenceState
        compile_only_validation = $compileValidation
        evidence_mode = $constants.evidence_mode
        current_gate = $constants.accepted_execution_gate
        design_status = $constants.execution_design_status
        fail_closed_scaffolding_status = $constants.fail_closed_scaffolding_status
        non_live_implementation_status = $constants.non_live_plan_status
        live_readiness = 'BLOCKED'
        native_execution_status = 'NOT_IMPLEMENTED'
        native_invocation_count = $counters.native_invocation_count
        device_query_count = $counters.device_query_count
        windows_mutation_count = $counters.windows_mutation_count
        driver_action_count = $counters.driver_action_count
        artifact_io_performed = $false
        native_library_load_performed = $false
        entry_point_resolution_performed = $false
        setupapi_newdev_invocation_performed = $false
        device_query_performed = $false
        windows_mutation_performed = $false
        driver_action_performed = $false
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
        compile_only_validation = Test-ChatpadNativeInteropCompileOnlyValidationEvidenceRecordOnly
        device_queries_available = $false
        windows_mutation_available = $false
        future_elevation_required = $true
        synthetic = $false
        production = $true
        fail_closed = $true
        mutation_counter_fields = @('windows_mutations_performed')
        device_query_counter_fields = @('live_device_queries_performed')
        native_operation_counter_fields = @('native_operations_performed')
        current_gate = $constants.accepted_execution_gate
        design_status = $constants.execution_design_status
        fail_closed_scaffolding_status = $constants.fail_closed_scaffolding_status
        non_live_implementation_status = $constants.non_live_plan_status
        envelope_verifier_status = $constants.envelope_verifier_status
        evidence_mode = $constants.evidence_mode
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
        current_gate = $constants.accepted_execution_gate
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
    $request = New-ChatpadNativeAdapterExecutionRequest -Operation $Operation -AdapterName $AdapterName
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
    $execution = Invoke-ChatpadNativeAdapterFailClosedExecution -Request $request -AdapterSelection $selection -Evidence $Evidence -AuthorizationState $null -ResultCode $resultCode -Reason $resultReason
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
        native_execution_status = $execution.native_execution_status
        live_readiness = $execution.live_readiness
        design_status = $execution.design_status
        fail_closed_scaffolding_status = $execution.fail_closed_scaffolding_status
        non_live_implementation_status = $execution.non_live_implementation_status
        evidence_mode = $execution.evidence_mode
        source_audit_result = $constants.source_audit_result
        source_audit_accepted = $true
        source_audit_commit = $constants.source_audit_commit
        compile_only_validation_authorized = $true
        compile_only_validation_performed = $true
        structure_layout_cbsize_validated = $true
        compile_only_validation = $execution.compile_only_validation
        execution_request = $request
        fail_closed_execution = $execution
        execution_authorization = $execution.authorization
        execution_evidence_state = $execution.execution_evidence
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
        native_invocation_count = $execution.native_invocation_count
        device_query_count = $execution.device_query_count
        windows_mutation_count = $execution.windows_mutation_count
        driver_action_count = $execution.driver_action_count
        artifact_io_performed = $execution.artifact_io_performed
        native_library_load_performed = $execution.native_library_load_performed
        entry_point_resolution_performed = $execution.entry_point_resolution_performed
        setupapi_newdev_invocation_performed = $execution.setupapi_newdev_invocation_performed
        device_query_performed = $execution.device_query_performed
        windows_mutation_performed = $execution.windows_mutation_performed
        driver_action_performed = $execution.driver_action_performed
        live_device_queries_performed = $counters.live_device_queries_performed
        windows_mutations_performed = $counters.windows_mutations_performed
        native_operations_performed = $counters.native_operations_performed
        current_gate = $constants.accepted_execution_gate
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
        @{ name='SP_DEVINSTALL_PARAMS_W'; ownership='caller stack or pinned buffer'; size_rule='cbSize initialized before device-install get or set'; lifetime='copied by SetupAPI according to API contract' },
        @{ name='SP_DRVINSTALL_PARAMS'; ownership='caller stack or pinned buffer'; size_rule='sequential layout; x86 20 bytes; x64 32 bytes; cbSize initialized before driver-node query'; lifetime='driver-node rank and flags copied by SetupAPI' },
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
        current_gate = $constants.accepted_execution_gate
        design_status = $constants.execution_design_status
        fail_closed_scaffolding_status = $constants.fail_closed_scaffolding_status
        non_live_implementation_status = $constants.non_live_plan_status
        envelope_verifier = [pscustomobject][ordered]@{
            schema_version = 'chatpad-native-adapter-execution-authorization-envelope-v1'
            status = $constants.envelope_verifier_status
            declared_field_validation_only = $true
            can_authorize_execution = $false
            artifact_io_performed = $false
            compile_output_io_performed = $false
            native_execution_status = 'NOT_IMPLEMENTED'
            live_readiness = 'BLOCKED'
            blocked_reason = $constants.execution_blocker
        }
        evidence_mode = $constants.evidence_mode
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
