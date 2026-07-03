Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ChatpadNativeInteropConstants {
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-native-interop-source-boundary-v1'
        declaration_inventory_schema = 'chatpad-native-interop-declaration-inventory-v1'
        call_plan_schema = 'chatpad-native-interop-call-plan-v1'
        source_boundary_status = 'SOURCE_DECLARATIONS_PRESENT_NON_EXECUTING'
        current_gate = 'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT'
        execution_blocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
        declaration_relative_path = 'tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'
        allowed_dlls = @('setupapi.dll','newdev.dll')
        prohibited_native_dlls = @('cfgmgr32.dll','difxapi.dll')
        prohibited_tools = @('pnputil','devcon','dpinst','dism')
    }
}

function Get-ChatpadNativeInteropDeclarationInventory {
    $constants = Get-ChatpadNativeInteropConstants
    $apis = @(
        @{ id='device-information-set-create'; dll='setupapi.dll'; entry_point='SetupDiCreateDeviceInfoList'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDeviceInfoList'; phase='open-exact-instance' },
        @{ id='device-information-set-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDeviceInfoList'; read_only=$true; mutating=$false; cleanup='final HDEVINFO owner'; phase='cleanup' },
        @{ id='exact-device-open'; dll='setupapi.dll'; entry_point='SetupDiOpenDeviceInfoW'; read_only=$true; mutating=$false; cleanup='device-information-set owner'; phase='open-exact-instance' },
        @{ id='canonical-instance-query'; dll='setupapi.dll'; entry_point='SetupDiGetDeviceInstanceIdW'; read_only=$true; mutating=$false; cleanup='caller-owned Unicode buffer'; phase='identity-verification' },
        @{ id='device-property-query'; dll='setupapi.dll'; entry_point='SetupDiGetDevicePropertyW'; read_only=$true; mutating=$false; cleanup='caller-owned typed buffer'; phase='state-capture' },
        @{ id='device-registry-property-query'; dll='setupapi.dll'; entry_point='SetupDiGetDeviceRegistryPropertyW'; read_only=$true; mutating=$false; cleanup='caller-owned typed buffer'; phase='state-capture' },
        @{ id='driver-list-build'; dll='setupapi.dll'; entry_point='SetupDiBuildDriverInfoList'; read_only=$true; mutating=$false; cleanup='SetupDiDestroyDriverInfoList'; phase='driver-node-enumeration' },
        @{ id='driver-list-destroy'; dll='setupapi.dll'; entry_point='SetupDiDestroyDriverInfoList'; read_only=$true; mutating=$false; cleanup='driver-list owner'; phase='cleanup' },
        @{ id='driver-node-enumeration'; dll='setupapi.dll'; entry_point='SetupDiEnumDriverInfoW'; read_only=$true; mutating=$false; cleanup='driver-list owner'; phase='driver-node-enumeration' },
        @{ id='driver-node-detail-query'; dll='setupapi.dll'; entry_point='SetupDiGetDriverInfoDetailW'; read_only=$true; mutating=$false; cleanup='caller-owned variable buffer'; phase='driver-node-enumeration' },
        @{ id='driver-install-params-query'; dll='setupapi.dll'; entry_point='SetupDiGetDriverInstallParamsW'; read_only=$true; mutating=$false; cleanup='caller-owned structure'; phase='driver-node-verification' },
        @{ id='selected-driver-association'; dll='setupapi.dll'; entry_point='SetupDiSetSelectedDriverW'; read_only=$false; mutating=$true; cleanup='driver-list owner'; phase='bind-selected-node' },
        @{ id='exact-device-install'; dll='newdev.dll'; entry_point='DiInstallDevice'; read_only=$false; mutating=$true; cleanup='preserve NeedReboot and last-error'; phase='bind-selected-node' }
    )
    $structures = @(
        @{ name='ChatpadDeviceInfoSetHandleToken'; purpose='typed HDEVINFO ownership token without native cleanup invocation in this phase'; cb_size_required=$false },
        @{ name='SP_DEVINFO_DATA'; purpose='exact retained device element'; cb_size_required=$true },
        @{ name='SP_DEVINSTALL_PARAMS_W'; purpose='driver install parameter capture'; cb_size_required=$true },
        @{ name='SP_DRVINFO_DATA_W'; purpose='candidate driver node identity'; cb_size_required=$true },
        @{ name='SP_DRVINFO_DETAIL_DATA_W'; purpose='variable-length candidate driver detail buffer contract'; cb_size_required=$true },
        @{ name='DEVPROPKEY'; purpose='SetupDiGetDevicePropertyW key contract'; cb_size_required=$false }
    )
    $constantsDeclared = @(
        'SPDIT_COMPATDRIVER',
        'DIGCF_PRESENT',
        'ERROR_INSUFFICIENT_BUFFER',
        'ERROR_NO_MORE_ITEMS',
        'INVALID_HANDLE_VALUE',
        'MaxPath',
        'LineLength',
        'AnySizeArray'
    )
    [pscustomobject][ordered]@{
        schema_version = $constants.declaration_inventory_schema
        declaration_relative_path = $constants.declaration_relative_path
        allowed_dlls = @($constants.allowed_dlls)
        prohibited_native_dlls = @($constants.prohibited_native_dlls)
        api_count = $apis.Count
        mutating_api_count = @($apis | Where-Object { [bool]$_.mutating }).Count
        read_only_api_count = @($apis | Where-Object { [bool]$_.read_only }).Count
        apis = @($apis | ForEach-Object { [pscustomobject]$_ })
        structure_count = $structures.Count
        structures = @($structures | ForEach-Object { [pscustomobject]$_ })
        constants = @($constantsDeclared)
    }
}

function Get-ChatpadNativeInteropErrorMapping {
    $rows = @(
        @{ code='EXACT_INSTANCE_NOT_FOUND'; phase='open-exact-instance'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='CANONICAL_INSTANCE_MISMATCH'; phase='identity-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='INSTANCE_IDENTITY_DRIFT'; phase='identity-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='ACCESS_DENIED'; phase='authorization'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='ELEVATION_REQUIRED'; phase='authorization'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='UNSUPPORTED_OPERATING_SYSTEM'; phase='platform'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='UNSUPPORTED_ARCHITECTURE'; phase='platform'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='PROPERTY_UNAVAILABLE'; phase='state-capture'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='DRIVER_LIST_BUILD_FAILURE'; phase='driver-node-enumeration'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='DRIVER_NODE_ENUMERATION_FAILURE'; phase='driver-node-enumeration'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='TARGET_DRIVER_NOT_FOUND'; phase='driver-node-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='TARGET_DRIVER_AMBIGUOUS'; phase='driver-node-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='PRIOR_DRIVER_NOT_FOUND'; phase='restore-driver-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='PRIOR_DRIVER_AMBIGUOUS'; phase='restore-driver-verification'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='SELECTED_DRIVER_ASSOCIATION_FAILURE'; phase='bind-selected-node'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='BIND_API_FAILURE_BEFORE_POSSIBLE_MUTATION'; phase='bind-selected-node'; controlled_failure=$true; mutation_may_have_occurred=$false; manual_recovery_required=$false },
        @{ code='BIND_FAILURE_AFTER_POSSIBLE_MUTATION'; phase='bind-selected-node'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='POST_BIND_VERIFICATION_FAILURE'; phase='postcondition'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='RESTORE_API_FAILURE'; phase='restore'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='POST_RESTORE_VERIFICATION_FAILURE'; phase='postcondition'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='RESTART_REQUIRED'; phase='postcondition'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$false },
        @{ code='REBOOT_REQUIRED'; phase='postcondition'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$false },
        @{ code='CLEANUP_FAILURE'; phase='cleanup'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='UNEXPECTED_NATIVE_EXCEPTION'; phase='exception'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true },
        @{ code='UNCERTAIN_DEVICE_STATE'; phase='uncertainty'; controlled_failure=$true; mutation_may_have_occurred=$true; manual_recovery_required=$true }
    )
    @($rows | ForEach-Object {
        [pscustomobject][ordered]@{
            code = $_.code
            phase = $_.phase
            controlled_failure = [bool]$_.controlled_failure
            mutation_may_have_occurred = [bool]$_.mutation_may_have_occurred
            manual_recovery_required = [bool]$_.manual_recovery_required
            retry_prohibited = $true
            win32_last_error_captured_before_cleanup = $true
            restart_pending = ([string]$_.code -eq 'RESTART_REQUIRED')
            reboot_pending = ([string]$_.code -eq 'REBOOT_REQUIRED')
        }
    })
}

function Get-ChatpadNativeInteropCallPlan {
    [CmdletBinding(PositionalBinding = $false)]
    param([Parameter(Mandatory)][ValidateSet('Apply','Restore','Restart')][string]$Operation)

    $constants = Get-ChatpadNativeInteropConstants
    $inventory = Get-ChatpadNativeInteropDeclarationInventory
    $commonOpen = @(
        'SetupDiCreateDeviceInfoList',
        'SetupDiOpenDeviceInfoW',
        'SetupDiGetDeviceInstanceIdW',
        'SetupDiGetDevicePropertyW',
        'SetupDiGetDeviceRegistryPropertyW'
    )
    $driverList = @(
        'SetupDiBuildDriverInfoList',
        'SetupDiEnumDriverInfoW',
        'SetupDiGetDriverInfoDetailW',
        'SetupDiGetDriverInstallParamsW'
    )
    $mutation = switch ($Operation) {
        'Apply' { @('SetupDiSetSelectedDriverW','DiInstallDevice') }
        'Restore' { @('SetupDiSetSelectedDriverW','DiInstallDevice') }
        'Restart' { @() }
    }
    $cleanup = @('SetupDiDestroyDriverInfoList','SetupDiDestroyDeviceInfoList')
    $sequence = @($commonOpen + $driverList + $mutation + $cleanup)
    if ($Operation -eq 'Restart') {
        $sequence = @($commonOpen + @('future-exact-device-restart-sequence') + @('SetupDiDestroyDeviceInfoList'))
    }
    [pscustomobject][ordered]@{
        schema_version = $constants.call_plan_schema
        operation = $Operation
        source_boundary_status = $constants.source_boundary_status
        current_gate = $constants.current_gate
        execution_allowed = $false
        native_invocation_available = $false
        compile_or_load_allowed = $false
        declared_api_count = $inventory.api_count
        ordered_steps = @($sequence | ForEach-Object {
            [pscustomobject][ordered]@{
                entry_point = [string]$_
                planned_only = $true
                invoked_in_this_phase = $false
            }
        })
    }
}

function Get-ChatpadNativeInteropSourceBoundaryContract {
    $constants = Get-ChatpadNativeInteropConstants
    $inventory = Get-ChatpadNativeInteropDeclarationInventory
    [pscustomobject][ordered]@{
        schema_version = $constants.schema_version
        source_boundary_status = $constants.source_boundary_status
        current_gate = $constants.current_gate
        capability_blocker = $constants.execution_blocker
        native_interop_implemented = $false
        native_source_declarations_present = $true
        native_compilation_permitted = $false
        native_loading_permitted = $false
        native_invocation_permitted = $false
        windows_device_query_permitted = $false
        windows_mutation_permitted = $false
        approved_declaration_paths = @($constants.declaration_relative_path)
        declaration_inventory = $inventory
        call_plans = @(('Apply','Restore','Restart') | ForEach-Object { Get-ChatpadNativeInteropCallPlan -Operation $_ })
        error_mapping = @(Get-ChatpadNativeInteropErrorMapping)
    }
}

function Test-ChatpadNativeInteropSourceBoundary {
    [CmdletBinding(PositionalBinding = $false)]
    param([string]$RepositoryRoot = '')
    if (-not $RepositoryRoot) {
        $RepositoryRoot = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
    }
    $RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    $constants = Get-ChatpadNativeInteropConstants
    $inventory = Get-ChatpadNativeInteropDeclarationInventory
    $declarationPath = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $constants.declaration_relative_path))
    $defects = [Collections.Generic.List[object]]::new()
    if (-not $declarationPath.StartsWith($RepositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $defects.Add([pscustomobject][ordered]@{ id='declaration-path-outside-repository'; path=$constants.declaration_relative_path })
    }
    if (-not (Test-Path -LiteralPath $declarationPath -PathType Leaf)) {
        $defects.Add([pscustomobject][ordered]@{ id='declaration-file-missing'; path=$constants.declaration_relative_path })
        $text = ''
    } else {
        $text = [IO.File]::ReadAllText($declarationPath)
    }
    foreach ($api in @($inventory.apis)) {
        if ($text -notmatch ([regex]::Escape([string]$api.entry_point))) {
            $defects.Add([pscustomobject][ordered]@{ id='declared-api-missing'; entry_point=[string]$api.entry_point })
        }
    }
    foreach ($structure in @($inventory.structures)) {
        if ($text -notmatch ([regex]::Escape([string]$structure.name))) {
            $defects.Add([pscustomobject][ordered]@{ id='declared-structure-missing'; structure=[string]$structure.name })
        }
    }
    $dllImportCount = ([regex]::Matches($text, '\[DllImport\s*\(')).Count
    if ($dllImportCount -ne $inventory.api_count) {
        $defects.Add([pscustomobject][ordered]@{ id='dllimport-count-mismatch'; expected=$inventory.api_count; actual=$dllImportCount })
    }
    foreach ($bad in @($constants.prohibited_native_dlls)) {
        if ($text -match [regex]::Escape($bad)) {
            $defects.Add([pscustomobject][ordered]@{ id='prohibited-native-dll-declared'; dll=$bad })
        }
    }
    foreach ($pattern in @('\[LibraryImport\s*\(',('Add-' + 'Type'),('SetupDiCallClassInstaller\s*\('),('UpdateDriverForPlugAndPlayDevices\s*\('),('CM_[A-Za-z0-9_]+\s*\('))) {
        if ($text -match $pattern) {
            $defects.Add([pscustomobject][ordered]@{ id='prohibited-source-pattern'; pattern=$pattern })
        }
    }
    $referenceFiles = @(& git -C $RepositoryRoot ls-files '*.csproj' '*.vcxproj' '*.sln' '*.props' '*.targets')
    foreach ($relative in $referenceFiles) {
        $full = Join-Path $RepositoryRoot $relative
        $referenceText = [IO.File]::ReadAllText($full)
        if ($referenceText -match [regex]::Escape('Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs') -or
            $referenceText -match [regex]::Escape('NativeInterop')) {
            $defects.Add([pscustomobject][ordered]@{ id='declaration-referenced-by-build-file'; path=$relative })
        }
    }
    $trackedBinaries = @(& git -C $RepositoryRoot ls-files '*.dll' '*.exe' '*.sys' '*.cat')
    $nativeBinaries = @($trackedBinaries | Where-Object { $_ -match 'NativeInterop|SetupApi|Newdev' })
    foreach ($binary in $nativeBinaries) {
        $defects.Add([pscustomobject][ordered]@{ id='native-interop-binary-tracked'; path=$binary })
    }
    [pscustomobject][ordered]@{
        result = if ($defects.Count) { 'FAIL' } else { 'PASS' }
        result_code = if ($defects.Count) { 'NATIVE_INTEROP_SOURCE_BOUNDARY_INVALID' } else { 'NATIVE_INTEROP_SOURCE_BOUNDARY_VALID' }
        declaration_relative_path = $constants.declaration_relative_path
        declaration_sha256 = if ($text) { (Get-FileHash -LiteralPath $declarationPath -Algorithm SHA256).Hash } else { '' }
        declared_api_count = $inventory.api_count
        declared_structure_count = $inventory.structure_count
        dllimport_count = $dllImportCount
        build_reference_file_count = $referenceFiles.Count
        native_interop_binary_count = $nativeBinaries.Count
        defects = @($defects)
    }
}

Export-ModuleMember -Function *-Chatpad*
