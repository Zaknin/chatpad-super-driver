Set-StrictMode -Version Latest

function Get-ChatpadHidMaestroTrustDecision {
 [CmdletBinding()]param([Collections.IDictionary]$Evidence)
 $requirements=[ordered]@{
  ExactPayload='Pinned INF/DLL payload mismatch.';UnmodifiedDlls='Runtime DLL bytes were modified.'
  CatalogsValid='Catalog signature/trust failed.';ExactSigner='Wrong catalog signer.'
  AllMembers='A required package file failed catalog membership.'
  TrustedRoot='Expected existing machine Root certificate missing.'
  TrustedPublisher='Expected existing machine TrustedPublisher certificate missing.'
  SigningKey='Existing signing key missing.';CertificateValid='Certificate expired/not yet valid.'
  CodeSigningEku='Code Signing EKU missing.';NoDuplicateCertificates='Unexpected certificate duplicate/subject identity.'
  MachineChain='Machine certificate chain verification failed.'
  NormalWindows='TESTSIGNING=false not verified.';Hvci='HVCI=true not verified.'
  InboxKernelPolicy='Inbox UMDF kernel components failed kernel signature policy.'
 }
 $blockers=@(foreach($key in $requirements.Keys){
  if(-not $Evidence.Contains($key) -or $Evidence[$key] -isnot [bool] -or -not $Evidence[$key]){$requirements[$key]}
 })
 [pscustomobject]@{InstallExpected=($blockers.Count -eq 0);Blockers=$blockers;RuntimeQualified=$false;
  Reason='Local PnP trust and exact payload are offline prerequisites; actual UMDF load/XInput must be verified separately.'}
}

function Get-ChatpadDevelopmentCertificateState {
 [CmdletBinding()]param()
 $ErrorActionPreference='Stop'
 $thumb='885ADDC8018AC58E19B14668ACDAC9072BB6AE15'
 $subject='CN=Chatpad Super Driver Local Development Test Signing'
 $expectedSha='300238DB21F1ECD2F2C2E9F3A03EFF0147CBC419D474B1B3B89433569D5E6C96'
 $records=@(foreach($store in @('Cert:\LocalMachine\Root','Cert:\LocalMachine\TrustedPublisher','Cert:\CurrentUser\My')){
  foreach($cert in Get-ChildItem -LiteralPath $store | Where-Object {$_.Thumbprint -eq $thumb -or $_.Subject -eq $subject}){
   $eku=@($cert.Extensions | Where-Object {$_.Oid.Value -eq '2.5.29.37'} | ForEach-Object {$_.EnhancedKeyUsages | ForEach-Object {$_.Value}})
   [pscustomobject]@{Store=$store;Subject=$cert.Subject;Thumbprint=$cert.Thumbprint;HasPrivateKey=$cert.HasPrivateKey;
    SHA256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($cert.RawData));
    NotBeforeUtc=$cert.NotBefore.ToUniversalTime().ToString('o');NotAfterUtc=$cert.NotAfter.ToUniversalTime().ToString('o');
    CurrentlyValid=([DateTime]::UtcNow -ge $cert.NotBefore.ToUniversalTime() -and [DateTime]::UtcNow -le $cert.NotAfter.ToUniversalTime());
    CodeSigningEku=($eku -contains '1.3.6.1.5.5.7.3.3');Eku=$eku}
  }
 })
 $root=@($records | Where-Object Store -eq 'Cert:\LocalMachine\Root')
 $publisher=@($records | Where-Object Store -eq 'Cert:\LocalMachine\TrustedPublisher')
 $signing=@($records | Where-Object Store -eq 'Cert:\CurrentUser\My')
 $exact=$records.Count -eq 3 -and @($records | Where-Object { $_.Thumbprint -cne $thumb -or $_.Subject -cne $subject -or $_.SHA256 -cne $expectedSha }).Count -eq 0
 [pscustomobject]@{Records=$records;TrustedRoot=($root.Count -eq 1 -and -not $root[0].HasPrivateKey);
  TrustedPublisher=($publisher.Count -eq 1 -and -not $publisher[0].HasPrivateKey);
  SigningKey=($signing.Count -eq 1 -and $signing[0].HasPrivateKey);
  NoDuplicateCertificates=$exact;CertificateValid=($exact -and @($records | Where-Object CurrentlyValid -ne $true).Count -eq 0);
  CodeSigningEku=($exact -and @($records | Where-Object CodeSigningEku -ne $true).Count -eq 0)}
}

