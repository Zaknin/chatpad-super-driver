[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ReferenceRepository,
 [string]$SdkDirectory=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/virtual/sdk-dependency'),
 [string]$OutputDirectory=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r2/qualification'),
 [string]$SignToolPath='C:/Program Files (x86)/Windows Kits/10/bin/10.0.26100.0/x64/signtool.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroQualification.psm1') -Force
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=[IO.Path]::GetFullPath($OutputDirectory)
$artifactRoot=[IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($artifactRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Generated qualification evidence must remain under repository artifacts/.'}
$pin=Get-Content (Join-Path $PSScriptRoot 'ChatpadVirtualXbox/upstream.json') -Raw | ConvertFrom-Json
$head=[string](& git.exe -C $ReferenceRepository rev-parse HEAD)
if($LASTEXITCODE -ne 0 -or $head -cne $pin.revision){throw 'Reference must be the exact pinned source revision.'}
$tag=[string](& git.exe -C $ReferenceRepository rev-list -n 1 $pin.tagInspected)
if($LASTEXITCODE -ne 0 -or $tag -cne $pin.revision){throw 'Release tag/source mismatch.'}
$dirty=@(& git.exe -C $ReferenceRepository status --porcelain --untracked-files=no)
if($LASTEXITCODE -ne 0 -or $dirty.Count){throw 'Pinned reference checkout must be clean.'}
$license=Join-Path $ReferenceRepository 'LICENSE'
if((Get-FileHash $license).Hash -cne $pin.licenseSha256){throw 'Pinned source license mismatch.'}
$archive=Join-Path $SdkDirectory 'release.zip'
$sdk=Join-Path $SdkDirectory 'HIDMaestro.Core.dll'
if((Get-FileHash $archive).Hash -cne $pin.c2r1ReleaseAssetSha256 -or
   (Get-FileHash $sdk).Hash -cne $pin.c2r1ReleaseSdkSha256){throw 'Official release/SDK pin mismatch.'}
if(-not(Test-Path -LiteralPath $SignToolPath -PathType Leaf)){throw 'Offline signature verifier missing.'}
New-Item -ItemType Directory $output -Force | Out-Null
$payload=Join-Path $output 'payload'
New-Item -ItemType Directory $payload -Force | Out-Null
# Resource access only: never construct HMContext, call upstream methods,
# run embedded helpers/installers or execute any extracted driver binary.
$assembly=[Reflection.Assembly]::LoadFrom((Resolve-Path -LiteralPath $sdk).Path)
$resources=@($assembly.GetManifestResourceNames())
$inventory=@(foreach($name in @('hidmaestro.inf','HIDMaestro.dll','hidmaestro_xusb.inf','HMXInput.dll','hmswd.exe')){
 $resource='HIDMaestro.Native.x64.'+$name
 $stream=$assembly.GetManifestResourceStream($resource)
 if(-not $stream){throw ('Required pinned payload absent: '+$name)}
 $path=Join-Path $payload $name
 $file=[IO.File]::Create($path)
 try{$stream.CopyTo($file)}finally{$file.Dispose();$stream.Dispose()}
 $sig=Get-AuthenticodeSignature -LiteralPath $path
 $machine=$null;$version=$null;$infVersion=$null
 if([IO.Path]::GetExtension($name) -in '.dll','.exe'){
  $bytes=[IO.File]::ReadAllBytes($path)
  $offset=[BitConverter]::ToInt32($bytes,0x3c)
  if($offset -lt 0 -or $offset+6 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes,$offset) -ne 0x00004550){throw 'Invalid PE header.'}
  $machine=('0x{0:X4}' -f [BitConverter]::ToUInt16($bytes,$offset+4))
  $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileVersion
  $lines=@(& $SignToolPath verify /pa /v $path 2>&1)
  $exitCode=$LASTEXITCODE
  $lines | Set-Content (Join-Path $output ($name+'.signature.txt')) -Encoding utf8
 }else{
  $exitCode=$null
  $text=[IO.File]::ReadAllText($path)
  $infVersion=[regex]::Match($text,'(?im)^DriverVer\s*=\s*(.+)$').Groups[1].Value.Trim()
 }
 [pscustomobject]@{Name=$name;SHA256=(Get-FileHash $path).Hash;Bytes=(Get-Item $path).Length;
  Machine=$machine;BinaryVersion=$version;DriverVer=$infVersion;AuthenticodeStatus=$sig.Status.ToString();
  Signer=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null};SignToolExit=$exitCode}
})
$expected=@($inventory | Select-Object Name,SHA256)
$identity=Test-ChatpadHidMaestroPackageIdentity $payload $expected
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $archive).Path)
try{$members=@($zip.Entries | Select-Object FullName,Length)}finally{$zip.Dispose()}
$catalogs=@('hidmaestro.cat','hidmaestro_xusb.cat' | ForEach-Object {
 $name=$_
 [pscustomobject]@{Name=$name;Embedded=@($resources | Where-Object {$_ -like ('*.'+$name)}).Count -gt 0;
  ReleaseMember=@($members | Where-Object {($_.FullName -split '/')[-1] -ieq $name}).Count -gt 0;
  SHA256=$null;Signature='UNAVAILABLE';Membership='BLOCKED: no catalog supplied'}
})
$result=[ordered]@{Schema=1;Revision=$pin.revision;ReleaseTag=$pin.tagInspected;
 ReleaseSHA256=$pin.c2r1ReleaseAssetSha256;SdkSHA256=$pin.c2r1ReleaseSdkSha256;
 SourceLicenseSHA256=$pin.licenseSha256;SourceIdentityVerified=$true;Architecture='x64';
 Files=$inventory;Catalogs=$catalogs;EmbeddedResourceNames=$resources;ReleaseMembers=$members;ExtractedIdentity=$identity;
 Result='BLOCKED';InstallationQualified=$false;
 Blocker='Pinned release supplies unsigned UMDF DLLs and no CAT; supported installer creates/signs with HIDMaestroTestCert and modifies machine trust stores, prohibited in C2R2.';
 NormalWindows='UMDF2 design supports ordinary Windows in principle; this supplied package has not passed trust/load qualification.';
 Hvci='No custom kernel image required for xbox-360-wired; live HVCI/load compatibility UNTESTED.';
 SecureBoot='No change; compatibility UNTESTED.';
 Installed=$false;ContextConstructed=$false;DeviceCreated=$false;DriverSigning=$false;TrustStoreMutation=$false;
 AdapterIdentityLimitation='Upstream SignDrivers changes DLL bytes. Existing embedded unsigned-byte guard cannot accept those signed bytes; requires separately pinned signed package contract, never remove validation.'}
$result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $output 'qualification.json') -Encoding utf8
Write-Output ('BLOCKED: '+$result.Blocker)
exit 2
