[CmdletBinding()]
param([string]$OutputDirectory=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/session-focused'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3SessionIpc.psm1') -Force
New-Item -ItemType Directory $OutputDirectory -Force | Out-Null
$script:checks=0
function Check([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAIL session: $Name"};$script:checks++;Write-Output "PASS $Name"}
function Reject([scriptblock]$Action,[string]$Name){$rejected=$false;try{& $Action | Out-Null}catch{$rejected=$true};Check $rejected $Name}
$fixture=Join-Path $OutputDirectory 'offline-stream-fixture.ps1'
@'
param([switch]$Cached,[switch]$Malformed)
$ErrorActionPreference='Stop'
[Console]::Out.WriteLine('{"event":"controller","valid":true,"report":0}')
if(-not $Cached){Start-Sleep -Milliseconds 200}
$ready='{"event":"session","interfacesVerified":true,"readersStarted":true,"controllerInterface":0,"controllerIn":129,"controllerOut":1,"chatpadInterface":2,"chatpadIn":132,"physicalOutputsEnabled":false}'
if($Malformed){$ready=$ready.Replace('"chatpadIn":132','"chatpadIn":133')}
[Console]::Out.WriteLine($ready)
for($i=1;$i -le 60000;$i++){[Console]::Out.WriteLine('{"event":"controller","valid":true,"report":'+$i+'}');if(($i%500) -eq 0){[Console]::Error.Write(('x'*20000))}}
[Console]::Out.WriteLine('{"event":"drained","reports":60000}')
$command=[Console]::In.ReadLine() | ConvertFrom-Json
if($command.command -ne 'stop'){exit 9}
[Console]::Out.WriteLine('{"event":"command","command":"stop","ok":true,"id":'+$command.id+'}')
[Console]::Out.WriteLine('{"event":"closed","ok":true}')
exit 0
'@ | Set-Content -LiteralPath $fixture -Encoding utf8
function Start-Fixture([string]$Argument='') {
 $p=New-Object Diagnostics.Process
 $p.StartInfo.FileName=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $p.StartInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+[IO.Path]::GetFullPath($fixture)+'" '+$Argument
 $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
 if(-not $p.Start()){throw 'Offline fixture could not start.'};return $p
}
foreach($mode in @('','-Cached')){
 $p=Start-Fixture $mode;$ipc=New-ChatpadC3SessionIpc $p 30
 try{
  $controller=Wait-ChatpadC3SessionEvent $ipc {param($e)$e.event -eq 'controller' -and $e.valid}
  Check ($controller.report -eq 0) ('controller first '+$mode)
  if($mode){Start-Sleep -Milliseconds 300;Receive-ChatpadC3SessionEvents $ipc}
  $ready=Test-ChatpadC3SessionReadiness $ipc
  Check ($ready.event -eq 'session') ('readiness pending or cached '+$mode)
  # Deliberately leave PowerShell idle; the pipe thread must keep draining.
  Start-Sleep -Milliseconds 500
  $done=Wait-ChatpadC3SessionEvent $ipc {param($e)$e.event -eq 'drained'} 15
  Check ($done.reports -eq 60000) ('high volume reached terminal control '+$mode)
  $ack=Send-ChatpadC3SessionCommand $ipc 'stop'
  Check ($ack.ok -and $ack.id -eq 1) ('stop acknowledgement '+$mode)
  Check ($p.WaitForExit(5000)) ('exit while stdout drain remains active '+$mode)
  Check ($ipc.Drain.Join(2000)) ('complete independent stdout stderr drain '+$mode)
  Receive-ChatpadC3SessionEvents $ipc
  Check ($p.ExitCode -eq 0 -and @($ipc.History | Where-Object {$_.event -eq 'closed' -and $_.ok}).Count -eq 1) ('closed and exit proof '+$mode)
  Check ($ipc.History.Count -le 2048 -and $ipc.Pending.Count -le 2048 -and ($ipc.Drain.Dropped+$ipc.RetainedTelemetryDropped) -gt 0 -and $ipc.Drain.Errors.Length -le 1048576 -and $ipc.Drain.ErrorCharactersDropped -gt 0 -and -not $ipc.Drain.Fault) ('bounded retention explicit telemetry/stderr drops '+$mode)
  [pscustomobject]@{Mode=$mode;Retained=$ipc.History.Count;TransportTelemetryDropped=$ipc.Drain.Dropped;RetainedTelemetryDropped=$ipc.RetainedTelemetryDropped;Exit=$p.ExitCode;Mutation=$false} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory ('stream-'+$(if($mode){'cached'}else{'pending'})+'.json'))
 }finally{if(-not $p.HasExited){$p.Kill();$p.WaitForExit(2000)|Out-Null};$p.Dispose()}
}
$p=Start-Fixture '-Malformed';$ipc=New-ChatpadC3SessionIpc $p 20
try{Reject {Test-ChatpadC3SessionReadiness $ipc} 'wrong endpoint readiness rejected'}finally{if(-not $p.HasExited){$p.Kill();$p.WaitForExit(2000)|Out-Null};$ipc.Drain.Join(2000)|Out-Null;$p.Dispose()}
$script:restores=0
$recovery=Invoke-ChatpadC3SessionRecovery {throw 'fixture cleanup failed'} {$script:restores++;[pscustomobject]@{Success=$true;Evidence='Fixture base verified'}}
Check ($script:restores -eq 1 -and -not $recovery.CleanupSucceeded -and $recovery.CleanupError -eq 'fixture cleanup failed' -and $recovery.Restored.Success) 'restore executes after cleanup failure with separate failed evidence'
Reject {Invoke-ChatpadC3SessionRecovery {} {throw 'fixture restore failed'}} 'restoration failure never reported recovered'
$hash='A'*64;$sysHash='B'*64
$material=[pscustomobject]@{NormalWindowsLoadExpected=$true;Version='1.0.14.0';Files=@([pscustomobject]@{Path='ChatpadFilterExtension.inf';SHA256=$hash},[pscustomobject]@{Path='ChatpadFilter.sys';SHA256=$sysHash})}
$inventory=@([pscustomobject]@{Known=$true;SHA256=$hash;Version='1.0.14.0';Selected=$true})
$state=[pscustomobject]@{Target=[pscustomobject]@{Problem=0;Service='xusb22';Inf='xusb22.inf';Provider='Microsoft';LowerFilters=@('vhf','ChatpadFilter');UpperFilters=@()};ClassLowerFilters=@();ClassUpperFilters=@();Stack=@('xusb22','ChatpadFilter','vhf');Services=@([pscustomobject]@{Name='ChatpadFilter';State='Running'})}
$image=[pscustomobject]@{SHA256=$sysHash}
Check (-not [string]::IsNullOrEmpty((Assert-ChatpadC3ExtensionRestored $state $inventory $material $image))) 'positive exact optional extension fixture'
$inventory[0].Selected=$null;Reject {Assert-ChatpadC3ExtensionRestored $state $inventory $material $image} 'unproven installed extension association blocked';$inventory[0].Selected=$true
$image.SHA256='C'*64;Reject {Assert-ChatpadC3ExtensionRestored $state $inventory $material $image} 'wrong installed filter hash blocked';$image.SHA256=$sysHash
$state.Target.LowerFilters=@();Reject {Assert-ChatpadC3ExtensionRestored $state $inventory $material $image} 'Xbox-only state not optional extension success';$state.Target.LowerFilters=@('vhf','ChatpadFilter')
$material.NormalWindowsLoadExpected=$false;Reject {Assert-ChatpadC3ExtensionRestored $state $inventory $material $image} 'normal Windows optional load uncertainty blocked'
[pscustomobject]@{Suite='C3Session';Passed=$script:checks;Failed=0;LiveMutation=$false;FixtureReports=120000} | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'summary.json')
Write-Output "PASS session $script:checks/$script:checks"
