Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ReadinessBranch = 'feature/runtime-bringup-observer-provenance-accounting-remediation'
$script:FrozenBaselineCommit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
$script:PriorImplementationCommit = 'a810d8ba3438a08cfa4742e53be61f64be5aa58e'
$script:PriorFinalizationCommit = '9b5c8f3b4ac8c0dc0453da693266a82fea636ec0'
$script:AcceptedProviderGuid = '{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}'
$script:AcceptedManifestPath = 'docs/evidence/runtime-instrumentation-implementation-manifest.json'
$script:AcceptedManifestSize = 28088
$script:AcceptedManifestSha256 = '35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
$script:AcceptedDebugSysPath = 'artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys'
$script:AcceptedDebugSysSize = 68096
$script:AcceptedDebugSysSha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
$script:AcceptedReleaseSysPath = 'artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys'
$script:AcceptedReleaseSysSize = 40960
$script:AcceptedReleaseSysSha256 = 'A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'
$script:KnownStopConditionIds = @(
    'target-identity-ambiguous','current-driver-unidentified','rollback-source-unavailable',
    'repository-or-binary-identity-wrong','signing-identity-wrong','package-validation-failed',
    'windows-rejects-signature','wrong-device-binds','unrelated-device-changed',
    'driver-service-fails-unexpectedly','unexpected-code-integrity-error',
    'unexpected-setupapi-match','device-disappears-without-recovery-path',
    'input-behavior-unstable','unplanned-reboot-required','trace-provider-wrong',
    'runtime-evidence-write-failed','command-differs-from-approved-plan',
    'prerequisite-changed-after-approval','rollback-cannot-be-guaranteed'
)

function Get-ChatpadProperty {
    param([object]$Object,[Parameter(Mandatory)][string]$Name,[object]$Default=$null)
    if ($null -eq $Object) { if($Default -is [array]){return ,$Default}; return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { if($Default -is [array]){return ,$Default}; return $Default }
    if ($property.Value -is [array]) { return ,$property.Value }
    return $property.Value
}

function Test-ChatpadObject {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [string] -or $Value -is [array] -or $Value -is [bool] -or $Value -is [ValueType]) { return $false }
    return $null -ne $Value.PSObject
}

function Get-ChatpadArray {
    param([object]$Object,[Parameter(Mandatory)][string]$Name)
    $value = Get-ChatpadProperty $Object $Name $null
    if ($null -eq $value) { return @() }
    if ($value -is [array]) { return @($value) }
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string] -and $value -isnot [pscustomobject]) { return @($value) }
    return @('__CHATPAD_WRONG_TYPE__')
}

function Test-ChatpadStringField {
    param([object]$Object,[Parameter(Mandatory)][string]$Name)
    $value = Get-ChatpadProperty $Object $Name $null
    if ($null -eq $value) { return $false }
    if ($value -is [array] -or $value -is [bool] -or ($value -is [ValueType] -and $value -isnot [string])) { return $false }
    return -not [string]::IsNullOrWhiteSpace([string]$value)
}

function Test-ChatpadTimestampValue {
    param([object]$Value)
    if ($null -eq $Value -or $Value -is [array] -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $false }
    try { [void][datetime]([string]$Value); return $true } catch { return $false }
}

function Compare-ChatpadTimestampOrder {
    param([object]$Start,[object]$Completion)
    try { return ([datetime]([string]$Completion)) -ge ([datetime]([string]$Start)) } catch { return $false }
}

function Test-ChatpadResultRecord {
    param([object]$Value,[switch]$RequireFailure)
    $fail = @()
    if (-not (Test-ChatpadObject $Value)) { return @('result-record-not-object') }
    if (-not (Test-ChatpadStringField $Value 'outcome')) { $fail += 'result-outcome-missing' }
    if ($null -eq (Get-ChatpadProperty $Value 'exit_code' $null)) { $fail += 'result-exit-code-missing' }
    else {
        try {
            $exit = [int](Get-ChatpadProperty $Value 'exit_code')
            if ($RequireFailure -and $exit -eq 0) { $fail += 'failed-result-success-exit' }
        } catch { $fail += 'result-exit-code-invalid' }
    }
    if (-not (Test-ChatpadStringField $Value 'operation_id')) { $fail += 'result-operation-id-missing' }
    return @($fail)
}

function Test-ChatpadNonEmpty {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [array]) { return @($Value).Count -gt 0 }
    return -not [string]::IsNullOrWhiteSpace([string]$Value)
}

function New-ChatpadRuntimeCheckResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL','BLOCKED')][string]$Result,
        [Parameter(Mandatory)][string]$ResultCode,
        [string]$Reason = '',
        [string[]]$StopConditionIds = @(),
        [object]$Data = $null
    )
    if ($Result -ne 'PASS') { Assert-ChatpadStopConditionIds $StopConditionIds | Out-Null }
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-runtime-check-result-v3'
        check = $Check
        result = $Result
        result_code = $ResultCode
        reason = $Reason
        stop_condition_ids = @($StopConditionIds)
        data = $Data
    }
}

function New-ChatpadValidatorInternalError {
    param([Parameter(Mandatory)][string]$Check,[Parameter(Mandatory)][Exception]$Exception)
    $message = ($Exception.Message -replace '[\r\n]+',' ').Trim()
    New-ChatpadRuntimeCheckResult `
        -Check $Check `
        -Result FAIL `
        -ResultCode VALIDATOR_INTERNAL_ERROR `
        -Reason 'Unexpected validator exception was contained.' `
        -StopConditionIds @('command-differs-from-approved-plan') `
        -Data ([pscustomobject]@{
            framework_error = $true
            exception_type = $Exception.GetType().FullName
            sanitized_message = $message
        })
}

function Assert-ChatpadStopConditionIds {
    param([Parameter(Mandatory)][string[]]$StopConditionIds)
    if (@($StopConditionIds).Count -eq 0) { throw [ArgumentException]::new('At least one stop-condition ID is required.') }
    foreach ($id in $StopConditionIds) {
        if ($script:KnownStopConditionIds -notcontains $id) { throw [ArgumentException]::new("Unknown stop-condition ID: $id") }
    }
    $true
}

function Assert-ChatpadFullCommit {
    param([Parameter(Mandatory)][string]$Value,[Parameter(Mandatory)][string]$Name)
    if ($Value -notmatch '^[0-9a-f]{40}$') { throw [ArgumentException]::new("$Name must be a full lowercase 40-character commit hash.") }
}

function Assert-ChatpadScalar {
    param([Parameter(Mandatory)][object]$Value,[Parameter(Mandatory)][string]$Name,[switch]$AllowQuotes,[switch]$AllowWildcards)
    if ($Value -is [array]) { throw [ArgumentException]::new("$Name must be a scalar value.") }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { throw [ArgumentException]::new("$Name is required.") }
    if ($text.IndexOf([char]0) -ge 0) { throw [ArgumentException]::new("$Name contains NUL.") }
    if ($text -match "[`r`n]") { throw [ArgumentException]::new("$Name contains a line break.") }
    if ($text -match '[\u202A-\u202E\u2066-\u2069\u200B\u200C\u200D\uFEFF]') { throw [ArgumentException]::new("$Name contains an unsupported Unicode control character.") }
    foreach ($ch in $text.ToCharArray()) {
        if ([int][char]$ch -lt 32 -and $ch -ne [char]9) { throw [ArgumentException]::new("$Name contains a control character.") }
    }
    if (-not $AllowQuotes -and $text -match '"') { throw [ArgumentException]::new("$Name contains an unsupported double quote.") }
    if (-not $AllowWildcards -and $text -match '[*?]') { throw [ArgumentException]::new("$Name must not contain wildcards.") }
    if ($Name -in @('Argument','WorkingDirectory','TargetInstanceId') -and $text -match '(^|[\\/])\.\.([\\/]|$)') { throw [ArgumentException]::new("$Name contains path traversal.") }
    $text
}

