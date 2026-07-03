[CmdletBinding()]
param(
    [string]$ManifestPath='docs/evidence/runtime-bringup-readiness-manifest.json',
    [switch]$RunCorruptionRegression
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

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
            $item=Get-Item -LiteralPath $fullPath
            $entry[0].byte_size=[long]$item.Length
            $entry[0].sha256=(Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
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
            $changedSuite=Get-Item -LiteralPath $tempSuitePath
            $changedSuiteHash=(Get-FileHash -LiteralPath $tempSuitePath -Algorithm SHA256).Hash
            $entry=@($manifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
            $entry[0].byte_size=[long]$changedSuite.Length
            $entry[0].sha256=$changedSuiteHash
            foreach($manifestEntry in @($manifest.entries|Where-Object id -ne 'evidence-synthetic-suite')){
                Set-ManifestEntryFileIdentity -Manifest $manifest -RelativePath ([string]$manifestEntry.relative_path)
            }
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
            $changedSuite=Get-Item -LiteralPath $tempSuitePath
            $changedSuiteHash=(Get-FileHash -LiteralPath $tempSuitePath -Algorithm SHA256).Hash
            $entry=@($manifest.entries|Where-Object id -eq 'evidence-synthetic-suite')
            $entry[0].byte_size=[long]$changedSuite.Length
            $entry[0].sha256=$changedSuiteHash
            foreach($manifestEntry in @($manifest.entries|Where-Object id -ne 'evidence-synthetic-suite')){
                Set-ManifestEntryFileIdentity -Manifest $manifest -RelativePath ([string]$manifestEntry.relative_path)
            }
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
$readinessCounts=[ordered]@{}
foreach($entry in $entries){
    $full=[IO.Path]::GetFullPath((Join-Path $root ([string]$entry.relative_path)))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$defects.containment++;continue}
    if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$defects.missing++;continue}
    $item=Get-Item $full;if([long]$entry.byte_size-ne$item.Length){$defects.size++};if([string]$entry.sha256-cne(Get-FileHash $full -Algorithm SHA256).Hash){$defects.hash++}
    if($entry.state-notin@('tracked','ignored')){$defects.state++}
    if($entry.evidence_classification-ne'synthetic'){$defects.declared_result++}
}
if($manifest.schema_version-ne'chatpad-runtime-bringup-readiness-manifest-v3'-or$manifest.framework_status-ne'PASS'-or$manifest.live_installation_readiness-ne'BLOCKED'-or$manifest.current_gate-ne'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT'-or$manifest.capability_blocker-ne'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'-or$manifest.live_adapter_status-ne'SCAFFOLD_NON_EXECUTING'-or$manifest.live_binding_authorized-ne$false){$defects.top_level++}
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
if([string]$manifest.readiness.exact_instance_framework_result-ne'PASS'-or$readinessCounts.exact_instance_offline_test_count-ne171-or$readinessCounts.exact_instance_offline_assertion_count-ne709-or$readinessCounts.synthetic_exact_binding_attempt_count-le0-or$readinessCounts.synthetic_exact_restoration_attempt_count-le0-or$readinessCounts.synthetic_exact_restart_attempt_count-ne0){$defects.unsupported_pass++}
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
if($inventoryDefectCount -or $inventoryCounts.tracked_ps1_count -ne 45 -or $inventoryCounts.tracked_psm1_count -ne 8 -or$inventoryCounts.tracked_powershell_count-ne53-or$inventoryCounts.parsed_ps1_count-ne45-or$inventoryCounts.parsed_psm1_count-ne8-or$inventoryCounts.parsed_powershell_count-ne53-or$inventoryCounts.parse_error_count-ne0-or$inventoryCounts.duplicate_normalized_path_count-ne0-or$inventoryCounts.missing_count-ne0-or$inventoryCounts.extra_count-ne0){$defects.powershell_inventory++}
$analyzer=$manifest.readiness.psscriptanalyzer
if($manifest.readiness.psscriptanalyzer_status-eq'PASS'){
    if($null-eq$analyzer-or[int]$analyzer.analyzed_file_count-ne53-or[int]$analyzer.error_count-ne0-or[int]$analyzer.tool_failure_count-ne0-or[bool]$analyzer.blanket_suppression_used){$defects.psscriptanalyzer++}
    if(@($analyzer.findings|Where-Object{$_.severity-notin@('Error','Warning','Information')}).Count){$defects.psscriptanalyzer++}
}
$total=($defects.Values|Measure-Object -Sum).Sum
[pscustomobject][ordered]@{schema_version='chatpad-runtime-bringup-readiness-manifest-validation-v2';result=$(if($total){'FAIL'}else{'PASS'});manifest_schema=$manifest.schema_version;entry_count=$entries.Count;defects=[pscustomobject]$defects;total_defects=$total;accounting_details=[pscustomobject]$accountingDetails}|ConvertTo-Json -Depth 8
if($total){exit 1}
