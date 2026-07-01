[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter()]
    [ValidateSet('SourceOnly', 'Full')]
    [string]$InspectionMode = 'Full'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("Result: FAIL ({0})" -f $_.Exception.Message)
    Write-Output 'Exit code: 1'
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

function Get-NormalizedDirectoryPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $fullPath += [System.IO.Path]::DirectorySeparatorChar
    }
    return $fullPath
}

function Assert-PathWithinDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Description)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directoryPath = Get-NormalizedDirectoryPath $Directory
    if (-not $fullPath.StartsWith(
        $directoryPath,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description escapes the required directory: $fullPath"
    }
    return $fullPath
}

function Invoke-GitLines {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& git -C $RepositoryRoot @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return @($output)
}

function Assert-GitIgnored {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RelativePath)

    & git -C $RepositoryRoot check-ignore -q -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Expected generated path is not ignored: $RelativePath"
    }
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

function Get-UniqueSymbolNames {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern)

    return @([regex]::Matches($Text, $Pattern) |
        ForEach-Object { $_.Value } |
        Sort-Object -Unique)
}

$repoRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRootLines = @(Invoke-GitLines $repoRoot @('rev-parse', '--show-toplevel'))
$gitRoot = [string]$gitRootLines[0]
if (-not $repoRoot.TrimEnd('\', '/').Equals(
    ([System.IO.Path]::GetFullPath($gitRoot)).TrimEnd('\', '/'),
    [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Script-derived repository root does not match Git root.'
}
$branchLines = @(Invoke-GitLines $repoRoot @('branch', '--show-current'))
$commitLines = @(Invoke-GitLines $repoRoot @('rev-parse', 'HEAD'))
$branch = [string]$branchLines[0]
$commit = [string]$commitLines[0]
$filterRoot = Join-Path $repoRoot 'src\driver\ChatpadFilter'
$projectPath = Join-Path $filterRoot 'ChatpadFilter.vcxproj'
$headerPath = Join-Path $filterRoot 'driver.h'
$devicePath = Join-Path $filterRoot 'device.c'
$manifestPath = Join-Path $repoRoot 'docs\evidence\production-owner-initialization-manifest.json'
$artifactsRoot = Join-Path $repoRoot 'artifacts'

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
    $includeDirectories = @($node.InnerText -split ';')
    foreach ($requiredDirectory in $requiredIncludeDirectories) {
        if ($includeDirectories -cnotcontains $requiredDirectory) {
            throw "Missing required production include directory: $requiredDirectory"
        }
    }
    if ($includeDirectories -cnotcontains '%(AdditionalIncludeDirectories)') {
        throw 'Production include directories must preserve inherited values.'
    }
    if (@($includeDirectories | Group-Object | Where-Object { $_.Count -gt 1 }).Count -ne 0) {
        throw 'Production include directories contain a duplicate entry.'
    }
    if (@($includeDirectories | Where-Object { $_ -match '^[A-Za-z]:\\' }).Count -ne 0) {
        throw 'Production include directories contain an absolute path.'
    }
}

$headerText = Remove-CComments ([System.IO.File]::ReadAllText($headerPath))
$deviceText = Remove-CComments ([System.IO.File]::ReadAllText($devicePath))
$productionCText = (
    Get-ChildItem -LiteralPath (Split-Path -Parent $devicePath) -Filter '*.c' -File |
        ForEach-Object { Remove-CComments ([System.IO.File]::ReadAllText($_.FullName)) }
) -join [Environment]::NewLine
$productionText = $headerText + [Environment]::NewLine + $productionCText

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
    1 'explicit production pre-object validator call'

$scalarIndex = $deviceText.IndexOf('context->DiagnosticSequence = 0u;')
$initializeIndex = $deviceText.IndexOf('ChatpadKmdfRequestOwnerInitializeStorage(')
$validateIndex = $deviceText.IndexOf('ChatpadKmdfRequestOwnerValidatePreObjectState(')
$lifecycleIndex = $deviceText.IndexOf(
    'ChatpadFilterLifecycleInitialize(&context->Lifecycle)')
if ($scalarIndex -lt 0 -or
    $initializeIndex -le $scalarIndex -or
    $validateIndex -le $initializeIndex -or
    $lifecycleIndex -le $validateIndex) {
    throw 'Owner initialization order is not scalar setup, initialize, explicit validate, lifecycle.'
}

$deviceAddEnd = $deviceText.IndexOf('ChatpadEvtDevicePrepareHardware(')
if ($deviceAddEnd -lt 0) {
    throw 'Unable to locate the callback boundary after ChatpadEvtDeviceAdd.'
}
$deviceAddText = $deviceText.Substring(0, $deviceAddEnd)
$singleline = [System.Text.RegularExpressions.RegexOptions]::Singleline
$ownerStorageFailureReturns = [regex]::IsMatch(
    $deviceAddText,
    'if\s*\(\s*ownerStorageResult\s*!=\s*CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK\s*\)\s*\{.*?return\s+(?:status|ChatpadOwnerInitializationResultToStatus\(ownerStorageResult\));\s*\}',
    $singleline)
$ownerValidationFailureReturns = [regex]::IsMatch(
    $deviceAddText,
    'if\s*\(\s*ownerValidationResult\s*!=\s*CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK\s*\)\s*\{.*?return\s+STATUS_INVALID_DEVICE_STATE;\s*\}',
    $singleline)
if (-not $ownerStorageFailureReturns -or -not $ownerValidationFailureReturns) {
    throw 'Initialization and explicit validation failures must return before lifecycle initialization.'
}

$forbiddenOwnerApis =
    'ChatpadKmdfRequestOwner(?:CreateBookkeepingSpinLock|CreateReusableRequest|CreateOutboundMemory|CreateInboundMemory|RollbackPartialCreation|Prepare[A-Za-z0-9_]*Attributes|ValidateReadyState)'
if ($productionText -match $forbiddenOwnerApis) {
    throw "Forbidden production request-owner API reference: $($Matches[0])"
}
$forbiddenRuntime =
    '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreate(?:Preallocated)?|WdfObjectDelete|WdfObjectReference|WdfObjectDereference|WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|WdfRequestCancelSentRequest|WdfUsbTargetDevice[A-Za-z0-9_]*|WdfIoTarget[A-Za-z0-9_]*|WdfIoQueueCreate|IoCallDriver|IoBuildDeviceIoControlRequest)\s*\('
if ($productionText -match $forbiddenRuntime) {
    throw "Forbidden production WDF, queue, target, or request call: $($Matches[0])"
}
if ($productionText -match
    '(?:RtlZeroMemory|memset)\s*\([^;\r\n]*ActivationRequestOwner' -or
    $productionText -match 'CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY\s*[|&^+\-]?=') {
    throw 'Production code duplicates initialization or publishes OWNER_READY.'
}

$postAddText = $deviceText.Substring($deviceAddEnd)
if ($postAddText -match 'ActivationRequestOwner|ChatpadKmdfRequestOwner') {
    throw 'A D0, hardware, cleanup, removal, or queue path observes the request owner.'
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

$trackedPaths = @(Invoke-GitLines $repoRoot @('ls-files'))
$trackedArtifacts = @($trackedPaths | Where-Object { $_ -match '^artifacts/' })
if ($trackedArtifacts.Count -ne 0) {
    throw "Generated artifacts are tracked: $($trackedArtifacts -join ', ')"
}
$generatedExtensions =
    '\.(?:sys|lib|obj|pdb|tlog|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk)$'
$trackedGenerated = @($trackedPaths | Where-Object {
    $_ -notmatch '^legacy/' -and (
        $_ -match $generatedExtensions -or
        $_ -match '(?i)(^|/)(?:package|installer|deployment)(/|$)' -or
        $_ -match '(?i)(?:transcript|build|test).*\.log$')
})
if ($trackedGenerated.Count -ne 0) {
    throw "Generated binary, evidence, certificate, key, or package path is tracked: $($trackedGenerated -join ', ')"
}
$stagedPaths = @(Invoke-GitLines $repoRoot @(
    'diff', '--cached', '--name-only', '--diff-filter=ACMR', '--'))
$stagedGenerated = @($stagedPaths | Where-Object {
    $_ -match '^artifacts/' -or $_ -match $generatedExtensions
})
if ($stagedGenerated.Count -ne 0) {
    throw "Generated artifact is staged: $($stagedGenerated -join ', ')"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
foreach ($entry in @($manifest.evidence_entries)) {
    if ([System.IO.Path]::IsPathRooted([string]$entry.path)) {
        throw "Manifest evidence path must be repository-relative: $($entry.path)"
    }
    $evidencePath = Assert-PathWithinDirectory `
        (Join-Path $repoRoot ([string]$entry.path)) `
        $artifactsRoot `
        "Manifest evidence path $($entry.id)"
    Assert-GitIgnored $repoRoot ([string]$entry.path)
    if ($InspectionMode -eq 'Full' -and
        -not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
        throw "Manifest evidence path is missing during full inspection: $($entry.path)"
    }
}

$directChecks = @(
    'XML project/reference/include/source cardinality',
    'comment-stripped production source cardinality/order/failure checks',
    'forbidden owner/WDF/queue/target/request source checks',
    'Git tracked/staged generated-output checks',
    'normalized manifest evidence containment and ignore checks')
$inferredChecks = @()
$limitations = @(
    'Source matching is narrowly scoped text/regex inspection, not a full C parser.',
    'The guard does not execute the driver or any request-owner helper.')

if ($InspectionMode -eq 'Full') {
    $driverPath = Join-Path $repoRoot (
        'artifacts\bin\{0}\{1}\ChatpadFilter\ChatpadFilter.sys' -f
            $Platform,
            $Configuration)
    $deviceObjectPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\device.obj' -f
            $Platform,
            $Configuration)
    $modelObjectPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\ChatpadRequestOwnerModel.obj' -f
            $Platform,
            $Configuration)
    $contextLibraryPath = Join-Path $repoRoot (
        'artifacts\bin\{0}\{1}\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib' -f
            $Platform,
            $Configuration)
    $contextObjectRoot = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadKmdfRequestOwnerContext' -f
            $Platform,
            $Configuration)
    $contextObjectPath = Join-Path $contextObjectRoot 'ChatpadKmdfRequestOwnerContext.obj'
    $driverCompileTlogPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\ChatpadFilter.tlog\CL.command.1.tlog' -f
            $Platform,
            $Configuration)
    $driverLinkTlogPath = Join-Path $repoRoot (
        'artifacts\obj\{0}\{1}\ChatpadFilter\ChatpadFilter.tlog\link.command.1.tlog' -f
            $Platform,
            $Configuration)
    $contextCompileTlogs = @(Get-ChildItem -LiteralPath $contextObjectRoot `
        -Recurse -File -Filter 'CL.command.1.tlog')
    if ($contextCompileTlogs.Count -ne 1) {
        throw "Expected one context compiler tlog; found $($contextCompileTlogs.Count)."
    }
    $contextCompileTlogPath = $contextCompileTlogs[0].FullName

    $artifactPaths = @(
        $driverPath,
        $deviceObjectPath,
        $modelObjectPath,
        $contextLibraryPath,
        $contextObjectPath,
        $driverCompileTlogPath,
        $driverLinkTlogPath,
        $contextCompileTlogPath)
    foreach ($path in $artifactPaths) {
        $normalizedPath = Assert-PathWithinDirectory $path $artifactsRoot 'Inspection artifact'
        if (-not (Test-Path -LiteralPath $normalizedPath -PathType Leaf)) {
            throw "Expected inspection artifact is missing: $normalizedPath"
        }
        $relativePath = $normalizedPath.Substring(
            (Get-NormalizedDirectoryPath $repoRoot).Length).Replace('\', '/')
        Assert-GitIgnored $repoRoot $relativePath
    }

    $dumpbinPath = Get-DumpbinPath
    $libPath = Join-Path (Split-Path -Parent $dumpbinPath) 'lib.exe'
    if (-not (Test-Path -LiteralPath $libPath -PathType Leaf)) {
        throw 'lib.exe was not found beside dumpbin.exe.'
    }

    $libraryMembersText = Invoke-ToolText $libPath @('/LIST', $contextLibraryPath)
    $libraryMembers = @($libraryMembersText -split '\r?\n' |
        Where-Object { $_ -match '\.obj$' })
    if ($libraryMembers.Count -ne 1 -or
        [System.IO.Path]::GetFileName($libraryMembers[0]) -cne
            'ChatpadKmdfRequestOwnerContext.obj') {
        throw 'Context library must contain exactly ChatpadKmdfRequestOwnerContext.obj.'
    }

    $deviceHeaders = Invoke-ToolText $dumpbinPath @('/HEADERS', $deviceObjectPath)
    $deviceSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $deviceObjectPath)
    $modelHeaders = Invoke-ToolText $dumpbinPath @('/HEADERS', $modelObjectPath)
    $modelSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $modelObjectPath)
    $contextHeaders = Invoke-ToolText $dumpbinPath @('/HEADERS', $contextObjectPath)
    $contextSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $contextObjectPath)
    $imports = Invoke-ToolText $dumpbinPath @('/IMPORTS', $driverPath)
    $driverHeaders = Invoke-ToolText $dumpbinPath @('/HEADERS', $driverPath)
    $driverSymbols = Invoke-ToolText $dumpbinPath @('/SYMBOLS', $driverPath)

    $allowedOwnerSymbols = @(
        'ChatpadKmdfRequestOwnerInitializeStorage',
        'ChatpadKmdfRequestOwnerValidatePreObjectState',
        'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
        'ChatpadKmdfRequestOwnerValidateCreationState')
    $forbiddenOwnerSymbols = @(
        'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
        'ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock',
        'ChatpadKmdfRequestOwnerCreateReusableRequest',
        'ChatpadKmdfRequestOwnerCreateOutboundMemory',
        'ChatpadKmdfRequestOwnerCreateInboundMemory',
        'ChatpadKmdfRequestOwnerRollbackPartialCreation',
        'ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes',
        'ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes',
        'ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes',
        'ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes',
        'ChatpadKmdfRequestOwnerValidateCreationState')
    $modelSupportSymbols = @(
        'ChatpadRequestOwnerInitialize',
        'ChatpadRequestOwnerGetSnapshot',
        'ChatpadRequestOwnerValidateInvariant')

    foreach ($symbol in @($allowedOwnerSymbols + $forbiddenOwnerSymbols)) {
        if ($contextSymbols -notmatch ('(?m)External[^\r\n]*\|\s*' + [regex]::Escape($symbol) + '\s*$')) {
            throw "Context object does not expose expected isolated symbol: $symbol"
        }
        if ($contextHeaders -notmatch ('COMDAT;\s*sym=\s*' + [regex]::Escape($symbol))) {
            throw "Context object does not provide a separate COMDAT for: $symbol"
        }
    }
    $observedModelSupport = Get-UniqueSymbolNames `
        $contextSymbols `
        'ChatpadRequestOwner(?:Initialize|GetSnapshot|ValidateInvariant)'
    if ($observedModelSupport.Count -ne $modelSupportSymbols.Count -or
        @($modelSupportSymbols | Where-Object {
            $observedModelSupport -cnotcontains $_
        }).Count -ne 0) {
        throw 'Context object pure-model references are not the exact required support set.'
    }

    $contextCompileCommand = [System.IO.File]::ReadAllText($contextCompileTlogPath)
    if ($contextCompileCommand -notmatch '(?i)(?:^|\s)/Gy(?:\s|$)') {
        throw 'Context object was not compiled with function-level linking (/Gy).'
    }
    $driverCompileCommand = [System.IO.File]::ReadAllText($driverCompileTlogPath)
    $driverLinkCommand = [System.IO.File]::ReadAllText($driverLinkTlogPath)
    foreach ($linkOption in @('/OPT:REF', '/OPT:ICF', '/INCREMENTAL:NO')) {
        if ($driverLinkCommand.IndexOf(
            $linkOption,
            [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "Driver link does not contain required retention option: $linkOption"
        }
    }
    if ($driverLinkCommand -notmatch '(?i)ChatpadKmdfRequestOwnerContext\.lib' -or
        $driverLinkCommand -match '(?i)/(?:INCLUDE|WHOLEARCHIVE):[^\s]*RequestOwner') {
        throw 'Driver link input or request-owner forced-retention state is invalid.'
    }

    $deviceOwnerSymbols = Get-UniqueSymbolNames `
        $deviceSymbols `
        'ChatpadKmdfRequestOwner[A-Za-z0-9_]+'
    if ($Configuration -eq 'Debug') {
        if ($deviceHeaders -notmatch 'File Type:\s+COFF OBJECT' -or
            $deviceOwnerSymbols.Count -ne $allowedOwnerSymbols.Count -or
            @($allowedOwnerSymbols | Where-Object {
                $deviceOwnerSymbols -cnotcontains $_
            }).Count -ne 0) {
            throw 'Debug device object does not have exactly the authorized owner initialization, orchestration, and ready-validation references.'
        }
        foreach ($symbol in $modelSupportSymbols) {
            if ($modelSymbols -notmatch ('(?m)External[^\r\n]*\|\s*' + [regex]::Escape($symbol) + '\s*$')) {
                throw "Debug production model object does not define required support: $symbol"
            }
        }
    } else {
        if ($deviceHeaders -notmatch 'File Type:\s+ANONYMOUS OBJECT' -or
            $modelHeaders -notmatch 'File Type:\s+ANONYMOUS OBJECT' -or
            $driverCompileCommand -notmatch '(?is)/GL\b.*\bDEVICE\.C\b' -or
            $driverCompileCommand -notmatch '(?is)/GL\b.*\bCHATPADREQUESTOWNERMODEL\.C\b') {
            throw 'Release owner inputs must be anonymous LTCG objects compiled with /GL.'
        }
        if ($deviceOwnerSymbols -match $forbiddenOwnerApis) {
            throw 'Release device object exposes a forbidden owner reference.'
        }
    }

    if (($deviceSymbols + [Environment]::NewLine + $driverSymbols) -match $forbiddenOwnerApis) {
        throw "Production object or observable PE symbol contains forbidden owner reference: $($Matches[0])"
    }
    $forbiddenWdfNames =
        '(?<![A-Za-z0-9_])(?:WdfSpinLockCreate|WdfRequestCreate|WdfMemoryCreatePreallocated|WdfObjectDelete)(?![A-Za-z0-9_])'
    if ($imports -match $forbiddenWdfNames) {
        throw "Observable PE import contains forbidden WDF object-management name: $($Matches[0])"
    }
    foreach ($sectionName in @('.text', '.rdata', '.data', '.pdata', '.reloc')) {
        if ($driverHeaders -notmatch ('(?m)^\s+[0-9A-F]+\s+' + [regex]::Escape($sectionName) + '\s*$')) {
            throw "Final driver does not expose expected PE section: $sectionName"
        }
    }

    $driverItem = Get-Item -LiteralPath $driverPath
    $driverHash = (Get-FileHash -LiteralPath $driverPath -Algorithm SHA256).Hash
    $runtimeInstrumentationPresent =
        (Test-Path -LiteralPath (Join-Path $filterRoot 'ChatpadRuntimeDiagnostics.h') -PathType Leaf) -and
        $productionText -match 'ChatpadTrace'
    if ($runtimeInstrumentationPresent) {
        $runtimeManifestPath = Join-Path $repoRoot 'docs\evidence\runtime-instrumentation-implementation-manifest.json'
        if (-not (Test-Path -LiteralPath $runtimeManifestPath -PathType Leaf)) {
            throw 'Runtime instrumentation manifest is required for instrumented binary validation.'
        }
        $runtimeManifest = Get-Content -LiteralPath $runtimeManifestPath -Raw | ConvertFrom-Json
        $binaryEvidenceId = '{0}-binary-identity' -f $Configuration.ToLowerInvariant()
        $binaryEvidence = @($runtimeManifest.evidence_entries | Where-Object {
            [string]$_.id -ceq $binaryEvidenceId
        })
        if ($binaryEvidence.Count -ne 1 -or
            [string]$binaryEvidence[0].configuration -cne $Configuration -or
            [string]$binaryEvidence[0].result -cne 'PASS' -or
            [int]$binaryEvidence[0].exit_code -ne 0 -or
            [string]$binaryEvidence[0].sha256 -notmatch '^[0-9A-F]{64}$' -or
            [long]$binaryEvidence[0].size -le 0 -or
            $driverItem.Length -ne [long]$binaryEvidence[0].size -or
            $driverHash -cne [string]$binaryEvidence[0].sha256) {
            throw 'Instrumented driver identity is not hash-bound to its configuration evidence entry.'
        }
        $expectedAuthenticode = 'NotSigned'
    } else {
        $driverArtifact = $manifest.artifacts.drivers.$Configuration
        if ($driverItem.Length -ne [long]$driverArtifact.size -or
            $driverHash -cne [string]$driverArtifact.sha256) {
            throw 'Final driver size or SHA-256 does not match the manifest baseline.'
        }
        $expectedAuthenticode = [string]$driverArtifact.authenticode
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $driverPath
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::NotSigned -or
        $signature.Status.ToString() -cne $expectedAuthenticode) {
        throw "Driver signature state is invalid: $($signature.Status)"
    }

    $directChecks += @(
        'existing artifact presence/containment/ignore state',
        'library member list and object symbol/COMDAT inspection',
        'compiler/linker tlog options and forced-retention absence',
        'production object allowed/forbidden reference inspection',
        'final PE sections, observable symbols/imports, hash, size, and signature')
    if ($Configuration -eq 'Debug') {
        $inferredChecks +=
            'The authorized owner initialization, orchestration, and ready-validation references are directly observable in Debug device.obj.'
    } else {
        $inferredChecks +=
            'Release allowed references are proven through source plus anonymous /GL inputs and may be inlined.'
    }
    $inferredChecks +=
        'Forbidden retention is inferred from absent production references, separate COMDATs, /OPT:REF and /OPT:ICF, no forced retention, and no forbidden observable PE evidence.'
    $limitations += @(
        'Final PE images may expose no useful COFF owner symbols, and optimized Release code may inline allowed functions.',
        'KMDF APIs dispatch through the WDF function table, so ordinary named PE import absence is not sufficient by itself to prove no KMDF object-management call.',
        'The combined conclusion relies on source, object, COMDAT, compiler, linker, and PE evidence; it is not runtime proof.')
}

$command = '.\tools\Test-ChatpadProductionOwnerInitialization.ps1 -Configuration {0} -Platform {1} -InspectionMode {2}' -f
    $Configuration,
    $Platform,
    $InspectionMode
Write-Output "Command: $command"
Write-Output "Working directory: $repoRoot"
Write-Output "Inspected commit: $commit"
Write-Output "Branch: $branch"
Write-Output "Configuration: $Configuration|$Platform"
Write-Output "Inspection mode: $InspectionMode"
Write-Output ("Direct checks: {0}" -f ($directChecks -join '; '))
Write-Output ("Inferred checks: {0}" -f $(
    if ($inferredChecks.Count -eq 0) { 'none (source-only mode)' }
    else { $inferredChecks -join '; ' }))
Write-Output ("Limitations: {0}" -f ($limitations -join ' '))
Write-Output 'Result: PASS'
Write-Output 'Exit code: 0'
exit 0