function Test-ChatpadPathContained {
    param([Parameter(Mandatory)][object]$Root,[Parameter(Mandatory)][object]$Candidate,[switch]$AllowRoot)
    if ($Root -is [array] -or $Candidate -is [array]) { return $false }
    try {
        $rootFull = [IO.Path]::GetFullPath([string]$Root).TrimEnd('\','/')
        $candidateFull = [IO.Path]::GetFullPath([string]$Candidate).TrimEnd('\','/')
    } catch { return $false }
    if ($AllowRoot -and $candidateFull.Equals($rootFull,[StringComparison]::OrdinalIgnoreCase)) { return $true }
    $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-ChatpadDisplayArgument {
    param([Parameter(Mandatory)][string]$Value)
    "'" + ($Value -replace "'", "''") + "'"
}

function New-ChatpadOperationPlan {
    param(
        [Parameter(Mandatory)][object]$OperationId,
        [Parameter(Mandatory)][ValidateSet('validate','stage','bind','verify','restore','rescan','trace-start','trace-stop','preserve','hash','event-export','observe')][string]$OperationType,
        [Parameter(Mandatory)][object]$Executable,
        [Parameter(Mandatory)][object[]]$Arguments,
        [ValidateSet('none','host','exact-device')][string]$TargetScope='none',
        [object]$TargetInstanceId='',
        [string[]]$InputArtifactIds=@(),
        [string[]]$PrerequisiteResultIds=@(),
        [Parameter(Mandatory)][string[]]$StopConditionIds,
        [int[]]$ExpectedExitCodes=@(0),
        [Parameter(Mandatory)][ValidateSet('offline-read-only','live-host-read-only','live-device-query','broad-host-mutation','exact-target-mutation','render-only')][string]$MutationClassification,
        [bool]$RequiresAuthorization=$true,
        [Parameter(Mandatory)][ValidateSet('planned','blocked','skipped_authorization','executed','failed','rolled_back','restored')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('synthetic','live')][string]$SourceClassification,
        [Parameter(Mandatory)][object]$SessionId,
        [Parameter(Mandatory)][object]$HostId,
        [Nullable[bool]]$ApprovedAsTargetSpecific=$null,
        [string]$Blocker='',
        [object]$ResultRecord=$null,
        [string]$StartUtc='',
        [string]$CompletedUtc='',
        [string]$RollbackOperationId='',
        [string]$OriginalOperationId='',
        [string]$FinalStateEvidenceId='',
        [string]$AuthorizationEvidenceId='',
        [object]$WorkingDirectory='<APPROVED_RUNTIME_WORKING_DIRECTORY>'
    )
    $safeId=Assert-ChatpadScalar $OperationId OperationId
    $safeExe=Assert-ChatpadScalar $Executable Executable
    $safeSession=Assert-ChatpadScalar $SessionId SessionId
    $safeHost=Assert-ChatpadScalar $HostId HostId
    $safeWorking=Assert-ChatpadScalar $WorkingDirectory WorkingDirectory -AllowQuotes -AllowWildcards
    $safeArgs=@();foreach($arg in @($Arguments)){$safeArgs+=Assert-ChatpadScalar $arg Argument -AllowQuotes -AllowWildcards}
    Assert-ChatpadStopConditionIds $StopConditionIds|Out-Null
    $safeTarget=''
    if($TargetScope -eq 'exact-device'){
        $safeTarget=Assert-ChatpadScalar $TargetInstanceId TargetInstanceId
        if($ApprovedAsTargetSpecific -ne $true){throw [ArgumentException]::new('Exact-device operation requires approved_as_target_specific=true.')}
    } elseif(Test-ChatpadNonEmpty $TargetInstanceId){$safeTarget=Assert-ChatpadScalar $TargetInstanceId TargetInstanceId}
    if($Status -eq 'blocked' -and [string]::IsNullOrWhiteSpace($Blocker)){throw [ArgumentException]::new('Blocked operation requires a blocker.')}
    if($Status -eq 'planned' -and ($null-ne$ResultRecord -or $StartUtc -or $CompletedUtc)){throw [ArgumentException]::new('Planned operation cannot contain execution evidence.')}
    if($Status -in @('executed','failed') -and ($null-eq$ResultRecord -or [string]::IsNullOrWhiteSpace($StartUtc) -or [string]::IsNullOrWhiteSpace($CompletedUtc))){throw [ArgumentException]::new("$Status operation requires result and execution timestamps.")}
    if($Status -eq 'failed' -and [int](Get-ChatpadProperty $ResultRecord 'exit_code' 0) -in $ExpectedExitCodes){throw [ArgumentException]::new('Failed operation requires a non-success exit code.')}
    if($Status -eq 'rolled_back' -and ([string]::IsNullOrWhiteSpace($OriginalOperationId) -or [string]::IsNullOrWhiteSpace($RollbackOperationId))){throw [ArgumentException]::new('Rolled-back operation requires original and rollback operation identity.')}
    if($Status -eq 'restored' -and [string]::IsNullOrWhiteSpace($FinalStateEvidenceId)){throw [ArgumentException]::new('Restored operation requires final-state evidence identity.')}
    [pscustomobject][ordered]@{
        schema_version='chatpad-structured-operation-v2';operation_id=$safeId;operation_type=$OperationType
        executable=$safeExe;arguments=@($safeArgs);working_directory=$safeWorking
        mutation_classification=$MutationClassification;target_scope=$TargetScope;target_instance_id=$safeTarget
        approved_as_target_specific=$(if($null-eq$ApprovedAsTargetSpecific){$false}else{[bool]$ApprovedAsTargetSpecific})
        input_artifact_ids=@($InputArtifactIds);prerequisite_result_ids=@($PrerequisiteResultIds)
        stop_condition_ids=@($StopConditionIds);expected_exit_codes=@($ExpectedExitCodes)
        requires_authorization=$RequiresAuthorization;status=$Status;source_classification=$SourceClassification
        session_id=$safeSession;host_id=$safeHost;blocker=$Blocker;result_record=$ResultRecord
        start_timestamp=$StartUtc;completion_timestamp=$CompletedUtc;completed_utc=$CompletedUtc
        original_operation_id=$OriginalOperationId;rollback_operation_id=$RollbackOperationId
        final_state_evidence_id=$FinalStateEvidenceId;authorization_evidence_id=$AuthorizationEvidenceId
        command_display=(ConvertTo-ChatpadDisplayArgument $safeExe)+' '+(($safeArgs|ForEach-Object{ConvertTo-ChatpadDisplayArgument $_})-join' ')
        display_is_execution_evidence=$false
        launch_contract='Future execution must use System.Diagnostics.ProcessStartInfo.ArgumentList and must never reparse command_display.'
    }
}

function Test-ChatpadOperationPlanContract {
    param($Operation)
    $fail=@()
    if (-not (Test-ChatpadObject $Operation)) {
        return New-ChatpadRuntimeCheckResult operation-plan FAIL OPERATION_LIFECYCLE_INVALID 'operation-not-object' @('command-differs-from-approved-plan')
    }
    foreach($f in @('operation_id','operation_type','executable','arguments','mutation_classification','target_scope','prerequisite_result_ids','stop_condition_ids','expected_exit_codes','requires_authorization','status','source_classification','session_id','host_id','approved_as_target_specific','display_is_execution_evidence')){
        if($null-eq$Operation.PSObject.Properties[$f]){$fail+="missing:$f"}
    }
    if($fail.Count){return New-ChatpadRuntimeCheckResult operation-plan FAIL OPERATION_FIELDS_MISSING ($fail-join';') @('command-differs-from-approved-plan')}
    $status = [string](Get-ChatpadProperty $Operation status '')
    $targetScope = [string](Get-ChatpadProperty $Operation target_scope '')
    $resultRecord = Get-ChatpadProperty $Operation result_record $null
    $startTimestamp = Get-ChatpadProperty $Operation start_timestamp ''
    $completionTimestamp = Get-ChatpadProperty $Operation completion_timestamp (Get-ChatpadProperty $Operation completed_utc '')
    $expectedExitCodes = @(Get-ChatpadArray $Operation expected_exit_codes)
    $arguments = Get-ChatpadProperty $Operation arguments $null
    if($status -notin @('planned','blocked','skipped_authorization','executed','failed','rolled_back','restored')){$fail+='status-invalid'}
    if($status -eq 'blocked' -and -not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation blocker ''))){$fail+='blocked-without-blocker'}
    if($targetScope -eq 'exact-device' -and (-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation target_instance_id '')) -or (Get-ChatpadProperty $Operation approved_as_target_specific $false)-ne$true)){$fail+='exact-target-invalid'}
    if($null -eq $arguments -or $arguments -isnot [array]){$fail+='arguments-not-array'}
    if($expectedExitCodes.Count -eq 0){$fail+='expected-exit-codes-missing'}
    foreach($code in $expectedExitCodes){try{[void][int]$code}catch{$fail+='expected-exit-code-invalid'}}
    if($status -in @('planned','blocked','skipped_authorization')){
        if($null-ne$resultRecord){$fail+="$status-has-result"}
        if(Test-ChatpadTimestampValue $startTimestamp -or Test-ChatpadTimestampValue $completionTimestamp){$fail+="$status-has-execution-timestamp"}
        if(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation rollback_operation_id '')){$fail+="$status-has-rollback-reference"}
        if(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation final_state_evidence_id '')){$fail+="$status-has-restoration-evidence"}
    }
    if($status -eq 'skipped_authorization' -and -not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation authorization_evidence_id ''))){$fail+='authorization-evidence-missing'}
    if($status -in @('executed','failed','rolled_back')){
        $fail += @(Test-ChatpadResultRecord $resultRecord -RequireFailure:($status -eq 'failed'))
        if(-not(Test-ChatpadTimestampValue $startTimestamp)){$fail+='start-timestamp-missing'}
        if(-not(Test-ChatpadTimestampValue $completionTimestamp)){$fail+='completion-timestamp-missing'}
        elseif((Test-ChatpadTimestampValue $startTimestamp) -and -not(Compare-ChatpadTimestampOrder $startTimestamp $completionTimestamp)){$fail+='completion-before-start'}
        if($null -ne $resultRecord -and (Test-ChatpadObject $resultRecord)){
            $outcome = [string](Get-ChatpadProperty $resultRecord outcome '')
            $exitCode = $null
            try { $exitCode = [int](Get-ChatpadProperty $resultRecord exit_code $null) } catch {}
            if((Get-ChatpadProperty $resultRecord operation_id '') -ne (Get-ChatpadProperty $Operation operation_id '')){$fail+='result-operation-id-mismatch'}
            if($status -eq 'executed' -and ($expectedExitCodes -notcontains $exitCode -or $outcome -notin @('success','executed'))){$fail+='executed-result-inconsistent'}
            if($status -eq 'failed' -and ($expectedExitCodes -contains $exitCode -and $outcome -in @('success','executed'))){$fail+='failed-result-success'}
            if($status -eq 'rolled_back' -and ($expectedExitCodes -notcontains $exitCode -or $outcome -notin @('success','rolled_back','restored-baseline'))){$fail+='rollback-result-unsuccessful'}
        }
    }
    if($status -eq 'rolled_back'){
        if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation original_operation_id ''))){$fail+='original-mutation-reference-missing'}
        if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation rollback_operation_id ''))){$fail+='rollback-operation-reference-missing'}
    }
    if($status -eq 'restored'){
        if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Operation final_state_evidence_id ''))){$fail+='final-reconciliation-evidence-missing'}
        if(-not(Test-ChatpadTimestampValue $completionTimestamp)){$fail+='restoration-timestamp-missing'}
        if($null -eq $resultRecord){$fail+='restored-result-missing'}
        else{
            $fail += @(Test-ChatpadResultRecord $resultRecord)
            if((Get-ChatpadProperty $resultRecord outcome '') -ne 'restored-baseline'){$fail+='restored-baseline-result-missing'}
        }
        if(@(Get-ChatpadArray $Operation unresolved_deviation_ids).Count){$fail+='restored-has-unresolved-deviation'}
    }
    if((Get-ChatpadProperty $Operation display_is_execution_evidence $true)-ne$false){$fail+='display-marked-executable'}
    try{Assert-ChatpadStopConditionIds @(Get-ChatpadProperty $Operation stop_condition_ids @())|Out-Null}catch{$fail+=$_.Exception.Message}
    if($fail.Count){return New-ChatpadRuntimeCheckResult operation-plan FAIL OPERATION_LIFECYCLE_INVALID ($fail-join';') @('command-differs-from-approved-plan')}
    New-ChatpadRuntimeCheckResult operation-plan PASS OPERATION_CONTRACT_VALID -Data $Operation
}

function Read-ChatpadJson {
    param([Parameter(Mandatory)][string]$Path)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw [IO.FileNotFoundException]::new("JSON file missing: $Path")}
    $raw=Get-Content -LiteralPath $Path -Raw
    $doc=$raw|ConvertFrom-Json
    ConvertTo-ChatpadKnownJsonArrayShape $doc
    $doc
}

function ConvertTo-ChatpadKnownJsonArrayShape {
    param([object]$Object)
    if($null -eq $Object -or $Object -is [string] -or $Object -is [ValueType]){return}
    $arrayFields=@('artifacts','operations','dependency_ids','arguments','input_artifact_ids','prerequisite_result_ids','stop_condition_ids','expected_exit_codes','unresolved_deviation_ids')
    foreach($property in @($Object.PSObject.Properties)){
        if($arrayFields -contains $property.Name -and $null -ne $property.Value -and $property.Value -isnot [array]){
            $property.Value=[object[]]@($property.Value)
        }
        foreach($item in @($property.Value)){ConvertTo-ChatpadKnownJsonArrayShape $item}
    }
}

function Get-ChatpadRepoRoot {
    $root=@(&git rev-parse --show-toplevel)
    if($LASTEXITCODE-ne0-or$root.Count-ne1){throw 'Unable to resolve repository root.'}
    [string]$root[0]
}

