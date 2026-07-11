[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$ExecuteLiveApply,
    [AllowNull()][object]$Authorization
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ChatpadOneShotLiveApplyGateModule = $null

function Import-ChatpadLiveApplyAuthorizationGate {
    if ($null -eq $script:ChatpadOneShotLiveApplyGateModule) {
        $gatePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadLiveExecutionAuthorizationGate.psm1'
        Import-Module $gatePath -Force
        $script:ChatpadOneShotLiveApplyGateModule = Get-Module -Name ChatpadLiveExecutionAuthorizationGate | Select-Object -First 1
    }
    $script:ChatpadOneShotLiveApplyGateModule
}

function Get-ChatpadLiveApplyValue {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties.Item($Name)
    if ($null -eq $property) { return $Default }
    $property.Value
}

function Get-ChatpadLiveApplyObject {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties.Item($Name)
    if ($null -eq $property) { return $Default }
    ,$property.Value
}

function Get-ChatpadLiveApplyArray {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Object) { return @() }
    $property = $Object.PSObject.Properties.Item($Name)
    if ($null -eq $property -or $null -eq $property.Value) { return @() }
    @($property.Value)
}

function Test-ChatpadLiveApplyExactArray {
    param([AllowNull()][object]$Actual, [Parameter(Mandatory)][string[]]$Expected)
    if ($null -eq $Actual -or $Actual -is [string]) { return $false }
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($values[$index] -isnot [string] -or -not [string]::Equals([string]$values[$index], $Expected[$index], [StringComparison]::Ordinal)) { return $false }
    }
    $true
}

function Get-ChatpadLiveApplySourceHash {
    param([Parameter(Mandatory)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "Rooted source path rejected: $RelativePath" }
    $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $fullPath = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    $rootWithSeparator = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootWithSeparator, [StringComparison]::OrdinalIgnoreCase)) { throw "Source path traversal rejected: $RelativePath" }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Source path missing: $RelativePath" }
    (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash
}

function New-ChatpadLiveApplyZeroCounters {
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
    }
}

function New-ChatpadOneShotLiveApplyAuthorizationRequest {
    $gateModule = Import-ChatpadLiveApplyAuthorizationGate
    $constants = & $gateModule { Get-LiveExecutionAuthorizationGateConstants }
    [pscustomobject][ordered]@{
        operation = $constants.operation
        target_chain = @($constants.accepted_ordered_target_chain)
        shared_container_id = $constants.shared_container_id
        operator_confirmation_id = $constants.operator_confirmation_id
        live_authorization_phrase = $constants.live_authorization_phrase
        task_8e_evidence_sha256 = $constants.task_8e_evidence_sha256
        task_8f_evidence_sha256 = $constants.task_8f_evidence_sha256
        task_8g_evidence_sha256 = $constants.task_8g_evidence_sha256
        task_8g_audited_implementation_commit = $constants.task_8g_audited_implementation_commit
        critical_source_hashes = @($constants.critical_source_hashes)
        rollback_recovery_reviewed = $true
        one_shot_attempt_understood = $true
    }
}

function New-ChatpadOneShotLiveApplyExecutorContract {
    $gateModule = Import-ChatpadLiveApplyAuthorizationGate
    $constants = & $gateModule { Get-LiveExecutionAuthorizationGateConstants }
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-one-shot-live-native-apply-executor-contract-v1'
        operation = 'APPLY'
        target_chain = @($constants.accepted_ordered_target_chain)
        shared_container_id = $constants.shared_container_id
        operator_confirmation_id = $constants.operator_confirmation_id
        task_8e_evidence_path = $constants.task_8e_evidence_path
        task_8e_evidence_sha256 = $constants.task_8e_evidence_sha256
        task_8f_evidence_path = $constants.task_8f_evidence_path
        task_8f_evidence_sha256 = $constants.task_8f_evidence_sha256
        task_8g_evidence_path = $constants.task_8g_evidence_path
        task_8g_evidence_sha256 = $constants.task_8g_evidence_sha256
        task_8g_audited_implementation_commit = $constants.task_8g_audited_implementation_commit
        task_8h_evidence_path = 'docs/evidence/live-execution-authorization-gate-task-8h-1.json'
        task_8h_evidence_sha256 = '2EAC8D3C707C53F77859620DC9D7D43903DC61F334774898BBFD56944977DBF2'
        task_8h_audited_implementation_commit = '98cb71a37a099e83ba2452017b7024cce69bc061'
        gate_authorization_request = New-ChatpadOneShotLiveApplyAuthorizationRequest
        runtime_critical_source_hashes = @($constants.critical_source_hashes)
        externally_validated_task_8h_root_source_hashes = @(
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadLiveExecutionAuthorizationGate.psm1'; sha256 = '2EC06735E8397A4562A1538F763C914C62B9F933DE6624333F053BD4165EE42E' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadLiveAuthorizationRegistry.cs'; sha256 = '86BE5EF2D1A7211A48B60B05F6AF66750CA952F1FAA46FBCF6DFECFDF9F5A687' }
        )
        task_8f_backend_path = 'tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1'
        task_8f_integration_method = 'FUTURE_PRODUCTION_PATH_MUST_ENTER_TASK_8F_BACKEND_AFTER_AUTHORIZATION_CONSUMPTION_ONLY'
        task_8i_1a_production_provider_construction_enabled = $false
    }
}

