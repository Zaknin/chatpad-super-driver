[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration,

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter()]
    [switch]$SelfTestOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifactsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'artifacts'))
$fullOutputPath = [System.IO.Path]::GetFullPath(
    $(if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    } else {
        Join-Path $repoRoot $OutputPath
    }))
if (-not $fullOutputPath.StartsWith(
        $artifactsRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Regression matrix output must remain beneath ignored artifacts/.'
}

function New-AssertionContract {
    param(
        [string]$Id,
        [string]$Script,
        [string[]]$Arguments,
        [string]$ExecutedPattern = '^Total assertions:\s*(\d+)\s*$')
    return [pscustomobject]@{
        Id = $Id
        Script = $Script
        Arguments = $Arguments
        Kind = 'assertion-bearing'
        ExecutedPattern = $ExecutedPattern
        PassedPattern = '^Passed assertions:\s*(\d+)\s*$'
        FailedPattern = '^Failed assertions:\s*(\d+)\s*$'
        ValidationType = $null
        RequiredChecks = @()
    }
}

function New-ValidationContract {
    param(
        [string]$Id,
        [string]$Script,
        [string[]]$Arguments,
        [string]$ValidationType,
        [object[]]$RequiredChecks)
    return [pscustomobject]@{
        Id = $Id
        Script = $Script
        Arguments = $Arguments
        Kind = 'non-assertion-validation'
        ExecutedPattern = $null
        PassedPattern = $null
        FailedPattern = $null
        ValidationType = $ValidationType
        RequiredChecks = @($RequiredChecks)
    }
}

$commands = @(
    New-AssertionContract 'request-owner-model' 'tools\Test-ChatpadRequestOwnerModel.ps1' @('-Configuration', $Configuration, '-Platform', $Platform)
    New-AssertionContract 'protocol' 'tools\Test-ChatpadProtocol.ps1' @('-Configuration', $Configuration, '-Platform', $Platform)
    New-AssertionContract 'transport' 'tools\Test-ChatpadTransport.ps1' @('-Configuration', $Configuration, '-Platform', $Platform)
    New-AssertionContract 'lifecycle' 'tools\Test-ChatpadFilterLifecycle.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) '^Lifecycle assertions:\s*(\d+)\s*$'
    New-AssertionContract 'control-setup' 'tools\Test-ChatpadControlSetup.ps1' @('-Configuration', $Configuration, '-Platform', $Platform)
    New-ValidationContract 'protocol-kernel-compatibility' 'tools\Test-ChatpadProtocolKernelCompatibility.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) 'compile-and-safety-validation' @(
        @{ Name = 'signing-execution-absence'; Pattern = '^Signing execution scan: PASS' },
        @{ Name = 'prohibited-output-absence'; Pattern = '^Prohibited output scan: PASS' },
        @{ Name = 'artifact-containment'; Pattern = '^Artifact containment: PASS' })
    New-ValidationContract 'wdf-control-setup' 'tools\Test-ChatpadWdfControlSetup.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) 'source-build-dormancy-validation' @(
        @{ Name = 'source-project-prohibition'; Pattern = '^Source/project prohibition guard: PASS' },
        @{ Name = 'dormancy'; Pattern = '^Dormancy guard: PASS' },
        @{ Name = 'authoritative-api'; Pattern = '^Authoritative API guard: PASS' },
        @{ Name = 'formatter-final'; Pattern = '^WDF control-setup formatter guard: PASS\.$' })
    New-ValidationContract 'production-linkage' 'tools\Test-ChatpadProductionLinkage.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) 'production-linkage-validation' @(
        @{ Name = 'production-linkage-semantic'; Pattern = '^Production linkage semantic guard: PASS' })
    New-ValidationContract 'production-owner-initialization-full' 'tools\Test-ChatpadProductionOwnerInitialization.ps1' @('-Configuration', $Configuration, '-Platform', $Platform, '-InspectionMode', 'Full') 'production-owner-static-and-binary-guard' @(
        @{ Name = 'machine-result'; Pattern = '^CHATPAD_VALIDATION_JSON=' },
        @{ Name = 'full-mode'; Pattern = '^Inspection mode: Full$' },
        @{ Name = 'cleanup-classification'; Pattern = '^CleanupOwnerObservationClassification=diagnostic-read-only-object-snapshot$' })
    New-ValidationContract 'kmdf-request-owner-context' 'tools\Test-ChatpadKmdfRequestOwnerContext.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) 'compile-semantic-safety-validation' @(
        @{ Name = 'semantic-guard'; Pattern = '^Semantic guard: PASS' },
        @{ Name = 'semantic-check-total'; Pattern = '^SemanticChecksTotal=(\d+)$' },
        @{ Name = 'semantic-check-passed'; Pattern = '^SemanticChecksPassed=(\d+)$' },
        @{ Name = 'final-guard'; Pattern = '^KMDF request-owner context compile-check guard: PASS\.$' })
    New-ValidationContract 'production-orchestration-full' 'tools\Test-ChatpadProductionOrchestrationInvocation.ps1' @('-Configuration', $Configuration, '-Platform', $Platform, '-InspectionMode', 'Full') 'production-orchestration-static-and-binary-guard' @(
        @{ Name = 'missing-result-zero'; Pattern = '^Missing result count: 0$' },
        @{ Name = 'duplicate-result-zero'; Pattern = '^Duplicate result count: 0$' },
        @{ Name = 'unexpected-result-zero'; Pattern = '^Unexpected result count: 0$' },
        @{ Name = 'result-pass'; Pattern = '^Result: PASS$' })
    New-ValidationContract 'runtime-instrumentation' 'tools\Test-ChatpadRuntimeInstrumentation.ps1' @('-Configuration', $Configuration, '-Platform', $Platform) 'static-production-instrumentation-guard' @(
        @{ Name = 'machine-result'; Pattern = '^CHATPAD_VALIDATION_JSON=' },
        @{ Name = 'missing-mapping-zero'; Pattern = '^MissingMappingCount=0$' },
        @{ Name = 'unexplained-wpp-zero'; Pattern = '^UnexplainedWppSiteCount=0$' },
        @{ Name = 'negative-fixtures'; Pattern = '^EmissionMapNegativeSelfTests=10$' },
        @{ Name = 'dynamic-negative-fixtures'; Pattern = '^DynamicEmitterNegativeSelfTests=10$' })
    New-AssertionContract 'runtime-instrumentation-pure-model' 'tests\offline\RuntimeInstrumentationModel\Test-RuntimeInstrumentationModel.ps1' @('-Configuration', $Configuration) '^AssertionsExecuted=(\d+)\s*$'
)

