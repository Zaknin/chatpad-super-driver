[CmdletBinding()]
param(
 [string]$OutputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/trust-final'),
 [string]$SecurityEvidencePath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadWinUsbTrust.psm1') -Force
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$output=[IO.Path]::GetFullPath($OutputPath)
$allowed=Join-Path $root 'artifacts'
if(-not $output.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Output must be inside ignored repository artifacts.'}
if(Test-Path -LiteralPath $output){throw 'Output already exists; retain prior evidence and use a new artifact directory.'}
New-Item -ItemType Directory -Path $output | Out-Null
$thumb='885ADDC8018AC58E19B14668ACDAC9072BB6AE15'
$subject='CN=Chatpad Super Driver Local Development Test Signing'
$signTool=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/10.0.26100.0/x64/signtool.exe'
if(-not(Test-Path -LiteralPath $signTool)){throw 'Pinned SignTool unavailable.'}
$storeInventory=@()
foreach($location in @('CurrentUser','LocalMachine')){foreach($store in @('My','Root','TrustedPublisher')){
 $matches=@(Get-ChildItem ('Cert:\'+$location+'\'+$store)|Where-Object Thumbprint -EQ $thumb)
 foreach($cert in $matches){if($cert.Subject -cne $subject){throw 'Existing certificate subject mismatch.'};$storeInventory += [pscustomobject]@{Store="$location/$store";Subject=$cert.Subject;Thumbprint=$cert.Thumbprint;HasPrivateKey=$cert.HasPrivateKey;NotBeforeUtc=$cert.NotBefore.ToUniversalTime().ToString('o');NotAfterUtc=$cert.NotAfter.ToUniversalTime().ToString('o')}}
}}
$storeInventory|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $output 'certificate-presence.json') -Encoding utf8
$private=@($storeInventory|Where-Object { $_.Store -eq 'CurrentUser/My' -and $_.HasPrivateKey })
if($private.Count -ne 1){throw 'Exactly one authorized existing CurrentUser/My signing identity with private key required; no certificate creation/import is allowed.'}
$unsigned=Join-Path $output 'unsigned';$regenerated=Join-Path $output 'fresh-signability';$signed=Join-Path $output 'signed'
# Inf2Cat embeds a random CTL ListIdentifier and current ThisUpdate. Preserve the
# exact accepted C2 unsigned package as a frozen deterministic payload; fresh
# signability validation remains separate, and generated catalogs are not edited.
& (Join-Path $PSScriptRoot 'ChatpadBinding/Build-Package.ps1') -OutputPath $regenerated *> (Join-Path $output 'fresh-signability-build.txt')
$seed=Join-Path $root 'artifacts/task-8lc2/binding/package'
$pins=@{'ChatpadWholeDeviceWinUSB.inf'='F66F99B466535A3E693354BE62B0EC75EA466DF4E4C612B72C3AB8AAAB912B17';'ChatpadWholeDeviceWinUSB.cat'='35DF7AA9E125C9507F463C0BBEFA828828849FAD60970A199BC865C00B668EB7'}
New-Item -ItemType Directory -Path $unsigned | Out-Null
foreach($name in $pins.Keys){$p=Join-Path $seed $name;if(-not(Test-ChatpadArtifactHash $p $pins[$name])){throw "Frozen C2 unsigned package missing/tampered: $name"};Copy-Item -LiteralPath $p -Destination $unsigned;if(-not(Test-ChatpadArtifactHash (Join-Path $unsigned $name) $pins[$name])){throw 'Frozen package independent copy hash mismatch.'}}
if((Get-FileHash (Join-Path $regenerated 'ChatpadWholeDeviceWinUSB.inf')).Hash -ne $pins['ChatpadWholeDeviceWinUSB.inf']){throw 'Reviewed INF changed; preserved unsigned catalog cannot be reused.'}
New-Item -ItemType Directory -Path $signed | Out-Null
Copy-Item -LiteralPath (Join-Path $unsigned 'ChatpadWholeDeviceWinUSB.inf'),(Join-Path $unsigned 'ChatpadWholeDeviceWinUSB.cat') -Destination $signed
$cat=Join-Path $signed 'ChatpadWholeDeviceWinUSB.cat';$inf=Join-Path $signed 'ChatpadWholeDeviceWinUSB.inf'
& $signTool sign /v /fd SHA256 /sha1 $thumb /s My $cat *> (Join-Path $output 'sign-catalog.txt')
if($LASTEXITCODE -ne 0){throw "Authorized offline catalog signing failed: $LASTEXITCODE"}
function Invoke-Verification([string]$Name,[string[]]$Arguments){
 & $signTool @Arguments *> (Join-Path $output ($Name+'.txt'))
 return [pscustomobject]@{Name=$Name;Arguments=$Arguments;ExitCode=$LASTEXITCODE;Log=($Name+'.txt')}
}
$verifications=@()
$verifications+=Invoke-Verification 'signed-catalog-pa' @('verify','/pa','/v',$cat)
$verifications+=Invoke-Verification 'signed-inf-member-pa' @('verify','/pa','/v','/c',$cat,$inf)
$verifications+=Invoke-Verification 'signed-catalog-kp' @('verify','/kp','/v',$cat)
$verifications+=Invoke-Verification 'signed-inf-member-kp' @('verify','/kp','/v','/c',$cat,$inf)
$verifications+=Invoke-Verification 'unsigned-catalog-pa' @('verify','/pa','/v',(Join-Path $unsigned 'ChatpadWholeDeviceWinUSB.cat'))
$kernel=Join-Path $env:SystemRoot 'System32/drivers/winusb.sys'
$verifications+=Invoke-Verification 'inbox-winusb-kp' @('verify','/a','/kp','/v',$kernel)
$sig=Get-AuthenticodeSignature -LiteralPath $cat
$chain=[Security.Cryptography.X509Certificates.X509Chain]::new($true)
$chain.ChainPolicy.RevocationMode=[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
$machineChain=$false;if($sig.SignerCertificate){$machineChain=$chain.Build($sig.SignerCertificate)}
$chainStatuses=@($chain.ChainStatus|ForEach-Object { [pscustomobject]@{Status=$_.Status.ToString();Information=$_.StatusInformation.Trim()} })
Add-Type -AssemblyName System.Security
$cms=[Security.Cryptography.Pkcs.SignedCms]::new();$cms.Decode([IO.File]::ReadAllBytes($cat))
$signatureIntact=$false;try{$cms.CheckSignature($true);$signatureIntact=$true}catch{$signatureIntact=$false}
$exactSigner=$cms.SignerInfos.Count -eq 1 -and $cms.SignerInfos[0].Certificate.Thumbprint -eq $thumb
$source=Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadWholeDeviceWinUSB.inf'
$sourceText=[IO.File]::ReadAllText($source)
$inBoxOnly=@(Get-ChildItem -LiteralPath $signed -File).Count -eq 2 -and $sourceText -notmatch '(?i)CopyFiles|AddService|\.sys|CoInstaller|Filter' -and $sourceText -match '(?im)^Include\s*=\s*winusb\.inf\s*$' -and $sourceText -match '(?im)^Needs\s*=\s*WINUSB\.NT.Services\s*$'
$security=$null;$normal=$false
if($SecurityEvidencePath){$security=Get-Content -LiteralPath $SecurityEvidencePath -Raw|ConvertFrom-Json;if($security.PSObject.Properties['CodeIntegrity']){$ci=$security.CodeIntegrity;$normal=$ci.QuerySucceeded -is [bool] -and $ci.QuerySucceeded -and $ci.TestSigning -is [bool] -and -not $ci.TestSigning -and [int]$ci.NtStatus -eq 0 -and ([uint32]$ci.Options -band 1) -ne 0}}
$evidence=[ordered]@{
 ExactReviewedInf=((Get-FileHash $source).Hash -eq (Get-FileHash $inf).Hash)
 InBoxOnly=[bool]$inBoxOnly
 SignatureIntact=[bool]$signatureIntact
 ExactSigner=[bool]$exactSigner
 CatalogAuthenticode=([int](@($verifications|Where-Object Name -EQ 'signed-catalog-pa')[0].ExitCode) -eq 0)
 InfMembership=([int](@($verifications|Where-Object Name -EQ 'signed-inf-member-pa')[0].ExitCode) -eq 0)
 LocalMachineRoot=(@($storeInventory|Where-Object Store -EQ 'LocalMachine/Root').Count -eq 1)
 LocalMachinePublisher=(@($storeInventory|Where-Object Store -EQ 'LocalMachine/TrustedPublisher').Count -eq 1)
 LocalMachineChain=[bool]$machineChain
 InBoxKernelPolicy=([int](@($verifications|Where-Object Name -EQ 'inbox-winusb-kp')[0].ExitCode) -eq 0)
 NormalMode=[bool]$normal
}
$decision=Get-ChatpadWinUsbTrustDecision $evidence
$files=@();foreach($variant in @('unsigned','signed')){foreach($name in @('ChatpadWholeDeviceWinUSB.inf','ChatpadWholeDeviceWinUSB.cat')){$p=Join-Path (Join-Path $output $variant) $name;$files += [pscustomobject]@{Variant=$variant;Role=$(if($name.EndsWith('.inf')){'WinUsbInf'}else{'WinUsbCatalog'});Path=$p;SHA256=(Get-FileHash $p -Algorithm SHA256).Hash}}}
$report=[ordered]@{Schema=1;Task='8L-C2R1';UnsignedFrozenPayloadDeterministic=$true;UnsignedInf2CatRegenerationReproducible=$false;UnsignedProvenance='Exact hash-pinned C2 unsigned package preserved; Inf2Cat emits random CTL ListIdentifier and current ThisUpdate; fresh signability checked separately.';SignedCatalogDeterministic=$false;SignedCatalogTimestamped=$false;NoCustomKernelBinary=$true;CatalogAuthenticodeState=$sig.Status.ToString();LocalMachineChainOfflineRevocationNotChecked=$true;LocalMachineChainStatus=$chainStatuses;Evidence=$evidence;Trust=$decision;Verifications=$verifications;Files=$files;InBoxKernel=[ordered]@{Path=$kernel;SHA256=(Get-FileHash $kernel).Hash};Security=$security;LiveMutationOccurred=$false;TrustStoreMutationOccurred=$false;CertificateCreationOccurred=$false;Staged=$false;PhysicalInstallVerified=$false;ProductionDistributionApproved=$false}
$report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $output 'trust-report.json') -Encoding utf8
$decision|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $output 'trust-decision.json') -Encoding utf8
$chain.Dispose()
Write-Output ('OFFLINE PACKAGE '+$(if($decision.NormalWindowsInstallExpected){'PASS'}else{'BLOCKED'})+': '+$decision.Reason)
Write-Output "Report: $(Join-Path $output 'trust-report.json')"