function Test-ChatpadOneShotLiveApplySourceHashInventory {
    param([AllowNull()][object]$Actual, [Parameter(Mandatory)][object[]]$Expected, [switch]$HashCurrentFiles)
    $defects = [Collections.Generic.List[string]]::new()
    if ($null -eq $Actual -or $Actual -is [string]) {
        $defects.Add('SOURCE_HASHES_MUST_BE_ORDERED_OBJECT_ARRAY')
        return [pscustomobject][ordered]@{ valid = $false; defects = @($defects); hashes = @() }
    }
    $values = @($Actual)
    if ($values.Count -eq 1 -and $values[0] -is [Array]) { $values = @($values[0]) }
    $Expected = @($Expected)
    if ($Expected.Count -eq 1 -and $Expected[0] -is [Array]) { $Expected = @($Expected[0]) }
    if ($values.Count -ne $Expected.Count) { $defects.Add('SOURCE_HASHES_KEY_SET_MUST_MATCH_FIXED_INVENTORY') }
    $hashes = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($index -ge $values.Count) { break }
        $path = Get-ChatpadLiveApplyValue $values[$index] 'path' ''
        $sha = Get-ChatpadLiveApplyValue $values[$index] 'sha256' ''
        if ($path -isnot [string] -or -not [string]::Equals([string]$path, [string]$Expected[$index].path, [StringComparison]::Ordinal)) { $defects.Add("SOURCE_HASH_PATH_MISMATCH_AT_INDEX_$index") }
        if ($sha -isnot [string] -or -not ([string]$sha -cmatch '^[0-9A-F]{64}$')) {
            $defects.Add("SOURCE_HASH_SHA256_FORMAT_MISMATCH_AT_INDEX_$index")
        } elseif (-not [string]::Equals([string]$sha, [string]$Expected[$index].sha256, [StringComparison]::Ordinal)) {
            $defects.Add("SOURCE_HASH_SHA256_MISMATCH_AT_INDEX_$index")
        }
        if ($HashCurrentFiles) {
            try {
                $current = Get-ChatpadLiveApplySourceHash -RelativePath ([string]$Expected[$index].path)
                $hashes.Add([pscustomobject][ordered]@{ path = [string]$Expected[$index].path; sha256 = $current })
                if (-not [string]::Equals($current, [string]$Expected[$index].sha256, [StringComparison]::Ordinal)) { $defects.Add("CURRENT_SOURCE_HASH_MISMATCH_AT_INDEX_$index") }
            } catch {
                $defects.Add("CURRENT_SOURCE_HASH_UNAVAILABLE_AT_INDEX_$index")
            }
        }
    }
    [pscustomobject][ordered]@{ valid = ($defects.Count -eq 0); defects = @($defects); hashes = @($hashes) }
}

