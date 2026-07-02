Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PlanSchema = 'chatpad-exact-instance-operation-plan-v1'
$script:SnapshotSchema = 'chatpad-exact-instance-restoration-snapshot-v1'
$script:EvidenceSchema = 'chatpad-exact-instance-operation-evidence-v1'
$script:PendingAuditBlocker = 'BLOCKED_PENDING_INDEPENDENT_AUDIT'
$script:AllowedModes = @('Plan','Apply','Restore','Verify')
$script:AllowedActions = @('query-exact-device','verify-package','bind-exact-device','verify-exact-device','restore-exact-device','restart-exact-device')
$script:AllowedTransitions = [ordered]@{
    PLAN_CREATED=@('PLAN_VALIDATED','BLOCKED')
    PLAN_VALIDATED=@('PREFLIGHT_STARTED','BLOCKED')
    PREFLIGHT_STARTED=@('TARGET_OPENED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    TARGET_OPENED=@('TARGET_IDENTITY_VERIFIED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    TARGET_IDENTITY_VERIFIED=@('SNAPSHOT_CAPTURED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    SNAPSHOT_CAPTURED=@('PACKAGE_IDENTITY_VERIFIED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    PACKAGE_IDENTITY_VERIFIED=@('READY_TO_BIND','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    READY_TO_BIND=@('BIND_STARTED','BLOCKED')
    BIND_STARTED=@('BIND_API_SUCCEEDED','BIND_FAILED_AFTER_MUTATION','RESTORE_REQUIRED')
    BIND_API_SUCCEEDED=@('POST_BIND_VERIFY_STARTED','RESTORE_REQUIRED')
    POST_BIND_VERIFY_STARTED=@('BIND_VERIFIED','RESTORE_REQUIRED')
    BIND_VERIFIED=@('RESTART_REQUIRED','REBOOT_REQUIRED','COMPLETED','RESTORE_STARTED')
    RESTART_REQUIRED=@('COMPLETED','RESTORE_STARTED','BLOCKED')
    REBOOT_REQUIRED=@('BLOCKED','RESTORE_STARTED')
    BIND_FAILED_BEFORE_MUTATION=@('BLOCKED')
    BIND_FAILED_AFTER_MUTATION=@('RESTORE_REQUIRED','BLOCKED')
    RESTORE_REQUIRED=@('RESTORE_STARTED','BLOCKED')
    RESTORE_STARTED=@('RESTORE_API_SUCCEEDED','RESTORE_FAILED')
    RESTORE_API_SUCCEEDED=@('POST_RESTORE_VERIFY_STARTED','RESTORE_FAILED')
    POST_RESTORE_VERIFY_STARTED=@('RESTORED','RESTORE_FAILED')
    RESTORED=@('COMPLETED')
    RESTORE_FAILED=@('BLOCKED')
    BLOCKED=@()
    COMPLETED=@()
}

function Copy-ChatpadExactObject {
    param([Parameter(Mandatory)][object]$InputObject)
    [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($InputObject,40))
}

function Get-ChatpadExactSha256Text {
    param([Parameter(Mandatory)][string]$Text)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        ($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join ''
    } finally {
        $sha.Dispose()
    }
}

function ConvertTo-ChatpadExactCanonicalJson {
    param([Parameter(Mandatory)][object]$InputObject)
    ConvertTo-ChatpadExactCanonicalJsonNode $InputObject
}

function ConvertTo-ChatpadExactJsonString {
    param([AllowNull()][string]$Value)
    if($null-eq$Value){return 'null'}
    $builder=[Text.StringBuilder]::new()
    [void]$builder.Append('"')
    foreach($character in $Value.ToCharArray()){
        $code=[int]$character
        switch($character){
            '"' {[void]$builder.Append('\"');continue}
            '\' {[void]$builder.Append('\\');continue}
            "`b" {[void]$builder.Append('\b');continue}
            "`f" {[void]$builder.Append('\f');continue}
            "`n" {[void]$builder.Append('\n');continue}
            "`r" {[void]$builder.Append('\r');continue}
            "`t" {[void]$builder.Append('\t');continue}
        }
        if($code-lt32){[void]$builder.Append(('\u{0:x4}'-f$code))}
        else{[void]$builder.Append($character)}
    }
    [void]$builder.Append('"')
    $builder.ToString()
}

function ConvertTo-ChatpadExactCanonicalJsonNode {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return 'null'}
    if($Value-is[string]-or$Value-is[char]-or$Value-is[guid]-or$Value-is[datetime]-or$Value-is[datetimeoffset]){
        if($Value-is[datetime]-or$Value-is[datetimeoffset]){return ConvertTo-ChatpadExactJsonString $Value.ToString('o',[Globalization.CultureInfo]::InvariantCulture)}
        return ConvertTo-ChatpadExactJsonString ([string]$Value)
    }
    if($Value-is[bool]){if($Value){return 'true'}else{return 'false'}}
    if($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int32]-or$Value-is[uint32]-or$Value-is[int64]-or$Value-is[uint64]-or$Value-is[decimal]){
        return ([IFormattable]$Value).ToString($null,[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value-is[single]-or$Value-is[double]){
        if([double]::IsNaN([double]$Value)-or[double]::IsInfinity([double]$Value)){throw [ArgumentException]::new('NONFINITE_JSON_NUMBER')}
        return ([IFormattable]$Value).ToString('R',[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value-is[Collections.IDictionary]){
        $parts=[Collections.Generic.List[string]]::new()
        foreach($key in @($Value.Keys|ForEach-Object{[string]$_}|Sort-Object)){
            $parts.Add((ConvertTo-ChatpadExactJsonString $key)+':'+(ConvertTo-ChatpadExactCanonicalJsonNode $Value[$key]))
        }
        return '{'+($parts-join',')+'}'
    }
    if($Value-is[Collections.IEnumerable]){
        $parts=[Collections.Generic.List[string]]::new()
        foreach($item in $Value){$parts.Add((ConvertTo-ChatpadExactCanonicalJsonNode $item))}
        return '['+($parts-join',')+']'
    }
    $objectParts=[Collections.Generic.List[string]]::new()
    foreach($property in @($Value.PSObject.Properties|Where-Object{$_.MemberType-in@('NoteProperty','Property','AliasProperty','ScriptProperty')}|Sort-Object Name)){
        $objectParts.Add((ConvertTo-ChatpadExactJsonString $property.Name)+':'+(ConvertTo-ChatpadExactCanonicalJsonNode $property.Value))
    }
    '{'+($objectParts-join',')+'}'
}

function Get-ChatpadExactObjectHash {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [string[]]$ExcludedProperties=@()
    )
    $copy=Copy-ChatpadExactObject $InputObject
    foreach($name in $ExcludedProperties){
        if($null-ne$copy.PSObject.Properties[$name]){$copy.PSObject.Properties.Remove($name)}
    }
    Get-ChatpadExactSha256Text (ConvertTo-ChatpadExactCanonicalJson $copy)
}

function Get-ChatpadExactProperty {
    param([object]$Object,[Parameter(Mandatory)][string]$Name,[object]$Default=$null)
    if($null-eq$Object -or $Object -is [array]){return $Default}
    if($Object-is[Collections.IDictionary]){
        if($Object.Contains($Name)){return $Object[$Name]}
        return $Default
    }
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property){return $Default}
    $property.Value
}

function Test-ChatpadExactGuid {
    param([object]$Value)
    $parsed=[guid]::Empty
    -not[string]::IsNullOrWhiteSpace([string]$Value) -and [guid]::TryParse([string]$Value,[ref]$parsed)
}

function ConvertTo-ChatpadCanonicalInstanceId {
    param([Parameter(Mandatory)][object]$InstanceId)
    if($InstanceId -isnot [string]){throw [ArgumentException]::new('INSTANCE_ID_TYPE_INVALID')}
    $value=[string]$InstanceId
    if($value-ne$value.Trim()){throw [ArgumentException]::new('INSTANCE_ID_WHITESPACE_INVALID')}
    if([string]::IsNullOrWhiteSpace($value)-or$value.Length-gt512){throw [ArgumentException]::new('INSTANCE_ID_LENGTH_INVALID')}
    if($value.IndexOfAny([char[]]"*?[]")-ge0-or$value-match'[/`"''\x00-\x1f]'){throw [ArgumentException]::new('INSTANCE_ID_PARTIAL_OR_WILDCARD')}
    $segments=$value.Split('\')
    if($segments.Count-lt3-or@($segments|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count){throw [ArgumentException]::new('INSTANCE_ID_INCOMPLETE')}
    $value.ToUpperInvariant()
}

function Test-ChatpadCanonicalInstanceIdEqual {
    param([Parameter(Mandatory)][object]$Left,[Parameter(Mandatory)][object]$Right)
    try {
        (ConvertTo-ChatpadCanonicalInstanceId $Left) -ceq (ConvertTo-ChatpadCanonicalInstanceId $Right)
    } catch {
        $false
    }
}

function Assert-ChatpadExactSafePath {
    param([Parameter(Mandatory)][object]$Path,[switch]$MustExist)
    if($Path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Path)){throw [ArgumentException]::new('PATH_INVALID')}
    $value=[string]$Path
    if($value.IndexOfAny([char[]]"*?")-ge0-or$value-match'[\x00-\x1f]'){throw [ArgumentException]::new('PATH_WILDCARD_OR_CONTROL_INVALID')}
    if(-not[IO.Path]::IsPathRooted($value)){throw [ArgumentException]::new('PATH_NOT_ABSOLUTE')}
    if($value-match'(^|[\\/])\.\.?([\\/]|$)'){throw [ArgumentException]::new('PATH_TRAVERSAL_INVALID')}
    $colonCount=@($value.ToCharArray()|Where-Object{$_-eq':'}).Count
    if($colonCount-ne1-or$value.IndexOf(':')-ne1){throw [ArgumentException]::new('PATH_ALTERNATE_DATA_STREAM_INVALID')}
    $full=[IO.Path]::GetFullPath($value)
    if($MustExist-and-not(Test-Path -LiteralPath $full -PathType Leaf)){throw [IO.FileNotFoundException]::new('PATH_NOT_FOUND')}
    $probe=$full
    while($probe-and(Test-Path -LiteralPath $probe)){
        $item=Get-Item -LiteralPath $probe -Force
        if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw [ArgumentException]::new('PATH_REPARSE_POINT_INVALID')}
        $parent=Split-Path -Parent $probe
        if($parent-eq$probe){break}
        $probe=$parent
    }
    $full
}

function Test-ChatpadDriverIdentity {
    param([object]$Identity,[switch]$RequirePackagePath)
    $defects=[Collections.Generic.List[string]]::new()
    if($null-eq$Identity-or$Identity-is[array]){$defects.Add('identity-not-object');return @($defects)}
    foreach($name in @('published_inf','provider','driver_version','driver_date','service','driver_key','driver_node_id','inf_sha256','catalog_sha256','architecture','model_id','install_section','matching_id')){
        $value=Get-ChatpadExactProperty $Identity $name ''
        if([string]::IsNullOrWhiteSpace([string]$value)){$defects.Add("missing:$name")}
    }
    foreach($name in @('inf_sha256','catalog_sha256')){
        if([string](Get-ChatpadExactProperty $Identity $name '')-notmatch'^[0-9a-fA-F]{64}$'){$defects.Add("invalid:$name")}
    }
    if($RequirePackagePath){
        try{[void](Assert-ChatpadExactSafePath (Get-ChatpadExactProperty $Identity 'canonical_inf_path' ''))}catch{$defects.Add($_.Exception.Message)}
        $size=Get-ChatpadExactProperty $Identity 'package_byte_size' $null
        if($null-eq$size-or$size-isnot[int]-and$size-isnot[long]-or[long]$size-le0){$defects.Add('package-size-invalid')}
    }
    @($defects)
}

function New-ChatpadRestorationSnapshot {
    param(
        [Parameter(Mandatory)][object]$DeviceState,
        [Parameter(Mandatory)][string]$SnapshotTimestamp
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
    $snapshot=[pscustomobject][ordered]@{
        schema_id=$script:SnapshotSchema
        canonical_instance_id=$canonical
        class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        hardware_ids=@(Get-ChatpadExactProperty $DeviceState 'hardware_ids' @())
        compatible_ids=@(Get-ChatpadExactProperty $DeviceState 'compatible_ids' @())
        device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        restart_required=[bool](Get-ChatpadExactProperty $DeviceState 'restart_required' $false)
        reboot_required=[bool](Get-ChatpadExactProperty $DeviceState 'reboot_required' $false)
        driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $DeviceState 'driver_identity' ([pscustomobject]@{}))
        snapshot_timestamp=$SnapshotTimestamp
        unavailable_properties=@(Get-ChatpadExactProperty $DeviceState 'unavailable_properties' @())
        snapshot_sha256=''
    }
    $snapshot.snapshot_sha256=Get-ChatpadExactObjectHash $snapshot -ExcludedProperties @('snapshot_sha256')
    $snapshot
}

function Test-ChatpadRestorationSnapshot {
    param([object]$Snapshot)
    $defects=[Collections.Generic.List[string]]::new()
    if($null-eq$Snapshot-or$Snapshot-is[array]){$defects.Add('snapshot-not-object');return @($defects)}
    if([string](Get-ChatpadExactProperty $Snapshot 'schema_id' '')-ne$script:SnapshotSchema){$defects.Add('snapshot-schema-invalid')}
    try{[void](ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Snapshot 'canonical_instance_id' ''))}catch{$defects.Add($_.Exception.Message)}
    if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Snapshot 'class_guid' ''))){$defects.Add('class-guid-invalid')}
    foreach($defect in @(Test-ChatpadDriverIdentity (Get-ChatpadExactProperty $Snapshot 'driver_identity' $null))){$defects.Add([string]$defect)}
    $expected=Get-ChatpadExactObjectHash $Snapshot -ExcludedProperties @('snapshot_sha256')
    if([string](Get-ChatpadExactProperty $Snapshot 'snapshot_sha256' '')-cne$expected){$defects.Add('snapshot-hash-mismatch')}
    $timestamp=[datetimeoffset]::MinValue
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Snapshot 'snapshot_timestamp' ''),[ref]$timestamp)){$defects.Add('snapshot-timestamp-invalid')}
    @($defects)
}

