[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageReportPath,[switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root=Join-Path $repo 'artifacts/task-8lc2r3'
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroPackage.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
$result=[ordered]@{Result='BLOCKED';Execute=$Execute.IsPresent;Staged=@();RebootRequired=$false;SecurityMutation=$false;TrustMutation=$false;PhysicalMutation=$false;Error=$null}
try{
 $report=Get-Content -LiteralPath $PackageReportPath -Raw | ConvertFrom-Json
 if($report.Revision -cne '1c126ed4780322454391b7be782230b35b0810f6' -or $report.InfVersion -cne '1.10.0.142' -or -not $report.Trust.InstallExpected -or $report.RuntimeDllsModified){throw 'Unqualified package report.'}
 $directory=(Resolve-Path -LiteralPath $report.PackageDirectory).Path
 if(-not $directory.StartsWith(([IO.Path]::GetFullPath($root)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){throw 'Package must be exact task-local staging.'}
 $certificate=Get-ChatpadDevelopmentCertificateState
 foreach($name in @('TrustedRoot','TrustedPublisher','CertificateValid','CodeSigningEku','NoDuplicateCertificates')){if(-not $certificate.$name){throw ('Current trust prerequisite '+$name)}}
 $security=Get-ChatpadCurrentSecurity
 if(-not $security.QuerySucceeded -or $security.TestSigning -ne $false -or $security.Hvci -ne $true){throw 'Current security prerequisite failed.'}
 $expected=@($report.Payload)+@($report.Catalogs)
 if($expected.Count -ne 6 -or @(Get-ChildItem $directory -Force).Count -ne 6){throw 'Exact six-file UMDF package required.'}
 foreach($file in $expected){if((Get-FileHash -LiteralPath (Join-Path $directory $file.Name)).Hash -cne $file.SHA256){throw ('Package hash drift '+$file.Name)}}
 $sign=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/10.0.26100.0/x64/signtool.exe'
 foreach($catalog in $report.Catalogs){
  $cat=Join-Path $directory $catalog.Name
  $signature=Get-AuthenticodeSignature $cat
  if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -cne '885ADDC8018AC58E19B14668ACDAC9072BB6AE15'){throw 'CAT trust/signer drift.'}
  foreach($member in $catalog.Members){
   & $sign verify /pa /v /c $cat (Join-Path $directory $member) > (Join-Path $root ('install-member-'+$member+'.txt')) 2>&1
   if($LASTEXITCODE -ne 0){throw ('CAT member rejected '+$member)}
  }
 }
 $before=Get-ChatpadBindingState
 if($before.Target.Inf -cne 'xusb22.inf' -or $before.Target.Problem -ne 52 -or @($before.Extensions | Where-Object PublishedInf -eq 'oem104.inf').Count -ne 1){throw 'Physical Xbox no longer at expected baseline.'}
 $before | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root 'physical-install-before.private.json') -Encoding utf8
 if(-not $Execute){$result.Result='PLAN';$result.Commands=@('pnputil /add-driver <exact task package>/hidmaestro.inf /install','pnputil /add-driver <exact task package>/hidmaestro_xusb.inf /install');$result | ConvertTo-Json -Depth 8;exit 0}
 $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if(-not $admin){throw 'Installation requires an elevated process.'}
 foreach($inf in @('hidmaestro.inf','hidmaestro_xusb.inf')){
  $lines=@(& (Join-Path $env:windir 'System32/pnputil.exe') /add-driver (Join-Path $directory $inf) /install 2>&1)
  $code=$LASTEXITCODE
  $lines | Set-Content (Join-Path $root ('pnputil-'+$inf+'.txt')) -Encoding utf8
  $published=[regex]::Match(($lines -join "`n"),'(?im)^Published Name:\s*(oem\d+\.inf)\s*$').Groups[1].Value
  $result.Staged+=@([pscustomobject]@{OriginalInf=$inf;PublishedInf=$published;ExitCode=$code;Log=('pnputil-'+$inf+'.txt')})
  $after=Get-ChatpadBindingState
  $after | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root 'physical-install-after.private.json') -Encoding utf8
  if(($before.Target | ConvertTo-Json -Depth 8 -Compress) -cne ($after.Target | ConvertTo-Json -Depth 8 -Compress) -or
     ($before.Extensions | ConvertTo-Json -Depth 8 -Compress) -cne ($after.Extensions | ConvertTo-Json -Depth 8 -Compress) -or
     ($before.ClassLowerFilters -join '|') -cne ($after.ClassLowerFilters -join '|') -or
     ($before.ClassUpperFilters -join '|') -cne ($after.ClassUpperFilters -join '|')){$result.PhysicalMutation=$true;throw 'Physical Xbox changed; stop immediately.'}
  if($code -eq 3010 -or ($lines -join "`n") -match '(?i)reboot (is )?required|restart (is )?required'){$result.RebootRequired=$true;$result.Result='REBOOT_REQUIRED';break}
  if($code -ne 0){throw ('PnPUtil failed '+$inf+' exit='+$code+'. See retained log.')}
  if(-not $published){throw 'Installation did not report an exact published OEM INF.'}
 }
 if(-not $result.RebootRequired){$result.Result='STAGED'}
}catch{$result.Error=$_.Exception.Message;$result.Result='BLOCKED'}
$result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root 'installation-result.json') -Encoding utf8
$result | ConvertTo-Json -Depth 12
if($result.Result -eq 'STAGED'){exit 0}else{exit 2}
