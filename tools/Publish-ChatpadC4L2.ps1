[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidateSet('Prepare','Publish')][string]$Mode,
 [Parameter(Mandatory)][ValidatePattern('^\d{8}T\d{6}Z$')][string]$UtcTimestamp,
 [Parameter(Mandatory)][string]$BuildDirectory,
 [string]$ArtifactsDirectory,
 [string]$VerificationSummaryPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $ArtifactsDirectory){$ArtifactsDirectory=Join-Path $repo 'artifacts/task-8lc4l2'}
$artifacts=[IO.Path]::GetFullPath($ArtifactsDirectory)
$artifactRoot=[IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $artifacts.StartsWith($artifactRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'C4L2 evidence must remain under ignored artifacts.'}
$build=(Resolve-Path -LiteralPath $BuildDirectory).Path
$package=(Resolve-Path -LiteralPath (Join-Path $build 'package')).Path
$manifestPath=Join-Path $build 'build-manifest.json'
if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Release build manifest is missing.'}
if(-not $VerificationSummaryPath){$VerificationSummaryPath=Join-Path $build 'release-verification.json'}
if(-not(Test-Path -LiteralPath $VerificationSummaryPath -PathType Leaf)){throw 'Focused offline verification summary is missing.'}
$verification=Get-Content -LiteralPath $VerificationSummaryPath -Raw|ConvertFrom-Json
if($verification.Result -cne 'PASS' -or $verification.Managed.Failed -ne 0 -or $verification.Native.Passed -ne 3 -or $verification.Native.Failed -ne 0 -or $verification.Setup.Result -cne 'PASS' -or $verification.ReadinessArtifacts.Failed -ne 0 -or $verification.RepositorySafety.Result -cne 'PASS'){
 throw 'Focused offline verification summary is incomplete or contains failures.'
}
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4Package.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadReadinessArtifacts.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Publish-ChatpadArtifact.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4L2Publication.psm1') -Force

function Git([string[]]$Arguments){$lines=@(& git.exe -C $repo @Arguments);if($LASTEXITCODE -ne 0){throw ('Git command failed: '+($Arguments -join ' '))};return $lines}
function Get-RepositoryIdentity {
 $branch=[string](@(Git @('branch','--show-current'))[0])
 $commit=[string](@(Git @('rev-parse','HEAD'))[0])
 if($branch -cne 'feature/chatpad-usermode-runner' -or [string]::IsNullOrWhiteSpace($commit)){throw 'C4L2 release requires the feature/chatpad-usermode-runner branch.'}
 if(@(Git @('status','--porcelain')).Count){throw 'C4L2 release requires a clean committed worktree.'}
 $remoteLine=[string](@(Git @('ls-remote','origin',('refs/heads/'+$branch)))[0])
 if(($remoteLine -split '\s+')[0] -cne $commit){throw 'Exact C4L2 source commit must be pushed before package publication.'}
 [pscustomobject]@{Branch=$branch;Commit=$commit}
}
function Get-PackageInventory {
 param([string]$Root)
 @(Get-ChildItem -LiteralPath $Root -File -Recurse|Sort-Object FullName|ForEach-Object {
  if($_.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Package inventory refuses reparse files: $($_.FullName)"}
  [pscustomobject]@{Path=$_.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/');Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
 })
}
function Assert-PackageMatchesBuildManifest {
 param($BuildManifest,[object[]]$Inventory)
 $declared=@($BuildManifest.Files|ForEach-Object {[pscustomobject]@{Path=([string]$_.Path).Replace('\','/');Bytes=[long]$_.Length;SHA256=[string]$_.SHA256}}|Sort-Object Path)
 $actual=@($Inventory|Sort-Object Path)
 if($declared.Count -ne $actual.Count){throw 'Build manifest file set differs from the package directory.'}
 for($i=0;$i -lt $declared.Count;$i++){
  if($declared[$i].Path -cne $actual[$i].Path -or $declared[$i].Bytes -ne $actual[$i].Bytes -or $declared[$i].SHA256 -cne $actual[$i].SHA256){throw "Build-manifest/package hash or length mismatch: $($actual[$i].Path)"}
 }
}
function Assert-InventoryMatches {
 param([object[]]$Expected,[object[]]$Actual)
 $left=@($Expected|Sort-Object Path);$right=@($Actual|Sort-Object Path)
 if($left.Count -ne $right.Count){throw 'Prepared package inventory length changed.'}
 for($i=0;$i -lt $left.Count;$i++){
  if([string]$left[$i].Path -cne [string]$right[$i].Path -or [long]$left[$i].Bytes -ne [long]$right[$i].Bytes -or [string]$left[$i].SHA256 -cne [string]$right[$i].SHA256){throw "Prepared package member changed after archive creation: $($right[$i].Path)"}
 }
}
function Get-OfflineEvidence {
 param($Inventory,$Verification)
 [ordered]@{
  Schema=1;Task='8L-C4L2';Result='PARTIAL';Scope='Offline implementation and package qualification only'
  Tests=[ordered]@{ManagedSuite=$Verification.Managed.Passed;ManagedFailures=$Verification.Managed.Failed;FocusedNativeCTest=$Verification.Native.Passed;FocusedNativeFailures=$Verification.Native.Failed;SetupRepositoryIdentity=$Verification.Setup.RepositoryIdentity;SetupPackageIdentity=$Verification.Setup.PackageIdentity;SetupBaseline=$Verification.Setup.Baseline;SetupPnPResult=$Verification.Setup.PnPResult;ReadinessArtifacts=$Verification.ReadinessArtifacts.Passed;RepositorySafety='PASS'}
  Package=[ordered]@{Members=@($Inventory).Count;ExactMemberSetVerified=$true;AllLengthsAndSHA256Verified=$true;SelfContainedWinX64=$true}
  Live=[ordered]@{ServiceInstallation='UNTESTED';ServiceLifecycle='UNTESTED';IPCAuthentication='OFFLINE_POLICY_TESTED_LIVE_UNTESTED';XInput='UNTESTED';Chatpad='UNTESTED';RumbleCallback='UNTESTED';Reconnect='UNTESTED';GracefulCleanup='UNTESTED';ClientCrashRecovery='UNTESTED';ServiceCrashRecovery='UNTESTED'}
  Safety=[ordered]@{ElevatedServiceInstallPerformed=$false;DriverBindingChanged=$false;PnPMutated=$false;RegistryMutated=$false;DeviceCreated=$false;TrustChanged=$false;Rebooted=$false}
 }
}

$buildManifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
if($buildManifest.Task -cne '8L-C4L2' -or $buildManifest.C4Tests -cne 'PASS'){throw 'Build manifest task or setup test result is invalid.'}
$identity=Get-RepositoryIdentity
$buildCommit=[string]$buildManifest.Repository.Commit
if($Mode -eq 'Prepare'){
 if($buildManifest.Repository.Branch -cne $identity.Branch -or $buildCommit -cne $identity.Commit){throw 'Prepare requires a fresh package built from exact current branch and commit.'}
 $readinessPath=Join-Path $artifacts 'readiness-input.json'
 if(-not(Test-Path -LiteralPath $readinessPath -PathType Leaf)){throw 'C4L2 readiness package identity is missing.'}
 $readiness=Get-Content -LiteralPath $readinessPath -Raw|ConvertFrom-Json
 if($readiness.Repository.Branch -cne $identity.Branch -or $readiness.Repository.Commit -cne $identity.Commit){throw 'Readiness branch/commit differs from the exact committed package source.'}
 if((Get-ChatpadC4ReadinessPackageRoot $readiness) -cne [IO.Path]::GetFullPath($package)){throw 'Readiness package root differs from the requested release package.'}
 Assert-ChatpadC4PackageIdentity $readiness $package (Join-Path $PSScriptRoot 'ChatpadSetup.ps1')|Out-Null
 $inventory=Get-PackageInventory $package
 Assert-PackageMatchesBuildManifest $buildManifest $inventory
 $local=Join-Path $artifacts ('publication/'+$UtcTimestamp)
 if(Test-Path -LiteralPath $local){throw 'C4L2 publication staging is immutable; choose a fresh UTC timestamp.'}
 New-Item -ItemType Directory -Path $local -Force|Out-Null
 $stage=Join-Path $local 'archive-stage';$packageStage=Join-Path $stage 'package'
 New-Item -ItemType Directory -Path $packageStage -Force|Out-Null
 foreach($record in $inventory){$from=Join-Path $package ($record.Path.Replace('/','\'));$to=Join-Path $packageStage ($record.Path.Replace('/','\'));New-Item -ItemType Directory -Path (Split-Path -Parent $to) -Force|Out-Null;Copy-Item -LiteralPath $from -Destination $to;if((Get-FileHash $from).Hash -cne (Get-FileHash $to).Hash){throw "Archive-stage package copy hash mismatch: $($record.Path)"}}
 $inventory|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $stage 'package-sha256-inventory.json') -Encoding utf8
 $offline=Get-OfflineEvidence $inventory $verification
 $offline|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $stage 'offline-evidence.json') -Encoding utf8
 $archive=Join-Path $local 'task-8l-c4l2-release.zip'
 $archiveHash=New-ChatpadDeterministicArchive $stage $archive
 $second=Join-Path $local 'determinism-check.zip'
 if((New-ChatpadDeterministicArchive $stage $second) -cne $archiveHash){throw 'C4L2 deterministic archive repeat hash mismatch.'}
 $prepared=[ordered]@{Schema=1;Task='8L-C4L2';UtcTimestamp=$UtcTimestamp;Branch=$identity.Branch;BuildCommit=$buildCommit;CanonicalPath=('\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\'+$UtcTimestamp);BuildDirectory=$build;PackageRoot=$package;ArchivePath=$archive;ArchiveSHA256=$archiveHash;PackageInventoryPath=(Join-Path $stage 'package-sha256-inventory.json');PackageInventorySHA256=(Get-FileHash (Join-Path $stage 'package-sha256-inventory.json')).Hash;OfflineEvidencePath=(Join-Path $stage 'offline-evidence.json');ArchiveMembers=@(Get-ChildItem -LiteralPath $stage -Recurse -File).Count;PackageMembers=$inventory.Count;PreparedUtc=[DateTime]::UtcNow.ToString('o')}
 $prepared|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $local 'prepared-release.json') -Encoding utf8
 Write-Output "PREPARED $($prepared.CanonicalPath)"
 Write-Output "ARCHIVE SHA256 $archiveHash"
 Write-Output "PACKAGE MEMBERS $($inventory.Count); exact readiness/build-manifest hashes PASS; deterministic repeat PASS"
 return
}

$preparedPath=Join-Path (Join-Path $artifacts ('publication/'+$UtcTimestamp)) 'prepared-release.json'
if(-not(Test-Path -LiteralPath $preparedPath -PathType Leaf)){throw 'Prepared C4L2 archive is missing; run -Mode Prepare before updating continuity documentation.'}
$prepared=Get-Content -LiteralPath $preparedPath -Raw|ConvertFrom-Json
if($prepared.UtcTimestamp -cne $UtcTimestamp -or $prepared.Branch -cne $identity.Branch -or $prepared.CanonicalPath -cne ('\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\'+$UtcTimestamp)){throw 'Prepared release identity or destination differs from the requested publication.'}
if(-not(Test-Path -LiteralPath $prepared.ArchivePath -PathType Leaf) -or (Get-FileHash $prepared.ArchivePath).Hash -cne $prepared.ArchiveSHA256){throw 'Prepared deterministic archive hash mismatch.'}
if($identity.Commit -cne $prepared.BuildCommit){
 $allowed=@('docs/PROJECT-STATE.md','docs/WORKLOG.md','docs/NEXT-TASK.md')
 $changed=@(Git @('diff','--name-only',([string]$prepared.BuildCommit),$identity.Commit))
 if(@($changed|Where-Object {$_ -notin $allowed}).Count -or -not $changed.Count){throw 'Only the documented continuity files may change after package preparation; rebuild if implementation files changed.'}
}
$inventory=Get-PackageInventory $package
$inventoryPath=[string]$prepared.PackageInventoryPath
$archivedInventory=Get-Content -LiteralPath $inventoryPath -Raw|ConvertFrom-Json
Assert-InventoryMatches @($archivedInventory) $inventory
$buildCommitIdentity=[string]$buildManifest.Repository.Commit
if($buildCommitIdentity -cne [string]$prepared.BuildCommit){throw 'Build manifest changed since archive preparation.'}

# Rebind readiness metadata to the exact pushed release commit. The post-build commit is restricted above to continuity documents only.
$readinessPath=Join-Path $artifacts 'readiness-input.json'
& (Join-Path $PSScriptRoot 'New-ChatpadC4Readiness.ps1') -RunnerPath (Join-Path $package 'ChatpadBridge.exe') -HelperDirectory $package -OutputPath $readinessPath
if($LASTEXITCODE -ne 0){throw 'Final commit-bound readiness regeneration failed.'}
$readiness=Get-Content -LiteralPath $readinessPath -Raw|ConvertFrom-Json
if($readiness.Repository.Branch -cne $identity.Branch -or $readiness.Repository.Commit -cne $identity.Commit){throw 'Final readiness identity does not match the pushed branch/commit.'}
Assert-ChatpadC4PackageIdentity $readiness $package (Join-Path $PSScriptRoot 'ChatpadSetup.ps1')|Out-Null
$members=@($readiness.Files|Where-Object Role -like 'VirtualFile:*' | ForEach-Object {[pscustomobject]@{Name=([string]$_.Role).Substring('VirtualFile:'.Length);SHA256=[string]$_.SHA256;Bytes=(Get-Item -LiteralPath $_.Path).Length}}|Sort-Object Name)
$setupMember=@($readiness.Files|Where-Object Role -ceq 'SetupTool')[0]
$publicIdentity=[ordered]@{Schema=1;Task='8L-C4L2';Repository=$identity;PackageArchiveMemberRoot='package/';SetupToolSHA256=$setupMember.SHA256;RuntimeMembers=$members;ExactMemberSetVerified=$true;PackageBuildCommit=$prepared.BuildCommit;ReleaseIdentityCommit=$identity.Commit}
$publicIdentityPath=Join-Path (Split-Path -Parent $preparedPath) 'readiness-identity.json'
$publicIdentity|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $publicIdentityPath -Encoding utf8
$evidence=Get-Content -LiteralPath $prepared.OfflineEvidencePath -Raw|ConvertFrom-Json
$result=[ordered]@{
 Schema=1;Task='8L-C4L2';Result='PARTIAL';Branch=$identity.Branch;Commit=$identity.Commit;PackageBuildCommit=$prepared.BuildCommit
 CanonicalPath=$prepared.CanonicalPath;ArchiveSHA256=$prepared.ArchiveSHA256;DeterministicArchiveVerified=$true
 OfflineEvidence=$evidence;ReadinessIdentityPath='readiness-identity.json';LocalReadinessIdentityVerified=$true
 ServiceInstallation='USER_INSTALL_AND_REPAIR_PASS';ServiceLifecycle='RUNNING; LIFECYCLE_QUALIFICATION_PENDING';IPCAuthentication='OFFLINE_POLICY_PASS_LIVE_UNTESTED';NormalUserRuntime='PENDING_STARTUP_FIX_RETRY'
 XInput='UNTESTED';Chatpad='UNTESTED';Rumble='UNTESTED';Reconnect='UNTESTED';CrashRecovery='UNTESTED'
 LiveGateCommand='Run the package ChatpadBridge.exe run from an ordinary, non-elevated PowerShell and return the complete output.'
 PublicationReadback='Pending'
}
$destination=[string]$prepared.CanonicalPath
$payloads=@(
 [pscustomobject]@{Path=$prepared.ArchivePath;Name='task-8l-c4l2-release.zip'},
 [pscustomobject]@{Path=$inventoryPath;Name='package-sha256-inventory.json'},
 [pscustomobject]@{Path=$prepared.OfflineEvidencePath;Name='offline-evidence.json'},
 [pscustomobject]@{Path=$publicIdentityPath;Name='readiness-identity.json'}
)
$receipts=@(foreach($item in $payloads){Publish-ChatpadArtifact -SourcePath $item.Path -DestinationDirectory $destination -FileName $item.Name})
if(-not (Test-ChatpadC4L2PublicationReceipts $receipts)){throw 'At least one atomic publisher payload failed source/.part/final readback.'}
$result.PublicationReadback='PASS'
$result.PayloadReceipts=$receipts
$resultPath=Join-Path (Split-Path -Parent $preparedPath) 'result-manifest.json'
$result|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $resultPath -Encoding utf8
$manifestReceipt=Publish-ChatpadArtifact -SourcePath $resultPath -DestinationDirectory $destination -FileName 'result-manifest.json'
$allReceipts=@($receipts)+@($manifestReceipt)
$receiptPath=Join-Path (Split-Path -Parent $preparedPath) 'publication-receipt.json'
$receiptData=[ordered]@{Schema=1;Task='8L-C4L2';CanonicalPath=$destination;Branch=$identity.Branch;Commit=$identity.Commit;ArchiveSHA256=$prepared.ArchiveSHA256;Payloads=$allReceipts;AllSourcePartFinalHashesVerified=$true;CompletionMarker='publication-receipt.json.sha256'}
$receiptData|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $receiptPath -Encoding utf8
$receipt=Publish-ChatpadArtifact -SourcePath $receiptPath -DestinationDirectory $destination -FileName 'publication-receipt.json'
$final=[ordered]@{Receipt=$receipt;ArchiveSHA256=$prepared.ArchiveSHA256;CanonicalPath=$destination;Readback=$allReceipts}
$finalPath=Join-Path (Split-Path -Parent $preparedPath) 'final-receipt-readback.json'
$final|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $finalPath -Encoding utf8
$result|ConvertTo-Json -Depth 14|Set-Content -LiteralPath (Join-Path $artifacts 'result-manifest.json') -Encoding utf8
Write-Output "PUBLISHED $destination"
Write-Output "ARCHIVE SHA256 $($prepared.ArchiveSHA256)"
Write-Output "PAYLOADS $(@($allReceipts).Count); source/.part/final readbacks and sidecars PASS; completion receipt committed last"
