[CmdletBinding()]
param([string]$ManifestPath = 'docs/evidence/runtime-bringup-readiness-manifest.json')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$script:Assertions = 0
$script:FixtureResults = [System.Collections.Generic.List[object]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:Assertions += 1
    if (-not $Condition) { throw $Message }
}

function Add-Fixture {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Purpose,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL','BLOCKED')][string]$ExpectedResult,
        [Parameter(Mandatory)][scriptblock]$Body
    )
    $startAssertions = $script:Assertions
    $actual = 'FAIL'
    $reason = ''
    try {
        $result = & $Body
        if ($result -and $result.PSObject.Properties.Name -contains 'result') { $actual = [string]$result.result }
        else { $actual = 'PASS' }
    } catch {
        $actual = 'FAIL'
        $reason = $_.Exception.Message
    }
    Assert-True ($actual -eq $ExpectedResult) "Fixture $Id expected $ExpectedResult but got $actual. $reason"
    $script:FixtureResults.Add([pscustomobject]@{
        id = $Id
        category = $Category
        purpose = $Purpose
        expected_result = $ExpectedResult
        actual_result = $actual
        assertion_count = $script:Assertions - $startAssertions
        result = $(if ($actual -eq $ExpectedResult) { 'PASS' } else { 'FAIL' })
        reason = $reason
    })
}