function Get-SingleRegexValue {
    param([string[]]$Output, [string]$Pattern, [string]$Description)
    $values = @()
    foreach ($line in $Output) {
        $match = [regex]::Match($line, $Pattern)
        if ($match.Success) { $values += [int]$match.Groups[1].Value }
    }
    if ($values.Count -ne 1) {
        throw "$Description must appear exactly once; found $($values.Count)."
    }
    return [int]$values[0]
}

function Assert-ConfigurationBinding {
    param([string[]]$Output, [string]$ExpectedConfiguration)
    $text = $Output -join "`n"
    $opposite = if ($ExpectedConfiguration -ceq 'Debug') { 'Release' } else { 'Debug' }
    $declaredPattern = '(?m)^Configuration\s*[:=]\s*' +
        [regex]::Escape($ExpectedConfiguration) + '(?:\|x64)?\s*$'
    $inlineConfigurationPattern = '(?i)\b' +
        [regex]::Escape($ExpectedConfiguration) + '\|x64\b'
    $artifactPattern = '(?i)[\\/]x64[\\/]' + [regex]::Escape($ExpectedConfiguration) + '[\\/]'
    if ($text -notmatch $declaredPattern -and
        $text -notmatch $inlineConfigurationPattern -and
        $text -notmatch $artifactPattern) {
        throw "Child result is not bound to $ExpectedConfiguration."
    }
    $oppositeArtifactPattern = '(?i)[\\/]x64[\\/]' + [regex]::Escape($opposite) + '[\\/]'
    if ($text -match $oppositeArtifactPattern) {
        throw "Child output contains contradictory $opposite artifact evidence."
    }
}