function Get-ChatpadFileIdentity {
    param([Parameter(Mandatory)][string]$Path,[switch]$RejectReparsePoint)
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Required file missing: $Path"}
    $item=Get-Item -LiteralPath $Path -Force
    if($RejectReparsePoint-and($item.Attributes-band[IO.FileAttributes]::ReparsePoint)){throw "Reparse point is not allowed: $Path"}
    [pscustomobject]@{path=$Path.Replace('\','/');size=[long]$item.Length;sha256=(Get-FileHash $item.FullName -Algorithm SHA256).Hash;full_name=$item.FullName}
}

function Get-ChatpadPeIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $b=[IO.File]::ReadAllBytes((Resolve-Path $Path));$off=[BitConverter]::ToInt32($b,0x3c)
    if([Text.Encoding]::ASCII.GetString($b,$off,4)-ne"PE`0`0"){throw 'Invalid PE.'}
    $machine=[BitConverter]::ToUInt16($b,$off+4);$opt=$off+0x18;$sub=[BitConverter]::ToUInt16($b,$opt+68);$cert=[BitConverter]::ToUInt32($b,$opt+148)
    [pscustomobject]@{machine=$(if($machine-eq0x8664){'x64'}else{'unexpected'});subsystem=$(if($sub-eq1){'Native'}else{'unexpected'});signature=$(if($cert-eq0){'Unsigned'}else{'EmbeddedSignaturePresent'})}
}

function Test-ChatpadRepositoryIdentityObject {
    param($State)
    $fail=@()
    foreach($f in @('frozen_baseline_commit','prior_readiness_implementation_commit','prior_readiness_finalization_commit','current_readiness_implementation_commit','current_readiness_finalization_commit','current_head')){
        $v=[string](Get-ChatpadProperty $State $f '');try{Assert-ChatpadFullCommit $v $f}catch{$fail+=$_.Exception.Message}
    }
    if((Get-ChatpadProperty $State prior_readiness_implementation_commit '')-ne$script:PriorImplementationCommit-or(Get-ChatpadProperty $State prior_readiness_finalization_commit '')-ne$script:PriorFinalizationCommit){$fail+='Prior readiness identity mismatch.'}
    if((Get-ChatpadProperty $State frozen_baseline_commit '')-ne$script:FrozenBaselineCommit){$fail+='Frozen baseline mismatch.'}
    if((Get-ChatpadProperty $State current_head '')-ne(Get-ChatpadProperty $State current_readiness_finalization_commit '')){$fail+='Current HEAD is not approved finalization.'}
    if((Get-ChatpadProperty $State current_finalization_parent '')-ne(Get-ChatpadProperty $State current_readiness_implementation_commit '')){$fail+='Finalization is not direct child of implementation.'}
    if(-not[bool](Get-ChatpadProperty $State frozen_is_ancestor $false)-or-not[bool](Get-ChatpadProperty $State prior_chain_valid $false)-or-not[bool](Get-ChatpadProperty $State current_chain_valid $false)){$fail+='Commit ancestry invalid.'}
    if((Get-ChatpadProperty $State current_branch '')-ne(Get-ChatpadProperty $State approved_branch '')-or[bool](Get-ChatpadProperty $State detached_head $false)-or[bool](Get-ChatpadProperty $State alternate_repository_root $false)){$fail+='Repository branch/root invalid.'}
    if([int](Get-ChatpadProperty $State staged_count 0)-or[int](Get-ChatpadProperty $State unstaged_count 0)-or[int](Get-ChatpadProperty $State untracked_count 0)){$fail+='Repository is dirty.'}
    if((Get-ChatpadProperty $State accepted_manifest_size 0)-ne$script:AcceptedManifestSize-or(Get-ChatpadProperty $State accepted_manifest_sha256 '')-ne$script:AcceptedManifestSha256){$fail+='Accepted manifest identity mismatch.'}
    if((Get-ChatpadProperty $State debug_size 0)-ne$script:AcceptedDebugSysSize-or(Get-ChatpadProperty $State debug_sha256 '')-ne$script:AcceptedDebugSysSha256-or(Get-ChatpadProperty $State release_size 0)-ne$script:AcceptedReleaseSysSize-or(Get-ChatpadProperty $State release_sha256 '')-ne$script:AcceptedReleaseSysSha256){$fail+='Frozen binary identity mismatch.'}
    if((Get-ChatpadProperty $State debug_machine '')-ne'x64'-or(Get-ChatpadProperty $State release_machine '')-ne'x64'-or(Get-ChatpadProperty $State debug_subsystem '')-ne'Native'-or(Get-ChatpadProperty $State release_subsystem '')-ne'Native'-or(Get-ChatpadProperty $State debug_signature '')-ne'Unsigned'-or(Get-ChatpadProperty $State release_signature '')-ne'Unsigned'){$fail+='Frozen PE identity mismatch.'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult repository-identity FAIL REPOSITORY_IDENTITY_INVALID ($fail-join'; ') @('repository-or-binary-identity-wrong')}
    New-ChatpadRuntimeCheckResult repository-identity PASS REPOSITORY_IDENTITY_VALID -Data $State
}

function Test-ChatpadCurrentRepositoryIdentity {
    param(
        [Parameter(Mandatory)][string]$CurrentReadinessImplementationCommit,
        [Parameter(Mandatory)][string]$CurrentReadinessFinalizationCommit,
        [string]$ApprovedBranch=$script:ReadinessBranch,
        [string]$ApprovedRepositoryRoot='C:\Dev\chatpad-super-driver'
    )
    Assert-ChatpadFullCommit $CurrentReadinessImplementationCommit CurrentReadinessImplementationCommit
    Assert-ChatpadFullCommit $CurrentReadinessFinalizationCommit CurrentReadinessFinalizationCommit
    $root=Get-ChatpadRepoRoot;$head=(&git -C $root rev-parse HEAD).Trim();$branch=(&git -C $root branch --show-current).Trim()
    $status=@(&git -C $root status --porcelain=v2);$staged=@(&git -C $root diff --cached --name-only);$unstaged=@(&git -C $root diff --name-only);$untracked=@(&git -C $root ls-files --others --exclude-standard)
    $manifest=Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedManifestPath) -RejectReparsePoint
    $debug=Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedDebugSysPath) -RejectReparsePoint;$release=Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedReleaseSysPath) -RejectReparsePoint
    $dp=Get-ChatpadPeIdentity $debug.full_name;$rp=Get-ChatpadPeIdentity $release.full_name
    &git -C $root merge-base --is-ancestor $script:FrozenBaselineCommit $head;$frozen=$LASTEXITCODE-eq0
    &git -C $root merge-base --is-ancestor $script:PriorImplementationCommit $script:PriorFinalizationCommit;$prior=$LASTEXITCODE-eq0
    $parent=(&git -C $root rev-parse "$CurrentReadinessFinalizationCommit^").Trim()
    &git -C $root merge-base --is-ancestor $CurrentReadinessImplementationCommit $CurrentReadinessFinalizationCommit;$current=$LASTEXITCODE-eq0
    $state=[pscustomobject]@{
        frozen_baseline_commit=$script:FrozenBaselineCommit;prior_readiness_implementation_commit=$script:PriorImplementationCommit;prior_readiness_finalization_commit=$script:PriorFinalizationCommit
        current_readiness_implementation_commit=$CurrentReadinessImplementationCommit;current_readiness_finalization_commit=$CurrentReadinessFinalizationCommit;current_head=$head;current_branch=$branch;approved_branch=$ApprovedBranch
        current_finalization_parent=$parent;frozen_is_ancestor=$frozen;prior_chain_valid=$prior;current_chain_valid=$current;detached_head=[string]::IsNullOrWhiteSpace($branch)
        alternate_repository_root=-not([IO.Path]::GetFullPath($root).Equals([IO.Path]::GetFullPath($ApprovedRepositoryRoot),[StringComparison]::OrdinalIgnoreCase))
        staged_count=$staged.Count;unstaged_count=$unstaged.Count;untracked_count=$untracked.Count
        accepted_manifest_size=$manifest.size;accepted_manifest_sha256=$manifest.sha256;debug_size=$debug.size;debug_sha256=$debug.sha256;release_size=$release.size;release_sha256=$release.sha256
        debug_machine=$dp.machine;release_machine=$rp.machine;debug_subsystem=$dp.subsystem;release_subsystem=$rp.subsystem;debug_signature=$dp.signature;release_signature=$rp.signature
    }
    Test-ChatpadRepositoryIdentityObject $state
}

function Test-ChatpadTargetSelectionContract {
    param($Inventory,$Contract)
    $fail=@()
    if (-not (Test-ChatpadObject $Inventory)) { $fail += 'inventory-not-object' }
    if (-not (Test-ChatpadObject $Contract)) { $fail += 'contract-not-object' }
    if($fail.Count){return New-ChatpadRuntimeCheckResult target-selection FAIL TARGET_SELECTION_INVALID ($fail-join';') @('target-identity-ambiguous')}
    foreach($f in @('candidate_set_id','session_id','host_id','captured_utc','fresh_until_utc','source_classification','candidate_instance_ids','candidates')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Inventory $f))){$fail+="missing:$f"}}
    if((Get-ChatpadProperty $Inventory source_classification)-notin@('synthetic','live')){$fail+='invalid-source'}
    if([bool](Get-ChatpadProperty $Inventory claims_live $false)-and(Get-ChatpadProperty $Inventory source_classification '')-ne'live'){$fail+='synthetic-as-live'}
    try{if([datetime](Get-ChatpadProperty $Contract validation_time_utc '')-gt[datetime](Get-ChatpadProperty $Inventory fresh_until_utc '')-or[datetime](Get-ChatpadProperty $Inventory captured_utc '')-gt[datetime](Get-ChatpadProperty $Inventory fresh_until_utc '')){$fail+='stale'}}catch{$fail+='invalid-time'}
    $candidates=@(Get-ChatpadArray $Inventory candidates)
    if($candidates.Count -eq 1 -and $candidates[0] -eq '__CHATPAD_WRONG_TYPE__'){$fail+='candidates-not-array';$candidates=@()}
    if($candidates.Count-ne1){$fail+='candidate-count'}
    $ids=@($candidates|ForEach-Object{[string](Get-ChatpadProperty $_ instance_id '')})
    if(($ids-join'|')-ne((Get-ChatpadArray $Inventory candidate_instance_ids)-join'|')-or(Get-ChatpadProperty $Inventory candidate_set_id '')-ne(Get-ChatpadProperty $Contract candidate_set_id '')){$fail+='candidate-set-mismatch'}
    if($candidates.Count-eq1){$c=$candidates[0];if((Get-ChatpadProperty $c selection_basis)-ne'exact-contract'){$fail+='selection-not-exact'}
        foreach($f in @('instance_id','class_guid','class_name','parent_id','container_id','bus_topology','current_inf','current_service','current_provider','vendor_id','product_id')){if([string](Get-ChatpadProperty $c $f '')-ne[string](Get-ChatpadProperty $Contract $f '')){$fail+="mismatch:$f"}}
        if(((Get-ChatpadArray $c hardware_ids)-join'|')-ne((Get-ChatpadArray $Contract hardware_ids)-join'|')-or((Get-ChatpadArray $c compatible_ids)-join'|')-ne((Get-ChatpadArray $Contract compatible_ids)-join'|')){$fail+='id-set-mismatch'}
    }
    if($fail.Count){return New-ChatpadRuntimeCheckResult target-selection FAIL TARGET_SELECTION_INVALID ($fail-join';') @('target-identity-ambiguous')}
    New-ChatpadRuntimeCheckResult target-selection PASS TARGET_SELECTION_VALID -Data $candidates[0]
}

function Test-ChatpadDriverStateContract {
    param($State)
    $required=@('instance_id','candidate_set_id','hardware_ids','compatible_ids','class_guid','class_name','parent_id','container_id','bus_topology','current_inf','original_inf_name','provider','driver_version','driver_date','service','package_identity','recovery_source','recovery_source_size','recovery_source_sha256','driver_stack_identities','service_state','collected_utc','fresh_until_utc','validation_time_utc','host_id','session_id','field_provenance','source_classification','command_result_id')
    $fail=@()
    if (-not (Test-ChatpadObject $State)) { return New-ChatpadRuntimeCheckResult current-driver-state FAIL DRIVER_STATE_INVALID 'state-not-object' @('current-driver-unidentified') }
    foreach($f in $required){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State $f))){$fail+="missing:$f"}}
    if((Get-ChatpadProperty $State source_classification)-notin@('synthetic','live')){$fail+='invalid-source'}
    if([bool](Get-ChatpadProperty $State claims_live $false)-and(Get-ChatpadProperty $State source_classification '')-ne'live'){$fail+='synthetic-as-live'}
    try{if([datetime](Get-ChatpadProperty $State validation_time_utc '')-gt[datetime](Get-ChatpadProperty $State fresh_until_utc '')){$fail+='stale'}}catch{$fail+='invalid-time'}
    try{if([string](Get-ChatpadProperty $State recovery_source_sha256 '')-notmatch'^[A-Fa-f0-9]{64}$'-or[long](Get-ChatpadProperty $State recovery_source_size -1)-lt0){$fail+='invalid-recovery-identity'}}catch{$fail+='invalid-recovery-identity'}
    $provenance=Get-ChatpadProperty $State field_provenance
    if(-not(Test-ChatpadObject $provenance)){$fail+='missing-provenance'}else{foreach($f in $required){if($f-ne'field_provenance'-and$provenance.PSObject.Properties.Name-notcontains$f){$fail+="missing-provenance:$f";break}}}
    if($fail.Count){return New-ChatpadRuntimeCheckResult current-driver-state FAIL DRIVER_STATE_INVALID ($fail-join';') @('current-driver-unidentified')}
    New-ChatpadRuntimeCheckResult current-driver-state PASS DRIVER_STATE_VALID -Data $State
}

