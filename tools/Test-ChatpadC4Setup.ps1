$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
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
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 $message=''
 try{Invoke-ChatpadC3BindingAction Bind $null -Execute|Out-Null}catch{$message=$_.Exception.Message}
 if($message -notmatch 'requires an elevated'){throw ('Setup elevation boundary failed: '+$message)}
}
Write-Output "C4 setup repository identity tests: $($cases.Count)/$($cases.Count) PASS"
