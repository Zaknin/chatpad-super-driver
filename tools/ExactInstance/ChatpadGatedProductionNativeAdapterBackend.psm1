Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This module is source-only orchestration for a future separately authorized
# exact-instance backend.  It exports nothing and has no live provider, native
# library loading, device discovery, or process fallback.  The only callable
# seam is module-private and is used by the focused offline recording tests.

function Get-GatedProductionBackendConstants {
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-gated-production-native-adapter-backend-v1'
        production_backend_identity = 'chatpad-windows-exact-instance-adapter-v1'
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        task_8e_evidence_path = 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        target_chain = @(
            'USB\VID_045E&PID_028E\1C21F10',
            'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00',
            'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000'
        )
        selected_target_instance_id = 'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00'
        blocker = 'BLOCKED_NATIVE_ADAPTER_PRODUCTION_BACKEND_NOT_INDEPENDENTLY_AUDITED'
        apply_restore_steps = @(
            'SetupDiCreateDeviceInfoList',
            'SetupDiOpenDeviceInfoW',
            'SetupDiGetDeviceInstanceIdW',
            'SetupDiGetDevicePropertyW',
            'SetupDiGetDeviceRegistryPropertyW',
            'SetupDiBuildDriverInfoList',
            'SetupDiEnumDriverInfoW',
            'SetupDiGetDriverInfoDetailW',
            'SetupDiGetDriverInstallParamsW',
            'SetupDiSetSelectedDriverW',
            'DiInstallDevice',
            'SetupDiDestroyDriverInfoList',
            'SetupDiDestroyDeviceInfoList'
        )
    }
}

function Get-GatedProductionBackendProperty {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    Write-Output -NoEnumerate $property.Value
}

function New-GatedProductionBackendZeroCounters {
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

function Test-GatedProductionBackendExactArray {
    param([AllowNull()][object]$Actual, [Parameter(Mandatory)][string[]]$Expected)
    if ($Actual -is [string] -or $null -eq $Actual) { return $false }
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($values[$index] -isnot [string] -or -not [string]::Equals([string]$values[$index], $Expected[$index], [StringComparison]::Ordinal)) { return $false }
    }
    $true
}

function Test-GatedProductionBackendRequest {
    param([AllowNull()][object]$Request)
    $constants = Get-GatedProductionBackendConstants
    $contractPath = Get-GatedProductionBackendProperty $Request 'contract_evidence_path' ''
    $contractHash = Get-GatedProductionBackendProperty $Request 'contract_evidence_sha256' ''
    $chain = Get-GatedProductionBackendProperty $Request 'target_chain' $null
    $container = Get-GatedProductionBackendProperty $Request 'shared_container_id' ''
    $confirmation = Get-GatedProductionBackendProperty $Request 'operator_confirmation_id' ''
    $contractValid = ([string]::Equals([string]$contractPath, $constants.contract_evidence_path, [StringComparison]::Ordinal) -and [string]::Equals([string]$contractHash, $constants.contract_evidence_sha256, [StringComparison]::Ordinal))
    $targetValid = ((Test-GatedProductionBackendExactArray -Actual $chain -Expected $constants.target_chain) -and [string]::Equals([string]$container, $constants.shared_container_id, [StringComparison]::Ordinal) -and [string]::Equals([string]$confirmation, $constants.operator_confirmation_id, [StringComparison]::Ordinal))
    [pscustomobject][ordered]@{
        contract_validation_passed = $contractValid
        exact_target_validation_passed = $targetValid
        result_code = if (-not $contractValid) { 'CONTRACT_EVIDENCE_IDENTITY_REJECTED' } elseif (-not $targetValid) { 'EXACT_TARGET_REJECTED' } else { 'VALIDATED_RECORDING_SHIM_ONLY' }
    }
}

function New-GatedProductionNativeProviderDescriptor {
    # Deliberately non-invocable: the accepted declarations stay in the existing
    # audited NativeInterop source boundary until a later execution task grants
    # a distinct live authorization path.
    $constants = Get-GatedProductionBackendConstants
    [pscustomobject][ordered]@{
        provider_identity = $constants.production_backend_identity
        provider_kind = 'DECLARATION_BACKED_PRODUCTION_PROVIDER_SOURCE_ONLY'
        native_invocation_available = $false
        selected_by_default = $false
        constructed_during_import = $false
    }
}

function New-GatedProductionRecordingProvider {
    param([string]$FailAt = '', [string]$FailureCode = 'SIMULATED_NATIVE_PROVIDER_FAILURE')
    [pscustomobject][ordered]@{
        provider_identity = 'chatpad-gated-production-native-adapter-recording-shim-v1'
        calls = [Collections.Generic.List[object]]::new()
        fail_at = $FailAt
        failure_code = $FailureCode
        native_io_performed = $false
    }
}

