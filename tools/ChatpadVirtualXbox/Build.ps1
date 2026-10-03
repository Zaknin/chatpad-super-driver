[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [switch]$EnableHidMaestro, [string]$HidMaestroSdkPath,
    [string]$DotnetPath = 'dotnet', [string]$ArtifactsDirectory,
    [string]$NuGetConfigPath, [switch]$SkipTests)
$ErrorActionPreference = 'Stop'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$destination = if ($ArtifactsDirectory) { [IO.Path]::GetFullPath($ArtifactsDirectory) } else { Join-Path $root 'artifacts/task-8lc2/virtual' }
$config = if ($NuGetConfigPath) { [IO.Path]::GetFullPath($NuGetConfigPath) } else { Join-Path $PSScriptRoot 'NuGet.Config' }
$project = Join-Path $PSScriptRoot 'ChatpadVirtualXbox.csproj'
$properties = @()
if ($EnableHidMaestro) {
    if (-not $HidMaestroSdkPath -or -not (Test-Path -LiteralPath $HidMaestroSdkPath -PathType Leaf)) {
        throw 'Provide a prebuilt pinned external HIDMaestro.Core.dll. Never build upstream payload as part of this tool.'
    }
    $properties += '-p:EnableHidMaestro=true'
    $properties += "-p:HidMaestroSdkPath=$([IO.Path]::GetFullPath($HidMaestroSdkPath))"
    $pin = Get-Content (Join-Path $PSScriptRoot 'upstream.json') -Raw | ConvertFrom-Json
    if ((Get-FileHash -LiteralPath $HidMaestroSdkPath -Algorithm SHA256).Hash -ne $pin.c2r1ReleaseSdkSha256) { throw 'External SDK does not match the pinned official release DLL hash.' }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
& $DotnetPath build $project --artifacts-path $destination -c $Configuration -m:2 @properties --configfile $config 2>&1 |
    Tee-Object -FilePath (Join-Path $destination "build-$Configuration.txt")
if ($LASTEXITCODE -ne 0) { throw "Build failed with exit $LASTEXITCODE" }
$assembly = Join-Path $destination "bin/ChatpadVirtualXbox/$($Configuration.ToLowerInvariant())/ChatpadVirtualXbox.dll"
if ($EnableHidMaestro) {
    $dependencyFolder = Split-Path ([IO.Path]::GetFullPath($HidMaestroSdkPath))
    foreach ($notice in @('LICENSE', 'THIRD-PARTY-NOTICES.txt')) {
        $sourceNotice = Join-Path $dependencyFolder $notice
        if (-not (Test-Path -LiteralPath $sourceNotice -PathType Leaf)) { throw "External SDK notice required for redistribution: $notice" }
        Copy-Item -LiteralPath $sourceNotice -Destination (Join-Path (Split-Path $assembly) "HIDMaestro-$notice")
    }
}
if (-not $SkipTests) {
    & $DotnetPath $assembly self-test 2>&1 | Tee-Object -FilePath (Join-Path $destination "tests-$Configuration.json")
    if ($LASTEXITCODE -ne 0) { throw "Offline tests failed with exit $LASTEXITCODE" }
}
Write-Output "Helper built: $assembly. SDK compilation never authorizes runtime/device creation."