function Convert-AssertionResult {
    param(
        [object]$Contract,
        [string[]]$Output,
        [int]$ExitCode,
        [string]$ExpectedConfiguration)

    if ($ExitCode -ne 0) { throw "Child exited nonzero: $ExitCode" }
    if ($Output.Count -eq 0) { throw 'Child emitted no result.' }
    Assert-ConfigurationBinding $Output $ExpectedConfiguration

    if ($Contract.Id -ceq 'runtime-instrumentation-pure-model') {
        $jsonLines = @($Output | Where-Object { $_ -match '^CHATPAD_RESULT_JSON=' })
        if ($jsonLines.Count -ne 1) { throw 'Pure-model machine result is missing or duplicated.' }
        try { $machine = $jsonLines[0].Substring('CHATPAD_RESULT_JSON='.Length) | ConvertFrom-Json }
        catch { throw 'Pure-model machine result is malformed.' }
        if ([string]$machine.suite_id -cne $Contract.Id -or
            [string]$machine.configuration -cne $ExpectedConfiguration -or
            [string]$machine.result -cne 'PASS') {
            throw 'Pure-model machine result identity, configuration, or result is invalid.'
        }
        $executed = [int]$machine.assertions.executed
        $passed = [int]$machine.assertions.passed
        $failed = [int]$machine.assertions.failed
        $zeroAuthorized = [bool]$machine.assertions.zero_authorized
    } else {
        $executed = Get-SingleRegexValue $Output $Contract.ExecutedPattern 'executed assertion count'
        $passed = Get-SingleRegexValue $Output $Contract.PassedPattern 'passed assertion count'
        $failed = Get-SingleRegexValue $Output $Contract.FailedPattern 'failed assertion count'
        $zeroAuthorized = $false
    }
    if ($executed -lt 0 -or $passed -lt 0 -or $failed -lt 0) {
        throw 'Assertion counts must be nonnegative.'
    }
    if ($executed -eq 0 -and -not $zeroAuthorized) {
        throw 'Assertion-bearing suite executed zero assertions without authorization.'
    }
    if ($executed -ne ($passed + $failed)) {
        throw 'Executed assertions do not equal passed plus failed.'
    }
    if ($failed -ne 0) { throw 'Assertion-bearing suite reported failed assertions.' }
    return [pscustomobject]@{
        executed = $executed
        passed = $passed
        failed = $failed
    }
}

function Convert-ValidationResult {
    param(
        [object]$Contract,
        [string[]]$Output,
        [int]$ExitCode,
        [string]$ExpectedConfiguration)

    if ($ExitCode -ne 0) { throw "Child exited nonzero: $ExitCode" }
    if ($Output.Count -eq 0) { throw 'Child emitted no result.' }
    Assert-ConfigurationBinding $Output $ExpectedConfiguration
    $successfulChecks = [System.Collections.Generic.List[string]]::new()
    foreach ($check in $Contract.RequiredChecks) {
        $matches = @($Output | Where-Object { $_ -match [string]$check.Pattern })
        if ($matches.Count -ne 1) {
            throw "Validation check $($check.Name) must appear exactly once; found $($matches.Count)."
        }
        $successfulChecks.Add([string]$check.Name)
    }

    $machineLines = @($Output | Where-Object { $_ -match '^CHATPAD_VALIDATION_JSON=' })
    if ($machineLines.Count -gt 1) { throw 'Validation machine result is duplicated.' }
    if ($machineLines.Count -eq 1) {
        try { $machine = $machineLines[0].Substring('CHATPAD_VALIDATION_JSON='.Length) | ConvertFrom-Json }
        catch { throw 'Validation machine result is malformed.' }
        if ([string]$machine.configuration -cne $ExpectedConfiguration -or
            [string]$machine.result -cne 'PASS' -or
            @($machine.failed_checks).Count -ne 0) {
            throw 'Validation machine result configuration or aggregate is contradictory.'
        }
    }
    if ($Contract.Id -ceq 'kmdf-request-owner-context') {
        $total = Get-SingleRegexValue $Output '^SemanticChecksTotal=(\d+)$' 'semantic check total'
        $passed = Get-SingleRegexValue $Output '^SemanticChecksPassed=(\d+)$' 'semantic checks passed'
        if ($total -le 0 -or $total -ne $passed) {
            throw 'KMDF semantic validation is empty or partial.'
        }
    }
    return @($successfulChecks)
}

function Get-AggregateStatus {
    param([object[]]$Entries, [int]$RequiredCount)
    if ($Entries.Count -ne $RequiredCount -or
        @($Entries | Where-Object result -cne 'PASS').Count -ne 0) {
        return 'FAIL'
    }
    return 'PASS'
}

