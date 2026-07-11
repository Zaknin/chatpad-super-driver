[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$executorPath = Join-Path $PSScriptRoot 'Invoke-ChatpadOneShotLiveNativeApply.ps1'
$gatePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadLiveExecutionAuthorizationGate.psm1'
$coordinatorPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadOneShotNativeExecutionCoordinator.psm1'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0
$concurrencySummaries = [Collections.Generic.List[object]]::new()

function Assert-8I {
    param([bool]$Condition, [string]$Message)
    $script:assertionCount++
    if (-not $Condition) { throw $Message }
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try { & $Body; $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'PASS' }) }
    catch { $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message }) }
}

function Assert-ZeroProhibitedCounters {
    param([object]$Result, [string]$Context)
    Assert-8I ($Result.backend_load_count -eq 0) "$Context backend load changed"
    Assert-8I ($Result.provider_construction_count -eq 0) "$Context production provider construction changed"
    Assert-8I ($Result.production_provider_construction_count -eq 0) "$Context production provider construction alias changed"
    Assert-8I (-not $Result.production_provider_constructed) "$Context production provider constructed flag changed"
    Assert-8I ($Result.native_invocation_count -eq 0) "$Context native invocation changed"
    Assert-8I ($Result.apply_attempt_count -eq 0) "$Context apply attempt changed"
    Assert-8I ($Result.retry_count -eq 0) "$Context retry count changed"
    foreach ($counter in $Result.counters.PSObject.Properties) { Assert-8I ($counter.Value -eq 0) "$Context prohibited counter $($counter.Name) changed" }
}

function Assert-RejectionBeforeConstruction {
    param([object]$Result, [string]$Context)
    Assert-8I (($Result.final_status -eq 'AUTHORIZATION_REJECTED') -or ($Result.final_status -eq 'PRECONDITION_REJECTED')) "$Context wrong final status $($Result.final_status)"
    Assert-8I (-not $Result.authorization_consumed) "$Context consumed authorization"
    Assert-8I ($Result.fake_construction_marker_count -eq 0) "$Context fake construction marker changed"
    Assert-8I ($Result.fake_invocation_marker_count -eq 0) "$Context fake invocation marker changed"
    Assert-ZeroProhibitedCounters $Result $Context
}

function New-TestAuthorization {
    $request = New-ChatpadOneShotLiveApplyAuthorizationRequest
    $issued = New-ChatpadOneShotLiveNativeApplyAuthorization -Request $request
    Assert-8I $issued.authorization_issued 'test authorization was not issued'
    $issued.authorization
}

function Invoke-Fake {
    param([AllowNull()][object]$Authorization, [string]$Outcome = 'Success', [AllowNull()][object]$Contract = $null)
    if ($null -eq $Contract) { $Contract = New-ChatpadOneShotLiveApplyExecutorContract }
    Invoke-ChatpadOneShotLiveApplyExecutorCore -ExecutionMode TestFake -Authorization $Authorization -Contract $Contract -FakeOutcome $Outcome
}

function Copy-ObjectDeep {
    param([Parameter(Mandatory)][object]$Object)
    [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($Object))
}

function Set-ContractValue {
    param([Parameter(Mandatory)][object]$Contract, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Value)
    [void]$Contract.PSObject.Properties.Remove($Name)
    $Contract | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
}

function Get-TextIndex {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Needle)
    $index = $Text.IndexOf($Needle, [StringComparison]::Ordinal)
    Assert-8I ($index -ge 0) "source token missing: $Needle"
    $index
}

Import-Module $gatePath -Force
Import-Module $coordinatorPath -Force
$gateModule = Get-Module ChatpadLiveExecutionAuthorizationGate | Select-Object -First 1
$coordinatorModule = Get-Module ChatpadOneShotNativeExecutionCoordinator | Select-Object -First 1
$dotSourceOutput = . $executorPath

Test-Case 'script parses and dot-source loading is non-executing' {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($executorPath, [ref]$tokens, [ref]$errors)
    Assert-8I (@($errors).Count -eq 0) 'executor parse errors were present'
    Assert-8I (@($dotSourceOutput).Count -eq 0) 'dot-source emitted output'
    $module = Get-Module ChatpadLiveExecutionAuthorizationGate | Select-Object -First 1
    Assert-8I ($module.ExportedFunctions.ContainsKey('New-ChatpadOneShotLiveNativeApplyAuthorization')) 'gate export missing after dot-source'
}

