[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VersionDirectories {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
            Sort-Object { [version]$_.Name } -Descending
    )
}

function Format-Values {
    param(
        [Parameter()]
        [object[]]$Values
    )

    if (-not $Values -or $Values.Count -eq 0) {
        return 'Not detected'
    }

    return ($Values -join ', ')
}

function Add-MissingComponent {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$List,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $List.Add($Message)
}

$report = [System.Collections.Generic.List[string]]::new()
$missing = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$windowsKey = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$windowsEdition = if ($windowsKey.ProductName) { [string]$windowsKey.ProductName } else { 'Unknown' }
$windowsVersion = if ($windowsKey.DisplayVersion) { [string]$windowsKey.DisplayVersion } elseif ($windowsKey.ReleaseId) { [string]$windowsKey.ReleaseId } else { 'Unknown' }
$windowsBuild = if ($windowsKey.UBR -ne $null) { '{0}.{1}' -f $windowsKey.CurrentBuildNumber, $windowsKey.UBR } else { [string]$windowsKey.CurrentBuildNumber }
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vswhereCandidates = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')
) | Select-Object -Unique
$vswherePath = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1

$vsInstallations = @()
if ($vswherePath) {
    try {
        $vsJson = & $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8
        if ($LASTEXITCODE -eq 0 -and $vsJson) {
            $parsedInstallations = ConvertFrom-Json -InputObject ($vsJson -join [Environment]::NewLine)
            $vsInstallations = @($parsedInstallations | ForEach-Object { $_ })
        }
    }
    catch {
        $warnings.Add("vswhere failed: $($_.Exception.Message)")
    }
}

$vsDetails = [System.Collections.Generic.List[object]]::new()
$msbuildPaths = [System.Collections.Generic.List[string]]::new()
$toolsetDetails = [System.Collections.Generic.List[object]]::new()
$integrationPaths = [System.Collections.Generic.List[string]]::new()
$templatePaths = [System.Collections.Generic.List[string]]::new()

foreach ($installation in $vsInstallations) {
    $installPath = [string]$installation.installationPath
    $displayVersion = if ($installation.catalog.productDisplayVersion) { [string]$installation.catalog.productDisplayVersion } else { [string]$installation.installationVersion }
    $edition = if ($installation.displayName) { [string]$installation.displayName } else { [string]$installation.productId }
    $vsDetails.Add([pscustomobject]@{
        Edition = $edition
        Version = $displayVersion
        InstallationVersion = [string]$installation.installationVersion
        Path = $installPath
    })

    $msbuildPath = Join-Path $installPath 'MSBuild\Current\Bin\MSBuild.exe'
    if (Test-Path -LiteralPath $msbuildPath -PathType Leaf) {
        $msbuildPaths.Add($msbuildPath)
    }

    $msvcRoot = Join-Path $installPath 'VC\Tools\MSVC'
    foreach ($toolsetDirectory in (Get-VersionDirectories -Path $msvcRoot)) {
        $compilerPath = Join-Path $toolsetDirectory.FullName 'bin\Hostx64\x64\cl.exe'
        if (-not (Test-Path -LiteralPath $compilerPath -PathType Leaf)) {
            continue
        }

        $spectreX64 = Test-Path -LiteralPath (Join-Path $toolsetDirectory.FullName 'lib\spectre\x64') -PathType Container
        $spectreX86 = Test-Path -LiteralPath (Join-Path $toolsetDirectory.FullName 'lib\spectre\x86') -PathType Container
        $toolsetDetails.Add([pscustomobject]@{
            Version = $toolsetDirectory.Name
            Family = if ($toolsetDirectory.Name -like '14.3*' -or $toolsetDirectory.Name -like '14.4*') { 'v143' } else { 'Other' }
            SpectreX64 = $spectreX64
            SpectreX86 = $spectreX86
            Path = $toolsetDirectory.FullName
        })
    }

    $platformToolsetRoots = @(
        (Join-Path $installPath 'MSBuild\Microsoft\VC\v170\Platforms\x64\PlatformToolsets\WindowsKernelModeDriver10.0'),
        (Join-Path $installPath 'MSBuild\Microsoft\VC\v170\Platforms\Win32\PlatformToolsets\WindowsKernelModeDriver10.0')
    )
    foreach ($path in $platformToolsetRoots) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            $integrationPaths.Add($path)
        }
    }

    $templateRoots = @(
        (Join-Path $installPath 'Common7\IDE\ProjectTemplates'),
        (Join-Path $installPath 'Common7\IDE\Extensions')
    )
    foreach ($templateRoot in $templateRoots) {
        if (-not (Test-Path -LiteralPath $templateRoot -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $templateRoot -Recurse -File -Filter '*.vstemplate' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '(?i)(driver|kmdf|wdk)' } |
            ForEach-Object { $templatePaths.Add($_.FullName) }
    }
}

