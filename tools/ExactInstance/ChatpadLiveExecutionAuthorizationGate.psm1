Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Source-only authorization gate. It can issue a process-local live authorization
# object, but this module has no production-provider constructor or native path.
if ($null -eq ('Chatpad.LiveAuthorization.LiveAuthorizationRegistry' -as [type])) {
    Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadLiveAuthorizationRegistry.cs')
}

function Get-LiveGateValue {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties.Item($Name)
    if ($null -eq $property) { return $Default }
    return $property.Value
}

$script:LiveGateSourceIntegrityRootOverride = $null
$script:LiveGateSourceIntegrityPathOverride = $null

function Get-LiveExecutionAuthorizationGateConstants {
    [pscustomobject][ordered]@{
        operation = 'APPLY'
        live_authorization_phrase = 'AUTHORIZE_ONE_LIVE_NATIVE_APPLY_ATTEMPT'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        task_8e_evidence_path = 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json'
        task_8e_evidence_sha256 = '493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F'
        task_8f_evidence_path = 'docs/evidence/native-adapter-production-backend-source-task-8f-1.json'
        task_8f_evidence_sha256 = '93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042'
        task_8g_evidence_path = 'docs/evidence/one-shot-native-execution-coordinator-task-8g-1.json'
        task_8g_evidence_sha256 = 'BB2016A9CFD85BFCA06862E7B3D386EE611355AA2416778BFDCB49C7A6C0BD12'
        task_8g_audited_implementation_commit = '79ec174dabd7e73f2d01021168921021bc118702'
        accepted_ordered_target_chain = @(
            'USB\VID_045E&PID_028E\1C21F10',
            'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00',
            'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000'
        )
        critical_source_hashes = @(
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadNonExecutingNativeAdapter.psm1'; sha256 = '78B85CBC2EB0FF58D65A5B97D35DEA9561FD7EA80E910444C2BEDC415C5AB919' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1'; sha256 = '77162617BAC6439921E3856A352ED8E940D43B549A717F2F58233C1445269754' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadOneShotNativeExecutionCoordinator.psm1'; sha256 = 'B639AAB4D3FBA440E1DD4183C71F8D5FCF54B632CF3DE2EAA91E50535B7277DA' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadOneShotAuthorizationRegistry.cs'; sha256 = '9C85311242920C0C2DDCDAD9A7AED9A10C6F145F70DFA03B092607372485A462' }
        )
        externally_validated_root_of_trust_paths = @(
            'tools/ExactInstance/ChatpadLiveExecutionAuthorizationGate.psm1',
            'tools/ExactInstance/ChatpadLiveAuthorizationRegistry.cs'
        )
    }
}

function New-LiveGateZeroCounters {
    [pscustomobject][ordered]@{
        device_query_count = 0
        native_invocation_count = 0
        setupapi_newdev_invocation_count = 0
        binding_count = 0
        windows_mutation_count = 0
        driver_action_count = 0
        rollback_count = 0
        restore_count = 0
        artifact_compile_output_access_count = 0
        production_provider_registration_count = 0
        production_provider_selection_count = 0
        production_provider_construction_count = 0
        production_provider_load_count = 0
        production_provider_invocation_count = 0
    }
}

function Test-LiveGateExactArray {
    param([AllowNull()][object]$Actual, [Parameter(Mandatory)][string[]]$Expected)
    if ($null -eq $Actual -or $Actual -is [string]) { return $false }
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($values[$index] -isnot [string] -or -not [string]::Equals([string]$values[$index], $Expected[$index], [StringComparison]::Ordinal)) { return $false }
    }
    return $true
}

function Test-LiveGateLiteralBooleanTrue {
    param([AllowNull()][object]$Value)
    return ($Value -is [System.Boolean] -and $Value -eq $true)
}

function Get-LiveGateRuntimeTypeName {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '<null>' }
    return $Value.GetType().FullName
}

function Get-LiveGateRepositoryRoot {
    if (-not [string]::IsNullOrWhiteSpace([string]$script:LiveGateSourceIntegrityRootOverride)) {
        return [IO.Path]::GetFullPath([string]$script:LiveGateSourceIntegrityRootOverride)
    }
    return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}

