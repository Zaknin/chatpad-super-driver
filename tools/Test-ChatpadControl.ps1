[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$installation = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $installation) { throw 'Visual Studio C++ tools were not found.' }
$msbuild = Join-Path $installation 'MSBuild\Current\Bin\MSBuild.exe'
$projects = @(
    'src\control\ChatpadControl\ChatpadControl.vcxproj',
    'tests\control\ChatpadControlTests\ChatpadControlTests.vcxproj'
)
foreach ($project in $projects) {
    & $msbuild (Join-Path $repoRoot $project) /nologo /m /t:Clean`;Build "/p:Configuration=$Configuration" "/p:Platform=$Platform" "/p:RepoRoot=$repoRoot" /verbosity:minimal
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$testExe = Join-Path $repoRoot "artifacts\bin\x64\$Configuration\ChatpadControlTests\ChatpadControlTests.exe"
& $testExe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$controlExe = Join-Path $repoRoot "artifacts\bin\x64\$Configuration\ChatpadControl\ChatpadControl.exe"
if (-not (Test-Path -LiteralPath $controlExe -PathType Leaf)) { throw "Missing companion utility: $controlExe" }
Write-Output "Companion: $controlExe"
Write-Output "SHA-256: $((Get-FileHash -LiteralPath $controlExe -Algorithm SHA256).Hash)"
exit 0
