Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-FixedProcess {
    param([string]$FilePath,[string[]]$ArgumentList)
    $out = [IO.Path]::GetTempFileName(); $err = [IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $out -RedirectStandardError $err
        [pscustomobject][ordered]@{ exit_code=[int]$p.ExitCode; stdout=([IO.File]::ReadAllText($out)); stderr=([IO.File]::ReadAllText($err)) }
    } finally { Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue }
}

function Get-ElevationObservation {
    $r=Invoke-FixedProcess -FilePath "$env:SystemRoot\System32\whoami.exe" -ArgumentList @('/groups','/fo','csv','/nh')
    $adminLine=@($r.stdout -split "`r?`n"|Where-Object{$_ -match 'S-1-5-32-544'})|Select-Object -First 1
    $integrityLine=@($r.stdout -split "`r?`n"|Where-Object{$_ -match 'S-1-16-(\d+)'})|Select-Object -First 1
    $rid=$null; if($integrityLine -match 'S-1-16-(\d+)'){$rid=[int]$Matches[1]}
    $member=$null-ne$adminLine
    $elevated=$member-and$adminLine-notmatch 'Deny only'-and$null-ne$rid-and$rid-ge12288
    [pscustomobject][ordered]@{ administrator_group_membership=$member; fully_elevated=$elevated; integrity_level=$(if($null-eq$rid){'UNAVAILABLE'}elseif($rid-ge16384){'SYSTEM'}elseif($rid-ge12288){'HIGH'}elseif($rid-ge8192){'MEDIUM'}else{'LOW'}); integrity_rid=$rid; command_exit_code=$r.exit_code; state=$(if($r.exit_code-ne0){'UNAVAILABLE'}elseif($elevated){'FULLY_ELEVATED'}elseif($member){'ADMINISTRATOR_FILTERED_OR_NOT_HIGH'}else{'NOT_ADMINISTRATOR'}) }
}

function Convert-BcdValue([string]$Text,[string]$Name){
    $m=[regex]::Match($Text,"(?im)^\s*"+[regex]::Escape($Name)+"\s+(\S.*)$")
    [pscustomobject][ordered]@{ presence=$(if($m.Success){'PRESENT'}else{'ABSENT'}); value=$(if($m.Success){$m.Groups[1].Value.Trim()}else{$null}) }
}