$kitsRoot = $null
try {
    $installedRoots = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots'
    if ($installedRoots.KitsRoot10) {
        $kitsRoot = [string]$installedRoots.KitsRoot10
    }
}
catch {
    $warnings.Add('Windows Kits registry entry was not readable.')
}
if (-not $kitsRoot) {
    $kitsRoot = Join-Path $programFilesX86 'Windows Kits\10'
}

$sdkVersions = [System.Collections.Generic.List[string]]::new()
foreach ($versionDirectory in (Get-VersionDirectories -Path (Join-Path $kitsRoot 'Include'))) {
    $windowsHeader = Join-Path $versionDirectory.FullName 'um\Windows.h'
    $kernel32Library = Join-Path $kitsRoot ("Lib\{0}\um\x64\kernel32.lib" -f $versionDirectory.Name)
    if ((Test-Path -LiteralPath $windowsHeader -PathType Leaf) -and (Test-Path -LiteralPath $kernel32Library -PathType Leaf)) {
        $sdkVersions.Add($versionDirectory.Name)
    }
}

$wdkVersions = [System.Collections.Generic.List[string]]::new()
$wdkTargetPaths = [System.Collections.Generic.List[string]]::new()
foreach ($versionDirectory in (Get-VersionDirectories -Path (Join-Path $kitsRoot 'Include'))) {
    $ntddkHeader = Join-Path $versionDirectory.FullName 'km\ntddk.h'
    $kernelLibrary = Join-Path $kitsRoot ("Lib\{0}\km\x64\ntoskrnl.lib" -f $versionDirectory.Name)
    if ((Test-Path -LiteralPath $ntddkHeader -PathType Leaf) -and (Test-Path -LiteralPath $kernelLibrary -PathType Leaf)) {
        $wdkVersions.Add($versionDirectory.Name)
    }

    $targetPath = Join-Path $kitsRoot ("build\{0}\WindowsDriver.Common.targets" -f $versionDirectory.Name)
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        $wdkTargetPaths.Add($targetPath)
    }
}

$kmdfHeaderPaths = [System.Collections.Generic.List[string]]::new()
$kmdfLibraryPaths = [System.Collections.Generic.List[string]]::new()
$kmdfHeaderRoot = Join-Path $kitsRoot 'Include\wdf\kmdf'
foreach ($versionDirectory in (Get-VersionDirectories -Path $kmdfHeaderRoot)) {
    $headerPath = Join-Path $versionDirectory.FullName 'wdf.h'
    if (Test-Path -LiteralPath $headerPath -PathType Leaf) {
        $kmdfHeaderPaths.Add($headerPath)
    }
}
$kmdfLibraryRoot = Join-Path $kitsRoot 'Lib\wdf\kmdf\x64'
foreach ($versionDirectory in (Get-VersionDirectories -Path $kmdfLibraryRoot)) {
    $libraryPath = Join-Path $versionDirectory.FullName 'WdfDriverEntry.lib'
    if (Test-Path -LiteralPath $libraryPath -PathType Leaf) {
        $kmdfLibraryPaths.Add($libraryPath)
    }
}

$matchingVersions = @($sdkVersions | Where-Object { $wdkVersions -contains $_ })
$v143Toolsets = @($toolsetDetails | Where-Object { $_.Family -eq 'v143' })
$spectreX64Toolsets = @($v143Toolsets | Where-Object { $_.SpectreX64 })
$spectreX86Toolsets = @($v143Toolsets | Where-Object { $_.SpectreX86 })

$gitVersion = 'Not detected'
try {
    $gitOutput = & git --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitOutput) {
        $gitVersion = [string]$gitOutput
    }
}
catch {
    $gitVersion = 'Not detected'
}

