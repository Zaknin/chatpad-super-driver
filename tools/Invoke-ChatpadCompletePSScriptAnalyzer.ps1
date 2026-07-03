[CmdletBinding()]
param(
    [string]$RepositoryRoot='',
    [string]$OutputPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not$RepositoryRoot){$RepositoryRoot=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())}
$RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
$tracked=@(&git -C $RepositoryRoot ls-files '*.ps1' '*.psm1'|Sort-Object)
$findings=[Collections.Generic.List[object]]::new()
$failures=[Collections.Generic.List[object]]::new()

function ConvertTo-EncodedCommand {
    param([Parameter(Mandatory)][string]$Text)
    [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Text))
}

foreach($path in $tracked){
    $full=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $path))
    $command=@"
`$ErrorActionPreference='Stop'
try {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    `$items=@(Invoke-ScriptAnalyzer -Path '$($full.Replace("'","''"))' -ErrorAction Stop|ForEach-Object{[pscustomobject]@{rule_name=[string]`$_.RuleName;line=[int]`$_.Line;severity=[string]`$_.Severity;message=[string]`$_.Message}})
    [pscustomobject]@{success=`$true;findings=`$items;exception_type='';message=''}|ConvertTo-Json -Depth 6 -Compress
} catch {
    [pscustomobject]@{success=`$false;findings=@();exception_type=`$_.Exception.GetType().FullName;message=`$_.Exception.Message}|ConvertTo-Json -Depth 6 -Compress
}
"@
    $raw=@(&powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand (ConvertTo-EncodedCommand $command))
    if($LASTEXITCODE-ne0-or-not$raw.Count){
        $failures.Add([pscustomobject]@{file=$path;exception_type='ANALYZER_CHILD_PROCESS_FAILED';message="Exit code $LASTEXITCODE with no valid result."})
        continue
    }
    try {$result=($raw-join"`n")|ConvertFrom-Json}
    catch {
        $failures.Add([pscustomobject]@{file=$path;exception_type=$_.Exception.GetType().FullName;message='Analyzer child result was not valid JSON.'})
        continue
    }
    if(-not[bool]$result.success){
        $failures.Add([pscustomobject]@{file=$path;exception_type=[string]$result.exception_type;message=[string]$result.message})
        continue
    }
    foreach($finding in @($result.findings)){
        $findings.Add([pscustomobject]@{rule_name=[string]$finding.rule_name;file=$path;line=[int]$finding.line;severity=[string]$finding.severity;message=[string]$finding.message})
    }
}

$sorted=@($findings|Sort-Object file,line,rule_name,severity,message)
$result=[pscustomobject][ordered]@{
    schema_version='chatpad-complete-psscriptanalyzer-v1'
    supported_runtime='Windows PowerShell 5.1'
    child_process_isolation='one-clean-process-per-tracked-file'
    tracked_ps1_count=@($tracked|Where-Object{$_-like'*.ps1'}).Count
    tracked_psm1_count=@($tracked|Where-Object{$_-like'*.psm1'}).Count
    tracked_total=$tracked.Count
    analyzed_file_count=$tracked.Count
    error_count=@($sorted|Where-Object severity -eq Error).Count
    warning_count=@($sorted|Where-Object severity -eq Warning).Count
    information_count=@($sorted|Where-Object severity -eq Information).Count
    tool_failure_count=$failures.Count
    findings=$sorted
    tool_failures=@($failures)
    blanket_suppression_used=$false
}
$json=$result|ConvertTo-Json -Depth 10
if($OutputPath){
    $fullOutput=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $OutputPath))
    if(-not$fullOutput.StartsWith($RepositoryRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'OutputPath must remain in the repository.'}
    [IO.Directory]::CreateDirectory((Split-Path -Parent $fullOutput))|Out-Null
    [IO.File]::WriteAllText($fullOutput,$json+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}
$json
if($result.error_count-or$result.tool_failure_count){exit 1}
