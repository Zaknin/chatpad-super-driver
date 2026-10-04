Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding.psm1')
Import-Module (Join-Path $PSScriptRoot 'C3Planning.psm1')
function Invoke-C3Process {
 param([string]$File,[string[]]$Arguments,[int]$Seconds=45)
 $p=New-Object Diagnostics.Process;$p.StartInfo.FileName=$File;$p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
 # PowerShell 5.1 has no ArgumentList. Escape using the Windows argv quoting
 # contract, never shell interpolation or Invoke-Expression.
 $quoted=@($Arguments | ForEach-Object {'"'+([regex]::Replace([regex]::Replace($_,'(\\*)"','$1$1\"'),'(\\+)$','$1$1'))+'"'})
 $p.StartInfo.Arguments=$quoted -join ' '
 try{if(-not $p.Start()){throw 'Process did not start.'};if(-not $p.WaitForExit($Seconds*1000)){$p.Kill();$p.WaitForExit();throw 'Bounded command timed out; rollback required.'};if($p.ExitCode -ne 0){throw "Command failed/reboot required: $File exit=$($p.ExitCode); no reboot."}}finally{$p.Dispose()}
}
function Get-C3Target($Captured){$s=Get-ChatpadBindingState;Resolve-ChatpadC3Target @($s.Target) $Captured | Out-Null;return $s}
function Assert-C3Elevation {if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Future C3 mutation requires an elevated human-started command.'}}
function Get-C3ExtensionRemovalPlan {
 param([object[]]$Planned,[object[]]$Live,$RecoveryBaseline=$null)
 Assert-ChatpadExtensionInventory $Live
 $remove=@($Planned);$unexpected=@()
 foreach($p in $Live){$same=@($Planned | Where-Object {$_.PublishedInf -eq $p.PublishedInf -and $_.SHA256 -eq $p.SHA256});if($same.Count -ne 1){$unexpected+=@($p)}}
 if($unexpected.Count){
  # Optional reinstall can allocate a new OEM address. This exception applies
  # only to recovery after that exact future operation began, never exclusion.
  $flag=if($null -ne $RecoveryBaseline){$RecoveryBaseline.PSObject.Properties['OptionalExtensionRestoreStarted']}else{$null}
  if($null -eq $flag -or $flag.Value -isnot [bool] -or $flag.Value -ne $true -or $unexpected.Count -ne 1){throw 'Extension store drift; not in captured exact removal plan.'}
  Assert-ChatpadRestorable $RecoveryBaseline.Readiness -RestoreExtension
  $material=$RecoveryBaseline.Readiness.ExtensionRestore
  $expected=Read-ChatpadExtensionInf $material.InfPath
  $new=$unexpected[0]
  if(-not $expected.Known -or -not $new.Known -or $new.Version -ne $material.Version -or $new.SHA256 -ine $expected.SHA256){throw 'Rediscovered optional extension differs from the exact saved restore package.'}
  # OEM addresses may also be reused. Replace the stale captured record only
  # after the saved optional package identity above has been verified exactly.
  $remove=@($remove | Where-Object {$_.PublishedInf -ine $new.PublishedInf})+@($new)
 }
 $remove
}
function Get-C3PublishedRemovalDisposition {
 param([string]$CapturedHash,[string]$ActualHash,[string]$ExperimentHash,[bool]$Recovering)
 if($CapturedHash -notmatch '^[a-fA-F0-9]{64}$' -or $ActualHash -notmatch '^[a-fA-F0-9]{64}$'){throw 'Invalid package identity hash.'}
 if($CapturedHash -ieq $ActualHash){return 'CapturedExtension'}
 # Windows can reuse the removed extension's OEM filename when staging the
 # experiment. Recovery must bind Microsoft before deleting that experiment;
 # the old extension name is not proof of the package currently occupying it.
 if($Recovering -and $ExperimentHash -match '^[a-fA-F0-9]{64}$' -and $ActualHash -ieq $ExperimentHash){return 'ExperimentReusedAddress'}
 throw 'Pre-removal package identity drift.'
}
function Remove-C3Extensions {
 param($Captured,[object[]]$Planned,$RecoveryBaseline=$null)
 $state=Get-C3Target $Captured;$live=@(Get-ChatpadExtensionInventory)
 $removal=@(Get-C3ExtensionRemovalPlan -Planned $Planned -Live $live -RecoveryBaseline $RecoveryBaseline)
 foreach($p in $removal){
  Get-C3Target $Captured | Out-Null
  if(Test-Path -LiteralPath $p.Path){
   $experimentHash=if($null -ne $RecoveryBaseline){@($RecoveryBaseline.Readiness.Files | Where-Object Role -eq 'WinUsbInf')[0].SHA256}else{''}
   $disposition=Get-C3PublishedRemovalDisposition $p.SHA256 (Get-FileHash -LiteralPath $p.Path).Hash $experimentHash ($null -ne $RecoveryBaseline)
   if($disposition -eq 'ExperimentReusedAddress'){continue}
   $fresh=Read-ChatpadExtensionInf $p.Path $p.PublishedInf;if(-not $fresh.Known -or $fresh.SHA256 -ne $p.SHA256){throw 'Pre-removal package identity drift.'};Invoke-C3Process 'pnputil.exe' @('/delete-driver',$p.PublishedInf,'/uninstall')
  }
  if(Test-Path -LiteralPath $p.Path){throw 'Exact extension exclusion did not remove published INF.'}
 }
 if(@(Get-ChatpadExtensionInventory).Count){throw 'A matching extension remains; no clean WinUSB transition.'}
}
function Clear-C3Filters($Captured){$s=Get-C3Target $Captured;if(@($s.ClassLowerFilters).Count -or @($s.ClassUpperFilters).Count -or @($s.Target.UpperFilters).Count){throw 'Class/upper-filter drift; no cleanup permitted.'};[Chatpad.Binding.ExactDevice]::ClearKnownLowerFilters($s.Target.InstanceId);$after=Get-C3Target $Captured;if(@($after.Target.LowerFilters).Count){throw 'Exact LowerFilters deletion did not verify.'}}
function Copy-C3RecoveryPackage {
 param($Package,[object[]]$Files,[string]$Directory)
 # Inbox INF and SYS may live in different Windows directories. Colocate such
 # members with the INF; retain subdirectories for sources within its package.
 $inf=[IO.Path]::GetFullPath($Package.InfPath)
 $sourceRoot=[IO.Path]::GetDirectoryName($inf)+[IO.Path]::DirectorySeparatorChar
 $filesWithInf=@($Files)
 if(-not @($Files | Where-Object {[IO.Path]::GetFullPath($_.Path) -ieq $inf}).Count){
  $filesWithInf+=([pscustomobject]@{Path=$inf;SHA256=(Get-FileHash -LiteralPath $inf -Algorithm SHA256).Hash})
 }
 $records=@();$destinations=@{}
 foreach($file in $filesWithInf){
  $original=[IO.Path]::GetFullPath($file.Path)
  $relative=if($original.StartsWith($sourceRoot,[StringComparison]::OrdinalIgnoreCase)){$original.Substring($sourceRoot.Length)}else{[IO.Path]::GetFileName($original)}
  $destination=[IO.Path]::GetFullPath((Join-Path $Directory $relative))
  if($destinations.ContainsKey($destination)){throw 'Duplicate recovery package destination; snapshot refused.'}
  $destinations[$destination]=$true
  New-Item -ItemType Directory (Split-Path $destination -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $original -Destination $destination
  if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ine $file.SHA256){throw 'Baseline source copy readback mismatch.'}
  $file | Add-Member -NotePropertyName OriginalPath -NotePropertyValue $original -Force
  $file.Path=$destination
  $records+=[pscustomobject]@{OriginalPath=$original;LocalPath=$destination;SHA256=$file.SHA256}
 }
 $Package | Add-Member -NotePropertyName OriginalInfPath -NotePropertyValue $inf -Force
 $Package.InfPath=Join-Path $Directory ([IO.Path]::GetFileName($inf))
 [pscustomobject]@{Files=$filesWithInf;Copies=$records}
}
function Save-ChatpadC3Baseline {
 param($State,[object[]]$Packages,$Readiness,[string]$Directory)
 Assert-ChatpadRestorable $Readiness;Assert-ChatpadExtensionInventory $Packages
 if(Test-Path -LiteralPath $Directory){throw 'Private C3 baseline directory must be new.'}
 $allowed=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../artifacts'))+[IO.Path]::DirectorySeparatorChar;$dir=[IO.Path]::GetFullPath($Directory)
 if(-not $dir.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Private C3 baseline must remain in artifacts.'}
 New-Item -ItemType Directory $dir | Out-Null
 # Clone before rebasing: caller readiness remains the provenance of the build,
 # while the private baseline becomes an independent recovery source.
 $recovery=$Readiness | ConvertTo-Json -Depth 25 | ConvertFrom-Json
 $m=Copy-C3RecoveryPackage $recovery.Microsoft @($recovery.Microsoft.PackageFiles) (Join-Path $dir 'source/microsoft')
 $recovery.Microsoft.PackageFiles=@($m.Files);$records=@($m.Copies)
 if($recovery.PSObject.Properties['ExtensionRestore'] -and $null -ne $recovery.ExtensionRestore){
  Test-ChatpadFileRecords @($recovery.ExtensionRestore.Files) 'Captured optional extension source'
  $e=Copy-C3RecoveryPackage $recovery.ExtensionRestore @($recovery.ExtensionRestore.Files) (Join-Path $dir 'source/extension')
  $recovery.ExtensionRestore.Files=@($e.Files);$records+=@($e.Copies)
 }
 Assert-ChatpadRestorable $recovery
 $baseline=[pscustomobject]@{Schema=2;CapturedUtc=[DateTime]::UtcNow.ToString('o');State=$State;Extensions=$Packages;Readiness=$recovery;Copies=$records;OptionalExtensionRestoreStarted=$false}
 $baseline | ConvertTo-Json -Depth 15 | Set-Content (Join-Path $dir 'baseline.json') -Encoding utf8
 return $baseline
}
function Invoke-ChatpadC3BindingAction {
 param([ValidateSet('Exclude','Bind','Restore')][string]$Operation,$Baseline,[switch]$Execute)
 if(-not $Execute){return [pscustomobject]@{Execute=$false;Operation=$Operation;RestorePlan=(New-ChatpadRestorePlan $Baseline.State.Target $Baseline.Readiness)}}
 Assert-C3Elevation;Assert-ChatpadRestorable $Baseline.Readiness
 if(-not ('Chatpad.Binding.ExactDevice' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ExactDevice.cs')}
 $captured=$Baseline.State.Target;$r=$Baseline.Readiness
 switch($Operation){
  'Exclude' {Remove-C3Extensions $captured @($Baseline.Extensions);Clear-C3Filters $captured}
  'Bind' {
   if(@(Get-ChatpadExtensionInventory).Count){throw 'Matching extension still present.'}
   $s=Get-C3Target $captured;Clear-C3Filters $captured;Test-ChatpadFileRecords @($r.Files) 'C3 source'
   $inf=@($r.Files | Where-Object Role -eq 'WinUsbInf')[0].Path
   Invoke-C3Process 'pnputil.exe' @('/add-driver',$inf)
   $s=Get-C3Target $captured;$reboot=[Chatpad.Binding.ExactDevice]::Install($s.Target.InstanceId,$inf,'WholeDevice','Chatpad Super Driver Project','0.0.1.0')
   if($reboot){throw 'WinUSB installation requests reboot; no restart/reboot executed.'}
   $s=Get-C3Target $captured;if((Get-ChatpadRecognizedState $s) -ne 'WinUSB'){throw 'WinUSB exact postcondition failed.'}
  }
  'Restore' {
   # Works after partial exclusion/binding, bridge crash or absent backend. A
   # matching unknown package stops even recovery rather than broad removal.
   Remove-C3Extensions $captured @($Baseline.Extensions) $Baseline;Clear-C3Filters $captured
   $s=Get-C3Target $captured;$m=$r.Microsoft
   $reboot=[Chatpad.Binding.ExactDevice]::Install($s.Target.InstanceId,$m.InfPath,$m.Section,$m.Provider,$m.Version)
   if($reboot){throw 'Microsoft restoration requests reboot; no restart/reboot executed.'}
   $s=Get-C3Target $captured;if((Get-ChatpadRecognizedState $s) -ne 'Xbox' -or @($s.Target.LowerFilters).Count -or ($s.Stack -join '\n') -match '(?i)ChatpadFilter'){throw 'Clean Microsoft base restoration not verified.'}
   $hash=@($r.Files | Where-Object Role -eq 'WinUsbInf')[0].SHA256
   foreach($file in Get-ChildItem (Join-Path $env:SystemRoot 'INF') -Filter 'oem*.inf' -File){if((Get-FileHash $file.FullName).Hash -eq $hash){$text=Get-Content $file.FullName -Raw;if($text -notmatch 'B6A5D05E-7E18-4DF1-8E47-12F072DE2C36'){throw 'Experiment identity mismatch.'};Invoke-C3Process 'pnputil.exe' @('/delete-driver',$file.Name)}}
   $s=Get-C3Target $captured;if((Get-ChatpadRecognizedState $s) -ne 'Xbox'){throw 'Final Microsoft verification failed.'}
  }
 }
 [pscustomobject]@{Success=$true;Evidence="Exact $Operation postcondition verified; no reboot."}
}
Export-ModuleMember -Function Invoke-ChatpadC3BindingAction,Save-ChatpadC3Baseline,Invoke-C3Process
