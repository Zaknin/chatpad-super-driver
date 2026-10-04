$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4Package.psm1') -Force
$cases=@(
 [pscustomobject]@{Name='C3 branch accepted';Readiness=[pscustomobject]@{Repository=[pscustomobject]@{Branch='feature/chatpad-winusb-bridge-poc';Commit=('a'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-winusb-bridge-poc';Commit=('a'*40)};Expected=$true},
 [pscustomobject]@{Name='C4 branch accepted only for C4 readiness';Readiness=[pscustomobject]@{Task='8L-C4';Repository=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('b'*40)}};Current=[pscustomobject]@{Branch='feature/chatpad-usermode-runner';Commit=('b'*40)};Expected=$true},
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
 $setupPayload=@($payloads|Where-Object Role -eq 'SetupTool')
 $runtimePayloads=@($payloads|Where-Object Role -like 'VirtualFile:*')
 if($setupPayload.Count -ne 1 -or $setupPayload[0].SHA256 -cne (Get-FileHash (Join-Path $packageRoot 'ChatpadSetup.ps1')).Hash){throw 'SetupTool must be hashed from the exact packaged bytes.'}
 if(@($runtimePayloads|Where-Object Role -eq 'VirtualFile:ChatpadSetup.ps1').Count){throw 'Setup script must not be recorded as an installed runtime member.'}
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
 $legacyReadiness=[pscustomobject]@{PackageRoot=$packageRoot;Files=@($readiness.Files)+@(New-ChatpadC4PackageRecord 'VirtualFile:ChatpadSetup.ps1' (Join-Path $packageRoot 'ChatpadSetup.ps1'))}
 $legacyError=''
 try{Assert-ChatpadC4PackageIdentity $legacyReadiness $packageRoot $repoSetup|Out-Null}catch{$legacyError=$_.Exception.Message}
 if($legacyError -notmatch 'must not be an installed runtime member'){throw 'Regression: stale VirtualFile:ChatpadSetup.ps1 metadata was not rejected clearly.'}
 $staleReadiness=[pscustomobject]@{PackageRoot=$packageRoot;Files=@($readiness.Files|ForEach-Object {if($_.Role -eq 'SetupTool'){[pscustomobject]@{Role=$_.Role;Path=$_.Path;SHA256=('F'*64)} } else{$_}})}
 $staleError=''
 try{Assert-ChatpadC4PackageIdentity $staleReadiness $packageRoot $repoSetup|Out-Null}catch{$staleError=$_.Exception.Message}
 if($staleError -notmatch 'SetupTool hash mismatch'){throw 'Regression: stale/current setup hash mismatch was not rejected clearly.'}
}
finally{Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue}
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $message=''
 try{Invoke-ChatpadC3BindingAction Bind $null -Execute|Out-Null}catch{$message=$_.Exception.Message}
 if($message -notmatch 'requires an elevated'){throw ('Setup elevation boundary failed: '+$message)}
}
Write-Output "C4 setup repository identity tests: $($cases.Count)/$($cases.Count) PASS; package identity regressions: 8/8 PASS"
