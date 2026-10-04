[CmdletBinding()]
param([string]$InstallResultPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r3/installation-result.json'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$install=Get-Content -LiteralPath $InstallResultPath -Raw | ConvertFrom-Json
if($install.Result -cne 'STAGED' -or $install.Staged.Count -ne 2){throw 'Exact successful two-package install record required.'}
$report=Get-Content (Join-Path $PSScriptRoot '../artifacts/task-8lc2r3/package-final/signed-package-report.json') -Raw | ConvertFrom-Json
$commands=@(foreach($name in @('hidmaestro_xusb.inf','hidmaestro.inf')){
 $entry=@($install.Staged | Where-Object OriginalInf -ceq $name)
 if($entry.Count -ne 1 -or $entry[0].PublishedInf -notmatch '^oem\d+\.inf$' -or $entry[0].PublishedInf -ieq 'oem104.inf'){throw 'Unsafe/ambiguous published INF.'}
 $expected=@($report.Payload | Where-Object Name -ceq $name)
 $path=Join-Path $env:windir ('INF/'+$entry[0].PublishedInf)
 if($expected.Count -ne 1 -or (Get-FileHash -LiteralPath $path).Hash -cne $expected[0].SHA256){throw 'Published package identity drift.'}
 [pscustomobject]@{OriginalInf=$name;PublishedInf=$entry[0].PublishedInf;SHA256=$expected[0].SHA256;Command=('pnputil.exe /delete-driver '+$entry[0].PublishedInf+' /uninstall')}
})
[pscustomobject]@{Result='PLAN_VERIFIED';Executed=$false;Commands=$commands;
 Preconditions=@('Stop/dispose project virtual controller; verify no HIDMaestro device is present.','Revalidate published INF and DriverStore INF/CAT/DLL hashes against frozen signed-package-report.','Administrator invocation; stop if Windows reports reboot required.');
 PostRemovalVerification=@('Both exact published INF names absent from pnputil /enum-drivers.','No present or phantom task-owned virtual devices, and its XInput slot absent.','Physical xusb22/oem104/Code52/filter baseline unchanged.','TESTSIGNING=false/HVCI=true and certificate inventories unchanged.');
 Limitations='Removal was prepared and identity-validated only; no package removal or reboot performed.'} | ConvertTo-Json -Depth 8
