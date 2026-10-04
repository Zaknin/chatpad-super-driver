[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Install','Status','Repair','Uninstall','RestoreMicrosoftXbox')][string]$Mode,
 [string]$PackageRoot,
 [string]$ReadinessPath,
 [string]$BaselinePath,
 [string]$InstanceId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$toolsRoot=if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1')){$PSScriptRoot}else{Join-Path $PSScriptRoot 'tools'}
$repo=Split-Path -Parent $toolsRoot
if(-not $ReadinessPath){$ReadinessPath=Join-Path $repo 'artifacts/task-8lc4/readiness-input.json'}
Import-Module (Join-Path $toolsRoot 'ChatpadC4Package.psm1') -Force
if(-not $PackageRoot){
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
 $baseline=Save-ChatpadC3Baseline $fresh $packages $readiness $baselineDirectory
 try {
  Invoke-ChatpadC3BindingAction Exclude $baseline -Execute|Out-Null
  Invoke-ChatpadC3BindingAction Bind $baseline -Execute|Out-Null
  $after=Get-ChatpadBindingState $fresh.Target.InstanceId
  if((Get-ChatpadRecognizedState $after) -cne 'WinUSB' -or $after.Target.Problem -ne 0 -or @($after.Target.LowerFilters).Count -or @($after.Target.UpperFilters).Count){throw 'Post-install WinUSB state did not verify.'}
 }catch{
  try{Invoke-ChatpadC3BindingAction Restore $baseline -Execute|Out-Null}catch{Write-Error -ErrorAction Continue ('Microsoft recovery also failed: '+$_.Exception.Message)}
  throw
 }
 $record=[pscustomobject]@{Schema=1;InstalledUtc=[DateTime]::UtcNow.ToString('o');InstanceId=$fresh.Target.InstanceId;ContainerId=$fresh.Target.ContainerId;BaselinePath=(Join-Path $baselineDirectory 'baseline.json');PackageRoot=[IO.Path]::GetFullPath($PackageRoot);DriverState='WinUSB';ElevationUsed=$true}
 $record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $installRecord -Encoding utf8
 $record|ConvertTo-Json -Depth 8
}
switch($Mode){
 'Status' {
  $status=Get-ChatpadBindingState $InstanceId
  $recognized=Get-ChatpadRecognizedState $status
  [pscustomobject]@{Mode='Status';ReadOnly=$true;Elevated=([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator));RecognizedState=$recognized;Target=$status.Target;ClassLowerFilters=$status.ClassLowerFilters;ClassUpperFilters=$status.ClassUpperFilters;InstallRecordPath=$installRecord;HidMaestroRuntime='query with ChatpadVirtualXbox.exe backend-status'}|ConvertTo-Json -Depth 12
 }
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
  $result=Invoke-ChatpadC3BindingAction Restore $baseline -Execute
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
