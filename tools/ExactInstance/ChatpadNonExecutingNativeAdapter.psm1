Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This module is deliberately source-only.  It contains no native declarations,
# native library loading, production backend construction, or device discovery.

function Get-NativeAdapterContractConstants {
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-nonexecuting-native-adapter-contract-v1'
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        target_chain = @(
            'USB\VID_045E&PID_028E\1C21F10',
            'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00',
            'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000'
        )
        production_adapter_identity = 'chatpad-windows-exact-instance-adapter-v1'
        fake_backend_identity = 'chatpad-native-adapter-fake-recording-backend-v1'
        blocker = 'BLOCKED_NATIVE_ADAPTER_IMPLEMENTATION_NOT_INDEPENDENTLY_AUDITED'
    }
}

function Get-NativeAdapterProperty {
    param(
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    Write-Output -NoEnumerate $property.Value
}

function New-NativeAdapterZeroCounters {
    [pscustomobject][ordered]@{
        device_query_count = 0
        native_invocation_count = 0
        setupapi_newdev_invocation_count = 0
        binding_count = 0
        windows_mutation_count = 0
        driver_action_count = 0
        artifact_compile_output_access_count = 0
    }
}

function Test-NativeAdapterExactStringArray {
    param(
        [AllowNull()][object]$Actual,
        [Parameter(Mandatory)][string[]]$Expected
    )

    if ($Actual -is [string] -or $null -eq $Actual) { return $false }
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($values[$index] -isnot [string] -or
            -not [string]::Equals([string]$values[$index], $Expected[$index], [StringComparison]::Ordinal)) {
            return $false
        }
    }
    $true
}

function Test-NativeAdapterAuthorizationCapability {
    param([AllowNull()][object]$AuthorizationCapability = $null)

    # No effective capability exists in this phase.  In particular, there is no
    # script-scope token, public object, or serializable value to recover.
    $false
}

function Test-NativeAdapterRequest {
    param(
        [AllowNull()][object]$Request,
        [AllowNull()][object]$AuthorizationCapability = $null
    )

    $constants = Get-NativeAdapterContractConstants
    $contractPath = Get-NativeAdapterProperty -Object $Request -Name 'contract_evidence_path' -Default ''
    $contractHash = Get-NativeAdapterProperty -Object $Request -Name 'contract_evidence_sha256' -Default ''
    $chain = Get-NativeAdapterProperty -Object $Request -Name 'target_chain' -Default $null
    $container = Get-NativeAdapterProperty -Object $Request -Name 'shared_container_id' -Default ''
    $confirmation = Get-NativeAdapterProperty -Object $Request -Name 'operator_confirmation_id' -Default ''

    $contractValidationPassed = (
        [string]$contractPath -is [string] -and
        [string]::Equals([string]$contractPath, $constants.contract_evidence_path, [StringComparison]::Ordinal) -and
        [string]$contractHash -is [string] -and
        [string]::Equals([string]$contractHash, $constants.contract_evidence_sha256, [StringComparison]::Ordinal)
    )
    $targetValidationPassed = (
        (Test-NativeAdapterExactStringArray -Actual $chain -Expected $constants.target_chain) -and
        [string]::Equals([string]$container, $constants.shared_container_id, [StringComparison]::Ordinal) -and
        [string]::Equals([string]$confirmation, $constants.operator_confirmation_id, [StringComparison]::Ordinal)
    )
    $authorizationAccepted = Test-NativeAdapterAuthorizationCapability -AuthorizationCapability $AuthorizationCapability
    $counters = New-NativeAdapterZeroCounters

    [pscustomobject][ordered]@{
        schema_version = 'chatpad-nonexecuting-native-adapter-validation-result-v1'
        result = if ($contractValidationPassed -and $targetValidationPassed) { 'VALIDATED_EXECUTION_PROHIBITED' } else { 'VALIDATION_REJECTED' }
        result_code = if (-not $contractValidationPassed) { 'CONTRACT_EVIDENCE_IDENTITY_REJECTED' } elseif (-not $targetValidationPassed) { 'EXACT_TARGET_REJECTED' } else { 'NATIVE_EXECUTION_PROHIBITED' }
        contract_validation_passed = $contractValidationPassed
        authorization_rejected = (-not $authorizationAccepted)
        target_validation_rejected = (-not $targetValidationPassed)
        backend_available = $false
        production_backend_present = $false
        production_backend_loaded = $false
        native_execution_prohibited = $true
        native_operation_executed = $false
        attempted_fake_backend_calls = 0
        counters = $counters
        blocker = $constants.blocker
    }
}

function Invoke-NativeAdapterFakeBackend {
    param(
        [Parameter(Mandatory)][object]$Backend,
        [Parameter(Mandatory)][string]$Operation
    )

    $constants = Get-NativeAdapterContractConstants
    if (-not [string]::Equals([string](Get-NativeAdapterProperty $Backend 'backend_identity' ''), $constants.fake_backend_identity, [StringComparison]::Ordinal) -or
        $null -eq (Get-NativeAdapterProperty $Backend 'calls' $null)) {
        return [pscustomobject][ordered]@{ result = 'BACKEND_UNAVAILABLE'; fake_backend_calls = 0 }
    }
    $Backend.calls.Add([pscustomobject][ordered]@{ operation = $Operation; native_io_performed = $false })
    [pscustomobject][ordered]@{ result = 'FAKE_OPERATION_RECORDED_NOT_NATIVE'; fake_backend_calls = 1 }
}