function Test-ChatpadRollbackContract {
    param($State)
    $fail=@()
    if (-not (Test-ChatpadObject $State)) {
        return New-ChatpadRuntimeCheckResult rollback-readiness FAIL ROLLBACK_CONTRACT_INVALID 'state-not-object' @('rollback-source-unavailable','rollback-cannot-be-guaranteed')
    }
    $driver=Test-ChatpadDriverStateContract (Get-ChatpadProperty $State pre_test_snapshot)
    if($driver.result-ne'PASS'){$fail+='snapshot-invalid'}
    foreach($f in @('target_instance_id','previous_package_identity','previous_provider','previous_version','previous_service','recovery_source_path','recovery_source_size','recovery_source_sha256','test_package_identity','evidence_directory','session_id','host_id','snapshot_session_id','source_classification','emergency_recovery')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State $f))){$fail+="missing:$f"}}
    if($null -eq (Get-ChatpadProperty $State rollback_operations $null)){$fail+='missing:rollback_operations'}
    if((Get-ChatpadProperty $State source_classification)-notin@('synthetic','live')){$fail+='invalid-source'}
    if((Get-ChatpadProperty $State snapshot_session_id '')-ne(Get-ChatpadProperty $State session_id '')-or(Get-ChatpadProperty (Get-ChatpadProperty $State pre_test_snapshot) session_id '')-ne(Get-ChatpadProperty $State session_id '')){$fail+='cross-session'}
    try{if([string](Get-ChatpadProperty $State recovery_source_sha256 '')-notmatch'^[A-Fa-f0-9]{64}$'-or[long](Get-ChatpadProperty $State recovery_source_size -1)-lt0){$fail+='recovery-unverifiable'}}catch{$fail+='recovery-unverifiable'}
    if((Get-ChatpadProperty $State source_classification '')-eq'synthetic'){if(-not[bool](Get-ChatpadProperty $State recovery_source_verified $false)){$fail+='recovery-unverified'}}
    elseif((Get-ChatpadProperty $State source_classification '')-eq'live'){if(-not(Test-Path -LiteralPath ([string](Get-ChatpadProperty $State recovery_source_path '')) -PathType Leaf)){$fail+='recovery-source-missing'}}
    $ops=@(Get-ChatpadArray $State rollback_operations)
    if($ops.Count -eq 1 -and $ops[0] -eq '__CHATPAD_WRONG_TYPE__'){$fail+='rollback-operations-not-array';$ops=@()}
    $targetInstanceId = [string](Get-ChatpadProperty $State target_instance_id '')
    $restore=@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq'restore'-and(Get-ChatpadProperty $_ target_scope '')-eq'exact-device'-and(Get-ChatpadProperty $_ target_instance_id '')-eq$targetInstanceId-and(Get-ChatpadProperty $_ status '')-eq'planned'});$verify=@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq'verify'-and(Get-ChatpadProperty $_ target_instance_id '')-eq$targetInstanceId-and(Get-ChatpadProperty $_ status '')-eq'planned'})
    if($ops.Count-eq0-or$restore.Count-ne1){$fail+='exact-restoration-missing'}
    if($verify.Count-ne1){$fail+='post-rollback-verification-missing'}
    if(@($ops|Where-Object{(Get-ChatpadProperty $_ status '')-eq'blocked'}).Count){$fail+='blocked-operation-cannot-satisfy'}
    if((Get-ChatpadProperty $State source_classification '')-eq'live'){return New-ChatpadRuntimeCheckResult rollback-readiness BLOCKED BLOCKED_NOT_IMPLEMENTED 'Exact-instance restoration is not implemented.' @('rollback-cannot-be-guaranteed') -Data $State}
    if($fail.Count){return New-ChatpadRuntimeCheckResult rollback-readiness FAIL ROLLBACK_CONTRACT_INVALID ($fail-join';') @('rollback-source-unavailable','rollback-cannot-be-guaranteed')}
    New-ChatpadRuntimeCheckResult rollback-readiness PASS ROLLBACK_CONTRACT_VALID -Data $State
}

function Read-ChatpadInfModel {
    param([Parameter(Mandatory)][string]$InfPath)
    if(-not(Test-Path $InfPath -PathType Leaf)){throw "INF missing: $InfPath"}
    $bytes=[IO.File]::ReadAllBytes($InfPath);$utf8=[Text.UTF8Encoding]::new($false,$true)
    try{$content=$utf8.GetString($bytes)}catch{throw 'INF encoding is not valid UTF-8.'}
    if($content.Contains([char]0)){throw 'INF contains NUL.'}
    $sections=[ordered]@{};$duplicates=@();$current=''
    foreach($line in($content-split"`r?`n")){$trim=($line-replace';.*$','').Trim();if(-not$trim){continue};if($trim-match'^\[([^\]]+)\]$'){$current=$Matches[1];if($sections.Contains($current)){$duplicates+=$current}else{$sections[$current]=[System.Collections.Generic.List[string]]::new()};continue};if(-not$current){throw 'INF content appears before a section.'};$sections[$current].Add($trim)}
    $strings=@{};if($sections.Contains('Strings')){foreach($line in $sections['Strings']){if($line-match'^([^=]+)=(.*)$'){$strings[$Matches[1].Trim()]=($Matches[2].Trim().Trim('\"'))}}}
    [pscustomobject]@{content=$content;sections=$sections;duplicates=$duplicates;strings=$strings}
}

function Expand-ChatpadInfValue {
    param([string]$Value,$Model,[ref]$Unresolved)
    [regex]::Replace($Value,'%([^%]+)%',{param($m)if($Model.strings.ContainsKey($m.Groups[1].Value)){$Model.strings[$m.Groups[1].Value]}else{$Unresolved.Value=$true;$m.Value}})
}

function Get-ChatpadInfAssignment {
    param($Model,[string]$Section,[string]$Key)
    if(-not$Model.sections.Contains($Section)){return $null}
    foreach($line in $Model.sections[$Section]){if($line-match('^'+[regex]::Escape($Key)+'\s*=\s*(.+)$')){return $Matches[1].Trim()}}
    $null
}

function Test-ChatpadPackageContract {
    param($Package)
    if (-not (Test-ChatpadObject $Package)) { return New-ChatpadRuntimeCheckResult package-validation FAIL PACKAGE_SEMANTICS_INVALID 'package-not-object' @('package-validation-failed','unexpected-setupapi-match') }
    $fail=@();$root=[string](Get-ChatpadProperty $Package package_root '');$inf=[string](Get-ChatpadProperty $Package inf_path '')
    if(-not(Test-ChatpadNonEmpty $root)-or-not(Test-ChatpadNonEmpty $inf)){$fail+='package-containment'}
    elseif(-not[IO.Path]::IsPathRooted($root)-or-not(Test-ChatpadPathContained $root $inf)){$fail+='package-containment'}
    if(Test-ChatpadNonEmpty $inf){try{$model=Read-ChatpadInfModel $inf}catch{$fail+=$_.Exception.Message;$model=$null}}else{$model=$null}
    if($model){
        if($model.duplicates.Count){$fail+='duplicate-sections'}
        foreach($s in @('Version','Manufacturer','DestinationDirs','Strings')){if(-not$model.sections.Contains($s)){$fail+="missing-section:$s"}}
        $unresolved=$false;$provider=Expand-ChatpadInfValue (Get-ChatpadInfAssignment $model Version Provider) $model ([ref]$unresolved)
        $catalogValue=Get-ChatpadInfAssignment $model Version 'CatalogFile.NTamd64'
        if(-not$catalogValue){$catalogValue=Get-ChatpadInfAssignment $model Version CatalogFile}
        $catalog=Expand-ChatpadInfValue $catalogValue $model ([ref]$unresolved)
        if((Get-ChatpadInfAssignment $model Version Signature)-ne'"$WINDOWS NT$"'){$fail+='signature-invalid'}
        if($provider-ne(Get-ChatpadProperty $Package expected_provider '')){$fail+='provider-mismatch'}
        if(-not(Get-ChatpadInfAssignment $model Version DriverVer)){$fail+='driverver-missing'}
        if($catalog-ne(Get-ChatpadProperty $Package expected_catalog_file '')-or-not(Test-Path (Join-Path $root $catalog) -PathType Leaf)){$fail+='catalog-relationship-invalid'}
        $manufacturer=@($model.sections['Manufacturer']);$modelSection=$null
    foreach($line in $manufacturer){if($line-match'^[^=]+=\s*([^,]+),\s*NTamd64$'){$modelSection=$Matches[1]+'.NTamd64'}}
        if(-not$modelSection-or-not$model.sections.Contains($modelSection)){$fail+='effective-model-section-missing'}
        $installBase=$null
    if($modelSection){foreach($line in $model.sections[$modelSection]){if($line-match'^[^=]+=\s*([^,]+),\s*(.+)$'){$hw=Expand-ChatpadInfValue $Matches[2].Trim() $model ([ref]$unresolved);if($hw-eq(Get-ChatpadProperty $Package expected_hardware_id '')){$installBase=$Matches[1].Trim()};if($hw-match'[*?]|^USB\\Class_'){$fail+='broad-hardware-match'}}}}
        if(-not$installBase){$fail+='model-install-link-missing'}
        $installSection=if($model.sections.Contains($installBase+'.NT')){$installBase+'.NT'}elseif($model.sections.Contains($installBase)){$installBase}else{$null}
        if(-not$installSection-or$installSection-eq$installBase){$fail+='decorated-install-section-missing'}
        $copyRef=if($installSection){Get-ChatpadInfAssignment $model $installSection CopyFiles}else{$null}
        if(-not$copyRef-or-not$model.sections.Contains($copyRef)){$fail+='copyfiles-link-missing'}
        $copied=@();if($copyRef-and$model.sections.Contains($copyRef)){$copied=@($model.sections[$copyRef]|ForEach-Object{($_-split',')[0].Trim()})}
        $services=$installBase+'.NT.Services';$addService=Get-ChatpadInfAssignment $model $services AddService;$serviceSection=$null
        if($addService){$parts=$addService-split',';if($parts.Count-ge3){$serviceSection=$parts[2].Trim()}}
        if(-not$serviceSection-or-not$model.sections.Contains($serviceSection)){$fail+='service-link-missing'}
        $serviceBinary=if($serviceSection){Get-ChatpadInfAssignment $model $serviceSection ServiceBinary}else{$null}
        $serviceFile=if($serviceBinary){[IO.Path]::GetFileName(($serviceBinary-replace'^%[^%]+%\\',''))}else{$null}
        if($serviceFile-ne(Get-ChatpadProperty $Package expected_service_binary '')){$fail+='service-binary-mismatch'}
        if($copied-notcontains$serviceFile){$fail+='service-binary-not-copied'}
        $wdf=$installBase+'.NT.Wdf';$kmdf=Get-ChatpadInfAssignment $model $wdf KmdfService;$kmdfSection=$null;if($kmdf){$kp=$kmdf-split',';if($kp.Count-ge2){$kmdfSection=$kp[1].Trim()}}
        if(-not$kmdfSection-or-not$model.sections.Contains($kmdfSection)-or-not(Get-ChatpadInfAssignment $model $kmdfSection KmdfLibraryVersion)){$fail+='kmdf-link-missing'}
        if($unresolved){$fail+='unresolved-string'}
    foreach($f in $copied){if([IO.Path]::IsPathRooted($f)-or$f-match'(^|[\\/])\.\.([\\/]|$)'){$fail+='copy-path-invalid'}}
    }
    if((Test-ChatpadNonEmpty $root) -and (Test-Path -LiteralPath $root -PathType Container)){
        $actual=@(Get-ChildItem $root -File -Recurse|ForEach-Object{$_.FullName.Substring($root.Length).TrimStart('\','/')-replace'\\','/'})
        $allowed=Get-ChatpadArray $Package allowed_files
        foreach($f in $actual){if($allowed-notcontains$f-or$f-match'(?i)\.(exe|dll|pfx|p12|pem|key|pvk|snk|cer|crt)$'){$fail+="unauthorized-file:$f"}}
        $sys=Join-Path $root ([string](Get-ChatpadProperty $Package sys_relative_path ''))
        if(-not(Test-Path $sys -PathType Leaf)-or(Get-FileHash $sys -Algorithm SHA256).Hash-ne(Get-ChatpadProperty $Package expected_sys_sha256 '')){$fail+='sys-identity-invalid'}
    } else {
        $fail+='package-root-missing'
    }
    if($fail.Count){return New-ChatpadRuntimeCheckResult package-validation FAIL PACKAGE_SEMANTICS_INVALID ($fail-join';') @('package-validation-failed','unexpected-setupapi-match')}
    New-ChatpadRuntimeCheckResult package-validation PASS PACKAGE_SEMANTICS_VALID -Data $Package
}

function Test-ChatpadSigningContract {
    param($State)
    $required=@('method','package_identity','sys_identity','cat_identity','certificate_thumbprint','certificate_subject','certificate_issuer','signature_thumbprint','signature_subject','signature_issuer','trust_status','private_key_present','key_usage','eku','valid_from_utc','valid_to_utc','validation_time_utc','fresh_until_utc','timestamping_policy','sys_signature_identity','cat_signature_identity','test_signing_state','secure_boot_state','hvci_state','code_integrity_state','credential_scope','session_id','host_id','source_classification')
    $fail=@()
    if (-not (Test-ChatpadObject $State)) { return New-ChatpadRuntimeCheckResult signing-readiness FAIL SIGNING_STATE_INVALID 'state-not-object' @('signing-identity-wrong','windows-rejects-signature') }
    foreach($f in $required){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State $f))){$fail+="missing:$f"}}
    if((Get-ChatpadProperty $State source_classification '')-notin@('synthetic','live')){$fail+='invalid-source'}
    if((Get-ChatpadProperty $State trust_status '')-ne'trusted'-or-not[bool](Get-ChatpadProperty $State private_key_present $false)-or(Get-ChatpadArray $State eku)-notcontains'Code Signing'-or(Get-ChatpadArray $State key_usage)-notcontains'digitalSignature'){$fail+='certificate-capability-invalid'}
    if((Get-ChatpadProperty $State certificate_thumbprint '')-ne(Get-ChatpadProperty $State signature_thumbprint '')-or(Get-ChatpadProperty $State certificate_subject '')-ne(Get-ChatpadProperty $State signature_subject '')-or(Get-ChatpadProperty $State certificate_issuer '')-ne(Get-ChatpadProperty $State signature_issuer '')){$fail+='certificate-signature-identity-mismatch'}
    if((Get-ChatpadProperty $State sys_signature_identity '')-ne(Get-ChatpadProperty $State sys_identity '')-or(Get-ChatpadProperty $State cat_signature_identity '')-ne(Get-ChatpadProperty $State package_identity '')){$fail+='signature-package-identity-mismatch'}
    try{if([datetime](Get-ChatpadProperty $State validation_time_utc '')-lt[datetime](Get-ChatpadProperty $State valid_from_utc '')-or[datetime](Get-ChatpadProperty $State validation_time_utc '')-gt[datetime](Get-ChatpadProperty $State valid_to_utc '')-or[datetime](Get-ChatpadProperty $State validation_time_utc '')-gt[datetime](Get-ChatpadProperty $State fresh_until_utc '')){$fail+='stale-or-invalid-time'}}catch{$fail+='invalid-time'}
    if((Get-ChatpadProperty $State timestamping_policy '')-ne'required-before-runtime'){$fail+='timestamp-policy-invalid'}
    if((Get-ChatpadProperty $State code_integrity_state '')-ne'compatible'-or(Get-ChatpadProperty $State hvci_state '')-notin@('disabled','enabled-compatible')-or(Get-ChatpadProperty $State secure_boot_state '')-notin@('disabled','enabled-compatible')-or(Get-ChatpadProperty $State test_signing_state '')-ne'planned-enabled'){$fail+='host-security-incompatible'}
    if((Get-ChatpadProperty $State method '')-eq'LocalTestCertificate'-and(Get-ChatpadProperty $State credential_scope '')-ne'local-test'){$fail+='credential-scope-invalid'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult signing-readiness FAIL SIGNING_STATE_INVALID ($fail-join';') @('signing-identity-wrong','windows-rejects-signature')}
    New-ChatpadRuntimeCheckResult signing-readiness PASS SIGNING_STATE_VALID -Data $State
}

