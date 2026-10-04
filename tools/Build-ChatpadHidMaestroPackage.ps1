[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReferenceRepository,
 [string]$OutputDirectory=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r3/package-build'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=[IO.Path]::GetFullPath($OutputDirectory)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Use a fresh deterministic directory under ignored artifacts.'}
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroPackage.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
$certificate=Get-ChatpadDevelopmentCertificateState
foreach($property in @('TrustedRoot','TrustedPublisher','SigningKey','NoDuplicateCertificates','CertificateValid','CodeSigningEku')){
 if($certificate.$property -ne $true){throw ('Existing certificate prerequisite failed: '+$property+'. No trust/key changes attempted.')}
}
$security=Get-ChatpadCurrentSecurity
if(-not $security.QuerySucceeded -or $security.TestSigning -ne $false -or $security.Hvci -ne $true){throw 'Normal Windows/HVCI not verified; no catalog or driver mutation.'}
$pin=Get-Content (Join-Path $PSScriptRoot 'ChatpadVirtualXbox/upstream.json') -Raw | ConvertFrom-Json
$source=[string](& git.exe -C $ReferenceRepository rev-parse HEAD)
if($LASTEXITCODE -ne 0 -or $source -cne $pin.revision){throw 'Wrong source revision.'}
$dirty=@(& git.exe -C $ReferenceRepository status --porcelain --untracked-files=no)
if($LASTEXITCODE -ne 0 -or $dirty.Count){throw 'Pinned source must be clean.'}
if((Get-FileHash (Join-Path $ReferenceRepository 'LICENSE')).Hash -cne $pin.licenseSha256){throw 'Pinned license mismatch.'}
$sdkDirectory=Join-Path $repo 'artifacts/task-8lc2r1/virtual/sdk-dependency'
$sdk=Join-Path $sdkDirectory 'HIDMaestro.Core.dll'
if((Get-FileHash $sdk).Hash -cne $pin.c2r1ReleaseSdkSha256 -or (Get-FileHash (Join-Path $sdkDirectory 'release.zip')).Hash -cne $pin.c2r1ReleaseAssetSha256){throw 'Official SDK/release mismatch.'}
$expected=[ordered]@{
 'hidmaestro.inf'='00806FBAA52314C73EA895936D9FEBCD4925A22036B4E55C3DCDB3C794F61661'
 'HIDMaestro.dll'='24B23EB1F572A83B9785AAD8386B379ACE916A6B22AD0CAB054D43DEE5AD7090'
 'hidmaestro_xusb.inf'='7E98D5F3C7C757E40F4A50D15AD0ADF5DB4E15D6F415B34913AC2B054C65D76B'
 'HMXInput.dll'='B3760B79AFB98D2379AE29EE81B8C2B086F3635C426FDF42F0D34587EEE1B2E1'
}
New-Item -ItemType Directory $output | Out-Null
$package=Join-Path $output 'package'
New-Item -ItemType Directory $package | Out-Null
$certificate | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $output 'certificate-state.json') -Encoding utf8
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path $sdk).Path)
$payload=@(foreach($name in $expected.Keys){
 $path=Join-Path $package $name
 $stream=$assembly.GetManifestResourceStream('HIDMaestro.Native.x64.'+$name)
 if(-not $stream){throw ('Missing payload '+$name)}
 $dest=[IO.File]::Create($path)
 try{$stream.CopyTo($dest)}finally{$dest.Dispose();$stream.Dispose()}
 if((Get-FileHash $path).Hash -cne $expected[$name]){throw ('Exact payload mismatch '+$name)}
 [pscustomobject]@{Name=$name;Bytes=(Get-Item $path).Length;SHA256=$expected[$name];Role=if($name.EndsWith('.inf')){'Inf'}else{'UmdfDll'};
  FileVersion=if($name.EndsWith('.dll')){[Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion}else{'1.10.0.142'};Architecture='x64';RelativePath=('package/'+$name)}
})
$payload | ConvertTo-Json | Set-Content (Join-Path $output 'extracted-runtime-manifest.json') -Encoding utf8
$packaged=@(foreach($file in $payload){
 $path=Join-Path $package $file.Name
 if($file.Role -eq 'Inf'){
  $text=[IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false,$true))
  [IO.File]::WriteAllBytes($path,(ConvertTo-ChatpadHidMaestroInf $text))
 }
 [pscustomobject]@{Name=$file.Name;Bytes=(Get-Item $path).Length;SHA256=(Get-FileHash $path).Hash;
  SourceSHA256=$file.SHA256;Role=$file.Role;FileVersion=$file.FileVersion;Architecture='x64';RelativePath=$file.RelativePath}
})
$wdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$verify=Join-Path $wdk 'Tools/10.0.26100.0/x64/InfVerif.exe'
$inf2cat=Join-Path $wdk 'bin/10.0.26100.0/x86/Inf2Cat.exe'
$sign=Join-Path $wdk 'bin/10.0.26100.0/x64/signtool.exe'
foreach($tool in @($verify,$inf2cat,$sign)){if(-not(Test-Path -LiteralPath $tool)){throw ('WDK tool missing '+$tool)}}
$verifications=@()
function Run([string]$Name,[string]$Tool,[string[]]$Arguments){
 $lines=@(& $Tool @Arguments 2>&1);$code=$LASTEXITCODE
 $lines | Set-Content (Join-Path $output ($Name+'.txt')) -Encoding utf8
 [pscustomobject]@{Name=$Name;ExitCode=$code;Arguments=$Arguments;Log=($Name+'.txt')}
}
foreach($inf in @('hidmaestro.inf','hidmaestro_xusb.inf')){
 $r=Run ('infverif-'+$inf) $verify @('/u',(Join-Path $package $inf));$verifications+=$r
 if($r.ExitCode -ne 0){throw ('InfVerif failed '+$inf+' exit='+$r.ExitCode)}
}
$r=Run 'inf2cat' $inf2cat @(('/driver:'+$package),'/os:10_CO_X64','/uselocaltime');$verifications+=$r
if($r.ExitCode -ne 0){throw ('Inf2Cat failed exit='+$r.ExitCode)}
$thumb='885ADDC8018AC58E19B14668ACDAC9072BB6AE15'
$catalogs=@(foreach($pair in @(@('hidmaestro.cat','hidmaestro.inf','HIDMaestro.dll'),@('hidmaestro_xusb.cat','hidmaestro_xusb.inf','HMXInput.dll'))){
 $cat=Join-Path $package $pair[0]
 $r=Run ('sign-'+$pair[0]) $sign @('sign','/v','/fd','SHA256','/sha1',$thumb,'/s','My',$cat);$verifications+=$r
 if($r.ExitCode -ne 0){throw ('CAT signing failed exit='+$r.ExitCode)}
 $r=Run ('verify-'+$pair[0]) $sign @('verify','/pa','/v',$cat);$verifications+=$r
 $sig=Get-AuthenticodeSignature -LiteralPath $cat
 if($r.ExitCode -ne 0 -or $sig.Status -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $thumb){throw 'Catalog trust/exact signer failed.'}
 foreach($member in $pair[1..2]){
  $r=Run ('member-'+$member) $sign @('verify','/pa','/v','/c',$cat,(Join-Path $package $member));$verifications+=$r
  if($r.ExitCode -ne 0){throw ('Catalog member failed '+$member)}
 }
 [pscustomobject]@{Name=$pair[0];SHA256=(Get-FileHash $cat).Hash;Bytes=(Get-Item $cat).Length;Signer=$sig.SignerCertificate.Thumbprint;Subject=$sig.SignerCertificate.Subject;Authenticode='Valid';Members=@($pair[1..2])}
})
foreach($file in $packaged){if((Get-FileHash (Join-Path $package $file.Name)).Hash -cne $file.SHA256){throw ('Package bytes changed '+$file.Name)}}
foreach($name in @('HIDMaestro.dll','HMXInput.dll')){if((Get-FileHash (Join-Path $package $name)).Hash -cne $expected[$name]){throw ('Runtime DLL source bytes changed '+$name)}}
$chain=[Security.Cryptography.X509Certificates.X509Chain]::new($true)
$chain.ChainPolicy.RevocationMode=[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
try{$machineChain=$chain.Build((Get-Item ('Cert:\CurrentUser\My\'+$thumb)))}finally{$chain.Dispose()}
$kernelOk=$true
foreach($name in @('WUDFRd.sys','mshidumdf.sys')){
 $r=Run ('inbox-'+$name) $sign @('verify','/a','/kp','/v',(Join-Path $env:windir ('System32/drivers/'+$name)));$verifications+=$r
 if($r.ExitCode -ne 0){$kernelOk=$false}
}
$evidence=[ordered]@{ExactPayload=$true;UnmodifiedDlls=$true;CatalogsValid=$true;ExactSigner=$true;AllMembers=$true;TrustedRoot=$certificate.TrustedRoot;TrustedPublisher=$certificate.TrustedPublisher;SigningKey=$certificate.SigningKey;CertificateValid=$certificate.CertificateValid;CodeSigningEku=$certificate.CodeSigningEku;NoDuplicateCertificates=$certificate.NoDuplicateCertificates;MachineChain=$machineChain;NormalWindows=($security.TestSigning -eq $false);Hvci=($security.Hvci -eq $true);InboxKernelPolicy=$kernelOk}
$decision=Get-ChatpadHidMaestroTrustDecision $evidence
$report=[ordered]@{Revision=$pin.revision;Release=$pin.tagInspected;InfVersion='1.10.0.142';DllVersion='1.10.1.0';Architecture='x64';PackageDirectory=$package;Payload=$packaged;SourcePayload=$payload;InfTransformation='UTF16LE+BOM, CRLF and NTamd64.10.0...17134 OS floor only';Catalogs=$catalogs;Evidence=$evidence;Trust=$decision;Security=$security;Verifications=$verifications;RuntimeDllsModified=$false;EmbeddedSigned=$false;CertificateCreated=$false;TrustModified=$false;Staged=$false;CatalogFreshGenerationByteDeterministic=$false;Determinism='Fixed staging/payload, generated catalogs frozen by exact hashes; Inf2Cat CTL identifiers/time are not edited.'}
$report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $output 'signed-package-report.json') -Encoding utf8
if(-not $decision.InstallExpected){Write-Output ('BLOCKED '+($decision.Blockers -join ' '));exit 2}
Write-Output 'PASS offline exact catalog-signed UMDF package; installation/load not yet verified.'
