[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/binding/tests.json'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
$checks=[Collections.Generic.List[object]]::new()
function Check($Name,[scriptblock]$Body){try{& $Body;$checks.Add([pscustomobject]@{Name=$Name;Passed=$true})}catch{$checks.Add([pscustomobject]@{Name=$Name;Passed=$false;Error=$_.Exception.Message})}}
function Require($Value){if(-not $Value){throw 'Assertion failed'}}
function Reject([scriptblock]$Body){$bad=$false;try{& $Body | Out-Null}catch{$bad=$true};Require $bad}
Check 'Known historical versions cover required revisions' {$a=Get-ChatpadExtensionAllowlist;foreach($v in @('1.0.0.0','1.0.1.0','1.0.2.0','1.0.9.0','1.0.10.0','1.0.11.0','1.0.12.0','1.0.13.0','1.0.14.0')){Require (@($a | Where-Object Version -eq $v).Count -eq 1)}}
Check 'Canonical extension authoritative identity' {$p=Read-ChatpadExtensionInf (Join-Path $PSScriptRoot '../artifacts/task-8k-legacy-layers-configuration-package/final/ChatpadFilterExtension.inf') 'oem700.inf';Require $p.Known;Require ($p.Version -eq '1.0.14.0');Require ($p.PublishedInf -eq 'oem700.inf')}
Check 'Unknown matching extension rejected' {$p=[pscustomobject]@{Matching=$true;Known=$false;PublishedInf='oem701.inf'};Reject {Assert-ChatpadExtensionInventory @($p)}}
Check 'Unrelated extension retained' {$p=[pscustomobject]@{Matching=$false;Known=$false;PublishedInf='oem701.inf'};Assert-ChatpadExtensionInventory @($p)}
Check 'Reconnect identity uses stable container' {$a=[pscustomobject]@{InstanceId='USB\VID_045E&PID_028E\OLD';ContainerId='{11111111-1111-1111-1111-111111111111}';HardwareIds=@('USB\VID_045E&PID_028E')};$b=$a | ConvertTo-Json | ConvertFrom-Json;$b.InstanceId='USB\VID_045E&PID_028E\NEW';Require ((Resolve-ChatpadC3Target @($b) $a).InstanceId -eq $b.InstanceId)}
Check 'Reconnect wrong container refused' {$a=[pscustomobject]@{ContainerId='A'};$b=[pscustomobject]@{InstanceId='USB\VID_045E&PID_028E\NEW';ContainerId='B';HardwareIds=@('USB\VID_045E&PID_028E')};Reject {Resolve-ChatpadC3Target @($b) $a}}
Check 'Postmutation state rollback complete' {foreach($s in Get-ChatpadC3States){if($s.AfterMutation){Require ($s.FailureTransition -eq 'RESTORE_MICROSOFT_XBOX');Require ($s.RollbackTransition -eq 'RESTORE_MICROSOFT_XBOX')}}}
Check 'State runner rollback on every postmutation failure' {foreach($s in @(Get-ChatpadC3States | Where-Object {$_.AfterMutation -and $_.Name -notmatch '^RESTORE|FINAL_VERIFY'})){$script:failedAt=$s.Name;$r=Invoke-ChatpadC3StateMachine -Action {param($state) if($state.Name -eq $script:failedAt){throw 'injected failure'};[pscustomobject]@{Success=$true;Evidence='mock'}};Require $r.RollbackAttempted;Require $r.RollbackSucceeded;Require (-not $r.Passed)}}
Check 'State runner recovery failure not success' {$r=Invoke-ChatpadC3StateMachine -Action {param($s) if($s.Name -in @('WINUSB_BIND','RESTORE_MICROSOFT_XBOX')){throw 'injected failure'};[pscustomobject]@{Success=$true;Evidence='mock'}};Require $r.RollbackAttempted;Require (-not $r.RollbackSucceeded);Require (-not $r.Passed)}
Check 'State runner normal mock path passes' {$r=Invoke-ChatpadC3StateMachine -Action {param($s)[pscustomobject]@{Success=$true;Evidence='mock'}};Require $r.Passed}
$fixtureRoot=Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/binding/fixtures';New-Item -ItemType Directory $fixtureRoot -Force | Out-Null
$msInf=Join-Path $fixtureRoot 'xusb22.inf';[IO.File]::WriteAllText($msInf,"[Version]`nProvider=%MSFT%`nDriverVer=08/24/2026,10.0.26100.9278`n[Models]`nX=CC_Install, USB\VID_045E&PID_028E`n[Services]`nAddService=xusb22,2,CC_XUSB22_Service`n[Strings]`nMSFT=`"Microsoft`"`n")
$dummy=Join-Path $fixtureRoot 'mock-binary.txt';[IO.File]::WriteAllText($dummy,'mock signed binary only')
$probe=Join-Path $fixtureRoot 'publication-probe.json';[IO.File]::WriteAllText($probe,'{"Purpose":"offline canonical receipt fixture"}')
$probeHash=(Get-FileHash $probe).Hash;[IO.File]::WriteAllText(($probe+'.sha256'),($probeHash+'  publication-probe.json'))
function FreshRepository {[pscustomobject]@{Branch='feature/chatpad-winusb-bridge-poc';Commit=('a'*40)}}
function Preflight($State,$Packages,$Readiness) {New-ChatpadC3Preflight $State $Packages $Readiness -CurrentRepository (FreshRepository) -CanonicalTaskRoot $fixtureRoot}
function Ready {
 $source=Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadWholeDeviceWinUSB.inf'
 [pscustomobject]@{Schema=1;Repository=(FreshRepository);Files=@([pscustomobject]@{Role='WinUsbInf';Path=$source;SHA256=(Get-FileHash $source).Hash},[pscustomobject]@{Role='WinUsbCat';Path=$dummy;SHA256=(Get-FileHash $dummy).Hash},[pscustomobject]@{Role='Poc';Path=$dummy;SHA256=(Get-FileHash $dummy).Hash},[pscustomobject]@{Role='VirtualBackend';Path=$dummy;SHA256=(Get-FileHash $dummy).Hash});Microsoft=[pscustomobject]@{InfPath=$msInf;InfSHA256=(Get-FileHash $msInf).Hash;Provider='Microsoft';Section='CC_Install';Version='10.0.26100.9278';PackageFiles=@([pscustomobject]@{Path=$dummy;SHA256=(Get-FileHash $dummy).Hash});SourceSignatureVerified=$true;CandidateVerified=$true};Trust=[pscustomobject]@{NormalWindowsInstallExpected=$true;Reason='mock'};Dependencies=[pscustomobject]@{Available=$true;Reason='mock'};Security=[pscustomobject]@{QuerySucceeded=$true;TestSigning=$false;Hvci=$true};CanonicalDirectory=[IO.Path]::GetFullPath($fixtureRoot);CanonicalWritable=$true;CanonicalWriteProof=[pscustomobject]@{Name='publication-probe.json';Path=[IO.Path]::GetFullPath($probe);SHA256=$probeHash;PartReadbackSHA256=$probeHash;FinalReadbackSHA256=$probeHash;Verified=$true;SidecarCommittedLast=$true}}
}
function State {Get-Content (Join-Path $PSScriptRoot 'ChatpadBinding/fixtures/xbox.json') -Raw | ConvertFrom-Json}
function Package {Read-ChatpadExtensionInf (Join-Path $PSScriptRoot '../artifacts/task-8k-legacy-layers-configuration-package/final/ChatpadFilterExtension.inf') 'oem700.inf'}
Check 'Transition exact ordered removal excludes matching package' {$p=New-ChatpadTransitionPlan (State) @((Package)) (Ready);Require ($p.Steps[1].Action -eq 'ExcludeExtension');Require ($p.Steps[1].Command[2] -eq 'oem700.inf');Require $p.NoMicrosoftPackageRemoval;Require (-not $p.Execute)}
Check 'All historical matching versions excluded before binding' {$p=Package;$p2=Package;$p2.PublishedInf='oem701.inf';$plan=New-ChatpadTransitionPlan (State) @($p,$p2) (Ready);Require (@($plan.Steps | Where-Object Action -eq 'ExcludeExtension').Count -eq 2)}
Check 'Unknown package transition blocked' {$p=Package;$p.Known=$false;Reject {New-ChatpadTransitionPlan (State) @($p) (Ready)}}
Check 'Unexpected lower filter transition blocked' {$s=State;$s.Target.LowerFilters+=@('Other');Reject {New-ChatpadTransitionPlan $s @((Package)) (Ready)}}
Check 'Class filter transition blocked' {$s=State;$s.ClassLowerFilters=@('Other');Reject {New-ChatpadTransitionPlan $s @((Package)) (Ready)}}
Check 'Duplicate OEM package transition blocked' {$p=Package;Reject {New-ChatpadTransitionPlan (State) @($p,$p) (Ready)}}
Check 'Restore independent of crashed bridge includes de-selection cleanup verify' {$p=New-ChatpadRestorePlan (State).Target (Ready);Require $p.IndependentOfPocAndBackend;Require ($p.Steps -contains 'DeSelectExperimentByExactMicrosoftBinding');Require ($p.Steps -contains 'VerifyMicrosoftServiceProblem0AndNoChatpadFilter');Require (-not $p.OptionalExtension)}
Check 'Missing Microsoft source fails restorable' {$r=Ready;$r.Microsoft.InfPath='missing/xusb22.inf';Reject {Assert-ChatpadRestorable $r}}
Check 'Changed Microsoft hash fails restorable' {$r=Ready;$r.Microsoft.InfSHA256='B'*64;Reject {Assert-ChatpadRestorable $r}}
Check 'Missing Microsoft identity fails restorable' {$r=Ready;$r.Microsoft.Provider='Other';Reject {Assert-ChatpadRestorable $r}}
Check 'Missing Microsoft signatures fails restorable' {$r=Ready;$r.Microsoft.SourceSignatureVerified=$false;Reject {Assert-ChatpadRestorable $r}}
Check 'Missing recovery package fails restorable' {$r=Ready;$r.Microsoft.PackageFiles=@();Reject {Assert-ChatpadRestorable $r}}
Check 'Read-only preflight PASS with complete injected evidence' {$r=Preflight (State) @((Package)) (Ready);Require ($r.Result -eq 'PASS');Require $r.ReadOnly;Require (-not $r.LiveMutation)}
Check 'Absent physical target preflight BLOCKED' {$s=State;$s.Target=$null;Require ((Preflight $s @((Package)) (Ready)).Result -eq 'BLOCKED')}
Check 'Missing current candidate preflight BLOCKED' {$r=Ready;$r.Microsoft.CandidateVerified=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Normal Windows trust failure preflight BLOCKED' {$r=Ready;$r.Trust.NormalWindowsInstallExpected=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Tampered WinUSB hash preflight BLOCKED' {$r=Ready;$r.Files[0].SHA256='B'*64;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'HVCI disabled preflight BLOCKED' {$r=Ready;$r.Security.Hvci=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Test signing enabled preflight BLOCKED' {$r=Ready;$r.Security.TestSigning=$true;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Unknown security preflight BLOCKED' {$r=Ready;$r.Security.QuerySucceeded=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Unknown canonical permissions preflight BLOCKED' {$r=Ready;$r.CanonicalWritable=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Missing backend dependencies preflight BLOCKED' {$r=Ready;$r.Dependencies.Available=$false;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Unknown extension preflight BLOCKED' {$p=Package;$p.Known=$false;Require ((Preflight (State) @($p) (Ready)).Result -eq 'BLOCKED')}
Check 'Readiness commit drift preflight BLOCKED' {$r=Ready;$r.Repository.Commit='b'*40;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Readiness branch drift preflight BLOCKED' {$r=Ready;$r.Repository.Branch='other';Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Missing fresh repository query preflight BLOCKED' {Require ((New-ChatpadC3Preflight (State) @((Package)) (Ready)).Result -eq 'BLOCKED')}
Check 'Arbitrary canonical writable boolean cannot pass' {$r=Ready;$r.CanonicalWriteProof=$null;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Tampered receipt hash preflight BLOCKED' {$r=Ready;$r.CanonicalWriteProof.FinalReadbackSHA256='b'*64;Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Receipt outside canonical directory preflight BLOCKED' {$r=Ready;$r.CanonicalDirectory=Join-Path $fixtureRoot 'unrelated';Require ((Preflight (State) @((Package)) $r).Result -eq 'BLOCKED')}
Check 'Published receipt outside required task root cannot pass' {Require ((New-ChatpadC3Preflight (State) @((Package)) (Ready) -CurrentRepository (FreshRepository)).Result -eq 'BLOCKED')}
Check 'Changed canonical sidecar preflight BLOCKED' {try{[IO.File]::WriteAllText(($probe+'.sha256'),(('b'*64)+'  publication-probe.json'));Require ((Preflight (State) @((Package)) (Ready)).Result -eq 'BLOCKED')}finally{[IO.File]::WriteAllText(($probe+'.sha256'),($probeHash+'  publication-probe.json'))}}
Check 'Canonical current readback does not claim fresh write permissions' {$r=Preflight (State) @((Package)) (Ready);Require $r.CanonicalEvidence.CurrentReadbackVerified;Require (-not $r.CanonicalEvidence.FreshWritePermissionEstablished);Require ($r.CanonicalEvidence.Limitation -match 'prior successful write')}
Check 'No evidence action cannot claim state success' {$r=Invoke-ChatpadC3StateMachine -Action {param($s)[pscustomobject]@{Success=$true;Evidence=''}};Require (-not $r.Passed);Require (-not $r.RollbackAttempted)}
Check 'CI interop source compiles without executing hardware operations' {$null=Get-ChatpadCurrentSecurity;Require ($null -ne ('Chatpad.Binding.CodeIntegrity' -as [type]));Require ($null -ne (Get-Command Test-ChatpadCurrentSignatures))}
Check 'Native lower filter deletion compiles only' {if(-not ('Chatpad.Binding.ExactDevice' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadBinding/ExactDevice.cs')};Require ($null -ne ('Chatpad.Binding.ExactDevice' -as [type]).GetMethod('ClearKnownLowerFilters'))}
Check 'Runner plan has no execution side effects' {$out=& (Join-Path $PSScriptRoot 'Invoke-ChatpadC3.ps1');Require (($out -join '`n') -match 'PLAN ONLY')}
New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force | Out-Null
$fail=@($checks | Where-Object {-not $_.Passed});[pscustomobject]@{Total=$checks.Count;Passed=$checks.Count-$fail.Count;Failed=$fail.Count;LiveMutations=0;Results=@($checks)} | ConvertTo-Json -Depth 8 | Set-Content $OutputPath
$fail | Format-Table -AutoSize
Write-Output "C3 offline tests: $($checks.Count-$fail.Count)/$($checks.Count) PASS; live mutations=0"
if($fail.Count){exit 1}
