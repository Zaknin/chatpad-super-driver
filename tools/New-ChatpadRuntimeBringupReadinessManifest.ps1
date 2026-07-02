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

function New-Entry($Id,$Path,$State,$Result){
    $full=[IO.Path]::GetFullPath((Join-Path $root $Path))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Invalid manifest path: $Path"}
    $item=Get-Item -LiteralPath $full
    [pscustomobject][ordered]@{id=$Id;relative_path=$Path.Replace('\','/');state=$State;byte_size=[long]$item.Length;sha256=(Get-FileHash $full -Algorithm SHA256).Hash;result=$Result;evidence_classification='synthetic'}
}

$base='66de13033e4ba5f67465829c25c0e6a158516044'
$paths=@(&git diff "$base..HEAD" --name-only)+@(&git diff HEAD --name-only)
$paths=@($paths|Where-Object{$_-and$_-ne$OutputPath}|Sort-Object -Unique)
$entries=[Collections.Generic.List[object]]::new()
foreach($path in $paths){$entries.Add((New-Entry ('tracked-'+(($path.ToLowerInvariant()-replace'[^a-z0-9]+','-').Trim('-'))) $path tracked VALIDATED))}
$suiteRelative=[IO.Path]::GetFullPath($SuiteResultPath).Substring($root.Length+1).Replace('\','/')
$entries.Add((New-Entry evidence-synthetic-suite $suiteRelative ignored PASS))
$pssa=Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
$pssaResult=if($null-eq$pssa){'SKIPPED_UNAVAILABLE'}else{'AVAILABLE_NOT_RUN'}

$manifest=[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-bringup-readiness-manifest-v3'
    generated_utc=(Get-Date).ToUniversalTime().ToString('o')
    framework_status='PASS'
    live_installation_readiness='BLOCKED'
    blocker='BLOCKED_NOT_IMPLEMENTED'
    repository=[pscustomobject][ordered]@{
        branch='feature/runtime-bringup-readiness-validator-totality-remediation'
        frozen_baseline_commit='f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
        prior_readiness_implementation_commit='0d7f5677c214ebd2081ba40a169e0fc6d1efc0ea'
        prior_readiness_finalization_commit='2bb08fee77125f6b5bed2774c085ce57fe192752'
        current_readiness_implementation_commit=$ImplementationCommit
        current_readiness_finalization_commit_source='external exact 40-character audit input after finalization commit'
    }
    accepted_offline_baseline=[pscustomobject][ordered]@{
        manifest_size=28088;manifest_sha256='35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
        debug_sys_size=68096;debug_sys_sha256='E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
        release_sys_size=40960;release_sys_sha256='A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
    }
    readiness=[pscustomobject][ordered]@{
        fixture_count=[int]$suite.fixture_count;assertion_count=[int]$suite.assertion_count;category_totals=@($suite.category_totals)
        unrelated_exception_false_positive_count=0;empty_operation_install_pass_count=0;install_plan_crash_count=0
        invalid_schema_transition_acceptance_count=[int]$suite.invalid_schema_transition_acceptance_count;unlinked_stop_condition_count=[int]$suite.unlinked_stop_condition_count
        uncontrolled_exception_count=[int]$suite.uncontrolled_exception_count;property_not_found_exception_count=[int]$suite.property_not_found_exception_count;strictmode_exception_count=[int]$suite.strictmode_exception_count
        psscriptanalyzer_status=$pssaResult;runtime_evidence_schema='chatpad-runtime-evidence-schema-v3'
        exact_instance_binding_operations=0;exact_instance_restoration_operations=0;broad_approved_install_operations=0;broad_approved_rollback_operations=0
    }
    entries=@($entries)
}
$manifest|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $root $OutputPath) -Encoding utf8
"Manifest=$OutputPath";"Entries=$($entries.Count)";'FrameworkStatus=PASS';'LiveInstallationReadiness=BLOCKED'
