Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:NativeDesignSchema = 'chatpad-native-adapter-design-gate-v1'
$script:LiveAdapterBlocker = 'BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED'
$script:TrustedMutationCapabilitySentinel = [object]::new()
$script:TrustedReadOnlyCapabilitySentinel = [object]::new()

function Test-ChatpadNativeMutationCapability {
    param([AllowNull()][object]$Capability)
    $present = [object]::ReferenceEquals($Capability, $script:TrustedMutationCapabilitySentinel)
    [pscustomobject][ordered]@{
        result = if ($present) { 'PASS' } else { 'BLOCKED' }
        result_code = if ($present) { 'TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT' } else { $script:LiveAdapterBlocker }
        capability_present = $present
        capability_serializable = $false
        capability_source = if ($present) { 'future-internal-production-composition-root' } else { 'none' }
    }
}

function Test-ChatpadNativeReadOnlyCapability {
    param([AllowNull()][object]$Capability)
    $present = [object]::ReferenceEquals($Capability, $script:TrustedReadOnlyCapabilitySentinel)
    [pscustomobject][ordered]@{
        result = if ($present) { 'PASS' } else { 'BLOCKED' }
        result_code = if ($present) { 'TRUSTED_NATIVE_READ_ONLY_CAPABILITY_PRESENT' } else { 'READ_ONLY_CAPABILITY_ABSENT' }
        read_only_capability_present = $present
        mutation_capability_present = [object]::ReferenceEquals($Capability, $script:TrustedMutationCapabilitySentinel)
    }
}

function New-ChatpadNativeReadOnlyDesignProbe {
    $script:TrustedReadOnlyCapabilitySentinel
}

function New-ChatpadNativeMutationCapability {
    throw $script:LiveAdapterBlocker
}

function Test-ChatpadNativeAdapterOperationGate {
    param(
        [Parameter(Mandatory)][ValidateSet('Apply','Restore','Restart')][string]$Operation,
        [AllowNull()][object]$Capability,
        [string]$AdapterName = '',
        [string]$Mode = '',
        [bool]$Synthetic = $true,
        [bool]$IsElevated = $false,
        [bool]$AllowWindowsMutation = $false,
        [AllowNull()][object]$AdapterObject = $null,
        [AllowNull()][object]$Evidence = $null
    )
    $capability = Test-ChatpadNativeMutationCapability -Capability $Capability
    $trusted = $capability.capability_present
    [pscustomobject][ordered]@{
        result = if ($trusted) { 'PASS' } else { 'BLOCKED' }
        result_code = if ($trusted) { 'TRUSTED_NATIVE_MUTATION_CAPABILITY_PRESENT' } else { $script:LiveAdapterBlocker }
        operation = $Operation
        adapter_name_trusted = $false
        public_mode_trusted = $false
        public_synthetic_flag_trusted = $false
        elevation_trusted = $false
        mutation_switch_trusted = $false
        caller_object_trusted = $false
        evidence_trusted = $false
        fake_adapter_trusted = $false
        live_capability_present = $trusted
        live_binding_authorized = $false
        live_restoration_authorized = $false
        live_restart_authorized = $false
        live_device_queries_performed = 0
        windows_mutations_performed = 0
        details = [pscustomobject][ordered]@{
            adapter_name = $AdapterName
            mode = $Mode
            synthetic = $Synthetic
            is_elevated = $IsElevated
            allow_windows_mutation = $AllowWindowsMutation
            adapter_object_type = if ($null -eq $AdapterObject) { '' } else { $AdapterObject.GetType().FullName }
            evidence_type = if ($null -eq $Evidence) { '' } else { $Evidence.GetType().FullName }
        }
    }
}

function Get-ChatpadNativeAdapterDesignContract {
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
        'internal-trusted-native-capability',
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
        schema_version = $script:NativeDesignSchema
        live_adapter_status = 'NOT_IMPLEMENTED'
        capability_blocker = $script:LiveAdapterBlocker
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
        evidence_fields = @('trusted_producer_identity','implementation_binary_identity','adapter_implementation_version','code_or_assembly_hash','operation_plan_hash','exact_canonical_instance_id','exact_target_driver_identity','exact_restoration_driver_identity','ordered_native_call_log','native_return_codes','win32_errors','before_state','after_state','restart_reboot_indication','cleanup_results','trusted_capability_provenance','synthetic_live_classification')
        operation_gates = @($operationGates)
        composition_root = [pscustomobject][ordered]@{
            permitted_future_location = 'internal production composition root only'
            present_in_this_task = $false
            arbitrary_module_or_class_name_selection = $false
            public_path_parameter_replacement = $false
            fake_adapter_satisfies = $false
            current_capability_creation_path = 'none'
        }
    }
}

function Test-ChatpadNativeDesignContractCompleteness {
    param([object]$Contract = (Get-ChatpadNativeAdapterDesignContract))
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
    $result = ($missingCalls.Count -eq 0 -and $missingErrors.Count -eq 0 -and $gateCount -eq 18 -and [bool]$Contract.exact_device_opening.retains_one_device_set_and_element)
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
