Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..', '..'))
$script:PlanPath = Join-Path $PSScriptRoot 'contracts\chatpad-live-apply-package-source-plan.json'
$script:InfRelativePath = 'src/driver/ChatpadFilter/package/ChatpadFilterExtension.inf'
$script:PrototypeRelativePath = 'prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf'
$script:Status = 'CANONICAL_WINDOWS_11_DRIVER_PACKAGE_SOURCE_DEFINED_NOT_BUILT_NOT_CATALOGED_NOT_SIGNED_NOT_STAGED_NOT_INSTALLABLE'
$script:Blocker = 'BLOCKED_NATIVE_ADAPTER_CANONICAL_DRIVER_PACKAGE_NOT_BUILT_CATALOGED_SIGNED_AND_INDEPENDENTLY_AUDITED'
$script:NextTask = 'TASK 8I-P1B-2 ' + [char]0x2014 + ' Build, catalog, sign, validate, and freeze the canonical Windows 11 driver package and immutable APPLY candidate contract'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-Names([object]$Value) {
    return @($Value.PSObject.Properties.Name)
}

function Assert-ExactProperties([object]$Value, [string[]]$Expected, [string]$Label) {
    if ($null -eq $Value) { throw "$Label is missing." }
    $actual = @(Get-Names $Value)
    if ($actual.Count -ne $Expected.Count -or (@(Compare-Object $Expected $actual -CaseSensitive).Count -ne 0)) {
        throw "$Label property set is not exact. Expected: $($Expected -join ', '). Actual: $($actual -join ', ')."
    }
}

function Assert-String([object]$Value, [string]$Expected, [string]$Label) {
    if ($Value -isnot [string] -or -not $Value.Equals($Expected, [System.StringComparison]::Ordinal)) {
        throw "$Label must equal '$Expected'."
    }
}

function Assert-Bool([object]$Value, [bool]$Expected, [string]$Label) {
    if ($Value -isnot [bool] -or $Value -ne $Expected) { throw "$Label must be literal Boolean $Expected." }
}

function Assert-StringArray([object[]]$Actual, [string[]]$Expected, [string]$Label) {
    $items = @($Actual)
    if ($items.Count -ne $Expected.Count) { throw "$Label count changed." }
    for ($i = 0; $i -lt $Expected.Count; $i++) {
        Assert-String $items[$i] $Expected[$i] "$Label[$i]"
    }
}

function Get-InfSections([string]$Text) {
    $sections = [ordered]@{}
    $current = $null
    foreach ($raw in ($Text -split "`r?`n")) {
        $line = ($raw -replace ';.*$', '').Trim()
        if ($line.Length -eq 0) { continue }
        if ($line -match '^\[([^\]]+)\]$') {
            $current = $Matches[1]
            if ($sections.Contains($current)) { throw "Duplicate INF section [$current]." }
            $sections[$current] = New-Object 'System.Collections.Generic.List[string]'
            continue
        }
        if ($null -eq $current) { throw "Active INF line outside a section: $line" }
        $sections[$current].Add($line)
    }
    return $sections
}

