Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding.psm1')
function Get-Field($Object,[string]$Name,$Default=$null){if($null -ne $Object -and $Object.PSObject.Properties[$Name]){return $Object.$Name};return $Default}
function Get-ChatpadExtensionAllowlist {$items=Get-Content (Join-Path $PSScriptRoot 'ExtensionAllowlist.json') -Raw | ConvertFrom-Json;foreach($item in $items){Write-Output $item}}
function Read-ChatpadExtensionInf {
 param([string]$Path,[string]$PublishedInf='')
 $text=Get-Content -LiteralPath $Path -Raw
 $values=@{};foreach($line in ($text -split '\r?\n')){if($line -match '^\s*([\w.]+)\s*=\s*([^;]+)'){$values[$matches[1]]=$matches[2].Trim().Trim('"')}}
 $provider=[string]$values['Provider'];if($provider -match '^%(.+)%$'){$provider=[string]$values[$matches[1]]}
 $version=([string]$values['DriverVer'] -split ',')[-1].Trim()
 $class=[string]$values['Class'];$ext=[string]$values['ExtensionId'];$hash=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
 $hw=@([regex]::Matches($text,'(?i)USB\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}(?:&[A-Z0-9_]+)?') | ForEach-Object {$_.Value.ToUpperInvariant()} | Select-Object -Unique)
 $matching=$class -ieq 'Extension' -and (($hw -join '|') -match 'USB\\VID_045E&PID_028E' -or $ext -ieq '{69E7CCD7-7011-4059-95D4-618974E126DD}' -or $text -match '(?i)ChatpadFilter')
 $known=@(Get-ChatpadExtensionAllowlist | Where-Object {$_.Version -eq $version -and $_.InfSHA256 -eq $hash}).Count -eq 1 -and $provider -ceq 'Chatpad Super Driver Project' -and $ext -ieq '{69E7CCD7-7011-4059-95D4-618974E126DD}' -and $hw.Count -eq 1 -and $hw[0] -eq 'USB\VID_045E&PID_028E' -and $class -ieq 'Extension' -and $values['CatalogFile'] -ieq 'ChatpadFilterExtension.cat'
 [pscustomobject]@{PublishedInf=$PublishedInf;Path=[IO.Path]::GetFullPath($Path);OriginalName=if($known){'ChatpadFilterExtension.inf'}else{Split-Path $Path -Leaf};Provider=$provider;Class=$class;ExtensionId=$ext;Version=$version;HardwareIds=$hw;Catalog=[string]$values['CatalogFile'];SHA256=$hash;Matching=$matching;Known=$known;Selected=$null;SelectionEvidence='not queried'}
}
function Get-ChatpadExtensionInventory {
 param([string[]]$CandidateLines=@())
 # Parse every OEM Extension INF, including unknown providers/names. OEM numbers
 # are addresses in the current store, never stable package identities.
 $result=@();foreach($file in Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'INF') -Filter 'oem*.inf' -File){
  $text=Get-Content -LiteralPath $file.FullName -Raw
  if($text -notmatch '(?im)^\s*Class\s*=\s*Extension\s*(?:;[^\r\n]*)?$'){continue}
  $p=Read-ChatpadExtensionInf $file.FullName $file.Name
  if($p.Matching){$selection=Get-ChatpadExtensionSelection @($CandidateLines | Where-Object {$null -ne $_}) $p.PublishedInf;$p | Add-Member NoteProperty CandidateForTarget $selection.CandidateForTarget;$p.Selected=$selection.Selected;$p.SelectionEvidence=if(@($CandidateLines | Where-Object {$null -ne $_}).Count){$selection.Evidence}else{'no present target; installed store history only'};$result+=$p}
 };return $result
}
function Get-ChatpadExtensionSelection {
 param([string[]]$Lines,[string]$PublishedInf)
 $text=$Lines -join "`n";$candidate=$text -match ('(?i)\b'+[regex]::Escape($PublishedInf)+'\b');$selected=$null
 # English PnPUtil Installed status is positive association evidence, whereas
 # mere candidate-list membership is not. Unknown/localized formats stay null.
 $blocks=[regex]::Matches($text,'(?ims)^\s*Driver Name:\s*(oem\d+\.inf)\s*$(.*?)(?=^\s*Driver Name:|\z)')
 foreach($b in $blocks){if($b.Groups[1].Value -ieq $PublishedInf -and $b.Groups[2].Value -match '(?im)^\s*Driver Status:\s*([^\r\n]+)'){$selected=$matches[1] -match '(?i)\bInstalled\b'}}
 [pscustomobject]@{CandidateForTarget=$candidate;Selected=$selected;Evidence=if($null -eq $selected){'installed association not proven'}else{'PnPUtil exact package driver-status Installed association'}}
}
function Assert-ChatpadExtensionInventory {
 param([object[]]$Packages)
 foreach($p in $Packages){if($p.Matching -and (-not $p.Known -or $p.PublishedInf -notmatch '^oem\d+\.inf$')){throw "Unknown matching extension identity: $($p.PublishedInf); no exclusion allowed."}}
 $names=@($Packages | Where-Object Matching | ForEach-Object PublishedInf)
 if(@($names | Select-Object -Unique).Count -ne $names.Count){throw 'Duplicate published package identity.'}
}
function Resolve-ChatpadC3Target {
 param([object[]]$Devices,$CapturedTarget)
 $physical=@($Devices | Where-Object {$null -ne $_ -and $_.InstanceId -match '^USB\\VID_045E&PID_028E\\[^\\]+$' -and @($_.HardwareIds) -contains 'USB\VID_045E&PID_028E'})
 if($physical.Count -ne 1){throw "Exactly one present physical target required; count=$($physical.Count)."}
 if($CapturedTarget){$container=[string](Get-Field $CapturedTarget 'ContainerId');if([string]::IsNullOrWhiteSpace($container) -or $physical[0].ContainerId -ine $container){throw 'Reconnect stable container identity mismatch; never select first connected target.'}}
 $physical[0]
}
function Test-ChatpadFileRecords {
 param([object[]]$Records,[string]$Purpose)
 if(-not $Records.Count){throw "$Purpose files missing."}
 foreach($file in $Records){if($file.SHA256 -notmatch '^[a-fA-F0-9]{64}$' -or -not (Test-Path -LiteralPath $file.Path -PathType Leaf) -or (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ine $file.SHA256){throw "$Purpose file missing/hash mismatch: $($file.Path)"}}
}
function Assert-ChatpadRestorable {
 param($Readiness,[switch]$RestoreExtension)
 $m=$Readiness.Microsoft
 if($m.Provider -cne 'Microsoft' -or $m.Section -cne 'CC_Install' -or $m.Version -notmatch '^10\.0\.\d+\.\d+$' -or (Split-Path $m.InfPath -Leaf) -ine 'xusb22.inf'){throw 'Exact Microsoft Xbox INF/section/provider/version identity required.'}
 Test-ChatpadFileRecords @([pscustomobject]@{Path=$m.InfPath;SHA256=$m.InfSHA256}) 'Microsoft INF'
 Test-ChatpadFileRecords @($m.PackageFiles) 'Microsoft recovery package'
 $text=Get-Content -LiteralPath $m.InfPath -Raw
 $providerToken=([regex]::Match($text,'(?im)^\s*Provider\s*=\s*%([^%]+)%')).Groups[1].Value
 $providerValue=([regex]::Match($text,'(?im)^\s*'+[regex]::Escape($providerToken)+'\s*=\s*"?([^"\r\n;]+)')).Groups[1].Value.Trim()
 $versionValue=([regex]::Match($text,'(?im)^\s*DriverVer\s*=\s*[^,]+,\s*([^\r\n;]+)')).Groups[1].Value.Trim()
 if($providerValue -cne 'Microsoft' -or $versionValue -ne $m.Version -or $text -notmatch '(?i)USB\\VID_045E&PID_028E' -or $text -notmatch '(?i)AddService\s*=\s*xusb22'){throw 'Microsoft INF contract does not match recovery route.'}
 if(-not (Get-Field $m 'SourceSignatureVerified' $false)){throw 'Microsoft package signature evidence missing.'}
 if($RestoreExtension){
  $e=$Readiness.ExtensionRestore;Test-ChatpadFileRecords @($e.Files) 'Optional extension recovery'
  $p=Read-ChatpadExtensionInf $e.InfPath
  if(-not $p.Known -or $p.Version -ne $e.Version){throw 'Optional extension restore identity unknown.'}
  $identity=@(Get-ChatpadExtensionAllowlist | Where-Object Version -eq $p.Version)[0]
  foreach($name in @('ChatpadFilterExtension.inf','ChatpadFilterExtension.cat','ChatpadFilter.sys')){$file=@($e.Files | Where-Object {(Split-Path $_.Path -Leaf) -eq $name});$key=switch($name){'ChatpadFilterExtension.inf'{'InfSHA256'};'ChatpadFilterExtension.cat'{'CatSHA256'};default{'SysSHA256'}};if($file.Count -ne 1 -or $file[0].SHA256 -ne $identity.$key){throw 'Optional extension exact package hashes disagree with history.'}}
  if(-not (Get-Field $e 'NormalWindowsLoadExpected' $false)){throw 'Optional custom-kernel extension cannot be restored as healthy in this security mode.'}
 }
}
function New-ChatpadTransitionPlan {
 param($State,[object[]]$Packages,$Readiness)
 Assert-ChatpadExtensionInventory $Packages
 $t=Resolve-ChatpadC3Target @($State.Target) $null
 Assert-ChatpadRestorable $Readiness
 if(@($State.ClassLowerFilters).Count -or @($State.ClassUpperFilters).Count -or @($t.UpperFilters).Count -or @($t.LowerFilters | Where-Object {$_ -notin @('vhf','ChatpadFilter')}).Count){throw 'Unexpected device/class filters; no broad cleanup.'}
 $steps=@([pscustomobject]@{Action='CaptureBaseline';InstanceId=$t.InstanceId;Precondition='unique physical identity and hashed recovery source';Success='private capture committed before mutation'})
 foreach($p in @($Packages | Where-Object Matching | Sort-Object PublishedInf)){$steps+=[pscustomobject]@{Action='ExcludeExtension';PublishedInf=$p.PublishedInf;InfSHA256=$p.SHA256;Version=$p.Version;Command=@('pnputil.exe','/delete-driver',$p.PublishedInf,'/uninstall');Precondition='same INF identity/hash immediately before command; no other present target';Success='published INF absent; no restart flag'}}
 $steps+=@([pscustomobject]@{Action='ClearExactDeviceFilters';InstanceId=$t.InstanceId;Before=@($t.LowerFilters);After=@();Precondition='all known extensions absent; filters exactly vhf/ChatpadFilter subset';Success='instance-only SPDRP_LOWERFILTERS absent; class untouched'},[pscustomobject]@{Action='StageWinUsb';InfPath=(@($Readiness.Files | Where-Object Role -eq 'WinUsbInf')[0]).Path;Precondition='trusted exact catalog/INF and no matching extension';Success='exact experiment package staged'},[pscustomobject]@{Action='BindWinUsb';InstanceId=$t.InstanceId;Precondition='exact staged candidate; same container';Success='WinUSB service, application interface, problem0 and no filters/old stack'})
 [pscustomobject]@{Schema=2;Operation='PlanWinUsbTransition';Execute=$false;Target=$t;Steps=$steps;Rollback='PlanRestoreXbox';NoMicrosoftPackageRemoval=$true;NoWildcardRemoval=$true;PhysicalAcceptance='UNTESTED'}
}
function New-ChatpadRestorePlan {
 param($CapturedTarget,$Readiness,[switch]$RestoreExtension)
 Assert-ChatpadRestorable $Readiness -RestoreExtension:$RestoreExtension
 $steps=@('StopOwnedBridgeAndHelper','ResolveUniqueHardwareAndStableContainer','IdentifyExactExperimentPublishedInfBySourceHash','DeSelectExperimentByExactMicrosoftBinding','RemoveOnlyExactExperimentPackageIfPresent','ClearOnlyKnownDeviceFilters','RebindExactMicrosoftCandidate','VerifyMicrosoftServiceProblem0AndNoChatpadFilter')
 if($RestoreExtension){$steps+=@('StageExactIntendedExtensionOnlyAfterBaseHealthy','InstallExtensionOnExactInstance','VerifyRequestedExtensionHashAndHealthyMicrosoftBase')}
 [pscustomobject]@{Schema=2;Operation='PlanRestoreXbox';Execute=$false;CapturedTarget=$CapturedTarget;Microsoft=$Readiness.Microsoft;Steps=$steps;OptionalExtension=$RestoreExtension.IsPresent;IndependentOfPocAndBackend=$true;ReconnectIdentity='unique hardware AND captured container; changed instance allowed';AutomaticRestart=$false}
}
function Get-ChatpadCanonicalReadback {
 param($Readiness,[string]$CanonicalTaskRoot='\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C2R1')
 $proof=Get-Field $Readiness 'CanonicalWriteProof'
 if(-not (Get-Field $Readiness 'CanonicalWritable' $false) -or -not $proof -or -not (Get-Field $proof 'Verified' $false) -or -not (Get-Field $proof 'SidecarCommittedLast' $false)){throw 'Verified canonical prior-write receipt missing; an arbitrary CanonicalWritable boolean is insufficient.'}
 $canonical=[IO.Path]::GetFullPath([string]$Readiness.CanonicalDirectory).TrimEnd('\','/')
 $root=[IO.Path]::GetFullPath($CanonicalTaskRoot).TrimEnd('\','/')
 if($canonical -ine $root -and -not $canonical.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Canonical directory is outside the required TASK-8L-C2R1 publication root.'}
 if($root.StartsWith('\\',[StringComparison]::Ordinal) -and ([IO.Path]::GetDirectoryName($canonical) -ine $root -or [IO.Path]::GetFileName($canonical) -notmatch '^\d{8}T\d{6}Z$')){throw 'Canonical directory must be one exact UTC timestamp directly under the task publication root.'}
 $path=[IO.Path]::GetFullPath([string]$proof.Path)
 $name=[IO.Path]::GetFileName($path)
 if($name -cne 'publication-probe.json' -or [string]$proof.Name -cne $name -or [IO.Path]::GetDirectoryName($path).TrimEnd('\','/') -ine $canonical){throw 'Canonical receipt path/name does not belong to the exact publication directory.'}
 $hash=[string]$proof.SHA256
 if($hash -notmatch '^[a-fA-F0-9]{64}$' -or [string]$proof.PartReadbackSHA256 -ine $hash -or [string]$proof.FinalReadbackSHA256 -ine $hash){throw 'Canonical receipt independent part/final hashes disagree.'}
 if(-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine $hash){throw 'Current canonical publication probe readback missing/hash mismatch.'}
 $sidecar=$path+'.sha256'
 $expected=$hash+'  '+$name
 if(-not (Test-Path -LiteralPath $sidecar -PathType Leaf) -or (Get-Content -LiteralPath $sidecar -Raw).Trim() -ine $expected){throw 'Current canonical publication probe sidecar missing/hash or name mismatch.'}
 [pscustomobject]@{CapturedUtc=[DateTime]::UtcNow.ToString('o');PriorWriteReceiptVerified=$true;CurrentReadbackVerified=$true;Path=$path;SHA256=$hash;Sidecar=$sidecar;FreshWritePermissionEstablished=$false;Limitation='Read-only preflight verifies a prior successful write and current file/sidecar readback; current create/rename permissions are not established.'}
}
function New-ChatpadC3Preflight {
 param($State,[object[]]$Packages,$Readiness,$CurrentRepository,[string]$CanonicalTaskRoot='\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C2R1')
 $blocks=[Collections.Generic.List[string]]::new();$transition=$null;$restore=$null
 try{Assert-ChatpadExtensionInventory $Packages}catch{$blocks.Add($_.Exception.Message)}
 try{$transition=New-ChatpadTransitionPlan $State $Packages $Readiness}catch{$blocks.Add($_.Exception.Message)}
 try{$restore=New-ChatpadRestorePlan (Get-Field $State 'Target') $Readiness}catch{$blocks.Add($_.Exception.Message)}
 try{
  foreach($role in @('WinUsbInf','WinUsbCat','Poc','VirtualBackend')){if(@($Readiness.Files | Where-Object Role -eq $role).Count -ne 1){throw "Exactly one $role hash record required."}}
  Test-ChatpadFileRecords @($Readiness.Files) 'C3 component'
  $inf=@($Readiness.Files | Where-Object Role -eq 'WinUsbInf')[0]
  if((Get-FileHash $inf.Path).Hash -ne (Get-FileHash (Join-Path $PSScriptRoot 'ChatpadWholeDeviceWinUSB.inf')).Hash){throw 'WinUSB INF differs from reviewed exact in-box-only source.'}
 }catch{$blocks.Add($_.Exception.Message)}
 if(-not (Get-Field $Readiness.Microsoft 'CandidateVerified' $false)){$blocks.Add('Current exact Microsoft compatible driver candidate unavailable/unverified.')}
 if(-not $Readiness.Trust.NormalWindowsInstallExpected){$blocks.Add('Normal Windows package trust: '+$Readiness.Trust.Reason)}
 if(-not $Readiness.Dependencies.Available){$blocks.Add('Runtime dependencies: '+$Readiness.Dependencies.Reason)}
 if(-not $Readiness.Security.QuerySucceeded -or $Readiness.Security.TestSigning -ne $false){$blocks.Add('Effective normal-Windows TESTSIGNING state not verified false.')}
 $canonicalEvidence=$null;try{$canonicalEvidence=Get-ChatpadCanonicalReadback $Readiness -CanonicalTaskRoot $CanonicalTaskRoot}catch{$blocks.Add($_.Exception.Message)}
 if($Readiness.Repository.Branch -cne 'feature/chatpad-winusb-bridge-poc' -or $Readiness.Repository.Commit -notmatch '^[0-9a-f]{40}$'){$blocks.Add('Repository branch/commit identity invalid.')}
 if(-not $CurrentRepository -or (Get-Field $CurrentRepository 'Branch') -cne $Readiness.Repository.Branch -or (Get-Field $CurrentRepository 'Commit') -cne $Readiness.Repository.Commit){$blocks.Add('Readiness repository identity differs from current independently queried branch/HEAD, or the fresh query is unavailable.')}
 [pscustomobject]@{Schema=2;Result=if($blocks.Count){'BLOCKED'}else{'PASS'};C3Ready=($blocks.Count -eq 0);ReadOnly=$true;LiveMutation=$false;Blockers=@($blocks | Select-Object -Unique);Security=$Readiness.Security;Target=(Get-Field $State 'Target');ExtensionInventory=$Packages;TransitionPlan=$transition;RestorePlan=$restore;Repository=$Readiness.Repository;CurrentRepository=$CurrentRepository;CanonicalDirectory=$Readiness.CanonicalDirectory;CanonicalEvidence=$canonicalEvidence;PhysicalAcceptance='UNTESTED'}
}
function Get-ChatpadC3States {
 $names=@('BASELINE_CAPTURE','EXTENSION_EXCLUSION','WINUSB_BIND','WINUSB_VERIFY','PHYSICAL_CONTROLLER_MONITOR','CHATPAD_TRANSPORT_MONITOR','CHATPAD_ACTIVATION','REAL_5_BYTE_REPORT','VIRTUAL_XBOX_CREATE','XINPUT_VERIFY','PHYSICAL_TO_VIRTUAL_MAPPING','RUMBLE_VERIFY','CHATPAD_SENDINPUT_VERIFY','DISCONNECT_RECONNECT','RESTORE_MICROSOFT_XBOX','RESTORE_CHATPAD_EXTENSION_IF_REQUESTED','FINAL_VERIFY')
 for($i=0;$i -lt $names.Count;$i++){[pscustomobject]@{Name=$names[$i];AfterMutation=($i -ge 1);Mutating=($names[$i] -in @('EXTENSION_EXCLUSION','WINUSB_BIND','CHATPAD_ACTIVATION','VIRTUAL_XBOX_CREATE','PHYSICAL_TO_VIRTUAL_MAPPING','RUMBLE_VERIFY','CHATPAD_SENDINPUT_VERIFY','DISCONNECT_RECONNECT','RESTORE_MICROSOFT_XBOX','RESTORE_CHATPAD_EXTENSION_IF_REQUESTED'));Precondition=if($i){'previous state evidence passes; identity and package hashes unchanged'}else{'preflight PASS; human starts future command'};SuccessCondition='action returns verified bounded success evidence';FailureTransition=if($i -ge 1){'RESTORE_MICROSOFT_XBOX'}else{'STOP'};RollbackTransition=if($i -ge 1){'RESTORE_MICROSOFT_XBOX'}else{'STOP'}}}
}
function Get-ChatpadCurrentSecurity {
 if(-not ('Chatpad.Binding.CodeIntegrity' -as [type])){Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Chatpad.Binding {
 public static class CodeIntegrity {
  [StructLayout(LayoutKind.Sequential)] public struct Info { public uint Length, Options; }
  [DllImport("ntdll.dll")] static extern int NtQuerySystemInformation(int kind,ref Info info,int size,out int used);
  public static Info Query(){Info i=new Info();i.Length=8;int used;int status=NtQuerySystemInformation(103,ref i,8,out used);if(status<0 || used<8)throw new InvalidOperationException("Effective CI query failed: "+status);return i;}
 }
}
'@}
 try{$i=[Chatpad.Binding.CodeIntegrity]::Query();$ok=$true;$testing=($i.Options -band 2) -ne 0;$hvci=($i.Options -band 0x400) -ne 0}catch{$ok=$false;$testing=$null;$hvci=$null}
 $secure=$null;try{$secure=Confirm-SecureBootUEFI -ErrorAction Stop}catch{}
 [pscustomobject]@{CapturedUtc=[DateTime]::UtcNow.ToString('o');QuerySucceeded=$ok;TestSigning=$testing;Hvci=$hvci;SecureBoot=$secure;SecureBootQuery=if($null -eq $secure){'unknown/not accessible'}else{'queried'};Mutation=$false}
}
function Test-ChatpadCurrentSignatures {
 param($Readiness)
 $tool=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/10.0.26100.0/x64/signtool.exe'
 if(-not (Test-Path -LiteralPath $tool)){throw 'Current package signature verifier unavailable.'}
 $m=$Readiness.Microsoft
 Test-ChatpadFileRecords @([pscustomobject]@{Path=$m.InfPath;SHA256=$m.InfSHA256}) 'Microsoft signature source'
 $output=@(& $tool verify /a /pa $m.InfPath 2>&1);if($LASTEXITCODE -ne 0){throw 'Current Microsoft INF catalog signature verification failed.'}
 $sys=@($m.PackageFiles | Where-Object {(Split-Path $_.Path -Leaf) -ieq 'xusb22.sys'})
 if($sys.Count -ne 1){throw 'Exact xusb22.sys recovery source missing/ambiguous.'}
 Test-ChatpadFileRecords $sys 'Microsoft kernel signature source'
 $output=@(& $tool verify /a /kp $sys[0].Path 2>&1);if($LASTEXITCODE -ne 0){throw 'Current Microsoft xusb22.sys kernel signature verification failed.'}
 $inf=@($Readiness.Files | Where-Object Role -eq 'WinUsbInf');$cat=@($Readiness.Files | Where-Object Role -eq 'WinUsbCat')
 if($inf.Count -ne 1 -or $cat.Count -ne 1){throw 'Current WinUSB signature sources missing/ambiguous.'}
 Test-ChatpadFileRecords @($inf+$cat) 'WinUSB signature source'
 $output=@(& $tool verify /pa /c $cat[0].Path $inf[0].Path 2>&1);if($LASTEXITCODE -ne 0){throw 'Current WinUSB catalog trust/INF membership verification failed.'}
 [pscustomobject]@{MicrosoftSourceSignatureVerified=$true;WinUsbCatalogCurrent=$true;PhysicalInstallVerified=$false}
}
function Get-ChatpadCurrentBackend {
 param($Readiness)
 $dep=$Readiness.Dependencies;$p=New-Object Diagnostics.Process
 if(-not (Test-Path -LiteralPath $dep.DotnetPath -PathType Leaf) -or -not (Test-Path -LiteralPath $dep.VirtualAssembly -PathType Leaf)){throw 'Explicit local .NET/runtime helper path unavailable.'}
 foreach($v in @($dep.DotnetPath,$dep.VirtualAssembly)){if($v.Contains('"')){throw 'Invalid runtime path quoting.'}}
 $p.StartInfo.FileName=$dep.DotnetPath;$p.StartInfo.Arguments='"'+$dep.VirtualAssembly+'" backend-status';$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 $p.StartInfo.EnvironmentVariables['DOTNET_ROOT']=Split-Path $dep.DotnetPath -Parent
 $p.StartInfo.EnvironmentVariables['DOTNET_SKIP_FIRST_TIME_EXPERIENCE']='1';$p.StartInfo.EnvironmentVariables['DOTNET_GENERATE_ASPNET_CERTIFICATE']='false';$p.StartInfo.EnvironmentVariables['DOTNET_CLI_TELEMETRY_OPTOUT']='1'
 try{if(-not $p.Start()){throw 'Read-only backend status process failed to start.'};$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(15000)){$p.Kill();$p.WaitForExit();throw 'Read-only backend status timeout.'};$r=$stdout.GetAwaiter().GetResult() | ConvertFrom-Json;if(-not $r.readOnly -or $r.contextConstructed -or $r.liveDeviceCreated){throw 'Backend status failed read-only contract.'};[pscustomobject]@{Available=($p.ExitCode -eq 0 -and $r.availability.sdkCompiled -and $r.availability.runtimeReady);Reason=$r.availability.reason;Status=$r;DotnetPath=$dep.DotnetPath;VirtualAssembly=$dep.VirtualAssembly}}finally{$p.Dispose()}
}
function Invoke-ChatpadC3StateMachine {
 param([Parameter(Mandatory)][scriptblock]$Action)
 $events=[Collections.Generic.List[object]]::new();$dirty=$false;$rollback=$false;$recovered=$false;$passed=$true
 foreach($s in Get-ChatpadC3States){try{if($s.AfterMutation){$dirty=$true};$r=& $Action $s;if(-not $r.Success -or [string]::IsNullOrWhiteSpace([string]$r.Evidence)){throw 'Success condition lacks positive evidence.'};$events.Add([pscustomobject]@{State=$s.Name;Success=$true;Evidence=$r.Evidence})}catch{$passed=$false;$events.Add([pscustomobject]@{State=$s.Name;Success=$false;Error=$_.Exception.Message});if($dirty){$rollback=$true;try{$recovery=@(Get-ChatpadC3States | Where-Object Name -eq 'RESTORE_MICROSOFT_XBOX')[0];$rr=& $Action $recovery;if(-not $rr.Success -or [string]::IsNullOrWhiteSpace([string]$rr.Evidence)){throw 'Rollback postcondition unverified.'};$recovered=$true;$events.Add([pscustomobject]@{State='ROLLBACK';Success=$true;Evidence=$rr.Evidence})}catch{$events.Add([pscustomobject]@{State='ROLLBACK';Success=$false;Error=$_.Exception.Message})}};break}}
 [pscustomobject]@{Passed=$passed;RollbackAttempted=$rollback;RollbackSucceeded=$recovered;Events=@($events)}
}
Export-ModuleMember -Function Get-ChatpadExtensionAllowlist,Read-ChatpadExtensionInf,Get-ChatpadExtensionInventory,Get-ChatpadExtensionSelection,Assert-ChatpadExtensionInventory,Resolve-ChatpadC3Target,Test-ChatpadFileRecords,Assert-ChatpadRestorable,New-ChatpadTransitionPlan,New-ChatpadRestorePlan,New-ChatpadC3Preflight,Get-ChatpadCanonicalReadback,Get-ChatpadC3States,Invoke-ChatpadC3StateMachine,Get-ChatpadCurrentSecurity,Test-ChatpadCurrentSignatures,Get-ChatpadCurrentBackend