function Test-ChatpadHostStateContract {
    param($State)
    $required=@('os_edition','os_version','os_build','architecture','is_administrator','powershell_version','system_time_utc','timezone','secure_boot','test_signing','code_integrity','hvci','device_guard','boot_configuration_id','boot_evidence_id','wdk_tool_identities','debug_tool_identities','required_command_identities','evidence_root_writable','evidence_root_contained','host_id','session_id','capture_timestamp_utc','fresh_until_utc','validation_time_utc','source_classification')
    $fail=@()
    if (-not (Test-ChatpadObject $State)) { return New-ChatpadRuntimeCheckResult host-preflight FAIL HOST_STATE_INVALID 'state-not-object' @('prerequisite-changed-after-approval','runtime-evidence-write-failed') }
    foreach($f in $required){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State $f))){$fail+="missing:$f"}}
    if(-not[bool](Get-ChatpadProperty $State is_administrator $false)){$fail+='administrator-required'}
    if((Get-ChatpadProperty $State architecture '')-ne'x64'){$fail+='architecture-unsupported'}
    if((Get-ChatpadProperty $State source_classification '')-notin@('synthetic','live')){$fail+='invalid-source'}
    if((Get-ChatpadProperty $State secure_boot '')-notin@('disabled','enabled-compatible')-or(Get-ChatpadProperty $State test_signing '')-ne'planned-enabled'-or(Get-ChatpadProperty $State code_integrity '')-ne'compatible'-or(Get-ChatpadProperty $State hvci '')-notin@('disabled','enabled-compatible')-or(Get-ChatpadProperty $State device_guard '')-notin@('disabled','enabled-compatible')){$fail+='security-state-unknown-or-incompatible'}
    try{if([datetime](Get-ChatpadProperty $State validation_time_utc '')-gt[datetime](Get-ChatpadProperty $State fresh_until_utc '')){$fail+='stale'}}catch{$fail+='invalid-time'}
    if(-not[bool](Get-ChatpadProperty $State evidence_root_writable $false)-or-not[bool](Get-ChatpadProperty $State evidence_root_contained $false)){$fail+='evidence-root-not-ready'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult host-preflight FAIL HOST_STATE_INVALID ($fail-join';') @('prerequisite-changed-after-approval','runtime-evidence-write-failed')}
    New-ChatpadRuntimeCheckResult host-preflight PASS HOST_STATE_VALID -Data $State
}

function Test-ChatpadEvidenceDirectoryContract {
    param($State)
    $fail=@()
    if (-not (Test-ChatpadObject $State)) { return New-ChatpadRuntimeCheckResult evidence-directory FAIL EVIDENCE_DIRECTORY_INVALID 'state-not-object' @('runtime-evidence-write-failed') }
    foreach($f in @('approved_root','evidence_directory','session_id','host_id','source_classification','session_marker_id','created_utc','fresh_until_utc','validation_time_utc')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State $f))){$fail+="missing:$f"}}
    $source=[string](Get-ChatpadProperty $State source_classification '')
    $root=[string](Get-ChatpadProperty $State approved_root '')
    $path=[string](Get-ChatpadProperty $State evidence_directory '')
    $session=[string](Get-ChatpadProperty $State session_id '')
    if($source-notin@('synthetic','live')){$fail+='invalid-source'}
    if(-not[IO.Path]::IsPathRooted($root)-or-not[IO.Path]::IsPathRooted($path)-or-not(Test-ChatpadPathContained $root $path)){$fail+='path-not-contained'}
    try{if([IO.Path]::GetFileName([IO.Path]::GetFullPath($path))-ne$session){$fail+='session-path-unlinked'}}catch{$fail+='session-path-unlinked'}
    foreach($flag in @('stale_session','session_id_reused','has_reparse_point','has_symlink_or_junction','inside_repository','lock_owned_by_other')){if([bool](Get-ChatpadProperty $State $flag $false)){$fail+=$flag}}
    if([bool](Get-ChatpadProperty $State is_unc_path $false)-and-not[bool](Get-ChatpadProperty $State unc_allowed $false)){$fail+='unc-not-allowed'}
    if([bool](Get-ChatpadProperty $State exists_before_session $false)-and-not[bool](Get-ChatpadProperty $State existing_empty_approved $false)){$fail+='existing-directory-not-approved'}
    try{if([datetime](Get-ChatpadProperty $State validation_time_utc '')-gt[datetime](Get-ChatpadProperty $State fresh_until_utc '')){$fail+='stale'}}catch{$fail+='invalid-time'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult evidence-directory FAIL EVIDENCE_DIRECTORY_INVALID ($fail-join';') @('runtime-evidence-write-failed')}
    New-ChatpadRuntimeCheckResult evidence-directory PASS EVIDENCE_DIRECTORY_VALID -Data $State
}

function Test-ChatpadWppPlanContract {
    param($Plan)
    $fail=@()
    if (-not (Test-ChatpadObject $Plan)) { return New-ChatpadRuntimeCheckResult wpp-plan FAIL WPP_PLAN_INVALID 'plan-not-object' @('trace-provider-wrong','runtime-evidence-write-failed') }
    foreach($f in @('session_id','host_id','source_classification','provider_guid','session_name','output_path','approved_root','start_timestamp_plan','stop_timestamp_plan','prerequisite_identities','operations')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Plan $f))){$fail+="missing:$f"}}
    $provider=[string](Get-ChatpadProperty $Plan provider_guid '')
    $source=[string](Get-ChatpadProperty $Plan source_classification '')
    $root=[string](Get-ChatpadProperty $Plan approved_root '')
    $output=[string](Get-ChatpadProperty $Plan output_path '')
    if($provider-ne$script:AcceptedProviderGuid){$fail+='provider-invalid'}
    if($source-notin@('synthetic','live')){$fail+='invalid-source'}
    if(-not(Test-ChatpadPathContained $root $output)-or[bool](Get-ChatpadProperty $Plan output_exists $false)-or[bool](Get-ChatpadProperty $Plan stale_output $false)){$fail+='output-path-invalid'}
    $ops=@(Get-ChatpadProperty $Plan operations @());foreach($type in @('trace-start','trace-stop','preserve','hash')){if(@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq$type}).Count-ne1){$fail+="missing-operation:$type"}}
    $session=[string](Get-ChatpadProperty $Plan session_id '');$planHostId=[string](Get-ChatpadProperty $Plan host_id '')
    if(@($ops|Where-Object{(Get-ChatpadProperty $_ session_id '')-ne$session-or(Get-ChatpadProperty $_ host_id '')-ne$planHostId}).Count){$fail+='operation-linkage-invalid'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult wpp-plan FAIL WPP_PLAN_INVALID ($fail-join';') @('trace-provider-wrong','runtime-evidence-write-failed')}
    New-ChatpadRuntimeCheckResult wpp-plan PASS WPP_PLAN_VALID -Data $Plan
}

function Test-ChatpadEventLogPlanContract {
    param($Plan)
    $fail=@()
    if (-not (Test-ChatpadObject $Plan)) { return New-ChatpadRuntimeCheckResult event-log-plan FAIL EVENT_LOG_PLAN_INVALID 'plan-not-object' @('runtime-evidence-write-failed','unexpected-code-integrity-error') }
    foreach($f in @('session_id','host_id','source_classification','capture_phase','window_start_utc','window_end_utc','required_channels','channel_availability','approved_root','output_paths','operations')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Plan $f))){$fail+="missing:$f"}}
    $source=[string](Get-ChatpadProperty $Plan source_classification '');$phase=[string](Get-ChatpadProperty $Plan capture_phase '')
    if($source-notin@('synthetic','live')-or$phase-notin@('baseline','post-test')){$fail+='classification-invalid'}
    $channels=@(Get-ChatpadProperty $Plan required_channels @());$availability=Get-ChatpadProperty $Plan channel_availability
    foreach($channel in @('System','Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration')){if($channels-notcontains$channel){$fail+="missing-channel:$channel"};if(-not[bool](Get-ChatpadProperty $availability $channel $false)){$fail+="channel-unavailable:$channel"}}
    try{if([datetime](Get-ChatpadProperty $Plan window_start_utc '')-ge[datetime](Get-ChatpadProperty $Plan window_end_utc '')){$fail+='window-invalid'}}catch{$fail+='window-invalid'}
    $paths=@(Get-ChatpadProperty $Plan output_paths @());if(@($paths|Sort-Object -Unique).Count-ne$paths.Count){$fail+='duplicate-output'}
    $root=[string](Get-ChatpadProperty $Plan approved_root '');foreach($p in $paths){if(-not(Test-ChatpadPathContained $root $p)){$fail+='output-not-contained'}}
    $ops=@(Get-ChatpadProperty $Plan operations @());if($ops.Count-ne$paths.Count-or@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-ne'event-export'-or(Get-ChatpadProperty $_ status '')-ne'blocked'}).Count){$fail+='export-operations-invalid'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult event-log-plan FAIL EVENT_LOG_PLAN_INVALID ($fail-join';') @('runtime-evidence-write-failed','unexpected-code-integrity-error')}
    New-ChatpadRuntimeCheckResult event-log-plan PASS EVENT_LOG_PLAN_VALID -Data $Plan
}

