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

function Get-DirectoryPath {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $separator = [System.IO.Path]::DirectorySeparatorChar.ToString()
    if (-not $fullPath.EndsWith($separator)) { $fullPath += $separator }
    return $fullPath
}

function Remove-SelectedArtifactDirectory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$ArtifactsRoot)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    $resolvedRepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).ProviderPath.TrimEnd('\', '/')
    $resolvedArtifactsRoot = (Resolve-Path -LiteralPath $ArtifactsRoot).ProviderPath.TrimEnd('\', '/')
    $artifactsPrefix = $resolvedArtifactsRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedPath.Equals($resolvedRepositoryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resolvedPath.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a directory outside artifacts/: $resolvedPath"
    }
    $relative = $resolvedPath.Substring($resolvedRepositoryRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    $tracked = @(& git -C $resolvedRepositoryRoot ls-files -- $relative)
    if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 0) {
        throw "Refusing to remove a directory that may contain tracked files: $resolvedPath"
    }
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Invoke-NativeLoggedStep {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogPath)

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $lines = @($output | ForEach-Object { if ($null -eq $_) { '' } else { $_.ToString() } })
    $text = $lines -join [Environment]::NewLine
    [System.IO.File]::AppendAllText(
        $LogPath,
        "Step: $Name`nExit code: $exitCode`n$text`n",
        [System.Text.Encoding]::UTF8)
    return [pscustomobject]@{ ExitCode = $exitCode; OutputLines = $lines; OutputText = $text }
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-RequestOwnerSemanticGuards {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $modelRoot = Join-Path $RepositoryRoot 'src\transport\ChatpadRequestOwnerModel'
    $headerPath = Join-Path $modelRoot 'ChatpadRequestOwnerModel.h'
    $sourcePath = Join-Path $modelRoot 'ChatpadRequestOwnerModel.c'
    $projectPath = Join-Path $modelRoot 'ChatpadRequestOwnerModel.vcxproj'
    $testPath = Join-Path $RepositoryRoot 'tests\transport\ChatpadRequestOwnerModelTests\ChatpadRequestOwnerModelTests.c'
    $modelFiles = @($headerPath, $sourcePath)
    $prohibited = '(?i)#\s*include\s*[<"](?:windows|ntddk|wdm|wdf|wdfusb|usb|usbdlib|hidsdi|setupapi|cfgmgr32)|\b(?:WDF[A-Z_]|Wdf[A-Za-z]|IoCallDriver|URB[A-Z_]|IOCTL[A-Z_]|HidD_[A-Za-z]|SetupDi[A-Za-z]|CM_[A-Za-z]|CreateFile|DeviceIoControl|malloc|calloc|realloc|free|new|delete|HeapAlloc|LocalAlloc|VirtualAlloc|Sleep|CreateThread|CreateEvent)\b'
    foreach ($file in $modelFiles) {
        $matches = @(Select-String -LiteralPath $file -Pattern $prohibited -AllMatches)
        if ($matches.Count -ne 0) {
            throw "Pure request-owner model contains a prohibited dependency in ${file}: $($matches[0].Line.Trim())"
        }
    }

    $sourceText = [System.IO.File]::ReadAllText($sourcePath)
    $headerText = [System.IO.File]::ReadAllText($headerPath)
    $testText = [System.IO.File]::ReadAllText($testPath)
    if ($sourceText -match '(?m)^\s*static\s+(?!const\b)[^();\r\n]+;\s*$') {
        throw 'Pure request-owner model contains file-scope mutable state.'
    }
    if ($sourceText -notmatch 'ChatpadRequestOwnerClearEffects\(effects\);') {
        throw 'Dispatcher does not clear caller effects before validation.'
    }
    if ($testText -notmatch 'rejected transition preserves state' -or
        $testText -notmatch 'rejected transition clears effects') {
        throw 'Tests do not guard rejected-transition atomicity and effects clearing.'
    }
    if (($sourceText + $headerText + $testText) -match '(?is)0x90u?.{0,32}0x00u?|90\s+00') {
        throw 'Prohibited unconfirmed 90 00 payload text exists in model/test source.'
    }

    $stateNames = @(
        'UNAVAILABLE','IDLE','PREPARING','READY','FORMATTED','SUBMITTING','IN_FLIGHT',
        'CANCEL_CALLING','CANCEL_PENDING','COMPLETING','AWAITING_CALL_RETURN','RETIRING','DRAINING','FAULTED')
    foreach ($stateName in $stateNames) {
        if ($headerText -notmatch "CHATPAD_REQUEST_OWNER_STATE_$stateName") {
            throw "Missing request-owner state: $stateName"
        }
    }
    $eventNames = @(
        'MAKE_AVAILABLE','MAKE_UNAVAILABLE','REQUEST_ADMISSION','BEGIN_OPERATION',
        'PREPARATION_SUCCEEDED','PREPARATION_FAILED','FORMATTING_SUCCEEDED','FORMATTING_FAILED',
        'SEND_CALL_BEGINS','SEND_RETURNED_ACCEPTED','SEND_RETURNED_FALSE','REQUEST_CANCELLATION',
        'CANCEL_CALL_BEGINS','CANCEL_CALL_RETURNED','COMPLETION_BEGINS','COMPLETION_FINISHES',
        'RETIREMENT_COMPLETES','BEGIN_DRAIN','FAULT')
    foreach ($eventName in $eventNames) {
        $symbol = "CHATPAD_REQUEST_OWNER_EVENT_$eventName"
        if ($headerText -notmatch $symbol -or $testText -notmatch $symbol) {
            throw "Event is not declared and classified by tests: $eventName"
        }
    }

    [xml]$project = Get-Content -LiteralPath $projectPath -Raw
    $namespace = New-Object System.Xml.XmlNamespaceManager($project.NameTable)
    $namespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $compileItems = @($project.SelectNodes('//msb:ItemGroup/msb:ClCompile[@Include]', $namespace) | ForEach-Object { $_.Include })
    $references = @($project.SelectNodes('//msb:ProjectReference', $namespace))
    if ($compileItems.Count -ne 1 -or $compileItems[0] -cne 'ChatpadRequestOwnerModel.c' -or $references.Count -ne 0) {
        throw 'Model project must compile exactly the pure model source with no project reference.'
    }

    $filterRoot = Join-Path $RepositoryRoot 'src\driver\ChatpadFilter'
    $filterReferences = @(
        Get-ChildItem -LiteralPath $filterRoot -File -ErrorAction Stop |
            Select-String -Pattern 'ChatpadRequestOwner' -SimpleMatch)
    if ($filterReferences.Count -ne 0) {
        throw 'ChatpadFilter source/project invokes or embeds the request-owner model.'
    }
    Write-Output 'Semantic guard: PASS (pure model, complete state/event surface, atomic rejection, driver dormancy).'
}

$repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRoot = @(& git -C $repoRoot rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or $gitRoot.Count -ne 1) {
    throw 'Unable to establish the exact repository root.'
}
$normalizedGitRoot = [System.IO.Path]::GetFullPath([string]$gitRoot[0])
if (-not $repoRoot.TrimEnd('\','/').Equals($normalizedGitRoot.TrimEnd('\','/'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Unable to establish the exact repository root.'
}

Test-RequestOwnerSemanticGuards -RepositoryRoot $repoRoot

$detectorOutput = @(& (Join-Path $PSScriptRoot 'Get-DriverBuildEnvironment.ps1') 2>&1)
$detectorExitCode = $LASTEXITCODE
Write-Output "Environment detector exit code: $detectorExitCode"
if ($detectorExitCode -ne 0) { $detectorOutput | Write-Output; exit $detectorExitCode }

$artifactsRoot = [System.IO.Path]::Combine($repoRoot, 'artifacts')
$libraryObjRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadRequestOwnerModel'))
$libraryBinRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadRequestOwnerModel'))
$testObjRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'obj', $Platform, $Configuration, 'ChatpadRequestOwnerModelTests'))
$testBinRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'bin', $Platform, $Configuration, 'ChatpadRequestOwnerModelTests'))
$logRoot = Get-DirectoryPath ([System.IO.Path]::Combine($artifactsRoot, 'logs'))
New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
Remove-SelectedArtifactDirectory $libraryObjRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $libraryBinRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $testObjRoot $repoRoot $artifactsRoot
Remove-SelectedArtifactDirectory $testBinRoot $repoRoot $artifactsRoot
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$buildLogPath = Join-Path $logRoot "chatpad-request-owner-model-build-$Configuration-$timestamp.log"
$testLogPath = Join-Path $logRoot "chatpad-request-owner-model-test-$Configuration-$timestamp.log"
[System.IO.File]::WriteAllText($buildLogPath, '', (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllText($testLogPath, '', (New-Object System.Text.UTF8Encoding($false)))

$programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
$vsWherePath = @(
    (Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'),
    (Join-Path ${env:ProgramFiles} 'Microsoft Visual Studio\Installer\vswhere.exe')) |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $vsWherePath) { throw 'vswhere.exe was not found.' }
$msbuildPaths = @(& $vsWherePath -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\Current\Bin\MSBuild.exe')
if ($LASTEXITCODE -ne 0 -or $msbuildPaths.Count -eq 0) { throw 'MSBuild.exe was not found.' }
$msbuildPath = [string]$msbuildPaths[0]

$testProject = Join-Path $repoRoot 'tests\transport\ChatpadRequestOwnerModelTests\ChatpadRequestOwnerModelTests.vcxproj'
$buildArguments = @($testProject, '/nologo', '/m', '/t:Clean;Build', "/p:Configuration=$Configuration", "/p:Platform=$Platform", '/p:PreferredToolArchitecture=x64', "/p:RepoRoot=$repoRoot", '/verbosity:minimal')
$build = Invoke-NativeLoggedStep 'MSBuild request-owner model tests' $msbuildPath $buildArguments $buildLogPath
$build.OutputText | Write-Output
Write-Output "MSBuild exit code: $($build.ExitCode)"
if ($build.ExitCode -ne 0) { Write-Output "Build log: $buildLogPath"; exit $build.ExitCode }

$libraryPath = Join-Path $libraryBinRoot 'ChatpadRequestOwnerModel.lib'
$executablePath = Join-Path $testBinRoot 'ChatpadRequestOwnerModelTests.exe'
if (-not (Test-Path -LiteralPath $libraryPath -PathType Leaf)) { throw "Expected model library not found: $libraryPath" }
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) { throw "Expected test executable not found: $executablePath" }

$test = Invoke-NativeLoggedStep 'Native request-owner model tests' $executablePath @() $testLogPath
$test.OutputText | Write-Output
$requiredLines = [ordered]@{
    'Transition states'='^Transition states: ([0-9]+)$';
    'Transition event classes'='^Transition event classes: ([0-9]+)$';
    'Transition combinations'='^Transition combinations: ([0-9]+)$';
    'Transition accepted'='^Transition accepted: ([0-9]+)$';
    'Transition idempotent'='^Transition idempotent: ([0-9]+)$';
    'Transition rejected'='^Transition rejected: ([0-9]+)$';
    'Transition faulting'='^Transition faulting: ([0-9]+)$';
    'Scenario count'='^Scenario count: ([0-9]+)$';
    'Exploration depth'='^Exploration depth: ([0-9]+)$';
    'Exploration attempts'='^Exploration attempts: ([0-9]+)$';
    'Exploration unique snapshots'='^Exploration unique snapshots: ([0-9]+)$';
    'Total'='^Total: ([0-9]+)$';
    'Passed'='^Passed: ([0-9]+)$';
    'Failed'='^Failed: ([0-9]+)$'
}
$values = @{}
foreach ($entry in $requiredLines.GetEnumerator()) {
    $pattern = $entry.Value.Substring(0, $entry.Value.Length - 1) + '\r?$'
    $matches = [regex]::Matches($test.OutputText, "(?m)$pattern")
    if ($matches.Count -ne 1) { throw "Test output does not contain exactly one '$($entry.Key)' line." }
    $values[$entry.Key] = [uint32]$matches[0].Groups[1].Value
}
if ($values['Transition states'] -ne 14 -or $values['Transition event classes'] -ne 19 -or
    $values['Transition combinations'] -ne 266 -or $values['Scenario count'] -ne 30 -or
    $values['Exploration depth'] -ne 10) {
    throw 'Test coverage statistics do not match the required bounded model.'
}
if (($values['Transition accepted'] + $values['Transition idempotent'] + $values['Transition rejected'] + $values['Transition faulting']) -ne $values['Transition combinations']) {
    throw 'Transition classification statistics do not sum to all combinations.'
}
if ($test.ExitCode -ne 0 -or $values['Failed'] -ne 0 -or $values['Total'] -ne $values['Passed']) {
    throw 'Request-owner model tests failed or reported inconsistent counts.'
}

Write-Output "Test executable exit code: $($test.ExitCode)"
Write-Output "Total assertions: $($values['Total'])"
Write-Output "Passed assertions: $($values['Passed'])"
Write-Output "Failed assertions: $($values['Failed'])"
Write-Output "Model library: $libraryPath"
Write-Output "Model library SHA-256: $(Get-Sha256 $libraryPath)"
Write-Output "Executable: $executablePath"
Write-Output "Executable SHA-256: $(Get-Sha256 $executablePath)"
Write-Output "Build log: $buildLogPath"
Write-Output "Test log: $testLogPath"

$artifactsPrefix = (Resolve-Path -LiteralPath $artifactsRoot).ProviderPath.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
$generated = @(Get-ChildItem -LiteralPath $libraryObjRoot, $libraryBinRoot, $testObjRoot, $testBinRoot -Recurse -File -ErrorAction SilentlyContinue)
foreach ($file in $generated) {
    if (-not $file.FullName.StartsWith($artifactsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated output escaped artifacts/: $($file.FullName)"
    }
}
Write-Output 'Output containment: PASS'
exit 0