function Test-ChatpadOneShotLiveApplyExecutorContract {
    param([AllowNull()][object]$Contract)
    $expected = New-ChatpadOneShotLiveApplyExecutorContract
    $defects = [Collections.Generic.List[string]]::new()
    if ($null -eq $Contract) { $defects.Add('contract') }
    $operation = [string](Get-ChatpadLiveApplyValue $Contract 'operation' '')
    if (-not [string]::Equals($operation, $expected.operation, [StringComparison]::Ordinal)) { $defects.Add('operation') }
    if (-not (Test-ChatpadLiveApplyExactArray -Actual (Get-ChatpadLiveApplyArray $Contract 'target_chain') -Expected @($expected.target_chain))) { $defects.Add('target_chain') }
    foreach ($name in @('shared_container_id','operator_confirmation_id','task_8e_evidence_path','task_8e_evidence_sha256','task_8f_evidence_path','task_8f_evidence_sha256','task_8g_evidence_path','task_8g_evidence_sha256','task_8g_audited_implementation_commit','task_8h_evidence_path','task_8h_evidence_sha256','task_8h_audited_implementation_commit','task_8f_backend_path','task_8f_integration_method')) {
        if (-not [string]::Equals([string](Get-ChatpadLiveApplyValue $Contract $name ''), [string](Get-ChatpadLiveApplyValue $expected $name ''), [StringComparison]::Ordinal)) { $defects.Add($name) }
    }
    if ([bool](Get-ChatpadLiveApplyValue $Contract 'task_8i_1a_production_provider_construction_enabled' $true)) { $defects.Add('task_8i_1a_production_provider_construction_enabled') }
    $runtimeHashValidation = Test-ChatpadOneShotLiveApplySourceHashInventory -Actual (Get-ChatpadLiveApplyArray $Contract 'runtime_critical_source_hashes') -Expected @($expected.runtime_critical_source_hashes) -HashCurrentFiles
    $rootHashValidation = Test-ChatpadOneShotLiveApplySourceHashInventory -Actual (Get-ChatpadLiveApplyArray $Contract 'externally_validated_task_8h_root_source_hashes') -Expected @($expected.externally_validated_task_8h_root_source_hashes) -HashCurrentFiles
    if (-not $runtimeHashValidation.valid) { $defects.Add('runtime_critical_source_hashes') }
    if (-not $rootHashValidation.valid) { $defects.Add('externally_validated_task_8h_root_source_hashes') }
    $gateModule = Import-ChatpadLiveApplyAuthorizationGate
    $gateRequest = Get-ChatpadLiveApplyObject $Contract 'gate_authorization_request' $null
    $gateSummary = & $gateModule { param($request) Test-LiveExecutionAuthorizationGateRequest -Request $request } $gateRequest
    if (-not $gateSummary.valid) { $defects.Add('gate_authorization_request') }
    [pscustomobject][ordered]@{
        valid = ($defects.Count -eq 0)
        defects = @($defects)
        operation = $operation
        target_chain = @(Get-ChatpadLiveApplyArray $Contract 'target_chain')
        shared_container_id = [string](Get-ChatpadLiveApplyValue $Contract 'shared_container_id' '')
        task_8g_audited_implementation_commit = [string](Get-ChatpadLiveApplyValue $Contract 'task_8g_audited_implementation_commit' '')
        task_8h_audited_implementation_commit = [string](Get-ChatpadLiveApplyValue $Contract 'task_8h_audited_implementation_commit' '')
        runtime_hash_validation = $runtimeHashValidation
        task_8h_root_hash_validation = $rootHashValidation
        gate_authorization_summary = $gateSummary
    }
}

function New-ChatpadOneShotLiveApplyResult {
    param(
        [Parameter(Mandatory)][string]$FinalStatus,
        [AllowNull()][object]$Contract,
        [AllowNull()][object]$ContractValidation = $null,
        [bool]$AuthorizationConsumed = $false,
        [int]$ProviderConstructionCount = 0,
        [int]$NativeInvocationCount = 0,
        [int]$ApplyAttemptCount = 0,
        [int]$RetryCount = 0,
        [string]$CleanupResult = 'NOT_STARTED',
        [string]$ErrorCategory = '',
        [AllowNull()][object]$NativeErrorCode = $null,
        [string[]]$StatusHistory = @(),
        [string[]]$EventOrder = @(),
        [int]$FakeConstructionMarkerCount = 0,
        [int]$FakeInvocationMarkerCount = 0,
        [string]$ExecutionMode = 'PRODUCTION_DISABLED'
    )
    if ($null -eq $Contract) { $Contract = New-ChatpadOneShotLiveApplyExecutorContract }
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-one-shot-live-native-apply-executor-result-v1'
        final_status = $FinalStatus
        status_history = @($StatusHistory)
        execution_mode = $ExecutionMode
        operation = [string](Get-ChatpadLiveApplyValue $Contract 'operation' 'APPLY')
        ordered_target_chain = @(Get-ChatpadLiveApplyArray $Contract 'target_chain')
        container_id = [string](Get-ChatpadLiveApplyValue $Contract 'shared_container_id' '{828F4587-006F-5AD1-B169-6AF57905DFDE}')
        audited_task_8g_commit = [string](Get-ChatpadLiveApplyValue $Contract 'task_8g_audited_implementation_commit' '79ec174dabd7e73f2d01021168921021bc118702')
        audited_task_8h_commit = [string](Get-ChatpadLiveApplyValue $Contract 'task_8h_audited_implementation_commit' '98cb71a37a099e83ba2452017b7024cce69bc061')
        task_8e_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8e_evidence_sha256' '')
        task_8f_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8f_evidence_sha256' '')
        task_8g_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8g_evidence_sha256' '')
        task_8h_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8h_evidence_sha256' '')
        authorization_consumed = $AuthorizationConsumed
        provider_construction_count = $ProviderConstructionCount
        native_invocation_count = $NativeInvocationCount
        apply_attempt_count = $ApplyAttemptCount
        retry_count = $RetryCount
        cleanup_result = $CleanupResult
        error_category = $ErrorCategory
        native_error_code = $NativeErrorCode
        event_order = @($EventOrder)
        fake_construction_marker_count = $FakeConstructionMarkerCount
        fake_invocation_marker_count = $FakeInvocationMarkerCount
        production_provider_constructed = $false
        production_provider_escaped = $false
        authorization_object_exposed = $false
        reusable_execution_state_exposed = $false
        counters = New-ChatpadLiveApplyZeroCounters
        contract_validation = $ContractValidation
    }
}