function Test-ChatpadInstallPlanContract {
    param($Plan)
    $fail=@()
    if (-not (Test-ChatpadObject $Plan)) { return New-ChatpadRuntimeCheckResult install-plan BLOCKED BLOCKED_NOT_IMPLEMENTED 'plan-not-object' @('command-differs-from-approved-plan','wrong-device-binds') -Data ([pscustomobject]@{framework_validation='FAIL';live_installation_readiness='BLOCKED';blocker='BLOCKED_NOT_IMPLEMENTED';executable_exact_binding_operations=0;executable_exact_restoration_operations=0;broad_approved_install_operations=0;broad_approved_rollback_operations=0;downstream_live_gates='BLOCKED'}) }
    foreach($f in @('repository_identity','accepted_baseline_identity','package_validation','signing_readiness','host_preflight','target_selection','current_driver_capture','rollback_readiness','evidence_directory')){if((Get-ChatpadProperty $Plan $f)-ne'PASS'){$fail+="prerequisite:$f"}}
    if((Get-ChatpadProperty $Plan source_classification '')-ne'live'){$fail+='live-prerequisites-required'}
    $ops=@(Get-ChatpadProperty $Plan operations @());if($ops.Count-eq0){$fail+='operation-list-empty'}
    foreach($op in $ops){$c=Test-ChatpadOperationPlanContract $op;if($c.result-ne'PASS'){$fail+="invalid-operation:$([string](Get-ChatpadProperty $op operation_id '<missing>'))"}}
    $bind=@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq'bind'-and(Get-ChatpadProperty $_ target_scope '')-eq'exact-device'-and(Get-ChatpadProperty $_ approved_as_target_specific $false)-eq$true-and(Get-ChatpadProperty $_ status '')-eq'planned'})
    $verify=@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq'verify'-and(Get-ChatpadProperty $_ target_scope '')-eq'exact-device'-and(Get-ChatpadProperty $_ status '')-eq'planned'})
    $restore=@($ops|Where-Object{(Get-ChatpadProperty $_ operation_type '')-eq'restore'-and(Get-ChatpadProperty $_ target_scope '')-eq'exact-device'-and(Get-ChatpadProperty $_ status '')-eq'planned'})
    if($bind.Count-ne1){$fail+='executable-exact-binding-missing'};if($verify.Count-ne1){$fail+='verification-missing'};if($restore.Count-ne1){$fail+='rollback-missing'}
    if(@($ops|Where-Object{(Get-ChatpadProperty $_ status '')-eq'blocked'}).Count){$fail+='blocked-operation-present'}
    $targets=@($ops|Where-Object{(Get-ChatpadProperty $_ target_scope '')-eq'exact-device'}|ForEach-Object{Get-ChatpadProperty $_ target_instance_id ''}|Sort-Object -Unique);if($targets.Count-ne1){$fail+='target-mismatch'}
    $sessions=@($ops|ForEach-Object{Get-ChatpadProperty $_ session_id ''}|Sort-Object -Unique);if($sessions.Count-ne1){$fail+='session-mismatch'}
    if($fail.Count-eq0){$fail+='exact-instance-binding-implementation-not-authorized'}
    New-ChatpadRuntimeCheckResult install-plan BLOCKED BLOCKED_NOT_IMPLEMENTED ($fail-join';') @('command-differs-from-approved-plan','wrong-device-binds') -Data ([pscustomobject]@{framework_validation='PASS';live_installation_readiness='BLOCKED';blocker='BLOCKED_NOT_IMPLEMENTED';executable_exact_binding_operations=0;executable_exact_restoration_operations=0;broad_approved_install_operations=0;broad_approved_rollback_operations=0;downstream_live_gates='BLOCKED'})
}

function Test-ChatpadPostTestReconciliationContract {
    param($State)
    $fail=@()
    if (-not (Test-ChatpadObject $State)) { return New-ChatpadRuntimeCheckResult post-test-reconciliation FAIL RECONCILIATION_INVALID 'state-not-object' @('rollback-cannot-be-guaranteed','prerequisite-changed-after-approval') }
    foreach($f in @('session_id','host_id','source_classification','expected_mode','final_classification','host_baseline','host_final','target_baseline','target_final','previous_driver','final_driver','service_baseline','service_final','package_baseline','package_final','boot_security_baseline','boot_security_final','trace_state','executed_operations','rollback_operations','final_state_evidence_id','residual_packages','residual_services','unresolved_deviations')){if($null-eq$State.PSObject.Properties[$f]){$fail+="missing:$f"}}
    if($fail.Count){return New-ChatpadRuntimeCheckResult post-test-reconciliation FAIL RECONCILIATION_INVALID ($fail-join';') @('rollback-cannot-be-guaranteed','prerequisite-changed-after-approval')}
    if((Get-ChatpadProperty $State source_classification '')-notin@('synthetic','live')){$fail+='invalid-source'}
    if((Get-ChatpadProperty $State final_classification '')-eq'fully-restored-baseline'){
        foreach($pair in @(@('host_baseline','host_final'),@('target_baseline','target_final'),@('previous_driver','final_driver'),@('service_baseline','service_final'),@('package_baseline','package_final'),@('boot_security_baseline','boot_security_final'))){if(((Get-ChatpadProperty $State $pair[0])|ConvertTo-Json -Compress -Depth 10)-ne((Get-ChatpadProperty $State $pair[1])|ConvertTo-Json -Compress -Depth 10)){$fail+="not-restored:$($pair[0])"}}
        if((Get-ChatpadProperty $State trace_state '')-ne'stopped'-or@(Get-ChatpadArray $State residual_packages).Count-or@(Get-ChatpadArray $State residual_services).Count-or@(Get-ChatpadArray $State unresolved_deviations).Count){$fail+='residual-state'}
        $mutations=@((Get-ChatpadArray $State executed_operations)|Where-Object{(Get-ChatpadProperty $_ status '')-eq'executed'});$rollbacks=@((Get-ChatpadArray $State rollback_operations)|Where-Object{(Get-ChatpadProperty $_ status '')-eq'executed'})
        if($mutations.Count-and$rollbacks.Count-lt$mutations.Count){$fail+='rollback-not-executed'}
        if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $State final_state_evidence_id ''))){$fail+='final-evidence-missing'}
    } elseif((Get-ChatpadProperty $State final_classification '')-eq'approved-test-state'){if((Get-ChatpadProperty $State expected_mode '')-ne'test-state'-or@(Get-ChatpadArray $State unresolved_deviations).Count){$fail+='test-state-invalid'}}
    else{$fail+='non-passable-classification'}
    if($fail.Count){return New-ChatpadRuntimeCheckResult post-test-reconciliation FAIL RECONCILIATION_INVALID ($fail-join';') @('rollback-cannot-be-guaranteed','prerequisite-changed-after-approval','unrelated-device-changed','driver-service-fails-unexpectedly')}
    New-ChatpadRuntimeCheckResult post-test-reconciliation PASS RECONCILIATION_VALID -Data $State
}

function Test-ChatpadEvidenceDocumentContract {
    param($Document)
    $fail=@()
    if (-not (Test-ChatpadObject $Document)) {
        return New-ChatpadRuntimeCheckResult runtime-evidence FAIL EVIDENCE_SEMANTICS_INVALID 'document-not-object' @('runtime-evidence-write-failed')
    }
    if((Get-ChatpadProperty $Document schema_version '')-ne'chatpad-runtime-evidence-schema-v3'){$fail+='schema-version'}
    $session=Get-ChatpadProperty $Document session
    if (-not (Test-ChatpadObject $session)) { $fail += 'session-not-object'; $session = [pscustomobject]@{} }
    foreach($f in @('session_id','host_id','evidence_classification','repository_identity')){if(-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $session $f))){$fail+="session:$f"}}
    $sessionId=[string](Get-ChatpadProperty $session session_id '')
    $hostId=[string](Get-ChatpadProperty $session host_id '')
    $evidenceClassification=[string](Get-ChatpadProperty $session evidence_classification '')
    if($null -eq (Get-ChatpadProperty $Document artifacts $null)){$fail+='artifacts-missing'}
    $artifacts=@(Get-ChatpadArray $Document artifacts)
    if($artifacts.Count -eq 1 -and $artifacts[0] -eq '__CHATPAD_WRONG_TYPE__'){$fail+='artifacts-not-array';$artifacts=@()}
    $allArtifactIds=@($artifacts|ForEach-Object{[string](Get-ChatpadProperty $_ id '')})
    $artifactIds=@()
    foreach($a in $artifacts){
        if (-not (Test-ChatpadObject $a)) { $fail+='artifact-not-object'; continue }
        $artifactId=[string](Get-ChatpadProperty $a id '')
        if(-not(Test-ChatpadNonEmpty $artifactId)){$fail+='artifact-id-missing'}
        elseif($artifactIds-contains$artifactId){$fail+='duplicate-artifact-id'}else{$artifactIds+=$artifactId}
        if((Get-ChatpadProperty $a session_id '')-ne$sessionId-or(Get-ChatpadProperty $a host_id '')-ne$hostId){$fail+='artifact-session-host'}
        if($evidenceClassification-eq'live'-and(Get-ChatpadProperty $a source_classification '')-ne'live'){$fail+='synthetic-in-live'}
        foreach($d in (Get-ChatpadArray $a dependency_ids)){if($allArtifactIds-notcontains[string]$d){$fail+='unresolved-artifact-dependency'}}
    }
    if($null -eq (Get-ChatpadProperty $Document operations $null)){$fail+='operations-missing'}
    $operations=@(Get-ChatpadArray $Document operations)
    if($operations.Count -eq 1 -and $operations[0] -eq '__CHATPAD_WRONG_TYPE__'){$fail+='operations-not-array';$operations=@()}
    $opIds=@()
    foreach($o in $operations){
        if (-not (Test-ChatpadObject $o)) { $fail+='operation-not-object'; continue }
        $operationId=[string](Get-ChatpadProperty $o operation_id '')
        if(-not(Test-ChatpadNonEmpty $operationId)){$fail+='operation-id-missing'}
        elseif($opIds-contains$operationId){$fail+='duplicate-operation-id'}else{$opIds+=$operationId}
        if((Get-ChatpadProperty $o session_id '')-ne$sessionId-or(Get-ChatpadProperty $o host_id '')-ne$hostId){$fail+='operation-session-host'}
        if($evidenceClassification-eq'live'-and(Get-ChatpadProperty $o source_classification '')-ne'live'){$fail+='synthetic-operation-in-live'}
        $operationContract = Test-ChatpadOperationPlanContract $o
        if($operationContract.result -ne 'PASS'){$fail+="operation-lifecycle:$($operationContract.reason)"}
    }
    foreach($o in $operations){
        if (-not (Test-ChatpadObject $o)) { continue }
        if((Get-ChatpadProperty $o status '')-eq'rolled_back'){
            $rollbackId=[string](Get-ChatpadProperty $o rollback_operation_id '')
            $rollbackOperation=@($operations|Where-Object{(Get-ChatpadProperty $_ operation_id '')-eq$rollbackId-and(Get-ChatpadProperty $_ status '')-eq'executed'})
            if($rollbackOperation.Count-ne1){$fail+='rollback-without-executed-operation'}
            elseif((Get-ChatpadProperty $rollbackOperation[0] session_id '')-ne(Get-ChatpadProperty $o session_id '')-or(Get-ChatpadProperty $rollbackOperation[0] host_id '')-ne(Get-ChatpadProperty $o host_id '')){$fail+='rollback-session-host-mismatch'}
            elseif((Test-ChatpadOperationPlanContract $rollbackOperation[0]).result -ne 'PASS'){$fail+='rollback-without-execution-result'}
        }
        foreach($artifactRef in (Get-ChatpadArray $o input_artifact_ids)){if($artifactIds -notcontains [string]$artifactRef){$fail+='unresolved-operation-artifact-reference'}}
        foreach($prereqRef in (Get-ChatpadArray $o prerequisite_result_ids)){if(($artifactIds -notcontains [string]$prereqRef) -and ($opIds -notcontains [string]$prereqRef)){$fail+='unresolved-operation-prerequisite'}}
    }
    if((Get-ChatpadProperty $Document result '')-eq'restored'){if(@($operations|Where-Object{(Get-ChatpadProperty $_ status '')-in@('planned','blocked','failed')}).Count-or-not(Test-ChatpadNonEmpty (Get-ChatpadProperty $Document final_reconciliation_evidence_id))){$fail+='invalid-restored-transition'}}
    if($fail.Count){return New-ChatpadRuntimeCheckResult runtime-evidence FAIL EVIDENCE_SEMANTICS_INVALID ($fail-join';') @('runtime-evidence-write-failed')}
    New-ChatpadRuntimeCheckResult runtime-evidence PASS EVIDENCE_SEMANTICS_VALID -Data $Document
}

