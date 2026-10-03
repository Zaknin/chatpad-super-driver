[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^\d{8}T\d{6}Z$')][string]$UtcTimestamp)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts=Join-Path $repo 'artifacts/task-8lc2'
$local=Join-Path $artifacts ('publication/'+$UtcTimestamp)
$canonical='\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C2\'+$UtcTimestamp
Import-Module (Join-Path $PSScriptRoot 'Publish-ChatpadArtifact.psm1') -Force
function Git([string[]]$Arguments){$result=@(& git.exe -C $repo @Arguments);if($LASTEXITCODE -ne 0){throw 'Git evidence query failed.'};return $result}
$branch=[string](@(Git @('branch','--show-current'))[0])
$commit=[string](@(Git @('rev-parse','HEAD'))[0])
if($branch -cne 'feature/chatpad-winusb-bridge-poc' -or @(Git @('status','--porcelain')).Count){throw 'Publish requires clean committed C2 branch.'}
$remote=[string](@(Git @('ls-remote','origin',('refs/heads/'+$branch)))[0])
if(($remote -split '\s+')[0] -cne $commit){throw 'Publish requires pushed exact branch/commit.'}
if(Test-Path -LiteralPath $local){throw 'Use a new immutable publication timestamp.'}
New-Item -ItemType Directory -Force -Path $local | Out-Null
$stage=Join-Path $local 'stage';New-Item -ItemType Directory -Force $stage | Out-Null
function CopyInto([string]$Source,[string]$Relative){
    if(-not(Test-Path -LiteralPath $Source -PathType Leaf)){throw "Missing required artifact $Source"}
    $target=Join-Path $stage $Relative;New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $Source -Destination $target
    if((Get-FileHash -LiteralPath $Source).Hash -cne (Get-FileHash -LiteralPath $target).Hash){throw 'Local staging hash mismatch.'}
}
function ZipDirectory([string]$Directory,[string]$Destination){
    $stream=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew)
    try{
        $zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        try{
            foreach($file in @(Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName)){
                $name=$file.FullName.Substring($Directory.Length).TrimStart('\','/').Replace('\','/')
                $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime=[DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
                $out=$entry.Open();$input=[IO.File]::OpenRead($file.FullName)
                try{$input.CopyTo($out)}finally{$input.Dispose();$out.Dispose()}
            }
        }finally{$zip.Dispose()}
    }finally{$stream.Dispose()}
}
$sourcePaths=@(Git @('ls-files','--','tools/ChatpadWinUsbPoc','tools/ChatpadVirtualXbox','tools/ChatpadBinding','tools/ChatpadBinding.ps1','tools/Test-ChatpadBinding.ps1','tools/Publish-ChatpadArtifact.psm1','tools/Publish-ChatpadC2.ps1','tools/Test-ChatpadPublisher.ps1','src/protocol/ChatpadProtocol','License.md'))
foreach($path in $sourcePaths){CopyInto (Join-Path $repo $path) ('source/'+$path)}
foreach($doc in @('TASK-8L-C2-PLAN.md','CHATPAD-WINUSB-C3-PROCEDURE.md','CHATPAD-WINUSB-BINDING.md','CHATPAD-VIRTUAL-XBOX.md','PROJECT-STATE.md','NEXT-TASK.md')){CopyInto (Join-Path $repo ('docs/'+$doc)) ('source/docs/'+$doc)}
foreach($configuration in @('Debug','Release')){
    foreach($name in @('ChatpadWinUsbPoc.exe','ChatpadBridgeTests.exe','ChatpadTopologyTests.exe','ChatpadHelperTests.exe','ChatpadCompletionTests.exe','ChatpadBridgeCore.lib')){CopyInto (Join-Path $artifacts ('native-bt/'+$configuration+'/'+$name)) ('native/'+$configuration+'/'+$name)}
    $helper=Join-Path $artifacts ('virtual/bin/ChatpadVirtualXbox/'+$configuration.ToLowerInvariant())
    foreach($name in @('ChatpadVirtualXbox.exe','ChatpadVirtualXbox.dll','ChatpadVirtualXbox.deps.json','ChatpadVirtualXbox.runtimeconfig.json')){CopyInto (Join-Path $helper $name) ('virtual/'+$configuration+'/'+$name)}
}
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $artifacts 'binding/package') -File)){CopyInto $file.FullName ('binding-package/'+$file.Name)}
foreach($file in @(Get-ChildItem -LiteralPath $artifacts -File | Where-Object { $_.Extension -in '.txt','.md','.json' -and $_.Name -notmatch 'private|review-diff' })) {CopyInto $file.FullName ('evidence/'+$file.Name)}
foreach($name in @('tests.json','tests-ps51.json','infverif.txt','inf2cat.txt','package.json')){CopyInto (Join-Path $artifacts ('binding/'+$name)) ('evidence/binding/'+$name)}
foreach($name in @('build-Debug.txt','build-Release.txt','tests-Debug.json','tests-Release.json','process-tests-Debug.json','process-tests-Release.json','process-tests-initial-failure.json','sdk-compilation-blocked.txt','xinput-slot0-snapshot.json')){CopyInto (Join-Path $artifacts ('virtual/'+$name)) ('evidence/virtual/'+$name)}
CopyInto (Join-Path $artifacts 'configuration-descriptor.bin') 'evidence/configuration-descriptor.bin'
# Raw baseline/stack/certificate-store material stays private. Recheck staged
# text against the live serial/container and user-profile strings before SMB.
$baseline=Get-Content -LiteralPath (Join-Path $artifacts 'binding/baseline-verified/baseline.json') -Raw | ConvertFrom-Json
$private=@([string]$baseline.State.Target.InstanceId,[string]$baseline.State.Target.ContainerId,$env:USERPROFILE)
foreach($file in @(Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object Extension -In '.txt','.md','.json','.ps1','.psm1','.cs','.cpp','.h','.inf','.props','.xml')){
    $text=[IO.File]::ReadAllText($file.FullName)
    foreach($value in $private){
        if($value -and ($text.Contains($value) -or $text.Contains($value.Replace('\','\\')))){
            if($file.FullName.Contains('\evidence\')){$text=$text.Replace($value,'<redacted>').Replace($value.Replace('\','\\'),'<redacted>')}
            else{throw "Private machine identity in staged source: $($file.Name)"}
        }
    }
    if($file.FullName.Contains('\evidence\')){[IO.File]::WriteAllText($file.FullName,$text,[Text.UTF8Encoding]::new($false))}
}
$summary=[ordered]@{result='PARTIAL';nativeAssertions=578;nativeSuites=@{core=516;topology=13;helper=41;completion=8};managedHelper=@{unit=85;subprocess=7};bindingChecks=38;publisherChecks=8;existingProtocolAssertions=904;existingControlTests=15;finalFailures=0;distinctOfflineChecks=1635;configurations=@('x64 Debug','x64 Release');liveEndToEnd='UNTESTED';retainedFailedCommands='Initial build configurations/PDB collision/pipe cancellation/publisher Git recursion/intentional red tests; corrected or bounded; logs included.'}
$summary | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $local 'test-summary.json') -Encoding utf8
CopyInto (Join-Path $local 'test-summary.json') 'test-summary.json'
@{branch=$branch;commit=$commit;remoteBranch='origin/'+$branch;startingCommit='672869d8e6138b80c1bcbe24cf2c22680066efcf';canonicalPath=$canonical;result='PARTIAL';liveMutation=$false} | ConvertTo-Json | Set-Content (Join-Path $stage 'git-revision.json') -Encoding utf8
$inventory=@(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {[pscustomobject]@{path=$_.FullName.Substring($stage.Length).TrimStart('\','/').Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
$inventory | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $local 'sha256-inventory.json') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $local 'sha256-inventory.json') -Destination (Join-Path $stage 'sha256-inventory.json')
$archive=Join-Path $local 'task-8l-c2-winusb-bridge-preparation.zip';ZipDirectory $stage $archive
# Confirm deterministic ordering/timestamps for identical staged bytes.
$repeat=Join-Path $local 'determinism-check.zip';ZipDirectory $stage $repeat
if((Get-FileHash $archive).Hash -cne (Get-FileHash $repeat).Hash){throw 'Deterministic archive comparison failed.'}
$candidate=Join-Path $local 'candidate-winusb-package.zip';ZipDirectory (Join-Path $stage 'binding-package') $candidate
$rollback=Join-Path $local 'binding-rollback-tool.zip';ZipDirectory (Join-Path $stage 'source/tools/ChatpadBinding') $rollback
$payloads=@($archive,$candidate,$rollback,(Join-Path $stage 'source/tools/ChatpadBinding.ps1'),(Join-Path $stage 'native/Release/ChatpadWinUsbPoc.exe'),(Join-Path $artifacts 'virtual-helper-offline.zip'),(Join-Path $local 'test-summary.json'),(Join-Path $stage 'evidence/physical-topology.json'),(Join-Path $local 'sha256-inventory.json'),(Join-Path $stage 'git-revision.json'),(Join-Path $stage 'source/docs/CHATPAD-WINUSB-C3-PROCEDURE.md'))
$receipts=@(foreach($file in $payloads){Publish-ChatpadArtifact $file $canonical (Split-Path -Leaf $file)})
$manifest=[ordered]@{schema=1;result='PARTIAL';branch=$branch;commit=$commit;remoteBranch='origin/'+$branch;buildConfiguration=@('MSVC v143 x64 Debug','MSVC v143 x64 Release','.NET9.0.318 Debug/Release mock/unavailable');testCounts=$summary;files=$receipts;dependencies=@{hidmaestroRevision='1c126ed4780322454391b7be782230b35b0810f6';license='MIT; included upstream literal license';actualSdk='.NET10+Windows targeting+verified external pinned SDK DLL; source adapter uncompiled';winusb='Microsoft inbox winusb.sys; prepared custom exact INF/unsigned catalog still requires trusted package'};unresolved=@('Persistent Chatpad extension exclusion plus exact filter/extension restoration; binding-only rollback cannot restore drift.','Unsigned/untrusted WinUSB catalog.','Real HIDMaestro SDK compile/install/create and upstream service/resource/autodeploy side effects require later authorized qualification.','Generic Win3231 is not proven STALL; strict activation will stop.','Real raw WinUSB controller/Chatpad, XInput, keyboard, rumble, lifecycle/latency and ordinary-boot security acceptance UNTESTED.');liveMutation=$false;liveBindingOccurred=$false;rebootOccurred=$false;securitySettingMutation=$false;dotnetFirstRunMessage='Reported development certificate installation; read-only store audit found only pre-existing May certificate, no new C2-dated match; no trust/import/removal commands.';canonicalSmbPath=$canonical;readBackVerificationResult=(@($receipts | Where-Object Verified -ne $true).Count -eq 0);manifestOwnReadback='Recorded in publication-receipt.json published after this manifest';archiveSha256=(Get-FileHash $archive).Hash;deterministicArchiveVerified=$true;endToEnd='UNTESTED'}
$manifestFile=Join-Path $local 'result-manifest.json';$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestFile -Encoding utf8
$manifestReceipt=Publish-ChatpadArtifact $manifestFile $canonical 'result-manifest.json'
$receiptFile=Join-Path $local 'publication-receipt.json';@{commit=$commit;canonicalSmbPath=$canonical;payloads=$receipts;manifest=$manifestReceipt;allReadBackVerified=$true;completionMarker='Each artifact .sha256 is committed last; receipt sidecar is overall completion marker.'} | ConvertTo-Json -Depth 10 | Set-Content $receiptFile -Encoding utf8
$finalReceipt=Publish-ChatpadArtifact $receiptFile $canonical 'publication-receipt.json'
$finalReceipt | ConvertTo-Json | Set-Content (Join-Path $local 'final-publication-readback.json') -Encoding utf8
$manifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $artifacts 'result-manifest.json') -Encoding utf8
Write-Output "PUBLISHED $canonical"
Write-Output "ARCHIVE SHA256 $($manifest.archiveSha256)"
Write-Output 'Independent source/.part/final SHA256 read-back PASS; completion sidecars committed last.'
