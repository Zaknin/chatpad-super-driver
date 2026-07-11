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
    $status='CANONICAL_WINDOWS_11_DRIVER_PACKAGE_BUILT_AND_CATALOGED_UNSIGNED_NOT_PRODUCTION_SIGNED_NOT_STAGED_NOT_INSTALLABLE_NOT_INDEPENDENTLY_AUDITED'
    $readiness='READY_FOR_EXTERNAL_PRODUCTION_SIGNING_PREPARATION_ONLY'
    $commit='4510e1f2f8a4b4e31ac40672261cf4ad94ec27c5'
    $project='src/driver/ChatpadFilter/ChatpadFilter.vcxproj'
    $projectHash='5641815C63FBB0C2A7442E555A1B70F3BE4C22014DF2BA29A29E987A2D903112'
    $infHash='0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC'
    $sysHash='E4E7BCA837F6B0C662A24CFDDC260D781FDA85E0B37CAE470D65A9716DB174BB'
    $catHash='6F0ABF84AE68010008A0360D4DDF716E644DD8D63E669F3AA96F27047EF613FD'
    $blocker='BLOCKED_NATIVE_ADAPTER_CANONICAL_DRIVER_PACKAGE_NOT_PRODUCTION_SIGNED_AND_INDEPENDENTLY_AUDITED'
    $next='TASK 8I-P1B-2B '+[char]0x2014+' Obtain and validate the externally production-signed canonical Windows 11 driver package'
    $eTop=@('schema','status','readiness','source_commit','source_parent','driver_project','package_source_plan','canonical_inf','toolchain','configuration','tracked_source_input_inventory','builds','reproducibility','binary_validation','package','inf_validation','catalog_generation','signature_validation','external_signing_handoff','operation_counters','blocker','next_task')
    $pTop=@('schema','status','readiness','source_commit','driver_project','canonical_inf','unsigned_sys','unsigned_catalog','package_file_inventory','configuration','toolchain','reproducibility','architecture','driver_framework','driver_type','service_name','filter_name','filter_attachment','target','driver_ver','catalog_filename','unsigned_signature_states','production_signing','current_installability','future_fields_unpopulated','blocker','next_task')
    Check (Test-ExactPropertySet $Evidence $eTop) 'evidence-properties'
    Check (Test-ExactPropertySet $UnsignedPlan $pTop) 'plan-properties'
    Check ($Evidence.schema-ceq'chatpad-canonical-live-apply-package-build-evidence-v1'-and$UnsignedPlan.schema-ceq'chatpad-live-apply-unsigned-package-plan-v1') 'schema'
    Check ($Evidence.status-ceq$status-and$UnsignedPlan.status-ceq$status-and$Evidence.readiness-ceq$readiness-and$UnsignedPlan.readiness-ceq$readiness) 'status-readiness'
    Check ($Evidence.source_commit-ceq$commit-and$UnsignedPlan.source_commit-ceq$commit) 'source-commit'
    Check ($Evidence.driver_project.path-ceq$project-and$UnsignedPlan.driver_project.path-ceq$project-and$Evidence.driver_project.sha256-ceq$projectHash-and$UnsignedPlan.driver_project.sha256-ceq$projectHash-and[long]$Evidence.driver_project.byte_size-eq7949-and$Evidence.driver_project.output_filename-ceq'ChatpadFilter.sys') 'driver-project'
    Check ($Evidence.package_source_plan.path-ceq'tools/ExactInstance/contracts/chatpad-live-apply-package-source-plan.json'-and[long]$Evidence.package_source_plan.byte_size-eq11888-and$Evidence.package_source_plan.sha256-ceq'EF814E4525275000F0A14A27F708C1D04148FF2902F5D6CB2F5504E317D33E81'-and$Evidence.package_source_plan.schema-ceq'chatpad-live-apply-package-source-plan-v1') 'source-plan'
    Check ($Evidence.canonical_inf.sha256-ceq$infHash-and$UnsignedPlan.canonical_inf.sha256-ceq$infHash-and[long]$Evidence.canonical_inf.byte_size-eq1581-and$Evidence.canonical_inf.driver_ver-ceq'07/11/2026,1.0.0.0') 'inf-identity'
    $toolExpected=[ordered]@{visual_studio_edition='Visual Studio Community 2022';visual_studio_display_version='17.14.35 (June 2026)';visual_studio_installation_version='17.14.37411.7';msbuild_version='17.14.40.60911';wdk_version='10.0.26100.0';windows_sdk_version='10.0.26100.0';kmdf_version='1.15';platform_toolset='WindowsKernelModeDriver10.0';compiler_version='19.44.35228.0';linker_version='14.44.35228.0';infverif_version='10.0.26100.6584';inf2cat_version='1.0.0519.24+3dc05997';signtool_version='10.0.26100.7705'}
    foreach($name in $toolExpected.Keys){Check ($Evidence.toolchain.$name-ceq$toolExpected[$name]) "toolchain-$name"}
    foreach($name in @('visual_studio_path','msbuild_path','compiler_path','linker_path','dumpbin_path','infverif_path','inf2cat_path','signtool_path')){Check ($Evidence.toolchain.$name-is[string]-and-not[string]::IsNullOrWhiteSpace($Evidence.toolchain.$name)) "toolpath-$name"}
    Check ($Evidence.configuration.configuration-ceq'Release'-and$Evidence.configuration.platform-ceq'x64'-and$Evidence.configuration.architecture-ceq'AMD64'-and$Evidence.configuration.sign_mode-ceq'Off'-and$Evidence.configuration.deterministic_link_environment-ceq'_LINK_=/Brepro /PDBALTPATH:ChatpadFilter.pdb') 'configuration'
    $sourcePlan=[IO.File]::ReadAllText($planPath)|ConvertFrom-Json
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
    $handoff=$Evidence.external_signing_handoff
    Check ($handoff.selected_route-ceq'WHCP_HLK_PRODUCTION_SIGNING'-and@($handoff.driver_folder_inputs).Count-eq3-and$handoff.symbol_input.filename-ceq'ChatpadFilter.pdb'-and$handoff.portal_submission_format-ceq'.hlkx'-and-not[bool]$handoff.returned_sys_expected_to_change-and[bool]$handoff.returned_catalog_expected_to_change-and-not[bool]$handoff.test_signed_substitution_permitted-and-not[bool]$handoff.portal_access_performed-and-not[bool]$handoff.submission_performed) 'handoff'
    if(@($handoff.driver_folder_inputs).Count-eq3){Check ($handoff.driver_folder_inputs[0].sha256-ceq$infHash-and$handoff.driver_folder_inputs[1].sha256-ceq$sysHash-and$handoff.driver_folder_inputs[2].sha256-ceq$catHash) 'handoff-files'}
    foreach($name in @('file_signing_count','certificate_creation_count','certificate_installation_count','private_key_access_count','portal_access_count','submission_count','package_staging_count','installation_count','driver_load_count','native_declaration_load_count','native_invocation_count','device_query_count','driver_store_query_count','registry_query_count','service_query_count','setupapi_newdev_invocation_count','binding_count','authorization_issuance_count','authorization_consumption_count','restart_count','reenumeration_count','rollback_count','restoration_count','windows_mutation_count')){Check ([long]$Evidence.operation_counters.$name-eq0) "counter-$name"}
    Check ($UnsignedPlan.unsigned_sys.sha256-ceq$sysHash-and[long]$UnsignedPlan.unsigned_sys.byte_size-eq40960-and$UnsignedPlan.unsigned_catalog.sha256-ceq$catHash-and[long]$UnsignedPlan.unsigned_catalog.byte_size-eq1202-and@($UnsignedPlan.package_file_inventory).Count-eq3-and$UnsignedPlan.configuration.configuration-ceq'Release'-and$UnsignedPlan.configuration.platform-ceq'x64'-and$UnsignedPlan.architecture-ceq'AMD64'-and$UnsignedPlan.driver_framework-ceq'KMDF 1.15') 'plan-package'
    Check ($UnsignedPlan.production_signing.route-ceq'WHCP_HLK_PRODUCTION_SIGNING'-and@($UnsignedPlan.production_signing.external_handoff_inventory).Count-eq4-and-not[bool]$UnsignedPlan.production_signing.portal_submission_created-and[bool]$UnsignedPlan.production_signing.external_hlk_testing_required-and[bool]$UnsignedPlan.production_signing.ev_submission_signature_required-and-not[bool]$UnsignedPlan.production_signing.test_signed_substitution_permitted-and$UnsignedPlan.current_installability-ceq'NOT_INSTALLABLE_UNSIGNED_PACKAGE') 'plan-signing'
    Check ($Evidence.blocker-ceq$blocker-and$UnsignedPlan.blocker-ceq$blocker-and$Evidence.next_task-ceq$next-and$UnsignedPlan.next_task-ceq$next) 'blocker-next'
    Check ($Evidence.driver_project.path-ceq$UnsignedPlan.driver_project.path-and$Evidence.driver_project.sha256-ceq$UnsignedPlan.driver_project.sha256-and$Evidence.canonical_inf.sha256-ceq$UnsignedPlan.canonical_inf.sha256-and$Evidence.binary_validation.sha256-ceq$UnsignedPlan.unsigned_sys.sha256-and$Evidence.catalog_generation.sha256-ceq$UnsignedPlan.unsigned_catalog.sha256-and$Evidence.external_signing_handoff.selected_route-ceq$UnsignedPlan.production_signing.route) 'evidence-plan-equality'
    return [pscustomobject]@{result=if($defects.Count){'FAIL'}else{'PASS'};defect_count=$defects.Count;defects=@($defects)}
}

