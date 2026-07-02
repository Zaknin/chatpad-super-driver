[CmdletBinding()]
param([string]$ManifestPath='docs/evidence/runtime-bringup-readiness-manifest.json')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
$manifest=Get-Content -LiteralPath (Join-Path $root $ManifestPath) -Raw|ConvertFrom-Json
$entries=@($manifest.entries)
$defects=[ordered]@{missing=0;duplicate_id=@($entries|Group-Object id|Where-Object Count -gt 1).Count;duplicate_path=@($entries|Group-Object relative_path|Where-Object Count -gt 1).Count;hash=0;size=0;state=0;containment=0;declared_result=0;top_level=0;fixture_totals=0;psscriptanalyzer=0;identity=0;unsupported_pass=0}
foreach($entry in $entries){
    $full=[IO.Path]::GetFullPath((Join-Path $root ([string]$entry.relative_path)))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$defects.containment++;continue}
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$defects.missing++;continue}
    $item=Get-Item $full;if([long]$entry.byte_size-ne$item.Length){$defects.size++};if([string]$entry.sha256-cne(Get-FileHash $full -Algorithm SHA256).Hash){$defects.hash++}
    if($entry.state-notin@('tracked','ignored')){$defects.state++}
    if($entry.evidence_classification-ne'synthetic'){$defects.declared_result++}
}
if($manifest.schema_version-ne'chatpad-runtime-bringup-readiness-manifest-v3'-or$manifest.framework_status-ne'PASS'-or$manifest.live_installation_readiness-ne'BLOCKED'-or$manifest.blocker-ne'BLOCKED_NOT_IMPLEMENTED'){$defects.top_level++}
if([int]$manifest.readiness.fixture_count-le0-or[int]$manifest.readiness.assertion_count-le0-or@($manifest.readiness.category_totals).Count-le0){$defects.fixture_totals++}
if($manifest.readiness.psscriptanalyzer_status-notin@('SKIPPED_UNAVAILABLE','PASS')){$defects.psscriptanalyzer++}
if($manifest.readiness.psscriptanalyzer_status-eq'PASS'-and$null-eq(Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)){$defects.psscriptanalyzer++}
foreach($name in @('frozen_baseline_commit','prior_readiness_implementation_commit','prior_readiness_finalization_commit','current_readiness_implementation_commit')){if([string]$manifest.repository.$name-notmatch'^[0-9a-f]{40}$'){$defects.identity++}}
if([int]$manifest.readiness.exact_instance_binding_operations-or[int]$manifest.readiness.exact_instance_restoration_operations-or[int]$manifest.readiness.broad_approved_install_operations-or[int]$manifest.readiness.broad_approved_rollback_operations){$defects.unsupported_pass++}
$total=($defects.Values|Measure-Object -Sum).Sum
[pscustomobject][ordered]@{schema_version='chatpad-runtime-bringup-readiness-manifest-validation-v2';result=$(if($total){'FAIL'}else{'PASS'});manifest_schema=$manifest.schema_version;entry_count=$entries.Count;defects=[pscustomobject]$defects;total_defects=$total}|ConvertTo-Json -Depth 8
if($total){exit 1}