function Get-ChatpadRuntimeObservationRequirement {
    param([Parameter(Mandatory)][string]$ConditionId)
    $requirements = @{
        'unrelated-device-changed' = [pscustomobject]@{
            evidence_type = 'device-inventory-diff'
            payload_fields = @('condition_id','session_id','host_id','baseline_inventory_id','post_inventory_id','difference_analysis_id')
            timestamp_pairs = @()
        }
        'driver-service-fails-unexpectedly' = [pscustomobject]@{
            evidence_type = 'driver-service-transition'
            payload_fields = @('condition_id','session_id','host_id','expected_service_identity','observed_service_state','expected_transition','observed_transition','result_or_event_id')
            timestamp_pairs = @()
        }
        'unexpected-code-integrity-error' = [pscustomobject]@{
            evidence_type = 'code-integrity-event'
            payload_fields = @('condition_id','session_id','host_id','source_channel','event_id','event_timestamp','package_or_binary_correlation','session_window_start_utc','session_window_end_utc')
            timestamp_pairs = @([pscustomobject]@{start='session_window_start_utc';end='session_window_end_utc'})
        }
        'unexpected-setupapi-match' = [pscustomobject]@{
            evidence_type = 'setupapi-match-analysis'
            payload_fields = @('condition_id','session_id','host_id','setupapi_source','target_instance_id','expected_package_or_inf','observed_match','session_window_start_utc','session_window_end_utc')
            timestamp_pairs = @([pscustomobject]@{start='session_window_start_utc';end='session_window_end_utc'})
        }
        'input-behavior-unstable' = [pscustomobject]@{
            evidence_type = 'input-behavior-observation'
            payload_fields = @('condition_id','session_id','host_id','observation_method','observation_window_start_utc','observation_window_end_utc','expected_input_behavior','observed_instability','target_or_session_linkage')
            timestamp_pairs = @([pscustomobject]@{start='observation_window_start_utc';end='observation_window_end_utc'})
        }
    }
    if($requirements.ContainsKey($ConditionId)){return $requirements[$ConditionId]}
    return $null
}

