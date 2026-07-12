[CmdletBinding()]param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$expectedRoot='C:\Dev\chatpad-super-driver'
$expectedBranch='feature/native-adapter-local-host-readiness-observation'
$expectedHead='c70d1b94c9fdc14de598df8326b6e0e912dc811d'
$moduleRelative='tools/ExactInstance/ChatpadLocalDevelopmentHostReadiness.psm1'
$moduleSha256='1DC7E8EC2FB4A5C0EDF03139EF391E162B8ECFADCA11EEF01DE90EC122028217'
$allowed=@($moduleRelative,'tools/Invoke-ChatpadLocalDevelopmentHostReadinessObservation.ps1','tools/Test-ChatpadLocalDevelopmentHostReadinessObservation.ps1')
$evidenceRelative='docs/evidence/local-development-host-readiness-observation-task-8i-p1b-ld-o1.json'
$allowedStatus=@($allowed)+$evidenceRelative
$knownExternalBcdTestSigningChange=$true
$reportedCommandResult='SUCCESS'
$rebootSinceTestSigningChange='OPERATOR_REPORTED_FALSE'
$firstAttemptSha256='255C874A774CF6492B4A70A99214988824351E738B9AC8D10443F59B441E31C3'
$firstAttemptObservationUtc='2026-07-12T00:25:29.5568249Z'
$firstAttemptOutcome='LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE'

