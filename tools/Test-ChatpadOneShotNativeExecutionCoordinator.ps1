[CmdletBinding(PositionalBinding = $false)]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadOneShotNativeExecutionCoordinator.psm1'
$adapterPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadNonExecutingNativeAdapter.psm1'
$backendPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadGatedProductionNativeAdapterBackend.psm1'
$tests = [Collections.Generic.List[object]]::new(); $assertionCount = 0
function Assert-OneShot { param([bool]$Condition,[string]$Message) $script:assertionCount++; if(-not $Condition){throw $Message} }
function Test-Case { param([string]$Name,[scriptblock]$Body) try { & $Body; $tests.Add([pscustomobject]@{name=$Name;result='PASS'}) } catch { $tests.Add([pscustomobject]@{name=$Name;result='FAIL';detail=$_.Exception.Message}) } }
function New-Request { [pscustomobject][ordered]@{contract_evidence_path='docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json';contract_evidence_sha256='1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080';task_8e_evidence_path='docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json';task_8e_evidence_sha256='493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F';task_8f_evidence_path='docs/evidence/native-adapter-production-backend-source-task-8f-1.json';task_8f_evidence_sha256='93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042';target_chain=@('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000');shared_container_id='{828F4587-006F-5AD1-B169-6AF57905DFDE}';operator_confirmation_id='operator-confirmation-c445630fbb303c7c'} }
Import-Module $modulePath -Force; Import-Module $adapterPath -Force; Import-Module $backendPath -Force
$coordinatorModule=Get-Module -Name ChatpadOneShotNativeExecutionCoordinator | Select-Object -First 1; $backendModule=Get-Module -Name ChatpadGatedProductionNativeAdapterBackend | Select-Object -First 1
function New-Provider([string]$FailAt=''){ & $backendModule { param($f) New-GatedProductionRecordingProvider -FailAt $f } $FailAt }
function New-Cap($r,$p=$null,[string]$op='APPLY'){ (& $coordinatorModule { param($r,$o) New-TestOnlyRecordingProviderAuthorization -Request $r -Operation $o } $r $op).authorization }
function Invoke-Coordinator($r,$cap,$p=$null,[string]$op='APPLY'){ & $coordinatorModule { param($r,$c,$o) Invoke-OneShotNativeExecutionCoordinator -Request $r -AuthorizationCapability $c -Operation $o } $r $cap $op }
function Get-RegistrySignatureText([Reflection.MethodBase]$Member) {
    $parameters = @($Member.GetParameters() | ForEach-Object { "$($_.ParameterType.FullName) $($_.Name)" })
    "$($Member.ReturnType.FullName) $($Member.DeclaringType.FullName).$($Member.Name)($($parameters -join ', '))"
}
function Get-ManagedRegistrySurface {
    $type = [Chatpad.OneShotAuthorization.Registry]
    [pscustomobject]@{
        methods = @($type.GetMethods([Reflection.BindingFlags]'Public,Static') | Where-Object DeclaringType -eq $type | Sort-Object Name | ForEach-Object { Get-RegistrySignatureText $_ })
        constructors = @($type.GetConstructors([Reflection.BindingFlags]'Public,Instance,Static') | Sort-Object Name | ForEach-Object { Get-RegistrySignatureText $_ })
    }
}
function Invoke-RecordingProviderThrowScenario([string]$ThrowEntryPoint) {
    $state=[pscustomobject]@{provider_call_count=0;provider_identity='';native_io_performed=$false}
    $original=& $backendModule { (Get-Command -Name Invoke-GatedProductionProviderCall -CommandType Function).ScriptBlock }
    & $backendModule {
        param($Original,$State,$EntryPointToThrow)
        $replacement={
            param([Parameter(Mandatory)][object]$Provider,[Parameter(Mandatory)][string]$EntryPoint,[Parameter(Mandatory)][object]$Arguments)
            $State.provider_call_count++
            $State.provider_identity=[string]$Provider.provider_identity
            $State.native_io_performed=[bool]$Provider.native_io_performed
            $result=& $Original -Provider $Provider -EntryPoint $EntryPoint -Arguments $Arguments
            if([string]::Equals($EntryPoint,$EntryPointToThrow,[StringComparison]::Ordinal)){throw [InvalidOperationException]::new("OFFLINE_RECORDING_PROVIDER_THROW:$EntryPoint")}
            $result
        }.GetNewClosure()
        Set-Item -Path Function:Invoke-GatedProductionProviderCall -Value $replacement
    } $original $state $ThrowEntryPoint
    try{
        $request=New-Request;$cap=New-Cap $request;$thrown=$null
        try{[void](Invoke-Coordinator $request $cap)}catch{$thrown=$_.Exception.Message}
        $callsAfterThrow=$state.provider_call_count;$replay=Invoke-Coordinator $request $cap
        [pscustomobject]@{thrown=$thrown;calls_after_throw=$callsAfterThrow;calls_after_replay=$state.provider_call_count;replay=$replay;provider_identity=$state.provider_identity;native_io_performed=$state.native_io_performed;prohibited_counters=(& $coordinatorModule { New-OneShotCoordinatorZeroCounters })}
    }finally{
        & $backendModule {param($Original) Set-Item -Path Function:Invoke-GatedProductionProviderCall -Value $Original} $original
    }
}
Test-Case 'import and exports expose no coordinator capability or provider' { Assert-OneShot ($coordinatorModule.ExportedFunctions.Count -eq 0) 'coordinator exported a function'; Assert-OneShot ($backendModule.ExportedFunctions.Count -eq 0) 'backend exported a function'; Assert-OneShot ($coordinatorModule.SessionState.PSVariable.GetValue('ProductionAuthorizationCapability',$null) -eq $null) 'production capability variable present' }
Test-Case 'public adapter remains prohibited' { $r=Invoke-ChatpadNonExecutingNativeAdapter -Request (New-Request); Assert-OneShot ($r.result_code -eq 'NATIVE_EXECUTION_PROHIBITED') 'public execution changed'; foreach($c in $r.counters.PSObject.Properties){Assert-OneShot ($c.Value -eq 0) 'public counter changed'} }
Test-Case 'managed helper signature exposes no provider injection reset or replacement surface' {
    $surface=Get-ManagedRegistrySurface
    $expected=@('System.Void Chatpad.OneShotAuthorization.Registry.CreateRecordingAuthorization(System.Object key, System.String fingerprint)','System.Boolean Chatpad.OneShotAuthorization.Registry.TryConsume(System.Object key, System.String fingerprint)')
    Assert-OneShot ((@($surface.methods) -join '|') -eq ($expected -join '|')) 'managed method signature surface changed'
    Assert-OneShot (@($surface.constructors).Count -eq 0) 'managed registry exposed a constructor'
    foreach($signature in @($surface.methods + $surface.constructors)){
        Assert-OneShot ($signature -notmatch 'Register\\(System\\.Object key, System\\.String fingerprint, System\\.Object provider\\)') 'obsolete Register signature present'
        Assert-OneShot ($signature -notmatch 'System\\.Object provider|Replace|Reset|SetProvider|providerCandidate|descriptor') "unsafe managed signature present: $signature"
    }
}
Test-Case 'direct managed arbitrary provider registration attempts cannot bind candidates' {
    $type=[Chatpad.OneShotAuthorization.Registry]
    $obsolete=@($type.GetMethods([Reflection.BindingFlags]'Public,Static')|Where-Object{$_.Name -eq 'Register' -and @($_.GetParameters()).Count -eq 3})
    Assert-OneShot ($obsolete.Count -eq 0) 'obsolete provider-accepting Register method exists'
    $request=New-Request
    $fingerprint=& $coordinatorModule { param($r) Get-OneShotRequestFingerprint -Request $r -Operation 'APPLY' } $request
    $productionDescriptor=& $backendModule { New-GatedProductionNativeProviderDescriptor }
    $fakeProvider=[pscustomobject]@{provider_identity='chatpad-gated-production-native-adapter-recording-shim-v1';calls=[Collections.Generic.List[object]]::new();native_io_performed=$false}
    $wrapper=[pscustomobject]@{Provider=$fakeProvider}
    $deserialized=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($fakeProvider))
    $candidates=@([pscustomobject]@{name='pscustomobject';value=[pscustomobject]@{provider='candidate'}},[pscustomobject]@{name='shape-compatible-fake';value=$fakeProvider},[pscustomobject]@{name='wrapper';value=$wrapper},[pscustomobject]@{name='deserialized';value=$deserialized},[pscustomobject]@{name='string';value='provider'},[pscustomobject]@{name='boolean';value=$true},[pscustomobject]@{name='production-descriptor';value=$productionDescriptor})
    foreach($candidate in $candidates){
        $threeArgumentRejected=$false
        try{[void]$type.InvokeMember('CreateRecordingAuthorization',[Reflection.BindingFlags]'InvokeMethod,Public,Static',$null,$null,@([pscustomobject]@{key=$candidate.name},$fingerprint,$candidate.value))}catch{$threeArgumentRejected=$true}
        Assert-OneShot $threeArgumentRejected "three-argument managed bind accepted $($candidate.name)"
        $directKey=[pscustomobject]@{direct_managed_key=$candidate.name}
        [Chatpad.OneShotAuthorization.Registry]::CreateRecordingAuthorization($directKey,$fingerprint)
        $out=Invoke-Coordinator $request $directKey
        Assert-OneShot ($out.result -eq 'AUTHORIZATION_PROVIDER_BINDING_REJECTED_NO_PROVIDER_CALL') "direct managed key bound provider for $($candidate.name)"
        Assert-OneShot ($out.provider_call_count -eq 0) "direct managed key reached provider for $($candidate.name)"
        foreach($c in $out.counters.PSObject.Properties){Assert-OneShot ($c.Value -eq 0) "direct managed counter changed for $($candidate.name)"}
    }
    Assert-OneShot (-not $productionDescriptor.native_invocation_available) 'production descriptor became invocable'
    Assert-OneShot (-not $productionDescriptor.selected_by_default) 'production descriptor became selected'
}
Test-Case 'ordinary forged wrapped and serialized capabilities fail before provider' { foreach($cap in @($null,'allow',$true,[pscustomobject]@{allow=$true},([Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize([pscustomobject]@{allow=$true}))))) { $p=New-Provider; $r=Invoke-Coordinator (New-Request) $cap $p; Assert-OneShot ($r.provider_call_count -eq 0) 'forged capability reached provider'; Assert-OneShot ($r.result -match 'AUTHORIZATION') 'forged capability was accepted' } }
Test-Case 'caller provider is ignored and cannot substitute bound provider' { $r=New-Request;$cap=New-Cap $r;$wrong=[pscustomobject]@{provider_identity='wrong';calls=[Collections.Generic.List[object]]::new();native_io_performed=$false};$result=Invoke-Coordinator $r $cap $wrong;Assert-OneShot ($result.result -eq 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE') 'bound provider was not used';Assert-OneShot ($wrong.calls.Count -eq 0) 'caller provider was used' }
Test-Case 'exact request enters recording provider once and consumes authorization' { $r=New-Request;$p=New-Provider;$cap=New-Cap $r $p;$result=Invoke-Coordinator $r $cap $p;Assert-OneShot ($result.result -eq 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE') 'recording plan did not complete';Assert-OneShot ($result.provider_call_count -eq 13) 'wrong recording count';Assert-OneShot $result.authorization_consumed 'authorization not consumed';foreach($c in $result.counters.PSObject.Properties){Assert-OneShot ($c.Value -eq 0) 'counter changed'} }
Test-Case 'identity operation and replay tampering makes zero calls' { $variants=@();$x=New-Request;$x.target_chain=@($x.target_chain[1],$x.target_chain[0],$x.target_chain[2]);$variants+=$x;$x=New-Request;$x.shared_container_id='wrong';$variants+=$x;$x=New-Request;$x.task_8f_evidence_sha256='0'*64;$variants+=$x;foreach($v in $variants){$cap=New-Cap (New-Request);$out=Invoke-Coordinator $v $cap;Assert-OneShot ($out.provider_call_count -eq 0) 'invalid request reached provider'};$r=New-Request;$cap=New-Cap $r;$first=Invoke-Coordinator $r $cap;$second=Invoke-Coordinator $r $cap;Assert-OneShot ($second.result -eq 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL') 'replay accepted';Assert-OneShot ($second.provider_call_count -eq 0) 'replay invoked provider' }
Test-Case 'authorization cannot transfer and is consumed' { $r=New-Request;$cap=New-Cap $r;$other=New-Provider;$out=Invoke-Coordinator $r $cap $other;Assert-OneShot ($out.result -eq 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE') 'bound provider did not execute';$again=Invoke-Coordinator $r $cap;Assert-OneShot ($again.result -eq 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL') 'authorization remained reusable' }
Test-Case 'production descriptor is never selected or constructed' { $descriptor=& $backendModule { New-GatedProductionNativeProviderDescriptor };Assert-OneShot (-not $descriptor.native_invocation_available) 'native provider enabled';Assert-OneShot (-not $descriptor.selected_by_default) 'production selected';Assert-OneShot (-not $descriptor.constructed_during_import) 'production constructed' }
Test-Case 'two same-process contenders atomically admit one recording plan' {
    $iterations=16
    $script=@'
param($modulePath,$request,$capability,$ready,$go)
Import-Module $modulePath -Force
$m=Get-Module ChatpadOneShotNativeExecutionCoordinator
& $m { param($r,$c,$ready,$go) Invoke-OneShotNativeExecutionCoordinator -Request $r -AuthorizationCapability $c -RaceReady $ready -RaceGo $go } $request $capability $ready $go
'@
    for($iteration=1;$iteration -le $iterations;$iteration++){
        $request=New-Request;$cap=New-Cap $request;$ready=[Threading.CountdownEvent]::new(2);$go=[Threading.ManualResetEventSlim]::new($false)
        $p1=[PowerShell]::Create();$p2=[PowerShell]::Create()
        foreach($p in @($p1,$p2)){[void]$p.AddScript($script).AddArgument($modulePath).AddArgument($request).AddArgument($cap).AddArgument($ready).AddArgument($go)}
        $a1=$p1.BeginInvoke();$a2=$p2.BeginInvoke();Assert-OneShot ($ready.Wait(5000)) "race contenders did not reach atomic gate at iteration $iteration";$go.Set();$r1=@($p1.EndInvoke($a1))[0];$r2=@($p2.EndInvoke($a2))[0];$p1.Dispose();$p2.Dispose();$ready.Dispose();$go.Dispose()
        $results=@($r1,$r2);Assert-OneShot ((@($results|Where-Object result -eq 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE').Count -eq 1)) "race did not yield one winner at iteration $iteration";Assert-OneShot ((@($results|Where-Object result -eq 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL').Count -eq 1)) "race did not yield one replay rejection at iteration $iteration";Assert-OneShot ((@($results|Measure-Object provider_call_count -Sum).Sum -eq 13)) "race did not yield one recording plan at iteration $iteration"
    }
    Assert-OneShot ($iterations -eq 16) 'race iteration count changed'
}
Test-Case 'SessionState has no effective production authorization' { Assert-OneShot ($coordinatorModule.SessionState.PSVariable.GetValue('ProductionAuthorizationCapability',$null) -eq $null) 'production authorization exposed';Assert-OneShot ($coordinatorModule.SessionState.PSVariable.GetValue('NativeAdapterExecutionCapability',$null) -eq $null) 'native capability exposed' }
Test-Case 'copied authorization wrapper fails' { $r=New-Request;$p=New-Provider;$cap=New-Cap $r $p;$out=Invoke-Coordinator $r ([pscustomobject]@{inner=$cap}) $p;Assert-OneShot ($out.provider_call_count -eq 0) 'wrapper reached provider' }
Test-Case 'deserialized authorization fails' { $r=New-Request;$p=New-Provider;$cap=New-Cap $r $p;$copy=[Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($cap));$out=Invoke-Coordinator $r $copy $p;Assert-OneShot ($out.provider_call_count -eq 0) 'serialized copy reached provider' }
Test-Case 'no provider argument is accepted by factory or coordinator' { $r=New-Request;$cap=New-Cap $r;$out=Invoke-Coordinator $r $cap;Assert-OneShot ($out.result -eq 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE') 'internal provider unavailable' }
Test-Case 'wrong operation fails before calls' { $r=New-Request;$p=New-Provider;$cap=New-Cap $r $p;$out=Invoke-Coordinator $r $cap $p 'RESTORE';Assert-OneShot ($out.provider_call_count -eq 0) 'wrong operation reached provider' }
Test-Case 'missing target fails before calls' { $r=New-Request;$r.target_chain=@($r.target_chain[0]);$p=New-Provider;$cap=New-Cap (New-Request) $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot ($out.provider_call_count -eq 0) 'missing target reached provider' }
Test-Case 'extra target fails before calls' { $r=New-Request;$r.target_chain+= 'HID\VID_045E&PID_028E\EXTRA';$p=New-Provider;$cap=New-Cap (New-Request) $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot ($out.provider_call_count -eq 0) 'extra target reached provider' }
Test-Case 'duplicate target fails before calls' { $r=New-Request;$r.target_chain[2]=$r.target_chain[1];$p=New-Provider;$cap=New-Cap (New-Request) $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot ($out.provider_call_count -eq 0) 'duplicate target reached provider' }
Test-Case 'wrong confirmation fails before calls' { $r=New-Request;$r.operator_confirmation_id='wrong';$p=New-Provider;$cap=New-Cap (New-Request) $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot ($out.provider_call_count -eq 0) 'wrong confirmation reached provider' }
Test-Case 'wrong TASK 8E evidence fails before calls' { $r=New-Request;$r.task_8e_evidence_path='wrong';$p=New-Provider;$cap=New-Cap (New-Request) $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot ($out.provider_call_count -eq 0) 'wrong 8E evidence reached provider' }
Test-Case 'cleanup calls never claim native operation' { $r=New-Request;$p=New-Provider 'SetupDiEnumDriverInfoW';$cap=New-Cap $r $p;$out=Invoke-Coordinator $r $cap $p;Assert-OneShot (-not $out.native_operation_performed) 'native operation claimed';Assert-OneShot $out.production_execution_prohibited 'production prohibition missing' }
Test-Case 'replay is rejected after a thrown internally bound recording-provider exception' { $out=Invoke-RecordingProviderThrowScenario 'SetupDiOpenDeviceInfoW';Assert-OneShot ($out.thrown -match 'OFFLINE_RECORDING_PROVIDER_THROW:SetupDiOpenDeviceInfoW') 'controlled provider exception did not occur';Assert-OneShot ($out.calls_after_throw -gt 0) 'genuine provider plan did not enter';Assert-OneShot ($out.provider_identity -eq 'chatpad-gated-production-native-adapter-recording-shim-v1') 'non-recording provider entered';Assert-OneShot (-not $out.native_io_performed) 'recording provider claimed native I/O';Assert-OneShot ($out.replay.result -eq 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL') 'exception replay was accepted';Assert-OneShot ($out.replay.provider_call_count -eq 0) 'exception replay entered provider';Assert-OneShot ($out.calls_after_replay -eq $out.calls_after_throw) 'exception replay retried recording plan';foreach($c in $out.prohibited_counters.PSObject.Properties){Assert-OneShot ($c.Value -eq 0) 'exception scenario counter changed'} }
Test-Case 'replay is rejected after a recording-provider cleanup failure' { $out=Invoke-RecordingProviderThrowScenario 'SetupDiDestroyDriverInfoList';Assert-OneShot ($out.thrown -match 'OFFLINE_RECORDING_PROVIDER_THROW:SetupDiDestroyDriverInfoList') 'controlled cleanup failure did not occur';Assert-OneShot ($out.calls_after_throw -gt 0) 'cleanup scenario did not enter provider';Assert-OneShot ($out.provider_identity -eq 'chatpad-gated-production-native-adapter-recording-shim-v1') 'cleanup scenario used a non-recording provider';Assert-OneShot (-not $out.native_io_performed) 'cleanup scenario claimed native I/O';Assert-OneShot ($out.replay.result -eq 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL') 'cleanup-failure replay was accepted';Assert-OneShot ($out.replay.provider_call_count -eq 0) 'cleanup-failure replay entered provider';Assert-OneShot ($out.calls_after_replay -eq $out.calls_after_throw) 'cleanup-failure replay retried recording plan';foreach($c in $out.prohibited_counters.PSObject.Properties){Assert-OneShot ($c.Value -eq 0) 'cleanup-failure counter changed'} }
Test-Case 'source excludes implicit selection and native fallbacks' { $text=Get-Content -Raw $modulePath;foreach($pattern in @('Get-CimInstance','Get-WmiObject','Get-PnpDevice','Get-ItemProperty','pnputil','devcon','Start-Process','LoadLibrary','GetProcAddress','\$env:','IsWindows')){Assert-OneShot ($text -notmatch $pattern) "forbidden pattern $pattern"} }
$failed=@($tests|Where-Object result -ne 'PASS');$report=[pscustomobject][ordered]@{schema_version='chatpad-one-shot-native-execution-coordinator-offline-test-v1';result=if($failed.Count){'FAIL'}else{'PASS'};test_count=$tests.Count;assertion_count=$assertionCount;failed_test_count=$failed.Count;runtime=$PSVersionTable.PSEdition;powershell_version=$PSVersionTable.PSVersion.ToString();tests=@($tests);prohibited_operation_counters=(& $coordinatorModule { New-OneShotCoordinatorZeroCounters })};$report;if($failed.Count){exit 1}
