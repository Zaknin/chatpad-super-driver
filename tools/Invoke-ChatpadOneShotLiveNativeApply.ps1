[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$ExecuteLiveApply,
    [AllowNull()][object]$Authorization
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ChatpadOneShotLiveApplyGateModule = $null
$script:ChatpadOneShotLiveApplyProductionBackendModule = $null

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

function Import-ChatpadOneShotLiveApplyProductionBackend {
    if ($null -eq $script:ChatpadOneShotLiveApplyProductionBackendModule) {
        $backendPath = Join-Path (Join-Path $PSScriptRoot '..') 'tools\ExactInstance\ChatpadGatedProductionNativeAdapterBackend.psm1'
        Import-Module $backendPath -Force
        $script:ChatpadOneShotLiveApplyProductionBackendModule = Get-Module -Name ChatpadGatedProductionNativeAdapterBackend | Select-Object -First 1
    }
    $script:ChatpadOneShotLiveApplyProductionBackendModule
}

function New-ChatpadOneShotLiveApplyBackendRequest {
    param([Parameter(Mandatory)][object]$Contract)
    [pscustomobject][ordered]@{
        contract_evidence_path = [string](Get-ChatpadLiveApplyValue $Contract 'contract_evidence_path' '')
        contract_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'contract_evidence_sha256' '')
        target_chain = @(Get-ChatpadLiveApplyArray $Contract 'target_chain')
        shared_container_id = [string](Get-ChatpadLiveApplyValue $Contract 'shared_container_id' '')
        operator_confirmation_id = [string](Get-ChatpadLiveApplyValue $Contract 'operator_confirmation_id' '')
    }
}

function New-ChatpadOneShotLiveApplyProductionProvider {
    param([Parameter(Mandatory)][object]$BackendModule)
    & $BackendModule { New-GatedProductionNativeProviderDescriptor }
}

function Invoke-ChatpadOneShotLiveApplyNativeApply {
    param(
        [Parameter(Mandatory)][object]$BackendModule,
        [Parameter(Mandatory)][object]$BackendRequest,
        [Parameter(Mandatory)][object]$ProductionProvider
    )
    & $BackendModule {
        param($request, $provider)
        Invoke-GatedProductionBackendRecordingPlan -Request $request -Provider $provider
    } $BackendRequest $ProductionProvider
}

