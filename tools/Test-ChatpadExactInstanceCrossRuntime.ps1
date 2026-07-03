[CmdletBinding()]
param(
    [string]$ImplementationCommit='',
    [string]$OutputPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
if(-not$ImplementationCommit){$ImplementationCommit=(&git rev-parse HEAD).Trim()}
if($ImplementationCommit-notmatch'^[0-9a-f]{40}$'){throw 'ImplementationCommit must be a full lowercase commit hash.'}
$workRoot=Join-Path $root ('artifacts\tmp\exact-instance-cross-runtime-'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($workRoot)|Out-Null
$runtimes=[ordered]@{
    'windows-powershell'=(Get-Command powershell.exe -ErrorAction Stop).Source
    'powershell-7'=(Get-Command pwsh.exe -ErrorAction Stop).Source
}

function ConvertTo-EncodedCommand {
    param([Parameter(Mandatory)][string]$Text)
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Text))
}

try {
    $documents=[ordered]@{}
    foreach($producer in $runtimes.GetEnumerator()){
        $documentPath=Join-Path $workRoot ($producer.Key+'.json')
        $command=@"
`$ErrorActionPreference='Stop'
Import-Module '$($root.Replace("'","''"))\tools\ExactInstance\ChatpadExactInstance.OfflineSuite.psm1' -Force
`$environment=New-ChatpadExactSuiteEnvironment
`$created=New-ChatpadExactSuitePlan `$environment '30000000-0000-0000-0000-000000000030' '$ImplementationCommit'
if(`$created.result-ne'PASS'){throw 'plan creation failed'}
`$canonical=ConvertTo-ChatpadExactCanonicalJson `$created.plan
[IO.File]::WriteAllText('$($documentPath.Replace("'","''"))',`$canonical,[Text.UTF8Encoding]::new(`$false))
"@
        & $producer.Value -NoProfile -EncodedCommand (ConvertTo-EncodedCommand $command) | Out-Null
        if($LASTEXITCODE-ne0){throw "Plan creation failed under $($producer.Key)."}
        $documents[$producer.Key]=$documentPath
    }

    $matrix=[Collections.Generic.List[object]]::new()
    foreach($producer in $runtimes.Keys){
        foreach($validator in $runtimes.GetEnumerator()){
            $documentPath=$documents[$producer]
            $command=@"
`$ErrorActionPreference='Stop'
Import-Module '$($root.Replace("'","''"))\tools\ExactInstance\ChatpadExactInstance.Contracts.psm1' -Force
`$document=Test-ChatpadExactJsonDocument ([IO.File]::ReadAllText('$($documentPath.Replace("'","''"))'))
if(`$document.result-ne'PASS'){throw (`$document.defects -join ';')}
`$plan=`$document.value
`$validation=Test-ChatpadExactInstancePlan `$plan -ExpectedPlanSha256 ([string](Get-ChatpadExactProperty `$plan 'plan_sha256' '')) -ExpectedOperationId ([string](Get-ChatpadExactProperty `$plan 'operation_id' '')) -ValidationTimeUtc '2026-07-03T00:05:00Z'
`$snapshot=Get-ChatpadExactProperty `$plan 'restoration_snapshot' `$null
[pscustomobject]@{result=`$validation.result;result_code=`$validation.result_code;plan_sha256=[string](Get-ChatpadExactProperty `$plan 'plan_sha256' '');computed_plan_sha256=Get-ChatpadExactObjectHash `$plan -ExcludedProperties @('plan_sha256');snapshot_sha256=[string](Get-ChatpadExactProperty `$snapshot 'snapshot_sha256' '');computed_snapshot_sha256=Get-ChatpadExactObjectHash `$snapshot -ExcludedProperties @('snapshot_sha256')}|ConvertTo-Json -Compress
"@
            $raw=@(& $validator.Value -NoProfile -EncodedCommand (ConvertTo-EncodedCommand $command))
            if($LASTEXITCODE-ne0){throw "Plan validation failed under $($validator.Key) for $producer output."}
            $value=($raw -join "`n")|ConvertFrom-Json
            $matrix.Add([pscustomobject][ordered]@{
                producer_runtime=$producer
                validator_runtime=$validator.Key
                result=[string]$value.result
                result_code=[string]$value.result_code
                plan_sha256=[string]$value.plan_sha256
                computed_plan_sha256=[string]$value.computed_plan_sha256
                snapshot_sha256=[string]$value.snapshot_sha256
                computed_snapshot_sha256=[string]$value.computed_snapshot_sha256
                hashes_identical=([string]$value.plan_sha256-ceq[string]$value.computed_plan_sha256-and[string]$value.snapshot_sha256-ceq[string]$value.computed_snapshot_sha256)
            })
        }
    }
    $failed=@($matrix|Where-Object{$_.result-ne'PASS'-or-not$_.hashes_identical})
    $result=[pscustomobject][ordered]@{
        schema_version='chatpad-exact-instance-cross-runtime-matrix-v1'
        canonical_json_version='chatpad-canonical-json-v1'
        result=if($failed.Count){'FAIL'}else{'PASS'}
        direction_count=$matrix.Count
        failed_direction_count=$failed.Count
        matrix=@($matrix)
        evidence_hash_contract='not-applicable-evidence-schema-has-no-self-hash'
    }
    $json=$result|ConvertTo-Json -Depth 10
    if($OutputPath){
        $full=[IO.Path]::GetFullPath((Join-Path $root $OutputPath))
        if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'OutputPath must remain inside the repository.'}
        [IO.Directory]::CreateDirectory((Split-Path -Parent $full))|Out-Null
        [IO.File]::WriteAllText($full,$json+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    }
    $json
    if($failed.Count){exit 1}
} finally {
    if(Test-Path -LiteralPath $workRoot){Remove-Item -LiteralPath $workRoot -Recurse -Force}
}
