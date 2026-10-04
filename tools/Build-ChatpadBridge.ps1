[CmdletBinding()]
param([string]$OutputDirectory,[switch]$SkipNativeTests)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $repo ('artifacts/task-8lc4/build-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'))}
$output=[IO.Path]::GetFullPath($OutputDirectory)
$artifactRoot=[IO.Path]::GetFullPath((Join-Path $repo 'artifacts'))+[IO.Path]::DirectorySeparatorChar
if(-not $output.StartsWith($artifactRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Build output must remain inside ignored artifacts.'}
if(Test-Path -LiteralPath $output){throw 'Build output already exists; choose a fresh artifacts directory.'}
$native=Join-Path $output 'native'
$helper=Join-Path $output 'helper'
$package=Join-Path $output 'package'
New-Item -ItemType Directory -Force -Path $native,$helper,$package|Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/UserModeBuild.props') -Destination (Join-Path $native 'Directory.Build.props')
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$instance=@(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)[0]
if($LASTEXITCODE -ne 0 -or -not $instance){throw 'MSVC x64 Build Tools missing.'}
& cmake -S (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc') -B (Join-Path $native 'build') -G 'Visual Studio 17 2022' -A x64 "-DCMAKE_GENERATOR_INSTANCE=$instance"
if($LASTEXITCODE -ne 0){throw "CMake configure failed: $LASTEXITCODE"}
& cmake --build (Join-Path $native 'build') --config Release --parallel 2 -- /m:2
if($LASTEXITCODE -ne 0){throw "Native Release build failed: $LASTEXITCODE"}
$nativeCTest='NOT_RUN_FOCUSED_PACKAGE_REGENERATION'
if(-not $SkipNativeTests){
 & ctest --test-dir (Join-Path $native 'build') -C Release --output-on-failure --parallel 2
 if($LASTEXITCODE -ne 0){throw "Native comprehensive suite failed: $LASTEXITCODE"}
 $nativeCTest='PASS'
}
$dotnet='C:/Dev/tools/dotnet10/dotnet.exe'
$sdk=Join-Path $repo 'artifacts/task-8lc2r1/virtual/real/bin/ChatpadVirtualXbox/release/HIDMaestro.Core.dll'
if((Get-FileHash -LiteralPath $sdk).Hash -ine 'CA45EFE79C2406EB766C972F9DFEBC4BA80E33E95923D2DF4B49B8F470434E75'){throw 'Pinned HIDMaestro SDK hash mismatch.'}
& $dotnet publish (Join-Path $PSScriptRoot 'ChatpadVirtualXbox/ChatpadVirtualXbox.csproj') -c Release -p:EnableHidMaestro=true "-p:HidMaestroSdkPath=$sdk" "-p:BaseOutputPath=$(Join-Path $helper 'obj/bin/')" "-p:BaseIntermediateOutputPath=$(Join-Path $helper 'obj/intermediate/')" "-p:IntermediateOutputPath=$(Join-Path $helper 'obj/intermediate/')" "-p:AppHostIntermediatePath=$(Join-Path $helper 'obj/intermediate/ChatpadVirtualXbox.exe')" "-p:MSBuildProjectExtensionsPath=$(Join-Path $helper 'obj/intermediate/')" -o $helper
if($LASTEXITCODE -ne 0){throw "HIDMaestro helper Release build failed: $LASTEXITCODE"}
Copy-Item -LiteralPath (Join-Path $native 'build/Release/ChatpadBridge.exe') -Destination $package
Get-ChildItem -LiteralPath $helper -File|Where-Object Extension -ne '.pdb'|Copy-Item -Destination $package
$qualifiedHelper=Join-Path $repo 'artifacts/task-8lc2r1/virtual/real/bin/ChatpadVirtualXbox/release'
foreach($name in @('HIDMaestro-LICENSE','HIDMaestro-THIRD-PARTY-NOTICES.txt')){Copy-Item -LiteralPath (Join-Path $qualifiedHelper $name) -Destination $package}
$driver=Join-Path $package 'driver';New-Item -ItemType Directory -Force -Path $driver|Out-Null
$sourcePackage=Join-Path $repo 'artifacts/task-8lc2r1/trust-final/signed'
$pins=@{'ChatpadWholeDeviceWinUSB.inf'='F66F99B466535A3E693354BE62B0EC75EA466DF4E4C612B72C3AB8AAAB912B17';'ChatpadWholeDeviceWinUSB.cat'='2185C667C79F7AAD3849BC2BD124B961F6618BBE84DF8EDBFF2FAB93FC2F1E16'}
foreach($name in $pins.Keys){$source=Join-Path $sourcePackage $name;if((Get-FileHash -LiteralPath $source).Hash -ine $pins[$name]){throw "Qualified signed WinUSB package changed: $name"};Copy-Item -LiteralPath $source -Destination (Join-Path $driver $name)}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ChatpadSetup.ps1') -Destination (Join-Path $package 'ChatpadSetup.ps1')
$tools=Join-Path $package 'tools';New-Item -ItemType Directory -Force -Path $tools|Out-Null
foreach($name in @('ChatpadBinding','ChatpadBinding.ps1','ChatpadHidMaestroPackage.psm1','ChatpadC4Package.psm1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $tools -Recurse -Force}
$readiness=Join-Path $repo 'artifacts/task-8lc4/readiness-input.json'
& (Join-Path $PSScriptRoot 'New-ChatpadC4Readiness.ps1') -RunnerPath (Join-Path $package 'ChatpadBridge.exe') -HelperDirectory $package -OutputPath $readiness
if($LASTEXITCODE -ne 0){throw 'C4 readiness generation failed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-ChatpadC4Setup.ps1')
if($LASTEXITCODE -ne 0){throw 'C4 setup/elevation tests failed.'}
$files=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object {[pscustomobject]@{Path=$_.FullName.Substring($package.Length+1);Length=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
$report=[pscustomobject]@{Schema=1;Task='8L-C4';BuiltUtc=[DateTime]::UtcNow.ToString('o');Repository=[pscustomobject]@{Branch=[string](& git.exe -C $repo branch --show-current);Commit=[string](& git.exe -C $repo rev-parse HEAD)};PackagePath=$package;RunnerPath=(Join-Path $package 'ChatpadBridge.exe');HelperPath=(Join-Path $package 'ChatpadVirtualXbox.exe');NativeCTest=$nativeCTest;C4Tests='PASS';Files=$files}
$report|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $output 'build-manifest.json') -Encoding utf8
$report|ConvertTo-Json -Depth 8