function Get-ChatpadDevicePreconditionFingerprint {
    param([Parameter(Mandatory)][object]$DeviceState)
    $projection=[pscustomobject][ordered]@{
        canonical_instance_id=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
        class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        driver_node_id=[string](Get-ChatpadExactProperty (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null) 'driver_node_id' '')
        published_inf=[string](Get-ChatpadExactProperty (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null) 'published_inf' '')
    }
    Get-ChatpadExactObjectHash $projection
}

function New-ChatpadExactInstancePlan {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][ValidateSet('bind','restore')][string]$OperationType,
        [Parameter(Mandatory)][string]$GeneratedUtc,
        [Parameter(Mandatory)][string]$ExpiresUtc,
        [Parameter(Mandatory)][string]$RepositoryBranch,
        [Parameter(Mandatory)][string]$ImplementationCommit,
        [Parameter(Mandatory)][string]$HostId,
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][object]$AuthorizationContext,
        [Parameter(Mandatory)][string]$RequestedInstanceId,
        [Parameter(Mandatory)][object]$DeviceState,
        [Parameter(Mandatory)][object]$TargetDriverIdentity,
        [Parameter(Mandatory)][object]$RestorationSnapshot,
        [Parameter(Mandatory)][string[]]$AuthorizedActions,
        [ValidateSet('none','exact-device-separate-authorization','reboot-never-automatic')][string]$RestartPolicy='none',
        [string[]]$StopConditions=@('target-instance-missing','target-identity-drift','package-identity-ambiguous','postcondition-unproven','restoration-driver-unavailable')
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
    $targetDefects=@(Test-ChatpadDriverIdentity $TargetDriverIdentity -RequirePackagePath)
    if($targetDefects.Count){throw [ArgumentException]::new("TARGET_IDENTITY_INVALID:$($targetDefects-join',')")}
    $snapshotDefects=@(Test-ChatpadRestorationSnapshot $RestorationSnapshot)
    if($snapshotDefects.Count){throw [ArgumentException]::new("RESTORATION_SNAPSHOT_INVALID:$($snapshotDefects-join',')")}
    $targetPath=Assert-ChatpadExactSafePath (Get-ChatpadExactProperty $TargetDriverIdentity 'canonical_inf_path' '')
    $plan=[pscustomobject][ordered]@{
        schema_id=$script:PlanSchema
        schema_version=1
        operation_id=$OperationId
        operation_type=$OperationType
        generated_utc=$GeneratedUtc
        expires_utc=$ExpiresUtc
        repository_branch=$RepositoryBranch
        implementation_commit=$ImplementationCommit
        host_identity=$HostId
        session_identity=$SessionId
        authorization_context=Copy-ChatpadExactObject $AuthorizationContext
        requested_instance_id=$RequestedInstanceId
        canonical_instance_id=$canonical
        device_class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        hardware_ids=@(Get-ChatpadExactProperty $DeviceState 'hardware_ids' @())
        compatible_ids=@(Get-ChatpadExactProperty $DeviceState 'compatible_ids' @())
        current_device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        current_problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        current_driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null)
        target_package_path=$targetPath
        target_package_byte_size=[long](Get-ChatpadExactProperty $TargetDriverIdentity 'package_byte_size' 0)
        target_package_sha256=[string](Get-ChatpadExactProperty $TargetDriverIdentity 'inf_sha256' '')
        target_driver_identity=Copy-ChatpadExactObject $TargetDriverIdentity
        expected_post_bind_driver_identity=Copy-ChatpadExactObject $TargetDriverIdentity
        restoration_snapshot=Copy-ChatpadExactObject $RestorationSnapshot
        exact_restoration_driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $RestorationSnapshot 'driver_identity' $null)
        precondition_fingerprint=Get-ChatpadDevicePreconditionFingerprint $DeviceState
        restoration_snapshot_fingerprint=[string](Get-ChatpadExactProperty $RestorationSnapshot 'snapshot_sha256' '')
        authorized_actions=@($AuthorizedActions)
        expected_restart_reboot_policy=$RestartPolicy
        stop_conditions=@($StopConditions)
        plan_sha256=''
    }
    $plan.plan_sha256=Get-ChatpadExactObjectHash $plan -ExcludedProperties @('plan_sha256')
    $plan
}

