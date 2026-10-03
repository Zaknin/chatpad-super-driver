Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not ('Chatpad.C3.SessionDrain' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'C3SessionDrain.cs')}
function New-ChatpadC3SessionIpc {
 param([Diagnostics.Process]$Process,[int]$Seconds=120)
 [pscustomobject]@{Process=$Process;Drain=[Chatpad.C3.SessionDrain]::new($Process.StandardOutput,$Process.StandardError,4096);Pending=[Collections.Generic.List[object]]::new();History=[Collections.Generic.List[object]]::new();Deadline=[DateTime]::UtcNow.AddSeconds($Seconds);NextId=0;RetainedTelemetryDropped=0}
}
function Add-C3BoundedEvent($List,$Event,$Ipc) {
 if($List.Count -ge 2048){
  $victim=-1;for($i=1;$i -lt $List.Count;$i++){if($List[$i].event -in @('controller','chatpad')){$victim=$i;break}}
  if($victim -lt 0){if($Event.event -in @('controller','chatpad')){$Ipc.RetainedTelemetryDropped++;return};throw 'Retained C3 control evidence overflow.'}
  $List.RemoveAt($victim);$Ipc.RetainedTelemetryDropped++
 }
 $List.Add($Event)
}
function Receive-ChatpadC3SessionEvents {
 param($Ipc)
 foreach($line in $Ipc.Drain.Take()){
  $event=$line | ConvertFrom-Json
  if(-not $event.PSObject.Properties['event']){throw 'Session event contract missing event type.'}
  Add-C3BoundedEvent $Ipc.Pending $event $Ipc;Add-C3BoundedEvent $Ipc.History $event $Ipc
 }
 if($Ipc.Drain.Fault){throw $Ipc.Drain.Fault}
}
function Wait-ChatpadC3SessionEvent {
 param($Ipc,[scriptblock]$Predicate,[int]$Seconds=12,[switch]$AllowFatal)
 $end=[DateTime]::UtcNow.AddSeconds($Seconds)
 while([DateTime]::UtcNow -lt $end -and [DateTime]::UtcNow -lt $Ipc.Deadline){
  # Sample EOF before Take. If EOF becomes true after Take, another iteration
  # must collect the terminal events that arrived in that small race window.
  $ended=$Ipc.Process.HasExited -and $Ipc.Drain.OutputEnded
  Receive-ChatpadC3SessionEvents $Ipc
  if(-not $AllowFatal){$fatal=@($Ipc.Pending | Where-Object event -eq 'fatal');if($fatal.Count){throw ('C3 session fatal: '+($fatal[0] | ConvertTo-Json -Compress))}}
  for($i=0;$i -lt $Ipc.Pending.Count;$i++){if(& $Predicate $Ipc.Pending[$i]){$event=$Ipc.Pending[$i];$Ipc.Pending.RemoveAt($i);return $event}}
  if($ended){throw 'C3 session ended before stage evidence.'}
  Start-Sleep -Milliseconds 10
 }
 throw 'C3 stage evidence deadline expired.'
}
function Send-ChatpadC3SessionCommand {
 param($Ipc,[string]$Command)
 $Ipc.NextId++;$id=$Ipc.NextId
 $Ipc.Process.StandardInput.WriteLine(([ordered]@{id=$id;command=$Command}|ConvertTo-Json -Compress));$Ipc.Process.StandardInput.Flush()
 $ack=Wait-ChatpadC3SessionEvent $Ipc {param($e)$e.event -eq 'command' -and $e.id -eq $id -and $e.command -eq $Command}
 if(-not $ack.ok){throw "C3 command refused: $Command"};return $ack
}
function Test-ChatpadC3SessionReadiness {
 param($Ipc)
 $ready=Wait-ChatpadC3SessionEvent $Ipc {param($e)$e.event -eq 'session'}
 if(-not $ready.interfacesVerified -or -not $ready.readersStarted -or $ready.controllerInterface -ne 0 -or $ready.controllerIn -ne 129 -or $ready.controllerOut -ne 1 -or $ready.chatpadInterface -ne 2 -or $ready.chatpadIn -ne 132 -or $ready.physicalOutputsEnabled){throw 'Same-session exact interface/reader readiness contract failed.'}
 return $ready
}
function Assert-ChatpadC3ExtensionRestored {
 param($State,[object[]]$Inventory,$Material,$InstalledImage)
 if(-not $Material.NormalWindowsLoadExpected){throw 'Optional extension normal-Windows load qualification is BLOCKED.'}
 $inf=@($Material.Files | Where-Object {(Split-Path $_.Path -Leaf) -ieq 'ChatpadFilterExtension.inf'});$sys=@($Material.Files | Where-Object {(Split-Path $_.Path -Leaf) -ieq 'ChatpadFilter.sys'})
 if($inf.Count -ne 1 -or $sys.Count -ne 1 -or $Inventory.Count -ne 1 -or -not $Inventory[0].Known -or $Inventory[0].SHA256 -ine $inf[0].SHA256 -or $Inventory[0].Version -ne $Material.Version -or $Inventory[0].Selected -ne $true){throw 'Exact intended optional extension installed association/hash/version is not verified.'}
 if($InstalledImage.SHA256 -ine $sys[0].SHA256){throw 'Installed optional filter image differs from recovery package.'}
 $t=$State.Target
 if($t.Problem -ne 0 -or $t.Service -ine 'xusb22' -or $t.Inf -ine 'xusb22.inf' -or $t.Provider -cne 'Microsoft' -or (@($t.LowerFilters)-join '|') -ine 'vhf|ChatpadFilter' -or @($t.UpperFilters).Count -or @($State.ClassLowerFilters).Count -or @($State.ClassUpperFilters).Count -or ($State.Stack -join '|') -notmatch '(?i)ChatpadFilter' -or ($State.Stack -join '|') -notmatch '(?i)\bvhf\b' -or @($State.Services | Where-Object {$_.Name -ieq 'ChatpadFilter' -and $_.State -eq 'Running'}).Count -ne 1){throw 'Exact optional extension healthy Microsoft/filter stack not verified.'}
 return 'Exact intended extension association, package/image hashes, known filters and running healthy stack verified.'
}
function Invoke-ChatpadC3SessionRecovery {
 param([scriptblock]$Cleanup,[scriptblock]$Restore)
 $errorMessage=$null;try{& $Cleanup | Out-Null}catch{$errorMessage=$_.Exception.Message}
 # Restoration errors propagate; a successful restore never relabels a
 # failed cleanup as successful acceptance.
 $restored=& $Restore
 [pscustomobject]@{CleanupSucceeded=($null -eq $errorMessage);CleanupError=$errorMessage;Restored=$restored}
}
Export-ModuleMember -Function New-ChatpadC3SessionIpc,Receive-ChatpadC3SessionEvents,Wait-ChatpadC3SessionEvent,Send-ChatpadC3SessionCommand,Test-ChatpadC3SessionReadiness,Assert-ChatpadC3ExtensionRestored,Invoke-ChatpadC3SessionRecovery
