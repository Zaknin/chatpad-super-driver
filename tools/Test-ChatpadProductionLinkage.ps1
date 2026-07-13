[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter()]
    [string]$BuildLogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("FAIL: {0}" -f $_.Exception.Message)
    exit 1
}

function Remove-CComments {
    param([Parameter(Mandatory)][string]$Text)
    $withoutBlocks = [regex]::Replace($Text, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($withoutBlocks, '(?m)//.*$', '')
}

function Get-DumpbinPath {
    $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    $vswhereCandidates = @(
        (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) | Select-Object -Unique
    $vswherePath = $vswhereCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $vswherePath) { throw 'vswhere.exe was not found.' }

    $installations = @(& $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8)
    if ($LASTEXITCODE -ne 0 -or $installations.Count -eq 0) {
        throw 'Visual Studio 2022 installation query failed.'
    }
    $parsed = ConvertFrom-Json -InputObject ($installations -join [Environment]::NewLine)
    foreach ($installation in (@($parsed | ForEach-Object { $_ }) | Sort-Object { [version]$_.installationVersion } -Descending)) {
        $toolRoot = Join-Path ([string]$installation.installationPath) 'VC\Tools\MSVC'
        if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) { continue }
        foreach ($versionDirectory in (Get-ChildItem -LiteralPath $toolRoot -Directory | Sort-Object { [version]$_.Name } -Descending)) {
            $candidate = Join-Path $versionDirectory.FullName 'bin\Hostx64\x64\dumpbin.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    throw 'Unable to locate dumpbin.exe in the Visual Studio 2022 MSVC toolsets.'
}

function Invoke-ToolText {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { if ($null -eq $_) { '' } else { $_.ToString() } })
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return ($output -join [Environment]::NewLine)
}

function Assert-NoMatch {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message)

    if ($Text -match $Pattern) { throw "$Message Match: $($Matches[0])" }
}

$repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRoot = @(& git -C $repoRoot rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or $gitRoot.Count -ne 1) { throw 'Unable to locate repository root.' }
$normalizedGitRoot = [System.IO.Path]::GetFullPath([string]$gitRoot[0])
if (-not $repoRoot.TrimEnd('\','/').Equals($normalizedGitRoot.TrimEnd('\','/'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Script-derived repository root does not match Git root.'
}

$filterProject = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
$contextProject = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj'
$driverRoot = Join-Path $repoRoot 'src\driver\ChatpadFilter'

[xml]$filterXml = Get-Content -LiteralPath $filterProject -Raw
$filterNs = New-Object System.Xml.XmlNamespaceManager($filterXml.NameTable)
$filterNs.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
$refs = @($filterXml.SelectNodes('//msb:ProjectReference', $filterNs))
if ($refs.Count -ne 1) { throw "Expected exactly one ProjectReference in ChatpadFilter; found $($refs.Count)." }
$ref = $refs[0]
if ($ref.Include -cne '..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj') {
    throw "Unexpected ProjectReference path: $($ref.Include)"
}
$refProject = $ref.SelectSingleNode('msb:Project', $filterNs)
$refLinkLibraryDependencies = $ref.SelectSingleNode('msb:LinkLibraryDependencies', $filterNs)
$refUseLibraryDependencyInputs = $ref.SelectSingleNode('msb:UseLibraryDependencyInputs', $filterNs)
$refReferenceOutputAssembly = $ref.SelectSingleNode('msb:ReferenceOutputAssembly', $filterNs)
$refGlobalPropertiesToRemove = $ref.SelectSingleNode('msb:GlobalPropertiesToRemove', $filterNs)
$refAdditionalProperties = $ref.SelectSingleNode('msb:AdditionalProperties', $filterNs)
if ($null -eq $refProject -or $refProject.InnerText -cne '{421C7E3A-5B02-4D07-A37D-4B45D3755694}') {
    throw "Unexpected ProjectReference GUID: $(if ($null -eq $refProject) { '<missing>' } else { $refProject.InnerText })"
}
if ($null -eq $refGlobalPropertiesToRemove -or $refGlobalPropertiesToRemove.InnerText -cne 'OutDir;IntDir') {
    throw 'ProjectReference must remove driver OutDir/IntDir global properties so the static library uses its own artifact directories.'
}
$expectedAdditionalProperties = 'OutDir=$(RepoRoot)\artifacts\bin\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\;IntDir=$(RepoRoot)\artifacts\obj\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\'
if ($null -eq $refAdditionalProperties -or $refAdditionalProperties.InnerText -cne $expectedAdditionalProperties) {
    throw 'ProjectReference must pass explicit WDK driver-packaging dependency output directories through AdditionalProperties.'
}
if ($null -ne $refReferenceOutputAssembly -or
    ($null -ne $refLinkLibraryDependencies -and $refLinkLibraryDependencies.InnerText -eq 'false') -or
    ($null -ne $refUseLibraryDependencyInputs -and $refUseLibraryDependencyInputs.InnerText -eq 'true')) {
    throw 'ProjectReference contains managed or non-default native-linkage metadata.'
}

$projectText = [System.IO.File]::ReadAllText($filterProject)
Assert-NoMatch $projectText '(?i)ChatpadKmdfRequestOwnerContext\.lib|AdditionalDependencies>.*ChatpadKmdf|AdditionalLibraryDirectories>.*ChatpadKmdf|WHOLEARCHIVE|/WHOLEARCHIVE|/FORCE|UseLibraryDependencyInputs>true|ReferenceOutputAssembly' 'Manual library, whole-archive, force, or managed-reference metadata is prohibited.'
Assert-NoMatch $projectText '(?i)/INCLUDE:ChatpadKmdf|/INCLUDE:.*RequestOwner' 'Request-owner forced symbol retention is prohibited.'
Assert-NoMatch $projectText '(?i)[A-Z]:\\' 'Absolute developer-machine path is prohibited in ChatpadFilter project.'

[xml]$contextXml = Get-Content -LiteralPath $contextProject -Raw
$contextNs = New-Object System.Xml.XmlNamespaceManager($contextXml.NameTable)
$contextNs.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
$contextType = @($contextXml.SelectNodes('//msb:ConfigurationType', $contextNs) | ForEach-Object { $_.'#text' } | Sort-Object -Unique)
if ($contextType.Count -ne 1 -or $contextType[0] -cne 'StaticLibrary') {
    throw 'Referenced context project is not consistently a static library.'
}

$driverSource = ''
Get-ChildItem -LiteralPath $driverRoot -File -ErrorAction Stop |
    Where-Object { $_.Extension -in @('.c', '.h') } |
    ForEach-Object { $driverSource += "`n" + (Remove-CComments ([System.IO.File]::ReadAllText($_.FullName))) }
$requestOwnerContextIncludeCount = [regex]::Matches($driverSource, '#include\s+"ChatpadKmdfRequestOwnerContext\.h"').Count
if ($requestOwnerContextIncludeCount -notin @(1, 2) -or
    [regex]::Matches($driverSource, 'ChatpadKmdfActivationRequestOwner\s+ActivationRequestOwner\s*;').Count -ne 1 -or
    [regex]::Matches($driverSource, 'ChatpadKmdfRequestOwnerInitializeStorage\s*\(').Count -ne 1 -or
    [regex]::Matches($driverSource, 'ChatpadKmdfRequestOwnerValidatePreObjectState\s*\(').Count -ne 1 -or
    [regex]::Matches($driverSource, 'ChatpadKmdfRequestOwnerCreateDormantObjectGraph\s*\(').Count -ne 1 -or
    [regex]::Matches($driverSource, 'ChatpadKmdfRequestOwnerValidateCreationState\s*\(').Count -ne 1 -or
    [regex]::Matches($driverSource, 'ChatpadKmdfGetActivationRequestContext\s*\(').Count -ne 1) {
    throw 'Production source must contain the exact authorized owner initialization and orchestration invocation integration plus diagnostic-only runtime instrumentation.'
}
Assert-NoMatch $driverSource 'ChatpadKmdfRequestOwner(?:CreateBookkeepingSpinLock|CreateReusableRequest|CreateOutboundMemory|CreateInboundMemory|RollbackPartialCreation|Prepare|Classify)' 'Production source must not call direct creation, rollback, attribute, or classification APIs.'
$requiredLiveApis = @(
    'IoSetCompletionRoutine',
    'WdfIoTargetSendInternalIoctlOthersSynchronously',
    'USBD_DEFAULT_PIPE_TRANSFER',
    'URB_FUNCTION_CONTROL_TRANSFER',
    'UsbBuildInterruptOrBulkTransferRequest',
    'VhfReadReportSubmit',
    'IoCallDriver')
foreach ($requiredLiveApi in $requiredLiveApis) {
    if ($driverSource -notmatch [regex]::Escape($requiredLiveApi)) {
        throw "Production source is missing required live-runtime API: $requiredLiveApi"
    }
}
Assert-NoMatch $driverSource 'WdfUsbTargetDevice(?:Create|SelectConfig|SendControlTransferSynchronously)|WdfUsbTargetPipeReadSynchronously' 'Production filter must not claim or reconfigure the xusb22-owned USB device.'
if ($projectText -notmatch '(?i)VhfKm\.lib') {
    throw 'ChatpadFilter project must link the VHF kernel client library.'
}
Assert-NoMatch $driverSource 'WdfRequest(?:Reuse|CancelSentRequest|SetCompletionRoutine)' 'Reusable-request user-mode bridge operations remain prohibited in the kernel runtime.'
$requestSendCount = [regex]::Matches($driverSource, 'WdfRequestSend\s*\(').Count
$controlDeviceSource = Remove-CComments ([System.IO.File]::ReadAllText((Join-Path $driverRoot 'ChatpadControlDevice.c')))
if ($requestSendCount -ne 1 -or
    $controlDeviceSource -notmatch 'WdfRequestFormatRequestUsingCurrentType\s*\(\s*Request\s*\)' -or
    $controlDeviceSource -notmatch 'WdfRequestSend\s*\(\s*Request\s*,\s*WdfDeviceGetIoTarget\s*\(\s*Device\s*\)') {
    throw 'The only permitted WdfRequestSend must forward one unknown device-control request unchanged to the lower xusb22 target.'
}

$prohibitedChanged = @(@(
    & git -C $repoRoot diff --name-only HEAD --
    & git -C $repoRoot ls-files --others --exclude-standard
) | Where-Object {
    $_ -match '(^|/)legacy/' -or
    (($_ -match '\.(inf|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk)$' -or $_ -match '(^|/)(package|deploy|installer)') -and
        $_ -cne 'src/driver/ChatpadFilter/package/ChatpadFilterExtension.inf') -or
    ($_ -match '^src/driver/ChatpadFilter/.*\.(cpp|hpp)$')
})
if ($prohibitedChanged.Count -ne 0) {
    throw "Prohibited source, INF, signing, packaging, install, or legacy change exists: $($prohibitedChanged -join ', ')"
}

$driverPath = Join-Path $repoRoot ("artifacts\bin\{0}\{1}\ChatpadFilter\ChatpadFilter.sys" -f $Platform, $Configuration)
if (-not (Test-Path -LiteralPath $driverPath -PathType Leaf)) {
    throw "Expected built driver image is missing: $driverPath"
}
$contextObjectPath = Join-Path $repoRoot ("artifacts\obj\{0}\{1}\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.obj" -f $Platform, $Configuration)
if (-not (Test-Path -LiteralPath $contextObjectPath -PathType Leaf)) {
    throw "Expected context object is missing: $contextObjectPath"
}
$dumpbinPath = Get-DumpbinPath
$imports = Invoke-ToolText -FilePath $dumpbinPath -Arguments @('/imports', $driverPath)
$symbols = Invoke-ToolText -FilePath $dumpbinPath -Arguments @('/symbols', $driverPath)
$contextSymbols = Invoke-ToolText -FilePath $dumpbinPath -Arguments @('/symbols', $contextObjectPath)
$imageText = $imports + [Environment]::NewLine + $symbols
Assert-NoMatch $imageText 'WdfRequest(?:Reuse|Send|CancelSentRequest|SetCompletionRoutine)' 'Final driver image must not retain obsolete reusable-request bridge operations.'
$objectImportPattern = '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreatePreallocated|WdfObjectDelete)(?![A-Za-z0-9_])'
if ($Configuration -eq 'Debug' -and (
    $contextSymbols -notmatch $objectImportPattern -or
    $contextSymbols -notmatch 'ChatpadKmdfRequestOwnerCreateDormantObjectGraph' -or
    $contextSymbols -notmatch 'ChatpadKmdfRequestOwnerRollbackPartialCreation')) {
    throw 'Context object must expose expected dormant orchestration, rollback, and WDF object-management evidence.'
}

if ($BuildLogPath) {
    if (-not (Test-Path -LiteralPath $BuildLogPath -PathType Leaf)) {
        throw "Build log path does not exist: $BuildLogPath"
    }
    $buildLog = [System.IO.File]::ReadAllText($BuildLogPath)
    Assert-NoMatch $buildLog '(?i)WHOLEARCHIVE|/WHOLEARCHIVE|/FORCE|/INCLUDE:ChatpadKmdf|/INCLUDE:.*RequestOwner' 'Build log contains prohibited retention evidence.'

    $expectedContextLibraryPath = [System.IO.Path]::Combine(
        $repoRoot,
        'artifacts',
        'bin',
        $Platform,
        $Configuration,
        'ChatpadKmdfRequestOwnerContext',
        'ChatpadKmdfRequestOwnerContext.lib')
    if ($buildLog.IndexOf($expectedContextLibraryPath, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Build log does not contain the expected generated artifact-library path: $expectedContextLibraryPath"
    }
}

Write-Output ("Production linkage semantic guard: PASS ({0}|{1}; request-owner linkage retained; lower-stack URB/VHF runtime present; direct lower-stack forwarding present; obsolete reusable-request bridge absent; diagnostic-only request-owner includes={2})." -f $Configuration, $Platform, $requestOwnerContextIncludeCount)
Write-Output 'Semantic guard limitation: targeted XML/text/binary string checks cannot prove full C macro expansion or all linker extraction internals; paired MSBuild logs, tlogs, dumpbin output, and diff review provide the binary evidence for this checkpoint.'
exit 0
