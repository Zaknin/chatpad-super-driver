[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$CanonicalDirectory,
 [Parameter(Mandatory)][string]$PublicationProbeReceiptPath,
 [string]$OutputPath=(Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/readiness-input.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$artifacts=Join-Path $repo 'artifacts/task-8lc2r1'
$trust=Get-Content -LiteralPath (Join-Path $artifacts 'trust-final/trust-report.json') -Raw | ConvertFrom-Json
$integration=Get-Content -LiteralPath (Join-Path $artifacts 'virtual/integration-report.json') -Raw | ConvertFrom-Json
$baseline=Get-Content -LiteralPath (Join-Path $repo 'artifacts/task-8lc2/binding/baseline-verified/baseline.json') -Raw | ConvertFrom-Json
$probe=Get-Content -LiteralPath $PublicationProbeReceiptPath -Raw | ConvertFrom-Json
if(-not $probe.Verified -or -not $probe.SidecarCommittedLast -or (Split-Path -Parent $probe.Path) -ine $CanonicalDirectory -or (Get-FileHash -LiteralPath $probe.Path).Hash -ine $probe.SHA256){throw 'Independently verified canonical publication probe required.'}
function Record([string]$Role,[string]$Path){
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Missing $Role prerequisite: $Path"}
 [pscustomobject]@{Role=$Role;Path=(Resolve-Path -LiteralPath $Path).Path;SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
}
$files=@()
foreach($f in @($trust.Files | Where-Object Variant -eq 'signed')){
 if((Get-FileHash $f.Path).Hash -cne $f.SHA256){throw 'Signed package hash drift.'}
 $role=if($f.Role -eq 'WinUsbCatalog'){'WinUsbCat'}else{$f.Role}
 $files+=Record $role $f.Path
}
$native=Join-Path $artifacts 'native/native-bt/Release/ChatpadWinUsbPoc.exe'
$helper=Join-Path $artifacts 'virtual/real/bin/ChatpadVirtualXbox/release'
$files+=Record 'Poc' $native
$files+=Record 'VirtualBackend' (Join-Path $helper 'ChatpadVirtualXbox.exe')
foreach($file in @(Get-ChildItem -LiteralPath $helper -File | Where-Object Extension -ne '.pdb')){$files+=Record ('VirtualFile:'+ $file.Name) $file.FullName}
$dotnet='C:/Dev/tools/dotnet10/dotnet.exe'
$files+=Record 'Dotnet' $dotnet
$m=$baseline.State.Target
$msInf=@($baseline.Files | Where-Object Name -eq 'xusb22.inf')[0]
$msSys=@($baseline.Files | Where-Object { $_.Name -eq 'xusb22.sys' -and $_.SourcePath -like '*DriverStore*' })[0]
foreach($source in @($msInf,$msSys)){if((Get-FileHash $source.SourcePath).Hash -cne $source.SHA256){throw 'Original Microsoft restoration source changed.'}}
$recovery=Join-Path $artifacts 'recovery/extension'
New-Item -ItemType Directory -Path $recovery -Force | Out-Null
$extensionFiles=@()
foreach($file in @($baseline.Files | Where-Object Name -in @('ChatpadFilterExtension.inf','ChatpadFilterExtension.cat','ChatpadFilter.sys'))){
 $local=(Join-Path (Split-Path -Parent (Join-Path $repo 'artifacts/task-8lc2/binding/baseline-verified/baseline.json')) $file.RelativePath)
 if((Get-FileHash $local).Hash -cne $file.SHA256){throw 'Retained extension recovery bytes changed.'}
 $target=Join-Path $recovery $file.Name
 if(Test-Path -LiteralPath $target){if((Get-FileHash $target).Hash -cne $file.SHA256){throw 'Recovery snapshot overwrite refused.'}}else{Copy-Item -LiteralPath $local -Destination $target}
 $extensionFiles+=Record 'ExtensionRestore' $target
}
$currentHead=[string](& git.exe -C $repo rev-parse HEAD)
if($LASTEXITCODE -ne 0){throw 'Git HEAD query failed.'}
$branch=[string](& git.exe -C $repo branch --show-current)
if($LASTEXITCODE -ne 0){throw 'Git branch query failed.'}
$security=Get-Content -LiteralPath (Join-Path $artifacts 'security-state.json') -Raw | ConvertFrom-Json
$inputManifest=[ordered]@{
 Schema=1;Repository=@{Branch=$branch;Commit=$currentHead};Files=$files
 Microsoft=@{InfPath=$msInf.SourcePath;InfSHA256=$msInf.SHA256;Provider=$m.Provider;Section=$m.Section;Version=$m.Version;PackageFiles=@((Record 'MicrosoftInf' $msInf.SourcePath),(Record 'MicrosoftKernel' $msSys.SourcePath));SourceSignatureVerified=$true;CandidateVerified=$false}
 ExtensionRestore=@{InfPath=(Join-Path $recovery 'ChatpadFilterExtension.inf');Version='1.0.14.0';Files=$extensionFiles;NormalWindowsLoadExpected=$false;Reason='Optional fallback SYS remains test-signed; normal-mode healthy restoration is not authorized/proven.'}
 Trust=$trust.Trust
 Dependencies=@{Available=$integration.runtime.availability.runtimeReady;Reason=$integration.runtime.availability.reason;DotnetPath=$dotnet;VirtualAssembly=(Join-Path $helper 'ChatpadVirtualXbox.dll')}
 Security=@{QuerySucceeded=$security.CodeIntegrity.QuerySucceeded;TestSigning=$security.CodeIntegrity.TestSigning;Hvci=$security.CodeIntegrity.Hvci;SecureBoot=$security.SecureBoot}
 CanonicalDirectory=$CanonicalDirectory;CanonicalWritable=$true;CanonicalWriteProof=$probe
 LocalOnly=$true;PrivateIdentityInSources='Retained private C2 baseline stays local; public outputs redact instance/container/profile.'
}
$inputManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output "Prepared hash-pinned C3 input: $OutputPath; live preflight must revalidate target, security, signatures and runtime."
