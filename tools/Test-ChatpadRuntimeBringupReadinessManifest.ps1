[CmdletBinding()]
param(
    [string]$ManifestPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [switch]$RunCorruptionRegression,
    [switch]$RunTask8ERegression,
    [switch]$RunTask8FRegression,
    [switch]$RunParserEvidencePathRegression,
    [switch]$NoArtifactOpenDesignGateAudit
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

function Test-ChatpadApprovedParserEvidencePath {
    param([AllowNull()][AllowEmptyString()][string]$Path)
    if([string]::IsNullOrWhiteSpace($Path)-or[IO.Path]::IsPathRooted($Path)){return $false}
    $normalized=$Path.Replace('\','/')
    if($normalized.Contains('//')-or$normalized.Contains(':')){return $false}
    $segments=@($normalized.Split('/')|Where-Object{$_-ne''})
    if($segments.Count-lt4-or$segments[0]-cne'artifacts'-or$segments[1]-cne'logs'){return $false}
    if(@($segments|Where-Object{$_-in@('.','..')}).Count){return $false}
    $rootSegment=$segments[2]
    if($rootSegment -cne 'static-parser-real-artifact-authorization-plumbing' -and $rootSegment -cne 'static-parser-status-boundary-remediation' -and $rootSegment-notmatch'(?i)^(static-metadata-parser-[a-z0-9][a-z0-9-]*|independent-static-metadata-parser-[a-z0-9][a-z0-9-]*|independent-static-parser-real-artifact-authorization-plumbing-(audit|remediation|remediation-audit)-[a-f0-9]{7,40})$'){return $false}
    $tail=($segments|Select-Object -Skip 3) -join '/'
    if($normalized-match'(?i)(artifacts/compile-only|chatpad\.nativeinterop\.compileonlyvalidation\.dll|compiled-artifact|native-interop|metadata-review|/legacy/)'){return $false}
    if($tail-match'(?i)real-artifact'){return $false}
    return $segments[-1]-ceq'static-metadata-parser-synthetic-validation.json'
}

function Get-ChatpadMetadataReviewBooleanExpectations {
    [ordered]@{
        compile_only_evidence_remediation_accepted=$true
        independent_design_audit_required=$false
        implementation_authorized=$false
        artifact_opening_authorized=$false
        artifact_bytes_opened=$false
        artifact_parsing_authorized=$false
        artifact_parsing_performed=$false
        artifact_writing_authorized=$false
        artifact_writing_occurred=$false
        assembly_loading_authorized=$false
        assembly_loading_occurred=$false
        runtime_reflection_authorized=$false
        runtime_reflection_occurred=$false
        compiled_artifact_execution_authorized=$false
        compiled_artifact_execution_occurred=$false
        native_dll_loading_authorized=$false
        native_dll_loading_occurred=$false
        native_entry_point_resolution_authorized=$false
        native_entry_point_resolution_occurred=$false
        native_invocation_authorized=$false
        native_invocation_occurred=$false
        setupapi_newdev_invocation_authorized=$false
        setupapi_newdev_invocation_occurred=$false
        device_query_authorized=$false
        device_query_occurred=$false
        hardware_access_authorized=$false
        hardware_access_occurred=$false
        windows_mutation_authorized=$false
        windows_mutation_occurred=$false
        registry_mutation_authorized=$false
        registry_mutation_occurred=$false
        service_mutation_authorized=$false
        service_mutation_occurred=$false
        certificate_mutation_authorized=$false
        certificate_mutation_occurred=$false
        key_mutation_authorized=$false
        key_mutation_occurred=$false
        credential_mutation_authorized=$false
        credential_mutation_occurred=$false
        driver_actions_authorized=$false
        driver_actions_occurred=$false
        driver_build_authorized=$false
        driver_build_occurred=$false
        driver_link_authorized=$false
        driver_link_occurred=$false
        driver_sign_authorized=$false
        driver_sign_occurred=$false
        driver_cat_generation_authorized=$false
        driver_cat_generation_occurred=$false
        driver_package_authorized=$false
        driver_package_occurred=$false
        driver_stage_authorized=$false
        driver_stage_occurred=$false
        driver_install_authorized=$false
        driver_install_occurred=$false
        driver_load_authorized=$false
        driver_load_occurred=$false
        driver_unload_authorized=$false
        driver_unload_occurred=$false
        driver_bind_authorized=$false
        driver_bind_occurred=$false
        driver_restore_authorized=$false
        driver_restore_occurred=$false
        driver_restart_authorized=$false
        driver_restart_occurred=$false
    }
}

function Get-ChatpadValueCategory {
    param([object]$Value)
    if($null-eq$Value){return 'null'}
    if($Value-is[array]){return 'array'}
    if($Value-is[bool]){return 'boolean'}
    if($Value-is[string]){return $(if($Value.Length){'string'}else{'empty-string'})}
    if($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int]-or$Value-is[uint32]-or$Value-is[long]-or$Value-is[uint64]-or$Value-is[single]-or$Value-is[double]-or$Value-is[decimal]){return 'number'}
    return 'object'
}

function New-ChatpadMetadataReviewDefect {
    param(
        [Parameter(Mandatory)][string]$DefectCode,
        [Parameter(Mandatory)][string]$FieldPath,
        [Parameter(Mandatory)][string]$ExpectedType,
        [object]$ActualValue,
        [Parameter(Mandatory)][string]$Reason
    )
    [pscustomobject][ordered]@{
        defect_code=$DefectCode
        field_path=$FieldPath
        expected_type=$ExpectedType
        actual_type=if($null-eq$ActualValue){'null'}else{$ActualValue.GetType().FullName}
        actual_value_category=Get-ChatpadValueCategory $ActualValue
        actual_value=if($null-eq$ActualValue){$null}elseif($ActualValue-is[array]){"array(count=$($ActualValue.Count))"}elseif($ActualValue-is[pscustomobject]){'object'}else{[string]$ActualValue}
        reason=$Reason
    }
}

function Test-ChatpadRequiredBooleanProperty {
    param(
        [object]$Container,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][bool]$ExpectedValue
    )
    $fieldPath="$Location.$PropertyName"
    if($null-eq$Container-or$Container-is[array]){
        return New-ChatpadMetadataReviewDefect 'METADATA_BOOLEAN.INVALID_CONTAINER' $fieldPath 'Boolean' $Container 'The Boolean field container is null or an array.'
    }
    $property=$Container.PSObject.Properties[$PropertyName]
    if($null-eq$property){
        return New-ChatpadMetadataReviewDefect 'METADATA_BOOLEAN.MISSING' $fieldPath 'Boolean' $null 'Required Boolean field is missing.'
    }
    $value=$property.Value
    if($null-eq$value){
        return New-ChatpadMetadataReviewDefect 'METADATA_BOOLEAN.NULL' $fieldPath 'Boolean' $null 'Required Boolean field is null.'
    }
    if($value-isnot[bool]){
        $category=Get-ChatpadValueCategory $value
        return New-ChatpadMetadataReviewDefect "METADATA_BOOLEAN.INVALID_TYPE.$($category.ToUpperInvariant().Replace('-','_'))" $fieldPath 'Boolean' $value 'Required Boolean field has a non-Boolean JSON type.'
    }
    if($value-ne$ExpectedValue){
        return New-ChatpadMetadataReviewDefect 'METADATA_BOOLEAN.VALUE_MISMATCH' $fieldPath 'Boolean' $value "Required Boolean value is $ExpectedValue."
    }
    return $null
}

function Test-ChatpadNativeExecutionStatusValue {
    param([object]$Container,[string]$PropertyName='native_execution_status',[string]$Location='manifest')
    $fieldPath="$Location.$PropertyName"
    if($null-eq$Container-or$Container-is[array]){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.INVALID_CONTAINER' $fieldPath 'String(NOT_IMPLEMENTED)' $Container 'Status container is null or an array.'
    }
    $property=$Container.PSObject.Properties[$PropertyName]
    if($null-eq$property){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.MISSING' $fieldPath 'String(NOT_IMPLEMENTED)' $null 'Required native execution status is missing.'
    }
    $value=$property.Value
    if($null-eq$value){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.NULL' $fieldPath 'String(NOT_IMPLEMENTED)' $null 'Required native execution status is null.'
    }
    if($value-isnot[string]){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.INVALID_TYPE' $fieldPath 'String(NOT_IMPLEMENTED)' $value 'Native execution status must be a JSON string.'
    }
    if([string]::IsNullOrWhiteSpace($value)){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.EMPTY' $fieldPath 'String(NOT_IMPLEMENTED)' $value 'Native execution status is empty.'
    }
    if($value-cne'NOT_IMPLEMENTED'){
        return New-ChatpadMetadataReviewDefect 'NATIVE_EXECUTION_STATUS.UNKNOWN_OR_IMPLEMENTED' $fieldPath 'String(NOT_IMPLEMENTED)' $value 'Native execution status must remain NOT_IMPLEMENTED.'
    }
    return $null
}

function New-ChatpadCountValidationDefect {
    param(
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$Location,
        [string]$RecordId='',
        [Parameter(Mandatory)][string]$DefectId,
        [Parameter(Mandatory)][string]$Reason,
        [object]$Value
    )
    [pscustomobject][ordered]@{
        defect_id=$DefectId
        field=$FieldName
        location=$Location
        record_id=$RecordId
        reason=$Reason
        value_type=if($null -eq $Value){'null'}else{$Value.GetType().FullName}
        value=if($null -eq $Value){$null}else{[string]$Value}
    }
}

function Test-ChatpadExactIntegerCount {
    param(
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$Location,
        [string]$RecordId='',
        [object]$Value,
        [switch]$AllowZero
    )
    $invalidPrefix='INVALID_INTEGER_COUNT'
    if($null -eq $Value){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.NULL" 'Count value is null.' $Value)}
    }
    if($Value -is [array]){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.ARRAY" 'Count value is an array.' $Value)}
    }
    if($Value -is [bool]){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.BOOLEAN" 'Count value is Boolean, not a numeric integer.' $Value)}
    }
    if($Value -is [string]){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.STRING" 'Count value is a string; numeric-looking strings are not accepted.' $Value)}
    }

    $numericTypes=@(
        [byte],[sbyte],[int16],[uint16],[int],[uint32],[long],[uint64],
        [single],[double],[decimal]
    )
    $isNumeric=$false
    foreach($type in $numericTypes){if($Value -is $type){$isNumeric=$true;break}}
    if(-not $isNumeric){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.OBJECT" 'Count value is not a JSON numeric scalar.' $Value)}
    }

    if($Value -is [single]){
        if([single]::IsNaN([single]$Value) -or [single]::IsInfinity([single]$Value)){
            return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.NON_FINITE" 'Count value is not finite.' $Value)}
        }
    }
    if($Value -is [double]){
        if([double]::IsNaN([double]$Value) -or [double]::IsInfinity([double]$Value)){
            return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.NON_FINITE" 'Count value is not finite.' $Value)}
        }
    }

    $decimalValue=$null
    try {
        $decimalValue=[decimal]$Value
    } catch {
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.OUT_OF_RANGE" 'Count value is outside the supported signed 64-bit integer range.' $Value)}
    }

    $min=[decimal][long]::MinValue
    $max=[decimal][long]::MaxValue
    if($decimalValue -lt $min -or $decimalValue -gt $max){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.OUT_OF_RANGE" 'Count value is outside the supported signed 64-bit integer range.' $Value)}
    }
    if([decimal]::Truncate($decimalValue) -ne $decimalValue){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.FRACTIONAL" 'Count value has a nonzero fractional component; integer-valued numeric forms such as 1.0 are accepted, but 1.5, 0.1, -0.5, and 2.0001 are rejected.' $Value)}
    }
    if(((-not $AllowZero) -and $decimalValue -le 0) -or ($AllowZero -and $decimalValue -lt 0)){
        return [pscustomobject][ordered]@{valid=$false;value=$null;defect=(New-ChatpadCountValidationDefect $FieldName $Location $RecordId "$invalidPrefix.NEGATIVE" 'Count value is negative.' $Value)}
    }
    return [pscustomobject][ordered]@{valid=$true;value=[long]$decimalValue;defect=$null}
}

function Get-ChatpadValidatedIntegerProperty {
    param(
        [object]$Item,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][string]$Location,
        [string]$RecordId='',
        [Parameter(Mandatory)][ref]$DefectCount,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Defects,
        [switch]$AllowZero
    )
    if($null -eq $Item -or $Item -is [array]){
        $DefectCount.Value++
        $Defects.Add((New-ChatpadCountValidationDefect $PropertyName $Location $RecordId 'INVALID_INTEGER_COUNT.CONTAINER' 'Count container is null or an array.' $Item))
        return $null
    }
    $property=$Item.PSObject.Properties[$PropertyName]
    if($null -eq $property){
        $DefectCount.Value++
        $Defects.Add((New-ChatpadCountValidationDefect $PropertyName $Location $RecordId 'INVALID_INTEGER_COUNT.MISSING' 'Required count property is missing.' $null))
        return $null
    }
    $validation=Test-ChatpadExactIntegerCount -FieldName $PropertyName -Location $Location -RecordId $RecordId -Value $property.Value -AllowZero:$AllowZero
    if(-not $validation.valid){
        $DefectCount.Value++
        $Defects.Add($validation.defect)
        return $null
    }
    return $validation.value
}

function Get-ChatpadIntegerPropertySum {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][ref]$DefectCount,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Defects,
        [Parameter(Mandatory)][string]$Location
    )
    $sum = [long]0
    foreach ($item in @($Items)) {
        $recordId=''
        if($null -ne $item -and $item -isnot [array] -and $null -ne $item.PSObject.Properties['fixture_id']){$recordId=[string]$item.PSObject.Properties['fixture_id'].Value}
        elseif($null -ne $item -and $item -isnot [array] -and $null -ne $item.PSObject.Properties['category']){$recordId=[string]$item.PSObject.Properties['category'].Value}
        $number=Get-ChatpadValidatedIntegerProperty -Item $item -PropertyName $PropertyName -Location $Location -RecordId $recordId -DefectCount $DefectCount -Defects $Defects -AllowZero
        if($null -ne $number){$sum += $number}
    }
    return $sum
}

function Get-ChatpadTask8EValue {
    param([AllowNull()][object]$Object,[Parameter(Mandatory)][string]$Name)
    if($null-eq$Object){return $null}
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property){return $null}
    $property.Value
}

