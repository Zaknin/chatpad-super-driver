[CmdletBinding()]
param([switch]$UnsignedPackage)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot=[System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot,'..'))
$modulePath=Join-Path $repoRoot 'tools\ExactInstance\ChatpadLiveApplyPackageSourceContract.psm1'
$planPath=Join-Path $repoRoot 'tools\ExactInstance\contracts\chatpad-live-apply-package-source-plan.json'
$infPath=Join-Path $repoRoot 'src\driver\ChatpadFilter\package\ChatpadFilterExtension.inf'
$prototypePath=Join-Path $repoRoot 'prototypes\inf\ChatpadFilterExtension\ChatpadFilterExtension.inf'
$unsignedEvidencePath=Join-Path $repoRoot 'docs\evidence\canonical-live-apply-package-build-task-8i-p1b-2a.json'
$unsignedPlanPath=Join-Path $repoRoot 'tools\ExactInstance\contracts\chatpad-live-apply-unsigned-package-plan.json'
$hostReadinessEvidencePath=Join-Path $repoRoot 'docs\evidence\local-development-host-readiness-observation-task-8i-p1b-ld-o1.json'
Import-Module $modulePath -Force

$script:tests=0
$script:assertions=0
$tempRoot=Join-Path ([System.IO.Path]::GetTempPath()) ('chatpad-package-source-contract-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempRoot)

function Assert-Test([bool]$Condition,[string]$Message) {
    $script:assertions++
    if (-not $Condition) { throw $Message }
}

function Pass-Test([string]$Name,[scriptblock]$Body) {
    & $Body
    $script:tests++
    Write-Output "PASS: $Name"
}

function Clone-Plan {
    return (([System.IO.File]::ReadAllText($planPath) | ConvertFrom-Json) | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
}

function Invoke-RejectedFixture {
    param([string]$Name,[scriptblock]$PlanMutation,[scriptblock]$InfMutation)
    $plan=Clone-Plan
    $inf=[System.IO.File]::ReadAllText($infPath)
    if ($null -ne $PlanMutation) { & $PlanMutation $plan | Out-Null }
    if ($null -ne $InfMutation) { $inf=& $InfMutation $inf }
    $fixtureDir=Join-Path $tempRoot ([guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $fixtureDir)
    $fixturePlan=Join-Path $fixtureDir 'plan.json'
    $fixtureInf=Join-Path $fixtureDir 'package.inf'
    [System.IO.File]::WriteAllText($fixturePlan,($plan | ConvertTo-Json -Depth 20),[System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($fixtureInf,$inf,[System.Text.UTF8Encoding]::new($false))
    $fixtureObject=[System.IO.File]::ReadAllText($fixturePlan) | ConvertFrom-Json
    $fixtureText=[System.IO.File]::ReadAllText($fixtureInf)
    $result=Test-ChatpadLiveApplyPackageSourceContract -PlanObject $fixtureObject -InfText $fixtureText
    Pass-Test $Name { Assert-Test (-not $result.is_valid -and $result.defect_count -gt 0) "$Name was not rejected." }
}

function Test-ExactPropertySet([object]$Object,[string[]]$Expected) {
    if($null-eq$Object){return $false}
    $actual=@($Object.PSObject.Properties.Name)
    return $actual.Count-eq$Expected.Count-and@(Compare-Object $Expected $actual -CaseSensitive).Count-eq0
}

function Test-UnsignedPackageObjects([object]$Evidence,[object]$UnsignedPlan) {
    $defects=[Collections.Generic.List[string]]::new()
    function Check([bool]$Condition,[string]$Name){if(-not$Condition){$defects.Add($Name)}}
    $evidenceStatus='CANONICAL_WINDOWS_11_DRIVER_PACKAGE_BUILT_AND_CATALOGED_UNSIGNED_FOR_LOCAL_DEVELOPMENT_NOT_STAGED_NOT_INSTALLED_NOT_LOADED_NOT_INDEPENDENTLY_AUDITED'
    $evidenceReadiness='READY_FOR_LOCAL_DEVELOPMENT_PACKAGE_AND_DEPLOYMENT_CONTRACT_AUDIT_ONLY'
    $status='LOCAL_DEVELOPMENT_HOST_READINESS_OBSERVED_TESTSIGNING_CONFIGURED_REBOOT_PENDING_HVCI_ACTIVE_PACKAGE_UNSIGNED_UNSTAGED_UNINSTALLED_UNLOADED'
    $readiness='READY_FOR_SELF_TEST_SIGNED_LOCAL_DEVELOPMENT_PACKAGE_PREPARATION_ONLY'
    $commit='4510e1f2f8a4b4e31ac40672261cf4ad94ec27c5'
    $project='src/driver/ChatpadFilter/ChatpadFilter.vcxproj'
    $projectHash='5641815C63FBB0C2A7442E555A1B70F3BE4C22014DF2BA29A29E987A2D903112'
    $infHash='0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC'
    $sysHash='E4E7BCA837F6B0C662A24CFDDC260D781FDA85E0B37CAE470D65A9716DB174BB'
    $catHash='6F0ABF84AE68010008A0360D4DDF716E644DD8D63E669F3AA96F27047EF613FD'
    $evidenceBlocker='BLOCKED_NATIVE_ADAPTER_LOCAL_DEVELOPMENT_PACKAGE_NOT_INDEPENDENTLY_AUDITED_AND_LOCAL_INSTALLATION_PATH_NOT_OBSERVED'
    $evidenceNext='TASK 8I-P1B-LD-R2 '+[char]0x2014+' Independent read-only audit of the unsigned canonical package and local-development deployment contract'
    $blocker='BLOCKED_NATIVE_ADAPTER_SELF_TEST_SIGNED_PACKAGE_NOT_CREATED_AND_CONFIGURED_TESTSIGNING_NOT_EFFECTIVE_UNTIL_REBOOT'
    $next='TASK 8I-P1B-LD-S1 '+[char]0x2014+' Create and freeze the self-test-signed local-development package'
    $future=@('windows_edition','windows_version','windows_build','secure_boot_state','test_signing_state','code_integrity_signature_enforcement_state','known_working_local_installation_mechanism','local_installation_mechanism_persistence','reboot_required_for_mechanism','signature_enforcement_changes_required','package_source_directory','published_inf_name_after_staging','driver_store_package_identity_after_staging','driver_node_provider','driver_node_description','driver_date','driver_version','driver_rank','driver_node_identity','exact_matching_candidate_count','target_physical_usb_node','target_container_id','restart_required_result','reboot_required_result','installed_service_identity','installed_filter_identity','rollback_package_identity','restoration_verification_fields')
    $prohibited=@('first enumerated candidate','lowest enumerated index','highest-ranked candidate without identity matching','hardware-ID-only matching','INF-basename-only matching','caller-selected candidate','caller-selected INF','wildcard provider','wildcard description','fallback candidate')
    $eTop=@('schema','status','readiness','source_commit','source_parent','driver_project','package_source_plan','canonical_inf','toolchain','configuration','tracked_source_input_inventory','builds','reproducibility','binary_validation','package','inf_validation','catalog_generation','signature_validation','deployment_policy','operation_counters','blocker','next_task')
    $pTop=@('schema','status','readiness','source_commit','driver_project','canonical_inf','unsigned_sys','unsigned_catalog','package_file_inventory','configuration','toolchain','reproducibility','architecture','driver_framework','driver_type','service_name','filter_name','filter_attachment','target','driver_ver','catalog_filename','unsigned_signature_states','host_readiness_observation','deployment_policy','candidate_selection','current_installability','future_local_deployment_fields','blocker','next_task')
    Check (Test-ExactPropertySet $Evidence $eTop) 'evidence-properties'
    Check (Test-ExactPropertySet $UnsignedPlan $pTop) 'plan-properties'
    Check ($Evidence.schema-ceq'chatpad-canonical-live-apply-package-build-evidence-v1'-and$UnsignedPlan.schema-ceq'chatpad-live-apply-unsigned-package-plan-v1') 'schema'
    Check ($Evidence.status-ceq$evidenceStatus-and$UnsignedPlan.status-ceq$status-and$Evidence.readiness-ceq$evidenceReadiness-and$UnsignedPlan.readiness-ceq$readiness) 'status-readiness'
    Check ($Evidence.source_commit-ceq$commit-and$UnsignedPlan.source_commit-ceq$commit) 'source-commit'
    Check ($Evidence.driver_project.path-ceq$project-and$UnsignedPlan.driver_project.path-ceq$project-and$Evidence.driver_project.sha256-ceq$projectHash-and$UnsignedPlan.driver_project.sha256-ceq$projectHash-and[long]$Evidence.driver_project.byte_size-eq7949-and$Evidence.driver_project.output_filename-ceq'ChatpadFilter.sys') 'driver-project'
    Check (Test-ExactPropertySet $Evidence.package_source_plan @('path','schema','build_time_identity','current_local_development_contract_identity','build_inputs_unchanged')) 'source-plan-properties'
    Check ($Evidence.package_source_plan.path-ceq'tools/ExactInstance/contracts/chatpad-live-apply-package-source-plan.json'-and$Evidence.package_source_plan.schema-ceq'chatpad-live-apply-package-source-plan-v1'-and[long]$Evidence.package_source_plan.build_time_identity.byte_size-eq11888-and$Evidence.package_source_plan.build_time_identity.sha256-ceq'EF814E4525275000F0A14A27F708C1D04148FF2902F5D6CB2F5504E317D33E81'-and[long]$Evidence.package_source_plan.current_local_development_contract_identity.byte_size-eq12387-and$Evidence.package_source_plan.current_local_development_contract_identity.sha256-ceq'95DAABC9EE093466E53CDBCE039343C66458B555E30E42F59FBA8494C91862CB'-and[bool]$Evidence.package_source_plan.build_inputs_unchanged) 'source-plan'
    Check ($Evidence.canonical_inf.sha256-ceq$infHash-and$UnsignedPlan.canonical_inf.sha256-ceq$infHash-and[long]$Evidence.canonical_inf.byte_size-eq1581-and$Evidence.canonical_inf.driver_ver-ceq'07/11/2026,1.0.0.0') 'inf-identity'
    $toolExpected=[ordered]@{visual_studio_edition='Visual Studio Community 2022';visual_studio_display_version='17.14.35 (June 2026)';visual_studio_installation_version='17.14.37411.7';msbuild_version='17.14.40.60911';wdk_version='10.0.26100.0';windows_sdk_version='10.0.26100.0';kmdf_version='1.15';platform_toolset='WindowsKernelModeDriver10.0';compiler_version='19.44.35228.0';linker_version='14.44.35228.0';infverif_version='10.0.26100.6584';inf2cat_version='1.0.0519.24+3dc05997';signtool_version='10.0.26100.7705'}
    foreach($name in $toolExpected.Keys){Check ($Evidence.toolchain.$name-ceq$toolExpected[$name]) "toolchain-$name"}
    foreach($name in @('visual_studio_path','msbuild_path','compiler_path','linker_path','dumpbin_path','infverif_path','inf2cat_path','signtool_path')){Check ($Evidence.toolchain.$name-is[string]-and-not[string]::IsNullOrWhiteSpace($Evidence.toolchain.$name)) "toolpath-$name"}
    Check ($Evidence.configuration.configuration-ceq'Release'-and$Evidence.configuration.platform-ceq'x64'-and$Evidence.configuration.architecture-ceq'AMD64'-and$Evidence.configuration.sign_mode-ceq'Off'-and$Evidence.configuration.deterministic_link_environment-ceq'_LINK_=/Brepro /PDBALTPATH:ChatpadFilter.pdb') 'configuration'
    $sourcePlan=[IO.File]::ReadAllText($planPath)|ConvertFrom-Json
    Check ($sourcePlan.deployment_policy.deployment_scope-ceq'LOCAL_DEVELOPMENT_ONLY'-and-not[bool]$sourcePlan.deployment_policy.production_distribution_signing_required-and$sourcePlan.deployment_policy.production_distribution_signing-ceq'OUT_OF_SCOPE_OPTIONAL_FUTURE_WORK'-and$sourcePlan.deployment_policy.production_distribution_objective_classification-ceq'OUT_OF_SCOPE_FOR_CURRENT_LOCAL_DEVELOPMENT_OBJECTIVE') 'source-plan-deployment-policy'
    Check (@($Evidence.tracked_source_input_inventory).Count-eq25) 'source-inventory-count'
    if(@($Evidence.tracked_source_input_inventory).Count-eq25){for($i=0;$i-lt25;$i++){Check ($Evidence.tracked_source_input_inventory[$i].path-ceq$sourcePlan.driver_source_inventory[$i].path-and$Evidence.tracked_source_input_inventory[$i].sha256-ceq$sourcePlan.driver_source_inventory[$i].sha256) "source-inventory-$i"}}
    Check (@($Evidence.builds).Count-eq2) 'build-count'
    if(@($Evidence.builds).Count-eq2){for($i=0;$i-lt2;$i++){$b=$Evidence.builds[$i];Check ($b.label-ceq@('A','B')[$i]-and$b.source_commit-ceq$commit-and[long]$b.exit_code-eq0-and[long]$b.warning_count-eq0-and[long]$b.error_count-eq0-and[long]$b.sys_byte_size-eq40960-and$b.sys_sha256-ceq$sysHash-and$b.link_environment-ceq'_LINK_=/Brepro /PDBALTPATH:ChatpadFilter.pdb'-and$b.command-match'/p:Configuration=Release'-and$b.command-match'/p:Platform=x64'-and$b.command-match'/p:SignMode=Off') "build-$i"};Check ($Evidence.builds[0].task_output_root-cne$Evidence.builds[1].task_output_root) 'build-root-reuse'}
    Check ([bool]$Evidence.reproducibility.sys_byte_identical-and[bool]$Evidence.reproducibility.sys_reproducible-and-not[bool]$Evidence.reproducibility.pdb_byte_identical-and-not[bool]$Evidence.reproducibility.manual_binary_normalization_performed) 'reproducibility'
    $binary=$Evidence.binary_validation
    Check ($binary.filename-ceq'ChatpadFilter.sys'-and[long]$binary.byte_size-eq40960-and$binary.sha256-ceq$sysHash-and$binary.pe_machine-ceq'0x8664'-and$binary.architecture-ceq'AMD64'-and$binary.subsystem-ceq'Native'-and$binary.entry_point-ceq'FxDriverEntry'-and[long]$binary.certificate_directory_size-eq0-and-not[bool]$binary.embedded_test_certificate-and$binary.signature_state-ceq'unsigned') 'binary'
    Check (@($binary.imports).Count-eq2-and$binary.imports[0]-ceq'ntoskrnl.exe'-and$binary.imports[1]-ceq'WDFLDR.SYS') 'imports'
    Check (@($Evidence.package.inventory).Count-eq3-and[long]$Evidence.package.extra_file_count-eq0-and-not[bool]$Evidence.package.pdb_in_package) 'package-inventory-count'
    if(@($Evidence.package.inventory).Count-eq3){Check ($Evidence.package.inventory[0].filename-ceq'ChatpadFilterExtension.inf'-and$Evidence.package.inventory[0].sha256-ceq$infHash-and$Evidence.package.inventory[1].filename-ceq'ChatpadFilter.sys'-and$Evidence.package.inventory[1].sha256-ceq$sysHash-and$Evidence.package.inventory[2].filename-ceq'ChatpadFilterExtension.cat'-and$Evidence.package.inventory[2].sha256-ceq$catHash) 'package-inventory'}
    Check ($Evidence.inf_validation.result-ceq'INF is VALID'-and[long]$Evidence.inf_validation.exit_code-eq0-and[long]$Evidence.inf_validation.warning_count-eq0-and[long]$Evidence.inf_validation.error_count-eq0-and[bool]$Evidence.inf_validation.copied_byte_for_byte) 'infverif'
    Check ($Evidence.catalog_generation.filename-ceq'ChatpadFilterExtension.cat'-and$Evidence.catalog_generation.os_target-ceq'10_CO_X64'-and[long]$Evidence.catalog_generation.exit_code-eq0-and[long]$Evidence.catalog_generation.warning_count-eq0-and[long]$Evidence.catalog_generation.error_count-eq0-and[long]$Evidence.catalog_generation.byte_size-eq1202-and$Evidence.catalog_generation.sha256-ceq$catHash-and[long]$Evidence.catalog_generation.extra_member_count-eq0-and-not[bool]$Evidence.catalog_generation.signer_present) 'catalog'
    Check (@($Evidence.catalog_generation.members).Count-eq2-and$Evidence.catalog_generation.members[0].filename-ceq'ChatpadFilterExtension.inf'-and$Evidence.catalog_generation.members[0].catalog_sha256-ceq$infHash-and$Evidence.catalog_generation.members[1].filename-ceq'ChatpadFilter.sys'-and$Evidence.catalog_generation.members[1].catalog_sha256-ceq'7CC0E1F59375E0C34DAAE9543385AE1FBD6CFC04E5A8B0885167D704C9515F8F') 'catalog-members'
    Check (Test-ExactPropertySet $Evidence.signature_validation @('sys_state','sys_signtool_exit_code','sys_signtool_error','cat_state','cat_signtool_exit_code','cat_signtool_error','test_certificate_present','unexpected_signer_present')) 'signature-properties'
    Check ($Evidence.signature_validation.sys_state-ceq'unsigned'-and$Evidence.signature_validation.cat_state-ceq'unsigned'-and[long]$Evidence.signature_validation.sys_signtool_exit_code-eq1-and[long]$Evidence.signature_validation.cat_signtool_exit_code-eq1-and-not[bool]$Evidence.signature_validation.test_certificate_present-and-not[bool]$Evidence.signature_validation.unexpected_signer_present) 'signature-state'
    $deployment=$Evidence.deployment_policy
    Check (Test-ExactPropertySet $deployment @('deployment_scope','current_required_route','package_signed','package_staged','package_installed','driver_loaded','local_installation_method','local_signature_enforcement_state','local_candidate_identity','local_published_inf_name','ordinary_production_signature_enforcement_loadability_claimed','host_readiness_observation_performed','local_package_inventory','diagnostic_symbol_input','optional_future_production_distribution','future_local_deployment_fields')) 'evidence-deployment-properties'
    Check ($deployment.deployment_scope-ceq'LOCAL_DEVELOPMENT_ONLY'-and$deployment.current_required_route-ceq'CONTROLLED_LOCAL_DEVELOPMENT_INSTALLATION'-and-not[bool]$deployment.package_signed-and-not[bool]$deployment.package_staged-and-not[bool]$deployment.package_installed-and-not[bool]$deployment.driver_loaded-and$deployment.local_installation_method-ceq'NOT_YET_OBSERVED'-and$deployment.local_signature_enforcement_state-ceq'NOT_YET_OBSERVED'-and$deployment.local_candidate_identity-ceq'NOT_YET_OBSERVED'-and$deployment.local_published_inf_name-ceq'NOT_YET_OBSERVED'-and-not[bool]$deployment.ordinary_production_signature_enforcement_loadability_claimed-and-not[bool]$deployment.host_readiness_observation_performed) 'evidence-local-state'
    Check (@($deployment.local_package_inventory).Count-eq3-and$deployment.local_package_inventory[0].sha256-ceq$infHash-and$deployment.local_package_inventory[1].sha256-ceq$sysHash-and$deployment.local_package_inventory[2].sha256-ceq$catHash) 'evidence-local-package'
    Check ($deployment.diagnostic_symbol_input.filename-ceq'ChatpadFilter.pdb'-and$deployment.diagnostic_symbol_input.sha256-ceq'6759516C2B70396A8B248B4013CE852DF55144A83B2D6DE6DCCD1D9400FDB648'-and-not[bool]$deployment.diagnostic_symbol_input.installable_package_member) 'diagnostic-symbol'
    $optional=$deployment.optional_future_production_distribution
    Check (Test-ExactPropertySet $optional @('classification','signing_route','whcp_hlk_required_for_current_objective','partner_center_submission_required_for_current_objective','windows_update_publication_required_for_current_objective','microsoft_production_signing_required_for_current_objective')) 'optional-production-properties'
    Check ($optional.classification-ceq'OUT_OF_SCOPE_FOR_CURRENT_LOCAL_DEVELOPMENT_OBJECTIVE'-and$optional.signing_route-ceq'OUT_OF_SCOPE_OPTIONAL_FUTURE_WORK'-and-not[bool]$optional.whcp_hlk_required_for_current_objective-and-not[bool]$optional.partner_center_submission_required_for_current_objective-and-not[bool]$optional.windows_update_publication_required_for_current_objective-and-not[bool]$optional.microsoft_production_signing_required_for_current_objective) 'optional-production-state'
    Check (@(Compare-Object $future @($deployment.future_local_deployment_fields) -CaseSensitive).Count-eq0-and@($deployment.future_local_deployment_fields).Count-eq28) 'evidence-future-fields'
    foreach($name in @('file_signing_count','certificate_creation_count','certificate_installation_count','private_key_access_count','portal_access_count','submission_count','package_staging_count','installation_count','driver_load_count','native_declaration_load_count','native_invocation_count','device_query_count','driver_store_query_count','registry_query_count','service_query_count','setupapi_newdev_invocation_count','binding_count','authorization_issuance_count','authorization_consumption_count','restart_count','reenumeration_count','rollback_count','restoration_count','windows_mutation_count')){Check ([long]$Evidence.operation_counters.$name-eq0) "counter-$name"}
    Check ($UnsignedPlan.unsigned_sys.sha256-ceq$sysHash-and[long]$UnsignedPlan.unsigned_sys.byte_size-eq40960-and$UnsignedPlan.unsigned_catalog.sha256-ceq$catHash-and[long]$UnsignedPlan.unsigned_catalog.byte_size-eq1202-and@($UnsignedPlan.package_file_inventory).Count-eq3-and$UnsignedPlan.package_file_inventory[0]-ceq'ChatpadFilterExtension.inf'-and$UnsignedPlan.package_file_inventory[1]-ceq'ChatpadFilter.sys'-and$UnsignedPlan.package_file_inventory[2]-ceq'ChatpadFilterExtension.cat'-and$UnsignedPlan.configuration.configuration-ceq'Release'-and$UnsignedPlan.configuration.platform-ceq'x64'-and$UnsignedPlan.architecture-ceq'AMD64'-and$UnsignedPlan.driver_framework-ceq'KMDF 1.15') 'plan-package'
    $planDeployment=$UnsignedPlan.deployment_policy
    Check (Test-ExactPropertySet $planDeployment @('deployment_scope','current_required_route','package_signed','package_staged','package_installed','driver_loaded','local_installation_method','local_signature_enforcement_state','local_candidate_identity','local_published_inf_name','ordinary_production_signature_enforcement_loadability_claimed','host_readiness_observation_performed','diagnostic_symbol_input','optional_future_production_distribution')) 'plan-deployment-properties'
    Check ($planDeployment.deployment_scope-ceq'LOCAL_DEVELOPMENT_ONLY'-and$planDeployment.current_required_route-ceq'CONTROLLED_LOCAL_DEVELOPMENT_INSTALLATION'-and-not[bool]$planDeployment.package_signed-and-not[bool]$planDeployment.package_staged-and-not[bool]$planDeployment.package_installed-and-not[bool]$planDeployment.driver_loaded-and$planDeployment.local_installation_method-ceq'NOT_YET_OBSERVED'-and$planDeployment.local_signature_enforcement_state-ceq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'-and$planDeployment.local_candidate_identity-ceq'NOT_YET_OBSERVED'-and$planDeployment.local_published_inf_name-ceq'NOT_YET_OBSERVED'-and-not[bool]$planDeployment.ordinary_production_signature_enforcement_loadability_claimed-and[bool]$planDeployment.host_readiness_observation_performed-and$UnsignedPlan.current_installability-ceq'NOT_INSTALLABLE_UNTIL_SELF_TEST_SIGNED_PACKAGE_EXISTS_AND_CONFIGURED_TESTSIGNING_IS_ACTIVATED_BY_REBOOT') 'plan-local-state'
    $hostObservation=$UnsignedPlan.host_readiness_observation
    $hostShape=Test-ExactPropertySet $hostObservation @('path','schema','byte_size','sha256','selected_outcome','secure_boot_state','testsigning_configured','reboot_since_testsigning_change','effective_test_mode_current_boot','local_signing_state','hvci_memory_integrity_state','embedded_test_signature_required_for_sys','signature_enforcement_change_required','bitlocker_protection_status','system_volume_lock_status','observer_mutation_count','external_bcd_mutation_recorded','overall_lane_mutation_count','supersedes_observation_sha256','superseded_outcome','supersession_reason','next_task')
    Check $hostShape 'host-readiness-properties'
    if($hostShape){Check ($hostObservation.path-ceq'docs/evidence/local-development-host-readiness-observation-task-8i-p1b-ld-o1.json'-and$hostObservation.schema-ceq'chatpad-local-development-host-readiness-observation-v1'-and[long]$hostObservation.byte_size-eq8467-and$hostObservation.sha256-ceq'019D59504588384DDD48B90B2315A261AE891030113C7953DF6EA2778F3E651C'-and$hostObservation.selected_outcome-ceq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'-and$hostObservation.secure_boot_state-ceq'DISABLED'-and[bool]$hostObservation.testsigning_configured-and-not[bool]$hostObservation.reboot_since_testsigning_change-and$hostObservation.effective_test_mode_current_boot-ceq'NOT_CONCLUSIVELY_OBSERVED'-and$hostObservation.local_signing_state-ceq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'-and$hostObservation.hvci_memory_integrity_state-ceq'ACTIVE'-and[bool]$hostObservation.embedded_test_signature_required_for_sys-and$hostObservation.signature_enforcement_change_required-ceq'REBOOT_REQUIRED_TO_ACTIVATE_CONFIGURED_TESTSIGNING'-and$hostObservation.bitlocker_protection_status-ceq'Off'-and$hostObservation.system_volume_lock_status-ceq'Unlocked'-and[long]$hostObservation.observer_mutation_count-eq0-and[bool]$hostObservation.external_bcd_mutation_recorded-and[long]$hostObservation.overall_lane_mutation_count-eq1-and$hostObservation.supersedes_observation_sha256-ceq'255C874A774CF6492B4A70A99214988824351E738B9AC8D10443F59B441E31C3'-and$hostObservation.superseded_outcome-ceq'LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'-and$hostObservation.supersession_reason-ceq'TARGETED_HOST_READINESS_OBSERVATION_REMEDIATION'-and$hostObservation.next_task-ceq$next) 'host-readiness-state'}
    Check ((Get-Item -LiteralPath $hostReadinessEvidencePath).Length-eq8467-and(Get-FileHash -LiteralPath $hostReadinessEvidencePath -Algorithm SHA256).Hash-ceq$hostObservation.sha256) 'host-readiness-file-identity'
    $hostEvidence=[IO.File]::ReadAllText($hostReadinessEvidencePath)|ConvertFrom-Json
    Check ($hostEvidence.selected_outcome-ceq$hostObservation.selected_outcome-and$hostEvidence.next_task-ceq$next-and$hostEvidence.secure_boot.state-ceq'DISABLED'-and$hostEvidence.testsigning_state-ceq'ENABLED'-and$hostEvidence.pre_observation_context.reboot_since_testsigning_change-ceq'OPERATOR_REPORTED_FALSE'-and$hostEvidence.pre_observation_context.effective_test_mode_current_boot-ceq'NOT_CONCLUSIVELY_OBSERVED'-and[bool]$hostEvidence.hvci.running-and[bool]$hostEvidence.hvci.future_sys_embedded_test_signature_required-and$hostEvidence.bitlocker.protection_status-ceq'Off'-and[long]$hostEvidence.observer_mutation_count-eq0-and[long]$hostEvidence.overall_lane_mutation_count-eq1-and-not[bool]$hostEvidence.pre_observation_context.pre_observation_external_mutation.performed_by_observer-and$hostEvidence.supersedes_observation_sha256-ceq$hostObservation.supersedes_observation_sha256) 'host-readiness-evidence-semantics'
    Check ($planDeployment.optional_future_production_distribution.classification-ceq'OUT_OF_SCOPE_FOR_CURRENT_LOCAL_DEVELOPMENT_OBJECTIVE'-and$planDeployment.optional_future_production_distribution.signing_route-ceq'OUT_OF_SCOPE_OPTIONAL_FUTURE_WORK'-and-not[bool]$planDeployment.optional_future_production_distribution.whcp_hlk_required_for_current_objective-and-not[bool]$planDeployment.optional_future_production_distribution.partner_center_submission_required_for_current_objective-and-not[bool]$planDeployment.optional_future_production_distribution.windows_update_publication_required_for_current_objective-and-not[bool]$planDeployment.optional_future_production_distribution.microsoft_production_signing_required_for_current_objective) 'plan-optional-production'
    Check (Test-ExactPropertySet $UnsignedPlan.candidate_selection @('scope','state','zero_exact_matches','one_exact_match','multiple_exact_matches','required_stable_discriminators','prohibited_strategies')) 'candidate-properties'
    Check ($UnsignedPlan.candidate_selection.scope-ceq'LOCAL_DEVELOPMENT_PACKAGE'-and$UnsignedPlan.candidate_selection.state-ceq'NOT_YET_OBSERVED'-and$UnsignedPlan.candidate_selection.zero_exact_matches-ceq'REJECT'-and$UnsignedPlan.candidate_selection.one_exact_match-ceq'ELIGIBLE'-and$UnsignedPlan.candidate_selection.multiple_exact_matches-ceq'REJECT_AMBIGUOUS'-and@(Compare-Object $prohibited @($UnsignedPlan.candidate_selection.prohibited_strategies) -CaseSensitive).Count-eq0) 'candidate-rules'
    Check (@(Compare-Object $future @($UnsignedPlan.future_local_deployment_fields) -CaseSensitive).Count-eq0-and@($UnsignedPlan.future_local_deployment_fields).Count-eq28) 'plan-future-fields'
    Check ($Evidence.blocker-ceq$evidenceBlocker-and$UnsignedPlan.blocker-ceq$blocker-and$Evidence.next_task-ceq$evidenceNext-and$UnsignedPlan.next_task-ceq$next) 'blocker-next'
    Check ($Evidence.driver_project.path-ceq$UnsignedPlan.driver_project.path-and$Evidence.driver_project.sha256-ceq$UnsignedPlan.driver_project.sha256-and$Evidence.canonical_inf.sha256-ceq$UnsignedPlan.canonical_inf.sha256-and$Evidence.binary_validation.sha256-ceq$UnsignedPlan.unsigned_sys.sha256-and$Evidence.catalog_generation.sha256-ceq$UnsignedPlan.unsigned_catalog.sha256-and$Evidence.deployment_policy.deployment_scope-ceq$UnsignedPlan.deployment_policy.deployment_scope-and$Evidence.deployment_policy.local_installation_method-ceq$UnsignedPlan.deployment_policy.local_installation_method) 'evidence-plan-equality'
    return [pscustomobject]@{result=if($defects.Count){'FAIL'}else{'PASS'};defect_count=$defects.Count;defects=@($defects)}
}

if($UnsignedPackage){
    try{
        $baselineEvidence=[IO.File]::ReadAllText($unsignedEvidencePath)|ConvertFrom-Json
        $baselineUnsignedPlan=[IO.File]::ReadAllText($unsignedPlanPath)|ConvertFrom-Json
        Pass-Test 'canonical unsigned evidence and plan pass'{$r=Test-UnsignedPackageObjects $baselineEvidence $baselineUnsignedPlan;Assert-Test ($r.result-eq'PASS'-and$r.defect_count-eq0) ($r.defects-join'; ')}
        $cases=@(
            @{n='wrong source commit';m={param($e,$p)$e.source_commit='0'*40}},
            @{n='wrong project';m={param($e,$p)$e.driver_project.path='wrong.vcxproj'}},
            @{n='Debug build';m={param($e,$p)$e.configuration.configuration='Debug'}},
            @{n='Win32 build';m={param($e,$p)$e.configuration.platform='Win32'}},
            @{n='reproducibility failure';m={param($e,$p)$e.builds[1].sys_sha256='A'*64}},
            @{n='wrong architecture';m={param($e,$p)$e.binary_validation.pe_machine='0x014C'}},
            @{n='added package file';m={param($e,$p)$e.package.inventory+=[pscustomobject]@{filename='extra';byte_size=1;sha256='A'*64;role='extra'}}},
            @{n='missing package file';m={param($e,$p)$e.package.inventory=@($e.package.inventory[0..1])}},
            @{n='wrong package member';m={param($e,$p)$p.package_file_inventory[1]='Wrong.sys'}},
            @{n='wrong INF hash';m={param($e,$p)$e.canonical_inf.sha256='B'*64}},
            @{n='wrong SYS hash';m={param($e,$p)$p.unsigned_sys.sha256='C'*64}},
            @{n='wrong CAT hash';m={param($e,$p)$p.unsigned_catalog.sha256='D'*64}},
            @{n='missing catalog member';m={param($e,$p)$e.catalog_generation.members=@($e.catalog_generation.members[0])}},
            @{n='added catalog member';m={param($e,$p)$e.catalog_generation.members+=[pscustomobject]@{filename='extra';catalog_sha1='A'*40;catalog_sha256='A'*64}}},
            @{n='test certificate fabrication';m={param($e,$p)$e.signature_validation.test_certificate_present=$true}},
            @{n='production-signed fabrication';m={param($e,$p)$e.status='PRODUCTION_SIGNED'}},
            @{n='placeholder signer';m={param($e,$p)$e.signature_validation|Add-Member -NotePropertyName signer_subject -NotePropertyValue 'PLACEHOLDER'}},
            @{n='WHCP HLK mandatory for local objective';m={param($e,$p)$p.deployment_policy.optional_future_production_distribution.whcp_hlk_required_for_current_objective=$true}},
            @{n='Partner Center next required task';m={param($e,$p)$e.next_task='Partner Center submission required next'}},
            @{n='production signing required for completion';m={param($e,$p)$e.deployment_policy.optional_future_production_distribution.microsoft_production_signing_required_for_current_objective=$true}},
            @{n='installable overclaim';m={param($e,$p)$p.current_installability='INSTALLABLE'}},
            @{n='package already staged';m={param($e,$p)$e.deployment_policy.package_staged=$true}},
            @{n='package already installed';m={param($e,$p)$e.deployment_policy.package_installed=$true}},
            @{n='driver already loaded';m={param($e,$p)$e.deployment_policy.driver_loaded=$true}},
            @{n='fabricated local installation method';m={param($e,$p)$e.deployment_policy.local_installation_method='PNPUTIL_WORKS'}},
            @{n='fabricated local enforcement state';m={param($e,$p)$e.deployment_policy.local_signature_enforcement_state='KNOWN'}},
            @{n='fabricated published INF';m={param($e,$p)$p.deployment_policy.local_published_inf_name='oem42.inf'}},
            @{n='fabricated candidate rank';m={param($e,$p)$p.candidate_selection|Add-Member -NotePropertyName driver_rank -NotePropertyValue 1}},
            @{n='fabricated driver store identity';m={param($e,$p)$p.deployment_policy|Add-Member -NotePropertyName driver_store_identity -NotePropertyValue 'fabricated'}},
            @{n='test mode assumed';m={param($e,$p)$p.deployment_policy.local_signature_enforcement_state='TEST_MODE_ENABLED'}},
            @{n='signature enforcement bypass assumed';m={param($e,$p)$p.deployment_policy.local_signature_enforcement_state='SIGNATURE_ENFORCEMENT_BYPASSED'}},
            @{n='ordinary production loadability overclaim';m={param($e,$p)$p.deployment_policy.ordinary_production_signature_enforcement_loadability_claimed=$true}},
            @{n='wrong local blocker';m={param($e,$p)$e.blocker='WRONG'}},
            @{n='wrong local next task';m={param($e,$p)$e.next_task='WRONG'}},
            @{n='evidence contract disagreement';m={param($e,$p)$p.deployment_policy.local_installation_method='DIFFERENT'}},
            @{n='zero candidate acceptance';m={param($e,$p)$p.candidate_selection.zero_exact_matches='ELIGIBLE'}},
            @{n='multiple candidate acceptance';m={param($e,$p)$p.candidate_selection.multiple_exact_matches='ELIGIBLE'}},
            @{n='best ranked fallback allowed';m={param($e,$p)$p.candidate_selection.prohibited_strategies=@($p.candidate_selection.prohibited_strategies|Where-Object{$_-ne'highest-ranked candidate without identity matching'})}},
            @{n='missing future observation field';m={param($e,$p)$p.future_local_deployment_fields=@($p.future_local_deployment_fields|Where-Object{$_-ne'secure_boot_state'})}},
            @{n='TESTSIGNING marked effective before reboot';m={param($e,$p)$p.host_readiness_observation.effective_test_mode_current_boot='CONCLUSIVELY_ENABLED'}},
            @{n='Outcome A inferred from BCD';m={param($e,$p)$p.host_readiness_observation.selected_outcome='LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION'}},
            @{n='Secure Boot marked enabled';m={param($e,$p)$p.host_readiness_observation.secure_boot_state='ENABLED'}},
            @{n='BitLocker marked protected';m={param($e,$p)$p.host_readiness_observation.bitlocker_protection_status='On'}},
            @{n='HVCI marked inactive';m={param($e,$p)$p.host_readiness_observation.hvci_memory_integrity_state='INACTIVE'}},
            @{n='embedded SYS signature unnecessary';m={param($e,$p)$p.host_readiness_observation.embedded_test_signature_required_for_sys=$false}},
            @{n='observer mutation nonzero';m={param($e,$p)$p.host_readiness_observation.observer_mutation_count=1}},
            @{n='external BCD mutation omitted';m={param($e,$p)$p.host_readiness_observation.external_bcd_mutation_recorded=$false}},
            @{n='overall lane mutation zero';m={param($e,$p)$p.host_readiness_observation.overall_lane_mutation_count=0}},
            @{n='package marked signed';m={param($e,$p)$p.deployment_policy.package_signed=$true}},
            @{n='plan package staged';m={param($e,$p)$p.deployment_policy.package_staged=$true}},
            @{n='plan package installed';m={param($e,$p)$p.deployment_policy.package_installed=$true}},
            @{n='plan driver loaded';m={param($e,$p)$p.deployment_policy.driver_loaded=$true}},
            @{n='candidate populated';m={param($e,$p)$p.candidate_selection.state='OBSERVED'}},
            @{n='host next task wrong';m={param($e,$p)$p.host_readiness_observation.next_task='WRONG'}},
            @{n='host evidence hash disagreement';m={param($e,$p)$p.host_readiness_observation.sha256='A'*64}},
            @{n='supersession metadata removed';m={param($e,$p)$p.host_readiness_observation.PSObject.Properties.Remove('supersession_reason')}},
            @{n='wrong deployment scope';m={param($e,$p)$p.deployment_policy.deployment_scope='COMMERCIAL_DISTRIBUTION'}}
        )
        foreach($case in $cases){$e=(($baselineEvidence|ConvertTo-Json -Depth 40)|ConvertFrom-Json);$p=(($baselineUnsignedPlan|ConvertTo-Json -Depth 40)|ConvertFrom-Json);&$case.m $e $p;$fixture=Join-Path $tempRoot ([guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $fixture|Out-Null;$ef=Join-Path $fixture 'evidence.json';$pf=Join-Path $fixture 'plan.json';[IO.File]::WriteAllText($ef,($e|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($pf,($p|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false));$r=Test-UnsignedPackageObjects ([IO.File]::ReadAllText($ef)|ConvertFrom-Json) ([IO.File]::ReadAllText($pf)|ConvertFrom-Json);Pass-Test ("rejects "+$case.n){Assert-Test ($r.result-eq'FAIL'-and$r.defect_count-gt0) ("Tamper passed: "+$case.n)}}
        Write-Output "TASK 8I-P1B-2A unsigned-package focused tests: $script:tests tests / $script:assertions assertions"
        exit 0
    }finally{if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}}
}

try {
    $baseline=Test-ChatpadLiveApplyPackageSourceContract
    Pass-Test 'canonical contract validates' { Assert-Test ($baseline.is_valid -and $baseline.defect_count -eq 0) "Canonical contract failed: $($baseline.defects -join '; ')" }
    Pass-Test 'canonical INF is outside prototypes' { Assert-Test (-not $infPath.StartsWith((Split-Path $prototypePath -Parent),[System.StringComparison]::OrdinalIgnoreCase)) 'Canonical INF is inside prototypes.' }
    Pass-Test 'prototype identity is exact' { Assert-Test ((Get-Item $prototypePath).Length -eq 1701 -and (Get-FileHash -Algorithm SHA256 $prototypePath).Hash -eq '821368368000A706BD2EAC0CB659090915C34E363F59F3F19F23D6DE0C4A05F4') 'Prototype identity changed.' }
    Pass-Test 'current status remains local-development and inactive' { $p=Clone-Plan; Assert-Test ($p.status -match 'FOR_LOCAL_DEVELOPMENT_NOT_STAGED_NOT_INSTALLED_NOT_LOADED') 'Local-development inactive status missing.' }
    Pass-Test 'future local observation inventory is complete' { $p=Clone-Plan; Assert-Test (@($p.future_local_deployment_fields).Count -eq 28) 'Future local observation inventory count changed.' }

    Invoke-RejectedFixture 'prototype path selected as production' { param($p) $p.canonical_inf.path='prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf' } $null
    Invoke-RejectedFixture 'wrong INF hash' { param($p) $p.canonical_inf.sha256=('0'*64) } $null
    Invoke-RejectedFixture 'wrong driver project' { param($p) $p.production_driver_project.path='src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj' } $null
    Invoke-RejectedFixture 'wrong binary filename' { param($p) $p.driver_binary_filename='Wrong.sys' } $null
    Invoke-RejectedFixture 'wrong class' { param($p) $p.device_setup_class.name='System' } $null
    Invoke-RejectedFixture 'wrong ClassGuid' { param($p) $p.device_setup_class.guid='{00000000-0000-0000-0000-000000000000}' } $null
    Invoke-RejectedFixture 'wrong provider' { param($p) $p.provider='*' } $null
    Invoke-RejectedFixture 'wrong hardware ID' { param($p) $p.stable_hardware_ids=@('USB\VID_045E&PID_FFFF') } $null
    Invoke-RejectedFixture 'added broad model' $null { param($s) $s -replace '(\[Models\.NTamd64\.10\.0\.\.\.22000\]\r?\n)',"`$1%Broad% = ChatpadFilter_Install, USB\Class_00`r`n" }
    Invoke-RejectedFixture 'missing architecture decoration' $null { param($s) $s.Replace('Models,NTamd64.10.0...22000','Models').Replace('[Models.NTamd64.10.0...22000]','[Models]') }
    Invoke-RejectedFixture 'changed filter order' $null { param($s) $s.Replace('FilterPosition = Lower','FilterPosition = Upper') }
    Invoke-RejectedFixture 'missing catalog filename' $null { param($s) $s -replace '(?m)^CatalogFile.*\r?\n','' }
    Invoke-RejectedFixture 'production signing made mandatory for local development' { param($p) $p.deployment_policy.production_distribution_signing_required=$true } $null
    Invoke-RejectedFixture 'placeholder catalog hash' { param($p) $p | Add-Member -NotePropertyName catalog_sha256 -NotePropertyValue ('0'*64) } $null
    Invoke-RejectedFixture 'placeholder signer' { param($p) $p | Add-Member -NotePropertyName package_signer_subject -NotePropertyValue 'PLACEHOLDER' } $null
    Invoke-RejectedFixture 'first enumerated candidate' { param($p) $p.caller_controls.first_or_best_driver_fallback_permitted=$true } $null
    Invoke-RejectedFixture 'best-ranked-only candidate' { param($p) $p.candidate_rule.prohibited_strategies=@($p.candidate_rule.prohibited_strategies | Where-Object { $_ -ne 'highest-ranked candidate without identity matching' }) } $null
    Invoke-RejectedFixture 'zero-match acceptance' { param($p) $p.candidate_rule.zero_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'multiple-match acceptance' { param($p) $p.candidate_rule.multiple_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'missing future local observation field' { param($p) $p.future_local_deployment_fields=@($p.future_local_deployment_fields | Where-Object { $_ -ne 'code_integrity_signature_enforcement_state' }) } $null
    Invoke-RejectedFixture 'added source file' { param($p) $p.package_source_inventory += [pscustomobject]@{role='extra';path='README.md';sha256=(Get-FileHash -Algorithm SHA256 (Join-Path $repoRoot 'README.md')).Hash} } $null
    Invoke-RejectedFixture 'caller-selected package path' { param($p) $p.caller_controls.caller_selected_package_path_permitted=$true } $null
    Invoke-RejectedFixture 'wrong blocker' { param($p) $p.blocker='WRONG_BLOCKER' } $null
    Invoke-RejectedFixture 'wrong next task' { param($p) $p.next_task='TASK 8I-P1C' } $null

    Write-Output "TASK 8I-P1B-1-C1 package-source focused tests: $script:tests tests / $script:assertions assertions"
    Write-Output 'Build/package/catalog/signing/staging/native/device/authorization/binding/mutation counters: 0/0/0/0/0/0/0/0/0/0'
    exit 0
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