if($PSVersionTable.PSVersion.Major-lt7){throw 'PowerShell 7 or later is required.'}
if(-not[Environment]::Is64BitProcess){throw 'An x64 PowerShell process is required.'}
$who=& "$env:SystemRoot\System32\whoami.exe" /groups /fo csv /nh 2>&1
if($LASTEXITCODE-ne0){throw 'Unable to establish elevation state.'}
$admin=@($who|Where-Object{$_-match'S-1-5-32-544'})|Select-Object -First 1
$integrity=@($who|Where-Object{$_-match'S-1-16-(\d+)'})|Select-Object -First 1
$rid=$null;if($integrity-match'S-1-16-(\d+)'){$rid=[int]$Matches[1]}
if($null-eq$admin-or$admin-match'Deny only'-or$null-eq$rid-or$rid-lt12288){throw 'A fully elevated administrator token is required.'}

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($root.TrimEnd('\')-cne$expectedRoot){throw "Repository root must be $expectedRoot"}
Push-Location $root
try{
    $branch=(& git branch --show-current).Trim();if($LASTEXITCODE-ne0-or$branch-cne$expectedBranch){throw 'Unexpected branch.'}
    $head=(& git rev-parse HEAD).Trim();if($LASTEXITCODE-ne0-or$head-cne$expectedHead){throw 'Unexpected HEAD.'}
    $status=@(& git status --porcelain=v1 --untracked-files=all);if($LASTEXITCODE-ne0){throw 'Unable to read repository status.'}
    foreach($line in $status){if($line.Length-lt4){throw 'Malformed Git status.'};$path=($line.Substring(3)-replace'\\','/');if($line.Substring(0,2)-cne'??'-or$allowedStatus-cnotcontains$path){throw "Unrelated repository change: $line"}}
    foreach($path in $allowed){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Required observer source missing: $path"}}
    if((Get-FileHash -LiteralPath $moduleRelative -Algorithm SHA256).Hash-cne$moduleSha256){throw 'Observer module identity mismatch.'}
    $evidence=$evidenceRelative
    if(-not(Test-Path -LiteralPath $evidence -PathType Leaf)){throw 'The exact first-attempt evidence is required for bounded supersession.'}
    try{$oldHash=(Get-FileHash -LiteralPath $evidence -Algorithm SHA256).Hash;$old=[IO.File]::ReadAllText((Resolve-Path $evidence))|ConvertFrom-Json}catch{throw 'Refusing to overwrite an unrelated evidence file.'}
    $oldObservationUtc=([DateTimeOffset]$old.observation_utc).UtcDateTime.ToString('o')
    $knownIdentity=$old.schema-ceq'chatpad-local-development-host-readiness-observation-v1'-and$oldObservationUtc-ceq$firstAttemptObservationUtc-and$old.selected_outcome-ceq$firstAttemptOutcome-and[int]$old.observer_mutation_count-eq0
    if($oldHash-cne$firstAttemptSha256-and-not$knownIdentity){throw 'Refusing to overwrite evidence that is not the exact known first inconclusive observation.'}
    Import-Module (Join-Path $root $moduleRelative) -Force
    $record=Get-ChatpadLocalDevelopmentHostReadiness -KnownExternalBcdTestSigningChange $knownExternalBcdTestSigningChange -ReportedCommandResult $reportedCommandResult -RebootSinceTestSigningChange $rebootSinceTestSigningChange
    $record|Add-Member -NotePropertyName supersedes_observation_sha256 -NotePropertyValue $firstAttemptSha256
    $record|Add-Member -NotePropertyName superseded_outcome -NotePropertyValue $firstAttemptOutcome
    $record|Add-Member -NotePropertyName supersession_reason -NotePropertyValue 'TARGETED_HOST_READINESS_OBSERVATION_REMEDIATION'
    $required=@('schema','observation_utc','windows','elevation','pre_observation_context','secure_boot','bcd','testsigning_state','device_guard','hvci','bitlocker','certificates','signature_enforcement_conclusion','selected_outcome','next_task','observer_mutation_count','overall_lane_mutation_count','query_counters','mutation_counters','supersedes_observation_sha256','superseded_outcome','supersession_reason')
    if(@(Compare-Object $required @($record.PSObject.Properties.Name) -CaseSensitive).Count){throw 'Observer returned an invalid evidence schema.'}
    if($record.schema-cne'chatpad-local-development-host-readiness-observation-v1'-or$record.selected_outcome-notin@('LOCAL_TEST_SIGNING_ALREADY_ENABLED_READY_FOR_SELF_TEST_SIGNED_PACKAGE_PREPARATION','LOCAL_TEST_SIGNING_DISABLED_HOST_SUPPORTS_CONTROLLED_ENABLEMENT','LOCAL_TEST_SIGNING_ROUTE_REQUIRES_SECURE_BOOT_OR_DISK_PROTECTION_DECISION','LOCAL_TEST_SIGNING_CONFIGURED_REBOOT_PENDING','LOCAL_DEVELOPMENT_SIGNING_ROUTE_NOT_YET_DETERMINABLE')){throw 'Observer returned an invalid bounded value.'}
    $external=$record.pre_observation_context.pre_observation_external_mutation
    if([int]$record.observer_mutation_count-ne0-or[int]$record.overall_lane_mutation_count-ne1-or[int]$record.pre_observation_context.pre_observation_external_mutation_count-ne1-or-not[bool]$record.pre_observation_context.known_external_bcd_testsigning_change-or$record.pre_observation_context.reboot_since_testsigning_change-cne'OPERATOR_REPORTED_FALSE'-or$record.pre_observation_context.testsigning_configured_for_next_boot_initial_state-cne'TO_BE_CONFIRMED_BY_READ_ONLY_BCD_OBSERVATION'-or$record.pre_observation_context.testsigning_configured_for_next_boot-notin@('CONFIRMED_ENABLED_BY_READ_ONLY_BCD_OBSERVATION','CONFIRMED_NOT_ENABLED_BY_READ_ONLY_BCD_OBSERVATION','INCONCLUSIVE_AFTER_READ_ONLY_BCD_OBSERVATION')-or$record.pre_observation_context.effective_test_mode_current_boot-cne'NOT_CONCLUSIVELY_OBSERVED'-or$external.command-cne'bcdedit /set testsigning on'-or$external.reported_result-cne'SUCCESS'-or$external.source-cne'OPERATOR_CONSOLE_TRANSCRIPT'-or[bool]$external.performed_by_observer){throw 'Observer returned invalid pre-observation mutation context.'}
    if($record.supersedes_observation_sha256-cne$firstAttemptSha256-or$record.superseded_outcome-cne$firstAttemptOutcome-or$record.supersession_reason-cne'TARGETED_HOST_READINESS_OBSERVATION_REMEDIATION'){throw 'Observer returned invalid supersession context.'}
    foreach($p in $record.mutation_counters.PSObject.Properties){if([int64]$p.Value-ne0){throw 'Observer reported a nonzero mutation counter.'}}
    $json=$record|ConvertTo-Json -Depth 12
    $full=[IO.Path]::GetFullPath((Join-Path $root $evidence));$dir=[IO.Path]::GetDirectoryName($full);$temp=Join-Path $dir ('.'+[IO.Path]::GetFileName($full)+'.'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{[IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false));Move-Item -LiteralPath $temp -Destination $full -Force}catch{Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;throw}
    $item=Get-Item -LiteralPath $full;$hash=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    [pscustomobject][ordered]@{evidence_path=$full;byte_size=[int64]$item.Length;sha256=$hash;selected_outcome=$record.selected_outcome;next_task=$record.next_task}|Format-List
}finally{Pop-Location}