$selfTestCount = 0
function Assert-ParserRejects {
    param([scriptblock]$Action, [string]$Description)
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (-not $rejected) { throw "Matrix negative fixture passed unexpectedly: $Description" }
    $script:selfTestCount += 1
}

$assertionFixture = $commands | Where-Object Id -ceq 'request-owner-model'
$validationFixture = $commands | Where-Object Id -ceq 'runtime-instrumentation'
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @() 0 $Configuration | Out-Null } 'exit zero with no result'
Assert-ParserRejects { Convert-ValidationResult $validationFixture @(
        "Configuration=$Configuration", 'CHATPAD_VALIDATION_JSON={bad-json',
        'MissingMappingCount=0', 'UnexplainedWppSiteCount=0', 'EmissionMapNegativeSelfTests=10') 0 $Configuration | Out-Null } 'malformed result data'
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @(
        "Configuration=$Configuration", 'Passed assertions: 1', 'Failed assertions: 0') 0 $Configuration | Out-Null } 'missing assertion count'
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @(
        "Configuration=$Configuration", 'Total assertions: 0', 'Passed assertions: 0', 'Failed assertions: 0') 0 $Configuration | Out-Null } 'unauthorized zero assertions'
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @(
        "Configuration=$Configuration", 'Total assertions: 3', 'Passed assertions: 1', 'Failed assertions: 1') 0 $Configuration | Out-Null } 'passed plus failed mismatch'
$contradictoryAggregate = @([pscustomobject]@{ result = 'FAIL' })
if ((Get-AggregateStatus $contradictoryAggregate 1) -cne 'FAIL') {
    throw 'Matrix aggregate accepted a child failure.'
}
$selfTestCount += 1
$wrongConfiguration = if ($Configuration -ceq 'Debug') { 'Release' } else { 'Debug' }
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @(
        "Configuration=$wrongConfiguration", 'Total assertions: 1', 'Passed assertions: 1', 'Failed assertions: 0') 0 $Configuration | Out-Null } 'wrong configuration'
Assert-ParserRejects { Convert-AssertionResult $assertionFixture @(
        "Configuration=$Configuration", "Artifact=C:\artifacts\x64\$wrongConfiguration\suite.exe",
        'Total assertions: 1', 'Passed assertions: 1', 'Failed assertions: 0') 0 $Configuration | Out-Null } 'copied or relabeled configuration result'
if ($selfTestCount -ne 8) { throw 'All eight matrix contract negative fixtures must execute.' }

$results = [System.Collections.Generic.List[object]]::new()
$transcript = [System.Collections.Generic.List[string]]::new()
$parseFailures = 0
$emptyResultFailures = 0
if (-not $SelfTestOnly) {
    foreach ($entry in $commands) {
        $scriptPath = Join-Path $repoRoot $entry.Script
        $commandText = '.\{0} {1}' -f $entry.Script, ($entry.Arguments -join ' ')
        $transcript.Add("===== $($entry.Id) =====")
        $transcript.Add("Command=$commandText")
        $output = @(& pwsh -NoProfile -File $scriptPath @($entry.Arguments) 2>&1 |
            ForEach-Object { $_.ToString() })
        $exitCode = $LASTEXITCODE
        foreach ($line in $output) { $transcript.Add($line) }
        $transcript.Add("ExitCode=$exitCode")

        $result = 'PASS'
        $parseError = $null
        $assertionResult = $null
        $successfulChecks = @()
        try {
            if ($entry.Kind -ceq 'assertion-bearing') {
                $assertionResult = Convert-AssertionResult $entry $output $exitCode $Configuration
            } else {
                $successfulChecks = @(Convert-ValidationResult $entry $output $exitCode $Configuration)
            }
        } catch {
            $result = 'FAIL'
            $parseError = $_.Exception.Message
            $parseFailures += 1
            if ($output.Count -eq 0) { $emptyResultFailures += 1 }
            $transcript.Add("ParseFailure=$parseError")
        }
        if ($exitCode -ne 0) { $result = 'FAIL' }

        $results.Add([pscustomobject][ordered]@{
            id = $entry.Id
            command = $commandText.Trim()
            configuration = $Configuration
            kind = $entry.Kind
            validation_type = $entry.ValidationType
            exit_code = $exitCode
            result = $result
            assertions_executed = $(if ($null -eq $assertionResult) { 0 } else { $assertionResult.executed })
            assertions_passed = $(if ($null -eq $assertionResult) { 0 } else { $assertionResult.passed })
            assertions_failed = $(if ($null -eq $assertionResult) { 0 } else { $assertionResult.failed })
            successful_checks = @($successfulChecks)
            parse_error = $parseError
        })
        if ($result -ne 'PASS') { break }
    }
}