function ConvertTo-LiveGateHexSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $builder = [Text.StringBuilder]::new(64)
    foreach ($byte in $Bytes) { [void]$builder.Append($byte.ToString('X2')) }
    return $builder.ToString()
}

function Test-LiveGateCallerCriticalSourceHashes {
    param([AllowNull()][object]$Actual)
    $expected = @((Get-LiveExecutionAuthorizationGateConstants).critical_source_hashes)
    $defects = [Collections.Generic.List[string]]::new()
    if ($null -eq $Actual -or $Actual -is [string]) {
        $defects.Add('CRITICAL_SOURCE_HASHES_MUST_BE_ORDERED_OBJECT_ARRAY')
        return [pscustomobject][ordered]@{ valid = $false; caller_hashes = @(); defects = @($defects) }
    }
    $values = @($Actual)
    if ($values.Count -ne $expected.Count) { $defects.Add('CRITICAL_SOURCE_HASHES_KEY_SET_MUST_MATCH_FIXED_INVENTORY') }
    for ($index = 0; $index -lt $expected.Count; $index++) {
        if ($index -ge $values.Count) { break }
        $pathValue = Get-LiveGateValue $values[$index] 'path' $null
        $hashValue = Get-LiveGateValue $values[$index] 'sha256' $null
        if ($pathValue -isnot [string] -or -not [string]::Equals([string]$pathValue, $expected[$index].path, [StringComparison]::Ordinal)) {
            $defects.Add("CRITICAL_SOURCE_HASHES_PATH_MISMATCH_AT_INDEX_$index")
        }
        if ($hashValue -isnot [string] -or -not ([string]$hashValue -cmatch '^[0-9A-F]{64}$')) {
            $defects.Add("CRITICAL_SOURCE_HASHES_SHA256_FORMAT_MISMATCH_AT_INDEX_$index")
        } elseif (-not [string]::Equals([string]$hashValue, $expected[$index].sha256, [StringComparison]::Ordinal)) {
            $defects.Add("CRITICAL_SOURCE_HASHES_SHA256_MISMATCH_AT_INDEX_$index")
        }
    }
    [pscustomobject][ordered]@{
        valid = ($defects.Count -eq 0)
        caller_hashes = @($values)
        defects = @($defects)
    }
}

function Test-LiveGateCurrentCriticalSourceHashes {
    $constants = Get-LiveExecutionAuthorizationGateConstants
    $expected = @($constants.critical_source_hashes)
    $defects = [Collections.Generic.List[string]]::new()
    $hashes = [Collections.Generic.List[object]]::new()
    $root = Get-LiveGateRepositoryRoot
    $rootWithSeparator = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

    for ($index = 0; $index -lt $expected.Count; $index++) {
        $declaredRelativePath = [string]$expected[$index].path
        $relativePath = $declaredRelativePath
        if ($null -ne $script:LiveGateSourceIntegrityPathOverride -and $script:LiveGateSourceIntegrityPathOverride.ContainsKey($declaredRelativePath)) {
            $relativePath = [string]$script:LiveGateSourceIntegrityPathOverride[$declaredRelativePath]
        }
        if ([IO.Path]::IsPathRooted($relativePath)) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_PATH_ROOTED_AT_INDEX_$index")
            continue
        }
        $fullPath = [IO.Path]::GetFullPath((Join-Path $root $relativePath))
        if (-not $fullPath.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_PATH_TRAVERSAL_AT_INDEX_$index")
            continue
        }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_MISSING_AT_INDEX_$index")
            continue
        }
        $item = Get-Item -LiteralPath $fullPath -Force
        if ($item -isnot [IO.FileInfo]) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_NOT_REGULAR_FILE_AT_INDEX_$index")
            continue
        }
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_REPARSEPOINT_AT_INDEX_$index")
            continue
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $hash = ConvertTo-LiveGateHexSha256 -Bytes ($sha.ComputeHash([IO.File]::ReadAllBytes($fullPath)))
        } finally {
            $sha.Dispose()
        }
        $hashes.Add([pscustomobject][ordered]@{ path = $declaredRelativePath; sha256 = $hash })
        if (-not [string]::Equals($hash, [string]$expected[$index].sha256, [StringComparison]::Ordinal)) {
            $defects.Add("CURRENT_CRITICAL_SOURCE_SHA256_MISMATCH_AT_INDEX_$index")
        }
    }

    [pscustomobject][ordered]@{
        valid = ($defects.Count -eq 0)
        current_hashes = @($hashes)
        defects = @($defects)
        repository_root = $root
        hash_algorithm = 'SHA256'
        path_resolution_semantics = 'REPOSITORY_RELATIVE_REGULAR_FILE_NO_REPARSEPOINT_NO_TRAVERSAL'
    }
}

