[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/tests.json'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
$results=[Collections.Generic.List[object]]::new()
function TestCase([string]$Name,[scriptblock]$Body){try{& $Body; $results.Add([pscustomobject]@{Name=$Name; Passed=$true})}catch{$results.Add([pscustomobject]@{Name=$Name; Passed=$false; Error=$_.Exception.Message})}}
function Require($Condition){if(-not $Condition){throw 'Assertion failed.'}}
function Reject([scriptblock]$Body){$rejected=$false;try{& $Body | Out-Null}catch{$rejected=$true}; Require $rejected}
function Fixture($Name){Get-Content -LiteralPath (Join-Path $PSScriptRoot "ChatpadBinding/fixtures/$Name.json") -Raw | ConvertFrom-Json}
function Baseline {
 [pscustomobject]@{Schema=1;State=(Fixture xbox);Files=@(
  [pscustomobject]@{Name='xusb22.inf';SHA256=('A'*64);RelativePath='restore/xusb22.inf'},
  [pscustomobject]@{Name='ChatpadFilterExtension.inf';SHA256='FE35416537D432CDB37B0B9C967298F86B2EE636F02937DE3AAB0F1E91FFB274';RelativePath='restore/ChatpadFilterExtension.inf'},
  [pscustomobject]@{Name='ChatpadFilter.sys';SHA256='16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0';RelativePath='restore/ChatpadFilter.sys'},
  [pscustomobject]@{Name='ChatpadFilterExtension.cat';SHA256='6D9724DF174383F37EB9DFC13C2A096BD067BD98F037F7C0A29F8292DD8F0732';RelativePath='restore/ChatpadFilterExtension.cat'}
 )}
}
TestCase 'Xbox fixture recognized' {Require ((Get-ChatpadRecognizedState (Fixture xbox)) -eq 'Xbox')}
TestCase 'WinUSB fixture recognized' {Require ((Get-ChatpadRecognizedState (Fixture winusb)) -eq 'WinUSB')}
TestCase 'WinUSB missing application interface rejected' {$s=Fixture winusb;$s.Interfaces=@();Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'Problem52 is not healthy binding' {$s=Fixture xbox;$s.Target.Problem=52;Require ((Get-ChatpadRecognizedState $s) -eq 'Problem')}
TestCase 'NonMicrosoft xbox rejected' {$s=Fixture xbox;$s.Target.Provider='Other';Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'WinUSB wrong provider rejected' {$s=Fixture winusb;$s.Target.Provider='Other';Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'WinUSB wrong model rejected' {$s=Fixture winusb;$s.Target.Section='Other';Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'WinUSB wrong version rejected' {$s=Fixture winusb;$s.Target.Version='0.0.2.0';Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
foreach($filter in @('ChatpadFilter','vhf','Unknown')){
 $local=$filter
 TestCase "WinUSB device lower filter $filter rejected" {$s=Fixture winusb;$s.Target.LowerFilters=@($local);Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
}
TestCase 'WinUSB device upper filter rejected' {$s=Fixture winusb;$s.Target.UpperFilters=@('Other');Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'WinUSB class lower filter rejected' {$s=Fixture winusb;$s.ClassLowerFilters=@('Other');Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'WinUSB contaminated stack rejected' {$s=Fixture winusb;$s.Stack+=@('ChatpadFilter');Require ((Get-ChatpadRecognizedState $s) -eq 'Unexpected')}
TestCase 'One exact physical target accepted' {$s=Fixture xbox;Require ((Select-ChatpadTarget @($s.Target)).InstanceId -eq $s.Target.InstanceId)}
TestCase 'Missing physical target rejected' {Reject {Select-ChatpadTarget @()}}
TestCase 'Two physical targets rejected without selector' {$a=(Fixture xbox).Target;$b=(Fixture xbox).Target;$b.InstanceId='USB\VID_045E&PID_028E\SYNTHETIC-B';Reject {Select-ChatpadTarget @($a,$b)}}
TestCase 'Two physical targets allow exact selector' {$a=(Fixture xbox).Target;$b=(Fixture xbox).Target;$b.InstanceId='USB\VID_045E&PID_028E\SYNTHETIC-B';Require ((Select-ChatpadTarget @($a,$b) $b.InstanceId).InstanceId -eq $b.InstanceId)}
TestCase 'MI_02 child rejected' {$s=Fixture xbox;$s.Target.InstanceId='USB\VID_045E&PID_028E&MI_02\SYNTHETIC';Reject {Select-ChatpadTarget @($s.Target)}}
TestCase 'Other VID/PID rejected' {$s=Fixture xbox;$s.Target.InstanceId='USB\VID_045E&PID_0291\SYNTHETIC';Reject {Select-ChatpadTarget @($s.Target)}}
TestCase 'Spoofed hardware array rejected' {$s=Fixture xbox;$s.Target.HardwareIds=@('USB\VID_045E&PID_0291');Reject {Select-ChatpadTarget @($s.Target)}}
TestCase 'Reviewed rollback manifest accepted' {Assert-ChatpadBaselineManifest (Baseline)}
TestCase 'Tampered extension hash rejected' {$b=Baseline;$b.Files[2].SHA256='B'*64;Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Missing extension catalog rejected' {$b=Baseline;$b.Files=@($b.Files | Where-Object Name -NE 'ChatpadFilterExtension.cat');Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Duplicate extension file rejected' {$b=Baseline;$b.Files+=@($b.Files[2]);Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Wrong Microsoft version baseline rejected' {$b=Baseline;$b.State.Target.Version='10.0.0.0';Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Baseline unexpected device filters rejected' {$b=Baseline;$b.State.Target.LowerFilters+=@('Other');Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Baseline missing extension rejected' {$b=Baseline;$b.State.Extensions=@();Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Unhealthy rollback baseline rejected' {$b=Baseline;$b.State.Target.Problem=52;Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'WinUSB cannot become Xbox rollback baseline' {$b=Baseline;$b.State=Fixture winusb;Reject {Assert-ChatpadBaselineManifest $b}}
TestCase 'Missing material rejected' {Reject {Assert-ChatpadBaseline (Baseline) (Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/nonexistent/baseline.json')}}
TestCase 'Exact fixture file hash accepted; changed byte rejected' {
 $dir=Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/hash-fixture'; New-Item -ItemType Directory -Path $dir -Force | Out-Null
 $path=Join-Path $dir 'material.txt'; [IO.File]::WriteAllText($path,'synthetic restore fixture')
 $file=[pscustomobject]@{RelativePath='material.txt';SHA256=(Get-FileHash -LiteralPath $path).Hash}
 Assert-ChatpadBaselineFiles @($file) (Join-Path $dir 'baseline.json')
 [IO.File]::WriteAllText($path,'synthetic changed byte'); Reject {Assert-ChatpadBaselineFiles @($file) (Join-Path $dir 'baseline.json')}
}
TestCase 'Traversal restoration material rejected' {$f=[pscustomobject]@{RelativePath='../material.txt';SHA256='A'*64};Reject {Assert-ChatpadBaselineFiles @($f) (Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/hash-fixture/baseline.json')}}
TestCase 'No execution authorization rejected before live API' {Reject {Assert-ChatpadExecutionGate '' '' '' ''}}
TestCase 'C2 authorization marker rejected' {Reject {Assert-ChatpadExecutionGate 'TASK-8L-C2' '' '' ''}}
TestCase 'Fixture execution rejected even C3 marker' {Reject {Assert-ChatpadExecutionGate 'TASK-8L-C3-EXACT-DEVICE-BINDING' '' '' 'fixture.json'}}
TestCase 'Native helper compiles only, never invoked' {if(-not ('Chatpad.Binding.ExactDevice' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadBinding/ExactDevice.cs')};Require ($null -ne ('Chatpad.Binding.ExactDevice' -as [type]))}
TestCase 'Narrow INF exactly one hardware model' {$t=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadWholeDeviceWinUSB.inf') -Raw;Require ([regex]::Matches($t,'USB\\VID_045E&PID_028E').Count -eq 1);Require ($t -notmatch '(?im)CopyFiles|ServiceBinary|CoInstaller|LowerFilters|UpperFilters|AddFilter|MI_02');Require ($t.Contains('{B6A5D05E-7E18-4DF1-8E47-12F072DE2C36}'))}
$out=[IO.Path]::GetFullPath($OutputPath);$allowed=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $out.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Test report must be under ignored artifacts.'}
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
$failed=@($results | Where-Object {-not $_.Passed})
[pscustomobject]@{Total=$results.Count;Passed=$results.Count-$failed.Count;Failed=$failed.Count;MutatingCalls=0;Results=@($results)} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $out -Encoding utf8
$failed | Format-Table -AutoSize
Write-Output "Binding offline tests: $($results.Count-$failed.Count)/$($results.Count) PASS; mutations=0"
if($failed.Count){exit 1}else{exit 0}