function Invoke-GatedProductionProviderCall {
    param([Parameter(Mandatory)][object]$Provider, [Parameter(Mandatory)][string]$EntryPoint, [Parameter(Mandatory)][object]$Arguments)
    if ([string](Get-GatedProductionBackendProperty $Provider 'provider_identity' '') -ne 'chatpad-gated-production-native-adapter-recording-shim-v1' -or $null -eq (Get-GatedProductionBackendProperty $Provider 'calls' $null)) {
        return [pscustomobject][ordered]@{ succeeded = $false; error_code = 'PROVIDER_UNAVAILABLE_NO_NATIVE_FALLBACK' }
    }
    $Provider.calls.Add([pscustomobject][ordered]@{ entry_point = $EntryPoint; arguments = $Arguments; native_io_performed = $false })
    if ([string]::Equals($EntryPoint, [string](Get-GatedProductionBackendProperty $Provider 'fail_at' ''), [StringComparison]::Ordinal)) {
        return [pscustomobject][ordered]@{ succeeded = $false; error_code = [string](Get-GatedProductionBackendProperty $Provider 'failure_code' 'SIMULATED_NATIVE_PROVIDER_FAILURE') }
    }
    [pscustomobject][ordered]@{ succeeded = $true; error_code = $null }
}

function New-GatedProductionBackendArguments {
    param([Parameter(Mandatory)][string]$EntryPoint, [Parameter(Mandatory)][object]$Request)
    $constants = Get-GatedProductionBackendConstants
    [pscustomobject][ordered]@{
        entry_point = $EntryPoint
        target_instance_id = $constants.selected_target_instance_id
        accepted_target_chain = @($constants.target_chain)
        shared_container_id = $constants.shared_container_id
        operator_confirmation_id = $constants.operator_confirmation_id
        contract_evidence_path = $constants.contract_evidence_path
        contract_evidence_sha256 = $constants.contract_evidence_sha256
        operation = 'Apply'
        flags = 0
    }
}

function Invoke-GatedProductionBackendRecordingPlan {
    param([Parameter(Mandatory)][object]$Request, [Parameter(Mandatory)][object]$Provider)
    $constants = Get-GatedProductionBackendConstants
    $validation = Test-GatedProductionBackendRequest -Request $Request
    $counters = New-GatedProductionBackendZeroCounters
    if (-not $validation.contract_validation_passed -or -not $validation.exact_target_validation_passed) {
        return [pscustomobject][ordered]@{
            schema_version = 'chatpad-gated-production-native-adapter-recording-result-v1'
            result = 'VALIDATION_REJECTED_NO_PROVIDER_CALL'
            result_code = $validation.result_code
            provider_call_count = 0
            cleanup_attempted = $false
            mutation_success_claimed = $false
            validation = $validation
            counters = $counters
        }
    }

    $driverListCreated = $false
    $deviceSetCreated = $false
    $failure = $null
    foreach ($entryPoint in $constants.apply_restore_steps) {
        if ($entryPoint -in @('SetupDiDestroyDriverInfoList', 'SetupDiDestroyDeviceInfoList')) { continue }
        $call = Invoke-GatedProductionProviderCall -Provider $Provider -EntryPoint $entryPoint -Arguments (New-GatedProductionBackendArguments -EntryPoint $entryPoint -Request $Request)
        if ($entryPoint -eq 'SetupDiCreateDeviceInfoList' -and $call.succeeded) { $deviceSetCreated = $true }
        if ($entryPoint -eq 'SetupDiBuildDriverInfoList' -and $call.succeeded) { $driverListCreated = $true }
        if (-not $call.succeeded) { $failure = [string]$call.error_code; break }
    }

    $cleanup = [Collections.Generic.List[string]]::new()
    if ($driverListCreated) { $cleanup.Add('SetupDiDestroyDriverInfoList') }
    if ($deviceSetCreated) { $cleanup.Add('SetupDiDestroyDeviceInfoList') }
    foreach ($entryPoint in $cleanup) {
        [void](Invoke-GatedProductionProviderCall -Provider $Provider -EntryPoint $entryPoint -Arguments (New-GatedProductionBackendArguments -EntryPoint $entryPoint -Request $Request))
    }
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-gated-production-native-adapter-recording-result-v1'
        result = if ($null -eq $failure) { 'RECORDING_PLAN_COMPLETED_NOT_EXECUTED' } else { 'RECORDING_PLAN_STOPPED_ON_PROVIDER_FAILURE' }
        result_code = if ($null -eq $failure) { 'EXECUTION_UNAUTHORIZED_RECORDING_SHIM_ONLY' } else { $failure }
        provider_call_count = [int]$Provider.calls.Count
        cleanup_attempted = ($cleanup.Count -gt 0)
        cleanup_order = @($cleanup)
        mutation_success_claimed = $false
        validation = $validation
        counters = $counters
    }
}

Export-ModuleMember -Function @()