function Get-LiveGateRequestFingerprint {
    param([Parameter(Mandatory)][object]$Request)
    $hashPairs = @()
    foreach ($item in @((Get-LiveGateValue $Request 'critical_source_hashes' @()))) {
        $hashPairs += ([string](Get-LiveGateValue $item 'path' '') + '=' + [string](Get-LiveGateValue $item 'sha256' ''))
    }
    @(
        [string](Get-LiveGateValue $Request 'operation' ''),
        (@(Get-LiveGateValue $Request 'target_chain' $null) -join '|'),
        [string](Get-LiveGateValue $Request 'shared_container_id' ''),
        [string](Get-LiveGateValue $Request 'operator_confirmation_id' ''),
        [string](Get-LiveGateValue $Request 'live_authorization_phrase' ''),
        [string](Get-LiveGateValue $Request 'task_8e_evidence_sha256' ''),
        [string](Get-LiveGateValue $Request 'task_8f_evidence_sha256' ''),
        [string](Get-LiveGateValue $Request 'task_8g_evidence_sha256' ''),
        [string](Get-LiveGateValue $Request 'task_8g_audited_implementation_commit' ''),
        ($hashPairs -join '|'),
        [string](Test-LiveGateLiteralBooleanTrue (Get-LiveGateValue $Request 'rollback_recovery_reviewed' $null)),
        [string](Test-LiveGateLiteralBooleanTrue (Get-LiveGateValue $Request 'one_shot_attempt_understood' $null))
    ) -join "`n"
}

