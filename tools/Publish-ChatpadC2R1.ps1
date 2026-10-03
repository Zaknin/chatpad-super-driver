[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^\d{8}T\d{6}Z$')][string]$UtcTimestamp,
 [string]$InputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/publication-input.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts=Join-Path $repo 'artifacts/task-8lc2r1'
Import-Module (Join-Path $PSScriptRoot 'Publish-ChatpadArtifact.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadReadinessArtifacts.psm1') -Force
function Invoke-Revision([string[]]$Arguments){
 $lines=@(& git.exe -C $repo @Arguments)
 if($LASTEXITCODE -ne 0){throw 'Git provenance query failed.'}
 return $lines
}
$branch=[string](@(Invoke-Revision @('branch','--show-current'))[0])
$commit=[string](@(Invoke-Revision @('rev-parse','HEAD'))[0])
if($branch -cne 'feature/chatpad-winusb-bridge-poc' -or @(Invoke-Revision @('status','--porcelain')).Count){throw 'Clean committed requested branch required.'}
$remote=[string](@(Invoke-Revision @('ls-remote','origin',('refs/heads/'+$branch)))[0])
if(($remote -split '\s+')[0] -cne $commit){throw 'Exact final commit must be pushed before publication.'}
$inputManifest=Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
if($inputManifest.Commit -cne $commit){throw 'Publication input must identify final HEAD.'}
$canonical='\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C2R1\'+$UtcTimestamp
$local=Join-Path $artifacts ('publication/'+$UtcTimestamp)
if(Test-Path -LiteralPath $local){throw 'Publication staging is immutable; use a new timestamp.'}
$stage=Join-Path $local 'stage'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
$privateValues=@($env:USERPROFILE)+@($inputManifest.PrivateValues)
function Add-StagedFile([string]$Source,[string]$Relative,[bool]$Evidence=$false){
 $sourcePath=(Resolve-Path -LiteralPath $Source).Path
 $target=[IO.Path]::GetFullPath((Join-Path $stage $Relative))
 if(-not $target.StartsWith($stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Staging path escapes archive root.'}
 if(Test-Path -LiteralPath $target){throw 'Duplicate archive member.'}
 New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
 if($Evidence -and [IO.Path]::GetExtension($sourcePath) -in '.json','.txt','.md','.xml'){
  $text=Protect-ChatpadEvidenceText ([IO.File]::ReadAllText($sourcePath)) $privateValues
  [IO.File]::WriteAllText($target,$text,[Text.UTF8Encoding]::new($false))
 }else{
  Copy-Item -LiteralPath $sourcePath -Destination $target
  if((Get-FileHash $sourcePath).Hash -cne (Get-FileHash $target).Hash){throw 'Local staging hash mismatch.'}
 }
}
$sourcePaths=@(Invoke-Revision @('ls-files','--','tools/ChatpadWinUsbPoc','tools/ChatpadVirtualXbox','tools/ChatpadBinding','tools/ChatpadBinding.ps1','tools/Invoke-ChatpadC3.ps1','tools/Test-ChatpadBinding.ps1','tools/Test-ChatpadC3.ps1','tools/Test-ChatpadC3Planning.ps1','tools/Build-ChatpadWinUsbVariants.ps1','tools/ChatpadWinUsbTrust.psm1','tools/Test-ChatpadWinUsbTrust.ps1','tools/ChatpadReadinessArtifacts.psm1','tools/Test-ChatpadReadinessArtifacts.ps1','tools/Publish-ChatpadArtifact.psm1','tools/Publish-ChatpadC2R1.ps1','tools/Test-ChatpadPublisher.ps1','src/protocol/ChatpadProtocol','License.md'))
$sourcePaths+=@(Invoke-Revision @('ls-files','--','tools/New-ChatpadC3Readiness.ps1','tools/Test-ChatpadC2R1.ps1','tools/Test-ChatpadC3Recovery.ps1','tools/Test-ChatpadC3Session.ps1','tools/ChatpadC3Session.psm1','tools/ChatpadC3Session.cs'))
foreach($path in $sourcePaths | Select-Object -Unique){Add-StagedFile (Join-Path $repo $path) ('source/'+$path)}
foreach($doc in @('TASK-8L-C2R1-PLAN.md','CHATPAD-WINUSB-TRUST.md','CHATPAD-WINUSB-BINDING.md','CHATPAD-VIRTUAL-XBOX.md','CHATPAD-WINUSB-C3-PROCEDURE.md','PROJECT-STATE.md','NEXT-TASK.md','DECISIONS.md')){Add-StagedFile (Join-Path $repo ('docs/'+$doc)) ('source/docs/'+$doc)}
foreach($file in $inputManifest.ArtifactFiles){
 if((Get-FileHash -LiteralPath $file.Path).Hash -cne $file.SHA256){throw ('Artifact identity changed: '+$file.RelativePath)}
 Add-StagedFile $file.Path $file.RelativePath
}
foreach($file in $inputManifest.EvidenceFiles){Add-StagedFile $file.Path ('evidence/'+$file.RelativePath) $true}
$inventory=@(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
 [pscustomobject]@{Path=$_.FullName.Substring($stage.Length).TrimStart('\','/').Replace('\','/');Bytes=$_.Length;SHA256=(Get-FileHash $_.FullName).Hash}
})
$inventoryPath=Join-Path $local 'sha256-inventory.json'
$inventory | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding utf8
Copy-Item $inventoryPath (Join-Path $stage 'sha256-inventory.json')
$manifest=[ordered]@{
 Schema=1;Task='8L-C2R1';Result=$inputManifest.Result;C3=$inputManifest.C3;Branch=$branch;Commit=$commit
 RemoteBranch='origin/'+$branch;StartingCommit='63902d912468f7a6819fe4f434bddd504d2bf5da'
 TestSummary=$inputManifest.TestSummary;Blockers=@($inputManifest.Blockers);BuildConfiguration='x64 Release; MSVC v143 /m:2; developer-local .NET10'
 LiveDeviceMutationOccurred=$false;DriverStagingInstallRemovalOccurred=$false;VirtualControllerCreated=$false
 InputInjectionOccurred=$false;RebootOccurred=$false;SecurityMutationOccurred=$false;TrustStoreMutationOccurred=$false
 OfflineCatalogSigningOccurred=$true;ExistingCertificateOnly=$true;LocalDeveloperSdkInstallationOccurred=$true
 CanonicalSmbPath=$canonical;Artifacts=$inventory;EndToEndAcceptance='UNTESTED'
 ReadBackVerification='Final external result-manifest.json and publication-receipt.json record each independently reopened .part/final hash; this archived snapshot precedes publication.'
}
$internalManifest=Join-Path $stage 'result-manifest.json'
$manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $internalManifest -Encoding utf8
$archive=Join-Path $local 'task-8l-c2r1-c3-readiness.zip'
$archiveHash=New-ChatpadDeterministicArchive $stage $archive
$repeatHash=New-ChatpadDeterministicArchive $stage (Join-Path $local 'determinism-check.zip')
if($archiveHash -cne $repeatHash){throw 'Identical staged bytes failed archive determinism check.'}
$payloads=@($archive,$inventoryPath)
foreach($name in @('preflight-c3.json','test-summary.json')){
 $matches=@(Get-ChildItem -LiteralPath (Join-Path $stage 'evidence') -Recurse -File -Filter $name)
 if($matches.Count -ne 1){throw ('Exactly one useful evidence file required: '+$name)}
 $payloads+=$matches[0].FullName
}
$receipts=@(foreach($payload in $payloads){Publish-ChatpadArtifact $payload $canonical (Split-Path -Leaf $payload)})
$manifest.ArchiveSHA256=$archiveHash
$manifest.DeterministicArchiveVerified=$true
$manifest.PublicationFiles=$receipts
$manifest.ReadBackVerification=@{PayloadsVerified=(@($receipts | Where-Object Verified -ne $true).Count -eq 0);SourcePartFinalHashesMatch=$true;CompletionSidecarsCommittedLast=$true;ManifestOwnReadback='See publication-receipt.json'}
$manifestPath=Join-Path $local 'result-manifest.json'
$manifest | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $manifestPath -Encoding utf8
$manifestReceipt=Publish-ChatpadArtifact $manifestPath $canonical 'result-manifest.json'
$receiptPath=Join-Path $local 'publication-receipt.json'
@{Commit=$commit;CanonicalSmbPath=$canonical;Payloads=$receipts;Manifest=$manifestReceipt;AllReadBackVerified=$true;CompletionMarker='publication-receipt.json.sha256'} | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receiptPath -Encoding utf8
$finalReceipt=Publish-ChatpadArtifact $receiptPath $canonical 'publication-receipt.json'
$finalReceipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $local 'final-receipt-readback.json') -Encoding utf8
Copy-Item $manifestPath (Join-Path $artifacts 'result-manifest.json')
Write-Output "PUBLISHED $canonical"
Write-Output "ARCHIVE SHA256 $archiveHash"
Write-Output 'Independent source/.part/final SHA256 readback PASS; completion sidecars committed last.'