function Test-ChatpadExactInstancePlan {
    param(
        [object]$Plan,
        [string]$ExpectedPlanSha256='',
        [string]$ExpectedOperationId='',
        [string]$ValidationTimeUtc=''
    )
    $defects=[Collections.Generic.List[string]]::new()
    if($null-eq$Plan-or$Plan-is[array]){$defects.Add('plan-not-object');return [pscustomobject]@{result='FAIL';result_code='PLAN_INVALID';defects=@($defects)}}
    if([string](Get-ChatpadExactProperty $Plan 'schema_id' '')-ne$script:PlanSchema){$defects.Add('plan-schema-invalid')}
    if([int](Get-ChatpadExactProperty $Plan 'schema_version' 0)-ne1){$defects.Add('plan-version-invalid')}
    if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Plan 'operation_id' ''))){$defects.Add('operation-id-invalid')}
    if($ExpectedOperationId-and[string](Get-ChatpadExactProperty $Plan 'operation_id' '')-cne$ExpectedOperationId){$defects.Add('operation-id-mismatch')}
    try {
        $requested=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Plan 'requested_instance_id' '')
        $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Plan 'canonical_instance_id' '')
        if($requested-cne$canonical){$defects.Add('canonical-instance-mismatch')}
    } catch {$defects.Add($_.Exception.Message)}
    if([string](Get-ChatpadExactProperty $Plan 'implementation_commit' '')-notmatch'^[0-9a-f]{40}$'){$defects.Add('implementation-commit-invalid')}
    try{[void](Assert-ChatpadExactSafePath (Get-ChatpadExactProperty $Plan 'target_package_path' ''))}catch{$defects.Add($_.Exception.Message)}
    foreach($defect in @(Test-ChatpadDriverIdentity (Get-ChatpadExactProperty $Plan 'target_driver_identity' $null) -RequirePackagePath)){$defects.Add([string]$defect)}
    foreach($defect in @(Test-ChatpadRestorationSnapshot (Get-ChatpadExactProperty $Plan 'restoration_snapshot' $null))){$defects.Add([string]$defect)}
    $actualHash=Get-ChatpadExactObjectHash $Plan -ExcludedProperties @('plan_sha256')
    if([string](Get-ChatpadExactProperty $Plan 'plan_sha256' '')-cne$actualHash){$defects.Add('plan-hash-invalid')}
    if($ExpectedPlanSha256-and$ExpectedPlanSha256-cne$actualHash){$defects.Add('plan-hash-mismatch')}
    $generated=[datetimeoffset]::MinValue;$expires=[datetimeoffset]::MinValue;$now=[datetimeoffset]::UtcNow
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Plan 'generated_utc' ''),[ref]$generated)){$defects.Add('generated-time-invalid')}
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Plan 'expires_utc' ''),[ref]$expires)){$defects.Add('expiry-time-invalid')}
    if($ValidationTimeUtc-and-not[datetimeoffset]::TryParse($ValidationTimeUtc,[ref]$now)){$defects.Add('validation-time-invalid')}
    if($expires-le$generated){$defects.Add('expiry-order-invalid')}
    if($expires-le$now){$defects.Add('plan-expired')}
    $actions=@(Get-ChatpadExactProperty $Plan 'authorized_actions' @())
    if($actions.Count-eq0-or@($actions|Where-Object{$_-notin$script:AllowedActions}).Count){$defects.Add('authorized-actions-invalid')}
    if($defects.Count){[pscustomobject]@{result='FAIL';result_code=if($defects-contains'plan-expired'){'PLAN_EXPIRED'}elseif($defects-contains'plan-hash-mismatch'-or$defects-contains'plan-hash-invalid'){'PLAN_HASH_MISMATCH'}elseif($defects-contains'operation-id-mismatch'){'OPERATION_ID_MISMATCH'}else{'PLAN_INVALID'};defects=@($defects)}}
    else{[pscustomobject]@{result='PASS';result_code='PLAN_VALID';defects=@()}}
}