function Invoke-ChatpadOneShotLiveApplyExecutorCore {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)][ValidateSet('ProductionDisabled','TestFake')][string]$ExecutionMode,
        [AllowNull()][object]$Authorization,
        [AllowNull()][object]$Contract = $null,
        [ValidateSet('Success','ConstructionFailure','InvocationFailure','Exception','ResultCaptureFailure','CleanupFailure')][string]$FakeOutcome = 'Success',
        [AllowNull()][object]$RaceReady = $null,
        [AllowNull()][object]$RaceGo = $null
    )
    if ($null -eq $Contract) { $Contract = New-ChatpadOneShotLiveApplyExecutorContract }
    $events = [Collections.Generic.List[string]]::new()
    $history = [Collections.Generic.List[string]]::new()
    $contractValidation = Test-ChatpadOneShotLiveApplyExecutorContract -Contract $Contract
    if (-not $contractValidation.valid) {
        $history.Add('PRECONDITION_REJECTED')
        return New-ChatpadOneShotLiveApplyResult -FinalStatus 'PRECONDITION_REJECTED' -Contract $Contract -ContractValidation $contractValidation -StatusHistory @($history) -EventOrder @($events) -ErrorCategory 'CONTRACT_REJECTED' -ExecutionMode $ExecutionMode
    }
    $events.Add('contract_validated')
    $gateModule = Import-ChatpadLiveApplyAuthorizationGate
    $fingerprint = & $gateModule { param($request) Get-LiveGateRequestFingerprint -Request $request } (Get-ChatpadLiveApplyValue $Contract 'gate_authorization_request' $null)
    if ($Authorization -isnot [Chatpad.LiveAuthorization.LiveNativeApplyAuthorization]) {
        $history.Add('AUTHORIZATION_REJECTED')
        return New-ChatpadOneShotLiveApplyResult -FinalStatus 'AUTHORIZATION_REJECTED' -Contract $Contract -ContractValidation $contractValidation -StatusHistory @($history) -EventOrder @($events) -ErrorCategory 'AUTHORIZATION_TYPE_OR_REGISTRY_REJECTED' -ExecutionMode $ExecutionMode
    }
    $events.Add('authorization_validated')
    if ($ExecutionMode -eq 'ProductionDisabled') {
        $history.Add('PRECONDITION_REJECTED')
        return New-ChatpadOneShotLiveApplyResult -FinalStatus 'PRECONDITION_REJECTED' -Contract $Contract -ContractValidation $contractValidation -StatusHistory @($history) -EventOrder @($events) -ErrorCategory 'TASK_8I_1A_PRODUCTION_PROVIDER_CONSTRUCTION_DISABLED' -ExecutionMode $ExecutionMode
    }
    if ($null -ne $RaceReady -and $null -ne $RaceGo) {
        [void]$RaceReady.Signal()
        [void]$RaceGo.Wait()
    }
    if (-not [Chatpad.LiveAuthorization.LiveAuthorizationRegistry]::TryConsumeOneShotLiveNativeApplyAuthorization($Authorization, $fingerprint)) {
        $history.Add('AUTHORIZATION_REJECTED')
        return New-ChatpadOneShotLiveApplyResult -FinalStatus 'AUTHORIZATION_REJECTED' -Contract $Contract -ContractValidation $contractValidation -StatusHistory @($history) -EventOrder @($events) -ErrorCategory 'AUTHORIZATION_REPLAY_OR_FINGERPRINT_REJECTED' -ExecutionMode $ExecutionMode
    }
    $events.Add('authorization_consumed')
    $history.Add('AUTHORIZATION_CONSUMED')
    $fakeConstruction = 0
    $fakeInvocation = 0
    $cleanup = 'NOT_STARTED'
    try {
        if ($FakeOutcome -eq 'ConstructionFailure') {
            return New-ChatpadOneShotLiveApplyResult -FinalStatus 'PROVIDER_CONSTRUCTION_FAILED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'PROVIDER_CONSTRUCTION_FAILED') -EventOrder @($events) -CleanupResult $cleanup -ErrorCategory 'FAKE_CONSTRUCTION_FAILURE' -ExecutionMode 'FAKE_ONLY'
        }
        $fakeConstruction = 1
        $events.Add('fake_construction_marker')
        if ($FakeOutcome -eq 'Exception') { throw [InvalidOperationException]::new('OFFLINE_FAKE_EXECUTOR_EXCEPTION_AFTER_CONSUME') }
        if ($FakeOutcome -eq 'InvocationFailure') {
            $cleanup = 'COMPLETED'
            $events.Add('cleanup_completed')
            return New-ChatpadOneShotLiveApplyResult -FinalStatus 'NATIVE_APPLY_FAILED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'NATIVE_APPLY_FAILED') -EventOrder @($events) -CleanupResult $cleanup -ErrorCategory 'FAKE_INVOCATION_FAILURE' -FakeConstructionMarkerCount $fakeConstruction -ExecutionMode 'FAKE_ONLY'
        }
        $fakeInvocation = 1
        $events.Add('fake_invocation_marker')
        if ($FakeOutcome -eq 'ResultCaptureFailure') {
            $cleanup = 'COMPLETED'
            $events.Add('cleanup_completed')
            return New-ChatpadOneShotLiveApplyResult -FinalStatus 'RESULT_CAPTURE_FAILED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'RESULT_CAPTURE_FAILED') -EventOrder @($events) -CleanupResult $cleanup -ErrorCategory 'FAKE_RESULT_CAPTURE_FAILURE' -FakeConstructionMarkerCount $fakeConstruction -FakeInvocationMarkerCount $fakeInvocation -ExecutionMode 'FAKE_ONLY'
        }
        $events.Add('result_captured')
        if ($FakeOutcome -eq 'CleanupFailure') {
            $cleanup = 'FAILED'
            return New-ChatpadOneShotLiveApplyResult -FinalStatus 'CLEANUP_FAILED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'CLEANUP_FAILED') -EventOrder @($events) -CleanupResult $cleanup -ErrorCategory 'FAKE_CLEANUP_FAILURE' -FakeConstructionMarkerCount $fakeConstruction -FakeInvocationMarkerCount $fakeInvocation -ExecutionMode 'FAKE_ONLY'
        }
        $cleanup = 'COMPLETED'
        $events.Add('cleanup_completed')
        New-ChatpadOneShotLiveApplyResult -FinalStatus 'NATIVE_APPLY_COMPLETED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'NATIVE_APPLY_COMPLETED') -EventOrder @($events) -CleanupResult $cleanup -FakeConstructionMarkerCount $fakeConstruction -FakeInvocationMarkerCount $fakeInvocation -ExecutionMode 'FAKE_ONLY'
    } catch {
        $cleanup = 'COMPLETED'
        $events.Add('cleanup_completed')
        New-ChatpadOneShotLiveApplyResult -FinalStatus 'NATIVE_APPLY_FAILED' -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -StatusHistory @($history + 'NATIVE_APPLY_FAILED') -EventOrder @($events) -CleanupResult $cleanup -ErrorCategory 'FAKE_THROWN_EXCEPTION' -NativeErrorCode $_.Exception.Message -FakeConstructionMarkerCount $fakeConstruction -FakeInvocationMarkerCount $fakeInvocation -ExecutionMode 'FAKE_ONLY'
    }
}

function Invoke-ChatpadOneShotLiveNativeApply {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [switch]$ExecuteLiveApply,
        [AllowNull()][object]$Authorization
    )
    $contract = New-ChatpadOneShotLiveApplyExecutorContract
    if (-not $ExecuteLiveApply) {
        return New-ChatpadOneShotLiveApplyResult -FinalStatus 'PRECONDITION_REJECTED' -Contract $contract -StatusHistory @('PRECONDITION_REJECTED') -ErrorCategory 'EXECUTE_LIVE_APPLY_SWITCH_REQUIRED'
    }
    Invoke-ChatpadOneShotLiveApplyExecutorCore -ExecutionMode ProductionDisabled -Authorization $Authorization -Contract $contract
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ChatpadOneShotLiveNativeApply -ExecuteLiveApply:$ExecuteLiveApply -Authorization $Authorization
}