function Get-ChatpadLocalDevelopmentHostReadiness {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][bool]$KnownExternalBcdTestSigningChange,
        [Parameter(Mandatory)][ValidateSet('SUCCESS')][string]$ReportedCommandResult,
        [Parameter(Mandatory)][ValidateSet('OPERATOR_REPORTED_FALSE')][string]$RebootSinceTestSigningChange
    )
    if(-not$KnownExternalBcdTestSigningChange-or$ReportedCommandResult-cne'SUCCESS'-or$RebootSinceTestSigningChange-cne'OPERATOR_REPORTED_FALSE'){throw 'FIXED_PRE_OBSERVATION_CONTEXT_REJECTED'}
    $queries=[ordered]@{ elevation=0; windows_identity=0; secure_boot=0; bcd_current=0; bcd_bootmgr=0; device_guard=0; hvci_registry=0; bitlocker=0; certificate_store_root=0; certificate_store_trusted_publisher=0; certificate_store_my=0; total=0 }
    $mutations=[ordered]@{ registry_write=0; bcd_mutation=0; secure_boot_mutation=0; bitlocker_mutation=0; certificate_mutation=0; package_stage_or_install=0; device_or_driver_query=0; driver_load=0; reboot_or_shutdown=0; windows_mutation=0; total=0 }
    $queries.elevation++; $queries.total++; $elevation=Get-ElevationObservation
    $processArch=if([Environment]::Is64BitProcess){'X64'}else{'X86'}
    if(-not$elevation.administrator_group_membership-or-not$elevation.fully_elevated-or$processArch-ne'X64'-or$PSVersionTable.PSVersion.Major-lt7){throw 'ELEVATION_GATE_REJECTED_BEFORE_HOST_QUERIES'}

    $queries.windows_identity++;$queries.total++
    $cv=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $windows=[pscustomobject][ordered]@{ product_name=[string]$cv.ProductName; edition_id=[string]$cv.EditionID; display_version=[string]$cv.DisplayVersion; current_build=[string]$cv.CurrentBuild; ubr=[int]$cv.UBR; full_version=('{0}.{1}'-f$cv.CurrentBuild,$cv.UBR); installation_type=[string]$cv.InstallationType; os_architecture=$(if([Environment]::Is64BitOperatingSystem){'X64'}else{'X86'}); environment_os_version=[Environment]::OSVersion.Version.ToString(); powershell_version=$PSVersionTable.PSVersion.ToString(); process_architecture=$processArch }

    $queries.secure_boot++;$queries.total++
    try{$sb=Confirm-SecureBootUEFI -ErrorAction Stop;$secure=[pscustomobject]@{state=$(if($sb){'ENABLED'}else{'DISABLED'});detail=$null}}
    catch{$msg=$_.Exception.Message;$secure=[pscustomobject]@{state=$(if($msg-match'not supported|not available on this platform|UEFI'){ 'UNSUPPORTED_NON_UEFI' }else{'UNAVAILABLE_OR_ACCESS_DENIED'});detail=($msg.Substring(0,[Math]::Min(240,$msg.Length)))}}

    $queries.bcd_current++;$queries.total++;$bc=Invoke-FixedProcess "$env:SystemRoot\System32\bcdedit.exe" @('/enum','{current}')
    $queries.bcd_bootmgr++;$queries.total++;$bb=Invoke-FixedProcess "$env:SystemRoot\System32\bcdedit.exe" @('/enum','{bootmgr}')
    $fields=[ordered]@{};foreach($n in @('testsigning','nointegritychecks','debug','flightsigning','bootmenupolicy')){$fields[$n]=Convert-BcdValue $bc.stdout $n}
    $bcd=[pscustomobject][ordered]@{ current_exit_code=$bc.exit_code; bootmgr_exit_code=$bb.exit_code; fields=[pscustomobject]$fields; bootmgr_bootmenupolicy=Convert-BcdValue $bb.stdout 'bootmenupolicy'; observation_state=$(if($bc.exit_code-eq0-and$bb.exit_code-eq0){'AVAILABLE'}else{'UNAVAILABLE'}) }
    $ts=if($bc.exit_code-ne0){'INCONCLUSIVE'}elseif($fields.testsigning.presence-eq'ABSENT'){'ABSENT'}elseif($fields.testsigning.value-match'^(?i:yes|on|true)$'){'ENABLED'}elseif($fields.testsigning.value-match'^(?i:no|off|false)$'){'DISABLED'}else{'INCONCLUSIVE'}

    $queries.device_guard++;$queries.total++
    try{$dgRaw=Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName 'Win32_DeviceGuard' -ErrorAction Stop;$dg=[pscustomobject][ordered]@{state='AVAILABLE';virtualization_based_security_status=[int]$dgRaw.VirtualizationBasedSecurityStatus;security_services_configured=@([int[]]$dgRaw.SecurityServicesConfigured);security_services_running=@([int[]]$dgRaw.SecurityServicesRunning);code_integrity_policy_enforcement_status=[int]$dgRaw.CodeIntegrityPolicyEnforcementStatus;usermode_code_integrity_policy_enforcement_status=[int]$dgRaw.UsermodeCodeIntegrityPolicyEnforcementStatus}}
    catch{$dg=[pscustomobject][ordered]@{state='UNAVAILABLE_OR_ACCESS_DENIED';virtualization_based_security_status=$null;security_services_configured=@();security_services_running=@();code_integrity_policy_enforcement_status=$null;usermode_code_integrity_policy_enforcement_status=$null}}

    $queries.hvci_registry++;$queries.total++
    try{$dgr=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -ErrorAction Stop}catch{$dgr=$null}
    try{$hr=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -ErrorAction Stop}catch{$hr=$null}
    $hEnabled=if($null-eq$hr){$null}elseif($null-eq$hr.PSObject.Properties['Enabled']){$null}else{[int]$hr.Enabled}
    $hRunning=if($dg.state-ne'AVAILABLE'){$null}else{2-in@($dg.security_services_running)}
    $hvci=[pscustomobject][ordered]@{state=$(if($null-eq$hr-and$dg.state-ne'AVAILABLE'){'UNAVAILABLE'}else{'AVAILABLE'});device_guard_enable_virtualization_based_security=$(if($null-ne$dgr-and$null-ne$dgr.PSObject.Properties['EnableVirtualizationBasedSecurity']){[int]$dgr.EnableVirtualizationBasedSecurity}else{$null});configured_enabled_value=$hEnabled;configured_state=$(if($null-eq$hEnabled){'UNAVAILABLE_OR_ABSENT'}elseif($hEnabled-eq1){'ENABLED'}elseif($hEnabled-eq0){'DISABLED'}else{'INCONCLUSIVE'});running=$hRunning;appears_active=$(if($null-eq$hRunning){'INCONCLUSIVE'}elseif($hRunning){'YES'}else{'NO'});future_sys_embedded_test_signature_required=$true}

    $queries.bitlocker++;$queries.total++
    try{$bl=Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop;$types=@($bl.KeyProtector|ForEach-Object{[string]$_.KeyProtectorType}|Sort-Object -Unique);$bitlocker=[pscustomobject][ordered]@{state='AVAILABLE';mount_point=[string]$bl.MountPoint;protection_status=[string]$bl.ProtectionStatus;lock_status=[string]$bl.LockStatus;encryption_percentage=[double]$bl.EncryptionPercentage;encryption_method=[string]$bl.EncryptionMethod;key_protector_types=$types;recovery_protector_present=@($types|Where-Object{$_-match'Recovery'}).Count-gt0}}
    catch{$bitlocker=[pscustomobject][ordered]@{state='UNAVAILABLE_OR_ACCESS_DENIED';mount_point=$env:SystemDrive;protection_status=$null;lock_status=$null;encryption_percentage=$null;encryption_method=$null;key_protector_types=@();recovery_protector_present=$null}}

    $certs=[Collections.Generic.List[object]]::new();$storeResults=[Collections.Generic.List[object]]::new();$normalizationErrors=[Collections.Generic.List[object]]::new();$certState='AVAILABLE';$certificateLimit=100
    foreach($storeSpec in @(
        [pscustomobject]@{name='Root';counter='certificate_store_root'},
        [pscustomobject]@{name='TrustedPublisher';counter='certificate_store_trusted_publisher'},
        [pscustomobject]@{name='My';counter='certificate_store_my'}
    )){
        $queries[$storeSpec.counter]++;$queries.total++;$storeObject=$null;$enumerated=0;$relevant=0;$storeState='AVAILABLE';$errorType=$null
        try{
            $storeObject=[Security.Cryptography.X509Certificates.X509Store]::new($storeSpec.name,[Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
            $storeObject.Open([Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly-bor[Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            foreach($c in $storeObject.Certificates){
                $enumerated++
                try{
                    $eku=[Collections.Generic.List[string]]::new();$basic=$null
                    foreach($extension in $c.Extensions){
                        if($extension.Oid.Value-ceq'2.5.29.37' -and $extension-is[Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]){foreach($oid in $extension.EnhancedKeyUsages){$eku.Add([string]$oid.Value)}}
                        elseif($extension.Oid.Value-ceq'2.5.29.19' -and $extension-is[Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]){$basic=$extension}
                    }
                    $codeSigning=$eku.Contains('1.3.6.1.5.5.7.3.3');$hasPrivateKey=[bool]$c.HasPrivateKey
                    if(-not$codeSigning-and-not$hasPrivateKey){continue};$relevant++
                    if($certs.Count-ge$certificateLimit){$certState='INCOMPLETE_LIMIT_REACHED';break}
                    $certs.Add([pscustomobject][ordered]@{store=$storeSpec.name;subject=[string]$c.Subject;issuer=[string]$c.Issuer;thumbprint=[string]$c.Thumbprint;serial_number=[string]$c.SerialNumber;not_before=$c.NotBefore.ToUniversalTime().ToString('o');not_after=$c.NotAfter.ToUniversalTime().ToString('o');code_signing_eku_present=$codeSigning;basic_constraints=$(if($null-eq$basic){'ABSENT'}else{[pscustomobject][ordered]@{certificate_authority=[bool]$basic.CertificateAuthority;has_path_length_constraint=[bool]$basic.HasPathLengthConstraint;path_length_constraint=$(if($basic.HasPathLengthConstraint){[int]$basic.PathLengthConstraint}else{$null});critical=[bool]$basic.Critical}});self_signed=$c.Subject-ceq$c.Issuer;has_private_key=$hasPrivateKey})
                }catch{$certState='PARTIAL_NORMALIZATION_FAILURE';$normalizationErrors.Add([pscustomobject][ordered]@{store=$storeSpec.name;error_type=$_.Exception.GetType().FullName})}
            }
        }catch{$storeState=$(if($_.Exception-is[UnauthorizedAccessException]){'ACCESS_DENIED'}elseif($_.Exception-is[Security.Cryptography.CryptographicException]){'UNAVAILABLE'}else{'ERROR'});$errorType=$_.Exception.GetType().FullName;$certState='UNAVAILABLE_OR_ACCESS_DENIED'}
        finally{if($null-ne$storeObject){$storeObject.Close();$storeObject.Dispose()}}
        $storeResults.Add([pscustomobject][ordered]@{store=$storeSpec.name;state=$storeState;enumerated_count=$enumerated;relevant_count=$relevant;error_type=$errorType})
    }

    $conflict=$fields.nointegritychecks.value-match'^(?i:yes|on|true)$'-or$fields.flightsigning.value-match'^(?i:yes|on|true)$'
    $complete=$secure.state-in@('ENABLED','DISABLED')-and$bcd.observation_state-eq'AVAILABLE'-and$dg.state-eq'AVAILABLE'-and$hvci.state-eq'AVAILABLE'-and$bitlocker.state-eq'AVAILABLE'-and$certState-eq'AVAILABLE'
    $effectiveTestMode='NOT_CONCLUSIVELY_OBSERVED'
    $observationInsufficient=-not$complete-or$conflict-or$ts-eq'INCONCLUSIVE'
    $protectionDecision=$secure.state-eq'ENABLED'-or($bitlocker.state-eq'AVAILABLE'-and$bitlocker.protection_status-match'On')
    if($observationInsufficient){$outcome='LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE';$next='TASK 8I-P1B-LD-O1R1 '+[char]0x2014+' Remediate host-readiness observation gaps'}
    elseif($protectionDecision){$outcome='LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION';$next='TASK 8I-P1B-LD-H1 '+[char]0x2014+' Design the controlled host-security transition and recovery plan'}
    elseif($ts-eq'ENABLED'-and$KnownExternalBcdTestSigningChange-and$RebootSinceTestSigningChange-ceq'OPERATOR_REPORTED_FALSE'-and$effectiveTestMode-ceq'NOT_CONCLUSIVELY_OBSERVED'){$outcome='LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING';$next='TASK 8I-P1B-LD-S1 '+[char]0x2014+' Create and freeze the self-test-signed local-development package'}
    elseif($ts-eq'ENABLED'-and$effectiveTestMode-ceq'CONCLUSIVELY_ENABLED'){$outcome='LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION';$next='TASK 8I-P1B-LD-S1 '+[char]0x2014+' Create and freeze the self-test-signed local-development package'}
    elseif($ts-in@('DISABLED','ABSENT')){$outcome='LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT';$next='TASK 8I-P1B-LD-S1 '+[char]0x2014+' Create and freeze the self-test-signed local-development package'}
    else{$outcome='LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE';$next='TASK 8I-P1B-LD-O1R1 '+[char]0x2014+' Remediate host-readiness observation gaps'}
    $externalMutation=[pscustomobject][ordered]@{command='bcdedit /set testsigning on';reported_result='SUCCESS';source='OPERATOR_CONSOLE_TRANSCRIPT';performed_by_observer=$false}
    [pscustomobject][ordered]@{schema='chatpad-local-development-host-readiness-observation-v1';observation_utc=[DateTime]::UtcNow.ToString('o');windows=$windows;elevation=$elevation;pre_observation_context=[pscustomobject][ordered]@{known_external_bcd_testsigning_change=$true;pre_observation_external_mutation_count=1;pre_observation_external_mutation=$externalMutation;reboot_since_testsigning_change='OPERATOR_REPORTED_FALSE';testsigning_configured_for_next_boot_initial_state='TO_BE_CONFIRMED_BY_READ_ONLY_BCD_OBSERVATION';testsigning_configured_for_next_boot=$(if($ts-eq'ENABLED'){'CONFIRMED_ENABLED_BY_READ_ONLY_BCD_OBSERVATION'}elseif($ts-in@('DISABLED','ABSENT')){'CONFIRMED_NOT_ENABLED_BY_READ_ONLY_BCD_OBSERVATION'}else{'INCONCLUSIVE_AFTER_READ_ONLY_BCD_OBSERVATION'});effective_test_mode_current_boot=$effectiveTestMode};secure_boot=$secure;bcd=$bcd;testsigning_state=$ts;device_guard=$dg;hvci=$hvci;bitlocker=$bitlocker;certificates=[pscustomobject]@{state=$certState;store_results=@($storeResults);normalization_error_count=$normalizationErrors.Count;normalization_errors=@($normalizationErrors);record_limit=$certificateLimit;records=@($certs)};signature_enforcement_conclusion=$(if($outcome-eq'LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING'){'TEST_SIGNING_CONFIGURED_FOR_NEXT_BOOT_EFFECTIVE_CURRENT_BOOT_STATE_INCONCLUSIVE_NOT_YET_LOADABLE'}elseif($outcome-like'*NOT_YET_DETERMINABLE'){'INCONCLUSIVE'}elseif($outcome-like'*ALREADY_ENABLED*'){'EFFECTIVE_TEST_MODE_CONCLUSIVELY_ENABLED_SELF_TEST_SIGNED_KERNEL_BINARY_REQUIRED'}else{'ORDINARY_KERNEL_SIGNATURE_ENFORCEMENT_APPLIES_UNTIL_CONTROLLED_TRANSITION'});selected_outcome=$outcome;next_task=$next;observer_mutation_count=0;overall_lane_mutation_count=1;query_counters=[pscustomobject]$queries;mutation_counters=[pscustomobject]$mutations}
}

Export-ModuleMember -Function Get-ChatpadLocalDevelopmentHostReadiness
