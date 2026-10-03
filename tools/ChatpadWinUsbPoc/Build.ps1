[CmdletBinding()]
param([ValidateSet('Debug','Release')][string]$Configuration='Release')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output=Join-Path $repo 'artifacts/task-8lc2'
New-Item -ItemType Directory -Force $output | Out-Null
# Explicit C2 user-mode configuration, matching existing portable protocol tests.
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'UserModeBuild.props') -Destination (Join-Path $output 'Directory.Build.props')
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$instance=@(& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)[0]
if($LASTEXITCODE -ne 0 -or -not $instance){throw 'MSVC x64 Build Tools missing'}
$build=Join-Path $output 'native-bt'
& cmake -S $PSScriptRoot -B $build -G 'Visual Studio 17 2022' -A x64 "-DCMAKE_GENERATOR_INSTANCE=$instance"
if($LASTEXITCODE -ne 0){throw "configure failed: $LASTEXITCODE"}
& cmake --build $build --config $Configuration
if($LASTEXITCODE -ne 0){throw "build failed: $LASTEXITCODE"}
& ctest --test-dir $build -C $Configuration --output-on-failure
if($LASTEXITCODE -ne 0){throw "offline tests failed: $LASTEXITCODE"}
