[CmdletBinding()]
param(
    [string]$ManifestPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [switch]$RunCorruptionRegression
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-ChatpadIntegerPropertySum {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][ref]$DefectCount
    )
    $sum = 0
    foreach ($item in @($Items)) {
        if ($null -eq $item -or $item -is [array] -or $null -eq $item.PSObject.Properties[$PropertyName]) {
            $DefectCount.Value++
            continue
        }
        $value = $item.PSObject.Properties[$PropertyName].Value
        if ($null -eq $value -or $value -is [array] -or $value -is [bool]) {
            $DefectCount.Value++
            continue
        }
        try {
            $number = [int]$value
            if ($number -lt 0) { throw 'negative' }
            $sum += $number
        } catch {
            $DefectCount.Value++
        }
    }
    return $sum
}

function Write-ChatpadUtf8NoBomJson {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][object]$Value)
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 30)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}

function Invoke-ChatpadManifestCorruptionRegression {
    param([Parameter(Mandatory)][string]$ManifestPath)

    $repoRoot=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
    $sourceManifestPath=[IO.Path]::GetFullPath((Join-Path $repoRoot $ManifestPath))
    $sourceManifest=Get-Content -LiteralPath $sourceManifestPath -Raw|ConvertFrom-Json
    $suiteEntry=@($sourceManifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
    if($suiteEntry.Count-ne1){throw 'Cannot locate exactly one evidence-synthetic-suite manifest entry.'}
    $sourceSuiteRelative=[string]$suiteEntry[0].relative_path
    $sourceSuitePath=[IO.Path]::GetFullPath((Join-Path $repoRoot $sourceSuiteRelative))
    $validatorRelative='tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1'
    $copyPaths=@($validatorRelative,$ManifestPath)+@($sourceManifest.entries|ForEach-Object{[string]$_.relative_path})
    $tempRoot=Join-Path ([IO.Path]::GetTempPath()) ('chatpad-manifest-regression-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        Push-Location $tempRoot
        try { git init -q | Out-Null } finally { Pop-Location }
        foreach($relative in @($copyPaths|Sort-Object -Unique)){
            $source=[IO.Path]::GetFullPath((Join-Path $repoRoot $relative))
            $target=[IO.Path]::GetFullPath((Join-Path $tempRoot $relative))
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
        }
        $tempManifestPath=Join-Path $tempRoot $ManifestPath
        $tempSuitePath=Join-Path $tempRoot $sourceSuiteRelative
        $baselineManifestText=Get-Content -LiteralPath $tempManifestPath -Raw
        $baselineSuiteText=Get-Content -LiteralPath $tempSuitePath -Raw
        $cases=@(
            [pscustomobject]@{
                id='all-harness-records-omitted'
                category='harness-self-test'
                keep={param($record) [string]$record.category -ne 'harness-self-test'}
                expected_count=0
            },
            [pscustomobject]@{
                id='one-harness-record-omitted'
                category='harness-self-test'
                keep={
                    param($record)
                    if([string]$record.category -ne 'harness-self-test'){return $true}
                    if(-not $script:SkippedOneHarnessRecord){$script:SkippedOneHarnessRecord=$true;return $false}
                    return $true
                }
                expected_count=5
            },
            [pscustomobject]@{
                id='all-accounting-negative-records-omitted'
                category='assertion-accounting-negative'
                keep={param($record) [string]$record.category -ne 'assertion-accounting-negative'}
                expected_count=0
            }
        )
        $results=[Collections.Generic.List[object]]::new()
        foreach($case in $cases){
            [IO.File]::WriteAllText($tempManifestPath,$baselineManifestText,[Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($tempSuitePath,$baselineSuiteText,[Text.UTF8Encoding]::new($false))
            $manifest=Get-Content -LiteralPath $tempManifestPath -Raw|ConvertFrom-Json
            $suite=Get-Content -LiteralPath $tempSuitePath -Raw|ConvertFrom-Json
            $script:SkippedOneHarnessRecord=$false
            $suite.fixtures=@(foreach($fixture in @($suite.fixtures)){if(& $case.keep $fixture){$fixture}})
            Write-ChatpadUtf8NoBomJson $tempSuitePath $suite
            $changedSuite=Get-Item -LiteralPath $tempSuitePath
            $changedSuiteHash=(Get-FileHash -LiteralPath $tempSuitePath -Algorithm SHA256).Hash
            $entry=@($manifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
            $entry[0].byte_size=[long]$changedSuite.Length
            $entry[0].sha256=$changedSuiteHash
            Write-ChatpadUtf8NoBomJson $tempManifestPath $manifest
            Push-Location $tempRoot
            try {
                $previousErrorActionPreference=$ErrorActionPreference
                $ErrorActionPreference='Continue'
                $outputLines=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $validatorRelative 2>&1)
                $exitCode=$LASTEXITCODE
            } finally {
                $ErrorActionPreference=$previousErrorActionPreference
                Pop-Location
            }
            $outputText=($outputLines|Out-String)
            $parsed=$null
            try { $parsed=$outputText|ConvertFrom-Json } catch { $parsed=$null }
            $propertyNotFound=[bool]($outputText -match 'PropertyNotFound')
            $actualCount=0
            $actualAssertions=0
            $expectedRecordCount=$null
            $expectedAssertionCount=$null
            $accountingDefects=$null
            if($null-ne$parsed){
                $details=$parsed.accounting_details
                if($case.id -like '*harness*'){
                    $actualCount=[int]$details.actual_harness_result_record_count
                    $actualAssertions=[int]$details.actual_harness_assertion_sum
                    $expectedRecordCount=[int]$details.expected_harness_result_record_count
                    $expectedAssertionCount=[int]$details.expected_harness_assertion_sum
                } else {
                    $actualCount=@($suite.fixtures|Where-Object category -eq $case.category).Count
                    $subsetDefects=0
                    $actualAssertions=Get-ChatpadIntegerPropertySum -Items ([object[]]@($suite.fixtures|Where-Object category -eq $case.category)) -PropertyName assertion_count -DefectCount ([ref]$subsetDefects)
                    $expectedRecordCount=18
                    $expectedAssertionCount=108
                }
                $accountingDefects=[int]$parsed.defects.accounting
            }
            $results.Add([pscustomobject][ordered]@{
                case=$case.id
                process_exit_code=$exitCode
                validator_result=if($null-ne$parsed){$parsed.result}else{'UNPARSED'}
                accounting_defect_count=$accountingDefects
                expected_record_count=$expectedRecordCount
                actual_record_count=$actualCount
                expected_assertion_count=$expectedAssertionCount
                actual_assertion_count=$actualAssertions
                uncontrolled_exception_count=if($null-ne$parsed -and -not $propertyNotFound){0}else{1}
                property_not_found=$propertyNotFound
                output_parsed=[bool]($null-ne$parsed)
            })
        }
        $failed=@($results|Where-Object{
            $_.process_exit_code -eq 0 -or
            $_.validator_result -ne 'FAIL' -or
            $_.accounting_defect_count -lt 1 -or
            $_.uncontrolled_exception_count -ne 0 -or
            $_.property_not_found
        })
        [pscustomobject][ordered]@{
            schema_version='chatpad-runtime-bringup-manifest-corruption-regression-v1'
            result=if($failed.Count){'FAIL'}else{'PASS'}
            case_count=$results.Count
            failed_case_count=$failed.Count
            cases=@($results)
        }
    } finally {
        if(Test-Path -LiteralPath $tempRoot){Remove-Item -LiteralPath $tempRoot -Recurse -Force}
    }
}

if($RunCorruptionRegression){
    $regression=Invoke-ChatpadManifestCorruptionRegression -ManifestPath $ManifestPath
    $regression|ConvertTo-Json -Depth 8
    if($regression.result-ne'PASS'){exit 1}
    exit 0
}

$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
$manifest=Get-Content -LiteralPath (Join-Path $root $ManifestPath) -Raw|ConvertFrom-Json
$entries=@($manifest.entries)
$defects=[ordered]@{missing=0;duplicate_id=@($entries|Group-Object id|Where-Object Count -gt 1).Count;duplicate_path=@($entries|Group-Object relative_path|Where-Object Count -gt 1).Count;hash=0;size=0;state=0;containment=0;declared_result=0;top_level=0;fixture_totals=0;accounting=0;observer_provenance=0;evidence_binding=0;psscriptanalyzer=0;identity=0;unsupported_pass=0;powershell_inventory=0;sample_validation=0;lifecycle=0;malformed_totality=0;stop_linkage=0}
$accountingDetails=[ordered]@{}
foreach($entry in $entries){
    $full=[IO.Path]::GetFullPath((Join-Path $root ([string]$entry.relative_path)))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$defects.containment++;continue}
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$defects.missing++;continue}
    $item=Get-Item $full;if([long]$entry.byte_size-ne$item.Length){$defects.size++};if([string]$entry.sha256-cne(Get-FileHash $full -Algorithm SHA256).Hash){$defects.hash++}
    if($entry.state-notin@('tracked','ignored')){$defects.state++}
    if($entry.evidence_classification-ne'synthetic'){$defects.declared_result++}
}
if($manifest.schema_version-ne'chatpad-runtime-bringup-readiness-manifest-v3'-or$manifest.framework_status-ne'PASS'-or$manifest.live_installation_readiness-ne'BLOCKED'-or$manifest.blocker-ne'BLOCKED_NOT_IMPLEMENTED'){$defects.top_level++}
$suiteEntry=@($entries|Where-Object id -eq 'evidence-synthetic-suite')
if($suiteEntry.Count-ne1){$defects.evidence_binding++}
else{
    $suitePath=[IO.Path]::GetFullPath((Join-Path $root ([string]$suiteEntry[0].relative_path)))
    try{$suite=Get-Content -LiteralPath $suitePath -Raw|ConvertFrom-Json}catch{$suite=$null;$defects.evidence_binding++}
    if($null-ne$suite){
        $records=@($suite.fixtures)
        $recordIds=@($records|ForEach-Object{[string]$_.fixture_id})
        $recordAssertionSum=0
        $recordDefects=0
        foreach($record in $records){
            if([string]::IsNullOrWhiteSpace([string]$record.fixture_id)-or[string]::IsNullOrWhiteSpace([string]$record.category)-or$record.category-is[array]){$recordDefects++;continue}
            try{$assertions=[int]$record.assertion_count;if($assertions-lt0-or($record.fixture_result-eq'PASS'-and$assertions-eq0)){$recordDefects++}else{$recordAssertionSum+=$assertions}}catch{$recordDefects++}
        }
        if(@($recordIds|Group-Object|Where-Object Count -gt 1).Count){$recordDefects++}
        $categoryDefects=0
        $derivedCategories=@($records|Group-Object category|Sort-Object Name|ForEach-Object{[pscustomobject]@{category=$_.Name;record_count=$_.Count;assertion_count=(Get-ChatpadIntegerPropertySum -Items ([object[]]$_.Group) -PropertyName assertion_count -DefectCount ([ref]$categoryDefects))}})
        $suiteCategories=@($suite.category_totals)
        foreach($expected in $derivedCategories){
            $actual=@($suiteCategories|Where-Object category -eq $expected.category)
            if($actual.Count-ne1-or[int]$actual[0].record_count-ne$expected.record_count-or[int]$actual[0].assertion_count-ne$expected.assertion_count){$categoryDefects++}
        }
        foreach($actual in $suiteCategories){if(@($derivedCategories|Where-Object category -eq $actual.category).Count-ne1){$categoryDefects++}}
        $categoryRecordSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$suiteCategories) -PropertyName record_count -DefectCount ([ref]$categoryDefects)
        $categoryAssertionSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$suiteCategories) -PropertyName assertion_count -DefectCount ([ref]$categoryDefects)
        $harness=@($records|Where-Object category -eq 'harness-self-test')
        $harnessAssertionSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$harness) -PropertyName assertion_count -DefectCount ([ref]$recordDefects)
        $accountingDetails=[ordered]@{
            expected_harness_result_record_count=[int]$suite.harness_result_record_count
            actual_harness_result_record_count=$harness.Count
            expected_harness_assertion_sum=[int]$suite.harness_assertion_sum
            actual_harness_assertion_sum=$harnessAssertionSum
            expected_total_result_record_count=[int]$suite.total_result_record_count
            actual_total_result_record_count=$records.Count
            expected_assertion_count=[int]$suite.assertion_count
            actual_record_assertion_sum=$recordAssertionSum
            expected_category_record_sum=[int]$suite.category_record_sum
            actual_category_record_sum=$categoryRecordSum
            expected_category_assertion_sum=[int]$suite.category_assertion_sum
            actual_category_assertion_sum=$categoryAssertionSum
            record_defect_count=$recordDefects
            category_defect_count=$categoryDefects
        }
        if($recordDefects-or$categoryDefects-or
            [int]$suite.fixture_count-ne$records.Count-or
            [int]$suite.total_result_record_count-ne$records.Count-or
            [int]$suite.fixture_assertion_sum-ne$recordAssertionSum-or
            [int]$suite.record_assertion_sum-ne$recordAssertionSum-or
            [int]$suite.assertion_count-ne$recordAssertionSum-or
            [int]$suite.category_record_sum-ne$categoryRecordSum-or
            [int]$suite.category_assertion_sum-ne$categoryAssertionSum-or
            $categoryRecordSum-ne$records.Count-or$categoryAssertionSum-ne$recordAssertionSum-or
            [int]$suite.harness_result_record_count-ne$harness.Count-or[int]$suite.harness_assertion_sum-ne$harnessAssertionSum-or
            [string]$suite.assertion_accounting_result-ne'PASS'-or
            [int]$suite.unassigned_assertion_count-or[int]$suite.off_ledger_assertion_count-or[int]$suite.duplicate_counted_assertion_count-or[int]$suite.category_reconciliation_defect_count){$defects.accounting++}
        if([int]$manifest.readiness.fixture_count-ne$records.Count-or
            [int]$manifest.readiness.total_result_record_count-ne$records.Count-or
            [int]$manifest.readiness.assertion_count-ne$recordAssertionSum-or
            [int]$manifest.readiness.fixture_assertion_sum-ne$recordAssertionSum-or
            [int]$manifest.readiness.record_assertion_sum-ne$recordAssertionSum-or
            [int]$manifest.readiness.category_record_sum-ne$categoryRecordSum-or
            [int]$manifest.readiness.category_assertion_sum-ne$categoryAssertionSum){$defects.fixture_totals++}
        if([string]$suite.observer_provenance_contract_result-ne'PASS'-or
            [int]$suite.missing_provenance_probe_count-ne5-or[int]$suite.missing_provenance_pass_count-ne0-or
            [int]$suite.synthetic_source_probe_count-ne5-or[int]$suite.synthetic_runtime_observer_pass_count-ne0-or
            [int]$suite.unsupported_runtime_observer_pass_count-ne0-or[int]$suite.runtime_observations_evaluated_live-ne0-or
            [string]$manifest.readiness.observer_provenance_contract_result-ne'PASS'-or
            [int]$manifest.readiness.missing_provenance_probe_count-ne5-or[int]$manifest.readiness.missing_provenance_pass_count-ne0-or
            [int]$manifest.readiness.synthetic_source_probe_count-ne5-or[int]$manifest.readiness.synthetic_runtime_observer_pass_count-ne0-or
            [int]$manifest.readiness.unsupported_runtime_observer_pass_count-ne0-or[int]$manifest.readiness.runtime_observations_evaluated_live-ne0){$defects.observer_provenance++}
    }
}
if([int]$manifest.readiness.fixture_count-le0-or[int]$manifest.readiness.assertion_count-le0-or@($manifest.readiness.category_totals).Count-le0){$defects.fixture_totals++}
if($manifest.readiness.psscriptanalyzer_status-notin@('SKIPPED_UNAVAILABLE','PASS')){$defects.psscriptanalyzer++}
if($manifest.readiness.psscriptanalyzer_status-eq'PASS'-and$null-eq(Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)){$defects.psscriptanalyzer++}
foreach($name in @('frozen_baseline_commit','prior_readiness_implementation_commit','prior_readiness_finalization_commit','current_readiness_implementation_commit')){if([string]$manifest.repository.$name-notmatch'^[0-9a-f]{40}$'){$defects.identity++}}
if([int]$manifest.readiness.exact_instance_binding_operations-or[int]$manifest.readiness.exact_instance_restoration_operations-or[int]$manifest.readiness.broad_approved_install_operations-or[int]$manifest.readiness.broad_approved_rollback_operations){$defects.unsupported_pass++}
if([string]$manifest.readiness.assertion_accounting_result-ne'PASS'-or[int]$manifest.readiness.unassigned_assertion_count-or[int]$manifest.readiness.off_ledger_assertion_count-or[int]$manifest.readiness.duplicate_counted_assertion_count-or[int]$manifest.readiness.category_reconciliation_defect_count){$defects.accounting++}
if([int]$manifest.readiness.invalid_lifecycle_acceptance_count -ne 0 -or [int]$manifest.readiness.missing_start_timestamp_acceptance_count -ne 0){$defects.lifecycle++}
if([int]$manifest.readiness.stop_condition_count -ne 20 -or [int]$manifest.readiness.unique_stop_condition_count -ne 20 -or [int]$manifest.readiness.runtime_observer_linkage_count -ne 5 -or [int]$manifest.readiness.unlinked_stop_condition_count -ne 0 -or [int]$manifest.readiness.unknown_stop_condition_id_count -ne 0 -or [int]$manifest.readiness.malformed_linkage_count -ne 0 -or [int]$manifest.readiness.nested_array_acceptance_count -ne 0){$defects.stop_linkage++}
if([int]$manifest.readiness.malformed_input_validator_count -ne 15 -or [int]$manifest.readiness.malformed_input_case_count -ne 180 -or [int]$manifest.readiness.uncontrolled_exception_count -ne 0 -or [int]$manifest.readiness.property_not_found_exception_count -ne 0 -or [int]$manifest.readiness.strictmode_exception_count -ne 0){$defects.malformed_totality++}
if([string]$manifest.readiness.committed_sample_structural_validation -ne 'PASS' -or [string]$manifest.readiness.committed_sample_semantic_validation -ne 'PASS'){$defects.sample_validation++}
$inventory=$manifest.readiness.powershell_inventory
if([int]$inventory.tracked_ps1_count -ne 41 -or [int]$inventory.tracked_psm1_count -ne 2 -or [int]$inventory.tracked_powershell_count -ne 43 -or [int]$inventory.parsed_ps1_count -ne 41 -or [int]$inventory.parsed_psm1_count -ne 2 -or [int]$inventory.parsed_powershell_count -ne 43 -or [int]$inventory.parse_error_count -ne 0 -or [int]$inventory.duplicate_normalized_path_count -ne 0 -or [int]$inventory.missing_count -ne 0 -or [int]$inventory.extra_count -ne 0){$defects.powershell_inventory++}
$total=($defects.Values|Measure-Object -Sum).Sum
[pscustomobject][ordered]@{schema_version='chatpad-runtime-bringup-readiness-manifest-validation-v2';result=$(if($total){'FAIL'}else{'PASS'});manifest_schema=$manifest.schema_version;entry_count=$entries.Count;defects=[pscustomobject]$defects;total_defects=$total;accounting_details=[pscustomobject]$accountingDetails}|ConvertTo-Json -Depth 8
if($total){exit 1}