function Test-ChatpadTask8EManifestEvidence {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][object]$Manifest)
    $defects=[Collections.Generic.List[string]]::new()
    $section=Get-ChatpadTask8EValue $Manifest 'nonexecuting_native_adapter_implementation'
    if($null-eq$section-or$section-is[array]){return [pscustomobject]@{result='FAIL';defect_count=1;defects=@('section') }}
    $expected=[ordered]@{
        evidence_path='docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json';schema='chatpad-native-adapter-nonexecuting-implementation-evidence-v1';status='SOURCE_IMPLEMENTATION_PRESENT_NO_NATIVE_EXECUTION_NO_BINDING_NO_MUTATION_NO_LIVE_DEVICE_ACCESS';readiness='READY_FOR_INDEPENDENT_NONEXECUTING_NATIVE_ADAPTER_AUDIT_ONLY';starting_branch='feature/native-adapter-execution-envelope-verifier';starting_commit='79955ef434ed4424a72b6dea8ec870a66ad5d8ef';implementation_branch='feature/native-adapter-nonexecuting-implementation';implementation_commit_parent='79955ef434ed4424a72b6dea8ec870a66ad5d8ef';implementation_commit_subject='feat: implement non-executing native adapter surface';contract_evidence_path='docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json';contract_evidence_sha256='1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080';adapter_source_path='tools/ExactInstance/ChatpadNonExecutingNativeAdapter.psm1';adapter_source_sha256='78B85CBC2EB0FF58D65A5B97D35DEA9561FD7EA80E910444C2BEDC415C5AB919';focused_test_path='tools/Test-ChatpadNonExecutingNativeAdapter.ps1';focused_test_sha256='5CEB63F658DB2FF232DFE9E872BC2228060AD34048503CBCF5A8D8F39FDDE254';capability_adversarial_result='PASS';sessionstate_extraction_result='PASS';live_readiness='BLOCKED';blocker='BLOCKED_NATIVE_ADAPTER_IMPLEMENTATION_NOT_INDEPENDENTLY_AUDITED'
    }
    foreach($pair in $expected.GetEnumerator()){if([string](Get-ChatpadTask8EValue $section $pair.Key)-cne$pair.Value){$defects.Add("section.$($pair.Key)")}}
    foreach($name in @('device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','artifact_compile_output_access_count','failed_validation_fake_backend_call_count')){$value=Get-ChatpadTask8EValue $section $name;if($null-eq$value-or$value-is[string]-or$value-is[array]-or[int]$value-ne0){$defects.Add("section.$name")}}
    if([int](Get-ChatpadTask8EValue $section 'approved_fake_backend_call_count')-ne1){$defects.Add('section.approved_fake_backend_call_count')}
    foreach($name in @('production_backend_present','production_backend_loaded','production_backend_selected_by_default','rollback_performed','restore_performed','native_execution_authorized','ready_for_native_execution','ready_for_binding_execution','ready_for_windows_mutation','ready_for_driver_action','ready_for_artifact_access','ready_for_compile_output_access')){if((Get-ChatpadTask8EValue $section $name)-isnot[bool]-or(Get-ChatpadTask8EValue $section $name)){$defects.Add("section.$name")}}
    if((Get-ChatpadTask8EValue $section 'ready_for_independent_audit_only')-isnot[bool]-or-not(Get-ChatpadTask8EValue $section 'ready_for_independent_audit_only')){$defects.Add('section.ready_for_independent_audit_only')}
    if([string](Get-ChatpadTask8EValue $section 'powershell_7_result')-cne'PASS'-or[int](Get-ChatpadTask8EValue $section 'powershell_7_test_count')-ne12-or[int](Get-ChatpadTask8EValue $section 'powershell_7_assertion_count')-ne81-or[string](Get-ChatpadTask8EValue $section 'windows_powershell_result')-cne'PASS'-or[int](Get-ChatpadTask8EValue $section 'windows_powershell_test_count')-ne12-or[int](Get-ChatpadTask8EValue $section 'windows_powershell_assertion_count')-ne81){$defects.Add('section.runtime-results')}
    $evidencePath=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot ([string](Get-ChatpadTask8EValue $section 'evidence_path'))))
    if(-not$evidencePath.StartsWith($RepositoryRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $evidencePath -PathType Leaf)){$defects.Add('evidence.path');return [pscustomobject]@{result='FAIL';defect_count=$defects.Count;defects=@($defects)}}
    try{$evidence=Get-Content -LiteralPath $evidencePath -Raw|ConvertFrom-Json}catch{$defects.Add('evidence.json');return [pscustomobject]@{result='FAIL';defect_count=$defects.Count;defects=@($defects)}}
    foreach($name in @('schema','status','readiness','starting_branch','starting_commit','implementation_branch','implementation_commit_parent','implementation_commit_subject','contract_evidence_path','contract_evidence_sha256','production_backend_present','production_backend_loaded','production_backend_selected_by_default','device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','artifact_compile_output_access_count','rollback_performed','restore_performed','native_execution_authorized','live_readiness')){if([string](Get-ChatpadTask8EValue $evidence $name)-cne[string](Get-ChatpadTask8EValue $section $name)){$defects.Add("evidence.$name")}}
    foreach($name in @('capability_adversarial_result','sessionstate_extraction_result')){if([string](Get-ChatpadTask8EValue $section $name)-cne'PASS'-or-not([string](Get-ChatpadTask8EValue $evidence $name)).StartsWith('PASS:',[StringComparison]::Ordinal)){$defects.Add("evidence.$name")}}
    if([string](Get-ChatpadTask8EValue $evidence 'remaining_blocker')-cne[string](Get-ChatpadTask8EValue $section 'blocker')-or[string](Get-ChatpadTask8EValue $evidence 'fake_backend_result')-cne'PASS: failed validation made zero fake calls; the internal seam recorded one approved fake non-native operation only.'){$defects.Add('evidence.blocker-or-fake-result')}
    $files=@(Get-ChatpadTask8EValue $evidence 'implementation_files')
    $expectedFiles=@([pscustomobject]@{path=$expected.adapter_source_path;sha256=$expected.adapter_source_sha256},[pscustomobject]@{path=$expected.focused_test_path;sha256=$expected.focused_test_sha256})
    if($files.Count-ne2){$defects.Add('evidence.implementation_files')}
    for($index=0;$index-lt$expectedFiles.Count;$index++){
        if($files.Count-le$index-or[string](Get-ChatpadTask8EValue $files[$index] 'path')-cne$expectedFiles[$index].path-or[string](Get-ChatpadTask8EValue $files[$index] 'sha256')-cne$expectedFiles[$index].sha256){$defects.Add("evidence.file.$index")}
        $source=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $expectedFiles[$index].path))
        if(-not(Test-Path -LiteralPath $source -PathType Leaf)-or(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash-cne$expectedFiles[$index].sha256){$defects.Add("source.file.$index")}
    }
    $runtimes=@(Get-ChatpadTask8EValue $evidence 'test_runtimes')
    foreach($runtimeName in @('PowerShell 7','Windows PowerShell')){$runtime=@($runtimes|Where-Object{[string](Get-ChatpadTask8EValue $_ 'name')-ceq$runtimeName});if($runtime.Count-ne1-or[string](Get-ChatpadTask8EValue $runtime[0] 'result')-cne'PASS'-or[int](Get-ChatpadTask8EValue $runtime[0] 'test_count')-ne12-or[int](Get-ChatpadTask8EValue $runtime[0] 'assertion_count')-ne81){$defects.Add("evidence.runtime.$runtimeName")}}
    [pscustomobject]@{result=if($defects.Count){'FAIL'}else{'PASS'};defect_count=$defects.Count;defects=@($defects)}
}

function Invoke-ChatpadTask8ERegression {
    param([Parameter(Mandatory)][string]$ManifestPath)
    $root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('chatpad-task8e-'+[guid]::NewGuid().ToString('N'))
    $paths=@($ManifestPath,'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json','docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json','tools/ExactInstance/ChatpadNonExecutingNativeAdapter.psm1','tools/Test-ChatpadNonExecutingNativeAdapter.ps1')
    New-Item -ItemType Directory -Path $temp|Out-Null
    try{
        foreach($relative in $paths){$target=Join-Path $temp $relative;New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target -Force}
        $manifestFile=Join-Path $temp $ManifestPath;$evidenceFile=Join-Path $temp 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json';$manifestText=Get-Content $manifestFile -Raw;$evidenceText=Get-Content $evidenceFile -Raw
        $cases=[Collections.Generic.List[object]]::new();$cases.Add([pscustomobject]@{id='section-removed';mutate={param($m,$e)[void]$m.PSObject.Properties.Remove('nonexecuting_native_adapter_implementation')}});$cases.Add([pscustomobject]@{id='section-array';mutate={param($m,$e)$m.nonexecuting_native_adapter_implementation=@()}})
        foreach($field in @('evidence_path','schema','status','readiness','implementation_branch','contract_evidence_sha256','adapter_source_sha256','focused_test_sha256','blocker')){$cases.Add([pscustomobject]@{id="section-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.nonexecuting_native_adapter_implementation.$field='tampered'"))})}
        foreach($field in @('device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','artifact_compile_output_access_count')){$cases.Add([pscustomobject]@{id="counter-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.nonexecuting_native_adapter_implementation.$field=1"))})}
        foreach($field in @('production_backend_present','production_backend_loaded','production_backend_selected_by_default')){$cases.Add([pscustomobject]@{id="production-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.nonexecuting_native_adapter_implementation.$field=`$true"))})}
        $cases.Add([pscustomobject]@{id='section-starting-commit';mutate={param($m,$e)$m.nonexecuting_native_adapter_implementation.starting_commit='tampered'}})
        $cases.Add([pscustomobject]@{id='adapter-source-identity-removed';mutate={param($m,$e)[void]$m.nonexecuting_native_adapter_implementation.PSObject.Properties.Remove('adapter_source_sha256')}})
        $cases.Add([pscustomobject]@{id='focused-test-identity-removed';mutate={param($m,$e)[void]$m.nonexecuting_native_adapter_implementation.PSObject.Properties.Remove('focused_test_sha256')}})
        $cases.Add([pscustomobject]@{id='unsupported-native-readiness';mutate={param($m,$e)$m.nonexecuting_native_adapter_implementation.ready_for_native_execution=$true}})
        $cases.Add([pscustomobject]@{id='fake-represented-native';mutate={param($m,$e)$e.fake_backend_result='PASS: native execution occurred'}})
        $cases.Add([pscustomobject]@{id='evidence-disagreement';mutate={param($m,$e)$e.status='tampered'}})
        $results=[Collections.Generic.List[object]]::new()
        $canonical=Get-Content $manifestFile -Raw|ConvertFrom-Json;$pass=Test-ChatpadTask8EManifestEvidence -RepositoryRoot $temp -Manifest $canonical;$results.Add([pscustomobject]@{id='canonical';result=$pass.result;passed=($pass.result-eq'PASS')})
        foreach($case in $cases){[IO.File]::WriteAllText($manifestFile,$manifestText,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($evidenceFile,$evidenceText,[Text.UTF8Encoding]::new($false));$m=Get-Content $manifestFile -Raw|ConvertFrom-Json;$e=Get-Content $evidenceFile -Raw|ConvertFrom-Json;& $case.mutate $m $e;[IO.File]::WriteAllText($manifestFile,($m|ConvertTo-Json -Depth 30)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($evidenceFile,($e|ConvertTo-Json -Depth 30)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false));$result=Test-ChatpadTask8EManifestEvidence -RepositoryRoot $temp -Manifest $m;$results.Add([pscustomobject]@{id=$case.id;result=$result.result;passed=($result.result-eq'FAIL')})}
        $failed=@($results|Where-Object{-not $_.passed});[pscustomobject]@{result=if($failed.Count){'FAIL'}else{'PASS'};test_count=$results.Count;assertion_count=$results.Count;failed_test_count=$failed.Count;tests=@($results);temporary_data_removed=$true}
    }finally{if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
}

function Get-ChatpadExactOrdinalArrayValueDefects {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$ExpectedValues,
        [Parameter(Mandatory)][AllowNull()][object]$ActualValues,
        [Parameter(Mandatory)][string]$FieldName
    )
    $defects=[Collections.Generic.List[string]]::new()
    if($ExpectedValues-is[string]-or$ExpectedValues-isnot[System.Collections.IList]){
        $defects.Add("${FieldName}: expected value is not an array/list (actual type: $(if($null-eq$ExpectedValues){'null'}else{$ExpectedValues.GetType().FullName})).")
        return [pscustomobject]@{defects=@($defects)}
    }
    if($null-eq$ActualValues-or$ActualValues-is[string]-or$ActualValues-isnot[System.Collections.IList]){
        $defects.Add("${FieldName}: expected array/list, actual type: $(if($null-eq$ActualValues){'null'}else{$ActualValues.GetType().FullName}).")
        return [pscustomobject]@{defects=@($defects)}
    }
    if($ExpectedValues.Count-ne$ActualValues.Count){$defects.Add("${FieldName}: expected count $($ExpectedValues.Count), actual count $($ActualValues.Count).")}
    $ordinalCount=[Math]::Min($ExpectedValues.Count,$ActualValues.Count)
    for($index=0;$index-lt$ordinalCount;$index++){
        $expectedValue=$ExpectedValues[$index];$actualValue=$ActualValues[$index]
        if($actualValue-isnot[string]-or-not[string]::Equals($expectedValue,$actualValue,[StringComparison]::Ordinal)){
            $actualDescription=if($null-eq$actualValue){'<null>'}elseif($actualValue-is[string]){"'$actualValue'"}else{"<$($actualValue.GetType().FullName)> '$actualValue'"}
            $defects.Add("${FieldName}: failing index $index; expected '$expectedValue', actual $actualDescription.")
        }
    }
    [pscustomobject]@{defects=@($defects)}
}

function Get-ChatpadExactOrdinalArrayPropertyDefects {
    param(
        [Parameter(Mandatory)][object]$Object,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][object]$ExpectedValues,
        [Parameter(Mandatory)][string]$FieldName
    )
    if($null-eq$Object-or$null-eq$Object.PSObject.Properties[$PropertyName]){
        return [pscustomobject]@{defects=@("${FieldName}: property is missing.")}
    }
    Get-ChatpadExactOrdinalArrayValueDefects -ExpectedValues $ExpectedValues -ActualValues $Object.PSObject.Properties[$PropertyName].Value -FieldName $FieldName
}

function Test-ChatpadTask8FManifestEvidence {
    param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][object]$Manifest)
    $defects=[Collections.Generic.List[string]]::new()
    $section=Get-ChatpadTask8EValue $Manifest 'gated_production_native_adapter_backend'
    if($null-eq$section-or$section-is[array]){return [pscustomobject]@{result='FAIL';defect_count=1;defects=@('section') }}
    $expected=[ordered]@{
        evidence_path='docs/evidence/native-adapter-production-backend-source-task-8f-1.json';schema='chatpad-gated-production-native-adapter-backend-evidence-v1';status='PRODUCTION_BACKEND_SOURCE_PRESENT_PRODUCTION_BACKEND_NOT_EXECUTED_NO_LIVE_DEVICE_ACCESS_NO_BINDING_NO_MUTATION_EXECUTION_UNAUTHORIZED';readiness='READY_FOR_INDEPENDENT_PRODUCTION_NATIVE_ADAPTER_BACKEND_AUDIT_ONLY';created_from_task='TASK 8F-1';starting_branch='feature/native-adapter-nonexecuting-implementation';starting_commit='22ce984beaf3b881a43b4aad3cc3d2c14d74fc4e';implementation_branch='feature/native-adapter-production-backend-source';implementation_commit_parent='22ce984beaf3b881a43b4aad3cc3d2c14d74fc4e';implementation_commit_subject='feat: implement gated production native adapter backend';contract_evidence_path='docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json';contract_evidence_sha256='1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080';task_8e_evidence_path='docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json';task_8e_evidence_schema='chatpad-native-adapter-nonexecuting-implementation-evidence-v1';backend_source_path='tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1';backend_source_sha256='77162617BAC6439921E3856A352ED8E940D43B549A717F2F58233C1445269754';focused_test_path='tools/Test-ChatpadGatedProductionNativeAdapterBackend.ps1';focused_test_sha256='63F6F700F2D1300016BDE7DFAA9DD0DB0EA28AC26814D1E342482DC702F9D10E';production_backend_identity='chatpad-windows-exact-instance-adapter-v1';remaining_blocker='BLOCKED_NATIVE_ADAPTER_PRODUCTION_BACKEND_NOT_INDEPENDENTLY_AUDITED';live_readiness='BLOCKED'
    }
    foreach($pair in $expected.GetEnumerator()){if([string](Get-ChatpadTask8EValue $section $pair.Key)-cne$pair.Value){$defects.Add("section.$($pair.Key)")}}
    $expectedChain=@('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
    # This declaration inventory is intentionally not the execution call plan.
    $expectedNativeApiDeclarations=@('SetupDiCreateDeviceInfoList','SetupDiDestroyDeviceInfoList','SetupDiOpenDeviceInfoW','SetupDiGetDeviceInstanceIdW','SetupDiGetDevicePropertyW','SetupDiGetDeviceRegistryPropertyW','SetupDiBuildDriverInfoList','SetupDiDestroyDriverInfoList','SetupDiEnumDriverInfoW','SetupDiGetDriverInfoDetailW','SetupDiGetDriverInstallParamsW','SetupDiSetSelectedDriverW','DiInstallDevice')
    $expectedPublicExports=@('Get-ChatpadNonExecutingNativeAdapterContract','Test-ChatpadNonExecutingNativeAdapterRequest','Invoke-ChatpadNonExecutingNativeAdapter','New-ChatpadNativeAdapterFakeRecordingBackend')
    $expectedPrivateBackendSurface=@('New-GatedProductionNativeProviderDescriptor','New-GatedProductionRecordingProvider','Invoke-GatedProductionProviderCall','Invoke-GatedProductionBackendRecordingPlan')
    $exactArrayFields=@(
        [pscustomobject]@{name='native_api_declarations_represented';expected=$expectedNativeApiDeclarations},
        [pscustomobject]@{name='public_exports';expected=$expectedPublicExports},
        [pscustomobject]@{name='private_backend_surface';expected=$expectedPrivateBackendSurface}
    )
    foreach($name in @('accepted_target_chain')){if(@(Get-ChatpadTask8EValue $section $name).Count-eq0){$defects.Add("section.$name")}}
    if((@(Get-ChatpadTask8EValue $section 'accepted_target_chain')-join'|')-cne($expectedChain-join'|')){$defects.Add('section.accepted_target_chain')}
    foreach($arrayField in $exactArrayFields){foreach($defect in (Get-ChatpadExactOrdinalArrayPropertyDefects -Object $section -PropertyName $arrayField.name -ExpectedValues $arrayField.expected -FieldName "section.$($arrayField.name)").defects){$defects.Add($defect)}}
    foreach($name in @('device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','rollback_count','restore_count','artifact_compile_output_access_count')){$value=Get-ChatpadTask8EValue $section $name;if($null-eq$value-or$value-is[string]-or$value-is[array]-or[int]$value-ne0){$defects.Add("section.$name")}}
    foreach($name in @('production_backend_loaded','production_backend_selected_by_default','production_backend_constructed_during_import','execution_authorized','native_execution_performed','live_device_access_performed','binding_performed','windows_mutation_performed','driver_action_performed','rollback_performed','restore_performed','ready_for_native_execution','ready_for_binding_execution','ready_for_windows_mutation','ready_for_driver_action','ready_for_artifact_access','ready_for_compile_output_access')){if((Get-ChatpadTask8EValue $section $name)-isnot[bool]-or(Get-ChatpadTask8EValue $section $name)){$defects.Add("section.$name")}}
    foreach($name in @('production_backend_source_present','ready_for_independent_audit_only')){if((Get-ChatpadTask8EValue $section $name)-isnot[bool]-or-not(Get-ChatpadTask8EValue $section $name)){$defects.Add("section.$name")}}
    if([string](Get-ChatpadTask8EValue $section 'powershell_7_result')-cne'PASS'-or[int](Get-ChatpadTask8EValue $section 'powershell_7_test_count')-ne7-or[int](Get-ChatpadTask8EValue $section 'powershell_7_assertion_count')-ne62-or[string](Get-ChatpadTask8EValue $section 'windows_powershell_result')-cne'PASS'-or[int](Get-ChatpadTask8EValue $section 'windows_powershell_test_count')-ne7-or[int](Get-ChatpadTask8EValue $section 'windows_powershell_assertion_count')-ne62){$defects.Add('section.runtime-results')}
    $evidencePath=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot ([string](Get-ChatpadTask8EValue $section 'evidence_path'))))
    if(-not$evidencePath.StartsWith($RepositoryRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath $evidencePath -PathType Leaf)){$defects.Add('evidence.path');return [pscustomobject]@{result='FAIL';defect_count=$defects.Count;defects=@($defects)}}
    try{$evidence=Get-Content -LiteralPath $evidencePath -Raw|ConvertFrom-Json}catch{$defects.Add('evidence.json');return [pscustomobject]@{result='FAIL';defect_count=$defects.Count;defects=@($defects)}}
    foreach($name in @($expected.Keys|Where-Object{$_-ne'evidence_path'})+@('accepted_target_chain','production_backend_source_present','production_backend_loaded','production_backend_selected_by_default','production_backend_constructed_during_import','execution_authorized','device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','rollback_count','restore_count','artifact_compile_output_access_count','native_execution_performed','live_device_access_performed','binding_performed','windows_mutation_performed','driver_action_performed','rollback_performed','restore_performed','ready_for_independent_audit_only','ready_for_native_execution','ready_for_binding_execution','ready_for_windows_mutation','ready_for_driver_action','ready_for_artifact_access','ready_for_compile_output_access','powershell_7_result','powershell_7_test_count','powershell_7_assertion_count','windows_powershell_result','windows_powershell_test_count','windows_powershell_assertion_count')){if(([string](Get-ChatpadTask8EValue $evidence $name))-cne([string](Get-ChatpadTask8EValue $section $name))){$defects.Add("evidence.$name")}}
    foreach($arrayField in $exactArrayFields){
        foreach($defect in (Get-ChatpadExactOrdinalArrayPropertyDefects -Object $evidence -PropertyName $arrayField.name -ExpectedValues $arrayField.expected -FieldName "evidence.$($arrayField.name)").defects){$defects.Add($defect)}
        $sectionArrayProperty=$section.PSObject.Properties[$arrayField.name];$evidenceArrayProperty=$evidence.PSObject.Properties[$arrayField.name]
        if($null-ne$sectionArrayProperty-and$null-ne$evidenceArrayProperty){foreach($defect in (Get-ChatpadExactOrdinalArrayValueDefects -ExpectedValues $sectionArrayProperty.Value -ActualValues $evidenceArrayProperty.Value -FieldName "manifest-evidence.$($arrayField.name)").defects){$defects.Add($defect)}}
    }
    foreach($name in @('capability_adversarial_result','sessionstate_extraction_result','exact_target_result','recording_shim_result','provider_failure_cleanup_result')){if(-not([string](Get-ChatpadTask8EValue $evidence $name)).StartsWith('PASS:',[StringComparison]::Ordinal)){$defects.Add("evidence.$name")}}
    foreach($file in @(@{path=$expected.backend_source_path;sha256=$expected.backend_source_sha256},@{path=$expected.focused_test_path;sha256=$expected.focused_test_sha256})){$source=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $file.path));if(-not(Test-Path -LiteralPath $source -PathType Leaf)-or(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash-cne$file.sha256){$defects.Add("source.$($file.path)")}}
    [pscustomobject]@{result=if($defects.Count){'FAIL'}else{'PASS'};defect_count=$defects.Count;defects=@($defects)}
}

