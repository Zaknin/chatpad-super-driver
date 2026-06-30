[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("FAIL: {0}" -f $_.Exception.Message)
    exit 1
}

function Remove-CComments {
    param([Parameter(Mandatory)][string]$Text)

    $withoutBlocks = [regex]::Replace(
        $Text,
        '/\*.*?\*/',
        '',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($withoutBlocks, '(?m)//.*$', '')
}

function Get-DumpbinPath {
    $programFilesX86 = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::ProgramFilesX86)
    $vswherePath = @(
        (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
    if (-not $vswherePath) {
        throw 'vswhere.exe was not found.'
    }

    $parsed = ConvertFrom-Json -InputObject (
        (@(& $vswherePath -all -products * -version '[17.0,18.0)' -format json -utf8)) -join
            [Environment]::NewLine)
    foreach ($installation in (@($parsed | ForEach-Object { $_ }) |
        Sort-Object { [version]$_.installationVersion } -Descending)) {
        $toolRoot = Join-Path ([string]$installation.installationPath) 'VC\Tools\MSVC'
        if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
            continue
        }
        foreach ($versionDirectory in (Get-ChildItem -LiteralPath $toolRoot -Directory |
            Sort-Object { [version]$_.Name } -Descending)) {
            $candidate = Join-Path $versionDirectory.FullName 'bin\Hostx64\x64\dumpbin.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    throw 'Unable to locate dumpbin.exe.'
}

function Invoke-ToolText {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return ($output -join [Environment]::NewLine)
}

function Assert-Count {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$Expected,
        [Parameter(Mandatory)][string]$Description)

    $actual = [regex]::Matches($Text, $Pattern).Count
    if ($actual -ne $Expected) {
        throw "Expected $Expected $Description occurrence(s); found $actual."
    }
}

$repoRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..'))
$filterRoot = Join-Path $repoRoot 'src\driver\ChatpadFilter'
$projectPath = Join-Path $filterRoot 'ChatpadFilter.vcxproj'
$headerPath = Join-Path $filterRoot 'driver.h'
$devicePath = Join-Path $filterRoot 'device.c'

[xml]$projectXml = Get-Content -LiteralPath $projectPath -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($projectXml.NameTable)
$ns.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')

$references = @($projectXml.SelectNodes('//msb:ProjectReference', $ns))
if ($references.Count -ne 1 -or
    $references[0].Include -cne
        '..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj') {
    throw 'ChatpadFilter must retain exactly the context-library ProjectReference.'
}

$compileItems = @($projectXml.SelectNodes('//msb:ClCompile[@Include]', $ns) |
    ForEach-Object { $_.Include })
$modelSource = '..\..\transport\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.c'
if (@($compileItems | Where-Object { $_ -ceq $modelSource }).Count -ne 1) {
    throw 'ChatpadFilter must compile exactly one portable request-owner model source.'
}
if (@($compileItems | Where-Object {
    $_ -match 'ChatpadKmdfRequestOwnerContext\.c$'
}).Count -ne 0) {
    throw 'ChatpadFilter must not compile isolated KMDF context source directly.'
}

$requiredIncludeDirectories = @(
    '$(RepoRoot)\src\driver\ChatpadKmdfRequestOwnerContext',
    '$(RepoRoot)\src\transport\ChatpadRequestOwnerModel',
    '$(RepoRoot)\src\transport\ChatpadTransport')
$includeNodes = @($projectXml.SelectNodes(
    '//msb:ItemDefinitionGroup/msb:ClCompile/msb:AdditionalIncludeDirectories',
    $ns))
if ($includeNodes.Count -ne 2) {
    throw 'Expected one include-directory list for each supported configuration.'
}
foreach ($node in $includeNodes) {
    foreach ($requiredDirectory in $requiredIncludeDirectories) {
        if (($node.InnerText -split ';') -cnotcontains $requiredDirectory) {
            throw "Missing required production include directory: $requiredDirectory"
        }
    }
    if (($node.InnerText -split ';') -cnotcontains '%(AdditionalIncludeDirectories)') {
        throw 'Production include directories must preserve inherited values.'
    }
}

$headerText = Remove-CComments ([System.IO.File]::ReadAllText($headerPath))
$deviceText = Remove-CComments ([System.IO.File]::ReadAllText($devicePath))
$productionCText = (
    Get-ChildItem -LiteralPath (Split-Path -Parent $devicePath) -Filter '*.c' -File |
        ForEach-Object { Remove-CComments ([System.IO.File]::ReadAllText($_.FullName)) }
) -join [Environment]::NewLine
Assert-Count $headerText '#include\s+"ChatpadKmdfRequestOwnerContext\.h"' 1 `
    'authoritative context-header include'
Assert-Count $headerText `
    'ChatpadKmdfActivationRequestOwner\s+ActivationRequestOwner\s*;' 1 `
    'embedded activation request owner'
if ($headerText -match
    'ChatpadKmdfActivationRequestOwner\s*(?:\*|\[[^\]]*\])\s*ActivationRequestOwner') {
    throw 'Production request owner must be embedded directly, not pointer- or array-based.'
}
if ($productionCText -match
    '(?m)^\s*(?:static\s+)?ChatpadKmdfActivationRequestOwner\s+[A-Za-z_][A-Za-z0-9_]*\s*;') {
    throw 'A file-scope or duplicate request owner exists.'
}

Assert-Count $deviceText `
    'ChatpadKmdfRequestOwnerInitializeStorage\s*\(\s*&context->ActivationRequestOwner\s*\)' `
    1 'production owner initializer call'
Assert-Count $deviceText `
    'ChatpadKmdfRequestOwnerValidatePreObjectState\s*\(\s*&context->ActivationRequestOwner\s*,\s*&ownerStorageValidation\s*\)' `
    1 'production pre-object validator call'

$scalarIndex = $deviceText.IndexOf('context->DiagnosticSequence = 0u;')
$initializeIndex = $deviceText.IndexOf('ChatpadKmdfRequestOwnerInitializeStorage(')
$validateIndex = $deviceText.IndexOf('ChatpadKmdfRequestOwnerValidatePreObjectState(')
$lifecycleIndex = $deviceText.IndexOf(
    'ChatpadFilterLifecycleInitialize(&context->Lifecycle)')
if ($scalarIndex -lt 0 -or
    $initializeIndex -le $scalarIndex -or
    $validateIndex -le $initializeIndex -or
    $lifecycleIndex -le $validateIndex) {
    throw 'Owner initialization order is not scalar setup, initialize, validate, lifecycle.'
}

$deviceAddEnd = $deviceText.IndexOf(
    'NTSTATUS' + [Environment]::NewLine + 'ChatpadEvtDevicePrepareHardware')
if ($deviceAddEnd -lt 0) {
    $deviceAddEnd = $deviceText.IndexOf('ChatpadEvtDevicePrepareHardware(')
}
$deviceAddText = $deviceText.Substring(0, $deviceAddEnd)
if ($deviceAddText -notmatch
    'if\s*\(\s*ownerStorageResult\s*!=\s*CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK\s*\)\s*\{\s*return\s+ChatpadOwnerInitializationResultToStatus\(ownerStorageResult\);\s*\}' -or
    $deviceAddText -notmatch
    'if\s*\(\s*ownerValidationResult\s*!=\s*CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK\s*\)\s*\{\s*return\s+STATUS_INVALID_DEVICE_STATE;\s*\}') {
    throw 'Initialization and validation failures must return before lifecycle initialization.'
}

$forbiddenOwnerApis =
    'ChatpadKmdfRequestOwner(?:CreateDormantObjectGraph|CreateBookkeepingSpinLock|CreateReusableRequest|CreateOutboundMemory|CreateInboundMemory|RollbackPartialCreation|Prepare[A-Za-z0-9_]*Attributes|ValidateReadyState|ValidateCreationState)'
if ($deviceText -match $forbiddenOwnerApis) {
    throw "Forbidden production request-owner API reference: $($Matches[0])"
}
$forbiddenRuntime =
    '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreate(?:Preallocated)?|WdfObjectDelete|WdfObjectReference|WdfObjectDereference|WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|WdfRequestCancelSentRequest|WdfUsbTargetDevice[A-Za-z0-9_]*|WdfIoTarget[A-Za-z0-9_]*|IoCallDriver|IoBuildDeviceIoControlRequest)\s*\('
if ($deviceText -match $forbiddenRuntime) {
    throw "Forbidden production WDF, target, or request call: $($Matches[0])"
}
if ($deviceText -match
    '(?:RtlZeroMemory|memset)\s*\([^;\r\n]*ActivationRequestOwner' -or
    $deviceText -match 'CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY\s*=') {
    throw 'Production code duplicates initialization or publishes OWNER_READY.'
}

$postAddText = $deviceText.Substring($deviceAddEnd)
if ($postAddText -match 'ActivationRequestOwner|ChatpadKmdfRequestOwner') {
    throw 'A D0, hardware, cleanup, or removal path observes the request owner.'
}
if (($headerText + $deviceText) -match '(?is)0x90u?.{0,32}0x00u?|90\s+00') {
    throw 'Prohibited unconfirmed 90 00 payload appeared in production integration.'
}

$prohibitedChanges = @(@(
    & git -C $repoRoot diff --name-only HEAD --
    & git -C $repoRoot ls-files --others --exclude-standard
) | Where-Object {
    $_ -match '(^|/)legacy/' -or
    $_ -match '\.(inf|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk)$' -or
    $_ -match '(^|/)(package|deploy|installer|recovery)(/|$)'
})
if ($prohibitedChanges.Count -ne 0) {
    throw "Prohibited integration change exists: $($prohibitedChanges -join ', ')"
}

$driverPath = Join-Path $repoRoot (
    'artifacts\bin\{0}\{1}\ChatpadFilter\ChatpadFilter.sys' -f
        $Platform,
        $Configuration)
$deviceObjectPath = Join-Path $repoRoot (
    'artifacts\obj\{0}\{1}\ChatpadFilter\device.obj' -f
        $Platform,
        $Configuration)
foreach ($path in @($driverPath, $deviceObjectPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Expected production binary is missing: $path"
    }
}

$dumpbinPath = Get-DumpbinPath
$deviceSymbols = Invoke-ToolText $dumpbinPath @('/symbols', $deviceObjectPath)
$deviceHeaders = Invoke-ToolText $dumpbinPath @('/headers', $deviceObjectPath)
if ($Configuration -eq 'Release') {
    $compileTlogPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\ChatpadFilter.tlog\CL.command.1.tlog' -f
            $Platform,
            $Configuration)
    if ($deviceHeaders -notmatch 'File Type:\s+ANONYMOUS OBJECT' -or
        -not (Test-Path -LiteralPath $compileTlogPath -PathType Leaf) -or
        ([System.IO.File]::ReadAllText($compileTlogPath) -notmatch
            '(?is)/GL\b.*\bDEVICE\.C\b')) {
        throw 'Release device.obj must be an anonymous LTCG object compiled from device.c with /GL.'
    }
} else {
    foreach ($requiredSymbol in @(
        'ChatpadKmdfRequestOwnerInitializeStorage',
        'ChatpadKmdfRequestOwnerValidatePreObjectState')) {
        if ($deviceSymbols -notmatch
            ('UNDEF[^\r\n]*' + [regex]::Escape($requiredSymbol))) {
            throw "Production device object does not reference required symbol: $requiredSymbol"
        }
    }
}
if ($deviceSymbols -match $forbiddenOwnerApis) {
    throw "Production device object references forbidden owner symbol: $($Matches[0])"
}

$imports = Invoke-ToolText $dumpbinPath @('/imports', $driverPath)
$symbols = Invoke-ToolText $dumpbinPath @('/symbols', $driverPath)
$binaryText = $imports + [Environment]::NewLine + $symbols
$forbiddenBinarySymbols =
    'ChatpadKmdfRequestOwner(?:CreateDormantObjectGraph|CreateBookkeepingSpinLock|CreateReusableRequest|CreateOutboundMemory|CreateInboundMemory|RollbackPartialCreation|Prepare[A-Za-z0-9_]*Attributes|ValidateReadyState|ValidateCreationState)'
if ($binaryText -match $forbiddenBinarySymbols) {
    throw "Final driver retains forbidden owner symbol: $($Matches[0])"
}
$forbiddenImports =
    '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreatePreallocated|WdfObjectDelete)(?![A-Za-z0-9_])'
if ($imports -match $forbiddenImports) {
    throw "Final driver imports forbidden WDF object-management API: $($Matches[0])"
}

$signature = Get-AuthenticodeSignature -LiteralPath $driverPath
if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::NotSigned) {
    throw "Driver must remain unsigned; observed $($signature.Status)."
}

Write-Output (
    'Production owner-initialization guard: PASS ({0}|{1}; one embedded owner; initializer and pre-object validator each referenced once before lifecycle initialization; no orchestration, creation, rollback, forbidden WDF import, target, or request operation).' -f
        $Configuration,
        $Platform)
Write-Output 'Semantic guard limitation: XML and targeted text/regex checks do not prove complete macro expansion or call-graph reachability; object symbols, final imports, retained build evidence, and diff review complete this checkpoint boundary.'
exit 0