function Test-ChatpadRuntimeObservationRecordShape {
    param($Observation)
    $fail = [Collections.Generic.List[string]]::new()
    if(-not(Test-ChatpadObject $Observation)){
        return New-ChatpadRuntimeCheckResult runtime-observation-record FAIL OBSERVATION_RECORD_SHAPE_INVALID 'observation-not-object' @('prerequisite-changed-after-approval') -Data ([pscustomobject]@{record_structure_valid=$false;provenance_valid=$false})
    }
    $conditionId = [string](Get-ChatpadProperty $Observation stop_condition_id '')
    $requirement = Get-ChatpadRuntimeObservationRequirement $conditionId
    if($null-eq$requirement){$fail.Add('condition-id-unknown')}
    foreach($field in @('observation_id','stop_condition_id','session_id','host_id','producer_identity','observer_script_path','capture_started_utc','capture_completed_utc','validation_time_utc','evidence_artifact_id','evidence_artifact_relative_path','evidence_artifact_sha256','evidence_type','applicable_stop_condition_id')){
        if(-not(Test-ChatpadStringField $Observation $field)){$fail.Add("missing-or-invalid:$field")}
    }
    $source = [string](Get-ChatpadProperty $Observation source_classification '')
    if($source-notin@('live','synthetic','sample','planned','unknown')){$fail.Add('source-classification-invalid')}
    $mode = [string](Get-ChatpadProperty $Observation observation_mode '')
    if($mode-notin@('runtime-evaluation','contract-only-fixture-validation','synthetic-negative-testing')){$fail.Add('observation-mode-invalid')}
    $evidenceAvailableProperty = $Observation.PSObject.Properties['evidence_available']
    $triggeredProperty = $Observation.PSObject.Properties['triggered']
    $syntheticProperty = $Observation.PSObject.Properties['synthetic']
    if($null-eq$evidenceAvailableProperty-or$evidenceAvailableProperty.Value-isnot[bool]){$fail.Add('evidence-available-not-boolean')}
    if($null-eq$triggeredProperty-or$triggeredProperty.Value-isnot[bool]){$fail.Add('triggered-not-boolean')}
    if($null-eq$syntheticProperty-or$syntheticProperty.Value-isnot[bool]){$fail.Add('synthetic-marker-not-boolean')}
    elseif(($source-eq'live'-and$syntheticProperty.Value)-or($source-ne'live'-and-not$syntheticProperty.Value)){$fail.Add('synthetic-marker-source-mismatch')}
    if(($source-eq'live'-and$mode-ne'runtime-evaluation')-or($source-ne'live'-and$mode-eq'runtime-evaluation')){$fail.Add('observation-mode-source-mismatch')}
    if((Get-ChatpadProperty $Observation producer_identity '')-ne'ChatpadRuntimeObservation/v1'){$fail.Add('producer-identity-invalid')}
    if((Get-ChatpadProperty $Observation observer_script_path '')-ne'tools/Test-ChatpadRuntimeObservation.ps1'){$fail.Add('observer-script-identity-invalid')}
    if((Get-ChatpadProperty $Observation applicable_stop_condition_id '')-ne$conditionId){$fail.Add('applicable-stop-condition-mismatch')}

    $start=$null;$completion=$null;$validation=$null
    try{$start=[datetimeoffset]([string](Get-ChatpadProperty $Observation capture_started_utc ''))}catch{$fail.Add('capture-start-invalid')}
    try{$completion=[datetimeoffset]([string](Get-ChatpadProperty $Observation capture_completed_utc ''))}catch{$fail.Add('capture-completion-invalid')}
    try{$validation=[datetimeoffset]([string](Get-ChatpadProperty $Observation validation_time_utc ''))}catch{$fail.Add('validation-time-invalid')}
    if($null-ne$start-and$null-ne$completion-and$completion-lt$start){$fail.Add('capture-completion-before-start')}
    $maximumAgeSeconds=$null
    $maximumAgeValue=Get-ChatpadProperty $Observation maximum_age_seconds $null
    if($maximumAgeValue-is[bool]-or$maximumAgeValue-is[array]){$fail.Add('maximum-age-invalid')}
    else{try{$maximumAgeSeconds=[int]$maximumAgeValue;if($maximumAgeSeconds-le0){throw 'invalid'}}catch{$fail.Add('maximum-age-invalid')}}
    if($null-ne$completion-and$null-ne$validation-and$null-ne$maximumAgeSeconds){
        if(($validation-$completion).TotalSeconds-gt$maximumAgeSeconds){$fail.Add('evidence-stale')}
        if(($completion-$validation).TotalSeconds-gt300){$fail.Add('evidence-future-dated')}
    }

    $artifact = Get-ChatpadProperty $Observation evidence_artifact $null
    if(-not(Test-ChatpadObject $artifact)){$fail.Add('evidence-artifact-not-object')}
    else{
        foreach($field in @('artifact_id','relative_path','sha256','evidence_type','session_id','host_id','condition_id','collection_result')){
            if(-not(Test-ChatpadStringField $artifact $field)){$fail.Add("artifact-missing-or-invalid:$field")}
        }
        if((Get-ChatpadProperty $artifact artifact_id '')-ne(Get-ChatpadProperty $Observation evidence_artifact_id '')){$fail.Add('artifact-id-mismatch')}
        if((Get-ChatpadProperty $artifact relative_path '')-ne(Get-ChatpadProperty $Observation evidence_artifact_relative_path '')){$fail.Add('artifact-path-mismatch')}
        if((Get-ChatpadProperty $artifact sha256 '')-ne(Get-ChatpadProperty $Observation evidence_artifact_sha256 '')){$fail.Add('artifact-hash-mismatch')}
        if((Get-ChatpadProperty $artifact evidence_type '')-ne(Get-ChatpadProperty $Observation evidence_type '')){$fail.Add('artifact-evidence-type-mismatch')}
        if((Get-ChatpadProperty $artifact session_id '')-ne(Get-ChatpadProperty $Observation session_id '')){$fail.Add('artifact-session-mismatch')}
        if((Get-ChatpadProperty $artifact host_id '')-ne(Get-ChatpadProperty $Observation host_id '')){$fail.Add('artifact-host-mismatch')}
        if((Get-ChatpadProperty $artifact condition_id '')-ne$conditionId){$fail.Add('artifact-condition-mismatch')}
        if((Get-ChatpadProperty $artifact collection_result '')-ne'collected'){$fail.Add('artifact-not-collected')}
        $sizeValue=Get-ChatpadProperty $artifact byte_size $null
        if($null-eq$sizeValue-or$sizeValue-is[bool]-or$sizeValue-is[array]){$fail.Add('artifact-size-invalid')}
        else{try{if([long]$sizeValue-lt0){throw 'invalid'}}catch{$fail.Add('artifact-size-invalid')}}
    }
    $relativePath=[string](Get-ChatpadProperty $Observation evidence_artifact_relative_path '')
    $normalizedPath=$relativePath.Replace('\','/')
    if($normalizedPath-ne$relativePath-or[IO.Path]::IsPathRooted($normalizedPath)-or@($normalizedPath-split'/')-contains'..'-or$normalizedPath-match'[\*\?\[]'-or-not$normalizedPath.StartsWith('artifacts/runtime-evidence/',[StringComparison]::OrdinalIgnoreCase)){$fail.Add('artifact-path-invalid')}
    if([string](Get-ChatpadProperty $Observation evidence_artifact_sha256 '')-notmatch'^[A-Fa-f0-9]{64}$'){$fail.Add('artifact-sha256-invalid')}
    if($null-ne$requirement-and(Get-ChatpadProperty $Observation evidence_type '')-ne$requirement.evidence_type){$fail.Add('evidence-type-condition-mismatch')}

    $payload=Get-ChatpadProperty $Observation condition_evidence $null
    if(-not(Test-ChatpadObject $payload)){$fail.Add('condition-evidence-not-object')}
    elseif($null-ne$requirement){
        foreach($field in $requirement.payload_fields){
            if(-not(Test-ChatpadStringField $payload $field)){$fail.Add("condition-evidence-missing:$field")}
        }
        if((Get-ChatpadProperty $payload condition_id '')-ne$conditionId){$fail.Add('condition-evidence-condition-mismatch')}
        if((Get-ChatpadProperty $payload session_id '')-ne(Get-ChatpadProperty $Observation session_id '')){$fail.Add('condition-evidence-session-mismatch')}
        if((Get-ChatpadProperty $payload host_id '')-ne(Get-ChatpadProperty $Observation host_id '')){$fail.Add('condition-evidence-host-mismatch')}
        foreach($pair in $requirement.timestamp_pairs){
            $payloadStart=$null;$payloadEnd=$null
            try{$payloadStart=[datetimeoffset]([string](Get-ChatpadProperty $payload $pair.start ''))}catch{$fail.Add("condition-evidence-time-invalid:$($pair.start)")}
            try{$payloadEnd=[datetimeoffset]([string](Get-ChatpadProperty $payload $pair.end ''))}catch{$fail.Add("condition-evidence-time-invalid:$($pair.end)")}
            if($null-ne$payloadStart-and$null-ne$payloadEnd-and$payloadEnd-lt$payloadStart){$fail.Add("condition-evidence-time-order:$($pair.start)")}
        }
    }
    $data=[pscustomobject][ordered]@{
        record_structure_valid=($fail.Count-eq0)
        provenance_valid=($fail.Count-eq0-and$source-eq'live')
        live_evidence_available=($fail.Count-eq0-and$source-eq'live'-and[bool](Get-ChatpadProperty $Observation evidence_available $false))
        runtime_condition_evaluated=$false
        runtime_condition_triggered=$false
        continuation_allowed=$false
    }
    if($fail.Count){return New-ChatpadRuntimeCheckResult runtime-observation-record FAIL OBSERVATION_RECORD_SHAPE_INVALID ($fail-join';') @($(if($conditionId-in$script:KnownStopConditionIds){$conditionId}else{'prerequisite-changed-after-approval'})) -Data $data}
    New-ChatpadRuntimeCheckResult runtime-observation-record PASS OBSERVATION_RECORD_SHAPE_VALID -Data $data
}

function Test-ChatpadRuntimeObservationContract {
    param($Observation)
    $id=[string](Get-ChatpadProperty $Observation stop_condition_id '')
    if($id-notin@('unrelated-device-changed','driver-service-fails-unexpectedly','unexpected-code-integrity-error','unexpected-setupapi-match','input-behavior-unstable')){return New-ChatpadRuntimeCheckResult runtime-observer FAIL OBSERVER_CONDITION_INVALID 'Unknown runtime observation condition.' @('prerequisite-changed-after-approval') -Data ([pscustomobject]@{record_structure_valid=$false;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})}
    if((Get-ChatpadProperty $Observation evidence_available $false)-ne$true){return New-ChatpadRuntimeCheckResult runtime-observer BLOCKED RUNTIME_EVIDENCE_NOT_AVAILABLE 'Runtime-only condition has not been evaluated.' @($id) -Data ([pscustomobject]@{record_structure_valid=$false;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})}
    $shape=Test-ChatpadRuntimeObservationRecordShape $Observation
    if($shape.result-ne'PASS'){return New-ChatpadRuntimeCheckResult runtime-observer FAIL RUNTIME_OBSERVATION_PROVENANCE_INVALID $shape.reason @($id) -Data ([pscustomobject]@{record_structure_valid=$false;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})}
    if((Get-ChatpadProperty $Observation source_classification '')-ne'live'-or(Get-ChatpadProperty $Observation observation_mode '')-ne'runtime-evaluation'-or(Get-ChatpadProperty $Observation synthetic $true)-ne$false){return New-ChatpadRuntimeCheckResult runtime-observer BLOCKED RUNTIME_EVIDENCE_NOT_AVAILABLE 'Only authentic live runtime evidence may satisfy a runtime observation.' @($id) -Data ([pscustomobject]@{record_structure_valid=$true;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})}
    $root=[IO.Path]::GetFullPath((Get-ChatpadRepoRoot))
    $artifactPath=[IO.Path]::GetFullPath((Join-Path $root ([string](Get-ChatpadProperty $Observation evidence_artifact_relative_path ''))))
    $artifact=Get-ChatpadProperty $Observation evidence_artifact $null
    if(-not$artifactPath.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $artifactPath -PathType Leaf)){
        return New-ChatpadRuntimeCheckResult runtime-observer FAIL RUNTIME_OBSERVATION_PROVENANCE_INVALID 'Live evidence artifact is missing or outside the repository evidence root.' @($id) -Data ([pscustomobject]@{record_structure_valid=$true;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})
    }
    $artifactItem=Get-Item -LiteralPath $artifactPath
    if($artifactItem.Length-ne[long](Get-ChatpadProperty $artifact byte_size -1)-or(Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash-cne[string](Get-ChatpadProperty $artifact sha256 '')){
        return New-ChatpadRuntimeCheckResult runtime-observer FAIL RUNTIME_OBSERVATION_PROVENANCE_INVALID 'Live evidence artifact size or SHA-256 does not match the observation record.' @($id) -Data ([pscustomobject]@{record_structure_valid=$true;provenance_valid=$false;live_evidence_available=$false;runtime_condition_evaluated=$false;runtime_condition_triggered=$false;continuation_allowed=$false})
    }
    if([bool](Get-ChatpadProperty $Observation triggered $false)){return New-ChatpadRuntimeCheckResult runtime-observer FAIL RUNTIME_STOP_CONDITION_TRIGGERED 'Runtime stop condition triggered.' @($id) -Data ([pscustomobject]@{record_structure_valid=$true;provenance_valid=$true;live_evidence_available=$true;runtime_condition_evaluated=$true;runtime_condition_triggered=$true;continuation_allowed=$false})}
    New-ChatpadRuntimeCheckResult runtime-observer PASS RUNTIME_OBSERVATION_CLEAR -Data ([pscustomobject]@{record_structure_valid=$true;provenance_valid=$true;live_evidence_available=$true;runtime_condition_evaluated=$true;runtime_condition_triggered=$false;continuation_allowed=$true})
}

function Test-ChatpadStopConditionRegisterContract {
    param($Register)
    if (-not (Test-ChatpadObject $Register)) { return New-ChatpadRuntimeCheckResult stop-condition-linkage FAIL STOP_LINKAGE_INVALID 'register-not-object' @('prerequisite-changed-after-approval') }
    $fail=[Collections.Generic.List[string]]::new()
    $malformedLinkageCount=0
    $unknownIdCount=0
    $unlinkedCount=0
    $conditions=@(Get-ChatpadArray $Register stop_conditions)
    $ids=@($conditions|ForEach-Object{[string](Get-ChatpadProperty $_ id '')})
    $uniqueIds=@($ids|Where-Object{$_}|Sort-Object -Unique)
    if($conditions.Count-ne20){$fail.Add("condition-count:$($conditions.Count)")}
    if($uniqueIds.Count-ne20){$fail.Add("unique-condition-count:$($uniqueIds.Count)")}
    foreach($id in $ids){
        if([string]::IsNullOrWhiteSpace($id)){$fail.Add('condition-id-empty');$unknownIdCount++}
        elseif($script:KnownStopConditionIds-notcontains$id){$fail.Add("unknown-condition-id:$id");$unknownIdCount++}
    }
    foreach($id in $script:KnownStopConditionIds){
        if($ids-notcontains$id){$fail.Add("missing-condition-id:$id")}
    }
    $executable=Get-ChatpadProperty $Register executable_linkage ([pscustomobject]@{})
    $observers=Get-ChatpadProperty $Register runtime_observer_linkage ([pscustomobject]@{})
    $operatorOnlyProperty=$Register.PSObject.Properties['operator_only_conditions']
    $operatorOnly=if($null-ne$operatorOnlyProperty-and$operatorOnlyProperty.Value-is[array]){@($operatorOnlyProperty.Value)}else{@()}
    if($null-eq$operatorOnlyProperty-or$operatorOnlyProperty.Value-isnot[array]){$fail.Add('operator-only-not-array');$malformedLinkageCount++}
    if(-not(Test-ChatpadObject $executable)){$fail.Add('executable-linkage-not-object');$malformedLinkageCount++}
    if(-not(Test-ChatpadObject $observers)){$fail.Add('runtime-observer-linkage-not-object');$malformedLinkageCount++}
    $allowedTopLevel=@('schema_version','stop_conditions','runtime_observer_linkage','operator_only_conditions','executable_linkage')
    foreach($propertyName in @($Register.PSObject.Properties|ForEach-Object Name)){
        if($propertyName-notin$allowedTopLevel){$fail.Add("unknown-linkage-classification:$propertyName")}
    }
    foreach($c in $conditions){
        if (-not (Test-ChatpadObject $c)) { $fail.Add('condition-not-object'); continue }
        foreach($f in @('id','detection_method','immediate_action','evidence_to_preserve','rollback_required','reboot_permitted','continuation_authority')){if($null-eq$c.PSObject.Properties[$f]){$fail.Add("missing:$([string](Get-ChatpadProperty $c id '<missing>')):$f")}}
        $classCount=0
        $conditionId=[string](Get-ChatpadProperty $c id '')
        if((Test-ChatpadObject $executable)-and$null-ne$executable.PSObject.Properties[$conditionId]){$classCount++}
        if((Test-ChatpadObject $observers)-and$null-ne$observers.PSObject.Properties[$conditionId]){$classCount++}
        if($operatorOnly-contains$conditionId){$classCount++}
        if($classCount-ne1){$fail.Add("classification:$conditionId");if($classCount-eq0){$unlinkedCount++}}
    }
    $executableNames=if(Test-ChatpadObject $executable){@($executable.PSObject.Properties|ForEach-Object Name)}else{@()}
    $observerNames=if(Test-ChatpadObject $observers){@($observers.PSObject.Properties|ForEach-Object Name)}else{@()}
    foreach($name in @($executableNames)+@($observerNames)+$operatorOnly){
        if($ids-notcontains$name){$fail.Add("unknown-link:$name");$unknownIdCount++}
    }
    $root=[IO.Path]::GetFullPath((Get-ChatpadRepoRoot))
    foreach($group in @(
        [pscustomobject]@{name='executable';value=$executable;names=$executableNames},
        [pscustomobject]@{name='runtime-observer';value=$observers;names=$observerNames}
    )){
        foreach($name in $group.names){
            $property=$group.value.PSObject.Properties[$name]
            if($null-eq$property){$fail.Add("missing-linkage:$($group.name):$name");$unlinkedCount++;continue}
            $paths=$property.Value
            if($paths-isnot[array]){$fail.Add("linkage-not-array:$($group.name):$name");$malformedLinkageCount++;continue}
            if($paths.Count-eq0){$fail.Add("linkage-empty:$($group.name):$name");$malformedLinkageCount++;continue}
            $normalizedPaths=[Collections.Generic.List[string]]::new()
            foreach($path in $paths){
                if($path-is[array]){$fail.Add("linkage-nested-array:$($group.name):$name");$malformedLinkageCount++;continue}
                if($path-isnot[string]){$fail.Add("linkage-non-string:$($group.name):$name");$malformedLinkageCount++;continue}
                if([string]::IsNullOrWhiteSpace($path)){$fail.Add("linkage-empty-string:$($group.name):$name");$malformedLinkageCount++;continue}
                $normalized=$path.Replace('\','/')
                if($normalized-ne$path){$fail.Add("linkage-path-not-normalized:$($group.name):$name");$malformedLinkageCount++}
                if($normalized-match'[\*\?\[]'){$fail.Add("linkage-wildcard:$($group.name):$name");$malformedLinkageCount++;continue}
                if([IO.Path]::IsPathRooted($normalized)-or@($normalized-split'/')-contains'..'){$fail.Add("linkage-traversal:$($group.name):$name");$malformedLinkageCount++;continue}
                if([IO.Path]::GetExtension($normalized)-ne'.ps1'){$fail.Add("linkage-type-not-approved:$($group.name):$name");$malformedLinkageCount++;continue}
                $full=[IO.Path]::GetFullPath((Join-Path $root $normalized))
                if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$fail.Add("linkage-not-contained:$($group.name):$name");$malformedLinkageCount++;continue}
                if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$fail.Add("linkage-path-missing:$($group.name):$name");$malformedLinkageCount++;continue}
                $normalizedPaths.Add($normalized.ToLowerInvariant())
            }
            if(@($normalizedPaths|Group-Object|Where-Object Count -gt 1).Count){$fail.Add("linkage-duplicate-normalized:$($group.name):$name");$malformedLinkageCount++}
            if($group.name-eq'runtime-observer'){
                if($paths.Count-ne1-or$paths[0]-isnot[string]-or$paths[0]-ne'tools/Test-ChatpadRuntimeObservation.ps1'){$fail.Add("observer-path-invalid:$name");$malformedLinkageCount++}
            }
        }
    }
    $runtimeObserverIds=@('unrelated-device-changed','driver-service-fails-unexpectedly','unexpected-code-integrity-error','unexpected-setupapi-match','input-behavior-unstable')
    foreach($id in $runtimeObserverIds){
        if($observerNames-notcontains$id){$fail.Add("observer-missing:$id");$unlinkedCount++}
        if($executableNames-contains$id-or$operatorOnly-contains$id){$fail.Add("runtime-observer-misclassified:$id")}
    }
    $data=[pscustomobject][ordered]@{
        stop_condition_count=$conditions.Count
        unique_stop_condition_count=$uniqueIds.Count
        runtime_observer_linkage_count=@($observerNames|Where-Object{$runtimeObserverIds-contains$_}).Count
        unlinked_count=$unlinkedCount
        unknown_id_count=$unknownIdCount
        malformed_linkage_count=$malformedLinkageCount
    }
    if($fail.Count){return New-ChatpadRuntimeCheckResult stop-condition-linkage FAIL STOP_LINKAGE_INVALID ($fail-join';') @('prerequisite-changed-after-approval') -Data $data}
    New-ChatpadRuntimeCheckResult stop-condition-linkage PASS STOP_LINKAGE_VALID -Data $data
}

function Get-ChatpadRuntimeConstants {
    [pscustomobject]@{readiness_branch=$script:ReadinessBranch;frozen_baseline_commit=$script:FrozenBaselineCommit;prior_implementation_commit=$script:PriorImplementationCommit;prior_finalization_commit=$script:PriorFinalizationCommit;accepted_provider_guid=$script:AcceptedProviderGuid;stop_condition_ids=@($script:KnownStopConditionIds)}
}

Export-ModuleMember -Function *-Chatpad*
