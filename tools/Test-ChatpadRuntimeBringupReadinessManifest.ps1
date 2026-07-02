[CmdletBinding()]
param(
    [string]$ManifestPath = 'docs/evidence/runtime-bringup-readiness-manifest.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Repository root could not be resolved.' }
$root = [IO.Path]::GetFullPath($root)
$manifest = Get-Content -LiteralPath (Join-Path $root $ManifestPath) -Raw | ConvertFrom-Json
$entries = @($manifest.entries)

$defects = [ordered]@{
    missing = 0
    extra = 0
    duplicate_id = @($entries | Group-Object id | Where-Object Count -gt 1).Count
    duplicate_path = @($entries | Group-Object { ([string]$_.relative_path).Replace('\','/').ToLowerInvariant() } | Where-Object Count -gt 1).Count
    hash = 0
    size = 0
    state = 0
    containment = 0
    declared_result = 0
    planned_executed = 0
    synthetic_live = 0
    total_reconciliation = 0
    unsupported_pass = 0
}

$listedPaths = @($entries | ForEach-Object { ([string]$_.relative_path).Replace('\','/') })
$requiredTracked = @(& git diff HEAD --name-only) + @(
    'tools/New-ChatpadRuntimeBringupReadinessManifest.ps1',
    'tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1'
)
$requiredTracked = @($requiredTracked | ForEach-Object { $_.Replace('\','/') } | Where-Object { $_ -and $_ -ne $ManifestPath.Replace('\','/') } | Sort-Object -Unique)
foreach ($path in $requiredTracked) {
    if ($listedPaths -notcontains $path) { $defects.missing++ }
}
foreach ($entry in $entries) {
    $relative = ([string]$entry.relative_path).Replace('\','/')
    if ([string]$entry.state -eq 'tracked' -and
        $relative -ne 'docs/evidence/runtime-instrumentation-implementation-manifest.json' -and
        $requiredTracked -notcontains $relative) {
        $defects.extra++
    }
}
foreach ($entry in $entries) {
    $relative = ([string]$entry.relative_path).Replace('\','/')
    $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        $defects.containment++
        continue
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $defects.missing++
        continue
    }
    $item = Get-Item -LiteralPath $full
    if ([long]$entry.byte_size -ne [long]$item.Length) { $defects.size++ }
    if ([string]$entry.sha256 -cne (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash) { $defects.hash++ }
    $isTracked = $null -ne (& git ls-files --error-unmatch -- $relative 2>$null)
    if ($LASTEXITCODE -ne 0) { $isTracked = $false }
    & git check-ignore -q -- $relative
    $isIgnored = ($LASTEXITCODE -eq 0)
    if (([string]$entry.state -eq 'tracked' -and -not ($isTracked -or $requiredTracked -contains $relative)) -or
        ([string]$entry.state -eq 'ignored' -and -not $isIgnored) -or
        ([string]$entry.state -notin @('tracked','ignored'))) {
        $defects.state++
    }
    if ([string]$entry.evidence_classification -ne 'synthetic') { $defects.synthetic_live++ }
    if ([string]$entry.result -eq 'PASS' -and $relative -match 'prohibited-scan-20260702T094317Z') { $defects.declared_result++ }
}

if ([int]$manifest.readiness_results.synthetic_fixture_count -ne 177 -or
    [int]$manifest.readiness_results.synthetic_assertion_count -ne 203 -or
    [int]$manifest.readiness_results.command_injection_fixture_count -ne 21 -or
    [int]$manifest.readiness_results.stop_condition_count -ne 20) {
    $defects.total_reconciliation++
}
if ([string]$manifest.result -ne 'PASS_WITH_BLOCKER' -or
    [string]$manifest.readiness_results.exact_instance_binding_status -ne 'BLOCKED_NOT_IMPLEMENTED') {
    $defects.unsupported_pass++
}
if (@($entries | Where-Object state -eq 'tracked-pending').Count -ne 0) { $defects.state++ }

$total = ($defects.Values | Measure-Object -Sum).Sum
[pscustomobject][ordered]@{
    schema_version = 'chatpad-runtime-bringup-readiness-manifest-validation-v1'
    result = $(if ($total -eq 0) { 'PASS' } else { 'FAIL' })
    manifest_schema = $manifest.schema_version
    entry_count = $entries.Count
    defects = [pscustomobject]$defects
    total_defects = $total
} | ConvertTo-Json -Depth 6

if ($total -ne 0) { exit 1 }