function Assert-Inf([string]$Text) {
    $required = @('Version','DestinationDirs','SourceDisksNames','SourceDisksFiles','Manufacturer','Models.NTamd64.10.0...22000','ChatpadFilter_Install.NT','ChatpadFilter_CopyFiles','ChatpadFilter_Install.NT.Services','ChatpadFilter_Service_Install','ChatpadFilter_Install.NT.Wdf','ChatpadFilter_Wdf','ChatpadFilter_Install.NT.Filters','ChatpadFilter_LowerFilter','Strings')
    $sections = Get-InfSections $Text
    Assert-StringArray @($sections.Keys) $required 'INF sections'
    $active = (($sections.Values | ForEach-Object { $_ }) -join "`n")
    $requiredLines = @(
        'Signature   = "$WINDOWS NT$"','Class       = Extension','ClassGuid   = {E2F84CE7-8EFA-411C-AA69-97454CA4CB57}',
        'Provider    = %ProviderName%','ExtensionId = {69E7CCD7-7011-4059-95D4-618974E126DD}','CatalogFile = ChatpadFilterExtension.cat',
        'DriverVer   = 07/11/2026,1.0.0.0','PnpLockdown = 1','ChatpadFilter_CopyFiles = 13','ChatpadFilter.sys = 1,,',
        '%ProviderName% = Models,NTamd64.10.0...22000','%DeviceDescription% = ChatpadFilter_Install, USB\VID_045E&PID_028E',
        'AddService = ChatpadFilter,,ChatpadFilter_Service_Install','ServiceBinary = %13%\ChatpadFilter.sys',
        'KmdfService = ChatpadFilter,ChatpadFilter_Wdf','KmdfLibraryVersion = 1.15',
        'AddFilter = ChatpadFilter,,ChatpadFilter_LowerFilter','FilterPosition = Lower','ProviderName       = "Chatpad Super Driver Project"')
    foreach ($line in $requiredLines) {
        if (-not $Text.Contains($line)) { throw "Required INF material is missing or changed: $line" }
    }
    $modelLines = @($sections['Models.NTamd64.10.0...22000'] | Where-Object { $_ -match '=' })
    if ($modelLines.Count -ne 1 -or $modelLines[0] -ne '%DeviceDescription% = ChatpadFilter_Install, USB\VID_045E&PID_028E') { throw 'INF model inventory is not exact.' }
    if ($Text -match '(?i)\b(?:UpperFilters|LowerFilters|CoInstallers|ClassInstall32|DefaultInstall|SPSVCINST_ASSOCSERVICE)\b') { throw 'INF contains a prohibited installer/filter directive.' }
    if ($Text -match '(?i)(?:[A-Z]:\\|\\\\|TODO|PLACEHOLDER|TESTSIGN|TEST SIGN|\*|USB\\VID_045E&PID_028E\\|828F4587|IG_00|HID\\|XnaComposite)') { throw 'INF contains a broad, machine-specific, placeholder, test-only, or prohibited match.' }
    if ([regex]::Matches($Text, '(?i)USB\\VID_045E&PID_028E').Count -ne 1) { throw 'INF hardware ID occurrence count is not exactly one.' }
}