Test-Case 'missing execute switch remains non-executing' {
    $result = & $executorPath
    Assert-8I ($result.final_status -eq 'PRECONDITION_REJECTED') 'missing execute switch did not reject'
    Assert-8I ($result.error_category -eq 'EXECUTE_LIVE_APPLY_SWITCH_REQUIRED') 'missing execute switch category changed'
    Assert-RejectionBeforeConstruction $result 'missing execute switch'
}

Test-Case 'ordinary operator surface is minimal' {
    $command = Get-Command $executorPath
    $public = @($command.Parameters.Keys | Where-Object { $_ -notin @('Verbose','Debug','ErrorAction','WarningAction','InformationAction','ProgressAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable') } | Sort-Object)
    Assert-8I (($public -join '|') -eq 'Authorization|ExecuteLiveApply') "public parameters changed: $($public -join ',')"
    foreach ($forbidden in @('Provider','ProviderFactory','Callback','ScriptBlock','Delegate','Function','NativeOperation','Operation','TargetChain','ContainerId','InfPath','DriverCandidate','DevicePath','RetryCount','RollbackAction','CleanupStrategy','ExecutionPayload','TestMode','Fake','ExecutionMode')) {
        Assert-8I ($public -notcontains $forbidden) "forbidden public parameter exposed: $forbidden"
    }
}

Test-Case 'structured result contract exposes production counters without sensitive state' {
    $result = & $executorPath
    foreach ($name in @('backend_load_count','production_provider_construction_count','provider_construction_count','native_invocation_count','apply_attempt_count','retry_count','cleanup_attempted','cleanup_result','source_validation_result','exception_type','backend_result_summary','contract_validation')) {
        Assert-8I ($null -ne $result.PSObject.Properties[$name]) "result contract missing $name"
    }
    foreach ($forbidden in @('Authorization','BackendModule','Provider','ProductionProvider','NativeHandle','Delegate','ScriptBlock','FunctionReference','Callback','ReusableExecutionState')) {
        Assert-8I ($null -eq $result.PSObject.Properties[$forbidden]) "result exposed forbidden property $forbidden"
    }
    Assert-8I ($result.backend_load_count -eq 0) 'missing-switch result loaded backend'
    Assert-8I ($result.production_provider_construction_count -eq 0) 'missing-switch result constructed provider'
    Assert-8I ($result.native_invocation_count -eq 0) 'missing-switch result invoked native path'
}

