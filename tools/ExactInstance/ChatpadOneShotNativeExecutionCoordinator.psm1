Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This module is a source-only coordinator.  Its sole test seam accepts the
# existing recording provider; it contains no production-provider constructor,
# native loader, device discovery, or public export.
Import-Module (Join-Path $PSScriptRoot 'ChatpadGatedProductionNativeAdapterBackend.psm1') -Force
if ($null -eq ('Chatpad.OneShotAuthorization.Registry' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadOneShotAuthorizationRegistry.cs') }
$script:OneShotRecordingProviderMapKey = 'Chatpad.OneShotAuthorization.RecordingProviders.v1'
$existingProviderMap = [AppDomain]::CurrentDomain.GetData($script:OneShotRecordingProviderMapKey)
if ($null -eq $existingProviderMap) {
    $existingProviderMap = [System.Runtime.CompilerServices.ConditionalWeakTable[object, object]]::new()
    [AppDomain]::CurrentDomain.SetData($script:OneShotRecordingProviderMapKey, $existingProviderMap)
}
$script:OneShotRecordingProviders = $existingProviderMap

function Get-OneShotValue {
    param([AllowNull()][object]$Object, [Parameter(Mandatory)][string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    Write-Output -NoEnumerate $property.Value
}

function Get-OneShotCoordinatorConstants {
    [pscustomobject][ordered]@{
        operation = 'APPLY'
        contract_evidence_path = 'docs/evidence/exact-instance-binding-non-mutating-implementation-contract.json'
        contract_evidence_sha256 = '1AE0132CE7CB2162F2D0D4930891A881586968C5523E0DAF8C18CF87EF1DD080'
        task_8e_evidence_path = 'docs/evidence/native-adapter-nonexecuting-implementation-task-8e-1.json'
        task_8e_evidence_sha256 = '493C80C445B9D3903D70509AA704177396172B139CCDD037195D4FA84AA9FB6F'
        task_8f_evidence_path = 'docs/evidence/native-adapter-production-backend-source-task-8f-1.json'
        task_8f_evidence_sha256 = '93B0D93E63FA43A9D5C7EE647BD5E261085CD3A4F47F5CD4FD4D1DFA01800042'
        shared_container_id = '{828F4587-006F-5AD1-B169-6AF57905DFDE}'
        operator_confirmation_id = 'operator-confirmation-c445630fbb303c7c'
        target_chain = @('USB\VID_045E&PID_028E\1C21F10','USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00','HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000')
        recording_provider_identity = 'chatpad-gated-production-native-adapter-recording-shim-v1'
    }
}

function Test-OneShotExactArray {
    param([AllowNull()][object]$Actual, [Parameter(Mandatory)][string[]]$Expected)
    if ($null -eq $Actual -or $Actual -is [string]) { return $false }
    $values = @($Actual)
    if ($values.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($values[$index] -isnot [string] -or -not [string]::Equals($values[$index], $Expected[$index], [StringComparison]::Ordinal)) { return $false }
    }
    return $true
}

function Get-OneShotRequestFingerprint {
    param([Parameter(Mandatory)][object]$Request, [Parameter(Mandatory)][string]$Operation)
    @($Operation,
      [string](Get-OneShotValue $Request 'contract_evidence_path' ''),[string](Get-OneShotValue $Request 'contract_evidence_sha256' ''),
      [string](Get-OneShotValue $Request 'task_8e_evidence_path' ''),[string](Get-OneShotValue $Request 'task_8e_evidence_sha256' ''),
      [string](Get-OneShotValue $Request 'task_8f_evidence_path' ''),[string](Get-OneShotValue $Request 'task_8f_evidence_sha256' ''),
      (@(Get-OneShotValue $Request 'target_chain' $null) -join '|'),[string](Get-OneShotValue $Request 'shared_container_id' ''),
      [string](Get-OneShotValue $Request 'operator_confirmation_id' '')) -join "`n"
}

function Test-OneShotExecutionRequest {
    param([AllowNull()][object]$Request, [Parameter(Mandatory)][string]$Operation)
    $c = Get-OneShotCoordinatorConstants
    if (-not [string]::Equals($Operation, $c.operation, [StringComparison]::Ordinal)) { return 'OPERATION_REJECTED' }
    $pairs = @(
        @('contract_evidence_path',$c.contract_evidence_path),@('contract_evidence_sha256',$c.contract_evidence_sha256),
        @('task_8e_evidence_path',$c.task_8e_evidence_path),@('task_8e_evidence_sha256',$c.task_8e_evidence_sha256),
        @('task_8f_evidence_path',$c.task_8f_evidence_path),@('task_8f_evidence_sha256',$c.task_8f_evidence_sha256),
        @('shared_container_id',$c.shared_container_id),@('operator_confirmation_id',$c.operator_confirmation_id))
    foreach ($pair in $pairs) { if (-not [string]::Equals([string](Get-OneShotValue $Request $pair[0] ''), $pair[1], [StringComparison]::Ordinal)) { return 'REQUEST_IDENTITY_REJECTED' } }
    if (-not (Test-OneShotExactArray -Actual (Get-OneShotValue $Request 'target_chain' $null) -Expected $c.target_chain)) { return 'EXACT_TARGET_REJECTED' }
    return 'REQUEST_VALIDATED'
}

function New-OneShotCoordinatorZeroCounters {
    & (Get-Module ChatpadGatedProductionNativeAdapterBackend) { New-GatedProductionBackendZeroCounters }
}

function New-TestOnlyRecordingProviderAuthorization {
    param([Parameter(Mandatory)][object]$Request, [string]$Operation = 'APPLY')
    if ((Test-OneShotExecutionRequest -Request $Request -Operation $Operation) -ne 'REQUEST_VALIDATED') { return $null }
    $backend = Get-Module ChatpadGatedProductionNativeAdapterBackend
    $provider = & $backend { New-GatedProductionRecordingProvider }
    $capability = [pscustomobject]@{ test_recording_provider_only = $true }
    [Chatpad.OneShotAuthorization.Registry]::CreateRecordingAuthorization($capability,(Get-OneShotRequestFingerprint -Request $Request -Operation $Operation))
    $script:OneShotRecordingProviders.Add($capability, $provider)
    return [pscustomobject]@{ authorization = $capability; observation = [pscustomobject]@{ provider_kind = 'OFFLINE_RECORDING_PROVIDER_ONLY' } }
}

function Invoke-OneShotNativeExecutionCoordinator {
    param([AllowNull()][object]$Request, [AllowNull()][object]$AuthorizationCapability, [string]$Operation = 'APPLY', [AllowNull()][object]$RaceReady = $null, [AllowNull()][object]$RaceGo = $null)
    $counters = New-OneShotCoordinatorZeroCounters
    $requestState = Test-OneShotExecutionRequest -Request $Request -Operation $Operation
    if ($requestState -ne 'REQUEST_VALIDATED') { return [pscustomobject][ordered]@{ result = 'REQUEST_VALIDATION_REJECTED_NO_PROVIDER_CALL'; result_code = $requestState; provider_call_count = 0; authorization_consumed = $false; counters = $counters; native_operation_performed = $false } }
    if ($null -ne $RaceReady -and $null -ne $RaceGo) { [void]$RaceReady.Signal(); $RaceGo.Wait() }
    if ($null -eq $AuthorizationCapability -or -not [Chatpad.OneShotAuthorization.Registry]::TryConsume($AuthorizationCapability,(Get-OneShotRequestFingerprint -Request $Request -Operation $Operation))) { return [pscustomobject][ordered]@{ result = 'AUTHORIZATION_REPLAY_REJECTED_NO_PROVIDER_CALL'; result_code = 'AUTHORIZATION_UNAVAILABLE_REPLAYED_OR_MISMATCHED'; provider_call_count = 0; authorization_consumed = $true; counters = $counters; native_operation_performed = $false } }
    $provider = $null
    if (-not $script:OneShotRecordingProviders.TryGetValue($AuthorizationCapability, [ref]$provider)) { return [pscustomobject][ordered]@{ result = 'AUTHORIZATION_PROVIDER_BINDING_REJECTED_NO_PROVIDER_CALL'; result_code = 'AUTHORIZATION_PROVIDER_BINDING_UNAVAILABLE'; provider_call_count = 0; authorization_consumed = $true; counters = $counters; native_operation_performed = $false } }
    $backend = Get-Module ChatpadGatedProductionNativeAdapterBackend
    $plan = & $backend { param($r, $p) Invoke-GatedProductionBackendRecordingPlan -Request $r -Provider $p } $Request $Provider
    [pscustomobject][ordered]@{
        result = if ($plan.result -eq 'RECORDING_PLAN_COMPLETED_NOT_EXECUTED') { 'RECORDING_PROVIDER_PLAN_COMPLETED_NOT_NATIVE' } else { 'RECORDING_PROVIDER_PLAN_STOPPED_NOT_NATIVE' }
        result_code = $plan.result_code; provider_call_count = $plan.provider_call_count; authorization_consumed = $true
        cleanup_attempted = $plan.cleanup_attempted; cleanup_order = @($plan.cleanup_order); provider_plan_result = $plan.result
        counters = $counters; native_operation_performed = $false; production_execution_prohibited = $true
    }
}

Export-ModuleMember -Function @()
