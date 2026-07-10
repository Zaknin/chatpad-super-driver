[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadGatedProductionNativeAdapterBackend.psm1'
$adapterPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadNonExecutingNativeAdapter.psm1'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0

function Assert-GatedBackendCondition {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    $script:assertionCount++
    if (-not $Condition) { throw $Message }
}

function Invoke-GatedBackendTestCase {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    try { & $Body; $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'PASS' }) }
    catch { $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message }) }
}

function New-GatedBackendAcceptedRequest {
    [pscustomobject][ordered]@{
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        target_chain = @('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
    }
}

Import-Module $modulePath -Force
Import-Module $adapterPath -Force
$module = Get-Module ChatpadGatedProductionNativeAdapterBackend

Invoke-GatedBackendTestCase 'backend module exports no constructor provider or execution surface' {
    Assert-GatedBackendCondition ($module.ExportedFunctions.Count -eq 0) 'backend module exported a function'
    Assert-GatedBackendCondition ($module.SessionState.PSVariable.GetValue('ProductionBackend', $null) -eq $null) 'production backend was constructed during import'
    Assert-GatedBackendCondition ($module.SessionState.PSVariable.GetValue('NativeAdapterExecutionCapability', $null) -eq $null) 'effective capability was present in SessionState'
}

Invoke-GatedBackendTestCase 'audited public exports and invocation remain prohibited' {
    $expected = @('Get-ChatpadNonExecutingNativeAdapterContract','Test-ChatpadNonExecutingNativeAdapterRequest','Invoke-ChatpadNonExecutingNativeAdapter','New-ChatpadNativeAdapterFakeRecordingBackend')
    Assert-GatedBackendCondition ((@((Get-Module ChatpadNonExecutingNativeAdapter).ExportedFunctions.Keys | Sort-Object) -join '|') -eq (@($expected | Sort-Object) -join '|')) 'public export surface changed'
    $result = Invoke-ChatpadNonExecutingNativeAdapter -Request (New-GatedBackendAcceptedRequest)
    Assert-GatedBackendCondition ($result.result_code -eq 'NATIVE_EXECUTION_PROHIBITED') 'public invocation was no longer prohibited'
    foreach ($counter in $result.counters.PSObject.Properties) { Assert-GatedBackendCondition ($counter.Value -eq 0) "public counter $($counter.Name) was non-zero" }
}

Invoke-GatedBackendTestCase 'production descriptor is source-only and never default selected' {
    $descriptor = & $module { New-GatedProductionNativeProviderDescriptor }
    Assert-GatedBackendCondition ($descriptor.provider_kind -eq 'DECLARATION_BACKED_PRODUCTION_PROVIDER_SOURCE_ONLY') 'wrong provider descriptor'
    Assert-GatedBackendCondition (-not $descriptor.native_invocation_available) 'descriptor offered native invocation'
    Assert-GatedBackendCondition (-not $descriptor.selected_by_default) 'descriptor selected by default'
    Assert-GatedBackendCondition (-not $descriptor.constructed_during_import) 'descriptor claimed import construction'
}

Invoke-GatedBackendTestCase 'exact request records the authoritative ordered plan and arguments' {
    $provider = & $module { New-GatedProductionRecordingProvider }
    $result = & $module { param($r, $p) Invoke-GatedProductionBackendRecordingPlan -Request $r -Provider $p } (New-GatedBackendAcceptedRequest) $provider
    $expected = @('SetupDiCreateDeviceInfoList','SetupDiOpenDeviceInfoW','SetupDiGetDeviceInstanceIdW','SetupDiGetDevicePropertyW','SetupDiGetDeviceRegistryPropertyW','SetupDiBuildDriverInfoList','SetupDiEnumDriverInfoW','SetupDiGetDriverInfoDetailW','SetupDiGetDriverInstallParamsW','SetupDiSetSelectedDriverW','DiInstallDevice','SetupDiDestroyDriverInfoList','SetupDiDestroyDeviceInfoList')
    Assert-GatedBackendCondition ($result.result -eq 'RECORDING_PLAN_COMPLETED_NOT_EXECUTED') 'recording plan did not complete'
    Assert-GatedBackendCondition ((@($provider.calls | ForEach-Object entry_point) -join '|') -eq ($expected -join '|')) 'recorded call order differed'
    Assert-GatedBackendCondition ($provider.calls[1].arguments.target_instance_id -eq 'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00') 'selected exact target differed'
    Assert-GatedBackendCondition ((@($provider.calls[1].arguments.accepted_target_chain) -join '|') -eq ((New-GatedBackendAcceptedRequest).target_chain -join '|')) 'exact chain differed'
    Assert-GatedBackendCondition ($provider.calls[1].arguments.shared_container_id -eq '{828F4587-006F-5AD1-B169-6AF57905DFDE}') 'container differed'
    Assert-GatedBackendCondition ($provider.calls[1].arguments.operator_confirmation_id -eq 'operator-confirmation-c445630fbb303c7c') 'confirmation differed'
    Assert-GatedBackendCondition (-not $result.mutation_success_claimed) 'recording shim claimed mutation success'
    foreach ($counter in $result.counters.PSObject.Properties) { Assert-GatedBackendCondition ($counter.Value -eq 0) "recording counter $($counter.Name) was non-zero" }
}

Invoke-GatedBackendTestCase 'invalid capability and malformed exact inputs make zero provider calls' {
    $variants = @()
    $reordered = New-GatedBackendAcceptedRequest; $reordered.target_chain = @($reordered.target_chain[1],$reordered.target_chain[0],$reordered.target_chain[2]); $variants += $reordered
    $missing = New-GatedBackendAcceptedRequest; $missing.target_chain = @($missing.target_chain[0]); $variants += $missing
    $extra = New-GatedBackendAcceptedRequest; $extra.target_chain += 'HID\VID_045E&PID_028E\EXTRA'; $variants += $extra
    $duplicate = New-GatedBackendAcceptedRequest; $duplicate.target_chain[2] = $duplicate.target_chain[1]; $variants += $duplicate
    $wrongContainer = New-GatedBackendAcceptedRequest; $wrongContainer.shared_container_id = '{00000000-0000-0000-0000-000000000000}'; $variants += $wrongContainer
    $wrongConfirmation = New-GatedBackendAcceptedRequest; $wrongConfirmation.operator_confirmation_id = 'wrong'; $variants += $wrongConfirmation
    $wrongEvidence = New-GatedBackendAcceptedRequest; $wrongEvidence.contract_evidence_sha256 = '0' * 64; $variants += $wrongEvidence
    foreach ($request in $variants) {
        $provider = & $module { New-GatedProductionRecordingProvider }
        $result = & $module { param($r, $p) Invoke-GatedProductionBackendRecordingPlan -Request $r -Provider $p } $request $provider
        Assert-GatedBackendCondition ($result.result -eq 'VALIDATION_REJECTED_NO_PROVIDER_CALL') 'invalid request reached provider'
        Assert-GatedBackendCondition ($provider.calls.Count -eq 0) 'invalid request made provider call'
    }
}

Invoke-GatedBackendTestCase 'provider failure stops operation calls and performs required cleanup' {
    $provider = & $module { New-GatedProductionRecordingProvider -FailAt 'SetupDiEnumDriverInfoW' -FailureCode 'DRIVER_NODE_ENUMERATION_FAILURE' }
    $result = & $module { param($r, $p) Invoke-GatedProductionBackendRecordingPlan -Request $r -Provider $p } (New-GatedBackendAcceptedRequest) $provider
    $actual = @($provider.calls | ForEach-Object entry_point)
    Assert-GatedBackendCondition ($result.result -eq 'RECORDING_PLAN_STOPPED_ON_PROVIDER_FAILURE') 'provider failure did not stop plan'
    Assert-GatedBackendCondition ($result.result_code -eq 'DRIVER_NODE_ENUMERATION_FAILURE') 'provider error was not preserved'
    Assert-GatedBackendCondition (($actual -join '|') -eq (@('SetupDiCreateDeviceInfoList','SetupDiOpenDeviceInfoW','SetupDiGetDeviceInstanceIdW','SetupDiGetDevicePropertyW','SetupDiGetDeviceRegistryPropertyW','SetupDiBuildDriverInfoList','SetupDiEnumDriverInfoW','SetupDiDestroyDriverInfoList','SetupDiDestroyDeviceInfoList') -join '|')) 'failure plan or cleanup ordering differed'
    Assert-GatedBackendCondition ($result.cleanup_attempted) 'cleanup was not attempted'
    Assert-GatedBackendCondition (-not $result.mutation_success_claimed) 'failure claimed mutation success'
}

Invoke-GatedBackendTestCase 'source excludes forbidden fallback mechanisms' {
    $text = Get-Content -Raw $modulePath
    foreach ($pattern in @('Get-CimInstance','Get-WmiObject','Get-PnpDevice','Get-ItemProperty','pnputil','devcon','Start-Process','&\s*pnputil','UpdateDriverForPlugAndPlayDevices','DiInstallDriver','ConfigurationManager')) {
        Assert-GatedBackendCondition ($text -notmatch $pattern) "forbidden fallback pattern present: $pattern"
    }
}

$failed = @($tests | Where-Object { $_.result -ne 'PASS' })
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-gated-production-native-adapter-backend-offline-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    tests = @($tests)
    prohibited_operation_counters = (& $module { New-GatedProductionBackendZeroCounters })
}
Write-Output $report
if ($failed.Count) { exit 1 }