if (-not $vswherePath) {
    Add-MissingComponent -List $missing -Message 'Install Visual Studio Installer (vswhere.exe is missing).'
}
if ($vsInstallations.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install Visual Studio 2022 or Visual Studio 2022 Build Tools.'
}
if ($msbuildPaths.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Add the Visual Studio 2022 MSBuild component.'
}
if ($v143Toolsets.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Add the MSVC v143 x64/x86 build tools component.'
}
if ($spectreX64Toolsets.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Add the MSVC v143 Spectre-mitigated libraries for x64/x86.'
}
if ($sdkVersions.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install a Windows 10 or Windows 11 SDK.'
}
if ($wdkVersions.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install the matching Windows Driver Kit (WDK).'
}
if ($matchingVersions.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install matching Windows SDK and WDK versions.'
}
if ($integrationPaths.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install or repair WDK Visual Studio 2022 integration (WindowsKernelModeDriver10.0).'
}
if ($kmdfHeaderPaths.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install KMDF headers from the WDK.'
}
if ($kmdfLibraryPaths.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install KMDF x64 libraries from the WDK.'
}
if ($wdkTargetPaths.Count -eq 0) {
    Add-MissingComponent -List $missing -Message 'Install WDK MSBuild targets.'
}
if ($templatePaths.Count -eq 0) {
    $warnings.Add('WDK Visual Studio project templates were not detected; templates are not required for command-line builds.')
}
if ($architecture -ne 'X64') {
    Add-MissingComponent -List $missing -Message 'Use an x64 Windows host for the initial x64-only project.'
}
if ($gitVersion -eq 'Not detected') {
    Add-MissingComponent -List $missing -Message 'Install Git and make git.exe available on PATH.'
}

$report.Add('Chatpad Windows Driver Build Environment')
$report.Add(('Generated: {0:u}' -f (Get-Date).ToUniversalTime()))
$report.Add('Detection mode: read-only')
$report.Add('')
$report.Add('[Host]')
$report.Add("Windows edition: $windowsEdition")
$report.Add("Windows version: $windowsVersion")
$report.Add("Windows build: $windowsBuild")
$report.Add("System architecture: $architecture")
$report.Add("PowerShell version: $($PSVersionTable.PSVersion)")
$report.Add("Git version: $gitVersion")
$report.Add('')
$report.Add('[Visual Studio 2022]')
$report.Add("vswhere: $(if ($vswherePath) { $vswherePath } else { 'Not detected' })")
if ($vsDetails.Count -eq 0) {
    $report.Add('Installations: Not detected')
}
else {
    foreach ($vs in $vsDetails) {
        $report.Add("Installation: $($vs.Edition); display version $($vs.Version); installation version $($vs.InstallationVersion); $($vs.Path)")
    }
}
$report.Add("MSBuild: $(Format-Values -Values $msbuildPaths.ToArray())")
$report.Add("MSVC v143 toolsets: $(Format-Values -Values @($v143Toolsets | ForEach-Object { $_.Version }))")
$report.Add("Spectre-mitigated x64 libraries: $(Format-Values -Values @($spectreX64Toolsets | ForEach-Object { $_.Version }))")
$report.Add("Spectre-mitigated x86 libraries: $(Format-Values -Values @($spectreX86Toolsets | ForEach-Object { $_.Version }))")
$report.Add('')
$report.Add('[Windows Kits]')
$report.Add("Kits root: $kitsRoot")
$report.Add("SDK versions: $(Format-Values -Values $sdkVersions.ToArray())")
$report.Add("WDK versions: $(Format-Values -Values $wdkVersions.ToArray())")
$report.Add("Matching SDK/WDK versions: $(Format-Values -Values $matchingVersions)")
$report.Add("WDK Visual Studio integration: $(Format-Values -Values $integrationPaths.ToArray())")
$report.Add("KMDF headers: $(Format-Values -Values $kmdfHeaderPaths.ToArray())")
$report.Add("KMDF x64 libraries: $(Format-Values -Values $kmdfLibraryPaths.ToArray())")
$report.Add("WDK MSBuild targets: $(Format-Values -Values $wdkTargetPaths.ToArray())")
$report.Add("WDK Visual Studio templates: $(Format-Values -Values $templatePaths.ToArray())")
$report.Add('')
$report.Add('[Readiness]')
if ($missing.Count -eq 0) {
    $report.Add('READY: The required x64 KMDF build toolchain is available.')
}
else {
    $report.Add('BLOCKED: The required x64 KMDF build toolchain is incomplete.')
    foreach ($item in $missing) {
        $report.Add("MISSING: $item")
    }
}
foreach ($warning in $warnings) {
    $report.Add("WARNING: $warning")
}

$reportText = ($report -join [Environment]::NewLine) + [Environment]::NewLine
Write-Output $reportText.TrimEnd()

if ($OutputPath) {
    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $outputDirectory = Split-Path -Parent $resolvedOutputPath
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedOutputPath, $reportText, [System.Text.UTF8Encoding]::new($false))
}

if ($missing.Count -gt 0) {
    exit 1
}

exit 0