function Test-LiveExecutionAuthorizationGateRequest {
    param([AllowNull()][object]$Request)
    $c = Get-LiveExecutionAuthorizationGateConstants
    $defects = [Collections.Generic.List[string]]::new()
    $operation = [string](Get-LiveGateValue $Request 'operation' '')
    $targetChain = Get-LiveGateValue $Request 'target_chain' $null
    $containerId = [string](Get-LiveGateValue $Request 'shared_container_id' '')
    $operatorId = [string](Get-LiveGateValue $Request 'operator_confirmation_id' '')
    $phrase = [string](Get-LiveGateValue $Request 'live_authorization_phrase' '')
    $task8e = [string](Get-LiveGateValue $Request 'task_8e_evidence_sha256' '')
    $task8f = [string](Get-LiveGateValue $Request 'task_8f_evidence_sha256' '')
    $task8g = [string](Get-LiveGateValue $Request 'task_8g_evidence_sha256' '')
    $auditedCommit = [string](Get-LiveGateValue $Request 'task_8g_audited_implementation_commit' '')
    $sourceHashes = Get-LiveGateValue $Request 'critical_source_hashes' $null
    $recoveryProperty = $Request.PSObject.Properties.Item('rollback_recovery_reviewed')
    $oneShotProperty = $Request.PSObject.Properties.Item('one_shot_attempt_understood')
    $recoveryValue = $null
    if ($null -ne $recoveryProperty) { $recoveryValue = $recoveryProperty.Value }
    $oneShotValue = $null
    if ($null -ne $oneShotProperty) { $oneShotValue = $oneShotProperty.Value }
    $recovery = ($recoveryValue -is [System.Boolean] -and $recoveryValue -eq $true)
    $oneShot = ($oneShotValue -is [System.Boolean] -and $oneShotValue -eq $true)
    $callerHashValidation = Test-LiveGateCallerCriticalSourceHashes -Actual $sourceHashes
    $currentHashValidation = Test-LiveGateCurrentCriticalSourceHashes

    if (-not [string]::Equals($operation, $c.operation, [StringComparison]::Ordinal)) { $defects.Add('operation') }
    if (-not (Test-LiveGateExactArray -Actual $targetChain -Expected $c.accepted_ordered_target_chain)) { $defects.Add('target_chain') }
    if (-not [string]::Equals($containerId, $c.shared_container_id, [StringComparison]::Ordinal)) { $defects.Add('shared_container_id') }
    if (-not [string]::Equals($operatorId, $c.operator_confirmation_id, [StringComparison]::Ordinal)) { $defects.Add('operator_confirmation_id') }
    if (-not [string]::Equals($phrase, $c.live_authorization_phrase, [StringComparison]::Ordinal)) { $defects.Add('live_authorization_phrase') }
    if (-not [string]::Equals($task8e, $c.task_8e_evidence_sha256, [StringComparison]::Ordinal)) { $defects.Add('task_8e_evidence_sha256') }
    if (-not [string]::Equals($task8f, $c.task_8f_evidence_sha256, [StringComparison]::Ordinal)) { $defects.Add('task_8f_evidence_sha256') }
    if (-not [string]::Equals($task8g, $c.task_8g_evidence_sha256, [StringComparison]::Ordinal)) { $defects.Add('task_8g_evidence_sha256') }
    if (-not [string]::Equals($auditedCommit, $c.task_8g_audited_implementation_commit, [StringComparison]::Ordinal)) { $defects.Add('task_8g_audited_implementation_commit') }
    if (-not $callerHashValidation.valid) { $defects.Add('critical_source_hashes') }
    if (-not $currentHashValidation.valid) { $defects.Add('current_critical_source_hashes') }
    if (-not $recovery) { $defects.Add('ROLLBACK_RECOVERY_REVIEWED_MUST_BE_LITERAL_BOOLEAN_TRUE') }
    if (-not $oneShot) { $defects.Add('ONE_SHOT_ATTEMPT_UNDERSTOOD_MUST_BE_LITERAL_BOOLEAN_TRUE') }

    [pscustomobject][ordered]@{
        operation = $operation
        ordered_target_chain = @($targetChain)
        container_id = $containerId
        operator_confirmation_identity = $operatorId
        live_authorization_phrase_match = [string]::Equals($phrase, $c.live_authorization_phrase, [StringComparison]::Ordinal)
        task_8e_evidence_identity = $task8e
        task_8f_evidence_identity = $task8f
        task_8g_evidence_identity = $task8g
        audited_implementation_commit = $auditedCommit
        fixed_expected_critical_source_inventory = @($c.critical_source_hashes)
        critical_source_hashes = @($sourceHashes)
        caller_supplied_critical_source_hashes = @($callerHashValidation.caller_hashes)
        caller_supplied_hash_map_valid = $callerHashValidation.valid
        caller_supplied_hash_map_defects = @($callerHashValidation.defects)
        current_file_hashes = @($currentHashValidation.current_hashes)
        current_file_hashes_valid = $currentHashValidation.valid
        current_file_hash_defects = @($currentHashValidation.defects)
        runtime_current_file_hashing_enabled = $true
        hash_algorithm = 'SHA256'
        caller_map_compared_to_accepted_map = $true
        current_file_map_compared_to_accepted_map = $true
        caller_map_compared_to_current_file_map = $true
        fixed_externally_validated_root_of_trust_inventory = @($c.externally_validated_root_of_trust_paths)
        root_of_trust_classification = 'DEPENDENT_SOURCE_FILES_RUNTIME_VALIDATED_GATE_SOURCE_EXTERNALLY_VALIDATED'
        path_resolution_semantics = $currentHashValidation.path_resolution_semantics
        one_shot_semantics = 'PROCESS_BOUND_REFERENCE_IDENTITY_BOUND_ONE_ATTEMPT_ONLY'
        rollback_recovery_reviewed_runtime_type = Get-LiveGateRuntimeTypeName $recoveryValue
        one_shot_attempt_understood_runtime_type = Get-LiveGateRuntimeTypeName $oneShotValue
        rollback_recovery_reviewed = $recovery
        one_shot_attempt_understood = $oneShot
        rollback_recovery_reviewed_exact_true = $recovery
        one_shot_attempt_understood_exact_true = $oneShot
        production_provider_registered = $false
        production_provider_selected = $false
        production_provider_constructed = $false
        production_provider_loaded = $false
        production_provider_invoked = $false
        production_provider_still_unavailable = $true
        live_invocation_performed = $false
        counters = New-LiveGateZeroCounters
        defects = @($defects)
        valid = ($defects.Count -eq 0)
    }
}