if($UnsignedPackage){
    try{
        $baselineEvidence=[IO.File]::ReadAllText($unsignedEvidencePath)|ConvertFrom-Json
        $baselineUnsignedPlan=[IO.File]::ReadAllText($unsignedPlanPath)|ConvertFrom-Json
        Pass-Test 'canonical unsigned evidence and plan pass'{$r=Test-UnsignedPackageObjects $baselineEvidence $baselineUnsignedPlan;Assert-Test ($r.result-eq'PASS'-and$r.defect_count-eq0) ($r.defects-join'; ')}
        $cases=@(
            @{n='wrong source commit';m={param($e,$p)$e.source_commit='0'*40}},@{n='wrong project';m={param($e,$p)$e.driver_project.path='wrong.vcxproj'}},@{n='Debug build';m={param($e,$p)$e.configuration.configuration='Debug'}},@{n='Win32 build';m={param($e,$p)$e.configuration.platform='Win32'}},@{n='different SYS hashes';m={param($e,$p)$e.builds[1].sys_sha256='A'*64}},@{n='wrong PE machine';m={param($e,$p)$e.binary_validation.pe_machine='0x014C'}},@{n='added package file';m={param($e,$p)$e.package.inventory+=[pscustomobject]@{filename='extra';byte_size=1;sha256='A'*64;role='extra'}}},@{n='wrong INF hash';m={param($e,$p)$e.canonical_inf.sha256='B'*64}},@{n='missing catalog member';m={param($e,$p)$e.catalog_generation.members=@($e.catalog_generation.members[0])}},@{n='added catalog member';m={param($e,$p)$e.catalog_generation.members+=[pscustomobject]@{filename='extra';catalog_sha1='A'*40;catalog_sha256='A'*64}}},@{n='test certificate';m={param($e,$p)$e.signature_validation.test_certificate_present=$true}},@{n='production-signed overclaim';m={param($e,$p)$e.status='PRODUCTION_SIGNED'}},@{n='placeholder signer';m={param($e,$p)$e.signature_validation|Add-Member signer_subject 'PLACEHOLDER'}},@{n='wrong signing route';m={param($e,$p)$e.external_signing_handoff.selected_route='ATTESTATION'}},@{n='missing handoff file';m={param($e,$p)$e.external_signing_handoff.driver_folder_inputs=@($e.external_signing_handoff.driver_folder_inputs[0..1])}},@{n='installable overclaim';m={param($e,$p)$p.current_installability='INSTALLABLE'}},@{n='wrong blocker';m={param($e,$p)$e.blocker='WRONG'}},@{n='wrong next task';m={param($e,$p)$e.next_task='WRONG'}},@{n='evidence plan mismatch';m={param($e,$p)$p.unsigned_sys.sha256='C'*64}}
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
    Pass-Test 'current status remains non-installable' { $p=Clone-Plan; Assert-Test ($p.status -match 'NOT_BUILT_NOT_CATALOGED_NOT_SIGNED_NOT_STAGED_NOT_INSTALLABLE') 'Non-installable status missing.' }
    Pass-Test 'future output inventory is complete' { $p=Clone-Plan; Assert-Test (@($p.future_p1b2_fields).Count -eq 23) 'Future output inventory count changed.' }

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
    Invoke-RejectedFixture 'test signing classified as production' { param($p) $p.signing_policy.test_signing_permitted_for_live_attempt=$true } $null
    Invoke-RejectedFixture 'placeholder catalog hash' { param($p) $p | Add-Member -NotePropertyName catalog_sha256 -NotePropertyValue ('0'*64) } $null
    Invoke-RejectedFixture 'placeholder signer' { param($p) $p | Add-Member -NotePropertyName package_signer_subject -NotePropertyValue 'PLACEHOLDER' } $null
    Invoke-RejectedFixture 'first enumerated candidate' { param($p) $p.caller_controls.first_or_best_driver_fallback_permitted=$true } $null
    Invoke-RejectedFixture 'best-ranked-only candidate' { param($p) $p.candidate_rule.prohibited_strategies=@($p.candidate_rule.prohibited_strategies | Where-Object { $_ -ne 'highest-ranked candidate without identity matching' }) } $null
    Invoke-RejectedFixture 'zero-match acceptance' { param($p) $p.candidate_rule.zero_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'multiple-match acceptance' { param($p) $p.candidate_rule.multiple_exact_matches='ELIGIBLE' } $null
    Invoke-RejectedFixture 'missing future output field' { param($p) $p.future_p1b2_fields=@($p.future_p1b2_fields | Where-Object { $_ -ne 'reproducibility_result' }) } $null
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
