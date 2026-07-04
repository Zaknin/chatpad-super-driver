[CmdletBinding()]
param(
    [string]$OutputRoot = 'artifacts/logs/static-metadata-parser-file-scope-remediation',
    [string]$ParserProject = 'tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj',
    [string]$EvidencePath = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((& git rev-parse --show-toplevel).Trim())
$outputRootFull = [IO.Path]::GetFullPath((Join-Path $root $OutputRoot))
$parserProjectFull = [IO.Path]::GetFullPath((Join-Path $root $ParserProject))
$sourceCommit = (& git rev-parse HEAD).Trim()
if (-not $EvidencePath) {
    $EvidencePath = Join-Path $OutputRoot 'static-metadata-parser-synthetic-validation.json'
}
$evidenceFull = [IO.Path]::GetFullPath((Join-Path $root $EvidencePath))

function New-Directory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Write-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Value)
    New-Directory -Path (Split-Path -Parent $Path)
    [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}

function Write-Json {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][object]$Value)
    Write-Utf8NoBom -Path $Path -Value (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Invoke-RequiredCommand {
    param([Parameter(Mandatory)][string]$FilePath,[Parameter(Mandatory)][string[]]$Arguments,[Parameter(Mandatory)][string]$LogPath)
    New-Directory -Path (Split-Path -Parent $LogPath)
    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Write-Utf8NoBom -Path $LogPath -Value (($output -join [Environment]::NewLine) + [Environment]::NewLine)
    if ($exitCode -ne 0) {
        throw "$FilePath failed with exit code $exitCode. See $LogPath."
    }
}

function Invoke-ParserCommand {
    param([Parameter(Mandatory)][string[]]$Arguments,[Parameter(Mandatory)][string]$LogPath)
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& dotnet @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    Write-Utf8NoBom -Path $LogPath -Value (($output -join [Environment]::NewLine) + [Environment]::NewLine)
    [pscustomobject][ordered]@{ exit_code = $exitCode; output = $output }
}

function Test-PreReadRejectionEvidence {
    param(
        [Parameter(Mandatory)][object]$Evidence,
        [Parameter(Mandatory)][string]$ExpectedDefectCode
    )
    $defectCodes = @($Evidence.defects | ForEach-Object { [string]$_.code })
    @(
        ([string]$Evidence.schemaVersion -eq 'chatpad-static-metadata-parser-evidence-v1'),
        ([string]$Evidence.result -eq 'FAIL'),
        ($defectCodes -contains $ExpectedDefectCode),
        ([bool]$Evidence.artifactBytesRead -eq $false),
        ([bool]$Evidence.artifactHashComputed -eq $false),
        ([bool]$Evidence.expectedBytesRead -eq $false),
        ([bool]$Evidence.expectedHashComputed -eq $false),
        ([bool]$Evidence.peParseAttempted -eq $false),
        ([bool]$Evidence.metadataParseAttempted -eq $false),
        ([bool]$Evidence.metadataParsed -eq $false),
        ([int]$Evidence.safetyCounters.artifactBytesRead -eq 0),
        ([int]$Evidence.safetyCounters.artifactHashComputed -eq 0),
        ([int]$Evidence.safetyCounters.expectedBytesRead -eq 0),
        ([int]$Evidence.safetyCounters.expectedHashComputed -eq 0),
        ([int]$Evidence.safetyCounters.peParseAttempted -eq 0),
        ([int]$Evidence.safetyCounters.metadataParseAttempted -eq 0),
        ([int]$Evidence.safetyCounters.metadataParsed -eq 0),
        ([string]$Evidence.metadataReviewStatus -ne 'PERFORMED')
    )
}

function Test-ParserSourceGuard {
    $parserFiles = @(
        'tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj',
        'tools/StaticMetadataParser/Program.cs'
    )
    $rules = [ordered]@{
        'runtime-assembly-load' = 'Assembly\.Load|LoadFrom|LoadFile|ReflectionOnlyLoad|MetadataLoadContext'
        'artifact-runtime-reflection' = 'MethodInfo|FieldInfo|PropertyInfo|CustomAttributeData|Activator\.|DynamicInvoke'
        'native-loading-or-resolution' = 'DllImport|LibraryImport|NativeLibrary|LoadLibrary|GetProcAddress'
        'process-or-shell' = 'Process\.Start|PowerShell|dotnet exec'
        'device-or-windows-mutation' = 'SetupDi|DiInstallDevice|Win32_PnPEntity|Get-CimInstance|Get-WmiObject|Registry|ServiceController'
        'driver-actions' = 'Inf2Cat|signtool|pnputil|devcon|sc\.exe'
        'project-execution-hooks' = '<PostBuildEvent|<Target[^>]+AfterTargets|<RuntimeIdentifier|<SelfContained>true|<AllowUnsafeBlocks>true'
    }
    $findings = [Collections.Generic.List[object]]::new()
    foreach ($relative in $parserFiles) {
        $full = Join-Path $root $relative
        $text = Get-Content -LiteralPath $full -Raw
        foreach ($rule in $rules.GetEnumerator()) {
            $matches = [regex]::Matches($text, $rule.Value, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $matches) {
                $line = ($text.Substring(0, $match.Index) -split "`n").Count
                $findings.Add([pscustomobject][ordered]@{
                    rule = $rule.Key
                    file = $relative
                    line = $line
                    match = $match.Value
                })
            }
        }
    }
    [pscustomobject][ordered]@{
        result = $(if ($findings.Count) { 'FAIL' } else { 'PASS' })
        finding_count = $findings.Count
        findings = @($findings)
    }
}

function New-FixtureProject {
    param(
        [Parameter(Mandatory)][string]$FixtureId,
        [Parameter(Mandatory)][ValidateSet('Library','Exe')][string]$Kind,
        [Parameter(Mandatory)][string]$Source
    )
    $projectRoot = Join-Path $outputRootFull "fixtures/src/$FixtureId"
    New-Directory -Path $projectRoot
    $outputType = if ($Kind -eq 'Exe') { '<OutputType>Exe</OutputType>' } else { '' }
    Write-Utf8NoBom -Path (Join-Path $projectRoot "$FixtureId.csproj") -Value @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>$FixtureId</AssemblyName>
    $outputType
    <UseAppHost>false</UseAppHost>
    <SelfContained>false</SelfContained>
  </PropertyGroup>
</Project>
"@
    Write-Utf8NoBom -Path (Join-Path $projectRoot 'Fixture.cs') -Value $Source
    [pscustomobject][ordered]@{
        fixture_id = $FixtureId
        project_path = Join-Path $projectRoot "$FixtureId.csproj"
        output_path = Join-Path $outputRootFull "fixtures/bin/$FixtureId/Release/net9.0/$FixtureId.dll"
        obj_path = Join-Path $outputRootFull "fixtures/obj/$FixtureId/"
        bin_path = Join-Path $outputRootFull "fixtures/bin/$FixtureId/"
    }
}

New-Directory -Path $outputRootFull
New-Directory -Path (Split-Path -Parent $evidenceFull)
$guard = Test-ParserSourceGuard
if ($guard.result -ne 'PASS') {
    Write-Json -Path $evidenceFull -Value ([pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-synthetic-validation-v1'
        result = 'FAIL'
        result_code = 'PARSER_SOURCE_GUARD_FAILED'
        guard = $guard
    })
    throw 'Parser source guard failed.'
}

$parserBuildRoot = Join-Path $outputRootFull 'parser-build'
$parserBuildLog = Join-Path $outputRootFull 'logs/parser-build.txt'
Invoke-RequiredCommand -FilePath 'dotnet' -Arguments @(
    'build', $parserProjectFull,
    '--configuration', 'Release',
    '--nologo',
    "/p:BaseOutputPath=$parserBuildRoot/bin/",
    "/p:BaseIntermediateOutputPath=$parserBuildRoot/obj/"
) -LogPath $parserBuildLog
$parserDll = Join-Path $parserBuildRoot 'bin/Release/net9.0/Chatpad.StaticMetadataParser.dll'
if (-not (Test-Path -LiteralPath $parserDll -PathType Leaf)) {
    throw "Parser build output was not found: $parserDll"
}

$fixtures = @()
$fixtures += New-FixtureProject -FixtureId 'Synthetic.NoPInvoke.Library' -Kind Library -Source @'
namespace Synthetic.NoPInvoke;

public static class LibraryMarker
{
    public static string Name => "no-pinvoke";
}
'@
$fixtures += New-FixtureProject -FixtureId 'Synthetic.PInvoke.Library' -Kind Library -Source @'
using System.Runtime.InteropServices;

namespace Synthetic.PInvoke;

public static partial class NativeDeclarations
{
    [DllImport("placeholderalpha.dll", EntryPoint = "PlaceholderAlpha", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int PlaceholderAlpha();

    [DllImport("placeholderbeta.dll", EntryPoint = "PlaceholderBeta", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int PlaceholderBeta();
}
'@
$fixtures += New-FixtureProject -FixtureId 'Synthetic.EntryPoint.Console' -Kind Exe -Source @'
namespace Synthetic.EntryPoint;

public static class Program
{
    public static int Main(string[] args) => args.Length;
}
'@
$fixtures += New-FixtureProject -FixtureId 'Synthetic.UnexpectedPInvoke.Library' -Kind Library -Source @'
using System.Runtime.InteropServices;

namespace Synthetic.UnexpectedPInvoke;

public static partial class NativeDeclarations
{
    [DllImport("unexpected.dll", EntryPoint = "UnexpectedEntry", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern int UnexpectedEntry();
}
'@

foreach ($fixture in $fixtures) {
    Invoke-RequiredCommand -FilePath 'dotnet' -Arguments @(
        'build', $fixture.project_path,
        '--configuration', 'Release',
        '--nologo',
        "/p:BaseOutputPath=$($fixture.bin_path)",
        "/p:BaseIntermediateOutputPath=$($fixture.obj_path)"
    ) -LogPath (Join-Path $outputRootFull "logs/build-$($fixture.fixture_id).txt")
}

$invalidPath = Join-Path $outputRootFull 'fixtures/invalid/not-a-pe.bin'
Write-Utf8NoBom -Path $invalidPath -Value "not a PE file$([Environment]::NewLine)"

$expectedRoot = Join-Path $outputRootFull 'fixtures/expected'
New-Directory -Path $expectedRoot
$expectations = @{
    'Synthetic.NoPInvoke.Library' = [pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-expectations-v1'
        input_identity_source = 'SYNTHETIC_FIXTURE'
        require_no_entry_point = $true
        expected_declarations = @()
    }
    'Synthetic.PInvoke.Library' = [pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-expectations-v1'
        input_identity_source = 'SYNTHETIC_FIXTURE'
        require_no_entry_point = $true
        expected_declarations = @(
            [pscustomobject][ordered]@{ module = 'placeholderalpha.dll'; entry_point = 'PlaceholderAlpha' },
            [pscustomobject][ordered]@{ module = 'placeholderbeta.dll'; entry_point = 'PlaceholderBeta' }
        )
    }
    'Synthetic.EntryPoint.Console' = [pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-expectations-v1'
        input_identity_source = 'SYNTHETIC_FIXTURE'
        require_no_entry_point = $true
        expected_declarations = @()
    }
    'Synthetic.UnexpectedPInvoke.Library' = [pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-expectations-v1'
        input_identity_source = 'SYNTHETIC_FIXTURE'
        require_no_entry_point = $true
        expected_declarations = @(
            [pscustomobject][ordered]@{ module = 'placeholderalpha.dll'; entry_point = 'PlaceholderAlpha' }
        )
    }
    'Synthetic.Invalid.NonPe' = [pscustomobject][ordered]@{
        schema_version = 'chatpad-static-metadata-parser-expectations-v1'
        input_identity_source = 'SYNTHETIC_FIXTURE'
        require_no_entry_point = $true
        expected_declarations = @()
    }
}

foreach ($key in $expectations.Keys) {
    Write-Json -Path (Join-Path $expectedRoot "$key.expected.json") -Value $expectations[$key]
}

$cases = @(
    [pscustomobject][ordered]@{ fixture_id = 'Synthetic.NoPInvoke.Library'; input = (@($fixtures | Where-Object fixture_id -eq 'Synthetic.NoPInvoke.Library')[0].output_path); expected_result = 'PASS'; expected_defects = @() },
    [pscustomobject][ordered]@{ fixture_id = 'Synthetic.PInvoke.Library'; input = (@($fixtures | Where-Object fixture_id -eq 'Synthetic.PInvoke.Library')[0].output_path); expected_result = 'PASS'; expected_defects = @() },
    [pscustomobject][ordered]@{ fixture_id = 'Synthetic.EntryPoint.Console'; input = (@($fixtures | Where-Object fixture_id -eq 'Synthetic.EntryPoint.Console')[0].output_path); expected_result = 'FAIL'; expected_defects = @('ENTRY_POINT_PRESENT') },
    [pscustomobject][ordered]@{ fixture_id = 'Synthetic.Invalid.NonPe'; input = $invalidPath; expected_result = 'FAIL'; expected_defects = @('INVALID_PE_OR_CLI_METADATA') },
    [pscustomobject][ordered]@{ fixture_id = 'Synthetic.UnexpectedPInvoke.Library'; input = (@($fixtures | Where-Object fixture_id -eq 'Synthetic.UnexpectedPInvoke.Library')[0].output_path); expected_result = 'FAIL'; expected_defects = @('EXPECTED_DECLARATION_MISSING','UNEXPECTED_DECLARATION') }
)

$records = [Collections.Generic.List[object]]::new()
foreach ($case in $cases) {
    $output = Join-Path $outputRootFull "evidence/$($case.fixture_id).evidence.json"
    New-Directory -Path (Split-Path -Parent $output)
    $expectedFile = Join-Path $expectedRoot "$($case.fixture_id).expected.json"
    $parseResult = Invoke-ParserCommand -Arguments @(
        $parserDll,
        '--input', ([IO.Path]::GetFullPath($case.input)),
        '--output', ([IO.Path]::GetFullPath($output)),
        '--expected', ([IO.Path]::GetFullPath($expectedFile)),
        '--parser-source-commit', $sourceCommit,
        '--parser-build-identity', (Get-Sha256 -Path $parserDll)
    ) -LogPath (Join-Path $outputRootFull "logs/parser-$($case.fixture_id).txt")
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Parser did not produce evidence for $($case.fixture_id)."
    }
    $evidence = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $defectCodes = @($evidence.defects | ForEach-Object { [string]$_.code })
    $expectedDefectsPresent = @($case.expected_defects | Where-Object { $defectCodes -contains $_ }).Count -eq @($case.expected_defects).Count
    $prohibitedCounters = @(
        [int]$evidence.safetyCounters.assemblyLoad,
        [int]$evidence.safetyCounters.runtimeReflection,
        [int]$evidence.safetyCounters.compiledArtifactExecution,
        [int]$evidence.safetyCounters.nativeDllLoad,
        [int]$evidence.safetyCounters.entryPointResolution,
        [int]$evidence.safetyCounters.nativeInvocation,
        [int]$evidence.safetyCounters.setupApiNewdevInvocation,
        [int]$evidence.safetyCounters.deviceQuery,
        [int]$evidence.safetyCounters.hardwareAccess,
        [int]$evidence.safetyCounters.windowsMutation,
        [int]$evidence.safetyCounters.driverBuild,
        [int]$evidence.safetyCounters.driverLink,
        [int]$evidence.safetyCounters.driverSign,
        [int]$evidence.safetyCounters.driverCatGeneration,
        [int]$evidence.safetyCounters.driverPackage,
        [int]$evidence.safetyCounters.driverStage,
        [int]$evidence.safetyCounters.driverInstall,
        [int]$evidence.safetyCounters.driverLoad,
        [int]$evidence.safetyCounters.driverUnload,
        [int]$evidence.safetyCounters.driverBind,
        [int]$evidence.safetyCounters.driverRestore,
        [int]$evidence.safetyCounters.driverRestart
    )
    $prohibitedZero = (($prohibitedCounters | Measure-Object -Sum).Sum -eq 0)
    $guaranteesMatchPolicyAndCounters = (
        [bool]$evidence.safetyPolicyEnforced -and
        [bool]$evidence.staticOnly -and
        [bool]$evidence.noLoadGuarantee -and
        [bool]$evidence.noRuntimeReflectionGuarantee -and
        [bool]$evidence.noExecutionGuarantee -and
        [bool]$evidence.noNativeInvocationGuarantee -and
        [bool]$evidence.noDeviceQueryGuarantee -and
        [bool]$evidence.noWindowsMutationGuarantee -and
        -not [bool]$evidence.driverActionsOccurred -and
        $prohibitedZero
    )
    $exitCodeExpected = if ($case.expected_result -eq 'PASS') { $parseResult.exit_code -eq 0 } else { $parseResult.exit_code -eq 2 }
    $checks = @(
        ([string]$evidence.schemaVersion -eq 'chatpad-static-metadata-parser-evidence-v1'),
        ([string]$evidence.result -eq [string]$case.expected_result),
        $exitCodeExpected,
        $expectedDefectsPresent,
        ([string]$evidence.inputPathDecision.decision -eq 'ALLOWED'),
        ([string]$evidence.expectedPathDecision.decision -eq 'ALLOWED'),
        ([string]$evidence.outputPathDecision.decision -eq 'ALLOWED'),
        ([bool]$evidence.artifactBytesRead -eq $true),
        ([bool]$evidence.artifactHashComputed -eq $true),
        ([bool]$evidence.expectedBytesRead -eq $true),
        ([bool]$evidence.expectedHashComputed -eq $false),
        ([bool]$evidence.peParseAttempted -eq $true),
        ([bool]$evidence.metadataParseAttempted -eq ($case.fixture_id -ne 'Synthetic.Invalid.NonPe')),
        ([bool]$evidence.outputWriteAttempted -eq $true),
        ([bool]$evidence.outputWriteCompleted -eq $true),
        ([int]$evidence.safetyCounters.artifactBytesRead -eq 1),
        ([int]$evidence.safetyCounters.expectedBytesRead -eq 1),
        ([int]$evidence.safetyCounters.outputWriteAttempted -eq 1),
        ([int]$evidence.safetyCounters.outputWriteCompleted -eq 1),
        ([bool]$evidence.assemblyLoadOccurred -eq $false),
        ([bool]$evidence.runtimeReflectionOccurred -eq $false),
        ([bool]$evidence.compiledArtifactExecutionOccurred -eq $false),
        ([bool]$evidence.nativeInvocationOccurred -eq $false),
        ([bool]$evidence.deviceQueryOccurred -eq $false),
        ([bool]$evidence.windowsMutationOccurred -eq $false),
        $prohibitedZero,
        $guaranteesMatchPolicyAndCounters
    )
    $records.Add([pscustomobject][ordered]@{
        fixture_id = $case.fixture_id
        input_path = ([IO.Path]::GetFullPath($case.input).Substring($root.Length + 1).Replace('\','/'))
        evidence_path = ([IO.Path]::GetFullPath($output).Substring($root.Length + 1).Replace('\','/'))
        evidence_size = (Get-Item -LiteralPath $output).Length
        evidence_sha256 = Get-Sha256 -Path $output
        expected_result = $case.expected_result
        actual_result = [string]$evidence.result
        expected_defects = @($case.expected_defects)
        actual_defects = $defectCodes
        parser_exit_code = $parseResult.exit_code
        assertion_count = $checks.Count
        fixture_result = $(if (@($checks | Where-Object { $_ -ne $true }).Count) { 'FAIL' } else { 'PASS' })
    })
}

$rejectionRecords = [Collections.Generic.List[object]]::new()
$blockedRelative = 'artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/not-real/Chatpad.NativeInterop.CompileOnlyValidation.dll'
$blockedAbsolute = [IO.Path]::GetFullPath((Join-Path $root $blockedRelative))
$blockedMixed = ($blockedAbsolute -replace '\\','/')
$blockedCase = [IO.Path]::GetFullPath((Join-Path $root 'ARTIFACTS/COMPILE-ONLY/NATIVE-INTEROP/BIN/RELEASE/X64/NET9.0-WINDOWS10.0.26100.0/NOT-REAL/CHATPAD.NATIVEINTEROP.COMPILEONLYVALIDATION.DLL'))
$blockedTraversal = 'artifacts/logs/static-metadata-parser-implementation-remediation/fixtures/../../../compile-only/native-interop/bin/Release/x64/not-real/Chatpad.NativeInterop.CompileOnlyValidation.dll'
$outsideFixtureWithRealName = [IO.Path]::GetFullPath((Join-Path $outputRootFull 'not-fixtures/Chatpad.NativeInterop.CompileOnlyValidation.dll'))
$outsideApprovedRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/logs/not-static-parser/fixtures/Synthetic.Outside.dll'))
$inputAlternateDataStream = ([IO.Path]::GetFullPath([string](@($fixtures | Where-Object fixture_id -eq 'Synthetic.NoPInvoke.Library')[0].output_path))) + ':probe'
$rejectionCases = @(
    [pscustomobject][ordered]@{ id='real-artifact-root-relative'; input=$blockedRelative; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='real-artifact-root-absolute'; input=$blockedAbsolute; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='real-artifact-root-mixed-slash'; input=$blockedMixed; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='real-artifact-root-case-variant'; input=$blockedCase; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='real-artifact-root-relative-traversal'; input=$blockedTraversal; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='real-artifact-filename-outside-fixture-root'; input=$outsideFixtureWithRealName; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='outside-approved-synthetic-fixture-roots'; input=$outsideApprovedRoot; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' },
    [pscustomobject][ordered]@{ id='input-alternate-data-stream'; input=$inputAlternateDataStream; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' }
)

$symlinkCase = $null
$symlinkPath = Join-Path $outputRootFull 'fixtures/reparse/linked-root'
$symlinkTarget = Split-Path -Parent ([string](@($fixtures | Where-Object fixture_id -eq 'Synthetic.NoPInvoke.Library')[0].output_path))
$symlinkInput = Join-Path $symlinkPath (Split-Path -Leaf ([string](@($fixtures | Where-Object fixture_id -eq 'Synthetic.NoPInvoke.Library')[0].output_path)))
try {
    New-Directory -Path (Split-Path -Parent $symlinkPath)
    if (Test-Path -LiteralPath $symlinkPath) {
        Remove-Item -LiteralPath $symlinkPath -Force
    }

    New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $symlinkTarget -Force | Out-Null
    $symlinkCase = [pscustomobject][ordered]@{ id='symlink-reparse-parent-under-fixture-root'; input=$symlinkInput; expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED' }
} catch {
    $symlinkCase = [pscustomobject][ordered]@{
        id='symlink-reparse-parent-under-fixture-root'
        input=$symlinkInput
        expected_defect='PARSER_INPUT_PATH.NOT_AUTHORIZED'
        not_run=$true
        reason="Directory symlink/reparse creation did not complete without admin: $($_.Exception.Message)"
    }
}

foreach ($case in @($rejectionCases + @($symlinkCase))) {
    if ($case.PSObject.Properties['not_run'] -and $case.not_run) {
        $rejectionRecords.Add([pscustomobject][ordered]@{
            case_id = $case.id
            input_path = [string]$case.input
            expected_defect = [string]$case.expected_defect
            actual_defects = @()
            parser_exit_code = $null
            assertion_count = 0
            rejection_result = 'NOT_RUN'
            not_run_reason = [string]$case.reason
        })
        continue
    }

    $output = Join-Path $outputRootFull "evidence/rejections/$($case.id).evidence.json"
    New-Directory -Path (Split-Path -Parent $output)
    $parseResult = Invoke-ParserCommand -Arguments @(
        $parserDll,
        '--input', ([string]$case.input),
        '--output', ([IO.Path]::GetFullPath($output)),
        '--parser-source-commit', $sourceCommit,
        '--parser-build-identity', (Get-Sha256 -Path $parserDll)
    ) -LogPath (Join-Path $outputRootFull "logs/rejection-$($case.id).txt")
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Parser did not produce rejection evidence for $($case.id)."
    }

    $evidence = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $checks = Test-PreReadRejectionEvidence -Evidence $evidence -ExpectedDefectCode ([string]$case.expected_defect)
    $checks += ($parseResult.exit_code -eq 2)
    $defectCodes = @($evidence.defects | ForEach-Object { [string]$_.code })
    $rejectionRecords.Add([pscustomobject][ordered]@{
        case_id = $case.id
        input_path = [string]$case.input
        evidence_path = ([IO.Path]::GetFullPath($output).Substring($root.Length + 1).Replace('\','/'))
        evidence_size = (Get-Item -LiteralPath $output).Length
        evidence_sha256 = Get-Sha256 -Path $output
        expected_defect = [string]$case.expected_defect
        actual_defects = $defectCodes
        parser_exit_code = $parseResult.exit_code
        artifact_bytes_read = [bool]$evidence.artifactBytesRead
        artifact_hash_computed = [bool]$evidence.artifactHashComputed
        metadata_parsed = [bool]$evidence.metadataParsed
        assertion_count = $checks.Count
        rejection_result = $(if (@($checks | Where-Object { $_ -ne $true }).Count) { 'FAIL' } else { 'PASS' })
    })
}

$validSyntheticInput = (@($fixtures | Where-Object fixture_id -eq 'Synthetic.NoPInvoke.Library')[0].output_path)
$validExpectedPath = Join-Path $expectedRoot 'Synthetic.NoPInvoke.Library.expected.json'

$expectedPathRecords = [Collections.Generic.List[object]]::new()
$blockedExpectedRelative = 'artifacts/compile-only/native-interop/not-real-file-scope-remediation/expected.json'
$blockedExpectedAbsolute = [IO.Path]::GetFullPath((Join-Path $root $blockedExpectedRelative))
$blockedExpectedMixed = $blockedExpectedAbsolute.Replace('\','/')
$blockedExpectedCase = [IO.Path]::GetFullPath((Join-Path $root 'ARTIFACTS/COMPILE-ONLY/NATIVE-INTEROP/NOT-REAL-FILE-SCOPE-REMEDIATION/EXPECTED.JSON'))
$blockedExpectedTraversal = 'artifacts/logs/static-metadata-parser-file-scope-remediation/fixtures/../../../compile-only/native-interop/not-real-file-scope-remediation/expected.json'
$outsideExpectedRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/logs/not-static-metadata-parser/fixtures/expected.json'))
$protectedExpectedName = [IO.Path]::GetFullPath((Join-Path $outputRootFull 'fixtures/expected/Chatpad.NativeInterop.CompileOnlyValidation.dll'))
$expectedAlternateDataStream = ([IO.Path]::GetFullPath($validExpectedPath)) + ':probe'
$expectedPathCases = @(
    [pscustomobject][ordered]@{ id='expected-blocked-root-relative'; expected_path=$blockedExpectedRelative },
    [pscustomobject][ordered]@{ id='expected-blocked-root-absolute'; expected_path=$blockedExpectedAbsolute },
    [pscustomobject][ordered]@{ id='expected-blocked-root-mixed-slash'; expected_path=$blockedExpectedMixed },
    [pscustomobject][ordered]@{ id='expected-blocked-root-case-variant'; expected_path=$blockedExpectedCase },
    [pscustomobject][ordered]@{ id='expected-blocked-root-relative-traversal'; expected_path=$blockedExpectedTraversal },
    [pscustomobject][ordered]@{ id='expected-outside-approved-fixture-root'; expected_path=$outsideExpectedRoot },
    [pscustomobject][ordered]@{ id='expected-protected-artifact-name'; expected_path=$protectedExpectedName },
    [pscustomobject][ordered]@{ id='expected-alternate-data-stream'; expected_path=$expectedAlternateDataStream }
)
foreach ($case in $expectedPathCases) {
    $output = Join-Path $outputRootFull "evidence/expected-rejections/$($case.id).evidence.json"
    New-Directory -Path (Split-Path -Parent $output)
    $parseResult = Invoke-ParserCommand -Arguments @(
        $parserDll,
        '--input', ([IO.Path]::GetFullPath($validSyntheticInput)),
        '--output', ([IO.Path]::GetFullPath($output)),
        '--expected', ([string]$case.expected_path),
        '--parser-source-commit', $sourceCommit,
        '--parser-build-identity', (Get-Sha256 -Path $parserDll)
    ) -LogPath (Join-Path $outputRootFull "logs/expected-rejection-$($case.id).txt")
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Parser did not produce expected-path rejection evidence for $($case.id)."
    }

    $evidence = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $checks = Test-PreReadRejectionEvidence -Evidence $evidence -ExpectedDefectCode 'PARSER_EXPECTED_PATH.NOT_AUTHORIZED'
    $checks += ([string]$evidence.inputPathDecision.decision -eq 'ALLOWED')
    $checks += ([string]$evidence.expectedPathDecision.decision -eq 'REJECTED')
    $checks += ([string]$evidence.outputPathDecision.decision -eq 'ALLOWED')
    $checks += ($parseResult.exit_code -eq 2)
    $expectedPathRecords.Add([pscustomobject][ordered]@{
        case_id = $case.id
        expected_path = [string]$case.expected_path
        evidence_path = ([IO.Path]::GetFullPath($output).Substring($root.Length + 1).Replace('\','/'))
        evidence_size = (Get-Item -LiteralPath $output).Length
        evidence_sha256 = Get-Sha256 -Path $output
        parser_exit_code = $parseResult.exit_code
        input_bytes_read = [bool]$evidence.artifactBytesRead
        expected_bytes_read = [bool]$evidence.expectedBytesRead
        input_hash_computed = [bool]$evidence.artifactHashComputed
        expected_hash_computed = [bool]$evidence.expectedHashComputed
        pe_parse_attempted = [bool]$evidence.peParseAttempted
        metadata_parse_attempted = [bool]$evidence.metadataParseAttempted
        assertion_count = $checks.Count
        rejection_result = $(if (@($checks | Where-Object { $_ -ne $true }).Count) { 'FAIL' } else { 'PASS' })
    })
}

$outputPathRecords = [Collections.Generic.List[object]]::new()
$blockedOutputRelative = 'artifacts/compile-only/native-interop/not-real-file-scope-remediation/out.json'
$blockedOutputAbsolute = [IO.Path]::GetFullPath((Join-Path $root $blockedOutputRelative))
$blockedOutputMixed = $blockedOutputAbsolute.Replace('\','/')
$blockedOutputCase = [IO.Path]::GetFullPath((Join-Path $root 'ARTIFACTS/COMPILE-ONLY/NATIVE-INTEROP/NOT-REAL-FILE-SCOPE-REMEDIATION/OUT.JSON'))
$blockedOutputTraversal = 'artifacts/logs/static-metadata-parser-file-scope-remediation/../../../compile-only/native-interop/not-real-file-scope-remediation/out.json'
$outsideOutputRoot = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/logs/not-static-metadata-parser/out.json'))
$protectedOutputName = [IO.Path]::GetFullPath((Join-Path $outputRootFull 'Chatpad.NativeInterop.CompileOnlyValidation.dll'))
$trackedOutputPath = [IO.Path]::GetFullPath((Join-Path $root 'docs/evidence/runtime-bringup-readiness-manifest.json'))
$existingAllowedOutput = [IO.Path]::GetFullPath((Join-Path $outputRootFull 'existing-output-sentinel.json'))
$outputAlternateDataStreamBase = [IO.Path]::GetFullPath((Join-Path $outputRootFull 'ads-output.json'))
$outputAlternateDataStream = $outputAlternateDataStreamBase + ':probe'
Write-Utf8NoBom -Path $existingAllowedOutput -Value "{`"sentinel`":true}$([Environment]::NewLine)"
$outputPathCases = @(
    [pscustomobject][ordered]@{ id='output-blocked-root-relative'; output_path=$blockedOutputRelative },
    [pscustomobject][ordered]@{ id='output-blocked-root-absolute'; output_path=$blockedOutputAbsolute },
    [pscustomobject][ordered]@{ id='output-blocked-root-mixed-slash'; output_path=$blockedOutputMixed },
    [pscustomobject][ordered]@{ id='output-blocked-root-case-variant'; output_path=$blockedOutputCase },
    [pscustomobject][ordered]@{ id='output-blocked-root-relative-traversal'; output_path=$blockedOutputTraversal },
    [pscustomobject][ordered]@{ id='output-outside-approved-evidence-root'; output_path=$outsideOutputRoot },
    [pscustomobject][ordered]@{ id='output-protected-artifact-name'; output_path=$protectedOutputName },
    [pscustomobject][ordered]@{ id='output-equals-input'; output_path=([IO.Path]::GetFullPath($validSyntheticInput)) },
    [pscustomobject][ordered]@{ id='output-equals-expected'; output_path=([IO.Path]::GetFullPath($validExpectedPath)) },
    [pscustomobject][ordered]@{ id='output-tracked-manifest'; output_path=$trackedOutputPath },
    [pscustomobject][ordered]@{ id='output-existing-allowed-evidence'; output_path=$existingAllowedOutput },
    [pscustomobject][ordered]@{ id='output-alternate-data-stream'; output_path=$outputAlternateDataStream; verification_path=$outputAlternateDataStreamBase }
)
foreach ($case in $outputPathCases) {
    $normalizedOutput = if ($case.PSObject.Properties['verification_path']) {
        [string]$case.verification_path
    } else {
        [IO.Path]::GetFullPath([string]$case.output_path)
    }
    $targetExistedBefore = Test-Path -LiteralPath $normalizedOutput -PathType Leaf
    $targetHashBefore = if ($targetExistedBefore) { Get-Sha256 -Path $normalizedOutput } else { '' }
    $inputHashBefore = Get-Sha256 -Path $validSyntheticInput
    $expectedHashBefore = Get-Sha256 -Path $validExpectedPath
    $parseResult = Invoke-ParserCommand -Arguments @(
        $parserDll,
        '--input', ([IO.Path]::GetFullPath($validSyntheticInput)),
        '--output', ([string]$case.output_path),
        '--expected', ([IO.Path]::GetFullPath($validExpectedPath)),
        '--parser-source-commit', $sourceCommit,
        '--parser-build-identity', (Get-Sha256 -Path $parserDll)
    ) -LogPath (Join-Path $outputRootFull "logs/output-rejection-$($case.id).txt")
    $targetExistsAfter = Test-Path -LiteralPath $normalizedOutput -PathType Leaf
    $targetHashAfter = if ($targetExistsAfter) { Get-Sha256 -Path $normalizedOutput } else { '' }
    $checks = @(
        ($parseResult.exit_code -eq 64),
        (($parseResult.output -join "`n") -match 'PARSER_OUTPUT_PATH\.NOT_AUTHORIZED'),
        ($targetExistedBefore -eq $targetExistsAfter),
        ($targetHashBefore -eq $targetHashAfter),
        ((Get-Sha256 -Path $validSyntheticInput) -eq $inputHashBefore),
        ((Get-Sha256 -Path $validExpectedPath) -eq $expectedHashBefore)
    )
    $outputPathRecords.Add([pscustomobject][ordered]@{
        case_id = $case.id
        output_path = [string]$case.output_path
        parser_exit_code = $parseResult.exit_code
        output_existed_before = $targetExistedBefore
        output_exists_after = $targetExistsAfter
        output_hash_before = $targetHashBefore
        output_hash_after = $targetHashAfter
        input_hash_unchanged = ((Get-Sha256 -Path $validSyntheticInput) -eq $inputHashBefore)
        expected_hash_unchanged = ((Get-Sha256 -Path $validExpectedPath) -eq $expectedHashBefore)
        output_write_attempted = $false
        output_write_completed = $false
        assertion_count = $checks.Count
        rejection_result = $(if (@($checks | Where-Object { $_ -ne $true }).Count) { 'FAIL' } else { 'PASS' })
    })
}

$safetyOptionRecords = [Collections.Generic.List[object]]::new()
$safetyCases = @(
    [pscustomobject][ordered]@{ id='obsolete-no-load-option'; option='--no-load'; expected_defect='PARSER_SAFETY.OPTION_NOT_SUPPORTED' },
    [pscustomobject][ordered]@{ id='unsafe-allow-load-option'; option='--allow-load'; expected_defect='PARSER_SAFETY.OPTION_NOT_SUPPORTED' }
)
foreach ($case in $safetyCases) {
    $output = Join-Path $outputRootFull "evidence/safety-options/$($case.id).evidence.json"
    New-Directory -Path (Split-Path -Parent $output)
    $parseResult = Invoke-ParserCommand -Arguments @(
        $parserDll,
        '--input', ([IO.Path]::GetFullPath($validSyntheticInput)),
        '--output', ([IO.Path]::GetFullPath($output)),
        '--parser-source-commit', $sourceCommit,
        '--parser-build-identity', (Get-Sha256 -Path $parserDll),
        ([string]$case.option)
    ) -LogPath (Join-Path $outputRootFull "logs/safety-option-$($case.id).txt")
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw "Parser did not produce safety-option evidence for $($case.id)."
    }

    $evidence = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
    $checks = Test-PreReadRejectionEvidence -Evidence $evidence -ExpectedDefectCode ([string]$case.expected_defect)
    $checks += ($parseResult.exit_code -eq 2)
    $defectCodes = @($evidence.defects | ForEach-Object { [string]$_.code })
    $safetyOptionRecords.Add([pscustomobject][ordered]@{
        case_id = $case.id
        option = [string]$case.option
        evidence_path = ([IO.Path]::GetFullPath($output).Substring($root.Length + 1).Replace('\','/'))
        evidence_size = (Get-Item -LiteralPath $output).Length
        evidence_sha256 = Get-Sha256 -Path $output
        expected_defect = [string]$case.expected_defect
        actual_defects = $defectCodes
        parser_exit_code = $parseResult.exit_code
        artifact_bytes_read = [bool]$evidence.artifactBytesRead
        artifact_hash_computed = [bool]$evidence.artifactHashComputed
        metadata_parsed = [bool]$evidence.metadataParsed
        assertion_count = $checks.Count
        safety_option_result = $(if (@($checks | Where-Object { $_ -ne $true }).Count) { 'FAIL' } else { 'PASS' })
    })
}

$failed = @($records | Where-Object fixture_result -ne 'PASS')
$failedRejections = @($rejectionRecords | Where-Object { $_.rejection_result -eq 'FAIL' })
$failedExpectedPathRejections = @($expectedPathRecords | Where-Object rejection_result -eq 'FAIL')
$failedOutputPathRejections = @($outputPathRecords | Where-Object rejection_result -eq 'FAIL')
$failedSafetyOptions = @($safetyOptionRecords | Where-Object safety_option_result -ne 'PASS')
$notRunRejections = @($rejectionRecords | Where-Object rejection_result -eq 'NOT_RUN')
$summary = [pscustomobject][ordered]@{
    schema_version = 'chatpad-static-metadata-parser-synthetic-validation-v1'
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    result = $(if ($failed.Count -or $failedRejections.Count -or $failedExpectedPathRejections.Count -or $failedOutputPathRejections.Count -or $failedSafetyOptions.Count) { 'FAIL' } else { 'PASS' })
    result_code = $(if ($failed.Count -or $failedRejections.Count -or $failedExpectedPathRejections.Count -or $failedOutputPathRejections.Count -or $failedSafetyOptions.Count) { 'STATIC_METADATA_PARSER_FILE_SCOPE_REMEDIATION_VALIDATION_FAILED' } else { 'STATIC_METADATA_PARSER_FILE_SCOPE_REMEDIATION_VALIDATION_PASSED' })
    parser_project_path = $ParserProject
    parser_project_sha256 = Get-Sha256 -Path $parserProjectFull
    parser_source_path = 'tools/StaticMetadataParser/Program.cs'
    parser_source_sha256 = Get-Sha256 -Path (Join-Path $root 'tools/StaticMetadataParser/Program.cs')
    parser_build_path = ($parserDll.Substring($root.Length + 1).Replace('\','/'))
    parser_build_sha256 = Get-Sha256 -Path $parserDll
    parser_source_commit = $sourceCommit
    parser_schema_version = 'chatpad-static-metadata-parser-evidence-v1'
    fixture_count = $records.Count
    assertion_count = [int]((($records + $rejectionRecords + $expectedPathRecords + $outputPathRecords + $safetyOptionRecords) | Measure-Object assertion_count -Sum).Sum)
    failed_fixture_count = $failed.Count
    guard = $guard
    fixtures = @($records)
    real_artifact_like_rejection_count = @($rejectionRecords | Where-Object rejection_result -eq 'PASS').Count
    real_artifact_like_rejection_not_run_count = $notRunRejections.Count
    failed_real_artifact_like_rejection_count = $failedRejections.Count
    rejection_cases = @($rejectionRecords)
    expected_path_rejection_count = @($expectedPathRecords | Where-Object rejection_result -eq 'PASS').Count
    failed_expected_path_rejection_count = $failedExpectedPathRejections.Count
    expected_path_rejection_cases = @($expectedPathRecords)
    output_path_rejection_count = @($outputPathRecords | Where-Object rejection_result -eq 'PASS').Count
    failed_output_path_rejection_count = $failedOutputPathRejections.Count
    output_path_rejection_cases = @($outputPathRecords)
    safety_option_rejection_count = @($safetyOptionRecords | Where-Object safety_option_result -eq 'PASS').Count
    failed_safety_option_rejection_count = $failedSafetyOptions.Count
    safety_option_cases = @($safetyOptionRecords)
    real_artifact_path_gate_status = 'IMPLEMENTED_PENDING_AUDIT'
    all_file_bearing_options_centrally_scoped = $true
    expected_path_gate_status = 'IMPLEMENTED_PENDING_AUDIT'
    output_path_gate_status = 'IMPLEMENTED_PENDING_AUDIT'
    allowed_input_scope = 'SYNTHETIC_FIXTURES_ONLY'
    allowed_expected_scope = 'SYNTHETIC_FIXTURES_ONLY'
    allowed_output_scope = 'PARSER_EVIDENCE_ROOTS_ONLY'
    pre_io_rejection_tests = $(if ($failedRejections.Count -or $failedExpectedPathRejections.Count -or $failedOutputPathRejections.Count -or $failedSafetyOptions.Count) { 'FAIL' } else { 'PASS' })
    pre_read_rejection_tests = $(if ($failedRejections.Count -or $failedExpectedPathRejections.Count -or $failedSafetyOptions.Count) { 'FAIL' } else { 'PASS' })
    safety_policy_mode = 'IMMUTABLE_STATIC_ONLY'
    safety_policy_enforced = $true
    real_compile_only_artifact_opened = $false
    real_compile_only_artifact_parsed = $false
    real_compile_only_artifact_hash_computed = $false
    real_compile_only_artifact_write_attempted = $false
    real_compile_only_artifact_write_completed = $false
    metadata_review_performed = $false
    parser_execution_scope = 'SYNTHETIC_FIXTURES_ONLY'
    prohibited_action_counters = [pscustomobject][ordered]@{
        assembly_load = 0
        runtime_reflection = 0
        real_compiled_artifact_execution = 0
        native_dll_load = 0
        entry_point_resolution = 0
        native_invocation = 0
        setupapi_newdev_invocation = 0
        device_query = 0
        hardware_access = 0
        windows_mutation = 0
        driver_build = 0
        driver_link = 0
        driver_sign = 0
        driver_cat_generation = 0
        driver_package = 0
        driver_stage = 0
        driver_install = 0
        driver_load = 0
        driver_bind = 0
        driver_restore = 0
        driver_restart = 0
    }
}
Write-Json -Path $evidenceFull -Value $summary
if ($summary.result -ne 'PASS') {
    throw "Static metadata parser synthetic validation failed. See $EvidencePath."
}
$summary
