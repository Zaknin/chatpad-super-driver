[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadNonExecutingNativeAdapter.psm1'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0

function Assert-AdapterCondition {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    $script:assertionCount++
    if (-not $Condition) { throw $Message }
}

function Invoke-AdapterTestCase {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    try {
        & $Body
        $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'PASS' })
    } catch {
        $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message })
    }
}

function New-AcceptedAdapterRequest {
    [pscustomobject][ordered]@{
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        target_chain = @(
            'USB\VID_045E&PID_028E\1C21F10',
            'USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00',
            'HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000'
        )
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
    }
}

Import-Module $modulePath -Force
$module = Get-Module ChatpadNonExecutingNativeAdapter
$contract = Get-ChatpadNonExecutingNativeAdapterContract

Invoke-AdapterTestCase 'load and inspection have zero prohibited activity' {
    foreach ($counter in $contract.counters.PSObject.Properties) { Assert-AdapterCondition ($counter.Value -eq 0) "load counter $($counter.Name) was non-zero" }
    Assert-AdapterCondition (-not $contract.production_backend_present) 'production backend was present on load'
    Assert-AdapterCondition (-not $contract.production_backend_loaded) 'production backend was loaded on inspection'
    Assert-AdapterCondition (-not $contract.production_backend_selected_by_default) 'production backend selected by default'
}

Invoke-AdapterTestCase 'accepted evidence and exact target validate while execution remains prohibited' {
    $result = Test-ChatpadNonExecutingNativeAdapterRequest -Request (New-AcceptedAdapterRequest)
    Assert-AdapterCondition $result.contract_validation_passed 'accepted evidence did not validate'
    Assert-AdapterCondition (-not $result.target_validation_rejected) 'accepted target was rejected'
    Assert-AdapterCondition $result.authorization_rejected 'authorization was unexpectedly accepted'
    Assert-AdapterCondition $result.native_execution_prohibited 'execution was not prohibited'
    Assert-AdapterCondition (-not $result.native_operation_executed) 'validation executed a native operation'
}

Invoke-AdapterTestCase 'reordered missing extra duplicate and wrong chains are rejected' {
    $accepted = New-AcceptedAdapterRequest
    $variants = @(
        @($accepted.target_chain[1], $accepted.target_chain[0], $accepted.target_chain[2]),
        @($accepted.target_chain[0], $accepted.target_chain[1]),
        @($accepted.target_chain + 'HID\VID_045E&PID_028E\EXTRA'),
        @($accepted.target_chain[0], $accepted.target_chain[1], $accepted.target_chain[1]),
        @('USB\VID_045E&PID_028E\WRONG', $accepted.target_chain[1], $accepted.target_chain[2])
    )
    foreach ($chain in $variants) {
        $request = New-AcceptedAdapterRequest; $request.target_chain = $chain
        $result = Test-ChatpadNonExecutingNativeAdapterRequest -Request $request
        Assert-AdapterCondition $result.target_validation_rejected 'invalid chain was accepted'
        Assert-AdapterCondition ($result.attempted_fake_backend_calls -eq 0) 'invalid chain attempted fake backend'
    }
}

Invoke-AdapterTestCase 'wrong container confirmation and evidence identity are rejected' {
    $wrongContainer = New-AcceptedAdapterRequest; $wrongContainer.shared_container_id = '{00000000-0000-0000-0000-000000000000}'
    $wrongConfirmation = New-AcceptedAdapterRequest; $wrongConfirmation.operator_confirmation_id = 'operator-confirmation-wrong'
    $wrongEvidence = New-AcceptedAdapterRequest; $wrongEvidence.contract_evidence_sha256 = '0' * 64
    foreach ($request in @($wrongContainer, $wrongConfirmation, $wrongEvidence)) {
        $result = Test-ChatpadNonExecutingNativeAdapterRequest -Request $request
        Assert-AdapterCondition (($result.target_validation_rejected) -or (-not $result.contract_validation_passed)) 'wrong accepted input passed validation'
        Assert-AdapterCondition ($result.attempted_fake_backend_calls -eq 0) 'wrong input attempted fake backend'
    }
}

Invoke-AdapterTestCase 'missing and ordinary caller capability are rejected' {
    $request = New-AcceptedAdapterRequest
    $missing = Invoke-ChatpadNonExecutingNativeAdapter -Request $request
    $ordinary = Invoke-ChatpadNonExecutingNativeAdapter -Request $request -AuthorizationCapability ([pscustomobject]@{ allow = $true })
    Assert-AdapterCondition $missing.authorization_rejected 'missing capability accepted'
    Assert-AdapterCondition $ordinary.authorization_rejected 'ordinary object capability accepted'
    Assert-AdapterCondition ($ordinary.result_code -eq 'NATIVE_EXECUTION_PROHIBITED') 'ordinary object changed execution result'
}

