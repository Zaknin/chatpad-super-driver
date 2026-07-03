Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NativeScaffoldConstants {
    [pscustomobject][ordered]@{
        design_schema = 'chatpad-native-adapter-design-gate-v2'
        adapter_contract_schema = 'chatpad-native-adapter-contract-v1'
        composition_schema = 'chatpad-native-adapter-composition-root-v1'
        operation_evidence_schema = 'chatpad-native-adapter-operation-evidence-v1'
        production_adapter_id = 'chatpad-windows-exact-instance-adapter-v1'
        synthetic_adapter_id = 'chatpad-fake-exact-instance-adapter-v1'
        execution_blocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        scaffold_gate = 'BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT'
        supported_operations = @('Apply', 'Restore', 'Restart')
    }
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
    [pscustomobject][ordered]@{
        schema_version = $constants.adapter_contract_schema
        adapter_identity = $constants.production_adapter_id
        adapter_implementation_kind = 'production-native-composition-scaffold'
        adapter_mode = 'windows-native-nonexecuting'
        contract_version = '1'
        evidence_contract_version = $constants.operation_evidence_schema
        result_code_contract_version = 'chatpad-native-adapter-result-codes-v1'
        supported_operation_identifiers = @('Apply', 'Restore', 'Restart')
        execution_state = 'non-executing-scaffold'
        native_execution_status = 'NOT_IMPLEMENTED'
        live_execution_available = $false
        native_interop_implemented = $false
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
    $readOnlyCalls = @(
        @{ id='device-information-set-create'; dll='setupapi.dll'; entry_point='SetupDiCreateDeviceInfoList'; purpose='Create one transaction-scoped device information set'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDeviceInfoList' },
        @{ id='exact-device-open'; dll='setupapi.dll'; entry_point='SetupDiOpenDeviceInfoW'; purpose='Open one complete Plug and Play instance ID into the retained set'; read_only=$true; mutating=$false; cleanup='device-information-set owner' },
        @{ id='canonical-instance-query'; dll='setupapi.dll'; entry_point='SetupDiGetDeviceInstanceIdW'; purpose='Retrieve adapter-returned canonical instance ID for ordinal-ignore-case comparison'; read_only=$true; mutating=$false; cleanup='caller-owned Unicode buffer' },
        @{ id='device-property-query'; dll='setupapi.dll/cfgmgr32.dll'; entry_point='SetupDiGetDevicePropertyW, SetupDiGetDeviceRegistryPropertyW, CM_Get_DevNode_Status'; purpose='Capture class, container, parent, location, IDs, status, problem code, and current driver identity'; read_only=$true; mutating=$false; cleanup='caller-owned typed buffers' },
        @{ id='driver-list-build'; dll='setupapi.dll'; entry_point='SetupDiBuildDriverInfoList'; purpose='Build driver nodes only for the retained exact device element'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDriverInfoList' },
        @{ id='driver-node-enumeration'; dll='setupapi.dll'; entry_point='SetupDiEnumDriverInfoW, SetupDiGetDriverInfoDetailW, SetupDiGetDriverInstallParamsW'; purpose='Collect immutable candidate identity without first or best fallback'; read_only=$true; mutating=$false; cleanup='driver-list owner' }
    )
    $mutatingCalls = @(
        @{ id='selected-driver-association'; dll='setupapi.dll'; entry_point='SetupDiSetSelectedDriverW'; purpose='Associate the exact enumerated driver node with the retained exact device element'; read_only=$false; mutating=$true; cleanup='driver-list owner' },
        @{ id='exact-device-install'; dll='newdev.dll'; entry_point='DiInstallDevice'; purpose='Bind only the retained exact device element to the selected driver node'; read_only=$false; mutating=$true; cleanup='preserve NeedReboot and last-error' },
        @{ id='postcondition-query'; dll='setupapi.dll/cfgmgr32.dll'; entry_point='property and driver identity queries'; purpose='Verify complete expected driver identity after API return'; read_only=$true; mutating=$false; cleanup='caller-owned buffers' },
        @{ id='driver-list-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDriverInfoList'; purpose='Destroy the device-specific SPDIT_COMPATDRIVER list exactly once'; read_only=$true; mutating=$false; cleanup='idempotent owner state' },
        @{ id='device-information-set-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDeviceInfoList'; purpose='Release HDEVINFO in deterministic cleanup'; read_only=$true; mutating=$false; cleanup='final HDEVINFO owner' },
        @{ id='exact-device-restart'; dll='setupapi.dll/cfgmgr32.dll'; entry_point='future exact-device restart sequence'; purpose='Restart only the exact retained instance when separately authorized'; read_only=$false; mutating=$true; cleanup='preserve restart and reboot state' }
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
    $scaffoldComplete = (
        $null -ne $production -and
        [string]$production.adapter_identity -eq 'chatpad-windows-exact-instance-adapter-v1' -and
        [bool]$production.production -eq $true -and
        [bool]$production.synthetic -eq $false -and
        [bool]$production.native_interop_implemented -eq $false -and
        [bool]$production.device_queries_available -eq $false -and
        [bool]$production.windows_mutation_available -eq $false -and
        [string]$production.execution_state -eq 'non-executing-scaffold' -and
        [bool]$composition.present_in_this_task -eq $true -and
        [bool]$composition.implicit_synthetic_fallback -eq $false
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
    $paths = @(& git -C $RepositoryRoot ls-files '*.ps1' '*.psm1')
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
    foreach ($relative in $paths) {
        $path = Join-Path $RepositoryRoot $relative
        $text = [IO.File]::ReadAllText($path)
        foreach ($pattern in $declarationPatterns) {
            if ($text -match $pattern) {
                $guardMatches.Add([pscustomobject][ordered]@{ relative_path = $relative; guard = 'native-declaration'; pattern = $pattern })
            }
        }
        $lines = [IO.File]::ReadAllLines($path)
        for ($index = 0; $index -lt $lines.Count; $index++) {
            foreach ($pattern in $invocationPatterns) {
                if ($lines[$index] -match $pattern) {
                    $guardMatches.Add([pscustomobject][ordered]@{ relative_path = $relative; line = $index + 1; guard = 'native-invocation'; pattern = $pattern })
                }
            }
        }
    }
    [pscustomobject][ordered]@{
        result = if ($guardMatches.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($guardMatches.Count) { 'NATIVE_EXECUTABLE_GUARD_FAILED' } else { 'NATIVE_EXECUTABLE_GUARD_VALID' }
        scanned_file_count = $paths.Count
        match_count = $guardMatches.Count
        matches = @($guardMatches)
    }
}

Export-ModuleMember -Function *-Chatpad*