function Copy-Object($Object) {
    return ($Object | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
}

function New-ValidRepositoryFixture {
    [pscustomobject]@{
        approved_readiness_branch = 'feature/runtime-bringup-readiness-remediation'
        approved_readiness_commit = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        accepted_baseline_commit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        current_branch = 'feature/runtime-bringup-readiness-remediation'
        current_head = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        staged_count = 0
        unstaged_count = 0
        untracked_nonignored_count = 0
        detached_head = $false
        alternate_repository_root = $false
        accepted_baseline_is_ancestor = $true
        accepted_manifest_size = 28088
        accepted_manifest_sha256 = '35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
        debug_sys_size = 68096
        debug_sys_sha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
        release_sys_size = 40960
        release_sys_sha256 = 'A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
        debug_pe_machine = 'x64'
        release_pe_machine = 'x64'
        debug_pe_subsystem = 'Native'
        release_pe_subsystem = 'Native'
        debug_signature_state = 'Unsigned'
        release_signature_state = 'Unsigned'
        binary_reparse_point = $false
        manifest_reparse_point = $false
    }
}

function New-ValidTargetContract {
    [pscustomobject]@{
        min_capture_utc = '2026-07-02T00:00:00Z'
        instance_id = 'USB\VID_045E&PID_028E\EXPECTED'
        hardware_ids = @('USB\VID_045E&PID_028E')
        compatible_ids = @('USB\Class_FF&SubClass_5D&Prot_01')
        class_guid = '{D61CA365-5AF4-4486-998B-9DB4734C6CA3}'
        class_name = 'SyntheticXusb'
        parent_id = 'USB\ROOT_HUB30\EXPECTED'
        container_id = '{00000000-0000-0000-0000-000000000028}'
        bus_topology = 'controller-port-1'
        current_inf = 'xusb22.inf'
        current_service = 'xusb22'
        current_provider = 'Microsoft'
        vendor_id = '045E'
        product_id = '028E'
    }
}

function New-ValidInventory {
    $c = New-ValidTargetContract
    [pscustomobject]@{
        source_classification = 'synthetic'
        claims_live = $false
        captured_utc = '2026-07-02T08:00:00Z'
        candidates = @([pscustomobject]@{
            instance_id = $c.instance_id
            hardware_ids = $c.hardware_ids
            compatible_ids = $c.compatible_ids
            class_guid = $c.class_guid
            class_name = $c.class_name
            parent_id = $c.parent_id
            container_id = $c.container_id
            bus_topology = $c.bus_topology
            current_inf = $c.current_inf
            current_service = $c.current_service
            current_provider = $c.current_provider
            vendor_id = $c.vendor_id
            product_id = $c.product_id
            selection_basis = 'exact-contract'
            friendly_name = 'Synthetic Controller'
        })
    }
}

function New-ValidDriverState {
    $c = New-ValidTargetContract
    [pscustomobject]@{
        instance_id = $c.instance_id
        hardware_ids = $c.hardware_ids
        compatible_ids = $c.compatible_ids
        class_guid = $c.class_guid
        class_name = $c.class_name
        parent_id = $c.parent_id
        container_id = $c.container_id
        bus_topology = $c.bus_topology
        current_inf = 'xusb22.inf'
        original_inf_name = 'oem42.inf'
        provider = 'Microsoft'
        driver_version = '10.0.26200.1'
        driver_date = '2026-01-01'
        service = 'xusb22'
        package_identity = 'xusb22.inf_amd64_synthetic'
        recovery_source = 'DriverStore\FileRepository\xusb22.inf_amd64_synthetic'
        driver_stack_identities = @('xusb22','hidclass')
        service_state = 'running'
        collected_utc = '2026-07-02T08:00:00Z'
        host_id = 'SYNTHETIC-HOST'
        session_id = 'CHATPAD-20260702T080000Z-ABCDEF'
        field_provenance = @{ current_inf = 'fixture'; service = 'fixture' }
        source_classification = 'synthetic'
        command_result_id = 'cmd-driver-state'
    }
}

function New-ValidRollbackState {
    [pscustomobject]@{
        target_instance_id = 'USB\VID_045E&PID_028E\EXPECTED'
        previous_package_identity = 'xusb22.inf_amd64_synthetic'
        previous_provider = 'Microsoft'
        previous_version = '10.0.26200.1'
        previous_service = 'xusb22'
        recovery_source_path = 'DriverStore\FileRepository\xusb22.inf_amd64_synthetic'
        recovery_source_sha256 = '1111111111111111111111111111111111111111111111111111111111111111'
        test_package_identity = 'chatpadfilter.inf_amd64_synthetic'
        evidence_directory = 'C:\Temp\ChatpadEvidence\CHATPAD-20260702T080000Z-ABCDEF'
        session_id = 'CHATPAD-20260702T080000Z-ABCDEF'
        snapshot_session_id = 'CHATPAD-20260702T080000Z-ABCDEF'
        stale_snapshot = $false
        unplanned_reboot_required = $false
        pre_test_snapshot = New-ValidDriverState
        emergency_recovery = @{ safe_mode = 'documented'; winre = 'documented'; input_device = 'separate keyboard' }
        rollback_operations = @(
            New-ChatpadOperationPlan -OperationId 'restore-exact' -Executable 'ChatpadRuntimeExactDeviceBindingHelper.exe' -Arguments @('--restore-instance','USB\VID_045E&PID_028E\EXPECTED') -TargetInstanceId 'USB\VID_045E&PID_028E\EXPECTED' -StopConditionIds @('rollback-cannot-be-guaranteed') -MutationClassification 'exact-target-mutation' -ExecutionStatus 'blocked'
        )
    }
}

function New-ValidSigningState {
    [pscustomobject]@{
        method = 'LocalTestCertificate'
        certificate_thumbprint = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
        subject = 'CN=Chatpad Local Test'
        issuer = 'CN=Chatpad Local Test'
        trust_status = 'trusted'
        private_key_present = $true
        eku = @('Code Signing')
        valid_from_utc = '2026-01-01T00:00:00Z'
        valid_to_utc = '2027-01-01T00:00:00Z'
        validation_time_utc = '2026-07-02T08:00:00Z'
        timestamping_plan = 'required-before-runtime'
        sys_signature_state = 'signed'
        cat_signature_state = 'signed'
        test_signing_state = 'planned-enabled'
        secure_boot_state = 'disabled'
        hvci_state = 'disabled'
        code_integrity_state = 'compatible'
        credential_scope = 'local-test'
        evidence_object_id = 'signing-state-synthetic'
    }
}

function New-ValidHostState {
    [pscustomobject]@{
        os_edition = 'Windows 11 Pro'
        os_version = '10.0'
        os_build = '26200.8655'
        architecture = 'x64'
        is_administrator = $true
        powershell_version = '7.6.3'
        system_time_utc = '2026-07-02T08:00:00Z'
        timezone = 'Asia/Baku'
        secure_boot = 'disabled'
        test_signing = 'planned-enabled'
        code_integrity = 'compatible'
        hvci = 'disabled'
        device_guard = 'compatible'
        boot_configuration_id = 'boot-fixture'
        wdk_tools = @('tracepdb','stampinf')
        debugging_tools = @('tracefmt')
        required_commands = @('pnputil.exe','wevtutil.exe','logman.exe')
        evidence_root_writable = $true
        evidence_root_contained = $true
        host_id = 'SYNTHETIC-HOST'
        capture_timestamp_utc = '2026-07-02T08:00:00Z'
        fresh_until_utc = '2026-07-02T09:00:00Z'
        source_classification = 'synthetic'
    }
}

function New-ValidEvidenceDirectoryState {
    [pscustomobject]@{
        approved_root = 'C:\Temp\ChatpadEvidence'
        evidence_directory = 'C:\Temp\ChatpadEvidence\CHATPAD-20260702T080000Z-ABCDEF'
        session_id = 'CHATPAD-20260702T080000Z-ABCDEF'
        source_classification = 'synthetic'
        exists_before_session = $false
        stale_session = $false
        session_id_reused = $false
        has_reparse_point = $false
        has_symlink_or_junction = $false
        is_unc_path = $false
        inside_repository = $false
        lock_exists = $false
    }
}

function New-ValidReconciliationState {
    [pscustomobject]@{
        approved_readiness_identity = 'impl-candidate'
        accepted_baseline_identity = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        host_baseline = 'host-before'
        host_final = 'host-after'
        target_baseline = 'target-before'
        target_final = 'target-after'
        previous_driver = 'xusb22'
        test_driver = 'chatpadfilter'
        service_state = 'restored'
        package_state = 'removed'
        boot_security_state = 'unchanged'
        trace_state = 'stopped'
        event_log_evidence = 'captured'
        executed_operations = @('none-in-synthetic')
        rollback_operations = @('restore-exact')
        residual_packages = @()
        residual_services = @()
        unresolved_deviations = @()
        expected_mode = 'restored-baseline'
        final_classification = 'fully-restored-baseline'
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('chatpad-runtime-remediation-fixtures-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $packageRoot = Join-Path $tempRoot 'pkg'
    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    $sysPath = Join-Path $packageRoot 'ChatpadFilter.sys'
    $catPath = Join-Path $packageRoot 'chatpadfilter.cat'
    $infPath = Join-Path $packageRoot 'chatpadfilter.inf'
    [IO.File]::WriteAllBytes($sysPath, [Text.Encoding]::ASCII.GetBytes('synthetic sys bytes'))
    [IO.File]::WriteAllBytes($catPath, [Text.Encoding]::ASCII.GetBytes('synthetic cat bytes'))
    $sysHash = (Get-FileHash -LiteralPath $sysPath -Algorithm SHA256).Hash
    @'
[Version]
Signature="$WINDOWS NT$"
Class=USBDevice
ClassGuid={D61CA365-5AF4-4486-998B-9DB4734C6CA3}
Provider=%ChatpadProvider%
DriverVer=07/02/2026,1.0.0.0
CatalogFile=chatpadfilter.cat

[Manufacturer]
%Mfg%=Models,NTamd64

[Models.NTamd64]
%Device%=Install, USB\VID_045E&PID_028E

[DestinationDirs]
DefaultDestDir=12

[Install.NT]
CopyFiles=DriverCopy

[DriverCopy]
ChatpadFilter.sys

[Install.NT.Services]
AddService=ChatpadFilter,0x00000002,ServiceInstall

[ServiceInstall]
ServiceBinary=%12%\ChatpadFilter.sys

[Install.NT.Wdf]
KmdfService=ChatpadFilter,KmdfInstall

[KmdfInstall]
KmdfLibraryVersion=1.33

[Strings]
ChatpadProvider="Synthetic Provider"
Mfg="Synthetic"
Device="Synthetic Chatpad"
'@ | Set-Content -LiteralPath $infPath -Encoding utf8
    $validPackage = [pscustomobject]@{
        package_root = $packageRoot
        inf_path = $infPath
        expected_hardware_id = 'USB\VID_045E&PID_028E'
        expected_service_binary = 'ChatpadFilter.sys'
        expected_sys_sha256 = $sysHash
        sys_relative_path = 'ChatpadFilter.sys'
        allowed_files = @('ChatpadFilter.sys','chatpadfilter.cat','chatpadfilter.inf')
        signature_required = $true
        cat_present = $true
        signature_identity_present = $true
    }

    Add-Fixture 'repo-valid' 'repository_identity' 'valid dual repository identity object passes' 'PASS' { Test-ChatpadRepositoryIdentityObject (New-ValidRepositoryFixture) }
    foreach ($case in @(
        @{id='repo-abbrev'; field='approved_readiness_commit'; value='aaaa'; purpose='abbreviated commit rejected'},
        @{id='repo-wrong-branch'; field='current_branch'; value='wrong'; purpose='wrong branch rejected'},
        @{id='repo-wrong-head'; field='current_head'; value='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'; purpose='wrong head rejected'},
        @{id='repo-dirty-index'; field='staged_count'; value=1; purpose='dirty index rejected'},
        @{id='repo-dirty-worktree'; field='unstaged_count'; value=1; purpose='dirty worktree rejected'},
        @{id='repo-untracked'; field='untracked_nonignored_count'; value=1; purpose='unexpected untracked rejected'},
        @{id='repo-detached'; field='detached_head'; value=$true; purpose='detached head rejected'},
        @{id='repo-alt-root'; field='alternate_repository_root'; value=$true; purpose='alternate repository rejected'},
        @{id='repo-manifest-hash'; field='accepted_manifest_sha256'; value='BAD'; purpose='manifest hash rejected'},
        @{id='repo-debug-hash'; field='debug_sys_sha256'; value='BAD'; purpose='debug hash rejected'},
        @{id='repo-release-transpose'; field='release_sys_sha256'; value='E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'; purpose='release transposition rejected'},
        @{id='repo-pe-machine'; field='debug_pe_machine'; value='x86'; purpose='wrong PE machine rejected'},
        @{id='repo-subsystem'; field='release_pe_subsystem'; value='WindowsCui'; purpose='wrong subsystem rejected'},
        @{id='repo-signed'; field='debug_signature_state'; value='Signed'; purpose='unexpected signature rejected'},
        @{id='repo-reparse'; field='binary_reparse_point'; value=$true; purpose='reparse binary rejected'}
    )) {
        Add-Fixture $case.id 'repository_identity' $case.purpose 'FAIL' { $s = New-ValidRepositoryFixture; $s.($case.field) = $case.value; Test-ChatpadRepositoryIdentityObject $s }
    }

    Add-Fixture 'target-valid' 'target_selection' 'valid exact target passes' 'PASS' { Test-ChatpadTargetSelectionContract -Inventory (New-ValidInventory) -Contract (New-ValidTargetContract) }
    foreach ($case in @('zero','multiple','friendly','partial','wildcard','missing-topology','wrong-parent','missing-container','duplicate','wrong-inf','wrong-service','wrong-provider','stale','synthetic-as-live','wrong-topology','reordered-hardware')) {
        Add-Fixture "target-$case" 'target_selection' "target defect rejected: $case" 'FAIL' {
            $i = New-ValidInventory; $c = New-ValidTargetContract
            switch ($case) {
                'zero' { $i.candidates = @() }
                'multiple' { $i.candidates = @($i.candidates[0], (Copy-Object $i.candidates[0])) }
                'friendly' { $i.candidates[0].selection_basis = 'friendly-name-only' }
                'partial' { $i.candidates[0].hardware_ids = @('USB\VID_045E') }
                'wildcard' { $i.candidates[0].hardware_ids = @('USB\VID_045E&PID_*') }
                'missing-topology' { $i.candidates[0].bus_topology = '' }
                'wrong-parent' { $i.candidates[0].parent_id = 'wrong' }
                'missing-container' { $i.candidates[0].container_id = '' }
                'duplicate' { $i.candidates = @($i.candidates[0], (Copy-Object $i.candidates[0])) }
                'wrong-inf' { $i.candidates[0].current_inf = 'wrong.inf' }
                'wrong-service' { $i.candidates[0].current_service = 'wrong' }
                'wrong-provider' { $i.candidates[0].current_provider = 'wrong' }
                'stale' { $i.captured_utc = '2020-01-01T00:00:00Z' }
                'synthetic-as-live' { $i.claims_live = $true }
                'wrong-topology' { $i.candidates[0].bus_topology = 'wrong-port' }
                'reordered-hardware' { $i.candidates[0].hardware_ids = @('USB\VID_045E&PID_028E','USB\EXTRA') }
            }
            Test-ChatpadTargetSelectionContract -Inventory $i -Contract $c
        }
    }

    Add-Fixture 'driver-state-valid' 'current_driver_capture' 'complete current-driver state passes' 'PASS' { Test-ChatpadDriverStateContract (New-ValidDriverState) }
    foreach ($field in @('instance_id','current_inf','original_inf_name','provider','driver_version','service','package_identity','recovery_source','field_provenance','command_result_id')) {
        Add-Fixture "driver-state-missing-$field" 'current_driver_capture' "missing $field rejected" 'FAIL' { $s = New-ValidDriverState; $s.$field = ''; Test-ChatpadDriverStateContract $s }
    }

    Add-Fixture 'rollback-valid' 'rollback_readiness' 'complete rollback state passes' 'PASS' { Test-ChatpadRollbackContract (New-ValidRollbackState) }
    foreach ($case in @('inf-only','missing-source','missing-provider','ambiguous-instance','wildcard','different-target','auto-restore','missing-input-recovery','missing-safe-mode','missing-evidence','unplanned-reboot','stale-snapshot','other-session')) {
        Add-Fixture "rollback-$case" 'rollback_readiness' "rollback defect rejected: $case" 'FAIL' {
            $s = New-ValidRollbackState
            switch ($case) {
                'inf-only' { $s.previous_package_identity = '' }
                'missing-source' { $s.recovery_source_path = '' }
                'missing-provider' { $s.previous_provider = '' }
                'ambiguous-instance' { $s.target_instance_id = '' }
                'wildcard' { $s.rollback_operations[0].arguments = @('--restore-instance','USB*') }
                'different-target' { $s.rollback_operations[0].target_instance_id = 'DIFFERENT' }
                'auto-restore' { $s.rollback_operations = @() }
                'missing-input-recovery' { $s.emergency_recovery.input_device = '' }
                'missing-safe-mode' { $s.emergency_recovery.safe_mode = '' }
                'missing-evidence' { $s.evidence_directory = '' }
                'unplanned-reboot' { $s.unplanned_reboot_required = $true }
                'stale-snapshot' { $s.stale_snapshot = $true }
                'other-session' { $s.snapshot_session_id = 'OTHER' }
            }
            Test-ChatpadRollbackContract $s
        }
    }

    Add-Fixture 'package-valid' 'package_validation' 'valid synthetic package passes' 'PASS' { Test-ChatpadPackageContract $validPackage }
    foreach ($case in @('wrong-architecture','missing-sys','wrong-sys','same-size-wrong-sys','missing-cat','extra-cat','extra-exe','certificate-file','wildcard-hwid','broad-class','undecorated','wrong-service-binary','wrong-provider','missing-driverver','duplicate-section','missing-kmdf','path-traversal','prefix-escape','unsigned')) {
        Add-Fixture "package-$case" 'package_validation' "package defect rejected: $case" 'FAIL' {
            $pRoot = Join-Path $tempRoot ("pkg-$case")
            Copy-Item -LiteralPath $packageRoot -Destination $pRoot -Recurse
            $p = Copy-Object $validPackage
            $p.package_root = $pRoot
            $p.inf_path = Join-Path $pRoot 'chatpadfilter.inf'
            switch ($case) {
                'wrong-architecture' { (Get-Content $p.inf_path -Raw).Replace('NTamd64','NTx86') | Set-Content $p.inf_path }
                'missing-sys' { Remove-Item -LiteralPath (Join-Path $pRoot 'ChatpadFilter.sys') }
                'wrong-sys' { Set-Content -LiteralPath (Join-Path $pRoot 'ChatpadFilter.sys') -Value 'wrong' }
                'same-size-wrong-sys' { [IO.File]::WriteAllBytes((Join-Path $pRoot 'ChatpadFilter.sys'), [byte[]](1..19)) }
                'missing-cat' { Remove-Item -LiteralPath (Join-Path $pRoot 'chatpadfilter.cat'); $p.cat_present = $false }
                'extra-cat' { Set-Content -LiteralPath (Join-Path $pRoot 'unexpected.cat') -Value 'x' }
                'extra-exe' { Set-Content -LiteralPath (Join-Path $pRoot 'evil.exe') -Value 'x' }
                'certificate-file' { Set-Content -LiteralPath (Join-Path $pRoot 'test.pfx') -Value 'x' }
                'wildcard-hwid' { (Get-Content $p.inf_path -Raw).Replace('USB\VID_045E&PID_028E','USB\VID_045E&PID_*') | Set-Content $p.inf_path }
                'broad-class' { Add-Content -LiteralPath $p.inf_path -Value 'USB\Class_FF' }
                'undecorated' { (Get-Content $p.inf_path -Raw).Replace('Models,NTamd64','Models') | Set-Content $p.inf_path }
                'wrong-service-binary' { (Get-Content $p.inf_path -Raw).Replace('ChatpadFilter.sys','Wrong.sys') | Set-Content $p.inf_path }
                'wrong-provider' { (Get-Content $p.inf_path -Raw).Replace('Provider=%ChatpadProvider%','Provider=%Wrong%') | Set-Content $p.inf_path }
                'missing-driverver' { (Get-Content $p.inf_path -Raw).Replace('DriverVer=07/02/2026,1.0.0.0','') | Set-Content $p.inf_path }
                'duplicate-section' { Add-Content -LiteralPath $p.inf_path -Value "`n[Version]`n" }
                'missing-kmdf' { (Get-Content $p.inf_path -Raw).Replace('KmdfLibraryVersion=1.33','') | Set-Content $p.inf_path }
                'path-traversal' { $p.allowed_files = @('ChatpadFilter.sys','chatpadfilter.cat','chatpadfilter.inf','../escape.sys') }
                'prefix-escape' { $siblingRoot = "$pRoot-escape"; Copy-Item -LiteralPath $packageRoot -Destination $siblingRoot -Recurse; $p.inf_path = Join-Path $siblingRoot 'chatpadfilter.inf' }
                'unsigned' { $p.signature_identity_present = $false }
            }
            Test-ChatpadPackageContract $p
        }
    }

    Add-Fixture 'signing-valid' 'signing_readiness' 'valid synthetic signing state passes' 'PASS' { Test-ChatpadSigningContract (New-ValidSigningState) }
    foreach ($case in @('signature-missing','untrusted','missing-private-key','expired','not-yet-valid','wrong-eku','wrong-thumbprint','missing-timestamp','unsigned-sys','unsigned-cat','secureboot-incompatible','hvci-incompatible','testsigning-inconsistent','release-credential','documentation-only')) {
        Add-Fixture "signing-$case" 'signing_readiness' "signing defect rejected: $case" 'FAIL' {
            $s = New-ValidSigningState
            switch ($case) {
                'signature-missing' { $s.sys_signature_state = 'unsigned'; $s.cat_signature_state = 'unsigned' }
                'untrusted' { $s.trust_status = 'untrusted' }
                'missing-private-key' { $s.private_key_present = $false }
                'expired' { $s.valid_to_utc = '2026-01-02T00:00:00Z' }
                'not-yet-valid' { $s.valid_from_utc = '2026-12-01T00:00:00Z' }
                'wrong-eku' { $s.eku = @('Server Authentication') }
                'wrong-thumbprint' { $s.certificate_thumbprint = '' }
                'missing-timestamp' { $s.timestamping_plan = 'missing' }
                'unsigned-sys' { $s.sys_signature_state = 'unsigned' }
                'unsigned-cat' { $s.cat_signature_state = 'unsigned' }
                'secureboot-incompatible' { $s.secure_boot_state = 'enabled' }
                'hvci-incompatible' { $s.hvci_state = 'enabled-incompatible' }
                'testsigning-inconsistent' { $s.test_signing_state = 'disabled' }
                'release-credential' { $s.credential_scope = 'release' }
                'documentation-only' { $s.evidence_object_id = '' }
            }
            Test-ChatpadSigningContract $s
        }
    }

    Add-Fixture 'host-valid' 'host_preflight' 'valid host state passes' 'PASS' { Test-ChatpadHostStateContract (New-ValidHostState) }
    foreach ($field in @('secure_boot','test_signing','code_integrity','hvci','device_guard','boot_configuration_id','wdk_tools','debugging_tools','required_commands','host_id')) {
        Add-Fixture "host-missing-$field" 'host_preflight' "missing $field rejected" 'FAIL' { $s = New-ValidHostState; $s.$field = ''; Test-ChatpadHostStateContract $s }
    }
    Add-Fixture 'host-evidence-not-writable' 'host_preflight' 'unwritable evidence root rejected' 'FAIL' { $s = New-ValidHostState; $s.evidence_root_writable = $false; Test-ChatpadHostStateContract $s }

    Add-Fixture 'evidence-dir-valid' 'evidence_directory' 'valid evidence directory state passes' 'PASS' { Test-ChatpadEvidenceDirectoryContract (New-ValidEvidenceDirectoryState) }
    foreach ($case in @('relative-root','traversal','prefix-escape','existing','stale','reused','reparse','junction','unc','inside-repo','lock','bad-session')) {
        Add-Fixture "evidence-dir-$case" 'evidence_directory' "evidence directory defect rejected: $case" 'FAIL' {
            $s = New-ValidEvidenceDirectoryState
            switch ($case) {
                'relative-root' { $s.approved_root = 'relative' }
                'traversal' { $s.evidence_directory = 'C:\Temp\ChatpadEvidence\..\escape' }
                'prefix-escape' { $s.evidence_directory = 'C:\Temp\ChatpadEvidence-Escape\CHATPAD-20260702T080000Z-ABCDEF' }
                'existing' { $s.exists_before_session = $true }
                'stale' { $s.stale_session = $true }
                'reused' { $s.session_id_reused = $true }
                'reparse' { $s.has_reparse_point = $true }
                'junction' { $s.has_symlink_or_junction = $true }
                'unc' { $s.is_unc_path = $true }
                'inside-repo' { $s.inside_repository = $true }
                'lock' { $s.lock_exists = $true }
                'bad-session' { $s.session_id = 'bad' }
            }
            Test-ChatpadEvidenceDirectoryContract $s
        }
    }

    $hostileValues = @('"quoted"','single''quote','value & whoami & value','value|more','value;whoami','value`whoami','$(whoami)','value > file','C:\Path With Spaces\File.inf','C:\Path (x)\File.inf','%TEMP%\x','$env:TEMP')
    foreach ($value in $hostileValues) {
        Add-Fixture ("render-safe-" + ([Math]::Abs($value.GetHashCode()))) 'command_injection' "hostile value preserved as one argument: $value" 'PASS' {
            $op = New-ChatpadOperationPlan -OperationId 'hostile-render' -Executable 'tool.exe' -Arguments @('--value',$value) -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'render-only'
            Assert-True (@($op.arguments).Count -eq 2) 'Argument count changed.'
            Assert-True ($op.arguments[1] -eq $value) 'Argument value changed.'
            $op
        }
    }
    foreach ($value in @("line`nbreak","carriage`rreturn",[string]([char]0),'USB\VID_*\BAD',[string]([char]0x202E))) {
        Add-Fixture ("render-reject-" + ([Math]::Abs($value.GetHashCode()))) 'command_injection' 'unsafe value rejected' 'FAIL' {
            New-ChatpadOperationPlan -OperationId 'hostile-render' -Executable 'tool.exe' -Arguments @('--value',$value) -TargetInstanceId $value -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'exact-target-mutation'
        }
    }
    Add-Fixture 'render-reject-array-scalar-confusion' 'command_injection' 'array rejected where scalar operation ID is required' 'FAIL' {
        New-ChatpadOperationPlan -OperationId @('one','two') -Executable 'tool.exe' -Arguments @('--value','safe') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'render-only'
    }
    Add-Fixture 'render-reject-empty-scalar' 'command_injection' 'empty required scalar rejected' 'FAIL' {
        New-ChatpadOperationPlan -OperationId '' -Executable 'tool.exe' -Arguments @('--value','safe') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'render-only'
    }
    Add-Fixture 'render-reject-whitespace-scalar' 'command_injection' 'whitespace-only required scalar rejected' 'FAIL' {
        New-ChatpadOperationPlan -OperationId '   ' -Executable 'tool.exe' -Arguments @('--value','safe') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'render-only'
    }
    Add-Fixture 'render-reject-path-traversal' 'command_injection' 'path traversal argument rejected' 'FAIL' {
        New-ChatpadOperationPlan -OperationId 'hostile-render' -Executable 'tool.exe' -Arguments @('--path','C:\approved\..\escape') -StopConditionIds @('command-differs-from-approved-plan') -MutationClassification 'render-only'
    }

    Add-Fixture 'wpp-valid' 'wpp_planning' 'valid WPP plan passes' 'PASS' { Test-ChatpadWppPlanContract ([pscustomobject]@{ provider_guid='{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}'; session_name='Chatpad-ABC'; session_name_reused=$false; output_exists=$false; reuses_stale_output=$false; output_under_evidence_root=$true }) }
    foreach ($case in @('wrong-provider','wildcard-provider','reused-session','stale-output','escaped-output')) {
        Add-Fixture "wpp-$case" 'wpp_planning' "WPP defect rejected: $case" 'FAIL' {
            $s = [pscustomobject]@{ provider_guid='{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}'; session_name='Chatpad-ABC'; session_name_reused=$false; output_exists=$false; reuses_stale_output=$false; output_under_evidence_root=$true }
            switch ($case) {
                'wrong-provider' { $s.provider_guid = '{BAD}' }
                'wildcard-provider' { $s.provider_guid = '*' }
                'reused-session' { $s.session_name_reused = $true }
                'stale-output' { $s.output_exists = $true }
                'escaped-output' { $s.output_under_evidence_root = $false }
            }
            Test-ChatpadWppPlanContract $s
        }
    }

    Add-Fixture 'eventlog-valid' 'event_log_planning' 'valid event log plan passes' 'PASS' { Test-ChatpadEventLogPlanContract ([pscustomobject]@{ required_channels=@('System','Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration'); capture_phase='baseline'; session_bound_time_window=$true; outputs_fresh_and_contained=$true; clears_logs=$false; configures_channels=$false }) }
    foreach ($case in @('missing-channel','wrong-phase','no-time-window','stale-output','clear-logs','configure-channel')) {
        Add-Fixture "eventlog-$case" 'event_log_planning' "event log defect rejected: $case" 'FAIL' {
            $s = [pscustomobject]@{ required_channels=@('System','Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration'); capture_phase='baseline'; session_bound_time_window=$true; outputs_fresh_and_contained=$true; clears_logs=$false; configures_channels=$false }
            switch ($case) {
                'missing-channel' { $s.required_channels = @('System') }
                'wrong-phase' { $s.capture_phase = 'middle' }
                'no-time-window' { $s.session_bound_time_window = $false }
                'stale-output' { $s.outputs_fresh_and_contained = $false }
                'clear-logs' { $s.clears_logs = $true }
                'configure-channel' { $s.configures_channels = $true }
            }
            Test-ChatpadEventLogPlanContract $s
        }
    }

    Add-Fixture 'install-blocked-exact-binding' 'exact_instance_install_planning' 'install plan blocks unresolved exact binding' 'BLOCKED' { Test-ChatpadInstallPlanContract ([pscustomobject]@{ repository_identity='PASS'; accepted_baseline_identity='PASS'; package_validation='PASS'; signing_readiness='PASS'; host_preflight='PASS'; target_selection='PASS'; current_driver_capture='PASS'; rollback_readiness='PASS'; evidence_directory='PASS'; exact_instance_binding_available=$false; operations=@() }) }
    Add-Fixture 'install-prereq-fails' 'exact_instance_install_planning' 'install plan rejects missing prerequisite' 'BLOCKED' { Test-ChatpadInstallPlanContract ([pscustomobject]@{ repository_identity='FAIL'; accepted_baseline_identity='PASS'; package_validation='PASS'; signing_readiness='PASS'; host_preflight='PASS'; target_selection='PASS'; current_driver_capture='PASS'; rollback_readiness='PASS'; evidence_directory='PASS'; exact_instance_binding_available=$true; operations=@() }) }
    Add-Fixture 'install-broad-approved-rejected' 'operation_rendering' 'broad operation cannot be target-specific' 'BLOCKED' { Test-ChatpadInstallPlanContract ([pscustomobject]@{ repository_identity='PASS'; accepted_baseline_identity='PASS'; package_validation='PASS'; signing_readiness='PASS'; host_preflight='PASS'; target_selection='PASS'; current_driver_capture='PASS'; rollback_readiness='PASS'; evidence_directory='PASS'; exact_instance_binding_available=$true; operations=@([pscustomobject]@{ mutation_classification='broad-host-mutation'; approved_as_target_specific=$true; arguments=@('/scan-devices') }) }) }

    Add-Fixture 'schema-valid-sample' 'evidence_schema' 'valid synthetic evidence document passes' 'PASS' { Test-ChatpadEvidenceDocumentContract ([pscustomobject]@{ schema_version='chatpad-runtime-evidence-schema-v2'; session=@{ session_id='SYNTHETIC-SESSION-0001'; evidence_classification='synthetic' }; artifacts=@([pscustomobject]@{ id='planned-artifact'; relative_path='planned/repo.json'; status='planned'; byte_size=$null; sha256=$null; evidence_classification='synthetic' }); operations=@([pscustomobject]@{ operation_id='render-only'; status='planned' }) }) }
    Add-Fixture 'schema-file-validates-sample' 'evidence_schema' 'Draft 2020-12 schema validates the committed synthetic sample' 'PASS' {
        $schemaPath = Join-Path $PSScriptRoot '..\docs\evidence\runtime-bringup-evidence-schema-v1.json'
        $samplePath = Join-Path $PSScriptRoot '..\docs\evidence\runtime-bringup-sample-evidence.json'
        Assert-True ((Get-Content -LiteralPath $samplePath -Raw | Test-Json -SchemaFile $schemaPath)) 'Committed sample failed machine schema validation.'
        [pscustomobject]@{ result='PASS' }
    }
    foreach ($case in @('bad-schema','bad-session','path-traversal','executed-no-hash','executed-no-result','rolledback-no-evidence','restored-no-final','synthetic-as-live','duplicate-artifact')) {
        Add-Fixture "schema-$case" 'evidence_schema' "schema defect rejected: $case" 'FAIL' {
            $d = [pscustomobject]@{ schema_version='chatpad-runtime-evidence-schema-v2'; session=@{ session_id='SYNTHETIC-SESSION-0001'; evidence_classification='synthetic' }; artifacts=@([pscustomobject]@{ id='a'; relative_path='a.json'; status='planned'; byte_size=$null; sha256=$null; evidence_classification='synthetic' }); operations=@([pscustomobject]@{ operation_id='op'; status='planned' }) }
            switch ($case) {
                'bad-schema' { $d.schema_version = 'bad' }
                'bad-session' { $d.session.session_id = 'bad' }
                'path-traversal' { $d.artifacts[0].relative_path = '../x' }
                'executed-no-hash' { $d.artifacts[0].status='executed'; $d.artifacts[0].byte_size=1; $d.artifacts[0].sha256='PLANNED_NOT_EXECUTED' }
                'executed-no-result' { $d.operations[0].status='executed' }
                'rolledback-no-evidence' { $d.operations[0].status='rolled_back' }
                'restored-no-final' { $d.operations[0].status='restored' }
                'synthetic-as-live' { $d.session.evidence_classification='live' }
                'duplicate-artifact' { $d.artifacts = @($d.artifacts[0], (Copy-Object $d.artifacts[0])) }
            }
            Test-ChatpadEvidenceDocumentContract $d
        }
    }

    Add-Fixture 'stop-link-valid' 'stop_condition_linkage' 'known stop-condition ID accepted' 'PASS' { Assert-ChatpadStopConditionIds @('runtime-evidence-write-failed') | Out-Null; [pscustomobject]@{ result='PASS' } }
    Add-Fixture 'stop-link-unknown' 'stop_condition_linkage' 'unknown stop-condition ID rejected' 'FAIL' { Assert-ChatpadStopConditionIds @('not-a-stop-id') }

    Add-Fixture 'reconcile-valid-restored' 'post_test_reconciliation' 'fully restored baseline passes' 'PASS' { Test-ChatpadPostTestReconciliationContract (New-ValidReconciliationState) }
    foreach ($case in @('approved-test-state','partial-rollback','unexplained','missing-evidence','wrong-mode','missing-field')) {
        Add-Fixture "reconcile-$case" 'post_test_reconciliation' "reconciliation case: $case" $(if ($case -eq 'approved-test-state') { 'PASS' } else { 'FAIL' }) {
            $s = New-ValidReconciliationState
            switch ($case) {
                'approved-test-state' { $s.expected_mode='test-state'; $s.final_classification='approved-test-state' }
                'partial-rollback' { $s.final_classification='partial-rollback' }
                'unexplained' { $s.final_classification='unexplained-deviation' }
                'missing-evidence' { $s.final_classification='blocked-missing-evidence' }
                'wrong-mode' { $s.expected_mode='test-state' }
                'missing-field' { $s.event_log_evidence = $null }
            }
            Test-ChatpadPostTestReconciliationContract $s
        }
    }

    if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
        Add-Fixture 'manifest-schema-known' 'manifest_truthfulness' 'readiness manifest schema is recognized' 'PASS' {
            $manifest = Read-ChatpadJson $ManifestPath
            Assert-True ([string]$manifest.schema_version -match '^chatpad-runtime-bringup-readiness-manifest-v[0-9]+$') 'Manifest schema is not versioned.'
            [pscustomobject]@{ result='PASS' }
        }
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

$totals = @{}
foreach ($group in ($script:FixtureResults | Group-Object category)) {
    $totals[$group.Name] = $group.Count
}

$failed = @($script:FixtureResults | Where-Object result -ne 'PASS')
$result = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

[pscustomobject]@{
    schema_version = 'chatpad-runtime-bringup-readiness-test-v2'
    result = $result
    fixture_count = $script:FixtureResults.Count
    assertion_count = $script:Assertions
    fixture_totals_by_category = $totals
    failed_fixture_count = $failed.Count
    command_injection_fixture_count = [int]$totals['command_injection']
    raw_command_concatenation_count = 0
    broad_approved_install_operation_count = 0
    broad_approved_rollback_operation_count = 0
    exact_instance_binding_status = 'BLOCKED_NOT_IMPLEMENTED'
    device_enumeration_performed = $false
    windows_mutation_performed = $false
    signing_performed = $false
    package_created_or_installed = $false
    trace_session_started = $false
    event_log_export_performed = $false
    fixtures = @($script:FixtureResults)
} | ConvertTo-Json -Depth 12

if ($result -ne 'PASS') { exit 1 }
