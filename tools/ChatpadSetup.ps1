[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Install','InstallBroker','Status','Repair','RepairBroker','Uninstall','UninstallBroker','RestoreMicrosoftXbox')][string]$Mode,
 [string]$PackageRoot,
 [string]$ReadinessPath,
 [string]$BaselinePath,
 [string]$InstanceId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$toolsRoot=if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1')){$PSScriptRoot}else{Join-Path $PSScriptRoot 'tools'}
$repo=Split-Path -Parent $toolsRoot
if(-not $ReadinessPath){$ReadinessPath=Join-Path $repo 'artifacts/task-8lc4l2/readiness-input.json'}
Import-Module (Join-Path $toolsRoot 'ChatpadC4Package.psm1') -Force
if(-not $PackageRoot -and $Mode -in @('Install','InstallBroker','Repair','RepairBroker')){
 if(-not(Test-Path -LiteralPath $ReadinessPath -PathType Leaf)){throw 'C4 readiness is missing; build the Release package first.'}
 $identity=Get-Content -LiteralPath $ReadinessPath -Raw|ConvertFrom-Json
 $PackageRoot=Get-ChatpadC4ReadinessPackageRoot $identity
}
$stateDirectory=Join-Path $env:ProgramData 'ChatpadBridge'
$installRecord=Join-Path $stateDirectory 'install.json'
Import-Module (Join-Path $toolsRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
Import-Module (Join-Path $toolsRoot 'ChatpadBinding/C3Planning.psm1') -Force
function Require-Administrator {
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $principal=[Security.Principal.WindowsPrincipal]::new($identity)
 if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw "$Mode requires an elevated PowerShell process; normal ChatpadBridge run/status does not."}
}
function Get-SetupBaseline {
 if($BaselinePath){$candidate=$BaselinePath}
 elseif(Test-Path -LiteralPath $installRecord){$candidate=[string](Get-Content -LiteralPath $installRecord -Raw|ConvertFrom-Json).BaselinePath}
 else{throw 'No saved Microsoft recovery baseline; Install must capture one before binding.'}
 if(-not(Test-Path -LiteralPath $candidate -PathType Leaf)){throw 'Saved Microsoft recovery baseline is missing.'}
 Get-Content -LiteralPath $candidate -Raw|ConvertFrom-Json
}
function Assert-RunnerStopped {
 $running=@(Get-Process -Name ChatpadBridge -ErrorAction SilentlyContinue)
 if($running.Count){throw 'Stop ChatpadBridge run before Repair, RestoreMicrosoftXbox or Uninstall; no process was terminated automatically.'}
}
function Get-ChatpadBrokerSetupIdentity {
 if(-not ('ChatpadBrokerSetupNative' -as [type])){
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Security.Principal;
public static class ChatpadBrokerSetupNative {
 [DllImport("kernel32.dll")] private static extern uint WTSGetActiveConsoleSessionId();
 [DllImport("kernel32.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool ProcessIdToSessionId(uint processId, out uint sessionId);
 [DllImport("wtsapi32.dll", CharSet=CharSet.Unicode, SetLastError=true, EntryPoint="WTSQuerySessionInformationW")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool WTSQuerySessionInformation(IntPtr server, int session, int infoClass, out IntPtr buffer, out int bytes);
 [DllImport("wtsapi32.dll")] private static extern void WTSFreeMemory(IntPtr value);
 private static int Read(int session, int infoClass, bool word) { IntPtr data=IntPtr.Zero; try { if(!WTSQuerySessionInformation(IntPtr.Zero,session,infoClass,out data,out _)) return -1; return word ? (int)(ushort)Marshal.ReadInt16(data) : Marshal.ReadInt32(data); } finally { if(data!=IntPtr.Zero) WTSFreeMemory(data); } }
 public static string UserSid { get { using(var identity=WindowsIdentity.GetCurrent()) return identity.User==null ? "" : identity.User.Value; } }
 public static bool Elevated { get { using(var identity=WindowsIdentity.GetCurrent()) return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator); } }
 public static int CurrentSession { get { uint value; return ProcessIdToSessionId((uint)System.Diagnostics.Process.GetCurrentProcess().Id,out value) ? (int)value : -1; } }
 public static int ActiveConsoleSession { get { uint value=WTSGetActiveConsoleSessionId(); return value==UInt32.MaxValue ? -1 : (int)value; } }
 public static int WtsProtocol { get { int session=ActiveConsoleSession; return session<0 ? -1 : Read(session,16,true); } }
 public static string SessionState { get { int session=ActiveConsoleSession; return session>=0 && Read(session,8,false)==0 ? "Active" : "Disconnected"; } }
}
'@
 }
 [pscustomobject]@{Elevated=[ChatpadBrokerSetupNative]::Elevated;UserSid=[ChatpadBrokerSetupNative]::UserSid;TokenSessionId=[ChatpadBrokerSetupNative]::CurrentSession;ActiveConsoleSessionId=[ChatpadBrokerSetupNative]::ActiveConsoleSession;WtsProtocol=[ChatpadBrokerSetupNative]::WtsProtocol;SessionState=[ChatpadBrokerSetupNative]::SessionState}
}
function Get-ChatpadBrokerAuthorizedIdentity {
 Require-Administrator
 $identity=Get-ChatpadBrokerSetupIdentity
 if(-not(Test-ChatpadBrokerSetupIdentity $identity $identity.UserSid)){throw 'Broker lifecycle requires an elevated setup process running as the authorized user in the active local console session; RDP and other sessions are rejected.'}
 return $identity
}
function Set-ChatpadBrokerInstallAcl([string]$Path) {
 $acl=Get-Acl -LiteralPath $Path
 $acl.SetAccessRuleProtection($true,$false)
 foreach($rule in @($acl.Access)){$acl.RemoveAccessRuleSpecific($rule)}
 $inherit=[Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
 $principals=@(
  [Security.Principal.SecurityIdentifier]::new('S-1-5-18'),
  [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
 )
 foreach($principal in $principals){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($principal,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))}
 $users=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
 $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($users,[Security.AccessControl.FileSystemRights]::ReadAndExecute,$inherit,[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function Set-ChatpadBrokerInstalledFileAcl([string]$Path) {
 $acl=Get-Acl -LiteralPath $Path
 $acl.SetAccessRuleProtection($true,$false)
 foreach($rule in @($acl.Access)){$acl.RemoveAccessRuleSpecific($rule)}
 $system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18')
 $administrators=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
 $users=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
 foreach($identity in @($system,$administrators)){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))}
 $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($users,[Security.AccessControl.FileSystemRights]::ReadAndExecute,[Security.AccessControl.AccessControlType]::Allow))
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function Invoke-ChatpadBrokerSc([string[]]$Arguments) {
 & sc.exe @Arguments
 if($LASTEXITCODE -ne 0){throw "Service Control Manager command failed for the fixed Chatpad broker service: sc.exe $($Arguments -join ' ') (exit $LASTEXITCODE)."}
}
function Get-ChatpadBrokerServiceRecord {
 $service=Get-CimInstance -ClassName Win32_Service -Filter "Name='ChatpadHidMaestroBroker'" -ErrorAction SilentlyContinue
 if(-not $service){return $null}
 $service
}
function Assert-ChatpadBrokerInstalledServiceIdentity($Service) {
 if(-not $Service){throw 'The fixed broker service is not installed.'}
 $root=Assert-ChatpadBrokerInstallRoot (Join-Path $env:ProgramFiles 'ChatpadBridge')
 $expected=('"'+(Join-Path $root 'ChatpadVirtualXbox.exe')+'" service')
 if(-not([string]$Service.StartName).Equals('LocalSystem',[StringComparison]::OrdinalIgnoreCase) -or -not([string]$Service.StartMode).Equals('Auto',[StringComparison]::OrdinalIgnoreCase) -or -not([string]$Service.PathName).Equals($expected,[StringComparison]::OrdinalIgnoreCase)){
  throw 'Existing broker service account/start mode/path conflicts with the fixed LocalSystem automatic protected-root service; refusing to replace it.'
 }
 return $true
}
function Wait-ChatpadBrokerServiceState([string]$State,[int]$TimeoutSeconds=30) {
 $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
 do{$service=Get-ChatpadBrokerServiceRecord;if($service -and [string]$service.State -ceq $State){return $service};Start-Sleep -Milliseconds 250}while([DateTime]::UtcNow -lt $deadline)
 throw "Broker service did not reach $State within $TimeoutSeconds seconds."
}
function Write-ChatpadBrokerAuthorization($Plan) {
 $path=$Plan.AuthorizationPath
 if(Test-Path -LiteralPath $path){if((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Broker authorization file is a reparse point.'}}
 $temporary=Join-Path $Plan.InstallRoot ('.BrokerAuthorization-'+[guid]::NewGuid().ToString('N')+'.tmp')
 [IO.File]::WriteAllText($temporary,[string]$Plan.AuthorizationJson,[Text.UTF8Encoding]::new($false))
 try{Set-ChatpadBrokerInstalledFileAcl $temporary;Move-Item -LiteralPath $temporary -Destination $path -Force}finally{Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
 Set-ChatpadBrokerInstalledFileAcl $path
 $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
 if($actual -cne [string]$Plan.AuthorizationHash){throw 'Generated BrokerAuthorization.json hash did not match bytes written.'}
}
function Copy-ChatpadBrokerRuntime($Plan) {
 if(-not(Test-Path -LiteralPath $Plan.InstallRoot)){New-Item -ItemType Directory -Path $Plan.InstallRoot -Force|Out-Null}
 $null=Assert-ChatpadBrokerInstallRoot $Plan.InstallRoot
 Set-ChatpadBrokerInstallAcl $Plan.InstallRoot
 foreach($member in $Plan.RuntimeRecords){
  if(-not(Test-Path -LiteralPath $member.SourcePath -PathType Leaf) -or (Get-Item -LiteralPath $member.SourcePath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint -or (Get-FileHash -LiteralPath $member.SourcePath -Algorithm SHA256).Hash -ine [string]$member.SHA256){throw "Packaged service member is missing, reparse, or stale: $($member.Name)"}
  if(Test-Path -LiteralPath $member.TargetPath){if((Get-Item -LiteralPath $member.TargetPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Installed service member is a reparse point: $($member.Name)"}}
  Copy-Item -LiteralPath $member.SourcePath -Destination $member.TargetPath -Force
  Set-ChatpadBrokerInstalledFileAcl $member.TargetPath
  Assert-ChatpadBrokerInstalledRuntimeMember $member $Plan.InstallRoot|Out-Null
 }
}
function Set-ChatpadBrokerAuthorizationHash($Plan) {
 $key='HKLM:\SYSTEM\CurrentControlSet\Services\ChatpadHidMaestroBroker\Parameters'
 New-Item -Path $key -Force|Out-Null
 New-ItemProperty -LiteralPath $key -Name AuthorizationSha256 -PropertyType String -Value $Plan.AuthorizationHash -Force|Out-Null
 if((Get-ItemProperty -LiteralPath $key -Name AuthorizationSha256).AuthorizationSha256 -cne $Plan.AuthorizationHash){throw 'Service Parameters authorization hash readback mismatch.'}
}
function Configure-ChatpadBrokerService($Plan,[bool]$Create) {
 if($Create){Invoke-ChatpadBrokerSc -Arguments (New-ChatpadBrokerScArguments -Operation Create -Plan $Plan)}
 else{Invoke-ChatpadBrokerSc -Arguments (New-ChatpadBrokerScArguments -Operation Config -Plan $Plan)}
 Invoke-ChatpadBrokerSc -Arguments (New-ChatpadBrokerScArguments -Operation Failure -Plan $Plan)
 Invoke-ChatpadBrokerSc -Arguments (New-ChatpadBrokerScArguments -Operation FailureFlag -Plan $Plan)
 $service=Get-ChatpadBrokerServiceRecord
 Assert-ChatpadBrokerInstalledServiceIdentity $service|Out-Null
 Set-ChatpadBrokerAuthorizationHash $Plan
}
function Write-ChatpadBrokerInstallRecord($Plan,$Readiness) {
 Initialize-PrivateStateDirectory
 $record=[pscustomobject]@{Schema=1;ServiceName=$Plan.ServiceName;AuthorizedUserSid=$Plan.AuthorizedUserSid;Repository=$Readiness.Repository;InstallRoot=$Plan.InstallRoot;AuthorizationSha256=$Plan.AuthorizationHash;Members=@($Plan.RuntimeRecords|ForEach-Object {@{Name=$_.Name;SHA256=$_.SHA256}})}
 $record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $stateDirectory 'broker-install.json') -Encoding utf8
}
function Get-ChatpadBrokerReleasePlan {
 if(-not(Test-Path -LiteralPath $ReadinessPath -PathType Leaf)){throw 'Broker C4L2 readiness identity is missing; build the exact package first.'}
 $readiness=Get-Content -LiteralPath $ReadinessPath -Raw|ConvertFrom-Json
 $branch=[string](& git.exe -C $repo branch --show-current);$head=[string](& git.exe -C $repo rev-parse HEAD)
 if($LASTEXITCODE -ne 0 -or $readiness.Repository.Branch -cne $branch -or $readiness.Repository.Commit -cne $head){throw 'Broker readiness branch/commit is stale; regenerate the package from current HEAD.'}
 $root=Resolve-ChatpadBrokerPackageRoot $PackageRoot (Get-ChatpadC4ReadinessPackageRoot $readiness)
 Assert-ChatpadC4PackageIdentity $readiness $root (Join-Path $PSScriptRoot 'ChatpadSetup.ps1')|Out-Null
 $identity=Get-ChatpadBrokerAuthorizedIdentity
 $runtime=@($readiness.Files|Where-Object Role -like 'VirtualFile:*')
 $plan=New-ChatpadBrokerServicePlan -Mode $Mode -InstallRoot (Join-Path $env:ProgramFiles 'ChatpadBridge') -RuntimeRecords $runtime -AuthorizedUserSid $identity.UserSid
 return [pscustomobject]@{Plan=$plan;Readiness=$readiness;Identity=$identity}
}
function Install-ChatpadBroker([switch]$Repair) {
 Require-Administrator
 Assert-RunnerStopped
 $release=Get-ChatpadBrokerReleasePlan
 $service=Get-ChatpadBrokerServiceRecord
 if($Repair){Assert-ChatpadBrokerInstalledServiceIdentity $service|Out-Null;if($service.State -ne 'Stopped'){Stop-Service -Name $release.Plan.ServiceName -Force;Wait-ChatpadBrokerServiceState 'Stopped'|Out-Null}}
 elseif($service){throw 'Broker service already exists; use -Mode RepairBroker to update its exact packaged runtime.'}
 Copy-ChatpadBrokerRuntime $release.Plan
 Write-ChatpadBrokerAuthorization $release.Plan
 Configure-ChatpadBrokerService $release.Plan (-not $Repair)
 Start-Service -Name $release.Plan.ServiceName
 $running=Wait-ChatpadBrokerServiceState 'Running'
 Assert-ChatpadBrokerInstalledServiceIdentity $running|Out-Null
 Write-ChatpadBrokerInstallRecord $release.Plan $release.Readiness
 [pscustomobject]@{Result='PASS';Mode=$Mode;ServiceName=$release.Plan.ServiceName;State=$running.State;StartName=$running.StartName;PathName=$running.PathName;InstallRoot=$release.Plan.InstallRoot;AuthorizedUserSid=$release.Identity.UserSid;RuntimeMembers=@($release.Plan.RuntimeRecords).Count;Recovery='restart/5000,restart/15000,restart/30000';PhysicalBindingChanged=$false}
}
function Remove-ChatpadBrokerService {
 Require-Administrator
 Assert-RunnerStopped
 $null=Get-ChatpadBrokerAuthorizedIdentity
 $service=Get-ChatpadBrokerServiceRecord
 if(-not $service){return [pscustomobject]@{Result='PASS';Mode='UninstallBroker';ServiceName='ChatpadHidMaestroBroker';State='NotInstalled';FilesRetained=$true}}
 Assert-ChatpadBrokerInstalledServiceIdentity $service|Out-Null
 if($service.State -ne 'Stopped'){Stop-Service -Name 'ChatpadHidMaestroBroker' -Force;Wait-ChatpadBrokerServiceState 'Stopped'|Out-Null}
 Invoke-ChatpadBrokerSc @('delete','ChatpadHidMaestroBroker')
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{$remaining=Get-ChatpadBrokerServiceRecord;if(-not $remaining){break};Start-Sleep -Milliseconds 250}while([DateTime]::UtcNow -lt $deadline)
 if($remaining){throw 'Broker service deletion was accepted but the fixed service registration did not disappear within 30 seconds.'}
 Remove-Item -LiteralPath (Join-Path $stateDirectory 'broker-install.json') -Force -ErrorAction SilentlyContinue
 [pscustomobject]@{Result='PASS';Mode='UninstallBroker';ServiceName='ChatpadHidMaestroBroker';State='Deleted';FilesRetained=$true;PhysicalBindingChanged=$false}
}
function Get-ChatpadBrokerStatus {
 $service=Get-ChatpadBrokerServiceRecord
 [pscustomobject]@{ServiceName='ChatpadHidMaestroBroker';Installed=[bool]$service;State=if($service){$service.State}else{'NotInstalled'};StartMode=if($service){$service.StartMode}else{$null};StartName=if($service){$service.StartName}else{$null};PathName=if($service){$service.PathName}else{$null};IdentityValid=if($service){try{Assert-ChatpadBrokerInstalledServiceIdentity $service|Out-Null;$true}catch{$false}}else{$false};Elevated=([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))}
}
function Initialize-PrivateStateDirectory {
 New-Item -ItemType Directory -Force -Path $stateDirectory|Out-Null
 $acl=Get-Acl -LiteralPath $stateDirectory
 $acl.SetAccessRuleProtection($true,$false)
 foreach($rule in @($acl.Access)){$acl.RemoveAccessRuleSpecific($rule)}
 $inherit=[Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
 $system=[Security.Principal.SecurityIdentifier]::new('S-1-5-18')
 $administrators=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
 foreach($identity in @($system,$administrators)){
  $rule=[Security.AccessControl.FileSystemAccessRule]::new($identity,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow)
  $acl.AddAccessRule($rule)
 }
 Set-Acl -LiteralPath $stateDirectory -AclObject $acl
}
function Write-InstallRecord($Record) {
 $Record|Add-Member -NotePropertyName UpdatedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
 $Record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $installRecord -Encoding utf8
}
function Install-Bridge {
 Require-Administrator
 Assert-RunnerStopped
 if(-not(Test-Path -LiteralPath $ReadinessPath -PathType Leaf)){throw 'C4 readiness file is missing; build the Release package first.'}
 if(-not(Test-Path -LiteralPath (Join-Path $PackageRoot 'ChatpadBridge.exe') -PathType Leaf) -or -not(Test-Path -LiteralPath (Join-Path $PackageRoot 'ChatpadVirtualXbox.exe') -PathType Leaf)){throw 'Release runner/helper package is incomplete.'}
 $readiness=Get-Content -LiteralPath $ReadinessPath -Raw|ConvertFrom-Json
 $branch=[string](& git.exe -C $repo branch --show-current);$head=[string](& git.exe -C $repo rev-parse HEAD)
 if($LASTEXITCODE -ne 0 -or $readiness.Repository.Branch -cne $branch -or $readiness.Repository.Commit -cne $head){throw 'Readiness branch/commit is stale; regenerate immediately before setup.'}
 Assert-ChatpadC4PackageIdentity $readiness $PackageRoot (Join-Path $PSScriptRoot 'ChatpadSetup.ps1')|Out-Null
 $preflightPath=Join-Path $repo 'artifacts/task-8lc4/setup-preflight-live.json'
 & (Join-Path $toolsRoot 'ChatpadBinding.ps1') -PreflightC3 -ReadinessPath $ReadinessPath -JsonPath $preflightPath
 if($LASTEXITCODE -ne 0){throw 'Exact-target C3 preflight blocked; see setup-preflight-live.json.'}
 $preflight=Get-Content -LiteralPath $preflightPath -Raw|ConvertFrom-Json
 if(-not $preflight.C3Ready -or @($preflight.Blockers).Count){throw 'C3 preflight did not authorize the exact current machine state.'}
 $runtime=Join-Path $PackageRoot 'ChatpadVirtualXbox.exe'
 & $runtime backend-status|Out-Null
 if($LASTEXITCODE -ne 0){throw 'Pinned HIDMaestro runtime status did not pass.'}
 $fresh=Get-ChatpadBindingState $InstanceId
 Resolve-ChatpadC3Target @($fresh.Target) $preflight.Target|Out-Null
 if($fresh.Target.Inf -cne 'xusb22.inf' -or $fresh.Target.Problem -ne 0 -or @($fresh.Target.LowerFilters).Count -or @($fresh.Target.UpperFilters).Count -or @($fresh.ClassLowerFilters).Count -or @($fresh.ClassUpperFilters).Count){throw 'Install requires healthy Microsoft xusb22 with no device/class filters.'}
 $packages=@(Get-ChatpadExtensionInventory -CandidateLines @($fresh.Candidates))
 $programFiles=Join-Path $env:ProgramFiles 'ChatpadBridge'
 New-Item -ItemType Directory -Force -Path $programFiles|Out-Null
 Get-ChildItem -LiteralPath $PackageRoot -Force|Where-Object Name -notin @('tools','ChatpadSetup.ps1')|Copy-Item -Destination $programFiles -Recurse -Force
 foreach($record in @($readiness.Files|Where-Object Role -like 'VirtualFile:*')){
  Assert-ChatpadC4InstalledRuntimeMember $record $programFiles|Out-Null
 }
 $stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
 Initialize-PrivateStateDirectory
 $baselineDirectory=Join-Path $stateDirectory ('baseline-'+$stamp)
 Import-Module (Join-Path $toolsRoot 'ChatpadBinding/C3Execution.psm1') -Force
 $baseline=Save-ChatpadC3Baseline $fresh $packages $readiness $baselineDirectory -PrivateRoot $stateDirectory
 $record=[pscustomobject]@{Schema=2;SetupStartedUtc=[DateTime]::UtcNow.ToString('o');InstanceId=$fresh.Target.InstanceId;ContainerId=$fresh.Target.ContainerId;BaselinePath=(Join-Path $baselineDirectory 'baseline.json');PackageRoot=[IO.Path]::GetFullPath($PackageRoot);DriverState='SetupInProgress';RebootRequired=$false;SetupError=$null;RecoveryError=$null}
 Write-InstallRecord $record
 try {
  Invoke-ChatpadC3BindingAction Exclude $baseline -Execute|Out-Null
  $bindResult=Invoke-ChatpadC3BindingAction Bind $baseline -Execute -AllowPendingReboot
  if($bindResult.RebootRequired){
   $record.DriverState='WinUSBBindPendingReboot';$record.RebootRequired=$true;Write-InstallRecord $record
   return [pscustomobject]@{Result='PENDING_REBOOT';RebootRequired=$true;InstanceId=$fresh.Target.InstanceId;BaselinePath=$record.BaselinePath;DriverState=$record.DriverState;Message='WinUSB installation succeeded but Windows requires a restart to complete device binding. Restart manually, then run ChatpadSetup.ps1 -Mode Status to verify.'}
  }
  $after=Get-ChatpadBindingState $fresh.Target.InstanceId
  if((Get-ChatpadRecognizedState $after) -cne 'WinUSB' -or $after.Target.Problem -ne 0 -or @($after.Target.LowerFilters).Count -or @($after.Target.UpperFilters).Count){throw 'Post-install WinUSB state did not verify.'}
  $record.DriverState='WinUSB';$record.RebootRequired=$false;Write-InstallRecord $record
  return [pscustomobject]@{Result='PASS';RebootRequired=$false;InstanceId=$fresh.Target.InstanceId;BaselinePath=$record.BaselinePath;DriverState=$record.DriverState}
 }catch{
  $setupError=$_.Exception.Message
  try{
   $restoreResult=Invoke-ChatpadC3BindingAction Restore $baseline -Execute -AllowPendingReboot
   if($restoreResult.RebootRequired){$record.DriverState='MicrosoftRestorePendingReboot';$record.RebootRequired=$true;$record.SetupError=$setupError;Write-InstallRecord $record;Write-Error -ErrorAction Continue 'Microsoft driver selection was issued successfully but Windows requires a restart to complete restoration.'}
   else{$record.DriverState='MicrosoftRestoredAfterSetupFailure';$record.RebootRequired=$false;$record.SetupError=$setupError;Write-InstallRecord $record}
  }catch{$recoveryError=$_.Exception.Message;$record.DriverState='RecoveryFailed';$record.RebootRequired=$false;$record.SetupError=$setupError;$record.RecoveryError=$recoveryError;Write-InstallRecord $record;Write-Error -ErrorAction Continue ('Microsoft recovery also failed: '+$recoveryError)}
  throw
 }
}
switch($Mode){
 'Status' {
  $status=Get-ChatpadBindingState $InstanceId
  $recognized=Get-ChatpadRecognizedState $status
  [pscustomobject]@{Mode='Status';ReadOnly=$true;Elevated=([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator));RecognizedState=$recognized;Target=$status.Target;ClassLowerFilters=$status.ClassLowerFilters;ClassUpperFilters=$status.ClassUpperFilters;InstallRecordPath=$installRecord;HidMaestroRuntime='query with ChatpadVirtualXbox.exe backend-status';BrokerService=(Get-ChatpadBrokerStatus)}|ConvertTo-Json -Depth 12
 }
 'InstallBroker' {Install-ChatpadBroker}
 'RepairBroker' {Install-ChatpadBroker -Repair}
 'UninstallBroker' {Remove-ChatpadBrokerService}
 'Install' {Install-Bridge}
 'Repair' {
  Require-Administrator
  Assert-RunnerStopped
  $current=Get-ChatpadBindingState $InstanceId
  if((Get-ChatpadRecognizedState $current) -ceq 'WinUSB' -and $current.Target.Problem -eq 0){'PASS: exact WinUSB binding already healthy; no PnP mutation required.'}
  elseif(Test-Path -LiteralPath $installRecord){
   $saved=Get-SetupBaseline
   Import-Module (Join-Path $toolsRoot 'ChatpadBinding/C3Execution.psm1') -Force
   Invoke-ChatpadC3BindingAction Restore $saved -Execute|Out-Null
   Install-Bridge
  }
  else{throw 'No exact C4 install baseline exists. Restore Microsoft Xbox or run Install from healthy Microsoft state.'}
 }
 'RestoreMicrosoftXbox' {
  Require-Administrator
  Assert-RunnerStopped
  $baseline=Get-SetupBaseline
  Import-Module (Join-Path $toolsRoot 'ChatpadBinding/C3Execution.psm1') -Force
  $result=Invoke-ChatpadC3BindingAction Restore $baseline -Execute -AllowPendingReboot
  if($result.Success){$result|ConvertTo-Json -Depth 8}
 }
 'Uninstall' {
  Require-Administrator
  Assert-RunnerStopped
  $baseline=Get-SetupBaseline
  Import-Module (Join-Path $toolsRoot 'ChatpadBinding/C3Execution.psm1') -Force
  $result=Invoke-ChatpadC3BindingAction Restore $baseline -Execute
  if(-not $result.Success){throw 'Microsoft Xbox restoration did not verify; install record retained.'}
  $programRoot=[IO.Path]::GetFullPath($env:ProgramFiles).TrimEnd('\')+[IO.Path]::DirectorySeparatorChar
  $programFiles=[IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'ChatpadBridge'))
  if(-not $programFiles.StartsWith($programRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Uninstall target escaped Program Files.'}
  if(Test-Path -LiteralPath $programFiles){
   if((Get-Item -LiteralPath $programFiles -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Uninstall target is a reparse point; refusing recursive removal.'}
   Remove-Item -LiteralPath $programFiles -Recurse -Force
  }
  Remove-Item -LiteralPath $installRecord -Force -ErrorAction SilentlyContinue
  'PASS: Microsoft xusb22 restored; the shared HIDMaestro runtime was retained.'
 }
}