function Test-ChatpadExactTransition {
    param([Parameter(Mandatory)][string]$From,[Parameter(Mandatory)][string]$To)
    if(-not$script:AllowedTransitions.Contains($From)){return $false}
    $script:AllowedTransitions[$From]-contains$To
}

function Add-ChatpadExactTransition {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Transitions,
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][string]$Timestamp,
        [string]$Reason=''
    )
    if($Transitions.Count){
        $prior=[string]$Transitions[$Transitions.Count-1].state
        if(-not(Test-ChatpadExactTransition $prior $State)){throw [InvalidOperationException]::new("STATE_TRANSITION_INVALID:$prior->$State")}
    } elseif($State-ne'PLAN_CREATED'){throw [InvalidOperationException]::new("STATE_TRANSITION_INVALID:<start>->$State")}
    $Transitions.Add([pscustomobject][ordered]@{sequence=$Transitions.Count+1;state=$State;timestamp=$Timestamp;reason=$Reason})
}

function Test-ChatpadRealExecutionAuthorization {
    param(
        [Parameter(Mandatory)][ValidateSet('Apply','Restore')][string]$Mode,
        [object]$Plan,
        [string]$ExpectedPlanSha256,
        [string]$OperationId,
        [string]$AuthorizationValue,
        [switch]$AllowWindowsMutation,
        [bool]$IsElevated,
        [string]$AdapterIdentity,
        [bool]$SyntheticAdapter,
        [bool]$CleanPreflight,
        [string]$ValidationTimeUtc
    )
    $defects=[Collections.Generic.List[string]]::new()
    $validation=Test-ChatpadExactInstancePlan $Plan -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId -ValidationTimeUtc $ValidationTimeUtc
    if($validation.result-ne'PASS'){$defects.Add($validation.result_code)}
    if(-not$AllowWindowsMutation){$defects.Add('WINDOWS_MUTATION_SWITCH_MISSING')}
    if(-not$IsElevated){$defects.Add('ELEVATION_REQUIRED')}
    if(-not$CleanPreflight){$defects.Add('PREFLIGHT_NOT_CLEAN')}
    if([string]::IsNullOrWhiteSpace($AuthorizationValue)){$defects.Add('AUTHORIZATION_VALUE_MISSING')}
    $expectedAuth=Get-ChatpadExactSha256Text ("$OperationId|$ExpectedPlanSha256|$Mode")
    if($AuthorizationValue-cne$expectedAuth){$defects.Add('AUTHORIZATION_VALUE_INVALID')}
    if($SyntheticAdapter-or$AdapterIdentity-ne'chatpad-windows-exact-instance-adapter-v1'){$defects.Add('REAL_ADAPTER_REQUIRED')}
    if($defects.Count){[pscustomobject]@{result='BLOCKED';result_code='EXECUTION_GATES_INCOMPLETE';defects=@($defects)}}
    else{[pscustomobject]@{result='PASS';result_code='EXECUTION_GATES_VALID';defects=@()}}
}

