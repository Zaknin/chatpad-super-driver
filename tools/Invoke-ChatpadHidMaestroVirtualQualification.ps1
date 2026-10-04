[CmdletBinding()]
param([switch]$Execute,[switch]$CleanupOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root=Join-Path $repo 'artifacts/task-8lc2r3'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroPackage.psm1') -Force
$result=[ordered]@{Result='BLOCKED';Execute=$Execute.IsPresent;Error=$null;PhysicalUnchanged=$false;SecurityUnchanged=$false;TrustUnchanged=$false;GameInputServiceUnchanged=$false;MetadataClean=$false}
function TrustInventory {
 @(foreach($store in @('Cert:\LocalMachine\Root','Cert:\LocalMachine\TrustedPublisher','Cert:\LocalMachine\My','Cert:\CurrentUser\My')){
  [pscustomobject]@{Store=$store;Thumbprints=@(Get-ChildItem $store | ForEach-Object Thumbprint | Sort-Object)}
 }) | ConvertTo-Json -Depth 5 -Compress
}
function PhysicalProjection($state){[ordered]@{Target=$state.Target;Extensions=$state.Extensions;ClassLowerFilters=$state.ClassLowerFilters;ClassUpperFilters=$state.ClassUpperFilters} | ConvertTo-Json -Depth 10 -Compress}
$metadata=@('HKLM:\SYSTEM\CurrentControlSet\Control\GameInput\Devices\045E028E00010005','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameInput\Devices\045E028E00010005','HKLM:\SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_045E&PID_028E')
$before=$null;$securityBefore=$null;$trustBefore=$null;$serviceBefore=$null
try{
 $install=Get-Content (Join-Path $root 'installation-result.json') -Raw | ConvertFrom-Json
 if($install.Result -cne 'STAGED' -or $install.RebootRequired -or $install.PhysicalMutation){throw 'Successful exact package staging prerequisite failed.'}
 $before=Get-ChatpadBindingState
 if($before.Target.Inf -cne 'xusb22.inf' -or $before.Target.Problem -ne 52 -or @($before.Extensions | Where-Object PublishedInf -eq 'oem104.inf').Count -ne 1){throw 'Expected physical baseline changed.'}
 $securityBefore=Get-ChatpadCurrentSecurity
 if(-not $securityBefore.QuerySucceeded -or $securityBefore.TestSigning -ne $false -or $securityBefore.Hvci -ne $true){throw 'Normal-Windows security gate failed.'}
 $trustBefore=TrustInventory
 $cert=Get-ChatpadDevelopmentCertificateState
 foreach($name in @('TrustedRoot','TrustedPublisher','CertificateValid','CodeSigningEku','NoDuplicateCertificates')){if(-not $cert.$name){throw ('Current certificate gate '+$name)}}
 $serviceBefore=Get-Service GameInputSvc | Select-Object Status,StartType
 if($serviceBefore.Status -ne 'Running'){throw 'GameInputSvc must already be running; SDK must not start/reconfigure it.'}
 if(@($metadata | Where-Object {Test-Path -LiteralPath $_}).Count){throw 'Shared profile metadata conflict; no lifecycle attempted.'}
 $before | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root 'physical-virtual-before.private.json') -Encoding utf8
 $trustBefore | Set-Content (Join-Path $root 'trust-virtual-before.private.json') -Encoding utf8
 if(-not $Execute){$result.Result='PLAN';$result | ConvertTo-Json;exit 0}
 if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Virtual root-device creation requires an elevated process.'}
 if($CleanupOnly){
  $qualification=Get-Content (Join-Path $root 'virtual-qualification.private.json') -Raw | ConvertFrom-Json
 }else{
 $start=[Diagnostics.ProcessStartInfo]::new('C:/Dev/tools/dotnet10/dotnet.exe')
 $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 foreach($arg in @((Join-Path $root 'virtual/bin/ChatpadVirtualXbox/release/ChatpadVirtualXbox.dll'),'qualify','--allow-live-virtual','--report-file',(Join-Path $root 'virtual-qualification.private.json'))){$start.ArgumentList.Add($arg)}
 $process=[Diagnostics.Process]::Start($start)
 $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
 if(-not $process.WaitForExit(180000)){$process.Kill($true);throw 'Finite qualification process exceeded 180 seconds; no acceptance claimed.'}
 $out.GetAwaiter().GetResult() | Set-Content (Join-Path $root 'virtual-stdout.txt') -Encoding utf8
 $err.GetAwaiter().GetResult() | Set-Content (Join-Path $root 'virtual-stderr.txt') -Encoding utf8
 $result.ExitCode=$process.ExitCode
 $qualification=Get-Content (Join-Path $root 'virtual-qualification.private.json') -Raw | ConvertFrom-Json
 }
 $ids=@($qualification.pnpActive.Devices | ForEach-Object InstanceId)
 if(-not $qualification.umdfHealthy -or -not $qualification.disconnectReturned -or -not (Test-ChatpadHidMaestroCleanupIds $ids)){throw 'No exact owned post-disconnect cleanup evidence.'}
 $result.PhantomCleanup=@(foreach($id in $ids){
  $device=Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
  if($null -ne $device){
   if($device.Present){throw 'SDK left a present virtual device; stop before removal and retain failure.'}
   $lines=@(& (Join-Path $env:windir 'System32/pnputil.exe') /remove-device $id 2>&1);$code=$LASTEXITCODE
   $lines | Add-Content (Join-Path $root 'virtual-phantom-cleanup.txt') -Encoding utf8
   if($code -ne 0 -or $null -ne (Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue)){throw ('Owned phantom removal failed: '+$code)}
   [pscustomobject]@{InstanceId=$id;ExitCode=$code;Removed=$true}
  }
 })
 $result.NoStaleDevice=$true
 if($CleanupOnly){$result.Result='PASS'}else{
 if($process.ExitCode -ne 0 -or $qualification.result -cne 'PASS'){throw ('Isolated runtime qualification failed: '+($qualification.error | ConvertTo-Json -Compress))}
 $result.Result='PASS'
 }
}catch{$result.Error=$_.Exception.Message;$result.Result='BLOCKED'}
finally{
 if($null -ne $before){
  $after=Get-ChatpadBindingState
  $after | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root 'physical-virtual-after.private.json') -Encoding utf8
  $result.PhysicalUnchanged=(PhysicalProjection $before) -ceq (PhysicalProjection $after)
 }
 if($null -ne $securityBefore){$securityAfter=Get-ChatpadCurrentSecurity;$securityBefore | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'security-virtual-before.json') -Encoding utf8;$securityAfter | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'security-after.json') -Encoding utf8;$result.SecurityUnchanged=Test-ChatpadHidMaestroSecurityInvariant $securityBefore $securityAfter}
 if($null -ne $trustBefore){$trustAfter=TrustInventory;$trustAfter | Set-Content (Join-Path $root 'trust-after.private.json') -Encoding utf8;$result.TrustUnchanged=$trustAfter -ceq $trustBefore}
 if($null -ne $serviceBefore){$serviceAfter=Get-Service GameInputSvc | Select-Object Status,StartType;$result.GameInputServiceUnchanged=($serviceAfter | ConvertTo-Json -Compress) -ceq ($serviceBefore | ConvertTo-Json -Compress)}
 $result.MetadataClean=@($metadata | Where-Object {Test-Path -LiteralPath $_}).Count -eq 0
 if($result.Result -eq 'PASS' -and (-not $result.PhysicalUnchanged -or -not $result.SecurityUnchanged -or -not $result.TrustUnchanged -or -not $result.GameInputServiceUnchanged -or -not $result.MetadataClean)){$result.Result='BLOCKED';$result.Error='Post-qualification invariant failed.'}
 $result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'virtual-invariants.json') -Encoding utf8
}
$result | ConvertTo-Json -Depth 8
if($result.Result -eq 'PASS'){exit 0}else{exit 2}