function Invoke-NativeAdapterOfflineFakeSeam {
    param(
        [Parameter(Mandatory)][object]$Request,
        [Parameter(Mandatory)][object]$Backend
    )

    $validation = Test-NativeAdapterRequest -Request $Request
    $counters = New-NativeAdapterZeroCounters
    if (-not $validation.contract_validation_passed -or $validation.target_validation_rejected) {
        return [pscustomobject][ordered]@{
            schema_version = 'chatpad-nonexecuting-native-adapter-fake-seam-result-v1'
            result = 'VALIDATION_REJECTED_NO_BACKEND_CALL'
            validation = $validation
            attempted_fake_backend_calls = 0
            native_operation_executed = $false
            counters = $counters
        }
    }
    $backendResult = Invoke-NativeAdapterFakeBackend -Backend $Backend -Operation 'ValidateExactTargetOnly'
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-nonexecuting-native-adapter-fake-seam-result-v1'
        result = [string]$backendResult.result
        validation = $validation
        attempted_fake_backend_calls = [int]$backendResult.fake_backend_calls
        native_operation_executed = $false
        counters = $counters
    }
}

function Get-ChatpadNonExecutingNativeAdapterContract {
    $constants = Get-NativeAdapterContractConstants
    [pscustomobject][ordered]@{
        schema_version = $constants.schema_version
        status = 'SOURCE_IMPLEMENTATION_PRESENT_NO_NATIVE_EXECUTION_NO_BINDING_NO_MUTATION_NO_LIVE_DEVICE_ACCESS'
        readiness = 'READY_FOR_INDEPENDENT_NONEXECUTING_NATIVE_ADAPTER_AUDIT_ONLY'
        accepted_contract_evidence_path = $constants.contract_evidence_path
        accepted_contract_evidence_sha256 = $constants.contract_evidence_sha256
        accepted_target_chain = @($constants.target_chain)
        shared_container_id = $constants.shared_container_id
        operator_confirmation_id = $constants.operator_confirmation_id
        exported_surface = @('Get-ChatpadNonExecutingNativeAdapterContract','Test-ChatpadNonExecutingNativeAdapterRequest','Invoke-ChatpadNonExecutingNativeAdapter','New-ChatpadNativeAdapterFakeRecordingBackend')
        internal_native_backend_interface = 'Invoke-NativeAdapterFakeBackend'
        production_backend_present = $false
        production_backend_loaded = $false
        production_backend_selected_by_default = $false
        native_library_loaded = $false
        counters = New-NativeAdapterZeroCounters
        blocker = $constants.blocker
    }
}

function Test-ChatpadNonExecutingNativeAdapterRequest {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Request = $null,
        [AllowNull()][object]$AuthorizationCapability = $null
    )

    Test-NativeAdapterRequest -Request $Request -AuthorizationCapability $AuthorizationCapability
}

function Invoke-ChatpadNonExecutingNativeAdapter {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [AllowNull()][object]$Request = $null,
        [AllowNull()][object]$AuthorizationCapability = $null
    )

    $validation = Test-NativeAdapterRequest -Request $Request -AuthorizationCapability $AuthorizationCapability
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-nonexecuting-native-adapter-operation-result-v1'
        result = 'BLOCKED'
        result_code = if (-not $validation.contract_validation_passed) { 'CONTRACT_EVIDENCE_IDENTITY_REJECTED' } elseif ($validation.target_validation_rejected) { 'EXACT_TARGET_REJECTED' } else { 'NATIVE_EXECUTION_PROHIBITED' }
        contract_validation_passed = $validation.contract_validation_passed
        authorization_rejected = $validation.authorization_rejected
        target_validation_rejected = $validation.target_validation_rejected
        backend_available = $false
        production_backend_present = $false
        production_backend_loaded = $false
        native_execution_prohibited = $true
        native_operation_executed = $false
        attempted_fake_backend_calls = 0
        counters = New-NativeAdapterZeroCounters
        validation = $validation
    }
}

function New-ChatpadNativeAdapterFakeRecordingBackend {
    [CmdletBinding(PositionalBinding = $false)]
    param()

    $constants = Get-NativeAdapterContractConstants
    [pscustomobject][ordered]@{
        backend_identity = $constants.fake_backend_identity
        calls = [Collections.Generic.List[object]]::new()
        native_io_performed = $false
        production_backend = $false
    }
}

Export-ModuleMember -Function Get-ChatpadNonExecutingNativeAdapterContract,Test-ChatpadNonExecutingNativeAdapterRequest,Invoke-ChatpadNonExecutingNativeAdapter,New-ChatpadNativeAdapterFakeRecordingBackend
