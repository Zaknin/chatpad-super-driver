[CmdletBinding()]
param([string]$ReadinessPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/readiness-input.json'),[switch]$Execute,[switch]$RestoreExtension,[string]$OutputDirectory=(Join-Path $PSScriptRoot ('../artifacts/task-8lc2r1/c3/'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1')
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3SessionIpc.psm1')
if(-not $Execute){Get-ChatpadC3States | ConvertTo-Json -Depth 8;Write-Output 'PLAN ONLY. Future human command -Execute runs the bounded experiment; C2R1 never invokes it.';exit 0}
if([Console]::IsInputRedirected){throw 'Future physical acceptance requires an interactive operator console.'}
$readiness=Get-Content -LiteralPath $ReadinessPath -Raw | ConvertFrom-Json
# Preflight is deliberately a separate child/read-only entrypoint. Positive
# machine report and exit0 are both required before any mutation.
$preflightPath=Join-Path $OutputDirectory 'preflight.json'
New-Item -ItemType Directory $OutputDirectory -Force | Out-Null
& (Join-Path $PSScriptRoot 'ChatpadBinding.ps1') -PreflightC3 -ReadinessPath $ReadinessPath -JsonPath $preflightPath
if($LASTEXITCODE -ne 0){throw 'C3 preflight BLOCKED; no live mutation started.'}
$preflight=Get-Content $preflightPath -Raw | ConvertFrom-Json
if(-not $preflight.C3Ready){throw 'Positive C3 readiness report required.'}
if($RestoreExtension){Assert-ChatpadRestorable $readiness -RestoreExtension}
$script:baseline=$null;$script:child=$null;$script:ipc=$null;$script:sessionNumber=0;$script:events=[Collections.Generic.List[object]]::new();$script:cleanupFailures=[Collections.Generic.List[string]]::new()
function Start-C3Session {
 $poc=@($readiness.Files | Where-Object Role -eq 'Poc')[0].Path;$helper=@($readiness.Files | Where-Object Role -eq 'VirtualBackend')[0].Path
 Test-ChatpadFileRecords @($readiness.Files) 'C3 session binaries'
 $script:child=New-Object Diagnostics.Process
 $script:child.StartInfo.FileName=$poc;$script:child.StartInfo.UseShellExecute=$false;$script:child.StartInfo.CreateNoWindow=$true
 $script:child.StartInfo.RedirectStandardInput=$true;$script:child.StartInfo.RedirectStandardOutput=$true;$script:child.StartInfo.RedirectStandardError=$true
 # Reconnection can change the instance. Re-resolve the unique captured
 # container immediately before every child, including the reconnect child.
 $fresh=Get-ChatpadBindingState; $target=Resolve-ChatpadC3Target @($fresh.Target) $script:baseline.State.Target
 if((Get-ChatpadRecognizedState $fresh) -ne 'WinUSB'){throw 'Fresh same-container WinUSB stack required before session.'}
 $instance=$target.InstanceId
 # Every interpolated argument is a validated fixed identity/path with no quote.
 if($helper.Contains('"') -or $instance.Contains('"')){throw 'Invalid session argument quoting.'}
 $script:child.StartInfo.Arguments='c3-session --seconds 120 --instance "'+$instance+'" --backend-helper "'+$helper+'" --backend hidmaestro'
 $script:child.StartInfo.EnvironmentVariables['DOTNET_ROOT']=Split-Path $readiness.Dependencies.DotnetPath -Parent
 if(-not $script:child.Start()){throw 'Session process start failed.'}
 $script:sessionNumber++;$script:ipc=New-ChatpadC3SessionIpc $script:child
}
function Wait-C3Event([scriptblock]$Predicate,[int]$Seconds=12){Wait-ChatpadC3SessionEvent $script:ipc $Predicate $Seconds}
function Send-C3Command([string]$Command){Send-ChatpadC3SessionCommand $script:ipc $Command}
function Accept-C3Physical([string]$Prompt,[int]$Seconds=20){
 Write-Host ($Prompt+' Press Y only after verifying; N or deadline fails and restores Microsoft Xbox.')
 $end=[DateTime]::UtcNow.AddSeconds($Seconds)
 while([DateTime]::UtcNow -lt $end){if($script:child){Receive-ChatpadC3SessionEvents $script:ipc;if(@($script:ipc.Pending | Where-Object event -eq 'fatal').Count -or $script:child.HasExited -or [DateTime]::UtcNow -ge $script:ipc.Deadline){throw 'Session failed/ended during physical acceptance.'}};if([Console]::KeyAvailable){$k=[Console]::ReadKey($true);if($k.Key -eq [ConsoleKey]::Y){return 'Operator verified: '+$Prompt};if($k.Key -eq [ConsoleKey]::N){throw 'Operator rejected physical acceptance.'}};Start-Sleep -Milliseconds 25}
 throw 'Physical acceptance deadline expired.'
}
function Stop-C3Session {
 if(-not $script:child){return}
 try{
  if(-not $script:child.HasExited){try{Send-C3Command 'stop' | Out-Null}catch{};$script:child.StandardInput.Close();if(-not $script:child.WaitForExit(5000)){$script:child.Kill();$script:child.WaitForExit();throw 'Session forced termination: crash cleanup not proven.'}}
  if(-not $script:ipc.Drain.Join(2000)){throw 'Session pipe drain did not finish after exit.'}
  Receive-ChatpadC3SessionEvents $script:ipc
  $closed=@($script:ipc.History | Where-Object {$_.event -eq 'closed'})
  if($script:child.ExitCode -ne 0 -or $closed.Count -ne 1 -or -not $closed[0].ok){throw 'Session exit/closed cleanup evidence failed; Microsoft restoration still required.'}
 }
 finally{
  if($script:ipc){
   # Always retain bounded telemetry and all control/terminal evidence. Drop
   # counts are explicit; telemetry sampling never serves as cleanup proof.
   $script:events.Add([pscustomobject]@{Session=$script:sessionNumber;Events=@($script:ipc.History);TransportTelemetryDropped=$script:ipc.Drain.Dropped;RetainedTelemetryDropped=$script:ipc.RetainedTelemetryDropped;StderrCharactersDropped=$script:ipc.Drain.ErrorCharactersDropped;DrainFault=$script:ipc.Drain.Fault})
   [IO.File]::WriteAllText((Join-Path $OutputDirectory ('session-'+$script:sessionNumber+'-stderr.txt')),$script:ipc.Drain.Errors+[Environment]::NewLine+'[stderr characters omitted after 1 MiB: '+$script:ipc.Drain.ErrorCharactersDropped+']')
  }
  $script:child.Dispose();$script:child=$null;$script:ipc=$null
 }
}
function Wait-C3ManualDisconnectReconnect {
 # The session has already proven graceful cleanup while USB was attached.
 # This qualifies clean shutdown/reopen, not unexpected hot-unplug cleanup.
 Write-Host 'Unplug the captured controller within 15 seconds; then reconnect that same controller within 15 seconds.'
 $captured=$script:baseline.State.Target;$end=[DateTime]::UtcNow.AddSeconds(15);$absent=$false
 while([DateTime]::UtcNow -lt $end){
  $devices=@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^USB\\VID_045E&PID_028E\\[^\\]+$')
  if(-not $devices.Count){$absent=$true;break};Start-Sleep -Milliseconds 500
 }
 if(-not $absent){throw 'Manual physical disconnect was not observed before deadline.'}
 $end=[DateTime]::UtcNow.AddSeconds(15)
 while([DateTime]::UtcNow -lt $end){
  $devices=@(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^USB\\VID_045E&PID_028E\\[^\\]+$')
  if($devices.Count){$fresh=Get-ChatpadBindingState;Resolve-ChatpadC3Target @($fresh.Target) $captured | Out-Null;return}
  Start-Sleep -Milliseconds 500
 }
 throw 'Manual same-container reconnection was not observed before deadline.'
}
$result=Invoke-ChatpadC3StateMachine -Action {
 param($state)
 $evidence=''
 switch($state.Name){
  'BASELINE_CAPTURE' {$fresh=Get-ChatpadBindingState;Resolve-ChatpadC3Target @($fresh.Target) $preflight.Target | Out-Null;$script:baseline=Save-ChatpadC3Baseline $fresh @($preflight.ExtensionInventory) $readiness (Join-Path $OutputDirectory 'private-baseline');$evidence='Hashed recovery sources captured before mutation.'}
  'EXTENSION_EXCLUSION' {$evidence=(Invoke-ChatpadC3BindingAction Exclude $script:baseline -Execute).Evidence}
  'WINUSB_BIND' {$evidence=(Invoke-ChatpadC3BindingAction Bind $script:baseline -Execute).Evidence}
  'WINUSB_VERIFY' {& (Join-Path $PSScriptRoot 'ChatpadBinding.ps1') -Verify -ExpectedState WinUSB;if($LASTEXITCODE -ne 0){throw 'WinUSB verification failed.'};Start-C3Session;$evidence='Exact WinUSB stack verified; finite continuous session started with outputs disabled.'}
  'PHYSICAL_CONTROLLER_MONITOR' {$e=Wait-C3Event {param($e)$e.event -eq 'controller' -and $e.valid};$evidence=$e | ConvertTo-Json -Compress}
  'CHATPAD_TRANSPORT_MONITOR' {Test-ChatpadC3SessionReadiness $script:ipc | Out-Null;$evidence='Exact session event verifies IF2/84 and independent readers; preactivation silence allowed.'}
  'CHATPAD_ACTIVATION' {$e=Send-C3Command 'activate';$evidence=$e | ConvertTo-Json -Compress}
  'REAL_5_BYTE_REPORT' {$e=Wait-C3Event {param($e)$e.event -eq 'chatpad' -and $e.valid -and $e.bytes -eq 5 -and $e.keyDataEnabled};$evidence=$e | ConvertTo-Json -Compress}
  'VIRTUAL_XBOX_CREATE' {$e=Send-C3Command 'create-virtual';$evidence=$e | ConvertTo-Json -Compress}
  'XINPUT_VERIFY' {$evidence=Accept-C3Physical 'Verify the newly created virtual Xbox identity and its explicit XInput slot; do not select the first connected controller.'}
  'PHYSICAL_TO_VIRTUAL_MAPPING' {Send-C3Command 'enable-mapping' | Out-Null;$evidence=Accept-C3Physical 'Verify each controller button, D-pad, both triggers and both signed stick axes in the intended virtual XInput slot.'}
  'RUMBLE_VERIFY' {Send-C3Command 'enable-rumble' | Out-Null;$evidence=Accept-C3Physical 'Issue separate left/right virtual motor requests, verify physical motors, then request zero motors.'}
  'CHATPAD_SENDINPUT_VERIFY' {Send-C3Command 'enable-keyboard' | Out-Null;$evidence=Accept-C3Physical 'In ordinary Notepad verify Base, Green, Orange, two-key press/release and no held keys after release.'}
  'DISCONNECT_RECONNECT' {
   Stop-C3Session
   $operator=Accept-C3Physical 'With session closed, verify no held keys, neutral/removed virtual target and stopped physical motors before unplugging.' 15
   Wait-C3ManualDisconnectReconnect
   Start-C3Session;Test-ChatpadC3SessionReadiness $script:ipc | Out-Null;$controller=Wait-C3Event {param($e)$e.event -eq 'controller' -and $e.valid};Stop-C3Session
   $evidence='Graceful cleanup, observed absent/present same-container reconnect and fresh WinUSB session/controller report verified. Unexpected hot unplug remains UNTESTED. '+$operator
  }
  'RESTORE_MICROSOFT_XBOX' {
   $recovery=Invoke-ChatpadC3SessionRecovery {Stop-C3Session} {Invoke-ChatpadC3BindingAction Restore $script:baseline -Execute}
   $evidence=$recovery.Restored.Evidence;if(-not $recovery.CleanupSucceeded){$script:cleanupFailures.Add($recovery.CleanupError);$evidence+=' Prior session cleanup FAILED: '+$recovery.CleanupError}
  }
  'RESTORE_CHATPAD_EXTENSION_IF_REQUESTED' {if($RestoreExtension){
   $material=$script:baseline.Readiness.ExtensionRestore;Assert-ChatpadRestorable $script:baseline.Readiness -RestoreExtension
   $fresh=Get-ChatpadBindingState;Resolve-ChatpadC3Target @($fresh.Target) $script:baseline.State.Target | Out-Null
   if((Get-ChatpadRecognizedState $fresh) -ne 'Xbox'){throw 'Healthy same-container Microsoft base required before optional restoration.'}
   $script:baseline.OptionalExtensionRestoreStarted=$true
   $script:baseline | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'private-baseline/baseline.json') -Encoding utf8
   Invoke-C3Process 'pnputil.exe' @('/add-driver',$material.InfPath,'/install')
   $fresh=Get-ChatpadBindingState;Resolve-ChatpadC3Target @($fresh.Target) $script:baseline.State.Target | Out-Null
   $inventory=@(Get-ChatpadExtensionInventory @($fresh.Candidates));Assert-ChatpadExtensionInventory $inventory
   $image=[pscustomobject]@{SHA256=(Get-FileHash -LiteralPath (Join-Path $env:SystemRoot 'System32/drivers/ChatpadFilter.sys')).Hash}
   $evidence=Assert-ChatpadC3ExtensionRestored $fresh $inventory $material $image
  }else{$evidence='Optional kernel extension remains excluded in normal Windows; exact source preserved.'}}
  'FINAL_VERIFY' {& (Join-Path $PSScriptRoot 'ChatpadBinding.ps1') -Verify -ExpectedState Xbox;if($LASTEXITCODE -ne 0){throw 'Final Microsoft Xbox verification failed.'};$evidence=Accept-C3Physical 'Verify normal Microsoft Xbox physical input is restored.'}
 }
 [pscustomobject]@{Success=$true;Evidence=$evidence}
}
if($script:cleanupFailures.Count){$result.Passed=$false;$result | Add-Member NoteProperty CleanupFailures @($script:cleanupFailures)}
$script:events | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $OutputDirectory 'session-events.json')
$result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $OutputDirectory 'result.json')
$result | ConvertTo-Json -Depth 12
if(-not $result.Passed){exit 2}