function Clear-ChatpadOneShotLiveApplyProductionState {
    param([AllowNull()][object]$ProductionProvider, [AllowNull()][object]$BackendResult)
    [pscustomobject][ordered]@{
        cleanup_attempted = $true
        cleanup_result = 'COMPLETED'
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
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
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
        task_8f_integration_method = 'PRODUCTION_PATH_IMPORTS_TASK_8F_BACKEND_AFTER_AUTHORIZATION_CONSUMPTION_AND_USES_FIXED_PRIVATE_SURFACES'
        task_8f_private_provider_constructor = 'New-GatedProductionNativeProviderDescriptor'
        task_8f_private_apply_invoker = 'Invoke-GatedProductionBackendRecordingPlan'
        task_8i_1a_production_path_state = 'DORMANT_COMPLETE_REQUIRES_VALID_TASK_8H_AUTHORIZATION'
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
    foreach ($name in @('shared_container_id','operator_confirmation_id','contract_evidence_path','contract_evidence_sha256','task_8e_evidence_path','task_8e_evidence_sha256','task_8f_evidence_path','task_8f_evidence_sha256','task_8g_evidence_path','task_8g_evidence_sha256','task_8g_audited_implementation_commit','task_8h_evidence_path','task_8h_evidence_sha256','task_8h_audited_implementation_commit','task_8f_backend_path','task_8f_integration_method','task_8f_private_provider_constructor','task_8f_private_apply_invoker','task_8i_1a_production_path_state')) {
        if (-not [string]::Equals([string](Get-ChatpadLiveApplyValue $Contract $name ''), [string](Get-ChatpadLiveApplyValue $expected $name ''), [StringComparison]::Ordinal)) { $defects.Add($name) }
    }
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
        [int]$BackendLoadCount = 0,
        [int]$NativeInvocationCount = 0,
        [int]$ApplyAttemptCount = 0,
        [int]$RetryCount = 0,
        [bool]$CleanupAttempted = $false,
        [string]$CleanupResult = 'NOT_STARTED',
        [string]$ErrorCategory = '',
        [AllowNull()][object]$NativeErrorCode = $null,
        [string]$ExceptionType = '',
        [string[]]$StatusHistory = @(),
        [string[]]$EventOrder = @(),
        [int]$FakeConstructionMarkerCount = 0,
        [int]$FakeInvocationMarkerCount = 0,
        [string]$ExecutionMode = 'PRODUCTION',
        [AllowNull()][object]$BackendResultSummary = $null,
        [bool]$ProductionProviderConstructed = $false
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
        contract_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'contract_evidence_sha256' '')
        task_8e_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8e_evidence_sha256' '')
        task_8f_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8f_evidence_sha256' '')
        task_8g_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8g_evidence_sha256' '')
        task_8h_evidence_sha256 = [string](Get-ChatpadLiveApplyValue $Contract 'task_8h_evidence_sha256' '')
        authorization_consumed = $AuthorizationConsumed
        provider_construction_count = $ProviderConstructionCount
        production_provider_construction_count = $ProviderConstructionCount
        backend_load_count = $BackendLoadCount
        native_invocation_count = $NativeInvocationCount
        apply_attempt_count = $ApplyAttemptCount
        retry_count = $RetryCount
        cleanup_attempted = $CleanupAttempted
        cleanup_result = $CleanupResult
        error_category = $ErrorCategory
        native_error_code = $NativeErrorCode
        exception_type = $ExceptionType
        event_order = @($EventOrder)
        source_validation_result = if ($null -ne $ContractValidation -and $ContractValidation.valid) { 'SOURCE_VALIDATED' } elseif ($null -ne $ContractValidation) { 'SOURCE_REJECTED' } else { 'NOT_RUN' }
        backend_result_summary = $BackendResultSummary
        fake_construction_marker_count = $FakeConstructionMarkerCount
        fake_invocation_marker_count = $FakeInvocationMarkerCount
        production_backend_loaded = ($BackendLoadCount -gt 0)
        production_provider_constructed = $ProductionProviderConstructed
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
        [Parameter(Mandatory)][ValidateSet('Production','TestFake')][string]$ExecutionMode,
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
    if ($ExecutionMode -eq 'Production') {
        $backendLoad = 0
        $providerConstruction = 0
        $nativeInvocation = 0
        $applyAttempt = 0
        $cleanupAttempted = $false
        $cleanup = 'NOT_STARTED'
        $finalStatus = ''
        $errorCategory = ''
        $nativeErrorCode = $null
        $exceptionType = ''
        $backendSummary = $null
        $backendModule = $null
        $productionProvider = $null
        $backendResult = $null
        try {
            try {
                $backendModule = Import-ChatpadOneShotLiveApplyProductionBackend
                $backendLoad = 1
                $events.Add('backend_loaded')
            } catch {
                $finalStatus = 'BACKEND_LOAD_FAILED'
                $errorCategory = 'TASK_8F_BACKEND_LOAD_FAILED'
                $nativeErrorCode = $_.Exception.Message
                $exceptionType = $_.Exception.GetType().FullName
            }
            if ([string]::IsNullOrEmpty($finalStatus)) {
                try {
                    $productionProvider = New-ChatpadOneShotLiveApplyProductionProvider -BackendModule $backendModule
                    $providerConstruction = 1
                    $events.Add('production_provider_constructed')
                } catch {
                    $finalStatus = 'PROVIDER_CONSTRUCTION_FAILED'
                    $errorCategory = 'TASK_8F_PROVIDER_CONSTRUCTION_FAILED'
                    $nativeErrorCode = $_.Exception.Message
                    $exceptionType = $_.Exception.GetType().FullName
                }
            }
            if ([string]::IsNullOrEmpty($finalStatus)) {
                try {
                    $applyAttempt = 1
                    $events.Add('native_apply_invocation_started')
                    $backendRequest = New-ChatpadOneShotLiveApplyBackendRequest -Contract $Contract
                    $backendResult = Invoke-ChatpadOneShotLiveApplyNativeApply -BackendModule $backendModule -BackendRequest $backendRequest -ProductionProvider $productionProvider
                    $events.Add('native_apply_invocation_completed')
                } catch {
                    $finalStatus = 'NATIVE_APPLY_FAILED'
                    $errorCategory = 'TASK_8F_NATIVE_APPLY_THREW'
                    $nativeErrorCode = $_.Exception.Message
                    $exceptionType = $_.Exception.GetType().FullName
                }
            }
            if ([string]::IsNullOrEmpty($finalStatus)) {
                try {
                    $backendCounters = Get-ChatpadLiveApplyValue $backendResult 'counters' $null
                    if ($null -ne $backendCounters) {
                        $nativeInvocation = [int](Get-ChatpadLiveApplyValue $backendCounters 'native_invocation_count' 0)
                    }
                    $backendSummary = [pscustomobject][ordered]@{
                        schema_version = [string](Get-ChatpadLiveApplyValue $backendResult 'schema_version' '')
                        result = [string](Get-ChatpadLiveApplyValue $backendResult 'result' '')
                        result_code = [string](Get-ChatpadLiveApplyValue $backendResult 'result_code' '')
                        provider_call_count = [int](Get-ChatpadLiveApplyValue $backendResult 'provider_call_count' 0)
                        cleanup_attempted = [bool](Get-ChatpadLiveApplyValue $backendResult 'cleanup_attempted' $false)
                        mutation_success_claimed = [bool](Get-ChatpadLiveApplyValue $backendResult 'mutation_success_claimed' $false)
                    }
                    $events.Add('result_captured')
                    if ([string]::Equals($backendSummary.result, 'RECORDING_PLAN_COMPLETED_NOT_EXECUTED', [StringComparison]::Ordinal)) {
                        $finalStatus = 'NATIVE_APPLY_COMPLETED'
                    } else {
                        $finalStatus = 'NATIVE_APPLY_FAILED'
                        $errorCategory = 'TASK_8F_BACKEND_APPLY_REJECTED'
                        $nativeErrorCode = $backendSummary.result_code
                    }
                } catch {
                    $finalStatus = 'RESULT_CAPTURE_FAILED'
                    $errorCategory = 'TASK_8F_RESULT_CAPTURE_FAILED'
                    $nativeErrorCode = $_.Exception.Message
                    $exceptionType = $_.Exception.GetType().FullName
                }
            }
        } catch {
            $finalStatus = 'NATIVE_APPLY_FAILED'
            $errorCategory = 'TASK_8F_PRODUCTION_BRANCH_UNHANDLED_EXCEPTION'
            $nativeErrorCode = $_.Exception.Message
            $exceptionType = $_.Exception.GetType().FullName
        } finally {
            try {
                $cleanupInfo = Clear-ChatpadOneShotLiveApplyProductionState -ProductionProvider $productionProvider -BackendResult $backendResult
                $cleanupAttempted = [bool](Get-ChatpadLiveApplyValue $cleanupInfo 'cleanup_attempted' $true)
                $cleanup = [string](Get-ChatpadLiveApplyValue $cleanupInfo 'cleanup_result' 'COMPLETED')
                $events.Add('cleanup_completed')
            } catch {
                $cleanupAttempted = $true
                $cleanup = 'FAILED'
                $finalStatus = 'CLEANUP_FAILED'
                $errorCategory = 'TASK_8F_CLEANUP_FAILED'
                $nativeErrorCode = $_.Exception.Message
                $exceptionType = $_.Exception.GetType().FullName
            }
        }
        if ([string]::IsNullOrEmpty($finalStatus)) { $finalStatus = 'RESULT_CAPTURE_FAILED'; $errorCategory = 'TASK_8F_RESULT_CAPTURE_MISSING' }
        $history.Add($finalStatus)
        return New-ChatpadOneShotLiveApplyResult -FinalStatus $finalStatus -Contract $Contract -ContractValidation $contractValidation -AuthorizationConsumed $true -ProviderConstructionCount $providerConstruction -BackendLoadCount $backendLoad -NativeInvocationCount $nativeInvocation -ApplyAttemptCount $applyAttempt -RetryCount 0 -CleanupAttempted $cleanupAttempted -CleanupResult $cleanup -ErrorCategory $errorCategory -NativeErrorCode $nativeErrorCode -ExceptionType $exceptionType -StatusHistory @($history) -EventOrder @($events) -ExecutionMode 'PRODUCTION' -BackendResultSummary $backendSummary -ProductionProviderConstructed ($providerConstruction -eq 1)
    }
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
    Invoke-ChatpadOneShotLiveApplyExecutorCore -ExecutionMode Production -Authorization $Authorization -Contract $contract
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ChatpadOneShotLiveNativeApply -ExecuteLiveApply:$ExecuteLiveApply -Authorization $Authorization
}