function ConvertTo-ChatpadHidMaestroInf {
 [CmdletBinding()]param([Parameter(Mandatory)][string]$Source)
 # These are the only source-to-package changes: supported encoding and
 # the OS floor required by the existing DIRID13 UMDF directives.
 if([regex]::Matches($Source,'(?m)^%ManufacturerName%\s*=\s*Standard,NTamd64\s*$').Count -ne 1 -or
    [regex]::Matches($Source,'(?m)^\[Standard.NTamd64\]\s*$').Count -ne 1){throw 'Unexpected pinned INF model decoration.'}
 $text=[regex]::Replace($Source,'(?m)^(%ManufacturerName%\s*=\s*Standard,)NTamd64\s*$', '${1}NTamd64.10.0...17134')
 $text=$text.Replace('[Standard.NTamd64]','[Standard.NTamd64.10.0...17134]')
 $text=$text.Replace("`r`n","`n").Replace("`n","`r`n")
 return ,([byte[]]([Text.Encoding]::Unicode.GetPreamble()+[Text.Encoding]::Unicode.GetBytes($text)))
}

function Test-ChatpadHidMaestroSecurityInvariant {
 param($Before,$After)
 foreach($name in @('QuerySucceeded','TestSigning','Hvci','SecureBoot','SecureBootQuery','Mutation')){if($Before.$name -cne $After.$name){return $false}}
 return $Before.QuerySucceeded -eq $true -and $Before.TestSigning -eq $false -and $Before.Hvci -eq $true -and $Before.Mutation -eq $false
}
function Test-ChatpadHidMaestroCleanupIds {
 param([string[]]$Ids)
 if($Ids.Count -ne 2){return $false}
 $root=@($Ids | Where-Object {$_ -cmatch '^ROOT\\VID_045E&PID_028E&IG_00\\HM_[0-9A-F]{16}$'})
 $swd=@($Ids | Where-Object {$_ -cmatch '^SWD\\HIDMAESTRO\\HM_[0-9A-F]{16}$'})
 return $root.Count -eq 1 -and $swd.Count -eq 1 -and ($root[0] -split '\\')[-1] -ceq ($swd[0] -split '\\')[-1]
}
function Test-ChatpadHidMaestroRuntimeQualification {
 param($Qualification,$Invariants)
 try{
  if($Qualification.result -cne 'PASS' -or $Qualification.umdfHealthy -ne $true -or $Qualification.adapterInitialized -ne $true -or $Qualification.cleanupPassed -ne $true -or $Qualification.observations.Count -ne 8 -or @($Qualification.observations | Where-Object {$_.Observation.Matched -ne $true}).Count){return $false}
  if($Invariants.Result -cne 'PASS'){return $false}
  foreach($name in @('PhysicalUnchanged','SecurityUnchanged','TrustUnchanged','GameInputServiceUnchanged','MetadataClean','NoStaleDevice')){if($Invariants.$name -ne $true){return $false}}
  return $true
 }catch{return $false}
}
Export-ModuleMember -Function Get-ChatpadHidMaestroTrustDecision,Get-ChatpadDevelopmentCertificateState,ConvertTo-ChatpadHidMaestroInf,Test-ChatpadHidMaestroSecurityInvariant,Test-ChatpadHidMaestroCleanupIds,Test-ChatpadHidMaestroRuntimeQualification