Test-Case 'production branch is source complete but not executed by focused tests' {
    $source = Get-Content -Raw $executorPath
    $obsoleteMode = 'Production' + 'Disabled'
    $obsoleteCategory = 'TASK_8I_1A_PRODUCTION_PROVIDER_' + 'CONSTRUCTION_DISABLED'
    $obsoleteFlag = 'production_provider_' + 'construction_enabled'
    Assert-8I ($source -notmatch $obsoleteMode) 'obsolete production mode remained in source'
    Assert-8I ($source -notmatch $obsoleteCategory) 'obsolete production category remained in source'
    Assert-8I ($source -notmatch $obsoleteFlag) 'obsolete production flag remained in source'
    Assert-8I ($source -match 'Invoke-ChatpadOneShotLiveApplyExecutorCore -ExecutionMode Production -Authorization') 'public entrypoint does not select production mode'
    Assert-8I (([regex]::Matches($source, [regex]::Escape("task_8f_backend_path = 'tools/ExactInstance/ChatpadGatedProductionNativeAdapterBackend.psm1'"))).Count -eq 1) 'fixed backend path occurrence changed'
    Assert-8I ($source -match "task_8f_private_provider_constructor = 'New-GatedProductionNativeProviderDescriptor'") 'fixed private constructor name missing'
    Assert-8I ($source -match "task_8f_private_apply_invoker = 'Invoke-GatedProductionBackendRecordingPlan'") 'fixed private apply invoker name missing'
    $contractIndex = Get-TextIndex $source 'Test-ChatpadOneShotLiveApplyExecutorContract -Contract $Contract'
    $authTypeIndex = Get-TextIndex $source 'Authorization -isnot [Chatpad.LiveAuthorization.LiveNativeApplyAuthorization]'
    $consumeIndex = Get-TextIndex $source 'TryConsumeOneShotLiveNativeApplyAuthorization($Authorization, $fingerprint)'
    $backendIndex = Get-TextIndex $source '$backendModule = Import-ChatpadOneShotLiveApplyProductionBackend'
    $constructionIndex = Get-TextIndex $source '$productionProvider = New-ChatpadOneShotLiveApplyProductionProvider -BackendModule $backendModule'
    $invocationIndex = Get-TextIndex $source '$backendResult = Invoke-ChatpadOneShotLiveApplyNativeApply -BackendModule $backendModule -BackendRequest $backendRequest -ProductionProvider $productionProvider'
    $cleanupIndex = Get-TextIndex $source 'finally {'
    Assert-8I ($contractIndex -lt $authTypeIndex) 'contract validation does not precede authorization validation'
    Assert-8I ($authTypeIndex -lt $consumeIndex) 'authorization validation does not precede consumption'
    Assert-8I ($consumeIndex -lt $backendIndex) 'authorization consumption does not precede backend load'
    Assert-8I ($backendIndex -lt $constructionIndex) 'backend load does not precede provider construction'
    Assert-8I ($constructionIndex -lt $invocationIndex) 'provider construction does not precede apply invocation'
    Assert-8I ($invocationIndex -lt $cleanupIndex) 'apply invocation does not precede guaranteed cleanup'
    Assert-8I (([regex]::Matches($source, [regex]::Escape('$productionProvider = New-ChatpadOneShotLiveApplyProductionProvider -BackendModule $backendModule'))).Count -eq 1) 'production construction call count changed'
    Assert-8I (([regex]::Matches($source, [regex]::Escape('$backendResult = Invoke-ChatpadOneShotLiveApplyNativeApply -BackendModule $backendModule -BackendRequest $backendRequest -ProductionProvider $productionProvider'))).Count -eq 1) 'native apply invocation call count changed'
    $productionBlock = $source.Substring($consumeIndex, (Get-TextIndex $source '$fakeConstruction = 0') - $consumeIndex)
    Assert-8I ($productionBlock -notmatch '\b(for|foreach|while|do)\b') 'production construction or invocation is enclosed by a loop'
    foreach ($status in @('PRECONDITION_REJECTED','AUTHORIZATION_REJECTED','AUTHORIZATION_CONSUMED','BACKEND_LOAD_FAILED','PROVIDER_CONSTRUCTION_FAILED','NATIVE_APPLY_FAILED','NATIVE_APPLY_COMPLETED','RESULT_CAPTURE_FAILED','CLEANUP_FAILED')) {
        Assert-8I ($source.Contains($status)) "required result status missing: $status"
    }
}

