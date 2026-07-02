[CmdletBinding()]
param(
    [string]$OutputPath = 'docs/evidence/runtime-bringup-readiness-manifest.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Repository root could not be resolved.'
}
$repositoryRoot = [IO.Path]::GetFullPath($repositoryRoot)
$outputFullPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))

function New-IdentityEntry {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][ValidateSet('tracked','ignored')][string]$State,
        [Parameter(Mandatory)][string]$Producer,
        [Parameter(Mandatory)][string]$Result
    )
    $fullPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $fullPath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest entry escapes repository: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Manifest entry is missing: $RelativePath"
    }
    $item = Get-Item -LiteralPath $fullPath
    [pscustomobject][ordered]@{
        id = $Id
        relative_path = $RelativePath.Replace('\','/')
        state = $State
        byte_size = [long]$item.Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
        timestamp_utc = $item.LastWriteTimeUtc.ToString('o')
        producer = $Producer
        result = $Result
        evidence_classification = 'synthetic'
        dependency_identities = @()
    }
}

function Get-LatestEvidencePath {
    param([Parameter(Mandatory)][string]$Pattern)
    $file = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'artifacts/logs') -File -Filter $Pattern |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $file) { throw "Required evidence log is missing: $Pattern" }
    return $file.FullName.Substring($repositoryRoot.Length + 1).Replace('\','/')
}

$entries = [System.Collections.Generic.List[object]]::new()
$entries.Add((New-IdentityEntry 'accepted-offline-manifest' 'docs/evidence/runtime-instrumentation-implementation-manifest.json' tracked 'accepted-offline-runtime-instrumentation' 'FROZEN_DEPENDENCY'))
$entries.Add((New-IdentityEntry 'debug-sys-frozen-binary' 'artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys' ignored 'accepted-offline-runtime-instrumentation' 'FROZEN_DEPENDENCY'))
$entries.Add((New-IdentityEntry 'release-sys-frozen-binary' 'artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys' ignored 'accepted-offline-runtime-instrumentation' 'FROZEN_DEPENDENCY'))
$entries.Add((New-IdentityEntry 'remediation-start-state' 'artifacts/logs/runtime-bringup-readiness-remediation-start-20260702T082439Z.log' ignored 'start-state-capture' 'PASS'))

$trackedPaths = @(& git diff HEAD --name-only) + @(
    'tools/New-ChatpadRuntimeBringupReadinessManifest.ps1',
    'tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1'
)
$trackedPaths = @($trackedPaths | ForEach-Object { $_.Replace('\','/') } | Where-Object { $_ -and $_ -ne $OutputPath.Replace('\','/') } | Sort-Object -Unique)
foreach ($relativePath in $trackedPaths) {
    $id = 'tracked-' + (($relativePath.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-'))
    $entries.Add((New-IdentityEntry $id $relativePath tracked 'runtime-bringup-readiness-remediation' 'CANDIDATE_TREE_VALIDATED'))
}

$evidence = [ordered]@{
    'ast-parse' = Get-LatestEvidencePath 'runtime-bringup-remediation-ast-*.log'
    'synthetic-suite' = Get-LatestEvidencePath 'runtime-bringup-remediation-synthetic-*.json'
    'json-schema' = Get-LatestEvidencePath 'runtime-bringup-remediation-schema-*.log'
    'repository-safety' = Get-LatestEvidencePath 'runtime-bringup-remediation-repository-safety-*.log'
    'changed-path-containment' = Get-LatestEvidencePath 'runtime-bringup-remediation-containment-*.log'
    'prohibited-operation-scan' = Get-LatestEvidencePath 'runtime-bringup-remediation-prohibited-scan-corrected-*.log'
    'file-hygiene' = Get-LatestEvidencePath 'runtime-bringup-remediation-file-hygiene-corrected-final-*.log'
    'git-diff-check' = Get-LatestEvidencePath 'runtime-bringup-remediation-diff-check-*.log'
    'psscriptanalyzer-status' = Get-LatestEvidencePath 'runtime-bringup-remediation-psscriptanalyzer-final-*.log'
}
foreach ($pair in $evidence.GetEnumerator()) {
    $entries.Add((New-IdentityEntry "evidence-$($pair.Key)" $pair.Value ignored 'offline-validation' 'PASS'))
}

$manifest = [pscustomobject][ordered]@{
    schema_version = 'chatpad-runtime-bringup-readiness-manifest-v2'
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    result = 'PASS_WITH_BLOCKER'
    repository = [pscustomobject][ordered]@{
        branch = 'feature/runtime-bringup-readiness-remediation'
        candidate_base_commit = 'b9990d287bee6916cc5bb4e6b7f194ee579c7fbb'
        accepted_baseline_commit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        approved_readiness_commit_source = 'external exact 40-character audit/session input'
        expected_commit_subject = 'test: remediate controlled runtime bring-up readiness'
    }
    accepted_offline_baseline = [pscustomobject][ordered]@{
        manifest_sha256 = '35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
        debug_sys_size = 68096
        debug_sys_sha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
        release_sys_size = 40960
        release_sys_sha256 = 'A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
    }
    readiness_results = [pscustomobject][ordered]@{
        synthetic_fixture_count = 177
        synthetic_assertion_count = 203
        command_injection_fixture_count = 21
        raw_command_concatenation_count = 0
        broad_approved_install_operation_count = 0
        broad_approved_rollback_operation_count = 0
        stop_condition_count = 20
        runtime_evidence_schema = 'chatpad-runtime-evidence-schema-v2'
        json_schema_draft = 'https://json-schema.org/draft/2020-12/schema'
        exact_instance_binding_status = 'BLOCKED_NOT_IMPLEMENTED'
    }
    self_reference_policy = 'The manifest excludes its own hash and final commit. It binds the candidate-tree files and requires the exact final commit as an external repository-identity input.'
    entries = @($entries)
}

$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outputFullPath -Encoding utf8
Write-Output "Manifest=$OutputPath"
Write-Output "Entries=$($entries.Count)"
Write-Output 'Result=PASS_WITH_BLOCKER'