$assertionEntries = @($results | Where-Object kind -ceq 'assertion-bearing')
$validationEntries = @($results | Where-Object kind -ceq 'non-assertion-validation')
$report = [ordered]@{
    schema_version = 'chatpad-runtime-instrumentation-regression-matrix-v2'
    configuration = $Configuration
    platform = $Platform
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    required_entry_count = $commands.Count
    executed_entry_count = $results.Count
    assertion_bearing_suite_count = @($commands | Where-Object Kind -ceq 'assertion-bearing').Count
    non_assertion_validation_count = @($commands | Where-Object Kind -ceq 'non-assertion-validation').Count
    executed_assertion_bearing_suite_count = $assertionEntries.Count
    executed_non_assertion_validation_count = $validationEntries.Count
    assertions_executed = $(if ($assertionEntries.Count -eq 0) { 0 } else { [int](($assertionEntries | Measure-Object assertions_executed -Sum).Sum) })
    assertions_passed = $(if ($assertionEntries.Count -eq 0) { 0 } else { [int](($assertionEntries | Measure-Object assertions_passed -Sum).Sum) })
    assertions_failed = $(if ($assertionEntries.Count -eq 0) { 0 } else { [int](($assertionEntries | Measure-Object assertions_failed -Sum).Sum) })
    entry_failures = @($results | Where-Object result -cne 'PASS').Count
    parse_failures = $parseFailures
    empty_result_failures = $emptyResultFailures
    synthetic_assertion_count = 0
    contract_negative_self_tests = $selfTestCount
    result = $(if ($SelfTestOnly) { 'PASS' } else { Get-AggregateStatus @($results) $commands.Count })
    entries = @($results)
}

$parent = Split-Path -Parent $fullOutputPath
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$jsonPath = [System.IO.Path]::ChangeExtension($fullOutputPath, '.json')
$transcript.Add('===== MATRIX SUMMARY =====')
foreach ($line in @(
        "Configuration=$Configuration",
        "ExecutedEntryCount=$($report.executed_entry_count)",
        "RequiredEntryCount=$($report.required_entry_count)",
        "AssertionBearingSuiteCount=$($report.assertion_bearing_suite_count)",
        "NonAssertionValidationCount=$($report.non_assertion_validation_count)",
        "AssertionsExecuted=$($report.assertions_executed)",
        "AssertionsPassed=$($report.assertions_passed)",
        "AssertionsFailed=$($report.assertions_failed)",
        "EntryFailures=$($report.entry_failures)",
        "ParseFailures=$($report.parse_failures)",
        "EmptyResultFailures=$($report.empty_result_failures)",
        "SyntheticAssertionCount=$($report.synthetic_assertion_count)",
        "ContractNegativeSelfTests=$($report.contract_negative_self_tests)",
        "Result=$($report.result)")) { $transcript.Add($line) }
[System.IO.File]::WriteAllLines($fullOutputPath, $transcript, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText(
    $jsonPath,
    ($report | ConvertTo-Json -Depth 10) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Configuration=$Configuration"
Write-Output "ExecutedEntryCount=$($report.executed_entry_count)"
Write-Output "RequiredEntryCount=$($report.required_entry_count)"
Write-Output "AssertionBearingSuiteCount=$($report.assertion_bearing_suite_count)"
Write-Output "NonAssertionValidationCount=$($report.non_assertion_validation_count)"
Write-Output "AssertionsExecuted=$($report.assertions_executed)"
Write-Output "AssertionsPassed=$($report.assertions_passed)"
Write-Output "AssertionsFailed=$($report.assertions_failed)"
Write-Output "EntryFailures=$($report.entry_failures)"
Write-Output "ParseFailures=$($report.parse_failures)"
Write-Output "EmptyResultFailures=$($report.empty_result_failures)"
Write-Output "SyntheticAssertionCount=$($report.synthetic_assertion_count)"
Write-Output "ContractNegativeSelfTests=$($report.contract_negative_self_tests)"
Write-Output "Transcript=$fullOutputPath"
Write-Output "Report=$jsonPath"
Write-Output "Result=$($report.result)"
if ($report.result -ne 'PASS') { exit 1 }
