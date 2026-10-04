[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RunnerPath,
 [Parameter(Mandatory)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Crash evidence must remain in ignored artifacts.'}
if(Test-Path -LiteralPath $output){throw 'Use a fresh crash test output directory.'}
New-Item -ItemType Directory -Force -Path $output|Out-Null
$local=Join-Path $output 'localappdata';New-Item -ItemType Directory -Force -Path $local|Out-Null
$runner=(Resolve-Path -LiteralPath $RunnerPath).Path
$log=Join-Path $local 'ChatpadBridge/logs/bridge.log'
$marker=Join-Path $local 'ChatpadBridge/logs/session.active.json'
function Start-IdleRunner {
 $process=New-Object Diagnostics.Process
 $process.StartInfo.FileName=$runner;$process.StartInfo.Arguments='run --no-virtual-controller'
 $process.StartInfo.WorkingDirectory=Split-Path -Parent $runner;$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true
 $process.StartInfo.EnvironmentVariables['LOCALAPPDATA']=$local
 if(-not $process.Start()){throw 'Runner did not start.'}
 $process
}
function Wait-Log([string]$Pattern,[Diagnostics.Process]$Process){
 $deadline=[DateTime]::UtcNow.AddSeconds(12)
 while([DateTime]::UtcNow -lt $deadline){
  if($Process.HasExited){throw "Runner exited early: $($Process.ExitCode)"}
  if(Test-Path -LiteralPath $log){$text=[IO.File]::ReadAllText($log);if($text -match $Pattern){return $text}}
  Start-Sleep -Milliseconds 100
 }
 throw "Expected runtime marker missing: $Pattern"
}
$first=$null;$second=$null
try{
 $first=Start-IdleRunner
 $firstLog=Wait-Log 'state=WAITING_FOR_DEVICE' $first
 if(-not(Test-Path -LiteralPath $marker)){throw 'Active-session marker was not created.'}
 $first.Kill();if(-not $first.WaitForExit(5000)){throw 'Controlled idle process termination did not complete.'}
 if(-not(Test-Path -LiteralPath $marker)){throw 'Unclean process death did not preserve the marker.'}
 $second=Start-IdleRunner
 $secondLog=Wait-Log 'unclean_previous_session=true stale_keyboard_release=PASS' $second
 $second.Kill();if(-not $second.WaitForExit(5000)){throw 'Second controlled idle process termination did not complete.'}
 $report=[pscustomobject]@{Schema=1;Test='C4 idle kill and next-launch stale keyboard recovery';Pass=$true;StartWithoutWinUsb='WAITING_FOR_DEVICE';FirstProcessKilled=$true;UncleanMarkerPersisted=$true;NextLaunchReleasedMappedScanCodes=$true;SecondProcessKilled=$true;VirtualControllerCreated=$false;PnpMutation=$false;FirstLog=$firstLog;RecoveryLog=$secondLog}
 $report|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $output 'idle-crash-result.json') -Encoding utf8
 $report|ConvertTo-Json -Depth 4
}finally{
 foreach($process in @($first,$second)){if($process -and -not $process.HasExited){$process.Kill();$process.WaitForExit(5000)};if($process){$process.Dispose()}}
 $resolvedLogRoot=[IO.Path]::GetFullPath((Split-Path -Parent $marker))
 if(-not $resolvedLogRoot.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Marker cleanup path escaped test output.'}
 if(Test-Path -LiteralPath $marker){Remove-Item -LiteralPath $marker -Force}
}