function Invoke-ChatpadTask8FRegression {
    param([Parameter(Mandatory)][string]$ManifestPath)
    $root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim());$temp=Join-Path ([IO.Path]::GetTempPath()) ('chatpad-task8f-'+[guid]::NewGuid().ToString('N'))
    $paths=@($ManifestPath,'docs/evidence/native-adapter-production-backend-source-task-8f-1.json','tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1','tools/Test-ChatpadGatedProductionNativeAdapterBackend.ps1')
    New-Item -ItemType Directory -Path $temp|Out-Null
    try{
        foreach($relative in $paths){$target=Join-Path $temp $relative;New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target -Force}
        $manifestFile=Join-Path $temp $ManifestPath;$evidenceFile=Join-Path $temp 'docs/evidence/native-adapter-production-backend-source-task-8f-1.json';$manifestText=Get-Content $manifestFile -Raw;$evidenceText=Get-Content $evidenceFile -Raw
        $cases=[Collections.Generic.List[object]]::new();$cases.Add([pscustomobject]@{id='section-removed';mutate={param($m,$e)[void]$m.PSObject.Properties.Remove('gated_production_native_adapter_backend')}});$cases.Add([pscustomobject]@{id='section-array';mutate={param($m,$e)$m.gated_production_native_adapter_backend=@()}})
        foreach($field in @('schema','status','readiness','implementation_branch','backend_source_sha256','focused_test_sha256','remaining_blocker')){$cases.Add([pscustomobject]@{id="section-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.gated_production_native_adapter_backend.$field='tampered'"))})}
        foreach($field in @('device_query_count','native_invocation_count','setupapi_newdev_invocation_count','binding_count','windows_mutation_count','driver_action_count','rollback_count','restore_count','artifact_compile_output_access_count')){$cases.Add([pscustomobject]@{id="counter-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.gated_production_native_adapter_backend.$field=1"))})}
        foreach($field in @('production_backend_loaded','production_backend_selected_by_default','production_backend_constructed_during_import','execution_authorized','native_execution_performed','live_device_access_performed','binding_performed','windows_mutation_performed','driver_action_performed')){$cases.Add([pscustomobject]@{id="forbidden-$field";mutate=([scriptblock]::Create("param(`$m,`$e) `$m.gated_production_native_adapter_backend.$field=`$true"))})}
        $cases.Add([pscustomobject]@{id='target-chain-reordered';mutate={param($m,$e)$m.gated_production_native_adapter_backend.accepted_target_chain=@($m.gated_production_native_adapter_backend.accepted_target_chain[1],$m.gated_production_native_adapter_backend.accepted_target_chain[0],$m.gated_production_native_adapter_backend.accepted_target_chain[2])}});$cases.Add([pscustomobject]@{id='evidence-disagreement';mutate={param($m,$e)$e.status='tampered'}})
        foreach($arrayField in @('native_api_declarations_represented','public_exports','private_backend_surface')){
            $sectionField="`$m.gated_production_native_adapter_backend.$arrayField";$evidenceField="`$e.$arrayField";$expectedCategory="section.${arrayField}:";$mismatchCategory="manifest-evidence.${arrayField}:"
            $cases.Add([pscustomobject]@{id="$arrayField-entry-removed";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) $sectionField=@($sectionField|Select-Object -Skip 1)"))})
            $cases.Add([pscustomobject]@{id="$arrayField-entry-added";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) $sectionField=@($sectionField)+@('TASK8F_UNAUTHORIZED_ADDED_ENTRY')"))})
            $cases.Add([pscustomobject]@{id="$arrayField-reordered";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) `$values=@($sectionField);`$first=`$values[0];`$values[0]=`$values[1];`$values[1]=`$first;$sectionField=`$values"))})
            $cases.Add([pscustomobject]@{id="$arrayField-entry-renamed";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) `$values=@($sectionField);`$values[0]='TASK8F_RENAMED_ENTRY';$sectionField=`$values"))})
            $cases.Add([pscustomobject]@{id="$arrayField-duplicate-entry";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) `$values=@($sectionField);`$values[1]=`$values[0];$sectionField=`$values"))})
            $cases.Add([pscustomobject]@{id="$arrayField-scalar";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) $sectionField='TASK8F_SCALAR'"))})
            $cases.Add([pscustomobject]@{id="$arrayField-null";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) $sectionField=`$null"))})
            $cases.Add([pscustomobject]@{id="$arrayField-empty";expected_defect_category=$expectedCategory;mutate=([scriptblock]::Create("param(`$m,`$e) $sectionField=@()"))})
            $cases.Add([pscustomobject]@{id="$arrayField-manifest-evidence-mismatch";expected_defect_category=$mismatchCategory;mutate=([scriptblock]::Create("param(`$m,`$e) `$values=@($evidenceField);`$values[0]='TASK8F_MANIFEST_EVIDENCE_MISMATCH';$evidenceField=`$values"))})
        }
        $results=[Collections.Generic.List[object]]::new();$canonical=Get-Content $manifestFile -Raw|ConvertFrom-Json;$pass=Test-ChatpadTask8FManifestEvidence -RepositoryRoot $temp -Manifest $canonical;$results.Add([pscustomobject]@{id='canonical';result=$pass.result;passed=($pass.result-eq'PASS')})
        foreach($case in $cases){[IO.File]::WriteAllText($manifestFile,$manifestText,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($evidenceFile,$evidenceText,[Text.UTF8Encoding]::new($false));$m=Get-Content $manifestFile -Raw|ConvertFrom-Json;$e=Get-Content $evidenceFile -Raw|ConvertFrom-Json;& $case.mutate $m $e;[IO.File]::WriteAllText($manifestFile,($m|ConvertTo-Json -Depth 30)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false));[IO.File]::WriteAllText($evidenceFile,($e|ConvertTo-Json -Depth 30)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false));$result=Test-ChatpadTask8FManifestEvidence -RepositoryRoot $temp -Manifest $m;$expectedCategory=[string](Get-ChatpadTask8EValue $case 'expected_defect_category');$categoryMatched=[string]::IsNullOrEmpty($expectedCategory)-or@($result.defects|Where-Object{$_-like"$expectedCategory*"}).Count-gt0;$results.Add([pscustomobject]@{id=$case.id;result=$result.result;expected_defect_category=$expectedCategory;passed=($result.result-eq'FAIL'-and$categoryMatched)})}
        $failed=@($results|Where-Object{-not $_.passed});[pscustomobject]@{result=if($failed.Count){'FAIL'}else{'PASS'};test_count=$results.Count;assertion_count=$results.Count;failed_test_count=$failed.Count;tests=@($results);temporary_data_removed=$true}
    }finally{if(Test-Path $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
}

function Compare-ChatpadIntegerProperty {
    param(
        [object]$Item,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][long]$Expected,
        [Parameter(Mandatory)][string]$Location,
        [string]$RecordId='',
        [Parameter(Mandatory)][ref]$DefectCount,
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Defects,
        [switch]$AllowZero
    )
    $actual=Get-ChatpadValidatedIntegerProperty -Item $Item -PropertyName $PropertyName -Location $Location -RecordId $RecordId -DefectCount $DefectCount -Defects $Defects -AllowZero:$AllowZero
    if($null -eq $actual){return $false}
    if($actual -ne $Expected){
        $DefectCount.Value++
        $Defects.Add((New-ChatpadCountValidationDefect $PropertyName $Location $RecordId 'INTEGER_COUNT.MISMATCH' "Expected $Expected but found $actual." $actual))
        return $false
    }
    return $true
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
    $childExecutableName=if($PSVersionTable.PSEdition -eq 'Core'){'pwsh.exe'}else{'powershell.exe'}
    $childPowerShell=Join-Path $PSHOME $childExecutableName
    if(-not(Test-Path -LiteralPath $childPowerShell -PathType Leaf)){
        $childPowerShell=(Get-Command $childExecutableName -ErrorAction Stop).Source
    }
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
        function Set-ManifestEntryFileIdentity {
            param(
                [Parameter(Mandatory)][object]$Manifest,
                [Parameter(Mandatory)][string]$RelativePath
            )
            $entry=@($Manifest.entries|Where-Object relative_path -eq $RelativePath.Replace('\','/'))
            if($entry.Count -ne 1){return}
            $fullPath=[IO.Path]::GetFullPath((Join-Path $tempRoot $RelativePath))
            $identity=Get-ChatpadEvidenceFileIdentity -RepositoryRoot $tempRoot -Path $fullPath -HashPolicy ([string]$entry[0].hash_policy) -CommitRepresented ([string]$entry[0].commit_represented) -State ([string]$entry[0].state)
            $entry[0].canonical_byte_size=[long]$identity.canonical_byte_size
            $entry[0].canonical_sha256=$identity.canonical_sha256
            $entry[0].raw_working_tree_byte_size=[long]$identity.raw_working_tree_byte_size
            $entry[0].raw_working_tree_sha256=$identity.raw_working_tree_sha256
            $entry[0].byte_size=[long]$identity.canonical_byte_size
            $entry[0].sha256=$identity.canonical_sha256
            $entry[0].working_tree_line_endings=$identity.working_tree_line_endings
            $entry[0].raw_and_canonical_differ=$identity.raw_and_canonical_differ
        }
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
            $entry=@($manifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
            Set-ManifestEntryFileIdentity -Manifest $manifest -RelativePath ([string]$entry[0].relative_path)
            Write-ChatpadUtf8NoBomJson $tempManifestPath $manifest
            Push-Location $tempRoot
            try {
                $previousErrorActionPreference=$ErrorActionPreference
                $ErrorActionPreference='Continue'
                $outputLines=@(& $childPowerShell -NoProfile -ExecutionPolicy Bypass -File $validatorRelative -ManifestPath $ManifestPath 2>&1)
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
                    $subsetValidationDefects=[Collections.Generic.List[object]]::new()
                    $actualAssertions=Get-ChatpadIntegerPropertySum -Items ([object[]]@($suite.fixtures|Where-Object category -eq $case.category)) -PropertyName assertion_count -DefectCount ([ref]$subsetDefects) -Defects $subsetValidationDefects -Location "regression.$($case.id).fixtures"
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
                child_runtime_executable=$childPowerShell
                child_manifest_path=$ManifestPath
                child_manifest_argument_forwarded=$true
            })
        }

        function Set-AssertionDependentTotals {
            param(
                [Parameter(Mandatory)][object]$Manifest,
                [Parameter(Mandatory)][object]$Suite,
                [Parameter(Mandatory)][string]$Category,
                [Parameter(Mandatory)][long]$OldValue,
                [Parameter(Mandatory)][long]$NewValue
            )
            $delta=$NewValue-$OldValue
            $changed=[Collections.Generic.List[object]]::new()
            foreach($field in @('fixture_assertion_sum','record_assertion_sum','assertion_count','harness_assertion_sum','category_assertion_sum')){
                if($null -ne $Suite.PSObject.Properties[$field]){
                    $before=[long]$Suite.PSObject.Properties[$field].Value
                    $Suite.PSObject.Properties[$field].Value=$before+$delta
                    $changed.Add([pscustomobject]@{location='suite';field=$field;before=$before;after=$Suite.PSObject.Properties[$field].Value})
                }
            }
            $suiteCategory=@($Suite.category_totals|Where-Object category -eq $Category)
            if($suiteCategory.Count -eq 1){
                $before=[long]$suiteCategory[0].assertion_count
                $suiteCategory[0].assertion_count=$before+$delta
                $changed.Add([pscustomobject]@{location="suite.category_totals.$Category";field='assertion_count';before=$before;after=$suiteCategory[0].assertion_count})
            }
            foreach($field in @('fixture_assertion_sum','record_assertion_sum','assertion_count','harness_assertion_sum','category_assertion_sum')){
                if($null -ne $Manifest.readiness.PSObject.Properties[$field]){
                    $before=[long]$Manifest.readiness.PSObject.Properties[$field].Value
                    $Manifest.readiness.PSObject.Properties[$field].Value=$before+$delta
                    $changed.Add([pscustomobject]@{location='manifest.readiness';field=$field;before=$before;after=$Manifest.readiness.PSObject.Properties[$field].Value})
                }
            }
            $manifestCategory=@($Manifest.readiness.category_totals|Where-Object category -eq $Category)
            if($manifestCategory.Count -eq 1){
                $before=[long]$manifestCategory[0].assertion_count
                $manifestCategory[0].assertion_count=$before+$delta
                $changed.Add([pscustomobject]@{location="manifest.readiness.category_totals.$Category";field='assertion_count';before=$before;after=$manifestCategory[0].assertion_count})
            }
            return @($changed)
        }

        function Invoke-CountCorruptionCase {
            param(
                [Parameter(Mandatory)][string]$CaseId,
                [Parameter(Mandatory)][string]$Group,
                [object]$MalformedValue,
                [switch]$RemoveProperty,
                [Nullable[long]]$CoercedTotalValue,
                [Parameter(Mandatory)][string]$ExpectedValidatorResult,
                [Parameter(Mandatory)][int]$ExpectedExitCode,
                [string]$ExpectedDefectPattern='INVALID_INTEGER_COUNT'
            )
            [IO.File]::WriteAllText($tempManifestPath,$baselineManifestText,[Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($tempSuitePath,$baselineSuiteText,[Text.UTF8Encoding]::new($false))
            $manifest=Get-Content -LiteralPath $tempManifestPath -Raw|ConvertFrom-Json
            $suite=Get-Content -LiteralPath $tempSuitePath -Raw|ConvertFrom-Json
            $target=@($suite.fixtures|Where-Object category -eq 'harness-self-test'|Select-Object -First 1)
            if($target.Count -ne 1){throw "Cannot locate target harness record for $CaseId."}
            $record=$target[0]
            $recordId=[string]$record.fixture_id
            $category=[string]$record.category
            $originalValue=[long]$record.assertion_count
            if($RemoveProperty){
                [void]$record.PSObject.Properties.Remove('assertion_count')
            } else {
                $record.assertion_count=$MalformedValue
            }
            $dependentChanges=@()
            if($null -ne $CoercedTotalValue){
                $dependentChanges=Set-AssertionDependentTotals -Manifest $manifest -Suite $suite -Category $category -OldValue $originalValue -NewValue $CoercedTotalValue
            }
            Write-ChatpadUtf8NoBomJson $tempSuitePath $suite
            $entry=@($manifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
            Set-ManifestEntryFileIdentity -Manifest $manifest -RelativePath ([string]$entry[0].relative_path)
            Write-ChatpadUtf8NoBomJson $tempManifestPath $manifest
            Push-Location $tempRoot
            try {
                $previousErrorActionPreference=$ErrorActionPreference
                $ErrorActionPreference='Continue'
                $outputLines=@(& $childPowerShell -NoProfile -ExecutionPolicy Bypass -File $validatorRelative -ManifestPath $ManifestPath 2>&1)
                $exitCode=$LASTEXITCODE
            } finally {
                $ErrorActionPreference=$previousErrorActionPreference
                Pop-Location
            }
            $outputText=($outputLines|Out-String)
            $parsed=$null
            try { $parsed=$outputText|ConvertFrom-Json } catch { $parsed=$null }
            $propertyNotFound=[bool]($outputText -match 'PropertyNotFound')
            $countDefects=@()
            if($null -ne $parsed -and $null -ne $parsed.accounting_details){
                $countDefects=@($parsed.accounting_details.count_validation_defects)
            }
            $defectText=($countDefects|ConvertTo-Json -Depth 8)
            $matchesExpectedDefect=if($ExpectedDefectPattern){[bool]($defectText -match [regex]::Escape($ExpectedDefectPattern))}else{$true}
            $casePassed=(
                $exitCode -eq $ExpectedExitCode -and
                $null -ne $parsed -and
                [string]$parsed.result -eq $ExpectedValidatorResult -and
                -not $propertyNotFound -and
                $matchesExpectedDefect
            )
            [pscustomobject][ordered]@{
                case=$CaseId
                group=$Group
                original_record_id=$recordId
                original_assertion_count=$originalValue
                malformed_assertion_count=if($RemoveProperty){'<missing>'}else{[string]$MalformedValue}
                dependent_total_changes=@($dependentChanges)
                process_exit_code=$exitCode
                validator_result=if($null-ne$parsed){$parsed.result}else{'UNPARSED'}
                expected_validator_result=$ExpectedValidatorResult
                total_defect_count=if($null-ne$parsed){$parsed.total_defects}else{$null}
                record_defect_count=if($null-ne$parsed){$parsed.accounting_details.record_defect_count}else{$null}
                accounting_defect_count=if($null-ne$parsed){$parsed.defects.accounting}else{$null}
                uncontrolled_exception_count=if($null-ne$parsed -and -not $propertyNotFound){0}else{1}
                property_not_found=$propertyNotFound
                invalid_integer_defects=@($countDefects)
                expected_defect_observed=$matchesExpectedDefect
                coerced_total_value_used_for_temp_bypass_reproduction=if($null -ne $CoercedTotalValue){$CoercedTotalValue}else{$null}
                rounded_or_coerced_value_accepted=($null-ne$parsed -and $parsed.result -eq 'PASS' -and $null -ne $CoercedTotalValue)
                output_parsed=[bool]($null-ne$parsed)
                case_passed=$casePassed
                child_runtime_executable=$childPowerShell
                child_manifest_path=$ManifestPath
                child_manifest_argument_forwarded=$true
            }
        }

        $additionalCases=@(
            @{CaseId='F1-fractional-unchanged-totals';Group='fractional';MalformedValue=[decimal]'1.5';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.FRACTIONAL'},
            @{CaseId='F2-fractional-self-consistent-coerced-totals';Group='fractional';MalformedValue=[decimal]'1.5';CoercedTotalValue=[long]2;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.FRACTIONAL'},
            @{CaseId='F3-second-fractional-0.1';Group='fractional';MalformedValue=[decimal]'0.1';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.FRACTIONAL'},
            @{CaseId='F4-oversized-integer';Group='fractional';MalformedValue=[decimal]'9223372036854775808';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.OUT_OF_RANGE'},
            @{CaseId='F5-integer-valued-decimal-1.0';Group='fractional';MalformedValue=[decimal]'1.0';ExpectedValidatorResult='PASS';ExpectedExitCode=0;ExpectedDefectPattern=''},
            @{CaseId='M1-missing-property';Group='malformed-count-matrix';RemoveProperty=$true;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.MISSING'},
            @{CaseId='M2-null';Group='malformed-count-matrix';MalformedValue=$null;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.NULL'},
            @{CaseId='M3-nonnumeric-string';Group='malformed-count-matrix';MalformedValue='abc';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.STRING'},
            @{CaseId='M4-numeric-looking-string';Group='malformed-count-matrix';MalformedValue='1';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.STRING'},
            @{CaseId='M5-boolean';Group='malformed-count-matrix';MalformedValue=$true;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.BOOLEAN'},
            @{CaseId='M6-array';Group='malformed-count-matrix';MalformedValue=@(1);ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.ARRAY'},
            @{CaseId='M7-object';Group='malformed-count-matrix';MalformedValue=[pscustomobject]@{value=1};ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.OBJECT'},
            @{CaseId='M8-negative-integer';Group='malformed-count-matrix';MalformedValue=-1;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.NEGATIVE'},
            @{CaseId='M9-fractional-number';Group='malformed-count-matrix';MalformedValue=[decimal]'2.0001';CoercedTotalValue=[long]2;ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.FRACTIONAL'},
            @{CaseId='M10-oversized-numeric-value';Group='malformed-count-matrix';MalformedValue=[decimal]'9223372036854775808';ExpectedValidatorResult='FAIL';ExpectedExitCode=1;ExpectedDefectPattern='INVALID_INTEGER_COUNT.OUT_OF_RANGE'}
        )
        foreach($caseSpec in $additionalCases){
            $invokeParams=@{
                CaseId=$caseSpec.CaseId
                Group=$caseSpec.Group
                ExpectedValidatorResult=$caseSpec.ExpectedValidatorResult
                ExpectedExitCode=$caseSpec.ExpectedExitCode
                ExpectedDefectPattern=$caseSpec.ExpectedDefectPattern
            }
            if($caseSpec.ContainsKey('MalformedValue')){$invokeParams.MalformedValue=$caseSpec.MalformedValue}
            if($caseSpec.ContainsKey('RemoveProperty')){$invokeParams.RemoveProperty=$true}
            if($caseSpec.ContainsKey('CoercedTotalValue')){$invokeParams.CoercedTotalValue=$caseSpec.CoercedTotalValue}
            $results.Add((Invoke-CountCorruptionCase @invokeParams))
        }
        function Invoke-HashPolicyCorruptionCase {
            param(
                [Parameter(Mandatory)][string]$CaseId,
                [Parameter(Mandatory)][scriptblock]$Mutate,
                [Parameter(Mandatory)][string]$ExpectedDefect
            )
            [IO.File]::WriteAllText($tempManifestPath,$baselineManifestText,[Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($tempSuitePath,$baselineSuiteText,[Text.UTF8Encoding]::new($false))
            $manifest=Get-Content -LiteralPath $tempManifestPath -Raw|ConvertFrom-Json
            $target=@($manifest.entries|Where-Object state -eq 'tracked'|Where-Object content_classification -eq 'text'|Select-Object -First 1)
            if($target.Count-ne1){throw "Cannot locate tracked text identity for $CaseId."}
            & $Mutate $manifest $target[0]
            Write-ChatpadUtf8NoBomJson $tempManifestPath $manifest
            Push-Location $tempRoot
            try {
                $previousErrorActionPreference=$ErrorActionPreference
                $ErrorActionPreference='Continue'
                $outputLines=@(& $childPowerShell -NoProfile -ExecutionPolicy Bypass -File $validatorRelative -ManifestPath $ManifestPath 2>&1)
                $exitCode=$LASTEXITCODE
            } finally {
                $ErrorActionPreference=$previousErrorActionPreference
                Pop-Location
            }
            $outputText=($outputLines|Out-String)
            try{$parsed=$outputText|ConvertFrom-Json}catch{$parsed=$null}
            $observed=if($null-ne$parsed){[int]$parsed.defects.$ExpectedDefect}else{0}
            [pscustomobject][ordered]@{
                case=$CaseId
                group='hash-policy'
                process_exit_code=$exitCode
                validator_result=if($null-ne$parsed){$parsed.result}else{'UNPARSED'}
                expected_defect=$ExpectedDefect
                expected_defect_count=$observed
                uncontrolled_exception_count=if($null-ne$parsed){0}else{1}
                property_not_found=[bool]($outputText-match'PropertyNotFound')
                output_parsed=[bool]($null-ne$parsed)
                case_passed=($exitCode-eq1-and$null-ne$parsed-and$parsed.result-eq'FAIL'-and$observed-ge1-and$outputText-notmatch'PropertyNotFound')
                child_runtime_executable=$childPowerShell
                child_manifest_path=$ManifestPath
                child_manifest_argument_forwarded=$true
            }
        }
        $results.Add((Invoke-HashPolicyCorruptionCase -CaseId 'H1-missing-hash-policy' -ExpectedDefect hash_policy -Mutate {param($manifest,$entry) [void]$entry.PSObject.Properties.Remove('hash_policy')}))
        $results.Add((Invoke-HashPolicyCorruptionCase -CaseId 'H2-unknown-hash-policy' -ExpectedDefect hash_policy -Mutate {param($manifest,$entry) $entry.hash_policy='unknown_policy'}))
        $results.Add((Invoke-HashPolicyCorruptionCase -CaseId 'H3-raw-policy-on-tracked-text' -ExpectedDefect hash_policy -Mutate {param($manifest,$entry) $entry.hash_policy='raw_file_bytes'}))
        $results.Add((Invoke-HashPolicyCorruptionCase -CaseId 'H4-canonical-hash-mismatch' -ExpectedDefect hash -Mutate {param($manifest,$entry) $entry.canonical_sha256=('0'*64);$entry.sha256=('0'*64)}))
        $results.Add((Invoke-HashPolicyCorruptionCase -CaseId 'H5-canonical-size-mismatch' -ExpectedDefect size -Mutate {param($manifest,$entry) $entry.canonical_byte_size=[long]$entry.canonical_byte_size+1;$entry.byte_size=[long]$entry.byte_size+1}))
        $invalidBooleanCases=@(
            @{id='missing';missing=$true;value=$null;expected_code='METADATA_BOOLEAN.MISSING'},
            @{id='null';missing=$false;value=$null;expected_code='METADATA_BOOLEAN.NULL'},
            @{id='numeric-zero';missing=$false;value=[long]0;expected_code='METADATA_BOOLEAN.INVALID_TYPE.NUMBER'},
            @{id='numeric-one';missing=$false;value=[long]1;expected_code='METADATA_BOOLEAN.INVALID_TYPE.NUMBER'},
            @{id='numeric-other';missing=$false;value=[long]2;expected_code='METADATA_BOOLEAN.INVALID_TYPE.NUMBER'},
            @{id='string-true';missing=$false;value='true';expected_code='METADATA_BOOLEAN.INVALID_TYPE.STRING'},
            @{id='string-false';missing=$false;value='false';expected_code='METADATA_BOOLEAN.INVALID_TYPE.STRING'},
            @{id='empty-string';missing=$false;value='';expected_code='METADATA_BOOLEAN.INVALID_TYPE.EMPTY_STRING'},
            @{id='array';missing=$false;value=[object[]]@();expected_code='METADATA_BOOLEAN.INVALID_TYPE.ARRAY'},
            @{id='object';missing=$false;value=[pscustomobject]@{invalid=$true};expected_code='METADATA_BOOLEAN.INVALID_TYPE.OBJECT'}
        )
        foreach($expectation in (Get-ChatpadMetadataReviewBooleanExpectations).GetEnumerator()){
            foreach($invalidCase in $invalidBooleanCases){
                $container=[pscustomobject]@{}
                if(-not$invalidCase.missing){
                    $container|Add-Member -NotePropertyName $expectation.Key -NotePropertyValue $invalidCase.value
                }
                $defect=Test-ChatpadRequiredBooleanProperty -Container $container -PropertyName $expectation.Key -Location 'manifest.compiled_artifact_metadata_review_design_gate' -ExpectedValue $expectation.Value
                $results.Add([pscustomobject][ordered]@{
                    case="MB-$($expectation.Key)-$($invalidCase.id)"
                    group='metadata-boolean-type'
                    field_path="manifest.compiled_artifact_metadata_review_design_gate.$($expectation.Key)"
                    mutation=$invalidCase.id
                    validator_result=if($null-ne$defect){'FAIL'}else{'PASS'}
                    expected_defect=$invalidCase.expected_code
                    observed_defect=if($null-ne$defect){$defect.defect_code}else{''}
                    expected_type=if($null-ne$defect){$defect.expected_type}else{''}
                    actual_type=if($null-ne$defect){$defect.actual_type}else{''}
                    actual_value_category=if($null-ne$defect){$defect.actual_value_category}else{''}
                    uncontrolled_exception_count=0
                    property_not_found=$false
                    output_parsed=$true
                    case_passed=($null-ne$defect-and$defect.defect_code-eq$invalidCase.expected_code-and$defect.expected_type-eq'Boolean')
                })
            }
        }
        $invalidNativeExecutionStatuses=@(
            @{id='missing';missing=$true;value=$null;expected_code='NATIVE_EXECUTION_STATUS.MISSING'},
            @{id='null';missing=$false;value=$null;expected_code='NATIVE_EXECUTION_STATUS.NULL'},
            @{id='empty';missing=$false;value='';expected_code='NATIVE_EXECUTION_STATUS.EMPTY'},
            @{id='unknown';missing=$false;value='UNKNOWN';expected_code='NATIVE_EXECUTION_STATUS.UNKNOWN_OR_IMPLEMENTED'},
            @{id='implemented';missing=$false;value='IMPLEMENTED';expected_code='NATIVE_EXECUTION_STATUS.UNKNOWN_OR_IMPLEMENTED'}
        )
        foreach($invalidStatus in $invalidNativeExecutionStatuses){
            $container=[pscustomobject]@{}
            if(-not$invalidStatus.missing){
                $container|Add-Member -NotePropertyName native_execution_status -NotePropertyValue $invalidStatus.value
            }
            $defect=Test-ChatpadNativeExecutionStatusValue -Container $container
            $results.Add([pscustomobject][ordered]@{
                case="NES-$($invalidStatus.id)"
                group='native-execution-status'
                field_path='manifest.native_execution_status'
                mutation=$invalidStatus.id
                validator_result=if($null-ne$defect){'FAIL'}else{'PASS'}
                expected_defect=$invalidStatus.expected_code
                observed_defect=if($null-ne$defect){$defect.defect_code}else{''}
                expected_type=if($null-ne$defect){$defect.expected_type}else{''}
                actual_type=if($null-ne$defect){$defect.actual_type}else{''}
                actual_value_category=if($null-ne$defect){$defect.actual_value_category}else{''}
                uncontrolled_exception_count=0
                property_not_found=$false
                output_parsed=$true
                case_passed=($null-ne$defect-and$defect.defect_code-eq$invalidStatus.expected_code)
            })
        }
        $failed=@($results|Where-Object{
            if($null -ne $_.PSObject.Properties['case_passed']){-not $_.case_passed}
            else {
                $_.process_exit_code -eq 0 -or
                $_.validator_result -ne 'FAIL' -or
                $_.accounting_defect_count -lt 1 -or
                $_.uncontrolled_exception_count -ne 0 -or
                $_.property_not_found
            }
        })
        [pscustomobject][ordered]@{
            schema_version='chatpad-runtime-bringup-manifest-corruption-regression-v1'
            result=if($failed.Count){'FAIL'}else{'PASS'}
            case_count=$results.Count
            failed_case_count=$failed.Count
            parent_runtime=$PSVersionTable.PSVersion.ToString()
            child_runtime_executable=$childPowerShell
            requested_manifest_path=$ManifestPath
            validation_mode=if($NoArtifactOpenDesignGateAudit){'NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT'}else{'STANDARD_MANIFEST_CORRUPTION_REGRESSION'}
            artifact_opening_performed=$false
            compiled_output_hash_verification_performed=$false
            metadata_parsing_performed=$false
            metadata_boolean_field_count=(Get-ChatpadMetadataReviewBooleanExpectations).Count
            metadata_boolean_invalid_type_case_count=$invalidBooleanCases.Count
            metadata_boolean_regression_case_count=((Get-ChatpadMetadataReviewBooleanExpectations).Count*$invalidBooleanCases.Count)
            native_execution_status_regression_case_count=$invalidNativeExecutionStatuses.Count
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

if($RunTask8ERegression){
    $regression=Invoke-ChatpadTask8ERegression -ManifestPath $ManifestPath
    $regression|ConvertTo-Json -Depth 8
    if($regression.result-ne'PASS'){exit 1}
    exit 0
}

if($RunTask8FRegression){
    $regression=Invoke-ChatpadTask8FRegression -ManifestPath $ManifestPath
    $regression|ConvertTo-Json -Depth 8
    if($regression.result-ne'PASS'){exit 1}
    exit 0
}

$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
$manifest=Get-Content -LiteralPath (Join-Path $root $ManifestPath) -Raw|ConvertFrom-Json
$entries=@($manifest.entries)
$defects=[ordered]@{missing=0;duplicate_id=@($entries|Group-Object id|Where-Object Count -gt 1).Count;duplicate_path=@($entries|Group-Object relative_path|Where-Object Count -gt 1).Count;hash=0;size=0;hash_policy=0;state=0;containment=0;declared_result=0;top_level=0;task_8e=0;task_8f=0;compile_validation=0;metadata_review_gate=0;fixture_totals=0;accounting=0;observer_provenance=0;evidence_binding=0;psscriptanalyzer=0;identity=0;unsupported_pass=0;powershell_inventory=0;sample_validation=0;lifecycle=0;malformed_totality=0;stop_linkage=0}
$accountingDetails=[ordered]@{}
$readinessCounts=[ordered]@{}
$parserEvidencePathRegression=[ordered]@{result='NOT_RUN';case_count=0;passed_count=0;failed_count=0;cases=@()}
if($RunParserEvidencePathRegression){
    $pathCases=@(
        [pscustomobject]@{id='standard-remediation';path='artifacts/logs/static-metadata-parser-preflight-output-remediation/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='independent-audit';path='artifacts/logs/independent-static-metadata-parser-file-scope-audit-1bdba8c/windows/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing';path='artifacts/logs/static-parser-real-artifact-authorization-plumbing/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing-independent-audit';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-audit-cb34346/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing-independent-remediation';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-cb34346/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing-independent-remediation-audit';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2d7a721/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing-independent-remediation-audit-uppercase-hex';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2D7A721/static-metadata-parser-synthetic-validation.json';expected=$true},
        [pscustomobject]@{id='authorization-plumbing-independent-missing-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-audit/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-independent-nonhex-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-audit-notasha/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-missing-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-nonhex-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-notasha/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-short-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2d7a72/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-long-sha';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-extra-suffix';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2d7a721-extra/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-lookalike-prefix';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-review-2d7a721/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-traversal';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2d7a721/../docs/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-remediation-audit-mixed-traversal';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-2d7a721\..\legacy/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-broad-independent-parser';path='artifacts/logs/independent-static-parser-anything-2d7a721/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-broad-real-artifact';path='artifacts/logs/independent-static-parser-real-artifact-anything-2d7a721/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-lookalike';path='artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-review-cb34346/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='authorization-plumbing-nested-real-artifact';path='artifacts/logs/static-parser-real-artifact-authorization-plumbing/real-artifact/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='non-parser-root';path='artifacts/logs/unrelated-audit/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='real-artifact-root';path='artifacts/compile-only/native-interop/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='production-driver-root';path='driver/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='package-signing-staging-root';path='packaging/signing/staging/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='binary-output-root';path='artifacts/bin/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='legacy-root';path='legacy/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='protected-tracked-path';path='docs/evidence/static-metadata-parser-synthetic-validation.json';expected=$false},
        [pscustomobject]@{id='missing-path';path=$null;expected=$false},
        [pscustomobject]@{id='empty-path';path='';expected=$false},
        [pscustomobject]@{id='protected-artifact-name';path='artifacts/logs/static-metadata-parser-preflight-output-remediation/Chatpad.NativeInterop.CompileOnlyValidation.dll';expected=$false}
    )
    $pathResults=@($pathCases|ForEach-Object{
        $actual=Test-ChatpadApprovedParserEvidencePath -Path $_.path
        [pscustomobject][ordered]@{case_id=$_.id;path=$_.path;expected=$_.expected;actual=$actual;result=if($actual-eq$_.expected){'PASS'}else{'FAIL'}}
    })
    $pathFailures=@($pathResults|Where-Object result -ne 'PASS')
    $parserEvidencePathRegression=[ordered]@{result=if($pathFailures.Count){'FAIL'}else{'PASS'};case_count=$pathResults.Count;passed_count=@($pathResults|Where-Object result -eq 'PASS').Count;failed_count=$pathFailures.Count;cases=$pathResults}
    if($pathFailures.Count){$defects.metadata_review_gate++}
}
$canonicalManifestEntryCount=@($entries|Where-Object{
    [string]$_.relative_path -eq 'docs/evidence/runtime-bringup-readiness-manifest.json'
}).Count
if($canonicalManifestEntryCount-ne0){$defects.top_level++}
foreach($entry in $entries){
    $full=[IO.Path]::GetFullPath((Join-Path $root ([string]$entry.relative_path)))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$defects.containment++;continue}
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$defects.missing++;continue}
    if($entry.state-notin@('tracked','ignored')){$defects.state++}
    $policyProperty=$entry.PSObject.Properties['hash_policy']
    $classificationProperty=$entry.PSObject.Properties['content_classification']
    $commitProperty=$entry.PSObject.Properties['commit_represented']
    if($null-eq$policyProperty-or$policyProperty.Value-notin@('canonical_lf_text','raw_file_bytes')-or$null-eq$classificationProperty-or$null-eq$commitProperty-or[string]$commitProperty.Value-notmatch'^[0-9a-f]{40}$'){
        $defects.hash_policy++
    } else {
        $policy=[string]$policyProperty.Value
        $classification=[string]$classificationProperty.Value
        if(($classification-eq'text'-and$policy-ne'canonical_lf_text')-or($classification-eq'binary'-and$policy-ne'raw_file_bytes')-or($classification-notin@('text','binary'))){$defects.hash_policy++}
        else {
            try {
                $actual=Get-ChatpadEvidenceFileIdentity -RepositoryRoot $root -Path $full -HashPolicy $policy -CommitRepresented ([string]$commitProperty.Value) -State ([string]$entry.state)
                if($null-eq$entry.PSObject.Properties['canonical_byte_size']-or$null-eq$entry.PSObject.Properties['byte_size']-or[long]$entry.canonical_byte_size-ne[long]$actual.canonical_byte_size-or[long]$entry.byte_size-ne[long]$actual.canonical_byte_size){$defects.size++}
                if($null-eq$entry.PSObject.Properties['canonical_sha256']-or$null-eq$entry.PSObject.Properties['sha256']-or[string]$entry.canonical_sha256-cne$actual.canonical_sha256-or[string]$entry.sha256-cne$actual.canonical_sha256){$defects.hash++}
                if($null-eq$entry.PSObject.Properties['raw_working_tree_byte_size']-or$null-eq$entry.PSObject.Properties['raw_working_tree_sha256']-or$null-eq$entry.PSObject.Properties['raw_and_canonical_differ']-or$null-eq$entry.PSObject.Properties['line_ending_policy']){$defects.hash_policy++}
            } catch {
                $defects.hash_policy++
            }
        }
    }
    if($entry.evidence_classification-ne'synthetic'){$defects.declared_result++}
}
$manifestPolicy=if($null-ne$manifest.PSObject.Properties['identity_policy']){$manifest.identity_policy}else{$null}
if($null-eq$manifestPolicy-or[string]$manifestPolicy.schema_version-ne'chatpad-evidence-file-identity-policy-v1'-or[string]$manifestPolicy.tracked_text_input_policy-ne'canonical_lf_text'-or[string]$manifestPolicy.binary_output_policy-ne'raw_file_bytes'){$defects.hash_policy++}
if($manifest.schema_version-ne'chatpad-runtime-bringup-readiness-manifest-v4'-or$manifest.real_artifact_static_metadata_review_completed-ne$true-or$manifest.framework_status-ne'PASS'-or$manifest.live_installation_readiness-ne'BLOCKED'-or$manifest.current_gate-ne'BLOCKED_NATIVE_ADAPTER_PRODUCTION_BACKEND_NOT_INDEPENDENTLY_AUDITED'-or$manifest.capability_blocker-ne'BLOCKED_NATIVE_ADAPTER_PRODUCTION_BACKEND_NOT_INDEPENDENTLY_AUDITED'-or$manifest.live_adapter_status-ne'SCAFFOLD_NON_EXECUTING'-or$manifest.live_binding_authorized-ne$false-or$manifest.manifest_generation_mode-notin@('NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT','STANDARD_READINESS_RESULT')){$defects.top_level++}
if($NoArtifactOpenDesignGateAudit-and$manifest.manifest_generation_mode-ne'NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT'){$defects.top_level++}
$task8EValidation=Test-ChatpadTask8EManifestEvidence -RepositoryRoot $root -Manifest $manifest
$defects.task_8e=[int]$task8EValidation.defect_count
$task8FValidation=Test-ChatpadTask8FManifestEvidence -RepositoryRoot $root -Manifest $manifest
$defects.task_8f=[int]$task8FValidation.defect_count
$executionDesignProperty=$manifest.PSObject.Properties['native_adapter_execution_design_gate']
if($null-eq$executionDesignProperty-or$null-eq$executionDesignProperty.Value-or$executionDesignProperty.Value-is[array]){
    $defects.top_level++
}
else{
    $executionDesign=$executionDesignProperty.Value
    $executionCounters=$executionDesign.PSObject.Properties['safety_counters']
    if($executionDesign.schema_version-ne'chatpad-native-adapter-execution-design-gate-v1'-or
        $executionDesign.status-ne'NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO'-or
        $executionDesign.fail_closed_scaffolding_status-ne'NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO'-or
        $executionDesign.fail_closed_scaffolding_implementation_commit-ne'7560fc242a39228d6a95f42ff908bb4be438d6ad'-or
        $executionDesign.fail_closed_scaffolding_audit_status-ne'NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
        $executionDesign.fail_closed_scaffolding_audit_acceptance_commit-ne'748ba24b3e795cd70b3325b6a54fb88569427ed6'-or
        $executionDesign.fail_closed_scaffolding_audit_remediation_commit-ne'af41a8eaeea96dcbcad75fb2e261c4352b2a468e'-or
        $executionDesign.non_live_implementation_status-ne'NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO'-or
        $executionDesign.non_live_implementation_commit-ne'4522510a17354fe53d163546e16ff24af5fa0374'-or
        $executionDesign.non_live_implementation_audit_status-ne'NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
        $executionDesign.non_live_implementation_audit_target_commit-ne'5e7a6f39d0363121b8bd3f6e4b38ceb517889679'-or
        $executionDesign.non_live_implementation_audit_required-ne$false-or
        $executionDesign.current_gate-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
        $executionDesign.opened_from_commit-ne'cb80939a862d33efb1abf26a14d5c75d43a77b30'-or
        $executionDesign.design_document_path-ne'docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md'-or
        $executionDesign.implementation_status-ne'NOT_IMPLEMENTED'-or
        $executionDesign.execution_authorized-ne$false-or
        $executionDesign.independent_audit_required-ne$false-or
        $executionDesign.live_installation_readiness-ne'BLOCKED'-or
        $executionDesign.capability_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
        $executionDesign.static_metadata_lane_status-ne'ACCEPTED_CLOSED'-or
        (@($executionDesign.supported_operations)-join'|')-ne'Apply|Restore|Restart'-or
        (@($executionDesign.native_api_families)-join'|')-ne'SetupAPI|Newdev'-or
        (@($executionDesign.required_evidence)-join'|')-ne'EXACT_INSTANCE_BINDING|APPROVED_DEVICE_INSTANCE_IDENTITY|APPROVED_ARTIFACT_IDENTITY|APPROVED_ROLLBACK_RECOVERY_PLAN'-or
        (@($executionDesign.required_future_authorizations)-join'|')-ne'NATIVE_ADAPTER_IMPLEMENTATION|WINDOWS_MUTATION|DRIVER_PACKAGE_SIGNING_STAGING_WHEN_APPLICABLE|LIVE_EXECUTION'-or
        $null-eq$executionCounters-or$null-eq$executionCounters.Value-or$executionCounters.Value-is[array]){
        $defects.top_level++
    }
    else{
        foreach($counterName in @('native_library_load_attempts','entry_point_resolution_attempts','setupapi_newdev_invocation_attempts','device_query_attempts','windows_mutation_attempts','driver_action_attempts','authorization_rejections','uncertain_state_events')){
            $counterValidation=if($null-ne$executionCounters.Value.PSObject.Properties[$counterName]){
                Test-ChatpadExactIntegerCount -FieldName $counterName -Location 'manifest.native_adapter_execution_design_gate.safety_counters' -Value $executionCounters.Value.$counterName -AllowZero
            }else{$null}
            if($null-eq$counterValidation-or-not$counterValidation.valid-or$counterValidation.value-ne0){
                $defects.top_level++
            }
        }
    }
    $executionScopeProperty=$executionDesign.PSObject.Properties['execution_scope_boundary']
    if($null-eq$executionScopeProperty-or$null-eq$executionScopeProperty.Value-or$executionScopeProperty.Value-is[array]){
        $defects.top_level++
    }
    else{
        $executionScope=$executionScopeProperty.Value
        if($executionScope.schema_version-ne'chatpad-native-adapter-execution-scope-boundary-v1'-or
            $executionScope.status-ne'NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO'-or
            $executionScope.scope_boundary_commit-ne'4cdde55e392e78db8a7a38858fb2f436557fbe2e'-or
            $executionScope.audit_acceptance_status-ne'NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
            $executionScope.audit_acceptance_target-ne'f0b10d862d23d0ede28b1139c2ccb726bfcddc48'-or
            $executionScope.lane_closeout_result-ne'AUDIT_PASS_LANE_CLOSED_NO_NATIVE_IO'-or
            $executionScope.lane_closeout_audit_target-ne'd1372ba8f7812d24a09b87238793e78435ac4492'-or
            $executionScope.lane_closeout_commit-ne'e68ed58e3c5a2560c331f4b69dfe021ae54531e1'-or
            $executionScope.closeout_identity_audit_acceptance_status-ne'NATIVE_ADAPTER_EXECUTION_BOUNDARY_CLOSEOUT_IDENTITY_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
            $executionScope.closeout_identity_audit_acceptance_target-ne'9c9af5cf0cfdffde67a0f2b4e41e8eceb42d673f'-or
            $executionScope.final_lane_closeout_status-ne'NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO'-or
            $executionScope.final_lane_closeout_audit_target-ne'f7f6041d6987ea8e3752546bd4c9116c88fbe56a'-or
            $executionScope.opened_from_non_live_audit_acceptance_commit-ne'bb6cc27c2281e04dee2166c5a67e124092055f9f'-or
            (@($executionScope.required_operation_classes)-join'|')-ne'NATIVE_ADAPTER_APPLY|NATIVE_ADAPTER_RESTORE|NATIVE_ADAPTER_RESTART'-or
            $executionScope.required_authorized_operation_class_count-ne1-or
            $executionScope.authorization_statement_requirement-ne'EXACTLY_ONE_OPERATION_CLASS_BOUND_TO_IMPLEMENTATION_COMMIT_HOST_SESSION_EXPIRY_EVIDENCE_ROOT_AND_ENVELOPE_HASH'-or
            $executionScope.approved_real_artifact_identity_requirement-ne'EXACT_CANONICAL_PATH_POSITIVE_BYTE_SIZE_UPPERCASE_SHA256_AND_ORIGIN_EVIDENCE'-or
            $executionScope.approved_real_artifact_identity_present-ne$false-or
            $executionScope.native_entry_point_allowlist_requirement-ne'EXACT_ORDERED_LIBRARY_QUALIFIED_OPERATION_BOUND_REVIEWED_SUBSET_NO_WILDCARDS'-or
            $executionScope.native_entry_point_allowlist_present-ne$false-or
            $executionScope.setupapi_newdev_function_allowlist_requirement-ne'EXACT_ORDERED_OPERATION_BOUND_REVIEWED_SUBSET_NO_WILDCARDS'-or
            $executionScope.setupapi_newdev_function_allowlist_present-ne$false-or
            (@($executionScope.reviewed_declaration_ceiling_not_authorized)-join'|')-ne'SetupDiCreateDeviceInfoList|SetupDiDestroyDeviceInfoList|SetupDiOpenDeviceInfoW|SetupDiGetDeviceInstanceIdW|SetupDiGetDevicePropertyW|SetupDiGetDeviceRegistryPropertyW|SetupDiBuildDriverInfoList|SetupDiDestroyDriverInfoList|SetupDiEnumDriverInfoW|SetupDiGetDriverInfoDetailW|SetupDiGetDriverInstallParamsW|SetupDiSetSelectedDriverW|DiInstallDevice'-or
            $executionScope.device_instance_binding_requirement-ne'EXACT_CANONICAL_INSTANCE_ID_APPROVED_SNAPSHOT_TARGET_AND_PRIOR_DRIVER_IDENTITIES_AND_ORDINAL_REOPEN_COMPARISON'-or
            $executionScope.dry_run_evidence_requirement-ne'INDEPENDENTLY_AUDITED_ENVELOPE_BOUND_NO_MUTATION_DRY_RUN_WITH_ORDERED_CALLS_PRECONDITIONS_POSTCONDITIONS_CLEANUP_AND_ZERO_ACTION_COUNTERS'-or
            $executionScope.rollback_restore_plan_requirement-ne'INDEPENDENTLY_ACCEPTED_EXACT_PRIOR_DRIVER_IDENTITY_ORDERED_CALLS_CLEANUP_VERIFICATION_STOP_CONDITIONS_AND_MANUAL_RECOVERY'-or
            $executionScope.windows_mutation_classification_requirement-ne'EXACT_PER_CALL_MUTATION_CLASS_PRECONDITION_POSTCONDITION_FAILURE_STATE_CLEANUP_DUTY_AND_INTEGER_COUNTERS'-or
            $executionScope.operator_confirmation_requirement-ne'EXPLICIT_SINGLE_OPERATION_CONFIRMATION_BOUND_TO_ENVELOPE_HASH_INSTANCE_ARTIFACT_HOST_SESSION_OPERATION_AND_EXPIRY'-or
            $executionScope.pre_implementation_audit_required-ne$true-or
            $executionScope.post_implementation_audit_required-ne$true-or
            $executionScope.implementation_audit_grants_execution_authority-ne$false-or
            $executionScope.current_repository_satisfies_envelope-ne$false-or
            $executionScope.current_task_authorizes_execution-ne$false-or
            $executionScope.artifact_access_authorized-ne$false-or
            $executionScope.native_library_load_authorized-ne$false-or
            $executionScope.native_entry_point_resolution_authorized-ne$false-or
            $executionScope.setupapi_newdev_invocation_authorized-ne$false-or
            $executionScope.device_query_authorized-ne$false-or
            $executionScope.hardware_access_authorized-ne$false-or
            $executionScope.windows_mutation_authorized-ne$false-or
            $executionScope.driver_action_authorized-ne$false){$defects.top_level++}
    }
    $envelopeVerifierProperty=$executionDesign.PSObject.Properties['execution_envelope_verifier']
    if($null-eq$envelopeVerifierProperty-or$null-eq$envelopeVerifierProperty.Value-or$envelopeVerifierProperty.Value-is[array]){
        $defects.top_level++
    }
    else{
        $envelopeVerifier=$envelopeVerifierProperty.Value
        if($envelopeVerifier.schema_version-ne'chatpad-native-adapter-execution-envelope-verifier-v1'-or
            $envelopeVerifier.status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO'-or
            $envelopeVerifier.opened_from_closed_boundary_commit-ne'68099a441db5f8b517dbeb296ab234a9ee639bdb'-or
            $envelopeVerifier.implementation_commit_recorded-ne$false-or
            $envelopeVerifier.independent_implementation_audit_required-ne$false-or
            $envelopeVerifier.audit_acceptance_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
            $envelopeVerifier.accepted_audit_target_commit-ne'4849d1959cab9c289952655eb73e3279117779d2'-or
            $envelopeVerifier.accepted_audit_target_parent_commit-ne'68099a441db5f8b517dbeb296ab234a9ee639bdb'-or
            $envelopeVerifier.audit_acceptance_audit_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO'-or
            $envelopeVerifier.audit_acceptance_audit_target_commit-ne'b6bdd01588e9d72113dd9b09fcfa9baf2026424d'-or
            $envelopeVerifier.audit_pass_recorded_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO'-or
            $envelopeVerifier.audit_pass_recorded_target_commit-ne'f235879fe6d74dcc02dfe2e56297ef14e5a48800'-or
            $envelopeVerifier.audit_pass_accepted_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO'-or
            $envelopeVerifier.audit_pass_accepted_target_commit-ne'b64a672984b6e7db16765f13de385b22f3491f11'-or
            $envelopeVerifier.audit_pass_acceptance_audit_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO'-or
            $envelopeVerifier.audit_pass_acceptance_audit_target_commit-ne'75a083a684c79b729de04c770371fb6190c9c9e7'-or
            $envelopeVerifier.audit_pass_acceptance_audit_accepted_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_ACCEPTED_NO_NATIVE_IO'-or
            $envelopeVerifier.audit_pass_acceptance_audit_accepted_target_commit-ne'ba952444d9d3e306da8985e25b93b74aa5f6cff6'-or
            $envelopeVerifier.lane_closeout_status-ne'NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO'-or
            $envelopeVerifier.lane_closeout_audit_target_commit-ne'e271e5c8dd464ba0aeee82e4dc163b12ae28b8de'-or
            $envelopeVerifier.prior_audit_pass_acceptance_audit_accepted_target_commit-ne'ba952444d9d3e306da8985e25b93b74aa5f6cff6'-or
            $envelopeVerifier.prior_audit_pass_acceptance_audit_target_commit-ne'75a083a684c79b729de04c770371fb6190c9c9e7'-or
            $envelopeVerifier.prior_audit_pass_record_target_commit-ne'f235879fe6d74dcc02dfe2e56297ef14e5a48800'-or
            $envelopeVerifier.prior_audit_pass_transition_target_commit-ne'b6bdd01588e9d72113dd9b09fcfa9baf2026424d'-or
            $envelopeVerifier.prior_verifier_implementation_audit_target_commit-ne'4849d1959cab9c289952655eb73e3279117779d2'-or
            $envelopeVerifier.audit_acceptance_recorded-ne$true-or
            $envelopeVerifier.audit_acceptance_grants_execution_authority-ne$false-or
            $envelopeVerifier.declared_field_validation_only-ne$true-or
            (@($envelopeVerifier.supported_operation_classes)-join'|')-ne'Apply|Restore|Restart'-or
            $envelopeVerifier.missing_envelope_result-ne'BLOCKED'-or
            $envelopeVerifier.malformed_envelope_result-ne'BLOCKED'-or
            $envelopeVerifier.stale_envelope_result-ne'BLOCKED'-or
            $envelopeVerifier.future_live_envelope_result-ne'BLOCKED'-or
            $envelopeVerifier.structurally_complete_envelope_result-ne'BLOCKED'-or
            $envelopeVerifier.complete_envelope_authorizes_execution-ne$false-or
            $envelopeVerifier.current_state_denial-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
            $envelopeVerifier.execution_authorized-ne$false-or
            $envelopeVerifier.native_execution_status-ne'NOT_IMPLEMENTED'-or
            $envelopeVerifier.live_readiness-ne'BLOCKED'-or
            $envelopeVerifier.artifact_io_performed-ne$false-or
            $envelopeVerifier.compile_output_io_performed-ne$false-or
            $envelopeVerifier.static_metadata_parser_invoked-ne$false-or
            $envelopeVerifier.native_library_load_count-ne0-or
            $envelopeVerifier.entry_point_resolution_count-ne0-or
            $envelopeVerifier.setupapi_newdev_invocation_count-ne0-or
            $envelopeVerifier.device_query_count-ne0-or
            $envelopeVerifier.hardware_access_count-ne0-or
            $envelopeVerifier.windows_mutation_count-ne0-or
            $envelopeVerifier.driver_action_count-ne0-or
            $envelopeVerifier.focused_test_count-ne18-or
            $envelopeVerifier.no_artifact_io_traced_function_count-ne23-or
            $envelopeVerifier.no_artifact_io_forbidden_command_count-ne0-or
            $envelopeVerifier.no_artifact_io_forbidden_member_count-ne0){
            $defects.top_level++
        }
    }
    $executionAuditProperty=$executionDesign.PSObject.Properties['audit_acceptance']
    if($null-eq$executionAuditProperty-or$null-eq$executionAuditProperty.Value-or$executionAuditProperty.Value-is[array]){
        $defects.top_level++
    }
    else{
        $executionAudit=$executionAuditProperty.Value
        if($executionAudit.verdict-ne'AUDIT PASS'-or
            $executionAudit.accepted_audit_target-ne'd71c6a46b0066eb8bc48e8de14795c223cdaa00c'-or
            $executionAudit.failed_audit_target-ne'dddd4afab914c1929de5683d6822fde5cbf46c6a'-or
            $executionAudit.failed_audit_finding-ne'FAIL_CLOSED_PROBES_REACHED_COMPILE_OUTPUT_VALIDATION_AND_HASHED_REAL_DLL'-or
            $executionAudit.remediation_result-ne'UNSAFE_ARTIFACT_HASHING_PATH_REMOVED'-or
            $executionAudit.evidence_mode-ne'EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO'-or
            [int]$executionAudit.transitive_function_count-ne17-or
            $executionAudit.record_only_validator_reachable-ne$true-or
            [int]$executionAudit.full_compile_output_validator_reachable_count-ne0-or
            [int]$executionAudit.get_file_hash_reachable_count-ne0-or
            [int]$executionAudit.output_enumeration_reachable_count-ne0-or
            [int]$executionAudit.native_or_file_loading_member_reachable_count-ne0-or
            [int]$executionAudit.fixed_tracked_json_read_count-ne2-or
            $executionAudit.windows_powershell_no_artifact_io_regression-ne'PASS'-or
            $executionAudit.powershell_7_no_artifact_io_regression-ne'PASS'-or
            [int]$executionAudit.windows_powershell_blocked_operation_count-ne3-or
            [int]$executionAudit.powershell_7_blocked_operation_count-ne3-or
            $executionAudit.missing_or_malformed_evidence_fails_closed-ne$true-or
            $executionAudit.full_compile_output_validator_run-ne$false-or
            $executionAudit.static_metadata_parser_run-ne$false-or
            $executionAudit.real_dll_accessed-ne$false-or
            $executionAudit.native_library_loaded-ne$false-or
            $executionAudit.native_entry_point_resolved-ne$false-or
            $executionAudit.setupapi_newdev_invoked-ne$false-or
            $executionAudit.device_queried-ne$false-or
            $executionAudit.windows_mutated-ne$false-or
            $executionAudit.driver_action_performed-ne$false-or
            $executionAudit.accepted-ne$true){$defects.top_level++}
    }
}
$metadataReviewDefectRecords=[Collections.Generic.List[object]]::new()
$topLevelNativeExecutionDefect=Test-ChatpadNativeExecutionStatusValue -Container $manifest -Location 'manifest'
if($null-ne$topLevelNativeExecutionDefect){$metadataReviewDefectRecords.Add($topLevelNativeExecutionDefect)}
$auditProperty=$manifest.PSObject.Properties['native_interop_source_audit']
if($null -eq $auditProperty -or $null -eq $auditProperty.Value -or $auditProperty.Value -is [array]){$defects.top_level++}
else{
    $audit=$auditProperty.Value
    if($audit.verdict-ne'AUDIT PASS'-or$audit.audited_commit-ne'dbba70d74e99c211d47187697e19e528b381520a'-or$audit.compile_only_validation_authorized-ne$false-or$audit.native_compilation_occurred-ne$false-or$audit.native_loading_occurred-ne$false-or$audit.native_invocation_occurred-ne$false-or$audit.device_query_occurred-ne$false-or$audit.windows_mutation_occurred-ne$false){$defects.top_level++}
}
$compileProperty=$manifest.PSObject.Properties['native_interop_compile_only_validation']
if($null -eq $compileProperty -or $null -eq $compileProperty.Value -or $compileProperty.Value -is [array]){$defects.compile_validation++}
else{
    $compileRecord=$compileProperty.Value
    $compileEvidence=$compileRecord
    $recordResult=$compileRecord.PSObject.Properties['result']
    $recordDefectCount=$compileRecord.PSObject.Properties['defect_count']
    $recordEvidence=$compileRecord.PSObject.Properties['evidence']
    if($null -ne $recordResult -or $null -ne $recordEvidence){
        if($null -eq $recordResult -or $recordResult.Value -ne 'PASS'){$defects.compile_validation++}
        if($null -eq $recordDefectCount -or [int]$recordDefectCount.Value -ne 0){$defects.compile_validation++}
        if($null -eq $recordEvidence -or $null -eq $recordEvidence.Value -or $recordEvidence.Value -is [array]){
            $defects.compile_validation++
        } else {
            $compileEvidence=$recordEvidence.Value
        }
    }
    if($compileEvidence.schema_version-ne'chatpad-native-interop-compile-only-validation-v2'-or$compileEvidence.build_result.result-ne'PASS'-or[int]$compileEvidence.build_result.compiler_exit_code-ne0-or[int]$compileEvidence.build_result.warning_count-ne0-or[int]$compileEvidence.build_result.error_count-ne0){$defects.compile_validation++}
    if($compileEvidence.readiness_transition.previous_gate-ne'BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED'-or$compileEvidence.readiness_transition.resulting_readiness_gate-ne'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT'-or$compileEvidence.readiness_transition.remaining_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or$compileEvidence.readiness_transition.transition_allowed-ne$true){$defects.compile_validation++}
    foreach($name in @('assemblyLoaded','managedCodeExecuted','nativeInvocationOccurred','deviceQueryOccurred','exactInstanceAccessed','windowsMutationOccurred','producedAssemblyExecuted','testHostExecuted','reflectionInspectionUsed','postBuildExecutionOccurred')){
        if($null -eq $compileEvidence.prohibited_actions.PSObject.Properties[$name] -or [bool]$compileEvidence.prohibited_actions.$name -ne $false){$defects.compile_validation++}
    }
}
$reauditProperty=$manifest.PSObject.Properties['native_interop_compile_only_evidence_reaudit']
if($null-eq$reauditProperty-or$null-eq$reauditProperty.Value-or$reauditProperty.Value-is[array]){$defects.top_level++}
else{
    $reaudit=$reauditProperty.Value
    if($reaudit.verdict-ne'AUDIT PASS'-or
        $reaudit.audited_commit-ne'3e922470f2e46d5eeb4b6fe7500c4f105c608b3b'-or
        $reaudit.artifact_inventory_path-ne'artifacts/logs/independent-compile-only-evidence-reaudit-3e92247/artifact-inventory.json'-or
        [long]$reaudit.artifact_inventory_byte_size-ne49650-or
        $reaudit.artifact_inventory_sha256-ne'09E4CB50663849B7E2ADB6D91817A35E97DC12831CA5384128ABE2A72BFCFA5C'-or
        $reaudit.line_ending_stable_evidence_accepted-ne$true-or
        $reaudit.historical_v1_compile_output_preservation_required-ne$false-or
        $reaudit.current_v2_evidence_authoritative-ne$true-or
        $reaudit.current_v2_primary_dll_sha256-ne'77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'-or
        $reaudit.assembly_loading_occurred-ne$false-or
        $reaudit.reflection_occurred-ne$false-or
        $reaudit.compiled_assembly_execution_occurred-ne$false-or
        $reaudit.native_invocation_occurred-ne$false-or
        $reaudit.device_query_occurred-ne$false-or
        $reaudit.windows_mutation_occurred-ne$false-or
        $reaudit.accepted-ne$true){$defects.top_level++}
}
$metadataGateProperty=$manifest.PSObject.Properties['compiled_artifact_metadata_review_design_gate']
if($null-eq$metadataGateProperty-or$null-eq$metadataGateProperty.Value-or$metadataGateProperty.Value-is[array]){
    $metadataReviewDefectRecords.Add((New-ChatpadMetadataReviewDefect 'METADATA_REVIEW_GATE.INVALID_CONTAINER' 'manifest.compiled_artifact_metadata_review_design_gate' 'Object' $(if($null-eq$metadataGateProperty){$null}else{$metadataGateProperty.Value}) 'Metadata-review design-gate container is missing, null, or an array.'))
}
else{
    $metadataGate=$metadataGateProperty.Value
    if($metadataGate.status-ne'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED'-or
        $metadataGate.current_gate-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
        $metadataGate.real_artifact_review_authorization_transition_commit-ne'baab23aece902cbb06e11a308d9092fdc0f9ce0d'-or
        $metadataGate.runtime_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
        $metadataGate.artifact_location_classification-ne'IGNORED_COMPILE_ONLY_OUTPUT'-or
        $metadataGate.proposed_inspection_mode-ne'STATIC_BYTE_AND_METADATA_PARSING_ONLY'-or
        $metadataGate.independent_design_audit_verdict-ne'AUDIT PASS'-or
        $metadataGate.independent_design_audit_branch-ne'feature/runtime-bringup-compiled-artifact-metadata-review-design-gate-remediation'-or
        $metadataGate.independent_design_audit_commit-ne'49b41dad087a3d7e6f4db7f52cd51a0c17eed222'-or
        $metadataGate.independent_design_audit_artifact_inventory_path-ne'artifacts/logs/independent-metadata-review-design-gate-remediation-audit-49b41da/artifact-inventory.json'-or
        [long]$metadataGate.independent_design_audit_artifact_inventory_byte_size-ne22305-or
        $metadataGate.independent_design_audit_artifact_inventory_sha256-ne'2EED833A5CF5948126A766FFAAA87FD267E548DD32B2237E1DA5644BF7355A3B'){$defects.metadata_review_gate++}
    $statusBoundaryAuditProperty=$metadataGate.PSObject.Properties['status_boundary_audit_acceptance']
    if($null-eq$statusBoundaryAuditProperty-or$null-eq$statusBoundaryAuditProperty.Value-or$statusBoundaryAuditProperty.Value-is[array]){
        $defects.metadata_review_gate++
    }
    else{
        $statusBoundaryAudit=$statusBoundaryAuditProperty.Value
        if($statusBoundaryAudit.verdict-ne'AUDIT PASS'-or
            $statusBoundaryAudit.accepted_audit_target-ne'83eb4acf44d50d8c43a09f7827728763e726e9c2'-or
            $statusBoundaryAudit.initial_git_status_empty-ne$true-or
            $statusBoundaryAudit.final_git_status_empty-ne$true-or
            $statusBoundaryAudit.evidence_inventory_path-ne'artifacts/logs/real-artifact-static-metadata-review/evidence-inventory.json'-or
            $statusBoundaryAudit.evidence_inventory_self_reference_policy-ne'excluded_from_authoritative_size_hash'-or
            [int]$statusBoundaryAudit.evidence_inventory_physical_file_count-ne16-or
            [int]$statusBoundaryAudit.evidence_inventory_authoritative_file_count-ne15-or
            $statusBoundaryAudit.evidence_inventory_authoritative_validation-ne'15/15'-or
            $statusBoundaryAudit.evidence_inventory_self_entry_authoritative-ne$false-or
            [int]$statusBoundaryAudit.evidence_inventory_preflight_subtree_file_count-ne14-or
            $statusBoundaryAudit.review_evidence_path-ne'artifacts/logs/real-artifact-static-metadata-review/static-metadata-parser-real-artifact-review.json'-or
            $statusBoundaryAudit.review_evidence_sha256-ne'024693B23AA26C42CD2F9D5AB995956CEB202A76FBA5481264EF828AAEDF0875'-or
            $statusBoundaryAudit.review_evidence_result-ne'STATIC_METADATA_VALIDATED'-or
            $statusBoundaryAudit.approved_real_artifact_path-ne'artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll'-or
            $statusBoundaryAudit.approved_real_artifact_sha256-ne'77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'-or
            $statusBoundaryAudit.parser_source_net_change_from_eedf2a5-ne'NONE'-or
            $statusBoundaryAudit.premature_transition_from_6372adf_reverted-ne$true-or
            $statusBoundaryAudit.parser_rerun_occurred-ne$false-or
            $statusBoundaryAudit.real_dll_access_occurred-ne$false-or
            $statusBoundaryAudit.runtime_native_device_windows_driver_actions_occurred-ne$false-or
            $statusBoundaryAudit.static_metadata_lane_closed-ne$true){$defects.metadata_review_gate++}
    }
    $authorizationAuditProperty=$metadataGate.PSObject.Properties['authorization_plumbing_audit']
    if($null-eq$authorizationAuditProperty-or$null-eq$authorizationAuditProperty.Value-or$authorizationAuditProperty.Value-is[array]){
        $defects.metadata_review_gate++
    }
    else{
        $authorizationAudit=$authorizationAuditProperty.Value
        if($authorizationAudit.verdict-ne'AUDIT PASS'-or
            $authorizationAudit.accepted_remediation_commit-ne'dca0a9d794b4442de86d53a90e4aab74dfe68971'-or
            $authorizationAudit.base_commit-ne'2d7a721ce3172b338df0de56853a256b1170fb4a'-or
            $authorizationAudit.audit_summary_path-ne'artifacts/logs/independent-static-parser-auth-plumbing-audit-root-remediation-audit-dca0a9d/audit-summary.json'-or
            [long]$authorizationAudit.audit_summary_byte_size-ne2666-or
            $authorizationAudit.audit_summary_sha256-ne'FAB4EC641663902C779A65721EED1C481F7CD0FF5410E0E38D23B43A475403A5'-or
            $authorizationAudit.audit_inventory_path-ne'artifacts/logs/independent-static-parser-auth-plumbing-audit-root-remediation-audit-dca0a9d/evidence-inventory.json'-or
            [long]$authorizationAudit.audit_inventory_byte_size-ne7462-or
            $authorizationAudit.audit_inventory_sha256-ne'DF6FB3F45689D231F77E4C53B18E0B7B5D099B93BC90F8847460DB5033E2761F'-or
            $authorizationAudit.accepted-ne$true){$defects.metadata_review_gate++}
    }
    $parserDesignProperty=$metadataGate.PSObject.Properties['static_metadata_parser_implementation_design']
    if($null-eq$parserDesignProperty-or$null-eq$parserDesignProperty.Value-or$parserDesignProperty.Value-is[array]){
        $defects.metadata_review_gate++
    }
    else{
        $parserDesign=$parserDesignProperty.Value
        if($parserDesign.status-ne'DESIGN_AUDIT_ACCEPTED_PENDING_IMPLEMENTATION_AUTHORIZATION'-or
            $parserDesign.current_gate-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
            $parserDesign.real_artifact_review_authorization_transition_commit-ne'baab23aece902cbb06e11a308d9092fdc0f9ce0d'-or
            $parserDesign.transition_base_commit-ne'382aa85980408939a93043583b48e942ebfbf018'-or
            $parserDesign.design_document_path-ne'docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md'-or
            $parserDesign.preferred_technology-ne'SYSTEM_REFLECTION_METADATA_PEREADER'-or
            $parserDesign.target_framework-ne'net9.0'-or
            $parserDesign.independent_design_audit_verdict-ne'AUDIT PASS'-or
            $parserDesign.independent_design_audit_branch-ne'feature/runtime-bringup-static-metadata-parser-implementation-design'-or
            $parserDesign.independent_design_audit_commit-ne'468e8679388481e923a37a985055046f72480921'-or
            $parserDesign.independent_design_audit_artifact_inventory_path-ne'artifacts/logs/independent-static-metadata-parser-design-audit-468e867/artifact-inventory.json'-or
            [long]$parserDesign.independent_design_audit_artifact_inventory_byte_size-ne54161-or
            $parserDesign.independent_design_audit_artifact_inventory_sha256-ne'D43213A552CF61E793BABD2792D6B3329706EF9F2DB3DC46D401B66307725B6F'-or
            $parserDesign.independent_design_audit_summary_path-ne'artifacts/logs/independent-static-metadata-parser-design-audit-468e867/audit-summary.json'-or
            [long]$parserDesign.independent_design_audit_summary_byte_size-ne14996-or
            $parserDesign.independent_design_audit_summary_sha256-ne'A1A83F8C7A818B45D2A19A2C10C9206FE0C38CB8335485E17E2124BCEFCDB2C5'-or
            $parserDesign.input_identity_source-ne'REFERENCE_ONLY_ACCEPTED_COMPILE_ONLY_V2_EVIDENCE'-or
            $parserDesign.referenced_primary_dll_sha256-ne'77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862'-or
            $parserDesign.parser_implementation_status-ne'STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED'-or
            $parserDesign.parser_execution_status-ne'STATIC_METADATA_VALIDATED'-or
            $parserDesign.metadata_review_status-ne'STATIC_METADATA_VALIDATED'-or
            $parserDesign.artifact_opening_status-ne'NOT_PERFORMED'-or
            $parserDesign.artifact_parsing_status-ne'NOT_PERFORMED'-or
            $parserDesign.artifact_hash_verification_status-ne'NOT_PERFORMED'-or
            $parserDesign.artifact_write_status-ne'NOT_PERFORMED'-or
            $parserDesign.assembly_loading_status-ne'NOT_PERFORMED'-or
            $parserDesign.runtime_reflection_status-ne'NOT_PERFORMED'-or
            $parserDesign.compiled_artifact_execution_status-ne'NOT_PERFORMED'-or
            $parserDesign.native_invocation_status-ne'NOT_PERFORMED'-or
            $parserDesign.device_query_status-ne'NOT_PERFORMED'-or
            $parserDesign.windows_mutation_status-ne'NOT_PERFORMED'-or
            $parserDesign.driver_actions_status-ne'NOT_PERFORMED'){$defects.metadata_review_gate++}
    }
    $parserImplementationProperty=$metadataGate.PSObject.Properties['static_metadata_parser_implementation']
    if($null-eq$parserImplementationProperty-or$null-eq$parserImplementationProperty.Value-or$parserImplementationProperty.Value-is[array]){
        $defects.metadata_review_gate++
    }
    else{
        $parserImplementation=$parserImplementationProperty.Value
        $parserEvidencePathProperty=$parserImplementation.PSObject.Properties['parser_synthetic_validation_path']
        if($parserImplementation.status-ne'ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED'-or
            $parserImplementation.current_gate-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or
            $parserImplementation.real_artifact_review_authorization_transition_commit-ne'baab23aece902cbb06e11a308d9092fdc0f9ce0d'-or
            $parserImplementation.independent_implementation_audit_verdict-ne'AUDIT PASS'-or
            $parserImplementation.independent_implementation_audit_branch-ne'feature/runtime-bringup-static-metadata-parser-preflight-output-remediation'-or
            $parserImplementation.independent_implementation_audit_commit-ne'f0be4746ad4cc548334336c1e66f07007b71859f'-or
            $parserImplementation.independent_implementation_audit_summary_path-ne'artifacts/logs/independent-static-metadata-parser-preflight-output-audit-f0be474/audit-summary.json'-or
            [long]$parserImplementation.independent_implementation_audit_summary_byte_size-ne5706-or
            $parserImplementation.independent_implementation_audit_summary_sha256-ne'E28834B3B307DE1782CEF1C2E0F9BCD497BD1A856A1AB745DA5E6D4060F5279A'-or
            $parserImplementation.independent_implementation_audit_artifact_inventory_path-ne'artifacts/logs/independent-static-metadata-parser-preflight-output-audit-f0be474/artifact-inventory.json'-or
            [long]$parserImplementation.independent_implementation_audit_artifact_inventory_byte_size-ne5553-or
            $parserImplementation.independent_implementation_audit_artifact_inventory_sha256-ne'2F0BEF0D246F6F52F2090E4214EA284B6D4321E8B2E5BADF91842B7AF26E603B'-or
            $parserImplementation.parser_tool_name-ne'Chatpad.StaticMetadataParser'-or
            $parserImplementation.parser_project_path-ne'tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj'-or
            $parserImplementation.parser_source_path-ne'tools/StaticMetadataParser/Program.cs'-or
            $parserImplementation.parser_evidence_schema_path-ne'docs/evidence/static-metadata-parser-evidence-schema-v1.md'-or
            $null-eq$parserEvidencePathProperty-or
            -not(Test-ChatpadApprovedParserEvidencePath -Path $(if($null-ne$parserEvidencePathProperty){[string]$parserEvidencePathProperty.Value}else{$null}))-or
            [long]$parserImplementation.parser_synthetic_validation_byte_size-le0-or
            [string]$parserImplementation.parser_synthetic_validation_sha256-notmatch'^[0-9A-F]{64}$'-or
            $parserImplementation.parser_evidence_schema_version-ne'chatpad-static-metadata-parser-evidence-v1'-or
            [int]$parserImplementation.synthetic_fixture_count-ne5-or
            [int]$parserImplementation.synthetic_assertion_count-lt474-or
            [int]$parserImplementation.failed_fixture_count-ne0-or
            $parserImplementation.real_artifact_path_gate_status-ne'STATUS_BOUNDARY_ACCEPTED'-or
            $parserImplementation.all_file_bearing_options_centrally_scoped-ne$true-or
            $parserImplementation.expected_path_gate_status-ne'ACCEPTED_STATIC_ONLY'-or
            $parserImplementation.output_path_gate_status-ne'ACCEPTED_STATIC_ONLY'-or
            $parserImplementation.preflight_rejection_output_suppression-ne'ACCEPTED_STATIC_ONLY'-or
            $parserImplementation.rejection_evidence_transport-ne'TEST_HARNESS_FROM_CONSOLE_DIAGNOSTIC'-or
            $parserImplementation.approved_parser_evidence_root_validation-ne'ACCEPTED_STATIC_ONLY'-or
            $parserImplementation.allowed_input_scope-ne'SYNTHETIC_FIXTURES_ONLY_AND_MANIFEST_AUTHORIZED_REAL_ARTIFACT_PREFLIGHT'-or
            $parserImplementation.allowed_expected_scope-ne'SYNTHETIC_FIXTURES_ONLY_OR_REAL_ARTIFACT_REVIEW_EVIDENCE_ROOT'-or
            $parserImplementation.allowed_output_scope-ne'PARSER_EVIDENCE_ROOTS_ONLY_OR_REAL_ARTIFACT_REVIEW_EVIDENCE_ROOT'-or
            $parserImplementation.pre_io_rejection_tests-ne'PASS'-or
            $parserImplementation.pre_read_rejection_tests-ne'PASS'-or
            [int]$parserImplementation.real_artifact_like_rejection_count-notin@(7,8,9)-or
            [int]$parserImplementation.real_artifact_like_rejection_not_run_count-notin@(0,1)-or
            [int]$parserImplementation.failed_real_artifact_like_rejection_count-ne0-or
            [int]$parserImplementation.expected_path_rejection_count-lt7-or
            [int]$parserImplementation.failed_expected_path_rejection_count-ne0-or
            [int]$parserImplementation.output_path_rejection_count-lt10-or
            [int]$parserImplementation.failed_output_path_rejection_count-ne0-or
            $parserImplementation.safety_policy_mode-ne'IMMUTABLE_STATIC_ONLY'-or
            $parserImplementation.safety_policy_enforced-ne$true-or
            [int]$parserImplementation.safety_option_rejection_count-ne2-or
            [int]$parserImplementation.failed_safety_option_rejection_count-ne0-or
            [int]$parserImplementation.real_artifact_preflight_only_count-ne17-or
            [int]$parserImplementation.failed_real_artifact_preflight_only_count-ne0-or
            [int]$parserImplementation.authorization_manifest_malformed_case_count-ne14-or
            [int]$parserImplementation.failed_authorization_manifest_malformed_case_count-ne0-or
            $parserImplementation.original_stop_condition_reproduction_result-ne'PASS'-or
            $parserImplementation.parser_execution_status-ne'STATIC_METADATA_VALIDATED'-or
            $parserImplementation.metadata_review_status-ne'STATIC_METADATA_VALIDATED'-or
            $parserImplementation.real_artifact_open_parse_hash_write_status-ne'PERFORMED'-or
            $parserImplementation.real_compile_only_artifact_opened-ne$true-or
            $parserImplementation.real_compile_only_artifact_parsed-ne$true-or
            $parserImplementation.real_compile_only_artifact_hash_computed-ne$true-or
            $parserImplementation.real_compile_only_artifact_write_attempted-ne$false-or
            $parserImplementation.real_compile_only_artifact_write_completed-ne$false-or
            $parserImplementation.real_artifact_review_completed-ne$true-or
            $parserImplementation.static_metadata_review_result-ne'STATIC_METADATA_VALIDATED'-or
            $parserImplementation.assembly_loading_occurred-ne$false-or
            $parserImplementation.runtime_reflection_occurred-ne$false-or
            $parserImplementation.compiled_artifact_execution_occurred-ne$false-or
            $parserImplementation.native_invocation_occurred-ne$false-or
            $parserImplementation.device_query_occurred-ne$false-or
            $parserImplementation.windows_mutation_occurred-ne$false-or
            $parserImplementation.driver_actions_occurred-ne$false){$defects.metadata_review_gate++}
    }
    $sectionNativeExecutionDefect=Test-ChatpadNativeExecutionStatusValue -Container $metadataGate -Location 'manifest.compiled_artifact_metadata_review_design_gate'
    if($null-ne$sectionNativeExecutionDefect){$metadataReviewDefectRecords.Add($sectionNativeExecutionDefect)}
    foreach($expectation in (Get-ChatpadMetadataReviewBooleanExpectations).GetEnumerator()){
        $booleanDefect=Test-ChatpadRequiredBooleanProperty -Container $metadataGate -PropertyName $expectation.Key -Location 'manifest.compiled_artifact_metadata_review_design_gate' -ExpectedValue $expectation.Value
        if($null-ne$booleanDefect){$metadataReviewDefectRecords.Add($booleanDefect)}
    }
}
$defects.metadata_review_gate += $metadataReviewDefectRecords.Count
$accountingDetails.metadata_review_gate_defects=@($metadataReviewDefectRecords)
$suiteEntry=@($entries|Where-Object id -eq 'evidence-synthetic-suite')
if($suiteEntry.Count-ne1){$defects.evidence_binding++}
else{
    $suitePath=[IO.Path]::GetFullPath((Join-Path $root ([string]$suiteEntry[0].relative_path)))
    try{$suite=Get-Content -LiteralPath $suitePath -Raw|ConvertFrom-Json}catch{$suite=$null;$defects.evidence_binding++}
    if($null-ne$suite){
        $countValidationDefects=[Collections.Generic.List[object]]::new()
        $records=@($suite.fixtures)
        $recordIds=@($records|ForEach-Object{if($null -ne $_.PSObject.Properties['fixture_id']){[string]$_.PSObject.Properties['fixture_id'].Value}else{''}})
        $recordAssertionSum=[long]0
        $recordDefects=0
        foreach($record in $records){
            $fixtureId=if($null -ne $record.PSObject.Properties['fixture_id']){[string]$record.PSObject.Properties['fixture_id'].Value}else{''}
            $categoryValue=if($null -ne $record.PSObject.Properties['category']){$record.PSObject.Properties['category'].Value}else{$null}
            if([string]::IsNullOrWhiteSpace($fixtureId)-or[string]::IsNullOrWhiteSpace([string]$categoryValue)-or$categoryValue-is[array]){$recordDefects++;continue}
            $assertions=Get-ChatpadValidatedIntegerProperty -Item $record -PropertyName assertion_count -Location 'suite.fixtures' -RecordId $fixtureId -DefectCount ([ref]$recordDefects) -Defects $countValidationDefects -AllowZero
            if($null -eq $assertions){continue}
            $fixtureResult=if($null -ne $record.PSObject.Properties['fixture_result']){[string]$record.PSObject.Properties['fixture_result'].Value}else{''}
            if($fixtureResult -eq 'PASS' -and $assertions -eq 0){
                $recordDefects++
                $countValidationDefects.Add((New-ChatpadCountValidationDefect 'assertion_count' 'suite.fixtures' $fixtureId 'INTEGER_COUNT.ZERO_PASS_RECORD' 'PASS records must have at least one assertion.' $assertions))
            } else {
                $recordAssertionSum += $assertions
            }
        }
        if(@($recordIds|Group-Object|Where-Object Count -gt 1).Count){$recordDefects++}
        $categoryDefects=0
        $derivedCategories=@($records|Group-Object category|Sort-Object Name|ForEach-Object{[pscustomobject]@{category=$_.Name;record_count=[long]$_.Count;assertion_count=(Get-ChatpadIntegerPropertySum -Items ([object[]]$_.Group) -PropertyName assertion_count -DefectCount ([ref]$categoryDefects) -Defects $countValidationDefects -Location "suite.fixtures.category.$($_.Name)")}})
        $suiteCategories=@($suite.category_totals)
        foreach($expected in $derivedCategories){
            $actual=@($suiteCategories|Where-Object category -eq $expected.category)
            if($actual.Count-ne1){$categoryDefects++;continue}
            [void](Compare-ChatpadIntegerProperty -Item $actual[0] -PropertyName record_count -Expected $expected.record_count -Location 'suite.category_totals' -RecordId ([string]$expected.category) -DefectCount ([ref]$categoryDefects) -Defects $countValidationDefects -AllowZero)
            [void](Compare-ChatpadIntegerProperty -Item $actual[0] -PropertyName assertion_count -Expected $expected.assertion_count -Location 'suite.category_totals' -RecordId ([string]$expected.category) -DefectCount ([ref]$categoryDefects) -Defects $countValidationDefects -AllowZero)
        }
        foreach($actual in $suiteCategories){if(@($derivedCategories|Where-Object category -eq $actual.category).Count-ne1){$categoryDefects++}}
        $categoryRecordSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$suiteCategories) -PropertyName record_count -DefectCount ([ref]$categoryDefects) -Defects $countValidationDefects -Location 'suite.category_totals'
        $categoryAssertionSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$suiteCategories) -PropertyName assertion_count -DefectCount ([ref]$categoryDefects) -Defects $countValidationDefects -Location 'suite.category_totals'
        $harness=@($records|Where-Object category -eq 'harness-self-test')
        $harnessAssertionSum=Get-ChatpadIntegerPropertySum -Items ([object[]]$harness) -PropertyName assertion_count -DefectCount ([ref]$recordDefects) -Defects $countValidationDefects -Location 'suite.fixtures.harness-self-test'
        $suiteAccountingDefects=0
        $readinessAccountingDefects=0
        $suiteCounts=[ordered]@{}
        foreach($name in @('harness_result_record_count','harness_assertion_sum','total_result_record_count','assertion_count','fixture_count','fixture_assertion_sum','record_assertion_sum','category_record_sum','category_assertion_sum','unassigned_assertion_count','off_ledger_assertion_count','duplicate_counted_assertion_count','category_reconciliation_defect_count')){
            $suiteCounts[$name]=Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName $name -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero
        }
        $readinessCounts=[ordered]@{}
        foreach($name in @('fixture_count','total_result_record_count','assertion_count','fixture_assertion_sum','record_assertion_sum','category_record_sum','category_assertion_sum','missing_provenance_probe_count','missing_provenance_pass_count','synthetic_source_probe_count','synthetic_runtime_observer_pass_count','unsupported_runtime_observer_pass_count','runtime_observations_evaluated_live','exact_instance_offline_test_count','exact_instance_offline_assertion_count','synthetic_exact_binding_attempt_count','synthetic_exact_restoration_attempt_count','synthetic_exact_restart_attempt_count','exact_instance_binding_operations','exact_instance_restoration_operations','exact_instance_restart_operations','broad_approved_install_operations','broad_approved_rollback_operations','windows_mutation_count','unassigned_assertion_count','off_ledger_assertion_count','duplicate_counted_assertion_count','category_reconciliation_defect_count','invalid_lifecycle_acceptance_count','missing_start_timestamp_acceptance_count','stop_condition_count','unique_stop_condition_count','runtime_observer_linkage_count','unlinked_stop_condition_count','unknown_stop_condition_id_count','malformed_linkage_count','nested_array_acceptance_count','malformed_input_validator_count','malformed_input_case_count','uncontrolled_exception_count','property_not_found_exception_count','strictmode_exception_count')){
            $readinessCounts[$name]=Get-ChatpadValidatedIntegerProperty -Item $manifest.readiness -PropertyName $name -Location 'manifest.readiness' -RecordId 'readiness' -DefectCount ([ref]$readinessAccountingDefects) -Defects $countValidationDefects -AllowZero
        }
        $accountingDetails=[ordered]@{
            metadata_review_gate_defects=@($metadataReviewDefectRecords)
            expected_harness_result_record_count=$suiteCounts.harness_result_record_count
            actual_harness_result_record_count=$harness.Count
            expected_harness_assertion_sum=$suiteCounts.harness_assertion_sum
            actual_harness_assertion_sum=$harnessAssertionSum
            expected_total_result_record_count=$suiteCounts.total_result_record_count
            actual_total_result_record_count=$records.Count
            expected_assertion_count=$suiteCounts.assertion_count
            actual_record_assertion_sum=$recordAssertionSum
            expected_category_record_sum=$suiteCounts.category_record_sum
            actual_category_record_sum=$categoryRecordSum
            expected_category_assertion_sum=$suiteCounts.category_assertion_sum
            actual_category_assertion_sum=$categoryAssertionSum
            record_defect_count=$recordDefects
            category_defect_count=$categoryDefects
            suite_count_defect_count=$suiteAccountingDefects
            readiness_count_defect_count=$readinessAccountingDefects
            count_validation_defects=@($countValidationDefects)
        }
        $suiteAccountingMismatch=$false
        if($null -eq $suiteCounts.fixture_count -or $suiteCounts.fixture_count -ne $records.Count){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.total_result_record_count -or $suiteCounts.total_result_record_count -ne $records.Count){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.fixture_assertion_sum -or $suiteCounts.fixture_assertion_sum -ne $recordAssertionSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.record_assertion_sum -or $suiteCounts.record_assertion_sum -ne $recordAssertionSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.assertion_count -or $suiteCounts.assertion_count -ne $recordAssertionSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.category_record_sum -or $suiteCounts.category_record_sum -ne $categoryRecordSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.category_assertion_sum -or $suiteCounts.category_assertion_sum -ne $categoryAssertionSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.harness_result_record_count -or $suiteCounts.harness_result_record_count -ne $harness.Count){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.harness_assertion_sum -or $suiteCounts.harness_assertion_sum -ne $harnessAssertionSum){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.unassigned_assertion_count -or $suiteCounts.unassigned_assertion_count -ne 0){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.off_ledger_assertion_count -or $suiteCounts.off_ledger_assertion_count -ne 0){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.duplicate_counted_assertion_count -or $suiteCounts.duplicate_counted_assertion_count -ne 0){$suiteAccountingMismatch=$true}
        if($null -eq $suiteCounts.category_reconciliation_defect_count -or $suiteCounts.category_reconciliation_defect_count -ne 0){$suiteAccountingMismatch=$true}
        if($recordDefects-or$categoryDefects-or
            $suiteAccountingDefects-or$suiteAccountingMismatch-or
            $categoryRecordSum-ne$records.Count-or$categoryAssertionSum-ne$recordAssertionSum-or
            [string]$suite.assertion_accounting_result-ne'PASS'){$defects.accounting++}
        if($readinessAccountingDefects-or
            $null -eq $readinessCounts.fixture_count -or $readinessCounts.fixture_count-ne$records.Count-or
            $null -eq $readinessCounts.total_result_record_count -or $readinessCounts.total_result_record_count-ne$records.Count-or
            $null -eq $readinessCounts.assertion_count -or $readinessCounts.assertion_count-ne$recordAssertionSum-or
            $null -eq $readinessCounts.fixture_assertion_sum -or $readinessCounts.fixture_assertion_sum-ne$recordAssertionSum-or
            $null -eq $readinessCounts.record_assertion_sum -or $readinessCounts.record_assertion_sum-ne$recordAssertionSum-or
            $null -eq $readinessCounts.category_record_sum -or $readinessCounts.category_record_sum-ne$categoryRecordSum-or
            $null -eq $readinessCounts.category_assertion_sum -or $readinessCounts.category_assertion_sum-ne$categoryAssertionSum){$defects.fixture_totals++}
        if([string]$suite.observer_provenance_contract_result-ne'PASS'-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName missing_provenance_probe_count -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne5-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName missing_provenance_pass_count -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne0-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName synthetic_source_probe_count -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne5-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName synthetic_runtime_observer_pass_count -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne0-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName unsupported_runtime_observer_pass_count -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne0-or
            (Get-ChatpadValidatedIntegerProperty -Item $suite -PropertyName runtime_observations_evaluated_live -Location 'suite' -RecordId 'evidence-synthetic-suite' -DefectCount ([ref]$suiteAccountingDefects) -Defects $countValidationDefects -AllowZero)-ne0-or
            [string]$manifest.readiness.observer_provenance_contract_result-ne'PASS'-or
            $readinessCounts.missing_provenance_probe_count-ne5-or$readinessCounts.missing_provenance_pass_count-ne0-or
            $readinessCounts.synthetic_source_probe_count-ne5-or$readinessCounts.synthetic_runtime_observer_pass_count-ne0-or
            $readinessCounts.unsupported_runtime_observer_pass_count-ne0-or$readinessCounts.runtime_observations_evaluated_live-ne0){$defects.observer_provenance++}
    }
}
if($null -ne $manifest.readiness.PSObject.Properties['fixture_count'] -and $null -ne $manifest.readiness.PSObject.Properties['assertion_count']){
    $topLevelDefects=[Collections.Generic.List[object]]::new()
    $topLevelDefectCount=0
    $topFixtureCount=Get-ChatpadValidatedIntegerProperty -Item $manifest.readiness -PropertyName fixture_count -Location 'manifest.readiness' -RecordId 'readiness' -DefectCount ([ref]$topLevelDefectCount) -Defects $topLevelDefects -AllowZero
    $topAssertionCount=Get-ChatpadValidatedIntegerProperty -Item $manifest.readiness -PropertyName assertion_count -Location 'manifest.readiness' -RecordId 'readiness' -DefectCount ([ref]$topLevelDefectCount) -Defects $topLevelDefects -AllowZero
    if($topLevelDefectCount -or $topFixtureCount-le0-or$topAssertionCount-le0-or@($manifest.readiness.category_totals).Count-le0){$defects.fixture_totals++}
} else {$defects.fixture_totals++}
if($manifest.readiness.psscriptanalyzer_status-notin@('SKIPPED_UNAVAILABLE','PASS')){$defects.psscriptanalyzer++}
if($manifest.readiness.psscriptanalyzer_status-eq'PASS'-and$null-eq(Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue)){$defects.psscriptanalyzer++}
foreach($name in @('frozen_baseline_commit','prior_readiness_implementation_commit','prior_readiness_finalization_commit','current_readiness_implementation_commit')){if([string]$manifest.repository.$name-notmatch'^[0-9a-f]{40}$'){$defects.identity++}}
if($readinessCounts.exact_instance_binding_operations-or$readinessCounts.exact_instance_restoration_operations-or$readinessCounts.exact_instance_restart_operations-or$readinessCounts.broad_approved_install_operations-or$readinessCounts.broad_approved_rollback_operations-or$readinessCounts.windows_mutation_count){$defects.unsupported_pass++}
if([string]$manifest.readiness.exact_instance_framework_result-ne'PASS'-or$readinessCounts.exact_instance_offline_test_count-ne209-or$readinessCounts.exact_instance_offline_assertion_count-ne839-or$readinessCounts.synthetic_exact_binding_attempt_count-le0-or$readinessCounts.synthetic_exact_restoration_attempt_count-le0-or$readinessCounts.synthetic_exact_restart_attempt_count-ne0){$defects.unsupported_pass++}
if([string]$manifest.readiness.assertion_accounting_result-ne'PASS'-or$readinessCounts.unassigned_assertion_count-or$readinessCounts.off_ledger_assertion_count-or$readinessCounts.duplicate_counted_assertion_count-or$readinessCounts.category_reconciliation_defect_count){$defects.accounting++}
if($readinessCounts.invalid_lifecycle_acceptance_count -ne 0 -or $readinessCounts.missing_start_timestamp_acceptance_count -ne 0){$defects.lifecycle++}
if($readinessCounts.stop_condition_count -ne 20 -or $readinessCounts.unique_stop_condition_count -ne 20 -or $readinessCounts.runtime_observer_linkage_count -ne 5 -or $readinessCounts.unlinked_stop_condition_count -ne 0 -or $readinessCounts.unknown_stop_condition_id_count -ne 0 -or $readinessCounts.malformed_linkage_count -ne 0 -or $readinessCounts.nested_array_acceptance_count -ne 0){$defects.stop_linkage++}
if($readinessCounts.malformed_input_validator_count -ne 15 -or $readinessCounts.malformed_input_case_count -ne 180 -or $readinessCounts.uncontrolled_exception_count -ne 0 -or $readinessCounts.property_not_found_exception_count -ne 0 -or $readinessCounts.strictmode_exception_count -ne 0){$defects.malformed_totality++}
if([string]$manifest.readiness.committed_sample_structural_validation -ne 'PASS' -or [string]$manifest.readiness.committed_sample_semantic_validation -ne 'PASS'){$defects.sample_validation++}
$inventory=$manifest.readiness.powershell_inventory
$inventoryDefects=[Collections.Generic.List[object]]::new()
$inventoryDefectCount=0
$inventoryCounts=[ordered]@{}
foreach($name in @('tracked_ps1_count','tracked_psm1_count','tracked_powershell_count','parsed_ps1_count','parsed_psm1_count','parsed_powershell_count','parse_error_count','duplicate_normalized_path_count','missing_count','extra_count')){
    $inventoryCounts[$name]=Get-ChatpadValidatedIntegerProperty -Item $inventory -PropertyName $name -Location 'manifest.readiness.powershell_inventory' -RecordId 'powershell_inventory' -DefectCount ([ref]$inventoryDefectCount) -Defects $inventoryDefects -AllowZero
}
if($inventoryDefectCount -or $inventoryCounts.tracked_ps1_count -ne 49 -or $inventoryCounts.tracked_psm1_count -ne 10 -or$inventoryCounts.tracked_powershell_count-ne59-or$inventoryCounts.parsed_ps1_count-ne49-or$inventoryCounts.parsed_psm1_count-ne10-or$inventoryCounts.parsed_powershell_count-ne59-or$inventoryCounts.parse_error_count-ne0-or$inventoryCounts.duplicate_normalized_path_count-ne0-or$inventoryCounts.missing_count-ne0-or$inventoryCounts.extra_count-ne0){$defects.powershell_inventory++}
$analyzer=$manifest.readiness.psscriptanalyzer
if($manifest.readiness.psscriptanalyzer_status-eq'PASS'){
    if($null-eq$analyzer-or[int]$analyzer.analyzed_file_count-ne55-or[int]$analyzer.error_count-ne0-or[int]$analyzer.tool_failure_count-ne0-or[bool]$analyzer.blanket_suppression_used){$defects.psscriptanalyzer++}
    if(@($analyzer.findings|Where-Object{$_.severity-notin@('Error','Warning','Information')}).Count){$defects.psscriptanalyzer++}
}
$total=($defects.Values|Measure-Object -Sum).Sum
[pscustomobject][ordered]@{
    schema_version='chatpad-runtime-bringup-readiness-manifest-validation-v3'
    result=$(if($total){'FAIL'}else{'PASS'})
    validation_mode=if($NoArtifactOpenDesignGateAudit){'NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT'}else{'STANDARD_MANIFEST_VALIDATION'}
    artifact_opening_performed=$false
    compiled_output_hash_verification_performed=$false
    metadata_parsing_performed=$false
    manifest_schema=$manifest.schema_version
    entry_count=$entries.Count
    defects=[pscustomobject]$defects
    total_defects=$total
    accounting_details=[pscustomobject]$accountingDetails
    parser_evidence_path_regression=[pscustomobject]$parserEvidencePathRegression
}|ConvertTo-Json -Depth 8
if($total){exit 1}