Invoke-AdapterTestCase 'strings booleans type names Add-Member wrappers and serialization cannot authorize' {
    $forged = [pscustomobject]@{ value = 'forged' }
    $forged.PSTypeNames.Insert(0, 'Chatpad.NativeAdapter.AuthorizationCapability')
    $forged | Add-Member -NotePropertyName authorize_native_execution -NotePropertyValue $true
    $wrapped = [pscustomobject]@{ inner = $forged }
    $serialized = [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($forged))
    foreach ($candidate in @('allow', $true, $forged, $wrapped, $serialized)) {
        $result = Invoke-ChatpadNonExecutingNativeAdapter -Request (New-AcceptedAdapterRequest) -AuthorizationCapability $candidate
        Assert-AdapterCondition $result.authorization_rejected 'forged capability was accepted'
        Assert-AdapterCondition $result.native_execution_prohibited 'forged capability removed prohibition'
        Assert-AdapterCondition (-not $result.native_operation_executed) 'forged capability executed operation'
    }
}

Invoke-AdapterTestCase 'SessionState and exports cannot retrieve an effective capability' {
    $retrieved = $module.SessionState.PSVariable.GetValue('NativeAdapterExecutionCapability', $null)
    $variables = @(& $module { @(Get-Variable | ForEach-Object { $_.Name }) })
    $exports = @($module.ExportedFunctions.Keys)
    Assert-AdapterCondition ($null -eq $retrieved) 'SessionState returned an effective capability'
    Assert-AdapterCondition ($variables -notcontains 'NativeAdapterExecutionCapability') 'module held a capability variable'
    Assert-AdapterCondition ($exports -notcontains 'New-ChatpadNativeMutationCapability') 'capability factory was exported'
    Assert-AdapterCondition ($exports -notcontains 'Invoke-NativeAdapterOfflineFakeSeam') 'internal fake seam was exported'
}

Invoke-AdapterTestCase 'failed validation makes zero fake backend calls' {
    $backend = New-ChatpadNativeAdapterFakeRecordingBackend
    $request = New-AcceptedAdapterRequest; $request.target_chain = @($request.target_chain[0])
    $result = & $module { param($r, $b) Invoke-NativeAdapterOfflineFakeSeam -Request $r -Backend $b } $request $backend
    Assert-AdapterCondition ($result.result -eq 'VALIDATION_REJECTED_NO_BACKEND_CALL') 'failed validation reached fake seam'
    Assert-AdapterCondition ($backend.calls.Count -eq 0) 'failed validation recorded a fake call'
    Assert-AdapterCondition ($result.attempted_fake_backend_calls -eq 0) 'failed validation reported fake calls'
}

Invoke-AdapterTestCase 'production backend is never selected by default' {
    $result = Invoke-ChatpadNonExecutingNativeAdapter -Request (New-AcceptedAdapterRequest)
    Assert-AdapterCondition (-not $result.production_backend_present) 'production backend present'
    Assert-AdapterCondition (-not $result.production_backend_loaded) 'production backend loaded'
    Assert-AdapterCondition (-not $result.backend_available) 'a backend was available by default'
}

Invoke-AdapterTestCase 'internal fake seam records only a non-native operation' {
    $backend = New-ChatpadNativeAdapterFakeRecordingBackend
    $result = & $module { param($r, $b) Invoke-NativeAdapterOfflineFakeSeam -Request $r -Backend $b } (New-AcceptedAdapterRequest) $backend
    Assert-AdapterCondition ($result.result -eq 'FAKE_OPERATION_RECORDED_NOT_NATIVE') 'approved fake operation was not recorded'
    Assert-AdapterCondition ($backend.calls.Count -eq 1) 'fake operation call count was not one'
    Assert-AdapterCondition (-not $backend.calls[0].native_io_performed) 'fake backend performed native I/O'
    foreach ($counter in $result.counters.PSObject.Properties) { Assert-AdapterCondition ($counter.Value -eq 0) "fake seam counter $($counter.Name) was non-zero" }
}

Invoke-AdapterTestCase 'result wording does not claim binding native runtime or live success' {
    $text = (Invoke-ChatpadNonExecutingNativeAdapter -Request (New-AcceptedAdapterRequest) | ConvertTo-Json -Depth 8)
    foreach ($claim in @('binding success', 'native success', 'runtime readiness', 'live readiness')) {
        Assert-AdapterCondition ($text -notmatch [regex]::Escape($claim)) "result claimed $claim"
    }
}

Invoke-AdapterTestCase 'all public prohibited-operation counters remain zero' {
    $result = Invoke-ChatpadNonExecutingNativeAdapter -Request (New-AcceptedAdapterRequest)
    foreach ($counter in $result.counters.PSObject.Properties) { Assert-AdapterCondition ($counter.Value -eq 0) "public counter $($counter.Name) was non-zero" }
    Assert-AdapterCondition ($result.attempted_fake_backend_calls -eq 0) 'public surface attempted a fake backend call'
}

$failed = @($tests | Where-Object { $_.result -ne 'PASS' })
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-nonexecuting-native-adapter-offline-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    tests = @($tests)
    prohibited_operation_counters = (Get-ChatpadNonExecutingNativeAdapterContract).counters
}
Write-Output $report
if ($failed.Count) { exit 1 }
