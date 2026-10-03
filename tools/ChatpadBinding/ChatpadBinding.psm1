Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:HardwareId = 'USB\VID_045E&PID_028E'
$script:InterfaceGuid = '{B6A5D05E-7E18-4DF1-8E47-12F072DE2C36}'
$script:KnownHashes = @{
 'ChatpadFilterExtension.inf'='FE35416537D432CDB37B0B9C967298F86B2EE636F02937DE3AAB0F1E91FFB274'
 'ChatpadFilter.sys'='16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0'
 'ChatpadFilterExtension.cat'='6D9724DF174383F37EB9DFC13C2A096BD067BD98F037F7C0A29F8292DD8F0732'
}
function Select-ChatpadTarget {
 param([object[]]$Devices,[string]$InstanceId)
 $matches = @($Devices | Where-Object { $_.InstanceId -match '^USB\\VID_045E&PID_028E\\[^\\]+$' -and @($_.HardwareIds) -contains $script:HardwareId })
 if ($InstanceId) { $matches = @($matches | Where-Object InstanceId -EQ $InstanceId) }
 if ($matches.Count -ne 1) { throw "Exactly one present physical 045E:028E target required; matches=$($matches.Count). Use exact -InstanceId when multiple physical targets exist." }
 return $matches[0]
}
function Get-ChatpadBindingState {
 param([string]$InstanceId)
 $devices = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -match '^USB\\VID_045E&PID_028E\\[^\\]+$' | ForEach-Object {
  $map=@{}; Get-PnpDeviceProperty -InstanceId $_.InstanceId | ForEach-Object { $map[$_.KeyName]=$_.Data }
  [pscustomobject]@{ InstanceId=$_.InstanceId; HardwareIds=@($map['DEVPKEY_Device_HardwareIds']); ContainerId=[string]$map['DEVPKEY_Device_ContainerId']; Inf=[string]$map['DEVPKEY_Device_DriverInfPath']; Section=[string]$map['DEVPKEY_Device_DriverInfSection']; Provider=[string]$map['DEVPKEY_Device_DriverProvider']; Version=[string]$map['DEVPKEY_Device_DriverVersion']; Service=[string]$map['DEVPKEY_Device_Service']; Problem=[int]$map['DEVPKEY_Device_ProblemCode']; LowerFilters=@($map['DEVPKEY_Device_LowerFilters'] | Where-Object {$null -ne $_}); UpperFilters=@($map['DEVPKEY_Device_UpperFilters'] | Where-Object {$null -ne $_}); LowerFiltersPresent=$map.ContainsKey('DEVPKEY_Device_LowerFilters'); UpperFiltersPresent=$map.ContainsKey('DEVPKEY_Device_UpperFilters'); ClassGuid=[string]$map['DEVPKEY_Device_ClassGuid'] }
 })
 $target=Select-ChatpadTarget $devices $InstanceId
 $class=Get-ItemProperty -LiteralPath (Join-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Class' $target.ClassGuid)
 $classLower=@(); $classUpper=@()
 if ($class.PSObject.Properties['LowerFilters']) { $classLower=@($class.LowerFilters) }
 if ($class.PSObject.Properties['UpperFilters']) { $classUpper=@($class.UpperFilters) }
 $extension=@(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'INF') -Filter 'oem*.inf' | Where-Object { Select-String -LiteralPath $_.FullName -SimpleMatch 'ChatpadFilter.sys' -Quiet } | ForEach-Object { [pscustomobject]@{ PublishedInf=$_.Name; Path=$_.FullName; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; Known= ((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash -eq $script:KnownHashes['ChatpadFilterExtension.inf']) } })
 $stack=@(& pnputil.exe /enum-devices /instanceid $target.InstanceId /stack 2>&1 | ForEach-Object { [string]$_ }); if($LASTEXITCODE -ne 0){throw "PnP stack query failed: $LASTEXITCODE"}
 $candidates=@(& pnputil.exe /enum-devices /instanceid $target.InstanceId /drivers 2>&1 | ForEach-Object { [string]$_ }); if($LASTEXITCODE -ne 0){throw "PnP candidate query failed: $LASTEXITCODE"}
 $interfaces=@(& pnputil.exe /enum-devices /instanceid $target.InstanceId /interfaces 2>&1 | ForEach-Object { [string]$_ }); if($LASTEXITCODE -ne 0){throw "PnP interface query failed: $LASTEXITCODE"}
 $services=@(Get-CimInstance Win32_SystemDriver | Where-Object Name -in @('xusb22','ChatpadFilter','vhf','WinUSB') | Select-Object Name,State,PathName)
 [pscustomobject]@{ Schema=1; Target=$target; ClassLowerFilters=$classLower; ClassUpperFilters=$classUpper; Extensions=$extension; Stack=$stack; Candidates=$candidates; Interfaces=$interfaces; Services=$services }
}
function Get-ChatpadRecognizedState {
 param($State)
 $t=$State.Target
 if($t.Problem -ne 0){ return 'Problem' }
 if($t.Service -ieq 'xusb22' -and $t.Inf -ieq 'xusb22.inf' -and $t.Provider -eq 'Microsoft'){return 'Xbox'}
 if($t.Service -ieq 'WinUSB' -and $t.Provider -eq 'Chatpad Super Driver Project' -and $t.Section -ieq 'WholeDevice' -and $t.Version -eq '0.0.1.0' -and @($t.LowerFilters).Count -eq 0 -and @($t.UpperFilters).Count -eq 0 -and @($State.ClassLowerFilters).Count -eq 0 -and @($State.ClassUpperFilters).Count -eq 0 -and @($State.Stack | Where-Object { $_ -match '(?i)ChatpadFilter|\bvhf\b|\bxusb22\b' }).Count -eq 0 -and ($State.Interfaces -join '\n').IndexOf($script:InterfaceGuid,[StringComparison]::OrdinalIgnoreCase) -ge 0){return 'WinUSB'}
 return 'Unexpected'
}
function Assert-ChatpadBaselineManifest {
 param($Baseline)
 if($Baseline.Schema -ne 1 -or (Get-ChatpadRecognizedState $Baseline.State) -ne 'Xbox'){throw 'Baseline must record healthy Microsoft xusb22 state.'}
 $t=$Baseline.State.Target
 Select-ChatpadTarget @($t) $t.InstanceId | Out-Null
 if($t.Section -ne 'CC_Install' -or $t.Version -ne '10.0.26100.9278'){throw 'Baseline Microsoft model/version differs from reviewed C1 baseline.'}
 if((@($t.LowerFilters)-join '|') -ine 'vhf|ChatpadFilter' -or @($t.UpperFilters).Count -ne 0 -or @($Baseline.State.ClassLowerFilters).Count -ne 0 -or @($Baseline.State.ClassUpperFilters).Count -ne 0){throw 'Baseline filters differ from reviewed C1 healthy stack.'}
 if(@($Baseline.State.Extensions).Count -ne 1 -or -not $Baseline.State.Extensions[0].Known -or $Baseline.State.Extensions[0].SHA256 -ne $script:KnownHashes['ChatpadFilterExtension.inf']){throw 'Baseline extension identity differs from reviewed C1 package.'}
 if(@($Baseline.Files).Count -lt 4){throw 'Baseline restoration material incomplete.'}
 foreach($file in $Baseline.Files){
  if($script:KnownHashes.ContainsKey($file.Name) -and $file.SHA256 -ne $script:KnownHashes[$file.Name]){throw 'Extension restoration identity is not the reviewed package.'}
 }
 foreach($name in $script:KnownHashes.Keys){if(@($Baseline.Files | Where-Object { $_.Name -eq $name -and $_.SHA256 -eq $script:KnownHashes[$name]}).Count -ne 1){throw "Missing exact extension restore material: $name"}}
 if(@($Baseline.Files | Where-Object { $_.Name -eq 'xusb22.inf' }).Count -ne 1){throw 'Missing captured Microsoft INF.'}
}
function Assert-ChatpadBaseline {
 param($Baseline,[string]$BaselinePath)
 Assert-ChatpadBaselineManifest $Baseline
 Assert-ChatpadBaselineFiles $Baseline.Files $BaselinePath
}
function Assert-ChatpadBaselineFiles {
 param([object[]]$Files,[string]$BaselinePath)
 foreach($file in $Files){
  $root=[IO.Path]::GetFullPath((Split-Path -Parent $BaselinePath))+[IO.Path]::DirectorySeparatorChar
  $path=[IO.Path]::GetFullPath((Join-Path $root $file.RelativePath))
  if(-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Baseline file escapes its capture directory.'}
  if(-not (Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.SHA256){throw "Baseline material hash mismatch: $($file.RelativePath)"}
 }
}
function New-ChatpadBindingPlan {
 param([ValidateSet('BindWinUsb','RestoreXbox')]$Operation,$State,$Baseline,[string]$BaselinePath,[string]$CandidateInf)
 Assert-ChatpadBaseline $Baseline $BaselinePath
 foreach($file in $Baseline.Files | Where-Object { $script:KnownHashes.ContainsKey($_.Name) }){if(-not (Test-Path -LiteralPath $file.SourcePath) -or (Get-FileHash -LiteralPath $file.SourcePath).Hash -ne $file.SHA256){throw 'Installed rollback extension material missing/changed.'}}
 if(-not (Test-Path -LiteralPath $Baseline.InstalledImage.Path) -or (Get-FileHash -LiteralPath $Baseline.InstalledImage.Path).Hash -ne $Baseline.InstalledImage.SHA256){throw 'Installed rollback filter image missing/changed.'}
 $t=$State.Target; $b=$Baseline.State.Target
 if($t.InstanceId -ine $b.InstanceId -or $t.ContainerId -ine $b.ContainerId -or @($t.HardwareIds) -notcontains $script:HardwareId){throw 'Live instance/container/hardware identity differs from baseline.'}
 $blockers=@(); $inf=''; $section=''; $provider=''; $version=''
 if($Operation -eq 'BindWinUsb'){
  if((Get-ChatpadRecognizedState $State) -ne 'Xbox'){ $blockers+='Bind requires healthy captured Xbox ownership.' }
  if(@($State.Extensions).Count -or @($t.LowerFilters).Count -or @($t.UpperFilters).Count -or @($State.ClassLowerFilters).Count -or @($State.ClassUpperFilters).Count){$blockers+='Persistent extension/filter exclusion unresolved. Stop; this tool never removes packages or changes filter properties.'}
  $inf=[IO.Path]::GetFullPath($CandidateInf); $section='WholeDevice'; $provider='Chatpad Super Driver Project'; $version='0.0.1.0'
  if(-not (Test-Path -LiteralPath $inf)){throw 'Candidate INF missing.'}
  $source=Join-Path $PSScriptRoot 'ChatpadWholeDeviceWinUSB.inf'
  if((Get-FileHash -LiteralPath $inf).Hash -ne (Get-FileHash -LiteralPath $source).Hash){throw 'Candidate INF differs from reviewed source.'}
  $cat=Join-Path (Split-Path -Parent $inf) 'ChatpadWholeDeviceWinUSB.cat'
  if(-not (Test-Path -LiteralPath $cat) -or (Get-AuthenticodeSignature -LiteralPath $cat).Status -ne 'Valid'){$blockers+='Candidate catalog is absent/unsigned/untrusted. C2 package is not installable.'}else{
   $signtool=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/10.0.26100.0/x64/signtool.exe'
   if(-not (Test-Path -LiteralPath $signtool)){$blockers+='Pinned catalog membership verifier unavailable.'}else{
    $membership=@(& $signtool verify /pa /c $cat $inf 2>&1)
    if($LASTEXITCODE -ne 0){$blockers+='Trusted catalog does not verify exact INF membership.'}
   }
  }
 } else {
  # Restoration is independent of WinUSB handles and never removes the extension.
  if((@($t.LowerFilters) -join '|') -ne (@($b.LowerFilters) -join '|') -or (@($t.UpperFilters) -join '|') -ne (@($b.UpperFilters) -join '|')){$blockers+='Device filter drift; exact filter restoration is outside this binding-only executor.'}
  if((@($State.ClassLowerFilters)-join '|') -ne (@($Baseline.State.ClassLowerFilters)-join '|') -or (@($State.ClassUpperFilters)-join '|') -ne (@($Baseline.State.ClassUpperFilters)-join '|')){$blockers+='Class filter drift; automatic class mutation prohibited.'}
  $known=@($State.Extensions | Where-Object { $_.Known -and $_.SHA256 -eq $script:KnownHashes['ChatpadFilterExtension.inf'] })
  if($known.Count -ne 1 -or @($State.Extensions).Count -ne 1){$blockers+='Installed rollback extension identity drift; binding-only restore cannot recreate missing/changed extension.'}
  $file=@($Baseline.Files | Where-Object Name -EQ 'xusb22.inf')[0]
  $inf=$file.SourcePath; $section=$b.Section; $provider=$b.Provider; $version=$b.Version
  if(-not (Test-Path -LiteralPath $inf) -or (Get-FileHash -LiteralPath $inf).Hash -ne $file.SHA256){throw 'Original inbox Microsoft INF missing or changed; no guessed replacement permitted.'}
 }
 [pscustomobject]@{ Schema=1; Operation=$Operation; Execute=$false; InstanceId=$t.InstanceId; Inf=$inf; InfSHA256=(Get-FileHash -LiteralPath $inf).Hash; Section=$section; Provider=$provider; Version=$version; InterfaceGuid=$script:InterfaceGuid; Blockers=$blockers; NativeCalls=@('SetupDiOpenDeviceInfoW','DI_ENUMSINGLEINF compatible node selection','SetupDiSetSelectedDriverW','DiInstallDevice flags=0'); NoAutomaticRestart=$true }
}
function Assert-ChatpadExecutionGate {
 param([string]$Authorization,[string]$BaselinePath,[string]$BaselineSha256,[string]$FixturePath)
 if($FixturePath){throw 'Fixtures can never execute binding.'}
 if($Authorization -cne 'TASK-8L-C3-EXACT-DEVICE-BINDING'){throw 'Future live task authorization marker required; C2 does not authorize execution.'}
 if($BaselineSha256 -notmatch '^[A-Fa-f0-9]{64}$' -or (Get-FileHash -LiteralPath $BaselinePath).Hash -ine $BaselineSha256){throw 'Independently recorded baseline SHA-256 required.'}
 if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Execution requires elevation; Status and CaptureBaseline do not.'}
}
function Save-ChatpadBaseline {
 param($State,[string]$OutputDirectory)
 if((Get-ChatpadRecognizedState $State) -ne 'Xbox'){throw 'Only healthy Xbox state may be captured as rollback baseline.'}
 $root=[IO.Path]::GetFullPath($OutputDirectory); $allowed=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../artifacts'))+[IO.Path]::DirectorySeparatorChar
 if(-not $root.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Private baseline must remain under ignored artifacts.'}
 if(Test-Path -LiteralPath $root){throw 'Use a new baseline directory; captures are immutable.'}
 New-Item -ItemType Directory -Path $root | Out-Null
 $sources=@(); $base=Join-Path $env:SystemRoot 'INF/xusb22.inf'; $sources+=$base
 $store=Join-Path $env:SystemRoot 'System32/DriverStore/FileRepository'
 $ext=@($State.Extensions | Where-Object Known)
 if($ext.Count -ne 1){throw 'Exactly one reviewed installed extension required for C1 restoration capture.'}
 $packages=@(Get-ChildItem -LiteralPath $store -Directory -Filter 'chatpadfilterextension.inf_amd64_*' | Where-Object { $p=Join-Path $_.FullName 'ChatpadFilterExtension.inf'; (Test-Path -LiteralPath $p) -and (Get-FileHash -LiteralPath $p).Hash -eq $script:KnownHashes['ChatpadFilterExtension.inf'] })
 if($packages.Count -ne 1){throw 'Exact extension DriverStore package ambiguous/missing.'}
 foreach($name in $script:KnownHashes.Keys){$sources+=Join-Path $packages[0].FullName $name}
 $basePackages=@(Get-ChildItem -LiteralPath $store -Directory -Filter 'xusb22.inf_amd64_*' | Where-Object { $p=Join-Path $_.FullName 'xusb22.inf'; (Test-Path -LiteralPath $p) -and (Get-FileHash -LiteralPath $p).Hash -eq (Get-FileHash -LiteralPath $base).Hash })
 if($basePackages.Count -ne 1){throw 'Exact base Microsoft DriverStore package ambiguous/missing.'}
 $sources+=@(Get-ChildItem -LiteralPath $basePackages[0].FullName -Recurse -File | Where-Object Name -NE 'xusb22.inf' | ForEach-Object FullName)
 $sources+=@($State.Services | Where-Object Name -In @('xusb22','vhf') | ForEach-Object PathName)
 $files=@(); $index=0
 foreach($source in $sources){
  $name=Split-Path -Leaf $source; $relative=Join-Path ('restore/{0:d3}' -f $index) $name; $index++
  $destination=Join-Path $root $relative; New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null; Copy-Item -LiteralPath $source -Destination $destination
  $hash=(Get-FileHash -LiteralPath $source).Hash; if((Get-FileHash -LiteralPath $destination).Hash -ne $hash){throw 'Restore copy hash mismatch.'}
  $files += [pscustomobject]@{Name=$name; SourcePath=$source; RelativePath=$relative; SHA256=$hash; Signature=(Get-AuthenticodeSignature -LiteralPath $source).Status.ToString()}
 }
 $images=@($State.Services | Where-Object Name -EQ 'ChatpadFilter')
 if($images.Count -ne 1){throw 'Installed filter service image is ambiguous/missing.'}
 $installed=$images[0].PathName
 if((Get-FileHash -LiteralPath $installed).Hash -ne $script:KnownHashes['ChatpadFilter.sys']){throw 'Installed running-image file differs from reviewed baseline.'}
 $baseline=[pscustomobject]@{Schema=1; CapturedUtc=[DateTime]::UtcNow.ToString('o'); State=$State; Files=$files; InstalledImage=[pscustomobject]@{Path=$installed; SHA256=(Get-FileHash -LiteralPath $installed).Hash}; Limitations=@('Copy of installed package files only; no export/staging/install performed.','Not a Microsoft-only clean baseline: extension and filters remain installed.','Binding executor never restores trust/filters/security changes.')}
 $path=Join-Path $root 'baseline.json'; $baseline | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8
 Assert-ChatpadBaseline $baseline $path
 [pscustomobject]@{BaselinePath=$path; SHA256=(Get-FileHash -LiteralPath $path).Hash; CopiedFiles=$files.Count; State='Xbox'; NoMutation=$true}
}
Export-ModuleMember -Function Select-ChatpadTarget,Get-ChatpadBindingState,Get-ChatpadRecognizedState,Assert-ChatpadBaselineManifest,Assert-ChatpadBaselineFiles,Assert-ChatpadBaseline,New-ChatpadBindingPlan,Assert-ChatpadExecutionGate,Save-ChatpadBaseline
