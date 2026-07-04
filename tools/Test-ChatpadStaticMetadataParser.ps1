[CmdletBinding()]
param(
    [string]$OutputRoot = 'artifacts/static-metadata-parser-implementation',
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
    $output = @(& dotnet @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Write-Utf8NoBom -Path $LogPath -Value (($output -join [Environment]::NewLine) + [Environment]::NewLine)
    [pscustomobject][ordered]@{ exit_code = $exitCode; output = $output }
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
        '--parser-build-identity', (Get-Sha256 -Path $parserDll),
        '--no-load',
        '--no-reflection',
        '--no-execute',
        '--no-native-invoke'
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
    $exitCodeExpected = if ($case.expected_result -eq 'PASS') { $parseResult.exit_code -eq 0 } else { $parseResult.exit_code -eq 2 }
    $checks = @(
        ([string]$evidence.schemaVersion -eq 'chatpad-static-metadata-parser-evidence-v1'),
        ([string]$evidence.result -eq [string]$case.expected_result),
        $exitCodeExpected,
        $expectedDefectsPresent,
        ([bool]$evidence.artifactBytesRead -eq $true),
        ([bool]$evidence.artifactHashComputed -eq $true),
        ([bool]$evidence.assemblyLoadOccurred -eq $false),
        ([bool]$evidence.runtimeReflectionOccurred -eq $false),
        ([bool]$evidence.compiledArtifactExecutionOccurred -eq $false),
        ([bool]$evidence.nativeInvocationOccurred -eq $false),
        ([bool]$evidence.deviceQueryOccurred -eq $false),
        ([bool]$evidence.windowsMutationOccurred -eq $false),
        $prohibitedZero
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

$failed = @($records | Where-Object fixture_result -ne 'PASS')
$summary = [pscustomobject][ordered]@{
    schema_version = 'chatpad-static-metadata-parser-synthetic-validation-v1'
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    result = $(if ($failed.Count) { 'FAIL' } else { 'PASS' })
    result_code = $(if ($failed.Count) { 'SYNTHETIC_FIXTURE_VALIDATION_FAILED' } else { 'SYNTHETIC_FIXTURE_VALIDATION_PASSED' })
    parser_project_path = $ParserProject
    parser_project_sha256 = Get-Sha256 -Path $parserProjectFull
    parser_source_path = 'tools/StaticMetadataParser/Program.cs'
    parser_source_sha256 = Get-Sha256 -Path (Join-Path $root 'tools/StaticMetadataParser/Program.cs')
    parser_build_path = ($parserDll.Substring($root.Length + 1).Replace('\','/'))
    parser_build_sha256 = Get-Sha256 -Path $parserDll
    parser_source_commit = $sourceCommit
    parser_schema_version = 'chatpad-static-metadata-parser-evidence-v1'
    fixture_count = $records.Count
    assertion_count = [int](($records | Measure-Object assertion_count -Sum).Sum)
    failed_fixture_count = $failed.Count
    guard = $guard
    fixtures = @($records)
    real_compile_only_artifact_opened = $false
    real_compile_only_artifact_parsed = $false
    real_compile_only_artifact_hash_computed = $false
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
