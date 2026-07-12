[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$modulePath=Join-Path $root 'tools\ExactInstance\ChatpadLocalDevelopmentHostReadiness.psm1'
$invokePath=Join-Path $root 'tools\Invoke-ChatpadLocalDevelopmentHostReadinessObservation.ps1'
$script:tests=0;$script:assertions=0
function Assert([bool]$Condition,[string]$Message){$script:assertions++;if(-not$Condition){throw $Message}}
function Test([string]$Name,[scriptblock]$Body){&$Body;$script:tests++;"PASS: $Name"}
function Parse([string]$Path){$e=$null;$t=$null;[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)|Out-Null;@($e)}
function Defects([string]$Module,[string]$Invoke){
    $d=[Collections.Generic.List[string]]::new()
    foreach($x in @('pnputil','devcon','driverquery','Get-WindowsDriver','SetupAPI','Newdev','sc.exe','fltmc','Get-PnpDevice','Get-PnpDeviceProperty','Win32_PnPEntity','Win32_SystemDriver','CurrentControlSet\Enum')){if($Module-match[regex]::Escape($x)-or$Invoke-match[regex]::Escape($x)){$d.Add("prohibited:$x")}}
    foreach($x in @('Set-ItemProperty','New-SelfSignedCertificate','Import-Certificate','Remove-Item Cert:','Suspend-BitLocker','Resume-BitLocker','Enable-BitLocker','Disable-BitLocker','Restart-Computer','Stop-Computer','shutdown.exe')){if(($Module+' '+$Invoke)-match[regex]::Escape($x)){$d.Add("mutation:$x")}}
    if($Module-match'bcdedit\.exe[^\r\n]*/(?:set|deletevalue|copy|create)'){$d.Add('mutation:bcdedit-write-verb')}
    foreach($x in @('RecoveryPassword','NumericalPassword','KeyProtectorId','.PrivateKey','GetRSAPrivateKey','Export-PfxCertificate','Export-Certificate')){if(($Module+' '+$Invoke)-match[regex]::Escape($x)){$d.Add("sensitive:$x")}}
    foreach($x in @("Confirm-SecureBootUEFI","bcdedit.exe","Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName 'Win32_DeviceGuard'","Get-BitLockerVolume -MountPoint `$env:SystemDrive","name='Root'","name='TrustedPublisher'","name='My'","X509Store]::new","StoreLocation]::LocalMachine","OpenFlags]::OpenExistingOnly","OpenFlags]::ReadOnly","HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard","HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity")){if($Module-notmatch[regex]::Escape($x)){$d.Add("missing-fixed:$x")}}
    if($Module-match'OpenFlags\]::ReadWrite'){$d.Add('certificate-store-write-open')}
    if($Module-notmatch'Export-ModuleMember -Function Get-ChatpadLocalDevelopmentHostReadiness'){$d.Add('export')}
    foreach($x in @('LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION','LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT','LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION','LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING','LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE','TASK 8I-P1B-LD-S1 ','Create and freeze the self-test-signed local-development package','TASK 8I-P1B-LD-H1 ','Design the controlled host-security transition and recovery plan','TASK 8I-P1B-LD-O1R1 ','Remediate host-readiness observation gaps','[char]0x2014')){if($Module-notmatch[regex]::Escape($x)){$d.Add("decision:$x")}}
    foreach($x in @("if(`$observationInsufficient){`$outcome='LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'","elseif(`$protectionDecision){`$outcome='LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION'","elseif(`$ts-eq'ENABLED'-and`$KnownExternalBcdTestSigningChange-and`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'-and`$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED'){`$outcome='LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'","elseif(`$ts-eq'ENABLED'-and`$effectiveTestMode-ceq'CONCLUSIVELY_ENABLED'){`$outcome='LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION'","elseif(`$ts-in@('DISABLED','ABSENT')){`$outcome='LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT'")){if($Module-notmatch[regex]::Escape($x)){$d.Add("decision-guard:$x")}}
    foreach($x in @("`$observationInsufficient=-not`$complete-or`$conflict-or`$ts-eq'INCONCLUSIVE'","`$protectionDecision=`$secure.state-eq'ENABLED'-or(`$bitlocker.state-eq'AVAILABLE'-and`$bitlocker.protection_status-match'On')")){if($Module-notmatch[regex]::Escape($x)){$d.Add("decision-input:$x")}}
    $dIndex=$Module.IndexOf("if(`$observationInsufficient)");$cIndex=$Module.IndexOf("elseif(`$protectionDecision)");$pIndex=$Module.IndexOf("LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING';`$next");$aIndex=$Module.IndexOf("LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION';`$next");$bIndex=$Module.IndexOf("LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT';`$next");if($dIndex-lt0-or-not($dIndex-lt$cIndex-and$cIndex-lt$pIndex-and$pIndex-lt$aIndex-and$aIndex-lt$bIndex)){$d.Add('decision-precedence')}
    foreach($x in @('if\(\$bc.exit_code-ne0\)\{''INCONCLUSIVE''\}','hvci.state-eq''AVAILABLE''','bitlocker.state-eq''AVAILABLE''','certState-eq''AVAILABLE''','UNAVAILABLE_OR_ACCESS_DENIED','UNAVAILABLE_OR_ABSENT','ELEVATION_GATE_REJECTED_BEFORE_HOST_QUERIES')){if($Module-notmatch$x){$d.Add("fail-closed:$x")}}
    if($Module-match'ChatpadCertificate'){$d.Add('unrelated-certificate-classification')}
    if($Invoke-notmatch"PSVersionTable.PSVersion.Major-lt7"-or$Invoke-notmatch'Is64BitProcess'-or$Invoke-notmatch'S-1-5-32-544'-or$Invoke-notmatch'S-1-16-' -or$Invoke-notmatch'Unexpected HEAD'){$d.Add('invocation-gates')}
    foreach($x in @("knownExternalBcdTestSigningChange=`$true","reportedCommandResult='SUCCESS'","rebootSinceTestSigningChange='OPERATOR_REPORTED_FALSE'","-KnownExternalBcdTestSigningChange `$knownExternalBcdTestSigningChange","-ReportedCommandResult `$reportedCommandResult","-RebootSinceTestSigningChange `$rebootSinceTestSigningChange")){if($Invoke-notmatch[regex]::Escape($x)){$d.Add("fixed-context:$x")}}
    if($Invoke-notmatch'WriteAllText\(\$temp'-or$Invoke-notmatch'Move-Item -LiteralPath \$temp -Destination \$full -Force'-or$Invoke-notmatch'UTF8Encoding\]::new\(\$false\)'){$d.Add('atomic-bomless-write')}
    foreach($x in @('schema','windows','elevation','pre_observation_context','known_external_bcd_testsigning_change','pre_observation_external_mutation_count','pre_observation_external_mutation','reboot_since_testsigning_change','testsigning_configured_for_next_boot_initial_state','testsigning_configured_for_next_boot','effective_test_mode_current_boot','secure_boot','bcd','testsigning_state','device_guard','hvci','bitlocker','certificates','signature_enforcement_conclusion','selected_outcome','next_task','observer_mutation_count','overall_lane_mutation_count','query_counters','mutation_counters')){if($Module-notmatch[regex]::Escape($x)-or$Invoke-notmatch[regex]::Escape($x)){$d.Add("schema:$x")}}
    foreach($x in @("command='bcdedit /set testsigning on'","reported_result='SUCCESS'","source='OPERATOR_CONSOLE_TRANSCRIPT'","performed_by_observer=`$false","pre_observation_external_mutation=`$externalMutation","observer_mutation_count=0","overall_lane_mutation_count=1","pre_observation_external_mutation_count=1","reboot_since_testsigning_change='OPERATOR_REPORTED_FALSE'","testsigning_configured_for_next_boot_initial_state='TO_BE_CONFIRMED_BY_READ_ONLY_BCD_OBSERVATION'","effective_test_mode_current_boot=`$effectiveTestMode","NOT_YET_LOADABLE")){if($Module-notmatch[regex]::Escape($x)){$d.Add("external-mutation:$x")}}
    foreach($x in @("firstAttemptSha256='255C874A774CF6492B4A70A99214988824351E738B9AC8D10443F59B441E31C3'","firstAttemptObservationUtc='2026-07-12T00:25:29.5568249Z'","supersedes_observation_sha256","superseded_outcome","supersession_reason","TARGETED_HOST_READINESS_OBSERVATION_REMEDIATION","Refusing to overwrite evidence that is not the exact known first inconclusive observation")){if($Invoke-notmatch[regex]::Escape($x)){$d.Add("supersession:$x")}}
    foreach($x in @('store_results','normalization_error_count','normalization_errors','record_limit','PARTIAL_NORMALIZATION_FAILURE','INCOMPLETE_LIMIT_REACHED','certificate_store_root','certificate_store_trusted_publisher','certificate_store_my')){if($Module-notmatch[regex]::Escape($x)){$d.Add("certificate-diagnostics:$x")}}
    foreach($x in @('registry_write=0','bcd_mutation=0','secure_boot_mutation=0','bitlocker_mutation=0','certificate_mutation=0','package_stage_or_install=0','device_or_driver_query=0','driver_load=0','reboot_or_shutdown=0','windows_mutation=0')){if($Module-notmatch[regex]::Escape($x)){$d.Add("zero-mutations:$x")}}
    @($d)
}

$module=[IO.File]::ReadAllText($modulePath);$invoke=[IO.File]::ReadAllText($invokePath)
Test 'PowerShell sources parse' {Assert (@(Parse $modulePath).Count-eq0) 'Module parse failure';Assert (@(Parse $invokePath).Count-eq0) 'Invocation parse failure'}
Test 'exact single module export' {$ast=[Management.Automation.Language.Parser]::ParseInput($module,[ref]$null,[ref]$null);$exports=@($ast.FindAll({param($n)$n -is[Management.Automation.Language.CommandAst]-and$n.GetCommandName()-eq'Export-ModuleMember'},$true));Assert ($exports.Count-eq1) 'Export count';Assert ($exports[0].Extent.Text-match'Get-ChatpadLocalDevelopmentHostReadiness') 'Export name'}
Test 'production source contract passes' {Assert (@(Defects $module $invoke).Count-eq0) ((Defects $module $invoke)-join'; ')}
Test 'observer accepts only bounded continuation context' {Assert ($module-match"\[ValidateSet\('SUCCESS'\)\]\[string\]\`$ReportedCommandResult") 'Result parameter is not bounded';Assert ($module-match"\[ValidateSet\('OPERATOR_REPORTED_FALSE'\)\]\[string\]\`$RebootSinceTestSigningChange") 'Reboot parameter is not bounded';Assert ($module-match'FIXED_PRE_OBSERVATION_CONTEXT_REJECTED') 'Context rejection missing'}
Test 'exact BCD read-only arguments' {Assert ($module-match"@\('/enum','\{current\}'\)") 'current BCD query';Assert ($module-match"@\('/enum','\{bootmgr\}'\)") 'bootmgr BCD query'}
Test 'certificate records are bounded' {Assert ($module-match'certs.Count-ge\$certificateLimit'-and$module-match'certificateLimit=100') 'Certificate bound';Assert ($module-match"code_signing_eku_present") 'EKU metadata'}
Test 'elevation precedes Windows identity query' {Assert ($module.IndexOf('Get-ElevationObservation')-lt$module.IndexOf("Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE")) 'Elevation gate ordering'}
Test 'invocation binds module identity' {Assert ($invoke-match"moduleSha256='[0-9A-F]{64}'") 'Missing module SHA-256';$expected=[regex]::Match($invoke,"moduleSha256='([0-9A-F]{64})'").Groups[1].Value;Assert ((Get-FileHash $modulePath -Algorithm SHA256).Hash-ceq$expected) 'Module SHA-256 mismatch'}
Test 'evidence path is exact' {Assert ($invoke-match[regex]::Escape('docs/evidence/local-development-host-readiness-observation-task-8i-p1b-ld-o1.json')) 'Evidence path'}
Test 'no real observer invocation in validator' {$validator=[IO.File]::ReadAllText($PSCommandPath);Assert ($validator-notmatch'(?m)^\s*Import-Module\s') 'Validator imports observer';Assert ($validator-notmatch'(?m)^\s*Get-ChatpadLocalDevelopmentHostReadiness\s*$') 'Validator calls observer'}
function Select-FixtureDecision([string]$CertificateState,[string]$SecureBootState='DISABLED',[string]$BitLockerProtection='Off',[string]$TestSigningState='ENABLED',[bool]$BcdAvailable=$true,[string]$DeviceGuardState='AVAILABLE',[string]$HvciState='AVAILABLE'){
    $complete=$SecureBootState-in@('ENABLED','DISABLED')-and$BcdAvailable-and$DeviceGuardState-eq'AVAILABLE'-and$HvciState-eq'AVAILABLE'-and$CertificateState-eq'AVAILABLE'
    $insufficient=-not$complete-or$TestSigningState-eq'INCONCLUSIVE'
    $protection=$SecureBootState-eq'ENABLED'-or$BitLockerProtection-match'On'
    if($insufficient){return 'LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'}
    if($protection){return 'LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION'}
    if($TestSigningState-eq'ENABLED'){return 'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'}
    if($TestSigningState-in@('DISABLED','ABSENT')){return 'LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT'}
    return 'LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'
}
Test 'exact first-attempt fixture reproduces Outcome D' {Assert ((Select-FixtureDecision 'UNAVAILABLE_OR_ACCESS_DENIED')-ceq'LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE') 'First attempt did not remain fail-closed'}
Test 'remediated certificate fixture selects reboot pending' {Assert ((Select-FixtureDecision 'AVAILABLE')-ceq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING') 'Conclusive no-reboot fixture did not select reboot pending'}
Test 'unavailable and unsupported fixtures remain fail closed' {Assert ((Select-FixtureDecision 'UNAVAILABLE_OR_ACCESS_DENIED')-like'*NOT_YET_DETERMINABLE') 'Unavailable passed';Assert ((Select-FixtureDecision 'AVAILABLE' 'UNSUPPORTED_NON_UEFI')-like'*NOT_YET_DETERMINABLE') 'Unsupported passed'}
Test 'positive protection fixture selects Outcome C' {Assert ((Select-FixtureDecision 'AVAILABLE' 'ENABLED')-ceq'LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION') 'Secure Boot conflict did not select C';Assert ((Select-FixtureDecision 'AVAILABLE' 'DISABLED' 'On')-ceq'LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION') 'BitLocker conflict did not select C'}
Test 'BCD alone cannot leave Outcome D' {Assert ((Select-FixtureDecision 'UNAVAILABLE_OR_ACCESS_DENIED' 'DISABLED' 'Off' 'ENABLED' $true)-like'*NOT_YET_DETERMINABLE') 'BCD alone selected a favorable outcome'}
Test 'corrected evidence preserves first observation supersession identity' {$first=Join-Path $root 'docs\evidence\local-development-host-readiness-observation-task-8i-p1b-ld-o1.json';Assert ((Get-FileHash $first -Algorithm SHA256).Hash-ceq'019D59504588384DDD48B90B2315A261AE891030113C7953DF6EA2778F3E651C') 'Corrected evidence changed';$o=[IO.File]::ReadAllText($first)|ConvertFrom-Json;Assert ($o.selected_outcome-ceq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'-and$o.supersedes_observation_sha256-ceq'255C874A774CF6492B4A70A99214988824351E738B9AC8D10443F59B441E31C3'-and$o.superseded_outcome-ceq'LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'-and$o.supersession_reason-ceq'TARGETED_HOST_READINESS_OBSERVATION_REMEDIATION') 'Supersession identity changed'}
Test 'unrelated evidence overwrite is rejected by source' {Assert ($invoke-match'oldHash-cne\$firstAttemptSha256-and-not\$knownIdentity') 'Unrelated overwrite rejection missing';Assert ($invoke-match'old\.schema-ceq''chatpad-local-development-host-readiness-observation-v1''') 'Known schema check missing'}
Test 'certificate metadata remains bounded and secret free' {foreach($x in @('subject','issuer','thumbprint','serial_number','not_before','not_after','code_signing_eku_present','basic_constraints','self_signed','has_private_key')){Assert ($module-match[regex]::Escape($x)) "Missing certificate field $x"};foreach($x in @('RecoveryPassword','KeyProtectorId','.PrivateKey','GetRSAPrivateKey')){Assert ($module-notmatch[regex]::Escape($x)) "Secret access $x"}}

$fixtures=[ordered]@{
 'TESTSIGNING inferred from recollection'=@('INCONCLUSIVE','ENABLED_FROM_RECOLLECTION')
 'TESTSIGNING inferred from package presence'=@("if(`$bc.exit_code-ne0){'INCONCLUSIVE'}","if(`$bc.exit_code-ne0){'ENABLED'}")
 'Missing BCD observation'=@("bcdedit.exe","bcdEDIT_REMOVED.exe")
 'Secure Boot unavailable classified disabled'=@("'UNAVAILABLE_OR_ACCESS_DENIED'","'DISABLED'")
 'HVCI unavailable classified off'=@("'UNAVAILABLE_OR_ABSENT'","'DISABLED'")
 'BitLocker recovery password leakage'=@('key_protector_types=$types','RecoveryPassword=$bl.KeyProtector')
 'Private-key material access'=@('has_private_key=$hasPrivateKey','PrivateKey=$c.PrivateKey')
 'Unrelated certificate classified Chatpad'=@('code_signing_eku_present','ChatpadCertificate')
 'Outcome A with TESTSIGNING disabled'=@("`$ts-eq'ENABLED'","`$ts-eq'DISABLED'")
 'Outcome B unresolved Secure Boot'=@("elseif(`$ts-in@('DISABLED','ABSENT'))","elseif(`$true)")
 'Outcome C without protection conflict'=@("`$secure.state-eq'ENABLED'-or(`$bitlocker.state-eq'AVAILABLE'-and`$bitlocker.protection_status-match'On')","`$true")
 'Outcome D mapped to signing'=@("'TASK 8I-P1B-LD-O1R1 '+[char]0x2014+' Remediate host-readiness observation gaps'","'TASK 8I-P1B-LD-S1 '+[char]0x2014+' Create and freeze the self-test-signed local-development package'")
 'bcdedit set'=@('bcdedit.exe" @(''/enum''','bcdedit.exe" @(''/set''')
 'Registry writes'=@('Get-ItemProperty -LiteralPath','Set-ItemProperty -LiteralPath')
 'Certificate creation'=@('X509Store]::new','New-SelfSignedCertificate; X509Store]::new')
 'BitLocker mutation'=@('Get-BitLockerVolume -MountPoint','Suspend-BitLocker; Get-BitLockerVolume -MountPoint')
 'Package installation'=@('Get-ElevationObservation','pnputil; Get-ElevationObservation')
 'Device query'=@('Get-ElevationObservation','Get-PnpDevice; Get-ElevationObservation')
 'Reboot command'=@('Get-ElevationObservation','Restart-Computer; Get-ElevationObservation')
 'Nonzero mutation counter'=@('windows_mutation=0','windows_mutation=1')
 'Missing known external mutation'=@('pre_observation_external_mutation=$externalMutation','pre_observation_external_mutation=$null')
 'Mutation falsely attributed to observer'=@('performed_by_observer=$false','performed_by_observer=$true')
 'Overall mutation count zero'=@('overall_lane_mutation_count=1','overall_lane_mutation_count=0')
 'Outcome A before reboot'=@("`$effectiveTestMode-ceq'CONCLUSIVELY_ENABLED'","`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'")
 'Outcome A based only on BCD'=@("-and`$effectiveTestMode-ceq'CONCLUSIVELY_ENABLED'",'')
 'Reboot pending with TESTSIGNING disabled'=@("elseif(`$ts-eq'ENABLED'-and`$KnownExternalBcdTestSigningChange-and`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'-and`$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED')","elseif(`$ts-eq'DISABLED'-and`$KnownExternalBcdTestSigningChange-and`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'-and`$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED')")
 'Reboot pending after reported reboot'=@("`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'-and`$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED'","`$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_TRUE'-and`$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED'")
 'Reboot pending mapped to installation'=@('NOT_YET_LOADABLE','READY_FOR_DRIVER_INSTALLATION')
 'Reboot pending mapped to native execution'=@('NOT_YET_LOADABLE','READY_FOR_NATIVE_APPLY')
 'Outcome C bypassed by reboot pending'=@('elseif($protectionDecision)','elseif($false-and$protectionDecision)')
 'Outcome D bypassed by reboot pending'=@('if($observationInsufficient)','if($false-and$observationInsufficient)')
}
foreach($name in $fixtures.Keys){$pair=$fixtures[$name];$changed=$module.Replace($pair[0],$pair[1]);Test "reject $name" {Assert ($changed-cne$module) "Fixture did not alter source: $name";Assert (@(Defects $changed $invoke).Count-gt0) "Fixture accepted: $name"}}

"Host-readiness static focused suite: $script:tests / $script:assertions"
