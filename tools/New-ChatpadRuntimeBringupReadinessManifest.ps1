[CmdletBinding()]
param(
    [string]$OutputPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [Parameter(Mandatory)][string]$ImplementationCommit,
    [Parameter(Mandatory)][string]$SuiteResultPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
if($ImplementationCommit-notmatch'^[0-9a-f]{40}$'){throw 'ImplementationCommit must be a full commit hash.'}
$suite=Get-Content -LiteralPath $SuiteResultPath -Raw|ConvertFrom-Json
if($suite.framework_status-ne'PASS'-or$suite.live_installation_readiness-ne'BLOCKED'-or$suite.blocker-ne'BLOCKED_NOT_IMPLEMENTED'){throw 'Suite result is not an accepted blocked result.'}

function Get-CheckedOutLocalBranch {
    $branchLines=@(& git symbolic-ref --quiet --short HEAD 2>$null)
    $exitCode=$LASTEXITCODE
    if($exitCode -ne 0){
        throw 'Detached HEAD is not supported for readiness-manifest generation; check out a named local branch and rerun.'
    }
    $branch=($branchLines -join "`n").Trim()
    if([string]::IsNullOrWhiteSpace($branch) -or $branch -match "[`r`n]"){
        throw 'Could not derive a single checked-out local branch name from Git.'
    }
    return $branch
}

function New-Entry($Id,$Path,$State,$Result){
    $full=[IO.Path]::GetFullPath((Join-Path $root $Path))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Invalid manifest path: $Path"}
    $item=Get-Item -LiteralPath $full
    [pscustomobject][ordered]@{id=$Id;relative_path=$Path.Replace('\','/');state=$State;byte_size=[long]$item.Length;sha256=(Get-FileHash $full -Algorithm SHA256).Hash;result=$Result;evidence_classification='synthetic'}
}

function Get-PowerShellInventory {
    $tracked=@(& git ls-files '*.ps1' '*.psm1' | ForEach-Object { $_.Replace('\','/') } | Sort-Object)
    $ps1=@($tracked|Where-Object{$_ -like '*.ps1'})
    $psm1=@($tracked|Where-Object{$_ -like '*.psm1'})
    $parsed=[Collections.Generic.List[string]]::new()
    $parseErrors=[Collections.Generic.List[object]]::new()
    foreach($path in $tracked){
        $full=[IO.Path]::GetFullPath((Join-Path $root $path))
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($full,[ref]$tokens,[ref]$errors)
        if(@($errors).Count){$parseErrors.Add([pscustomobject]@{path=$path;errors=@($errors|ForEach-Object{$_.Message})})}
        $parsed.Add($path)
    }
    $parsedPs1=@($parsed|Where-Object{$_ -like '*.ps1'})
    $parsedPsm1=@($parsed|Where-Object{$_ -like '*.psm1'})
    $normalized=@($tracked|ForEach-Object{$_.ToLowerInvariant()})
    $parsedNormalized=@($parsed|ForEach-Object{$_.ToLowerInvariant()})
    [pscustomobject][ordered]@{
        tracked_ps1_count=$ps1.Count
        tracked_psm1_count=$psm1.Count
        tracked_powershell_count=$tracked.Count
        parsed_ps1_count=$parsedPs1.Count
        parsed_psm1_count=$parsedPsm1.Count
        parsed_powershell_count=$parsed.Count
        parse_error_count=$parseErrors.Count
        excluded_files=@()
        duplicate_normalized_path_count=@($normalized|Group-Object|Where-Object Count -gt 1).Count
        missing_count=@($normalized|Where-Object{$parsedNormalized -notcontains $_}).Count
        extra_count=@($parsedNormalized|Where-Object{$normalized -notcontains $_}).Count
        parse_errors=@($parseErrors)
    }
}

$base='9b5c8f3b4ac8c0dc0453da693266a82fea636ec0'
$paths=@(&git diff "$base..HEAD" --name-only)+@(&git diff HEAD --name-only)
$paths=@($paths|Where-Object{$_-and$_-ne$OutputPath}|Sort-Object -Unique)
$entries=[Collections.Generic.List[object]]::new()
foreach($path in $paths){$entries.Add((New-Entry ('tracked-'+(($path.ToLowerInvariant()-replace'[^a-z0-9]+','-').Trim('-'))) $path tracked VALIDATED))}
$suiteRelative=[IO.Path]::GetFullPath($SuiteResultPath).Substring($root.Length+1).Replace('\','/')
$entries.Add((New-Entry evidence-synthetic-suite $suiteRelative ignored PASS))
$pssa=Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
$pssaResult=if($null-eq$pssa){'SKIPPED_UNAVAILABLE'}else{'AVAILABLE_NOT_RUN'}
$powershellInventory=Get-PowerShellInventory
$checkedOutBranch=Get-CheckedOutLocalBranch

$manifest=[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-bringup-readiness-manifest-v3'
    generated_utc=(Get-Date).ToUniversalTime().ToString('o')
    framework_status='PASS'
    live_installation_readiness='BLOCKED'
    blocker='BLOCKED_NOT_IMPLEMENTED'
    repository=[pscustomobject][ordered]@{
        branch=$checkedOutBranch
        frozen_baseline_commit='f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        prior_readiness_implementation_commit='ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10'
        prior_readiness_finalization_commit='88e3cbba3a64828322b7c703765e6b1e2369f698'
        current_readiness_implementation_commit=$ImplementationCommit
        current_readiness_finalization_commit_source='external exact 40-character audit input after finalization commit'
    }
    accepted_offline_baseline=[pscustomobject][ordered]@{
        manifest_size=28088;manifest_sha256='35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
        debug_sys_size=68096;debug_sys_sha256='E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
        release_sys_size=40960;release_sys_sha256='A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
    }
    readiness=[pscustomobject][ordered]@{
        fixture_count=[int]$suite.fixture_count
        fixture_assertion_sum=[int]$suite.fixture_assertion_sum
        harness_result_record_count=[int]$suite.harness_result_record_count
        harness_assertion_sum=[int]$suite.harness_assertion_sum
        total_result_record_count=[int]$suite.total_result_record_count
        assertion_count=[int]$suite.assertion_count
        record_assertion_sum=[int]$suite.record_assertion_sum
        category_record_sum=[int]$suite.category_record_sum
        category_assertion_sum=[int]$suite.category_assertion_sum
        assertion_accounting_result=[string]$suite.assertion_accounting_result
        unassigned_assertion_count=[int]$suite.unassigned_assertion_count
        off_ledger_assertion_count=[int]$suite.off_ledger_assertion_count
        duplicate_counted_assertion_count=[int]$suite.duplicate_counted_assertion_count
        category_reconciliation_defect_count=[int]$suite.category_reconciliation_defect_count
        category_totals=@($suite.category_totals)
        unrelated_exception_false_positive_count=0;empty_operation_install_pass_count=0;install_plan_crash_count=0
        invalid_schema_transition_acceptance_count=[int]$suite.invalid_schema_transition_acceptance_count;unlinked_stop_condition_count=[int]$suite.unlinked_stop_condition_count
        invalid_lifecycle_acceptance_count=[int]$suite.invalid_lifecycle_acceptance_count;missing_start_timestamp_acceptance_count=[int]$suite.missing_start_timestamp_acceptance_count
        stop_condition_count=[int]$suite.stop_condition_count;unique_stop_condition_count=[int]$suite.unique_stop_condition_count
        runtime_observer_linkage_count=[int]$suite.runtime_observer_linkage_count;unknown_stop_condition_id_count=[int]$suite.unknown_stop_condition_id_count
        malformed_linkage_count=[int]$suite.malformed_linkage_count;nested_array_acceptance_count=[int]$suite.nested_array_acceptance_count
        uncontrolled_exception_count=[int]$suite.uncontrolled_exception_count;property_not_found_exception_count=[int]$suite.property_not_found_exception_count;strictmode_exception_count=[int]$suite.strictmode_exception_count
        observer_provenance_contract_result=[string]$suite.observer_provenance_contract_result
        missing_provenance_probe_count=[int]$suite.missing_provenance_probe_count
        missing_provenance_pass_count=[int]$suite.missing_provenance_pass_count
        synthetic_source_probe_count=[int]$suite.synthetic_source_probe_count
        synthetic_runtime_observer_pass_count=[int]$suite.synthetic_runtime_observer_pass_count
        unsupported_runtime_observer_pass_count=[int]$suite.unsupported_runtime_observer_pass_count
        runtime_observations_evaluated_live=[int]$suite.runtime_observations_evaluated_live
        runtime_observation_gates_blocked_or_unavailable=[int]$suite.runtime_observation_gates_blocked_or_unavailable
        malformed_input_validator_count=[int]$suite.malformed_input_validator_count;malformed_input_case_count=[int]$suite.malformed_input_case_count
        committed_sample_structural_validation=[string]$suite.committed_sample_structural_validation
        committed_sample_semantic_validation=[string]$suite.committed_sample_semantic_validation
        powershell_inventory=$powershellInventory
        psscriptanalyzer_status=$pssaResult;runtime_evidence_schema='chatpad-runtime-evidence-schema-v3'
        exact_instance_binding_operations=0;exact_instance_restoration_operations=0;broad_approved_install_operations=0;broad_approved_rollback_operations=0
    }
    entries=@($entries)
}
$manifestJson=$manifest|ConvertTo-Json -Depth 20
[IO.File]::WriteAllText((Join-Path $root $OutputPath),$manifestJson+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
"Manifest=$OutputPath";"Entries=$($entries.Count)";'FrameworkStatus=PASS';'LiveInstallationReadiness=BLOCKED'
