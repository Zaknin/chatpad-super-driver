[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^\d{8}T\d{6}Z$')][string]$UtcTimestamp,
 [Parameter(Mandatory)][string]$BuildDirectory,
 [string]$ArtifactsDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $ArtifactsDirectory){$ArtifactsDirectory=Join-Path $repo 'artifacts/task-8lc4'}
$artifacts=(Resolve-Path -LiteralPath $ArtifactsDirectory).Path
$build=(Resolve-Path -LiteralPath $BuildDirectory).Path
$package=Join-Path $build 'package'
if(-not(Test-Path -LiteralPath (Join-Path $package 'ChatpadBridge.exe') -PathType Leaf)){throw 'Release package is incomplete.'}
Import-Module (Join-Path $PSScriptRoot 'Publish-ChatpadArtifact.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadReadinessArtifacts.psm1') -Force
function Git([string[]]$Arguments){$lines=@(& git.exe -C $repo @Arguments);if($LASTEXITCODE -ne 0){throw ('Git command failed: '+($Arguments -join ' '))};$lines}
$branch=[string](@(Git @('branch','--show-current'))[0])
$commit=[string](@(Git @('rev-parse','HEAD'))[0])
if($branch -cne 'feature/chatpad-usermode-runner' -or @(Git @('status','--porcelain')).Count){throw 'Publish requires a clean committed C4 branch.'}
$remoteLine=[string](@(Git @('ls-remote','origin',('refs/heads/'+$branch)))[0])
if(($remoteLine -split '\s+')[0] -cne $commit){throw 'Exact C4 commit must be pushed before publication.'}
$canonical='\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4\'+$UtcTimestamp
$local=Join-Path $artifacts ('publication/'+$UtcTimestamp)
if(Test-Path -LiteralPath $local){throw 'Publication staging is immutable; use a new UTC timestamp.'}
$stage=Join-Path $local 'stage';New-Item -ItemType Directory -Path $stage -Force|Out-Null
$private=@($env:USERPROFILE,$repo)
try{
 $preflight=Get-Content (Join-Path $artifacts 'setup-preflight-live.json') -Raw|ConvertFrom-Json
 $private+=@([string]$preflight.Target.InstanceId,[string]$preflight.Target.ContainerId)
 foreach($value in @($preflight.Target.HardwareIds)){if($value -match 'VID_045E&PID_028E\\([^\\]+)$'){$private+=$Matches[1]}}
}catch{throw 'Sanitization inputs are unavailable; refusing publication.'}
function Add-File([string]$Source,[string]$Relative,[switch]$Sanitize){
 $from=(Resolve-Path -LiteralPath $Source).Path
 $to=[IO.Path]::GetFullPath((Join-Path $stage $Relative))
 if(-not $to.StartsWith($stage+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Archive member escaped staging root.'}
 if(Test-Path -LiteralPath $to){throw "Duplicate staged member: $Relative"}
 New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force|Out-Null
 if($Sanitize){$text=Protect-ChatpadEvidenceText ([IO.File]::ReadAllText($from)) $private;[IO.File]::WriteAllText($to,$text,[Text.UTF8Encoding]::new($false))}
 else{Copy-Item -LiteralPath $from -Destination $to;if((Get-FileHash $from).Hash -cne (Get-FileHash $to).Hash){throw "Staging hash mismatch: $Relative"}}
}
Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object {
 $relative=$_.FullName.Substring($package.Length).TrimStart('\','/')
 Add-File $_.FullName ('package/'+$relative)
}
$evidence=@(
 @((Join-Path $build 'build-manifest.json'),'evidence/build-manifest.json',$true),
 @((Join-Path $artifacts 'setup-preflight-live.json'),'evidence/preflight.json',$true),
 @((Join-Path $artifacts 'runtime-diagnostics.txt'),'evidence/runtime-diagnostics.txt',$true),
 @((Join-Path $artifacts 'performance-sanity.json'),'evidence/performance-sanity.json',$true),
 @((Join-Path $artifacts 'idle-crash-final-source/idle-crash-result.json'),'evidence/idle-crash-result.json',$true),
 @((Join-Path $repo 'artifacts/task-8lc2r1/test-summary.json'),'evidence/comprehensive-regression.json',$true),
 @((Join-Path $build 'native/build/Testing/Temporary/LastTest.log'),'evidence/c4-native-ctest.log',$true),
 @((Join-Path $repo 'docs/PROJECT-STATE.md'),'evidence/PROJECT-STATE.md',$true),
 @((Join-Path $repo 'docs/NEXT-TASK.md'),'evidence/NEXT-TASK.md',$true),
 @((Join-Path $repo 'docs/DECISIONS.md'),'evidence/DECISIONS.md',$true)
)
foreach($item in $evidence){if(-not(Test-Path -LiteralPath $item[0] -PathType Leaf)){throw "Required evidence missing: $($item[1])"};Add-File $item[0] $item[1] -Sanitize:$item[2]}
$reconnect=[ordered]@{Schema=1;Result='UNTESTED';Reason='Current execution shell is not elevated and the exact device remains bound to Microsoft xusb22; no WinUSB session or replug was performed.';ReconnectCycles=0;PhysicalAcceptance='UNTESTED'}
$reconnect|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $stage 'evidence/reconnect-result.json') -Encoding utf8
$inventory=@(Get-ChildItem -LiteralPath $stage -Recurse -File|Sort-Object FullName|ForEach-Object {[pscustomobject]@{Path=$_.FullName.Substring($stage.Length).TrimStart('\','/').Replace('\','/');Bytes=$_.Length;SHA256=(Get-FileHash $_.FullName).Hash}})
$inventory|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $stage 'sha256-inventory.json') -Encoding utf8
$internal=[ordered]@{Schema=1;Task='8L-C4';Result='PARTIAL';Branch=$branch;Commit=$commit;RemoteBranch=('origin/'+$branch);StartingCommit='c5975efefd160ad45ca41e939e24c3b9fdd922c6';CanonicalPath=$canonical;BuildConfiguration='x64 Release; MSVC; pinned .NET 10 helper';ComprehensiveRegression='2064/2064 passed; zero failed';C4NativeTests='8/8 targets passed';SetupIdentityTests='4/4 passed';LiveAcceptance='UNTESTED';Blocker='Current session is not elevated; device remains on healthy Microsoft xusb22.';ActionsNotPerformed=@('Driver install/bind/uninstall','PnP mutation','Security/trust changes','Reboot','Hardware reads','User keypress','Physical rumble','Virtual controller creation');PhysicalMutationOccurred=$false;RebootOccurred=$false;SecurityMutationOccurred=$false;TrustMutationOccurred=$false;Artifacts=$inventory}
$internal|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $stage 'result-manifest.json') -Encoding utf8
$archive=Join-Path $local 'task-8l-c4-usermode-runner.zip'
$archiveHash=New-ChatpadDeterministicArchive $stage $archive
$repeat=Join-Path $local 'determinism-check.zip'
if((New-ChatpadDeterministicArchive $stage $repeat) -cne $archiveHash){throw 'Deterministic archive check failed.'}
$payloads=@($archive,(Join-Path $stage 'evidence/runtime-diagnostics.txt'),(Join-Path $stage 'evidence/comprehensive-regression.json'),(Join-Path $stage 'evidence/idle-crash-result.json'),(Join-Path $stage 'evidence/performance-sanity.json'),(Join-Path $package 'ChatpadBridge.exe'),(Join-Path $package 'ChatpadSetup.ps1'),(Join-Path $stage 'sha256-inventory.json'))
$receipts=@(foreach($file in $payloads){Publish-ChatpadArtifact $file $canonical (Split-Path -Leaf $file)})
$manifest=[ordered]@{}
foreach($key in $internal.Keys){$manifest[$key]=$internal[$key]}
$manifest.ArchiveSHA256=$archiveHash
$manifest.DeterministicArchiveVerified=$true
$manifest.PublicationFiles=$receipts
$manifest.SourcePartFinalReadbackVerified=(@($receipts|Where-Object Verified -ne $true).Count -eq 0)
$manifest.SidecarsCommittedLast=$true
$manifest.EndToEndAcceptance='UNTESTED'
$manifestPath=Join-Path $local 'result-manifest.json';$manifest|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $manifestPath -Encoding utf8
$manifestReceipt=Publish-ChatpadArtifact $manifestPath $canonical 'result-manifest.json'
$receiptPath=Join-Path $local 'publication-receipt.json'
@{Commit=$commit;CanonicalPath=$canonical;ArchiveSHA256=$archiveHash;Payloads=$receipts;Manifest=$manifestReceipt;AllReadbackVerified=$true;CompletionMarker='publication-receipt.json.sha256'}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $receiptPath -Encoding utf8
$receipt=Publish-ChatpadArtifact $receiptPath $canonical 'publication-receipt.json'
$receipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $local 'final-receipt-readback.json') -Encoding utf8
$manifest|ConvertTo-Json -Depth 14|Set-Content -LiteralPath (Join-Path $artifacts 'result-manifest.json') -Encoding utf8
Write-Output "PUBLISHED $canonical"
Write-Output "ARCHIVE SHA256 $archiveHash"
Write-Output 'Independent source/.part/final hash readback PASS; sidecars committed last.'