function Test-ChatpadExactInstanceEvidence {
    param([object]$Evidence)
    $defects=[Collections.Generic.List[string]]::new()
    if($null-eq$Evidence-or$Evidence-is[array]){$defects.Add('evidence-not-object')}
    else {
        if([string](Get-ChatpadExactProperty $Evidence 'schema_id' '')-ne$script:EvidenceSchema){$defects.Add('evidence-schema-invalid')}
        if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Evidence 'operation_id' ''))){$defects.Add('operation-id-invalid')}
        if([string](Get-ChatpadExactProperty $Evidence 'plan_sha256' '')-notmatch'^[0-9a-f]{64}$'){$defects.Add('plan-hash-invalid')}
        $synthetic=[bool](Get-ChatpadExactProperty $Evidence 'synthetic' $false)
        $adapter=[string](Get-ChatpadExactProperty $Evidence 'adapter_identity' '')
        $source=[string](Get-ChatpadExactProperty $Evidence 'source_classification' '')
        if($adapter-eq'chatpad-fake-exact-instance-adapter-v1'-and(-not$synthetic-or$source-ne'synthetic')){$defects.Add('fake-adapter-provenance-spoofed')}
        if($synthetic-and$adapter-ne'chatpad-fake-exact-instance-adapter-v1'){$defects.Add('synthetic-adapter-identity-invalid')}
        if([bool](Get-ChatpadExactProperty $Evidence 'live_readiness_satisfied' $true)){$defects.Add('synthetic-evidence-cannot-satisfy-live-readiness')}
        foreach($name in @('live_exact_binding_operation_count','live_exact_restoration_operation_count','live_restart_operation_count','windows_mutation_count')){
            if([int](Get-ChatpadExactProperty $Evidence $name -1)-ne0){$defects.Add("live-counter-nonzero:$name")}
        }
        if([string](Get-ChatpadExactProperty $Evidence 'blocker' '')-ne$script:PendingAuditBlocker){$defects.Add('pending-audit-blocker-missing')}
    }
    if($defects.Count){[pscustomobject]@{result='FAIL';result_code='EVIDENCE_PROVENANCE_INVALID';defects=@($defects)}}
    else{[pscustomobject]@{result='PASS';result_code='EVIDENCE_VALID';defects=@()}}
}

function Get-ChatpadExactInstanceConstants {
    [pscustomobject][ordered]@{
        plan_schema=$script:PlanSchema
        snapshot_schema=$script:SnapshotSchema
        evidence_schema=$script:EvidenceSchema
        pending_audit_blocker=$script:PendingAuditBlocker
        allowed_modes=@($script:AllowedModes)
        allowed_actions=@($script:AllowedActions)
        allowed_transitions=$script:AllowedTransitions
    }
}

Export-ModuleMember -Function *-Chatpad*
