[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [switch]$EnableHidMaestro, [string]$HidMaestroSdkPath)
$ErrorActionPreference = 'Stop'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$destination = Join-Path $root 'artifacts/task-8lc2/virtual'
$project = Join-Path $PSScriptRoot 'ChatpadVirtualXbox.csproj'
$properties = @()
if ($EnableHidMaestro) {
    if (-not $HidMaestroSdkPath -or -not (Test-Path -LiteralPath $HidMaestroSdkPath -PathType Leaf)) {
        throw 'Provide a prebuilt pinned external HIDMaestro.Core.dll. Never build upstream payload as part of this tool.'
    }
    $properties += '-p:EnableHidMaestro=true'
    $properties += "-p:HidMaestroSdkPath=$([IO.Path]::GetFullPath($HidMaestroSdkPath))"
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
& dotnet build $project --artifacts-path $destination -c $Configuration @properties --configfile (Join-Path $PSScriptRoot 'NuGet.Config') 2>&1 |
    Tee-Object -FilePath (Join-Path $destination "build-$Configuration.txt")
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit $LASTEXITCODE" }
$assembly = Join-Path $destination "bin/ChatpadVirtualXbox/$($Configuration.ToLowerInvariant())/ChatpadVirtualXbox.dll"
& dotnet $assembly self-test 2>&1 | Tee-Object -FilePath (Join-Path $destination "tests-$Configuration.json")
if ($LASTEXITCODE -ne 0) { throw "Offline tests failed with exit $LASTEXITCODE" }
Write-Output "Offline helper built: $assembly. Real backend compilation/runtime remains separate."