Test-Case 'authorization rejection cases stay before construction' {
    $request = New-ChatpadOneShotLiveApplyAuthorizationRequest
    $recordingAuthorization = (& $coordinatorModule { param($r) New-TestOnlyRecordingProviderAuthorization -Request $r -Operation 'APPLY' } ([pscustomobject][ordered]@{
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        task_8e_evidence_path = 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json'
        task_8e_evidence_sha256 = '493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F'
        task_8f_evidence_path = 'docs/evidence/native-adapter-production-backend-source-task-8f-1.json'
        task_8f_evidence_sha256 = '93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042'
        target_chain = @('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
    })).authorization
    $valid = New-TestAuthorization
    $serialized = [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($valid))
    $shell = [Runtime.Serialization.FormatterServices]::GetUninitializedObject([Chatpad.LiveAuthorization.LiveNativeApplyAuthorization])
    $wrongFingerprint = [Chatpad.LiveAuthorization.LiveAuthorizationRegistry]::CreateOneShotLiveNativeApplyAuthorization('wrong-fingerprint')
    $consumed = New-TestAuthorization
    [void](Invoke-Fake $consumed)
    $candidates = @(
        [pscustomobject]@{ name = 'null'; value = $null },
        [pscustomobject]@{ name = 'string'; value = 'AUTHORIZE' },
        [pscustomobject]@{ name = 'boolean'; value = $true },
        [pscustomobject]@{ name = 'recording authorization'; value = $recordingAuthorization },
        [pscustomobject]@{ name = 'reflection shell'; value = $shell },
        [pscustomobject]@{ name = 'reconstructed object'; value = [pscustomobject]@{ fingerprint = 'copied' } },
        [pscustomobject]@{ name = 'serialized object'; value = $serialized },
        [pscustomobject]@{ name = 'wrapper'; value = [pscustomobject]@{ inner = $valid } },
        [pscustomobject]@{ name = 'copied properties'; value = [pscustomobject]@{ type = $valid.GetType().FullName } },
        [pscustomobject]@{ name = 'wrong fingerprint'; value = $wrongFingerprint },
        [pscustomobject]@{ name = 'consumed authorization'; value = $consumed }
    )
    foreach ($candidate in $candidates) {
        $result = & $executorPath -ExecuteLiveApply -Authorization $candidate.value
        Assert-RejectionBeforeConstruction $result "authorization rejection $($candidate.name)"
        Assert-8I ($result.final_status -eq 'AUTHORIZATION_REJECTED') "authorization rejection $($candidate.name) wrong status"
    }
    Assert-8I ($request.operation -eq 'APPLY') 'request helper changed while testing candidates'
}

Test-Case 'exact contract rejection cases stay before construction' {
    $baseAuth = New-TestAuthorization
    $cases = @(
        @{ name = 'wrong operation'; mutate = { param($c) $c.operation = 'RESTORE' } },
        @{ name = 'wrong target'; mutate = { param($c) $c.target_chain[1] = 'USB\VID_045E&PID_028E&IG_00\WRONG' } },
        @{ name = 'reordered targets'; mutate = { param($c) $c.target_chain = @($c.target_chain[1],$c.target_chain[0],$c.target_chain[2]) } },
        @{ name = 'missing target'; mutate = { param($c) $c.target_chain = @($c.target_chain[0],$c.target_chain[1]) } },
        @{ name = 'added target'; mutate = { param($c) $c.target_chain += 'HID\VID_045E&PID_028E\EXTRA' } },
        @{ name = 'wrong container'; mutate = { param($c) $c.shared_container_id = '{00000000-0000-0000-0000-000000000000}' } },
        @{ name = 'wrong task 8g commit'; mutate = { param($c) $c.task_8g_audited_implementation_commit = '0000000000000000000000000000000000000000' } },
        @{ name = 'wrong task 8h commit'; mutate = { param($c) $c.task_8h_audited_implementation_commit = '0000000000000000000000000000000000000000' } },
        @{ name = 'wrong source hash'; mutate = { param($c) $c.runtime_critical_source_hashes[0].sha256 = '0' * 64 } },
        @{ name = 'missing source hash'; mutate = { param($c) $c.runtime_critical_source_hashes = @($c.runtime_critical_source_hashes | Select-Object -Skip 1) } },
        @{ name = 'extra source hash'; mutate = { param($c) $c.runtime_critical_source_hashes += [pscustomobject][ordered]@{ path = 'tools/ExactInstance/Extra.psm1'; sha256 = 'A' * 64 } } },
        @{ name = 'wrong task 8h root hash'; mutate = { param($c) $c.externally_validated_task_8h_root_source_hashes[0].sha256 = '0' * 64 } }
    )
    foreach ($case in $cases) {
        $contract = Copy-ObjectDeep (New-ChatpadOneShotLiveApplyExecutorContract)
        & $case.mutate $contract
        $result = Invoke-Fake $baseAuth 'Success' $contract
        Assert-RejectionBeforeConstruction $result "contract rejection $($case.name)"
        Assert-8I ($result.error_category -eq 'CONTRACT_REJECTED') "contract rejection $($case.name) wrong category"
    }
    $usable = Invoke-Fake $baseAuth
    Assert-8I $usable.authorization_consumed 'contract rejection consumed the valid authorization'
    Assert-8I ($usable.final_status -eq 'NATIVE_APPLY_COMPLETED') 'valid authorization did not remain usable after contract rejections'
}

Test-Case 'fake success proves exact post-consumption event order' {
    $auth = New-TestAuthorization
    $result = Invoke-Fake $auth
    $expected = @('contract_validated','authorization_validated','authorization_consumed','fake_construction_marker','fake_invocation_marker','result_captured','cleanup_completed')
    Assert-8I ($result.authorization_consumed) 'fake success did not consume authorization'
    Assert-8I (($result.event_order -join '|') -eq ($expected -join '|')) 'event order changed'
    Assert-8I ([array]::IndexOf(@($result.event_order), 'authorization_consumed') -lt [array]::IndexOf(@($result.event_order), 'fake_construction_marker')) 'construction marker came before consumption'
    Assert-8I ($result.fake_construction_marker_count -eq 1) 'fake construction marker count changed'
    Assert-8I ($result.fake_invocation_marker_count -eq 1) 'fake invocation marker count changed'
    Assert-8I ($result.final_status -eq 'NATIVE_APPLY_COMPLETED') 'fake success status changed'
    Assert-ZeroProhibitedCounters $result 'fake success'
}

Test-Case 'failure outcomes permanently consume without retry or replay' {
    $outcomes = @(
        @{ outcome = 'Success'; status = 'NATIVE_APPLY_COMPLETED'; construction = 1; invocation = 1 },
        @{ outcome = 'ConstructionFailure'; status = 'PROVIDER_CONSTRUCTION_FAILED'; construction = 0; invocation = 0 },
        @{ outcome = 'InvocationFailure'; status = 'NATIVE_APPLY_FAILED'; construction = 1; invocation = 0 },
        @{ outcome = 'Exception'; status = 'NATIVE_APPLY_FAILED'; construction = 1; invocation = 0 },
        @{ outcome = 'ResultCaptureFailure'; status = 'RESULT_CAPTURE_FAILED'; construction = 1; invocation = 1 },
        @{ outcome = 'CleanupFailure'; status = 'CLEANUP_FAILED'; construction = 1; invocation = 1 }
    )
    foreach ($case in $outcomes) {
        $auth = New-TestAuthorization
        $first = Invoke-Fake $auth $case.outcome
        Assert-8I ($first.authorization_consumed) "$($case.outcome) did not consume"
        Assert-8I ($first.final_status -eq $case.status) "$($case.outcome) wrong final status $($first.final_status)"
        Assert-8I ($first.fake_construction_marker_count -eq $case.construction) "$($case.outcome) wrong construction marker count"
        Assert-8I ($first.fake_invocation_marker_count -eq $case.invocation) "$($case.outcome) wrong invocation marker count"
        Assert-ZeroProhibitedCounters $first $case.outcome
        $replay = Invoke-Fake $auth
        Assert-8I ($replay.final_status -eq 'AUTHORIZATION_REJECTED') "$($case.outcome) replay was not rejected"
        Assert-8I (-not $replay.authorization_consumed) "$($case.outcome) replay claimed consumption"
        Assert-8I ($replay.fake_construction_marker_count -eq 0) "$($case.outcome) replay constructed"
        Assert-8I ($replay.fake_invocation_marker_count -eq 0) "$($case.outcome) replay invoked"
        Assert-ZeroProhibitedCounters $replay "$($case.outcome) replay"
    }
}

Test-Case 'two-contender fake race admits exactly one winner per iteration' {
    if ($null -eq ('Chatpad.Testing.LiveApplyExecutorRaceHarness' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Reflection;
using System.Threading;

namespace Chatpad.Testing {
    public static class LiveApplyExecutorRaceHarness {
        private static Type FindType(string fullName) {
            foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies()) {
                Type type = assembly.GetType(fullName, false);
                if (type != null) return type;
            }
            return null;
        }

        public static bool[] Race(object authorization, string fingerprint, int contenders) {
            if (authorization == null) throw new ArgumentNullException("authorization");
            if (fingerprint == null) throw new ArgumentNullException("fingerprint");
            Type registryType = FindType("Chatpad.LiveAuthorization.LiveAuthorizationRegistry");
            if (registryType == null) throw new InvalidOperationException("live authorization registry type not loaded");
            MethodInfo consume = registryType.GetMethod("TryConsumeOneShotLiveNativeApplyAuthorization", BindingFlags.Public | BindingFlags.Static);
            if (consume == null) throw new InvalidOperationException("live authorization consume method not found");
            bool[] winners = new bool[contenders];
            Exception[] failures = new Exception[contenders];
            using (CountdownEvent ready = new CountdownEvent(contenders))
            using (ManualResetEventSlim go = new ManualResetEventSlim(false)) {
                Thread[] threads = new Thread[contenders];
                for (int index = 0; index < contenders; index++) {
                    int captured = index;
                    threads[index] = new Thread(delegate() {
                        try {
                            ready.Signal();
                            go.Wait();
                            winners[captured] = (bool)consume.Invoke(null, new object[] { authorization, fingerprint });
                        } catch (Exception ex) {
                            failures[captured] = ex;
                        }
                    });
                    threads[index].IsBackground = true;
                    threads[index].Start();
                }
                if (!ready.Wait(5000)) throw new InvalidOperationException("race contenders did not reach atomic gate");
                go.Set();
                for (int index = 0; index < contenders; index++) threads[index].Join();
            }
            for (int index = 0; index < failures.Length; index++) {
                if (failures[index] != null) throw new InvalidOperationException("race contender failed", failures[index]);
            }
            return winners;
        }
    }
}
'@
    }
    $iterations = 12
    for ($iteration = 1; $iteration -le $iterations; $iteration++) {
        $auth = New-TestAuthorization
        $contract = New-ChatpadOneShotLiveApplyExecutorContract
        $fingerprint = & $gateModule { param($request) Get-LiveGateRequestFingerprint -Request $request } (Get-ChatpadLiveApplyObject $contract 'gate_authorization_request' $null)
        $winnerFlags = [Chatpad.Testing.LiveApplyExecutorRaceHarness]::Race($auth, $fingerprint, 2)
        $winners = @($winnerFlags | Where-Object { $_ })
        $rejections = @($winnerFlags | Where-Object { -not $_ })
        $replay = Invoke-Fake $auth
        $fakeConstruction = $winners.Count
        $fakeInvocation = $winners.Count
        $productionConstruction = 0
        $nativeInvocation = 0
        Assert-8I ($winnerFlags.Count -eq 2) "race result count changed at iteration $iteration"
        Assert-8I ($winners.Count -eq 1) "race winner count changed at iteration $iteration"
        Assert-8I ($rejections.Count -eq 1) "race rejection count changed at iteration $iteration"
        Assert-8I ($replay.final_status -eq 'AUTHORIZATION_REJECTED') "race replay was not permanently rejected at iteration $iteration"
        Assert-8I ($fakeConstruction -eq 1) "race fake construction count changed at iteration $iteration"
        Assert-8I ($fakeInvocation -eq 1) "race fake invocation count changed at iteration $iteration"
        Assert-8I ($productionConstruction -eq 0) "race production construction changed at iteration $iteration"
        Assert-8I ($nativeInvocation -eq 0) "race native invocation changed at iteration $iteration"
        Assert-ZeroProhibitedCounters $replay "race iteration $iteration replay"
        $concurrencySummaries.Add([pscustomobject][ordered]@{ iteration = $iteration; contenders = 2; authorization_winners = $winners.Count; fake_construction_markers = $fakeConstruction; fake_invocation_markers = $fakeInvocation; replay_rejections = $rejections.Count; production_constructions = $productionConstruction; native_invocations = $nativeInvocation; device_queries = 0; windows_mutations = 0 })
    }
    Assert-8I ($iterations -eq 12) 'race iteration count changed'
}

Test-Case 'structured result omits sensitive objects and reusable execution state' {
    $result = Invoke-Fake (New-TestAuthorization)
    foreach ($forbidden in @('Authorization','Provider','NativeHandle','Delegate','ScriptBlock','FunctionReference','Callback','ReusableExecutionState')) {
        Assert-8I ($null -eq $result.PSObject.Properties[$forbidden]) "result exposed forbidden property $forbidden"
    }
    Assert-8I (-not $result.authorization_object_exposed) 'authorization object exposure flag changed'
    Assert-8I (-not $result.production_provider_escaped) 'provider escaped flag changed'
    Assert-8I (-not $result.reusable_execution_state_exposed) 'reusable state flag changed'
}

$failed = @($tests | Where-Object { $_.result -ne 'PASS' })
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-one-shot-live-native-apply-executor-offline-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    tests = @($tests)
    concurrency_iterations = @($concurrencySummaries)
    prohibited_operation_counters = New-ChatpadLiveApplyZeroCounters
}
Write-Output $report
if ($failed.Count) { exit 1 }
