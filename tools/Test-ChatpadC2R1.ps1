[CmdletBinding()]
param([string]$DotnetPath='C:/Dev/tools/dotnet10/dotnet.exe',[switch]$BuildOnly)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$root=Join-Path $repo 'artifacts/task-8lc2r1'
$logs=Join-Path $root 'regression'
New-Item -ItemType Directory $logs -Force | Out-Null
$env:DOTNET_ROOT=Split-Path $DotnetPath -Parent
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
$virtual=Join-Path $root 'virtual/real'
function Run([string]$Name,[string]$File,[string[]]$Arguments){
 $lines=@(& $File @Arguments 2>&1);$code=$LASTEXITCODE
 $lines | Set-Content (Join-Path $logs ($Name+'.txt')) -Encoding utf8
 if($code -ne 0){throw "$Name failed exit=$code; retained log."}
 Write-Host "$Name PASS"
 return ($lines -join "`n")
}
$pwsh=(Get-Process -Id $PID).Path
if(-not $BuildOnly){
 $suites=[Collections.Generic.List[object]]::new()
 function Count([string]$Name,[int]$Total){if($Total -le 0){throw "Missing test count: $Name"};$suites.Add([pscustomobject]@{Suite=$Name;Passed=$Total;Failed=0})}
 $native=Run 'native' 'ctest' @('--test-dir',(Join-Path $root 'native/native-bt'),'-C','Release','-V','--parallel','2')
 foreach($match in [regex]::Matches($native,'\{[^\r\n]*"suite"[^\r\n]*\}')){$r=$match.Value | ConvertFrom-Json; if($r.failed -ne 0){throw 'Native report failure'};Count $r.suite $r.passed}
 foreach($match in [regex]::Matches($native,'PASS topology (\d+) assertions|(\d+) checks, 0 failures')){Count ('native-'+$suites.Count) ([int]($match.Groups[1].Value+$match.Groups[2].Value))}
 $managed=Run 'managed-unit' $DotnetPath @((Join-Path $virtual 'bin/ChatpadVirtualXbox/release/ChatpadVirtualXbox.dll'),'self-test')
 $r=$managed | ConvertFrom-Json;if($r.failed){throw 'Managed unit failure'};Count 'managed-unit' $r.passed
 $null=Run 'managed-process' $pwsh @('-NoProfile','-File',(Join-Path $PSScriptRoot 'ChatpadVirtualXbox/Test-Helper.ps1'),'-DotnetPath',$DotnetPath,'-ArtifactsDirectory',$virtual)
 $r=Get-Content (Join-Path $virtual 'process-tests-Release.json') -Raw | ConvertFrom-Json;if($r.failed){throw 'Process failure'};Count 'managed-process' $r.passed
 foreach($entry in @(@('binding','Test-ChatpadBinding.ps1','Binding offline tests: (\d+)/'),@('c3','Test-ChatpadC3.ps1','C3 offline tests: (\d+)/'),@('trust','Test-ChatpadWinUsbTrust.ps1','PASS: (\d+) trust'),@('publisher','Test-ChatpadPublisher.ps1','PASS publisher (\d+)/'),@('archive','Test-ChatpadReadinessArtifacts.ps1','PASS archive/privacy (\d+)/'),@('recovery','Test-ChatpadC3Recovery.ps1','C3 recovery tests: (\d+)/'),@('session-ipc','Test-ChatpadC3Session.ps1','PASS session (\d+)/'))){
  $out=Run $entry[0] $pwsh @('-NoProfile','-File',(Join-Path $PSScriptRoot $entry[1]));$m=[regex]::Match($out,$entry[2]);if(-not $m.Success){throw ('Count missing: '+$entry[0])};Count $entry[0] ([int]$m.Groups[1].Value)
 }
 foreach($name in @('ChatpadProtocolTests','ChatpadControlTests')){
  $out=Run $name (Join-Path $repo ('artifacts/bin/x64/Release/'+$name+'/'+$name+'.exe')) @();$m=[regex]::Match($out,'(?m)^Passed: (\d+)');if($out -notmatch '(?m)^Failed: 0\r?$'){throw 'Retained suite output missing success'};Count $name ([int]$m.Groups[1].Value)
 }
 $null=Run 'repository-safety' $pwsh @('-NoProfile','-File',(Join-Path $PSScriptRoot 'Test-RepositorySafety.ps1'))
 $null=Run 'diff-check' 'git.exe' @('-C',$repo,'diff','--check')
 $parse=@();foreach($f in Get-ChildItem $PSScriptRoot -Recurse -File | Where-Object Extension -in '.ps1','.psm1'){$errors=$null;$tokens=$null;$null=[Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$tokens,[ref]$errors);$parse+=@($errors)}
 if($parse.Count){$parse | Set-Content (Join-Path $logs 'syntax-failure.txt');throw 'PowerShell parse failure'}
 $summary=[pscustomobject]@{Configuration='Release';CompletedUtc=[DateTime]::UtcNow.ToString('o');ComprehensiveRuns=1;Total=($suites | Measure-Object Passed -Sum).Sum;Failed=0;Suites=@($suites);PowerShellSyntax='PASS';RepositorySafety='PASS';LiveMutations=0;PhysicalAcceptance='UNTESTED'}
 $summary | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $root 'test-summary.json') -Encoding utf8
 $summary | ConvertTo-Json -Depth 8
 exit 0
}
$null=Run 'build-managed' $pwsh @('-NoProfile','-File',(Join-Path $PSScriptRoot 'ChatpadVirtualXbox/Build.ps1'),'-Configuration','Release','-DotnetPath',$DotnetPath,'-ArtifactsDirectory',$virtual,'-EnableHidMaestro','-HidMaestroSdkPath',(Join-Path $root 'virtual/sdk-dependency/HIDMaestro.Core.dll'),'-SkipTests')
$helper=Join-Path $virtual 'bin/ChatpadVirtualXbox/release/ChatpadVirtualXbox.exe'
$null=Run 'build-native' $pwsh @('-NoProfile','-File',(Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/Build.ps1'),'-Configuration','Release','-OutputDirectory',(Join-Path $root 'native'),'-VirtualHelperExecutable',$helper,'-SkipTests')
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$installation=@(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)[0]
$msbuild=Join-Path $installation 'MSBuild/Current/Bin/MSBuild.exe'
foreach($project in @('src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj','tests/protocol/ChatpadProtocolTests.vcxproj','src/control/ChatpadControl/ChatpadControl.vcxproj','tests/control/ChatpadControlTests/ChatpadControlTests.vcxproj')){
 $null=Run ('build-'+[IO.Path]::GetFileNameWithoutExtension($project)) $msbuild @((Join-Path $repo $project),'/nologo','/m:2','/t:Build','/p:Configuration=Release','/p:Platform=x64',('/p:RepoRoot='+$repo),'/p:BuildInParallel=false','/p:CL_MPCount=2','/verbosity:minimal')
}
Write-Output 'Release builds complete; regression has not run.'
