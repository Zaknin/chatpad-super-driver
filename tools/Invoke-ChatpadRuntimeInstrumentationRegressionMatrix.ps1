[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration,

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter(Mandatory)]
    [string]$OutputPath
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

$commands = @(
    @{ Id = 'request-owner-model'; Script = 'tools\Test-ChatpadRequestOwnerModel.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'protocol'; Script = 'tools\Test-ChatpadProtocol.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'transport'; Script = 'tools\Test-ChatpadTransport.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'lifecycle'; Script = 'tools\Test-ChatpadFilterLifecycle.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'control-setup'; Script = 'tools\Test-ChatpadControlSetup.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'protocol-kernel-compatibility'; Script = 'tools\Test-ChatpadProtocolKernelCompatibility.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'wdf-control-setup'; Script = 'tools\Test-ChatpadWdfControlSetup.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'production-linkage'; Script = 'tools\Test-ChatpadProductionLinkage.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'production-owner-initialization-full'; Script = 'tools\Test-ChatpadProductionOwnerInitialization.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform, '-InspectionMode', 'Full') },
    @{ Id = 'kmdf-request-owner-context'; Script = 'tools\Test-ChatpadKmdfRequestOwnerContext.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'production-orchestration-full'; Script = 'tools\Test-ChatpadProductionOrchestrationInvocation.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform, '-InspectionMode', 'Full') },
    @{ Id = 'runtime-instrumentation'; Script = 'tools\Test-ChatpadRuntimeInstrumentation.ps1'; Arguments = @('-Configuration', $Configuration, '-Platform', $Platform) },
    @{ Id = 'runtime-instrumentation-pure-model'; Script = 'tests\offline\RuntimeInstrumentationModel\Test-RuntimeInstrumentationModel.ps1'; Arguments = @() }
)

$results = [System.Collections.Generic.List[object]]::new()
$transcript = [System.Collections.Generic.List[string]]::new()
foreach ($entry in $commands) {
    $scriptPath = Join-Path $repoRoot $entry.Script
    $commandText = '.\{0} {1}' -f
        $entry.Script.Replace('\', '/'),
        ($entry.Arguments -join ' ')
    $transcript.Add("===== $($entry.Id) =====")
    $transcript.Add("Command=$commandText")
    $output = @(& pwsh -NoProfile -File $scriptPath @($entry.Arguments) 2>&1 |
        ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) { $transcript.Add($line) }
    $transcript.Add("ExitCode=$exitCode")

    $passedValues = @(
        foreach ($line in $output) {
            foreach ($pattern in @(
                    '(?:AssertionsPassed|PassedAssertions|SemanticChecksPassed|AssertionCount)\s*[=:]\s*(\d+)',
                    '(?:Tests passed)\s*:\s*(\d+)')) {
                $match = [regex]::Match($line, $pattern)
                if ($match.Success) { [int]$match.Groups[1].Value }
            }
        })
    $totalValues = @(
        foreach ($line in $output) {
            foreach ($pattern in @(
                    '(?:AssertionsTotal|TotalAssertions|SemanticChecksTotal)\s*[=:]\s*(\d+)',
                    '(?:Tests total)\s*:\s*(\d+)')) {
                $match = [regex]::Match($line, $pattern)
                if ($match.Success) { [int]$match.Groups[1].Value }
            }
        })
    $passedAssertions = if ($passedValues.Count -eq 0) { 1 } else { ($passedValues | Measure-Object -Maximum).Maximum }
    $totalAssertions = if ($totalValues.Count -eq 0) { $passedAssertions } else { ($totalValues | Measure-Object -Maximum).Maximum }
    $warningCount = @($output | Where-Object { $_ -match '(?i)\bwarning(?:s)?\b' -and $_ -notmatch '(?i)warnings\s*[=:]\s*0' }).Count
    $errorCount = @($output | Where-Object { $_ -match '(?i)\berror(?:s)?\b' -and $_ -notmatch '(?i)errors\s*[=:]\s*0' }).Count
    $result = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    $results.Add([pscustomobject]@{
        id = $entry.Id
        command = $commandText.Trim()
        configuration = $Configuration
        exit_code = $exitCode
        result = $result
        passed_assertions = [int]$passedAssertions
        total_assertions = [int]$totalAssertions
        warnings = $warningCount
        errors = $errorCount
    })
    if ($exitCode -ne 0) {
        break
    }
}

$report = [ordered]@{
    schema_version = 'chatpad-runtime-instrumentation-regression-matrix-v1'
    configuration = $Configuration
    platform = $Platform
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    required_entry_count = $commands.Count
    executed_entry_count = $results.Count
    result = if ($results.Count -eq $commands.Count -and @($results | Where-Object result -ne 'PASS').Count -eq 0) { 'PASS' } else { 'FAIL' }
    passed_assertions = [int](($results | Measure-Object passed_assertions -Sum).Sum)
    total_assertions = [int](($results | Measure-Object total_assertions -Sum).Sum)
    warnings = [int](($results | Measure-Object warnings -Sum).Sum)
    errors = [int](($results | Measure-Object errors -Sum).Sum)
    entries = @($results)
}

$parent = Split-Path -Parent $fullOutputPath
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$jsonPath = [System.IO.Path]::ChangeExtension($fullOutputPath, '.json')
$transcript.Add('===== MATRIX SUMMARY =====')
$transcript.Add("Configuration=$Configuration")
$transcript.Add("ExecutedEntryCount=$($report.executed_entry_count)")
$transcript.Add("RequiredEntryCount=$($report.required_entry_count)")
$transcript.Add("PassedAssertions=$($report.passed_assertions)")
$transcript.Add("TotalAssertions=$($report.total_assertions)")
$transcript.Add("Warnings=$($report.warnings)")
$transcript.Add("Errors=$($report.errors)")
$transcript.Add("Result=$($report.result)")
[System.IO.File]::WriteAllLines($fullOutputPath, $transcript, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText(
    $jsonPath,
    ($report | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Configuration=$Configuration"
Write-Output "ExecutedEntryCount=$($report.executed_entry_count)"
Write-Output "RequiredEntryCount=$($report.required_entry_count)"
Write-Output "PassedAssertions=$($report.passed_assertions)"
Write-Output "TotalAssertions=$($report.total_assertions)"
Write-Output "Warnings=$($report.warnings)"
Write-Output "Errors=$($report.errors)"
Write-Output "Transcript=$fullOutputPath"
Write-Output "Report=$jsonPath"
Write-Output "Result=$($report.result)"
if ($report.result -ne 'PASS') { exit 1 }