function Assert-Plan([object]$Plan, [string]$InfText) {
    $top = @('schema','status','production_driver_project','driver_binary_filename','canonical_inf','catalog_filename','architecture','driver_framework','driver_type','service_name','filter_name','filter_attachment','device_setup_class','provider','manufacturer_section','model_section','install_section','extension_id','stable_hardware_ids','compatible_ids','target_node','driver_source_inventory','package_source_inventory','package_file_inventory','version_policy','catalog_policy','signing_policy','prototype_exclusion','caller_controls','candidate_rule','future_p1b2_fields','material_directive_bases','blocker','next_task')
    Assert-ExactProperties $Plan $top 'plan'
    Assert-String $Plan.schema 'chatpad-live-apply-package-source-plan-v1' 'schema'
    Assert-String $Plan.status $script:Status 'status'
    Assert-ExactProperties $Plan.production_driver_project @('path','sha256','source_identity_schema') 'production_driver_project'
    Assert-String $Plan.production_driver_project.path 'src/driver/ChatpadFilter/ChatpadFilter.vcxproj' 'production project path'
    Assert-String $Plan.production_driver_project.source_identity_schema 'ordered-path-sha256-v1' 'source identity schema'
    Assert-String $Plan.driver_binary_filename 'ChatpadFilter.sys' 'driver binary filename'
    Assert-ExactProperties $Plan.canonical_inf @('path','sha256') 'canonical_inf'
    Assert-String $Plan.canonical_inf.path $script:InfRelativePath 'canonical INF path'
    Assert-String $Plan.catalog_filename 'ChatpadFilterExtension.cat' 'catalog filename'
    Assert-String $Plan.architecture 'AMD64' 'architecture'
    Assert-String $Plan.driver_framework 'KMDF 1.15' 'driver framework'
    Assert-String $Plan.driver_type 'device-specific non-associated extension lower filter' 'driver type'
    Assert-String $Plan.service_name 'ChatpadFilter' 'service name'
    Assert-String $Plan.filter_name 'ChatpadFilter' 'filter name'
    Assert-ExactProperties $Plan.filter_attachment @('method','position','level','associated_service','base_inf','base_service','preserves_base_function_driver') 'filter_attachment'
    Assert-String $Plan.filter_attachment.method 'DDInstall.Filters AddFilter' 'filter method'
    Assert-String $Plan.filter_attachment.position 'Lower' 'filter position'
    Assert-String $Plan.filter_attachment.level 'none because xusb22 exposes no project-owned named level' 'filter level'
    Assert-Bool $Plan.filter_attachment.associated_service $false 'associated service'
    Assert-String $Plan.filter_attachment.base_inf 'xusb22.inf' 'base INF'
    Assert-String $Plan.filter_attachment.base_service 'xusb22' 'base service'
    Assert-Bool $Plan.filter_attachment.preserves_base_function_driver $true 'base preservation'
    Assert-ExactProperties $Plan.device_setup_class @('name','guid') 'device_setup_class'
    Assert-String $Plan.device_setup_class.name 'Extension' 'class'
    Assert-String $Plan.device_setup_class.guid '{E2F84CE7-8EFA-411C-AA69-97454CA4CB57}' 'ClassGuid'
    Assert-String $Plan.provider 'Chatpad Super Driver Project' 'provider'
    Assert-String $Plan.manufacturer_section 'Manufacturer' 'manufacturer section'
    Assert-String $Plan.model_section 'Models.NTamd64.10.0...22000' 'model section'
    Assert-String $Plan.install_section 'ChatpadFilter_Install' 'install section'
    Assert-String $Plan.extension_id '{69E7CCD7-7011-4059-95D4-618974E126DD}' 'ExtensionId'
    Assert-StringArray @($Plan.stable_hardware_ids) @('USB\VID_045E&PID_028E') 'stable hardware IDs'
    if (@($Plan.compatible_ids).Count -ne 0) { throw 'Compatible ID inventory must be empty.' }
    Assert-ExactProperties $Plan.target_node @('role','stable_hardware_id','exact_live_instance_id','function_instance_id','hid_descendant_instance_id','container_id','live_validation_required_before_candidate_selection') 'target_node'
    Assert-String $Plan.target_node.role 'physical USB XnaComposite controller devnode below preserved xusb22 function driver' 'target role'
    Assert-String $Plan.target_node.stable_hardware_id 'USB\VID_045E&PID_028E' 'target stable ID'
    Assert-String $Plan.target_node.exact_live_instance_id 'USB\VID_045E&PID_028E\1C21F10' 'live instance'
    Assert-String $Plan.target_node.function_instance_id 'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00' 'function instance'
    Assert-String $Plan.target_node.hid_descendant_instance_id 'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000' 'HID descendant'
    Assert-String $Plan.target_node.container_id '{828F4587-006F-5AD1-B169-6AF57905DFDE}' 'ContainerId'
    Assert-Bool $Plan.target_node.live_validation_required_before_candidate_selection $true 'live target validation'

    $expectedSourcePaths = @('Directory.Build.props','src/driver/ChatpadFilter/ChatpadFilter.vcxproj','src/driver/ChatpadFilter/ChatpadActivationPreparation.c','src/driver/ChatpadFilter/ChatpadActivationPreparation.h','src/driver/ChatpadFilter/ChatpadFilterLifecycle.c','src/driver/ChatpadFilter/ChatpadFilterLifecycle.h','src/driver/ChatpadFilter/ChatpadRuntimeDiagnostics.h','src/driver/ChatpadFilter/device.c','src/driver/ChatpadFilter/driver.c','src/driver/ChatpadFilter/driver.h','src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj','src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c','src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h','src/protocol/ChatpadProtocol/ChatpadActivationExecutor.h','src/protocol/ChatpadProtocol/ChatpadActivationRequests.c','src/protocol/ChatpadProtocol/ChatpadActivationRequests.h','src/protocol/ChatpadProtocol/ChatpadActivationSequence.c','src/protocol/ChatpadProtocol/ChatpadActivationSequence.h','src/transport/ChatpadControlSetup/ChatpadControlSetup.c','src/transport/ChatpadControlSetup/ChatpadControlSetup.h','src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.c','src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.h','src/transport/ChatpadTransport/ChatpadTransportAdapter.h','src/transport/ChatpadWdfControlSetup/ChatpadWdfControlSetupFormatter.c','src/transport/ChatpadWdfControlSetup/ChatpadWdfControlSetupFormatter.h')
    if (@($Plan.driver_source_inventory).Count -ne $expectedSourcePaths.Count) { throw 'Driver source inventory count changed.' }
    for ($i=0; $i -lt $expectedSourcePaths.Count; $i++) {
        $entry=$Plan.driver_source_inventory[$i]
        Assert-ExactProperties $entry @('path','sha256') "driver_source_inventory[$i]"
        Assert-String $entry.path $expectedSourcePaths[$i] "driver source path[$i]"
        $actualPath=Join-Path $script:RepoRoot $entry.path
        Assert-String $entry.sha256 (Get-Sha256 $actualPath) "driver source hash[$i]"
    }
    Assert-String $Plan.production_driver_project.sha256 (Get-Sha256 (Join-Path $script:RepoRoot $Plan.production_driver_project.path)) 'project hash'
    Assert-String $Plan.canonical_inf.sha256 (Get-Sha256 (Join-Path $script:RepoRoot $script:InfRelativePath)) 'INF hash'
    if (@($Plan.package_source_inventory).Count -ne 2) { throw 'Package source inventory must contain exactly project and INF.' }
    foreach ($entry in @($Plan.package_source_inventory)) { Assert-ExactProperties $entry @('role','path','sha256') 'package source entry' }
    Assert-StringArray @($Plan.package_source_inventory.path) @('src/driver/ChatpadFilter/ChatpadFilter.vcxproj',$script:InfRelativePath) 'package source paths'
    if (@($Plan.package_file_inventory).Count -ne 2) { throw 'Package file inventory must contain exactly INF and SYS.' }
    Assert-StringArray @($Plan.package_file_inventory.filename) @('ChatpadFilterExtension.inf','ChatpadFilter.sys') 'package filenames'
    foreach ($entry in @($Plan.package_file_inventory)) { Assert-ExactProperties $entry @('filename','role','catalog_covered') 'package file entry'; Assert-Bool $entry.catalog_covered $true 'catalog coverage' }

    Assert-ExactProperties $Plan.version_policy @('source_driver_ver','date_source','version_source','generated_from_clock','identical_source_rebuild_policy','new_version_policy','p1b2_freeze_policy') 'version_policy'
    Assert-String $Plan.version_policy.source_driver_ver '07/11/2026,1.0.0.0' 'source DriverVer'
    Assert-Bool $Plan.version_policy.generated_from_clock $false 'clock generation'
    Assert-ExactProperties $Plan.catalog_policy @('filename','covered_files','generation_performed','p1b2_requirement') 'catalog_policy'
    Assert-String $Plan.catalog_policy.filename 'ChatpadFilterExtension.cat' 'catalog policy filename'
    Assert-StringArray @($Plan.catalog_policy.covered_files) @('ChatpadFilterExtension.inf','ChatpadFilter.sys') 'catalog members'
    Assert-Bool $Plan.catalog_policy.generation_performed $false 'catalog generation'
    Assert-ExactProperties $Plan.signing_policy @('production_route','production_route_selected','test_signing_permitted_for_live_attempt','test_mode_permitted','boot_policy_changes_permitted','secure_boot_changes_permitted','temporary_certificate_trust_permitted','current_installability') 'signing_policy'
    Assert-String $Plan.signing_policy.production_route 'Microsoft attestation signing or WHCP signing; exact route remains a P1B-2 release-security decision' 'production signing route'
    foreach ($name in @('production_route_selected','test_signing_permitted_for_live_attempt','test_mode_permitted','boot_policy_changes_permitted','secure_boot_changes_permitted','temporary_certificate_trust_permitted')) { Assert-Bool $Plan.signing_policy.$name $false "signing policy $name" }
    Assert-String $Plan.signing_policy.current_installability 'NOT_INSTALLABLE_UNSIGNED_SOURCE_ONLY' 'installability'
    Assert-ExactProperties $Plan.prototype_exclusion @('path','byte_size','sha256','excluded_from_production','classification') 'prototype_exclusion'
    Assert-String $Plan.prototype_exclusion.path $script:PrototypeRelativePath 'prototype path'
    if ($Plan.prototype_exclusion.byte_size -isnot [long] -and $Plan.prototype_exclusion.byte_size -isnot [int]) { throw 'Prototype byte size must be an integer.' }
    $prototypePath=Join-Path $script:RepoRoot $script:PrototypeRelativePath
    if ([long]$Plan.prototype_exclusion.byte_size -ne (Get-Item -LiteralPath $prototypePath).Length) { throw 'Prototype byte size changed.' }
    Assert-String $Plan.prototype_exclusion.sha256 (Get-Sha256 $prototypePath) 'prototype hash'
    Assert-Bool $Plan.prototype_exclusion.excluded_from_production $true 'prototype exclusion'
    Assert-ExactProperties $Plan.caller_controls @('caller_selected_package_path_permitted','caller_selected_inf_path_permitted','caller_selected_candidate_permitted','first_or_best_driver_fallback_permitted') 'caller_controls'
    foreach ($name in @($Plan.caller_controls.PSObject.Properties.Name)) { Assert-Bool $Plan.caller_controls.$name $false "caller control $name" }
    Assert-ExactProperties $Plan.candidate_rule @('state','zero_exact_matches','one_exact_match','multiple_exact_matches','required_discriminators','prohibited_strategies') 'candidate_rule'
    Assert-String $Plan.candidate_rule.state 'DESIGN_ONLY_NOT_EXECUTABLE_UNTIL_P1B2_FREEZES_ACTUAL_PACKAGE_VALUES' 'candidate state'
    Assert-String $Plan.candidate_rule.zero_exact_matches 'REJECT' 'zero match rule'
    Assert-String $Plan.candidate_rule.one_exact_match 'ELIGIBLE' 'one match rule'
    Assert-String $Plan.candidate_rule.multiple_exact_matches 'REJECT_AMBIGUOUS' 'multiple match rule'
    Assert-StringArray @($Plan.candidate_rule.required_discriminators) @('published INF identity','provider','description','date','version','stable hardware ID','model and install-section relationship','catalog and package identity','driver rank constraints','service and filter identity','target-node role','exact live instance chain','ContainerId') 'candidate discriminators'
    Assert-StringArray @($Plan.candidate_rule.prohibited_strategies) @('first enumerated candidate','lowest enumerated index','highest-ranked candidate without identity matching','hardware-ID-only matching','INF-basename-only matching','caller-selected candidate','caller-selected INF','wildcard provider','wildcard description','fallback candidate') 'prohibited candidate strategies'
    $future=@('built_sys_byte_size','built_sys_sha256','final_inf_byte_size','final_inf_sha256','catalog_byte_size','catalog_sha256','published_staged_inf_name','package_signer_subject','signature_chain_identity','signature_verification_result','driver_package_date','driver_package_version','driver_node_provider','driver_node_description','driver_rank','driver_node_identity','setupapi_package_identity','exact_candidate_match_result','restart_required_result','reboot_required_result','build_provenance','build_tool_versions','reproducibility_result')
    Assert-StringArray @($Plan.future_p1b2_fields) $future 'future P1B-2 fields'
    if (@($Plan.material_directive_bases).Count -ne 10) { throw 'Material directive basis inventory changed.' }
    foreach ($entry in @($Plan.material_directive_bases)) { Assert-ExactProperties $entry @('directive','basis') 'material directive basis'; if ([string]::IsNullOrWhiteSpace($entry.directive) -or [string]::IsNullOrWhiteSpace($entry.basis)) { throw 'Material directive basis is empty.' } }
    Assert-String $Plan.blocker $script:Blocker 'blocker'
    Assert-String $Plan.next_task $script:NextTask 'next task'

    $project=[System.IO.File]::ReadAllText((Join-Path $script:RepoRoot 'src/driver/ChatpadFilter/ChatpadFilter.vcxproj'))
    $device=[System.IO.File]::ReadAllText((Join-Path $script:RepoRoot 'src/driver/ChatpadFilter/device.c'))
    if ($project -notmatch '<ConfigurationType>Driver</ConfigurationType>' -or $project -notmatch '<DriverType>KMDF</DriverType>' -or $project -notmatch '<Platform>x64</Platform>') { throw 'Production project metadata no longer proves x64 KMDF Driver output.' }
    if ($device -notmatch 'WdfFdoInitSetFilter\s*\(') { throw 'Production source no longer declares filter capability.' }
    Assert-Inf $InfText
}

function Test-ChatpadLiveApplyPackageSourceContract {
    [CmdletBinding()]
    param(
        [Parameter()][object]$PlanObject,
        [Parameter()][string]$InfText
    )
    $defects=New-Object 'System.Collections.Generic.List[string]'
    try {
        if ($null -eq $PlanObject) { $PlanObject=([System.IO.File]::ReadAllText($script:PlanPath) | ConvertFrom-Json) }
        if ($PSBoundParameters.ContainsKey('InfText') -eq $false) { $InfText=[System.IO.File]::ReadAllText((Join-Path $script:RepoRoot $script:InfRelativePath)) }
        Assert-Plan $PlanObject $InfText
    } catch { $defects.Add($_.Exception.Message) }
    return [pscustomobject]@{ schema='chatpad-live-apply-package-source-contract-result-v1'; is_valid=($defects.Count -eq 0); defect_count=$defects.Count; defects=@($defects) }
}

Export-ModuleMember -Function Test-ChatpadLiveApplyPackageSourceContract
