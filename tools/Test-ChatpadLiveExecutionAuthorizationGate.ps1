[CmdletBinding(PositionalBinding = $false)]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadLiveExecutionAuthorizationGate.psm1'
$coordinatorPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadOneShotNativeExecutionCoordinator.psm1'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0

function Assert-8H { param([bool]$Condition, [string]$Message) $script:assertionCount++; if (-not $Condition) { throw $Message } }
function Test-Case { param([string]$Name, [scriptblock]$Body) try { & $Body; $tests.Add([pscustomobject]@{ name = $Name; result = 'PASS' }) } catch { $tests.Add([pscustomobject]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message }) } }

Import-Module $modulePath -Force
$gateModule = Get-Module ChatpadLiveExecutionAuthorizationGate | Select-Object -First 1

function New-Request {
    [pscustomobject][ordered]@{
        operation = 'APPLY'
        target_chain = @('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
        live_authorization_phrase = 'AUTHORIZE_ONE_LIVE_NATIVE_APPLY_ATTEMPT'
        task_8e_evidence_sha256 = '493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F'
        task_8f_evidence_sha256 = '93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042'
        task_8g_evidence_sha256 = 'BB2016A9CFD85BFCA06862E7B3D386EE611355AA2416778BFDCB49C7A6C0BD12'
        task_8g_audited_implementation_commit = '79ec174dabd7e73f2d01021168921021bc118702'
        critical_source_hashes = @(
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadNonExecutingNativeAdapter.psm1'; sha256 = '78B85CBC2EB0FF58D65A5B97D35DEA9561FD7EA80E910444C2BEDC415C5AB919' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1'; sha256 = '77162617BAC6439921E3856A352ED8E940D43B549A717F2F58233C1445269754' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadOneShotNativeExecutionCoordinator.psm1'; sha256 = 'B639AAB4D3FBA440E1DD4183C71F8D5FCF54B632CF3DE2EAA91E50535B7277DA' },
            [pscustomobject][ordered]@{ path = 'tools/ExactInstance/ChatpadOneShotAuthorizationRegistry.cs'; sha256 = '9C85311242920C0C2DDCDAD9A7AED9A10C6F145F70DFA03B092607372485A462' }
        )
        rollback_recovery_reviewed = $true
        one_shot_attempt_understood = $true
    }
}

function New-Auth($request = (New-Request)) { (New-ChatpadOneShotLiveNativeApplyAuthorization -Request $request).authorization }
function Invoke-FakeConsumer($request, $authorization, $outcome = 'Success') { & $gateModule { param($r,$a,$o) Invoke-TestOnlyLiveGateRecordingConsumer -Request $r -Authorization $a -Outcome $o } $request $authorization $outcome }
function Assert-ZeroCounters($counters, [string]$Context) { foreach ($counter in $counters.PSObject.Properties) { Assert-8H ($counter.Value -eq 0) "$Context changed counter $($counter.Name)" } }
function Assert-Rejected($request, [string]$ExpectedDefect) {
    $result = New-ChatpadOneShotLiveNativeApplyAuthorization -Request $request
    Assert-8H (-not $result.authorization_issued) "$ExpectedDefect issued authorization"
    Assert-8H (@($result.pre_authorization_summary.defects) -contains $ExpectedDefect) "$ExpectedDefect was not reported"
    Assert-ZeroCounters $result.pre_authorization_summary.counters $ExpectedDefect
}

Test-Case 'exact valid authorization issuance returns summary and live object' {
    $result = New-ChatpadOneShotLiveNativeApplyAuthorization -Request (New-Request)
    Assert-8H $result.authorization_issued 'authorization not issued'
    Assert-8H ($result.authorization.GetType().FullName -eq 'Chatpad.LiveAuthorization.LiveNativeApplyAuthorization') 'wrong authorization type'
    Assert-8H ($result.pre_authorization_summary.production_provider_still_unavailable) 'production provider availability changed'
    Assert-8H (-not $result.pre_authorization_summary.live_invocation_performed) 'live invocation occurred'
    Assert-ZeroCounters $result.pre_authorization_summary.counters 'valid issuance'
}

foreach ($case in @(
    @{ name='missing live phrase'; field='live_authorization_phrase'; value=$null; defect='live_authorization_phrase' },
    @{ name='wrong live phrase'; field='live_authorization_phrase'; value='AUTHORIZE_TWO_ATTEMPTS'; defect='live_authorization_phrase' },
    @{ name='wrong phrase case'; field='live_authorization_phrase'; value='authorize_one_live_native_apply_attempt'; defect='live_authorization_phrase' },
    @{ name='phrase whitespace'; field='live_authorization_phrase'; value=' AUTHORIZE_ONE_LIVE_NATIVE_APPLY_ATTEMPT '; defect='live_authorization_phrase' },
    @{ name='wrong operation'; field='operation'; value='RESTORE'; defect='operation' },
    @{ name='wrong container'; field='shared_container_id'; value='{00000000-0000-0000-0000-000000000000}'; defect='shared_container_id' },
    @{ name='wrong operator confirmation'; field='operator_confirmation_id'; value='operator-confirmation-wrong'; defect='operator_confirmation_id' },
    @{ name='wrong TASK 8E identity'; field='task_8e_evidence_sha256'; value=('0'*64); defect='task_8e_evidence_sha256' },
    @{ name='wrong TASK 8F identity'; field='task_8f_evidence_sha256'; value=('0'*64); defect='task_8f_evidence_sha256' },
    @{ name='wrong TASK 8G identity'; field='task_8g_evidence_sha256'; value=('0'*64); defect='task_8g_evidence_sha256' },
    @{ name='wrong audited commit'; field='task_8g_audited_implementation_commit'; value='0000000000000000000000000000000000000000'; defect='task_8g_audited_implementation_commit' },
    @{ name='missing recovery acknowledgement'; field='rollback_recovery_reviewed'; value=$false; defect='rollback_recovery_reviewed' },
    @{ name='missing one-shot acknowledgement'; field='one_shot_attempt_understood'; value=$false; defect='one_shot_attempt_understood' }
)) {
    Test-Case $case.name {
        $request = New-Request
        if ($null -eq $case.value) { [void]$request.PSObject.Properties.Remove($case.field) } else { $request.($case.field) = $case.value }
        Assert-Rejected $request $case.defect
    }
}

Test-Case 'target removal is rejected' { $request = New-Request; $request.target_chain = @($request.target_chain[0], $request.target_chain[1]); Assert-Rejected $request 'target_chain' }
Test-Case 'target addition is rejected' { $request = New-Request; $request.target_chain += 'HID\VID_045E&PID_028E\EXTRA'; Assert-Rejected $request 'target_chain' }
Test-Case 'target reordering is rejected' { $request = New-Request; $request.target_chain = @($request.target_chain[1], $request.target_chain[0], $request.target_chain[2]); Assert-Rejected $request 'target_chain' }
Test-Case 'wrong critical source hash is rejected' { $request = New-Request; $request.critical_source_hashes[1].sha256 = '0' * 64; Assert-Rejected $request 'critical_source_hashes' }

Test-Case 'serialization deserialization copy and wrappers are rejected' {
    $request = New-Request; $auth = New-Auth $request
    foreach ($candidate in @(
        [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($auth)),
        [pscustomobject]@{ inner = $auth },
        [pscustomobject]@{ live = $true },
        'AUTHORIZE_ONE_LIVE_NATIVE_APPLY_ATTEMPT',
        $true
    )) {
        $out = Invoke-FakeConsumer $request $candidate
        Assert-8H ($out.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'candidate was accepted'
        Assert-8H ($out.provider_call_count -eq 0) 'candidate reached fake provider'
    }
}

Test-Case 'request transfer rejects before fake consumer' {
    $request = New-Request; $auth = New-Auth $request; $other = New-Request; $other.task_8f_evidence_sha256 = '0' * 64
    $out = Invoke-FakeConsumer $other $auth
    Assert-8H ($out.result -eq 'REQUEST_REJECTED_NO_RECORDING_CONSUMPTION') 'transferred request was accepted'
    Assert-8H ($out.provider_call_count -eq 0) 'transferred request reached fake provider'
}

Test-Case 'recording and live authorizations are not type-compatible' {
    Import-Module $coordinatorPath -Force
    $coordinator = Get-Module ChatpadOneShotNativeExecutionCoordinator | Select-Object -First 1
    $request = New-Request
    $recordingRequest = [pscustomobject][ordered]@{
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        task_8e_evidence_path = 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json'
        task_8e_evidence_sha256 = '493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F'
        task_8f_evidence_path = 'docs/evidence/native-adapter-production-backend-source-task-8f-1.json'
        task_8f_evidence_sha256 = '93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042'
        target_chain = @('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
    }
    $recordingAuth = (& $coordinator { param($r) New-TestOnlyRecordingProviderAuthorization -Request $r } $recordingRequest).authorization
    $liveOut = Invoke-FakeConsumer $request $recordingAuth
    Assert-8H ($liveOut.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'recording authorization accepted by live consumer'
    $liveAuth = New-Auth $request
    $recordingOut = & $coordinator { param($r,$a) Invoke-OneShotNativeExecutionCoordinator -Request $r -AuthorizationCapability $a } $recordingRequest $liveAuth
    Assert-8H ($recordingOut.provider_call_count -eq 0) 'live authorization accepted by recording coordinator'
}

Test-Case 'replay after successful fake consumption is rejected' {
    $request = New-Request; $auth = New-Auth $request
    $first = Invoke-FakeConsumer $request $auth 'Success'; $second = Invoke-FakeConsumer $request $auth 'Success'
    Assert-8H ($first.result -eq 'OFFLINE_RECORDING_CONSUMER_COMPLETED_NOT_NATIVE') 'first success failed'
    Assert-8H ($second.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'success replay accepted'
}

Test-Case 'replay after fake consumer failure is rejected' {
    $request = New-Request; $auth = New-Auth $request
    $first = Invoke-FakeConsumer $request $auth 'Failure'; $second = Invoke-FakeConsumer $request $auth 'Success'
    Assert-8H ($first.result -eq 'OFFLINE_RECORDING_CONSUMER_FAILED_NOT_NATIVE') 'fake failure did not occur'
    Assert-8H ($second.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'failure replay accepted'
}

Test-Case 'replay after exception is rejected' {
    $request = New-Request; $auth = New-Auth $request; $thrown = $false
    try { [void](Invoke-FakeConsumer $request $auth 'Exception') } catch { $thrown = ($_.Exception.Message -match 'OFFLINE_LIVE_GATE_RECORDING_CONSUMER_EXCEPTION_AFTER_CONSUME') }
    $second = Invoke-FakeConsumer $request $auth 'Success'
    Assert-8H $thrown 'exception was not thrown'
    Assert-8H ($second.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'exception replay accepted'
}

Test-Case 'replay after cleanup failure is rejected' {
    $request = New-Request; $auth = New-Auth $request; $thrown = $false
    try { [void](Invoke-FakeConsumer $request $auth 'CleanupFailure') } catch { $thrown = ($_.Exception.Message -match 'OFFLINE_LIVE_GATE_RECORDING_CONSUMER_CLEANUP_FAILURE_AFTER_CONSUME') }
    $second = Invoke-FakeConsumer $request $auth 'Success'
    Assert-8H $thrown 'cleanup failure was not thrown'
    Assert-8H ($second.result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL') 'cleanup replay accepted'
}

Test-Case 'two concurrent contenders use actual live registry and admit one' {
    $script = @'
param($modulePath,$request,$auth,$ready,$go)
Import-Module $modulePath -Force
$m = Get-Module ChatpadLiveExecutionAuthorizationGate
& $m { param($r,$a,$ready,$go) Invoke-TestOnlyLiveGateRecordingConsumer -Request $r -Authorization $a -RaceReady $ready -RaceGo $go } $request $auth $ready $go
'@
    for ($i = 1; $i -le 16; $i++) {
        $request = New-Request; $auth = New-Auth $request; $ready = [Threading.CountdownEvent]::new(2); $go = [Threading.ManualResetEventSlim]::new($false)
        $p1 = [PowerShell]::Create(); $p2 = [PowerShell]::Create()
        foreach ($p in @($p1,$p2)) { [void]$p.AddScript($script).AddArgument($modulePath).AddArgument($request).AddArgument($auth).AddArgument($ready).AddArgument($go) }
        $a1 = $p1.BeginInvoke(); $a2 = $p2.BeginInvoke(); Assert-8H ($ready.Wait(5000)) 'race was not ready'; $go.Set()
        $r1 = @($p1.EndInvoke($a1))[0]; $r2 = @($p2.EndInvoke($a2))[0]
        $p1.Dispose(); $p2.Dispose(); $ready.Dispose(); $go.Dispose()
        $results = @($r1,$r2)
        Assert-8H ((@($results | Where-Object result -eq 'OFFLINE_RECORDING_CONSUMER_COMPLETED_NOT_NATIVE').Count) -eq 1) 'concurrency winner count changed'
        Assert-8H ((@($results | Where-Object result -eq 'LIVE_AUTHORIZATION_REPLAY_OR_TYPE_REJECTED_NO_PROVIDER_CALL').Count) -eq 1) 'concurrency replay count changed'
        Assert-8H ((@($results | Measure-Object provider_call_count -Sum).Sum) -eq 1) 'concurrency fake provider count changed'
        foreach ($result in $results) { Assert-ZeroCounters $result.counters 'concurrency' }
    }
}

Test-Case 'import produces no authorization and production provider remains unavailable' {
    Assert-8H ($gateModule.ExportedFunctions.Keys.Count -eq 1) 'unexpected export count'
    Assert-8H ($gateModule.ExportedFunctions.ContainsKey('New-ChatpadOneShotLiveNativeApplyAuthorization')) 'live gate export missing'
    foreach ($name in @('LiveAuthorization','ProductionAuthorizationCapability','NativeAdapterExecutionCapability')) {
        Assert-8H ($gateModule.SessionState.PSVariable.GetValue($name, $null) -eq $null) "$name appeared on import"
    }
    $text = Get-Content -Raw $modulePath
    foreach ($pattern in @('Get-CimInstance','Get-WmiObject','Get-PnpDevice','Get-ItemProperty','pnputil','devcon','Start-Process','LoadLibrary','GetProcAddress','New-GatedProductionNativeProviderDescriptor','Invoke-GatedProductionBackendRecordingPlan')) {
        Assert-8H ($text -notmatch $pattern) "forbidden source pattern present: $pattern"
    }
}

Test-Case 'every prohibited counter remains zero' {
    $request = New-Request; $result = New-ChatpadOneShotLiveNativeApplyAuthorization -Request $request; $out = Invoke-FakeConsumer $request $result.authorization
    Assert-ZeroCounters $out.counters 'final zero counter'
    foreach ($flag in @('production_provider_registered','production_provider_selected','production_provider_constructed','production_provider_loaded','production_provider_invoked','live_invocation_performed')) {
        Assert-8H (-not [bool]$out.$flag) "$flag changed"
    }
}

$failed = @($tests | Where-Object result -ne 'PASS')
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-live-execution-authorization-gate-offline-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    concurrency = [pscustomobject][ordered]@{ contenders = 2; successful_consumptions = 1; replay_rejections = 1; production_constructions = 0; native_invocations = 0; bounded_iterations = 16 }
    production_provider_state = [pscustomobject][ordered]@{ production_provider_registered = $false; production_provider_selected = $false; production_provider_constructed = $false; production_provider_loaded = $false; production_provider_invoked = $false }
    prohibited_operation_counters = (& $gateModule { New-LiveGateZeroCounters })
    tests = @($tests)
}
$report
if ($failed.Count) { exit 1 }