function New-ChatpadOneShotLiveNativeApplyAuthorization {
    param([Parameter(Mandatory)][object]$Request)
    $summary = Test-LiveExecutionAuthorizationGateRequest -Request $Request
    if (-not $summary.valid) {
        return [pscustomobject][ordered]@{
            result = 'LIVE_AUTHORIZATION_REJECTED_FAIL_CLOSED'
            authorization_issued = $false
            authorization = $null
            pre_authorization_summary = $summary
        }
    }
    $authorization = [Chatpad.LiveAuthorization.LiveAuthorizationRegistry]::CreateOneShotLiveNativeApplyAuthorization((Get-LiveGateRequestFingerprint -Request $Request))
    [pscustomobject][ordered]@{
        result = 'ONE_SHOT_LIVE_NATIVE_APPLY_AUTHORIZATION_ISSUED_NOT_INVOKED'
        authorization_issued = $true
        authorization = $authorization
        authorization_type = 'Chatpad.LiveAuthorization.LiveNativeApplyAuthorization'
        pre_authorization_summary = $summary
    }
}

function Invoke-TestOnlyLiveGateRecordingConsumer {
    param(
        [Parameter(Mandatory)][object]$Request,
        [AllowNull()][object]$Authorization,
        [ValidateSet('Success','Failure','Exception','CleanupFailure')][string]$Outcome = 'Success',
        [AllowNull()][object]$RaceReady = $null,
        [AllowNull()][object]$RaceGo = $null
    )
    $summary = Test-LiveExecutionAuthorizationGateRequest -Request $Request
    if (-not $summary.valid) {
        return [pscustomobject][ordered]@{ result = 'REQUEST_REJECTED_NO_RECORDING_CONSUMPTION'; authorization_consumed = $false; recording_consumed = $false; provider_call_count = 0; counters = New-LiveGateZeroCounters; summary = $summary }
    }
    if ($null -ne $RaceReady -and $null -ne $RaceGo) { [void]$RaceReady.Signal(); $RaceGo.Wait() }
    if ($Authorization -isnot [Chatpad.LiveAuthorization.LiveNativeApplyAuthorization] -or -not [Chatpad.LiveAuthorization.LiveAuthorizationRegistry]::TryConsumeOneShotLiveNativeApplyAuthorization($Authorization, (Get-LiveGateRequestFingerprint -Request $Request))) {
        return [pscustomobject][ordered]@{ result = 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL'; authorization_consumed = $true; recording_consumed = $false; provider_call_count = 0; counters = New-LiveGateZeroCounters; summary = $summary }
    }
    if ($Outcome -eq 'Exception') { throw [InvalidOperationException]::new('OFFLINE_LIVE_GATE_RECORDING_CONSUMER_EXCEPTION_AFTER_CONSUME') }
    if ($Outcome -eq 'CleanupFailure') { throw [InvalidOperationException]::new('OFFLINE_LIVE_GATE_RECORDING_CONSUMER_CLEANUP_FAILURE_AFTER_CONSUME') }
    [pscustomobject][ordered]@{
        result = if ($Outcome -eq 'Success') { 'OFFLINE_RECORDING_CONSUMER_COMPLETED_NOT_NATIVE' } else { 'OFFLINE_RECORDING_CONSUMER_FAILED_NOT_NATIVE' }
        authorization_consumed = $true
        recording_consumed = $true
        provider_call_count = if ($Outcome -eq 'Success') { 1 } else { 0 }
        counters = New-LiveGateZeroCounters
        production_provider_registered = $false
        production_provider_selected = $false
        production_provider_constructed = $false
        production_provider_loaded = $false
        production_provider_invoked = $false
        live_invocation_performed = $false
        summary = $summary
    }
}

Export-ModuleMember -Function @('New-ChatpadOneShotLiveNativeApplyAuthorization')
