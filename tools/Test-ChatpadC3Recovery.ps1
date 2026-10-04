[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/binding/recovery-tests.json'))
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
$checks=[Collections.Generic.List[object]]::new()
function Check($Name,[scriptblock]$Body){try{& $Body;$checks.Add([pscustomobject]@{Name=$Name;Passed=$true})}catch{$checks.Add([pscustomobject]@{Name=$Name;Passed=$false;Error=$_.Exception.Message})}}
function Require($Value){if(-not $Value){throw 'Assertion failed'}}
function Reject([scriptblock]$Body){$bad=$false;try{& $Body | Out-Null}catch{$bad=$true};Require $bad}
function FileRecord($Path){[pscustomobject]@{Path=$Path;SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}}
$root=Join-Path $PSScriptRoot ('../artifacts/task-8lc2r1/binding/recovery-fixtures/'+[Guid]::NewGuid().ToString('N'))
$source=Join-Path $root 'original';New-Item -ItemType Directory $source -Force | Out-Null
$inf=Join-Path $source 'xusb22.inf'
[IO.File]::WriteAllText($inf,"[Version]`nProvider=%MSFT%`nDriverVer=08/24/2026,10.0.26100.9278`n[Models]`nX=CC_Install, USB\VID_045E&PID_028E`n[Services]`nAddService=xusb22,2,CC_XUSB22_Service`n[Strings]`nMSFT=`"Microsoft`"`n")
$kernelDirectory=Join-Path $root 'original-driverstore';New-Item -ItemType Directory $kernelDirectory | Out-Null
$sys=Join-Path $kernelDirectory 'xusb22.sys';[IO.File]::WriteAllText($sys,'offline unsigned fixture, never installed')
$nested=Join-Path $source 'profiles/controller.txt';New-Item -ItemType Directory (Split-Path $nested -Parent) | Out-Null;[IO.File]::WriteAllText($nested,'nested package fixture')
$extension=Join-Path $source 'extension';New-Item -ItemType Directory $extension | Out-Null
$retained=Join-Path $PSScriptRoot '../artifacts/task-8k-legacy-layers-configuration-package/final'
$extensionRecords=@();foreach($name in @('ChatpadFilterExtension.inf','ChatpadFilterExtension.cat','ChatpadFilter.sys')){Copy-Item -LiteralPath (Join-Path $retained $name) -Destination (Join-Path $extension $name);$extensionRecords+=FileRecord (Join-Path $extension $name)}
$readiness=[pscustomobject]@{
 Microsoft=[pscustomobject]@{InfPath=$inf;InfSHA256=(Get-FileHash $inf).Hash;Provider='Microsoft';Section='CC_Install';Version='10.0.26100.9278';PackageFiles=@((FileRecord $inf),(FileRecord $sys),(FileRecord $nested));SourceSignatureVerified=$true}
 ExtensionRestore=[pscustomobject]@{InfPath=(Join-Path $extension 'ChatpadFilterExtension.inf');Version='1.0.14.0';Files=$extensionRecords;NormalWindowsLoadExpected=$true}
 Files=@([pscustomobject]@{Role='WinUsbInf';Path='unused-for-offline-restore-plan';SHA256=('a'*64)})
}
$state=[pscustomobject]@{Target=[pscustomobject]@{InstanceId='offline';ContainerId='offline'}}
$directory=Join-Path $root 'snapshot'
$baseline=Save-ChatpadC3Baseline $state @() $readiness $directory
Check 'Recovery readiness points to copied Microsoft INF and package' {Require ($baseline.Readiness.Microsoft.InfPath -ne $inf);Require ((Split-Path $baseline.Readiness.Microsoft.InfPath -Parent) -eq (Split-Path $baseline.Readiness.Microsoft.PackageFiles[1].Path -Parent));Require (Test-Path -LiteralPath $baseline.Readiness.Microsoft.InfPath)}
Check 'Optional extension INF CAT SYS remain adjacent and copied' {$e=$baseline.Readiness.ExtensionRestore;Require ($e.InfPath -ne $readiness.ExtensionRestore.InfPath);Require (@($e.Files | ForEach-Object {Split-Path $_.Path -Parent} | Select-Object -Unique).Count -eq 1);Require ($e.Files[0].Path -like '*source*extension*')}
Check 'Nested Microsoft source topology retained' {Require ($baseline.Readiness.Microsoft.PackageFiles[2].Path -like '*microsoft*profiles*controller.txt')}
Check 'Input readiness remains unchanged and originals recorded' {Require ($readiness.Microsoft.InfPath -eq $inf);Require ($baseline.Readiness.Microsoft.OriginalInfPath -eq [IO.Path]::GetFullPath($inf));Require ($baseline.Copies.Count -eq 6);foreach($copy in $baseline.Copies){Require (Test-Path -LiteralPath $copy.LocalPath);Require ($copy.OriginalPath -ne $copy.LocalPath)}}
# These paths are exact disposable files created above under ignored artifacts.
[IO.File]::WriteAllText($inf,'original changed after capture')
Remove-Item -LiteralPath $sys,$nested
foreach($record in $extensionRecords){Remove-Item -LiteralPath $record.Path}
Check 'Copied Microsoft restore remains valid after original drift and removal' {Assert-ChatpadRestorable $baseline.Readiness;$plan=New-ChatpadRestorePlan $state.Target $baseline.Readiness;Require ($plan.Microsoft.InfPath -eq $baseline.Readiness.Microsoft.InfPath);Require $plan.IndependentOfPocAndBackend}
Check 'Copied optional restore remains valid after original removal' {Assert-ChatpadRestorable $baseline.Readiness -RestoreExtension;$plan=New-ChatpadRestorePlan $state.Target $baseline.Readiness -RestoreExtension;Require $plan.OptionalExtension}
Check 'Persisted baseline reload independently restores from snapshot' {$saved=Get-Content -LiteralPath (Join-Path $directory 'baseline.json') -Raw | ConvertFrom-Json;Assert-ChatpadRestorable $saved.Readiness -RestoreExtension;Require ($saved.Readiness.Microsoft.InfPath -eq $baseline.Readiness.Microsoft.InfPath)}
Check 'Binding action plan consumes snapshot recovery source' {$action=Invoke-ChatpadC3BindingAction -Operation Restore -Baseline $baseline;Require (-not $action.Execute);Require ($action.RestorePlan.Microsoft.InfPath -eq $baseline.Readiness.Microsoft.InfPath)}
Check 'Tampered copied Microsoft INF rejected' {$path=$baseline.Readiness.Microsoft.InfPath;$bytes=[IO.File]::ReadAllBytes($path);try{[IO.File]::WriteAllText($path,'tampered');Reject {Assert-ChatpadRestorable $baseline.Readiness}}finally{[IO.File]::WriteAllBytes($path,$bytes)}}
Check 'Tampered copied extension SYS rejected' {$path=@($baseline.Readiness.ExtensionRestore.Files | Where-Object {(Split-Path $_.Path -Leaf) -eq 'ChatpadFilter.sys'})[0].Path;$bytes=[IO.File]::ReadAllBytes($path);try{[IO.File]::WriteAllText($path,'tampered');Reject {Assert-ChatpadRestorable $baseline.Readiness -RestoreExtension}}finally{[IO.File]::WriteAllBytes($path,$bytes)}}
Check 'Snapshot recapture refuses overwrite' {Reject {Save-ChatpadC3Baseline $state @() $baseline.Readiness $directory}}
Check 'Microsoft-only readiness snapshots without optional extension' {$r=$baseline.Readiness | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$r.PSObject.Properties.Remove('ExtensionRestore');$saved=Save-ChatpadC3Baseline $state @() $r (Join-Path $root 'microsoft-only');Assert-ChatpadRestorable $saved.Readiness;Require ($saved.Copies.Count -eq 3)}
Check 'INF absent from package records is retained as recovery member' {$r=$baseline.Readiness | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$r.PSObject.Properties.Remove('ExtensionRestore');$r.Microsoft.PackageFiles=@($r.Microsoft.PackageFiles | Where-Object {(Split-Path $_.Path -Leaf) -eq 'xusb22.sys'});$saved=Save-ChatpadC3Baseline $state @() $r (Join-Path $root 'inf-added');Assert-ChatpadRestorable $saved.Readiness;Require ($saved.Copies.Count -eq 2);Require (@($saved.Readiness.Microsoft.PackageFiles | Where-Object {(Split-Path $_.Path -Leaf) -eq 'xusb22.inf'}).Count -eq 1)}
Check 'Ambiguous package member destination refuses capture' {$r=$baseline.Readiness | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$other=Join-Path $root 'collision/xusb22.sys';New-Item -ItemType Directory (Split-Path $other -Parent) | Out-Null;[IO.File]::WriteAllText($other,'different file with same member name');$r.Microsoft.PackageFiles+=FileRecord $other;Reject {Save-ChatpadC3Baseline $state @() $r (Join-Path $root 'collision-snapshot')}}
function RecoveryRemovalPlan {param($Packages,$Saved,[object[]]$Planned=@());& (Get-Module C3Execution) {param($live,$captured,$original) Get-C3ExtensionRemovalPlan -Planned @($original) -Live @($live) -RecoveryBaseline $captured} $Packages $Saved $Planned}
$reinstalled=Read-ChatpadExtensionInf $baseline.Readiness.ExtensionRestore.InfPath 'oem777.inf'
Check 'Recovery baseline excludes optional reinstall authorization by default' {Require ($baseline.OptionalExtensionRestoreStarted -ceq $false)}
Check 'New optional OEM removal refused before optional install began' {Reject {RecoveryRemovalPlan @($reinstalled) $baseline}}
$optional=$baseline | ConvertTo-Json -Depth 20 | ConvertFrom-Json
$optional | Add-Member NoteProperty OptionalExtensionRestoreStarted $true -Force
Check 'Authorized optional snapshot recovered with newly assigned OEM' {$plan=@(RecoveryRemovalPlan @($reinstalled) $optional);Require ($plan.Count -eq 1);Require ($plan[0].PublishedInf -eq 'oem777.inf');Require ($plan[0].SHA256 -eq $reinstalled.SHA256)}
Check 'Authorized optional recovery refuses other known version' {$wrong=$reinstalled | ConvertTo-Json -Depth 5 | ConvertFrom-Json;$wrong.Version='1.0.13.0';Reject {RecoveryRemovalPlan @($wrong) $optional}}
Check 'Authorized optional recovery refuses changed INF hash' {$wrong=$reinstalled | ConvertTo-Json -Depth 5 | ConvertFrom-Json;$wrong.SHA256='b'*64;Reject {RecoveryRemovalPlan @($wrong) $optional}}
Check 'Authorized optional recovery refuses unknown identity' {$wrong=$reinstalled | ConvertTo-Json -Depth 5 | ConvertFrom-Json;$wrong.Known=$false;Reject {RecoveryRemovalPlan @($wrong) $optional}}
Check 'Authorized optional recovery refuses ambiguous multiple new OEMs' {$other=$reinstalled | ConvertTo-Json -Depth 5 | ConvertFrom-Json;$other.PublishedInf='oem778.inf';Reject {RecoveryRemovalPlan @($reinstalled,$other) $optional}}
Check 'Authorized optional recovery replaces reused OEM address with exact new identity' {$prior=$reinstalled | ConvertTo-Json -Depth 5 | ConvertFrom-Json;$prior.Version='1.0.13.0';$prior.SHA256='c'*64;$plan=@(RecoveryRemovalPlan @($reinstalled) $optional @($prior));Require ($plan.Count -eq 1);Require ($plan[0].SHA256 -eq $reinstalled.SHA256)}
Check 'Optional recovery refuses string authorization token' {$bad=$optional | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$bad.OptionalExtensionRestoreStarted='true';Reject {RecoveryRemovalPlan @($reinstalled) $bad}}
Check 'Optional recovery refuses unqualified normal Windows extension' {$bad=$optional | ConvertTo-Json -Depth 20 | ConvertFrom-Json;$bad.Readiness.ExtensionRestore.NormalWindowsLoadExpected=$false;Reject {RecoveryRemovalPlan @($reinstalled) $bad}}
function PublishedRemovalDisposition($planned,$actual,$experiment,[bool]$recovering){& (Get-Module C3Execution) {param($p,$a,$e,$r) Get-C3PublishedRemovalDisposition $p $a $e $r} $planned $actual $experiment $recovering}
Check 'Captured extension hash retains exact removal' {Require ((PublishedRemovalDisposition ('A'*64) ('A'*64) ('B'*64) $false) -eq 'CapturedExtension')}
Check 'Recovery permits OEM address reused by exact experiment bytes' {Require ((PublishedRemovalDisposition ('A'*64) ('B'*64) ('B'*64) $true) -eq 'ExperimentReusedAddress')}
Check 'Exclusion refuses address reused by experiment' {Reject {PublishedRemovalDisposition ('A'*64) ('B'*64) ('B'*64) $false}}
Check 'Recovery refuses unknown bytes at reused OEM address' {Reject {PublishedRemovalDisposition ('A'*64) ('C'*64) ('B'*64) $true}}
New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force | Out-Null
$fail=@($checks | Where-Object {-not $_.Passed});[pscustomobject]@{Total=$checks.Count;Passed=$checks.Count-$fail.Count;Failed=$fail.Count;LiveMutations=0;Results=@($checks)} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath
$fail | Format-Table -AutoSize
Write-Output "C3 recovery tests: $($checks.Count-$fail.Count)/$($checks.Count) PASS; live mutations=0"
if($fail.Count){exit 1}
