$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4Package.psm1') -Force
$installRoot=Join-Path $env:ProgramFiles 'ChatpadBridge'
$approvedSid='S-1-5-21-100-200-300-1001'
$validIdentity=[pscustomobject]@{Elevated=$true;UserSid=$approvedSid;TokenSessionId=4;ActiveConsoleSessionId=4;WtsProtocol=0;SessionState='Active'}
if(-not(Test-ChatpadBrokerSetupIdentity $validIdentity $approvedSid)){throw 'Broker install must accept only the elevated authorized local console identity.'}
foreach($identity in @(
 [pscustomobject]@{Elevated=$false;UserSid=$approvedSid;TokenSessionId=4;ActiveConsoleSessionId=4;WtsProtocol=0;SessionState='Active'},
 [pscustomobject]@{Elevated=$true;UserSid='S-1-5-21-100-200-300-1002';TokenSessionId=4;ActiveConsoleSessionId=4;WtsProtocol=0;SessionState='Active'},
 [pscustomobject]@{Elevated=$true;UserSid=$approvedSid;TokenSessionId=3;ActiveConsoleSessionId=4;WtsProtocol=0;SessionState='Active'},
 [pscustomobject]@{Elevated=$true;UserSid=$approvedSid;TokenSessionId=4;ActiveConsoleSessionId=4;WtsProtocol=2;SessionState='Active'},
 [pscustomobject]@{Elevated=$true;UserSid=$approvedSid;TokenSessionId=4;ActiveConsoleSessionId=4;WtsProtocol=0;SessionState='Disconnected'}
)){if(Test-ChatpadBrokerSetupIdentity $identity $approvedSid){throw 'Broker install accepted non-elevated, wrong-SID, stale, RDP or inactive sessions.'}}
$cases=@(
 [pscustomobject]@{Name='C3 branch accepted';Readiness=[pscustomobject]@{Repository=[pscustomobject]@{Branch='feature/chatpad-winusb-bridge-poc';Commit=('a'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-winusb-bridge-poc';Commit=('a'*40)};Expected=$true},
 [pscustomobject]@{Name='C4 branch accepted only for C4 readiness';Readiness=[pscustomobject]@{Task='8L-C4';Repository=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('b'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('b'*40)};Expected=$true},
 [pscustomobject]@{Name='C4L2 package accepted only for current runner branch';Readiness=[pscustomobject]@{Task='8L-C4L2';Repository=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('e'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('e'*40)};Expected=$true},
 [pscustomobject]@{Name='C4 branch rejected for legacy readiness';Readiness=[pscustomobject]@{Repository=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('c'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('c'*40)};Expected=$false},
 [pscustomobject]@{Name='C4 readiness cannot claim another branch';Readiness=[pscustomobject]@{Task='8L-C4';Repository=[pscustomobject]@{Branch='feature/other';Commit=('d'*40)}};Current=[pscustomobject]@{Branch='feature/other';Commit=('d'*40)};Expected=$false}
)
foreach($case in $cases){
 $actual=Test-ChatpadSourceRepositoryIdentity $case.Readiness $case.Current
 if($actual -ne $case.Expected){throw ($case.Name+': expected '+$case.Expected+', received '+$actual)}
}
$packageRoot=Join-Path ([IO.Path]::GetTempPath()) ('chatpad-c4-package-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $packageRoot|Out-Null
try{
 foreach($name in @('ChatpadBridge.exe','ChatpadVirtualXbox.exe','ChatpadVirtualXbox.dll','HIDMaestro.Core.dll','ChatpadSetup.ps1')){
  Set-Content -LiteralPath (Join-Path $packageRoot $name) -Value ('current package bytes: '+$name) -NoNewline
 }
 $payloads=New-ChatpadC4PackagePayloadRecords $packageRoot
 $servicePlan=New-ChatpadBrokerServicePlan -Mode InstallBroker -InstallRoot $installRoot -RuntimeRecords @($payloads|Where-Object Role -like 'VirtualFile:*') -AuthorizedUserSid $approvedSid
 if($servicePlan.ServiceName -cne 'ChatpadHidMaestroBroker' -or $servicePlan.Account -cne 'LocalSystem' -or $servicePlan.StartType -cne 'Automatic'){throw 'Broker install plan must select only the fixed LocalSystem automatic service.'}
 if($servicePlan.BinaryPathName -cne ('"'+(Join-Path $installRoot 'ChatpadVirtualXbox.exe')+'" service') -or -not([IO.Path]::IsPathRooted($servicePlan.ExecutablePath))){throw 'Service image path must be absolute, quoted and under protected Program Files.'}
 if(@($servicePlan.RecoveryActions).Count -ne 3 -or $servicePlan.MutationScope -cne 'service-only'){throw 'Broker service recovery or mutation boundary is not fixed.'}
 if(-not $servicePlan.AuthorizationPath.StartsWith($servicePlan.InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or @($servicePlan.RuntimeRecords|Where-Object {-not $_.TargetPath.StartsWith($servicePlan.InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase)}).Count){throw 'Service configuration and runtime dependency paths must remain under the protected install root.'}
 $missingExeError='';try{New-ChatpadBrokerServicePlan -Mode InstallBroker -InstallRoot $installRoot -RuntimeRecords @($payloads|Where-Object { $_.Role -like 'VirtualFile:*' -and $_.Role -notlike 'VirtualFile:ChatpadVirtualXbox.exe'}) -AuthorizedUserSid $approvedSid|Out-Null}catch{$missingExeError=$_.Exception.Message}
 if($missingExeError -notmatch 'ChatpadVirtualXbox.exe'){throw ('Broker package without the service apphost was accepted: '+$missingExeError)}
 $shaAlgorithm=[Security.Cryptography.SHA256]::Create();try{$configHash=([BitConverter]::ToString($shaAlgorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($servicePlan.AuthorizationJson)))).Replace('-','')}finally{$shaAlgorithm.Dispose()}
 if($servicePlan.AuthorizationHash -cne $configHash){throw 'Authorization config hash must derive from exact generated bytes.'}
 $repairPlan=New-ChatpadBrokerServicePlan -Mode RepairBroker -InstallRoot $installRoot -RuntimeRecords @($payloads|Where-Object Role -like 'VirtualFile:*') -AuthorizedUserSid $approvedSid
 $uninstallPlan=New-ChatpadBrokerServicePlan -Mode UninstallBroker -InstallRoot $installRoot -RuntimeRecords @($payloads|Where-Object Role -like 'VirtualFile:*') -AuthorizedUserSid $approvedSid
 if($repairPlan.ServiceName -cne $servicePlan.ServiceName -or $uninstallPlan.ServiceName -cne $servicePlan.ServiceName){throw 'Repair/uninstall must be scoped to the single fixed broker service.'}
 $badMember=[pscustomobject]@{Role='VirtualFile:..\outside.dll';SHA256=('A'*64)}
 $badMemberError='';try{New-ChatpadBrokerServicePlan -Mode InstallBroker -InstallRoot $installRoot -RuntimeRecords (@($payloads|Where-Object Role -like 'VirtualFile:*')+@($badMember)) -AuthorizedUserSid $approvedSid|Out-Null}catch{$badMemberError=$_.Exception.Message}
 if($badMemberError -notmatch 'member name'){throw 'Package path traversal was not rejected before service install.'}
 $badRootError='';try{Assert-ChatpadBrokerInstallRoot (Join-Path $packageRoot 'arbitrary-private')|Out-Null}catch{$badRootError=$_.Exception.Message}
 if($badRootError -notmatch 'Program Files'){throw 'Service install root outside protected Program Files was accepted.'}
 $selected=Resolve-ChatpadBrokerPackageRoot $packageRoot $packageRoot
 if($selected -cne [IO.Path]::GetFullPath($packageRoot)){throw 'Explicit broker package root must resolve to the readiness package identity.'}
 $selectionError='';try{Resolve-ChatpadBrokerPackageRoot (Join-Path $packageRoot 'older-package') $packageRoot|Out-Null}catch{$selectionError=$_.Exception.Message}
 if($selectionError -notmatch 'does not match the package identity'){throw 'Explicit stale broker package root was silently replaced by the readiness path.'}
 if(Test-ChatpadBrokerInstallRootIdentity (Join-Path $env:ProgramFiles 'ChatpadBridge') $env:ProgramFiles $true){throw 'Broker install root reparse points must be rejected.'}
 if(-not(Test-ChatpadBrokerInstallRootIdentity (Join-Path $env:ProgramFiles 'ChatpadBridge') $env:ProgramFiles $false)){throw 'Exact protected Program Files broker root should be accepted.'}
 $setupPayload=@($payloads|Where-Object Role -eq 'SetupTool')
 $runtimePayloads=@($payloads|Where-Object Role -like 'VirtualFile:*')
 if($setupPayload.Count -ne 1 -or $setupPayload[0].SHA256 -cne (Get-FileHash (Join-Path $packageRoot 'ChatpadSetup.ps1')).Hash){throw 'SetupTool must be hashed from the exact packaged bytes.'}
 if(@($runtimePayloads|Where-Object Role -eq 'VirtualFile:ChatpadSetup.ps1').Count){throw 'Setup script must not be recorded as an installed runtime member.'}
 $setupSource=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadSetup.ps1') -Raw
 foreach($dispatch in @("'InstallBroker' {Install-ChatpadBroker}","'RepairBroker' {Install-ChatpadBroker -Repair}","'UninstallBroker' {Remove-ChatpadBrokerService}")){if(-not $setupSource.Contains($dispatch)){throw "Broker setup dispatch missing or changed: $dispatch"}}
 if(-not $setupSource.Contains('BrokerService=(Get-ChatpadBrokerStatus)')){throw 'Read-only Status mode must report broker service identity and state.'}
 $setupTokens=$null;$setupAstErrors=$null;$setupAst=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'ChatpadSetup.ps1'),[ref]$setupTokens,[ref]$setupAstErrors)
 if(@($setupAstErrors).Count){throw 'Broker setup script must parse without errors.'}
 $brokerFunctions=@($setupAst.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in @('Install-ChatpadBroker','Remove-ChatpadBrokerService')},$true))
 if($brokerFunctions.Count -ne 2 -or @($brokerFunctions|Where-Object {$_.Extent.Text -match 'Invoke-ChatpadC3BindingAction|Install-Bridge|RestoreMicrosoftXbox'}).Count){throw 'Broker service lifecycle must not invoke physical binding operations.'}
 $repoSetup=Join-Path $packageRoot 'ChatpadSetup.ps1'
 $readiness=[pscustomobject]@{PackageRoot=$packageRoot;Files=@(
  (New-ChatpadC4PackageRecord 'Poc' (Join-Path $packageRoot 'ChatpadBridge.exe')),
  (New-ChatpadC4PackageRecord 'VirtualBackend' (Join-Path $packageRoot 'ChatpadVirtualXbox.exe'))
 )+$payloads}
 Assert-ChatpadC4PackageIdentity $readiness $packageRoot $repoSetup|Out-Null
 if((Get-ChatpadC4ReadinessPackageRoot $readiness) -cne [IO.Path]::GetFullPath($packageRoot)){throw 'Default package selection must follow readiness package identity.'}
 $installed=Join-Path $packageRoot 'installed';New-Item -ItemType Directory -Path $installed|Out-Null
 foreach($record in $runtimePayloads){Copy-Item (Join-Path $packageRoot ($record.Role.Substring('VirtualFile:'.Length))) $installed}
 foreach($record in $runtimePayloads){Assert-ChatpadC4InstalledRuntimeMember $record $installed|Out-Null}
 Set-Content -LiteralPath (Join-Path $installed 'HIDMaestro.Core.dll') -Value 'modified runtime bytes' -NoNewline
 $runtimeError=''
 try{Assert-ChatpadC4InstalledRuntimeMember (@($runtimePayloads|Where-Object Role -eq 'VirtualFile:HIDMaestro.Core.dll')[0]) $installed|Out-Null}catch{$runtimeError=$_.Exception.Message}
 if($runtimeError -notmatch 'Installed helper runtime member hash mismatch'){throw 'Runtime member hash validation was not retained.'}
 Set-Content -LiteralPath (Join-Path $packageRoot 'UnmanifestedRuntime.dll') -Value 'extra bytes' -NoNewline
 $extraError='';try{Assert-ChatpadC4PackageIdentity $readiness $packageRoot $repoSetup|Out-Null}catch{$extraError=$_.Exception.Message}
 if($extraError -notmatch 'member set differs'){throw 'Unmanifested runtime file was accepted in the package.'}
 Remove-Item -LiteralPath (Join-Path $packageRoot 'UnmanifestedRuntime.dll') -Force
 $legacyReadiness=[pscustomobject]@{PackageRoot=$packageRoot;Files=@($readiness.Files)+@(New-ChatpadC4PackageRecord 'VirtualFile:ChatpadSetup.ps1' (Join-Path $packageRoot 'ChatpadSetup.ps1'))}
 $legacyError=''
 try{Assert-ChatpadC4PackageIdentity $legacyReadiness $packageRoot $repoSetup|Out-Null}catch{$legacyError=$_.Exception.Message}
 if($legacyError -notmatch 'must not be an installed runtime member'){throw 'Regression: stale VirtualFile:ChatpadSetup.ps1 metadata was not rejected clearly.'}
 $staleReadiness=[pscustomobject]@{PackageRoot=$packageRoot;Files=@($readiness.Files|ForEach-Object {if($_.Role -eq 'SetupTool'){[pscustomobject]@{Role=$_.Role;Path=$_.Path;SHA256=('F'*64)} } else{$_}})}
 $staleError=''
 try{Assert-ChatpadC4PackageIdentity $staleReadiness $packageRoot $repoSetup|Out-Null}catch{$staleError=$_.Exception.Message}
 if($staleError -notmatch 'SetupTool hash mismatch'){throw 'Regression: stale/current setup hash mismatch was not rejected clearly.'}
 $repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
 $approvedPrivate=Join-Path $env:ProgramData 'ChatpadBridge'
 $artifactBaseline=Join-Path (Join-Path $repo 'artifacts') 'baseline-test'
 $privateBaseline=Join-Path $approvedPrivate 'baseline-test'
 if(-not(Test-ChatpadC3BaselineDirectory $artifactBaseline)){throw 'Artifact-backed private baseline path must remain accepted.'}
 if(-not(Test-ChatpadC3BaselineDirectory $privateBaseline $approvedPrivate)){throw 'Explicit persistent private baseline root must be accepted.'}
 if(Test-ChatpadC3BaselineDirectory $approvedPrivate $approvedPrivate){throw 'Baseline path must be a child of the approved root, not the root itself.'}
 if(Test-ChatpadC3BaselineDirectory ($approvedPrivate+'-sibling') $approvedPrivate){throw 'Sibling path must not pass private-root containment.'}
 if(Test-ChatpadC3BaselineDirectory (Join-Path $packageRoot 'arbitrary-private/baseline') (Join-Path $packageRoot 'arbitrary-private')){throw 'Arbitrary caller-supplied private roots must be rejected.'}
 $bindPending=New-ChatpadC3ActionResult Bind $true
 if(-not $bindPending.Success -or -not $bindPending.RebootRequired -or $bindPending.Operation -cne 'Bind'){throw 'Successful Bind plus NeedReboot must remain a successful pending-restart result.'}
 $restorePending=New-ChatpadC3ActionResult Restore $true
 if(-not $restorePending.Success -or -not $restorePending.RebootRequired -or $restorePending.Operation -cne 'Restore'){throw 'Successful Restore plus NeedReboot must remain a successful pending-restart result.'}
 $bindComplete=New-ChatpadC3ActionResult Bind $false
 if(-not $bindComplete.Success -or $bindComplete.RebootRequired -or $bindComplete.Operation -cne 'Bind'){throw 'Completed Bind must not request a restart.'}
 if(-not (Get-Command Invoke-ChatpadC3BindingAction).Parameters.ContainsKey('AllowPendingReboot')){throw 'C4 must explicitly opt in to pending-restart results.'}
}
finally{Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $message=''
 try{Invoke-ChatpadC3BindingAction Bind $null -Execute|Out-Null}catch{$message=$_.Exception.Message}
 if($message -notmatch 'requires an elevated'){throw ('Setup elevation boundary failed: '+$message)}
}
Write-Output "C4 setup repository identity tests: $($cases.Count)/$($cases.Count) PASS; broker setup/package regressions: PASS; package identity regressions: 8/8 PASS; baseline path regressions: 5/5 PASS; PnP restart-result regressions: 4/4 PASS"
