Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadExactInstance.Contracts.psm1') -Force

function New-ChatpadFakeDriverIdentity {
    param(
        [Parameter(Mandatory)][string]$NodeId,
        [Parameter(Mandatory)][string]$PublishedInf,
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$Version,
        [string]$Service='xusb22',
        [string]$DriverKey='{FAKE}\0001',
        [string]$OriginalInf='xusb22.inf',
        [string]$Description='Synthetic controller driver',
        [string]$MatchingId='USB\VID_045E&PID_028E',
        [string]$CanonicalInfPath='C:\Synthetic\DriverStore\driver.inf',
        [string]$InfSha256=('1'*64),
        [string]$CatalogSha256=('2'*64),
        [string]$Architecture='amd64',
        [string]$ModelId='synthetic-model',
        [string]$InstallSection='Synthetic_Install',
        [string]$DriverDate='2026-07-01',
        [long]$PackageByteSize=4096,
        [string]$Signer='Synthetic Signer',
        [string]$CatalogIdentity='synthetic.cat',
        [int]$Rank=16711680
    )
    [pscustomobject][ordered]@{
        canonical_inf_path=$CanonicalInfPath
        package_byte_size=$PackageByteSize
        published_inf=$PublishedInf
        original_inf=$OriginalInf
        provider=$Provider
        description=$Description
        driver_version=$Version
        driver_date=$DriverDate
        signer=$Signer
        catalog_identity=$CatalogIdentity
        service=$Service
        driver_key=$DriverKey
        matching_id=$MatchingId
        driver_rank=$Rank
        driver_node_id=$NodeId
        inf_sha256=$InfSha256
        catalog_sha256=$CatalogSha256
        architecture=$Architecture
        model_id=$ModelId
        install_section=$InstallSection
    }
}

function New-ChatpadFakeDevice {
    param(
        [Parameter(Mandatory)][string]$InstanceId,
        [Parameter(Mandatory)][object]$DriverIdentity,
        [string[]]$HardwareIds=@('USB\VID_045E&PID_028E'),
        [string[]]$CompatibleIds=@('USB\Class_FF'),
        [string]$ContainerId='{11111111-1111-1111-1111-111111111111}',
        [string]$ParentInstanceId='USB\ROOT_HUB30\FAKE',
        [string[]]$LocationPaths=@('PCIROOT(0)#PCI(1400)#USBROOT(0)#USB(1)'),
        [string]$ClassGuid='{4D36E96F-E325-11CE-BFC1-08002BE10318}',
        [string]$DeviceStatus='started',
        [int]$ProblemCode=0
    )
    [pscustomobject][ordered]@{
        canonical_instance_id=ConvertTo-ChatpadCanonicalInstanceId $InstanceId
        class_guid=$ClassGuid
        container_id=$ContainerId
        parent_instance_id=$ParentInstanceId
        location_paths=@($LocationPaths)
        hardware_ids=@($HardwareIds)
        compatible_ids=@($CompatibleIds)
        device_status=$DeviceStatus
        problem_code=$ProblemCode
        restart_required=$false
        reboot_required=$false
        driver_identity=Copy-ChatpadExactObject $DriverIdentity
        unavailable_properties=@()
    }
}

function New-ChatpadFakeExactInstanceAdapter {
    param(
        [Parameter(Mandatory)][object[]]$Devices,
        [Parameter(Mandatory)][object[]]$Packages,
        [hashtable]$Behavior=@{}
    )
    $deviceList=[Collections.Generic.List[object]]::new()
    foreach($device in @($Devices)){$deviceList.Add((Copy-ChatpadExactObject $device))}
    $packageList=[Collections.Generic.List[object]]::new()
    foreach($package in @($Packages)){$packageList.Add((Copy-ChatpadExactObject $package))}
    [pscustomobject]@{
        adapter_identity='chatpad-fake-exact-instance-adapter-v1'
        adapter_mode='offline-fake'
        synthetic=$true
        devices=$deviceList
        packages=$packageList
        call_log=[Collections.Generic.List[object]]::new()
        transactions=@{}
        behavior=$Behavior
        counters=[ordered]@{
            plan_operations=0;query_operations=0;package_verification_operations=0
            synthetic_exact_binding_attempts=0;synthetic_exact_successful_bindings=0
            synthetic_exact_restoration_attempts=0;synthetic_exact_successful_restorations=0
            synthetic_exact_restart_attempts=0;broad_installation_attempts=0;broad_rollback_attempts=0
            blocked_operations=0;synthetic_operations=0;live_operations=0
            controlled_failures=0;uncontrolled_exceptions=0
            live_exact_binding_operations=0;live_exact_restoration_operations=0
            live_restart_operations=0;windows_mutations=0
        }
    }
}

function Add-ChatpadFakeAdapterCall {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$Operation,
        [string]$InstanceId='',
        [object]$Arguments=$null,
        [string]$Outcome='called'
    )
    $Adapter.call_log.Add([pscustomobject][ordered]@{
        sequence=$Adapter.call_log.Count+1
        operation=$Operation
        canonical_instance_id=$InstanceId
        arguments=if($null-eq$Arguments){[pscustomobject]@{}}else{Copy-ChatpadExactObject $Arguments}
        outcome=$Outcome
        synthetic=$true
    })
}

function Find-ChatpadFakeExactDevice {
    param([Parameter(Mandatory)][object]$Adapter,[Parameter(Mandatory)][string]$InstanceId)
    $canonical=ConvertTo-ChatpadCanonicalInstanceId $InstanceId
    $deviceMatches=@($Adapter.devices|Where-Object{[string]$_.canonical_instance_id-ceq$canonical})
    if($deviceMatches.Count-eq0){return [pscustomobject]@{result='BLOCKED';result_code='TARGET_INSTANCE_NOT_FOUND';device=$null}}
    if($deviceMatches.Count-ne1){return [pscustomobject]@{result='BLOCKED';result_code='TARGET_INSTANCE_AMBIGUOUS';device=$null}}
    [pscustomobject]@{result='PASS';result_code='TARGET_INSTANCE_OPENED';device=$deviceMatches[0]}
}

function Invoke-ChatpadFakeOpenExactDevice {
    param([Parameter(Mandatory)][object]$Adapter,[Parameter(Mandatory)][string]$InstanceId)
    $canonical=ConvertTo-ChatpadCanonicalInstanceId $InstanceId
    $Adapter.counters.query_operations++
    $Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'open-exact-device' $canonical ([pscustomobject]@{selector_type='complete-instance-id'})
    $result=Find-ChatpadFakeExactDevice $Adapter $canonical
    if($result.result-ne'PASS'){$Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++}
    $result
}

function Test-ChatpadFakeDriverIdentityMatch {
    param([Parameter(Mandatory)][object]$Left,[Parameter(Mandatory)][object]$Right)
    foreach($name in @('driver_node_id','published_inf','provider','driver_version','driver_date','service','driver_key','inf_sha256','catalog_sha256','architecture','model_id','install_section','matching_id')){
        if([string](Get-ChatpadExactProperty $Left $name '')-cne[string](Get-ChatpadExactProperty $Right $name '')){return $false}
    }
    $true
}

function Invoke-ChatpadFakeResolvePackage {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][object]$DriverIdentity,
        [ValidateSet('target','restoration')][string]$Purpose='target'
    )
    $Adapter.counters.package_verification_operations++
    $Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'resolve-exact-driver-node' '' ([pscustomobject]@{purpose=$Purpose;driver_node_id=[string](Get-ChatpadExactProperty $DriverIdentity 'driver_node_id' '')})
    $packageMatches=@($Adapter.packages|Where-Object{Test-ChatpadFakeDriverIdentityMatch $_ $DriverIdentity})
    if($packageMatches.Count-eq0){
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return [pscustomobject]@{result='BLOCKED';result_code=if($Purpose-eq'restoration'){'RESTORE_DRIVER_NOT_AVAILABLE'}else{'TARGET_DRIVER_NOT_AVAILABLE'};package=$null}
    }
    if($packageMatches.Count-ne1){
        $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++
        return [pscustomobject]@{result='BLOCKED';result_code=if($Purpose-eq'restoration'){'RESTORE_DRIVER_IDENTITY_AMBIGUOUS'}else{'TARGET_DRIVER_IDENTITY_AMBIGUOUS'};package=$null}
    }
    [pscustomobject]@{result='PASS';result_code='EXACT_DRIVER_NODE_RESOLVED';package=$packageMatches[0]}
}

function Invoke-ChatpadFakeBindExactDevice {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$CanonicalInstanceId,
        [Parameter(Mandatory)][object]$DriverIdentity
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId $CanonicalInstanceId
    $Adapter.counters.synthetic_exact_binding_attempts++
    $Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'bind-exact-device' $canonical ([pscustomobject]@{driver_node_id=[string](Get-ChatpadExactProperty $DriverIdentity 'driver_node_id' '')})
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'bind_throw_before_mutation' $false)){
        throw [InvalidOperationException]::new('FAKE_ADAPTER_BIND_EXCEPTION_BEFORE_MUTATION')
    }
    $opened=Find-ChatpadFakeExactDevice $Adapter $canonical
    if($opened.result-ne'PASS'){$Adapter.counters.controlled_failures++;return [pscustomobject]@{result='FAIL';result_code=$opened.result_code;mutation_possible=$false}}
    $opened.device.driver_identity=Copy-ChatpadExactObject $DriverIdentity
    $opened.device.restart_required=[bool](Get-ChatpadExactProperty $Adapter.behavior 'restart_required' $false)
    $opened.device.reboot_required=[bool](Get-ChatpadExactProperty $Adapter.behavior 'reboot_required' $false)
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'bind_postcondition_mismatch' $false)){
        $opened.device.driver_identity.driver_node_id='unexpected-node'
    }
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'bind_throw_after_mutation' $false)){
        throw [InvalidOperationException]::new('FAKE_ADAPTER_BIND_EXCEPTION_AFTER_MUTATION')
    }
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'bind_api_failure_after_mutation' $false)){
        return [pscustomobject]@{result='FAIL';result_code='BIND_API_FAILED_AFTER_MUTATION';mutation_possible=$true;win32_error=31}
    }
    $Adapter.counters.synthetic_exact_successful_bindings++
    [pscustomobject]@{result='PASS';result_code='BIND_API_SUCCEEDED';mutation_possible=$true;win32_error=0;restart_required=$opened.device.restart_required;reboot_required=$opened.device.reboot_required}
}

function Invoke-ChatpadFakeRestoreExactDevice {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [Parameter(Mandatory)][string]$CanonicalInstanceId,
        [Parameter(Mandatory)][object]$DriverIdentity
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId $CanonicalInstanceId
    $Adapter.counters.synthetic_exact_restoration_attempts++
    $Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'restore-exact-device' $canonical ([pscustomobject]@{driver_node_id=[string](Get-ChatpadExactProperty $DriverIdentity 'driver_node_id' '')})
    $opened=Find-ChatpadFakeExactDevice $Adapter $canonical
    if($opened.result-ne'PASS'){$Adapter.counters.controlled_failures++;return [pscustomobject]@{result='FAIL';result_code=$opened.result_code;mutation_possible=$false}}
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'restore_failure' $false)){
        return [pscustomobject]@{result='FAIL';result_code='RESTORE_API_FAILED';mutation_possible=$true;win32_error=31}
    }
    $opened.device.driver_identity=Copy-ChatpadExactObject $DriverIdentity
    $opened.device.restart_required=$false;$opened.device.reboot_required=$false
    if([bool](Get-ChatpadExactProperty $Adapter.behavior 'restore_postcondition_mismatch' $false)){
        $opened.device.driver_identity.driver_node_id='wrong-restored-node'
    }
    $Adapter.counters.synthetic_exact_successful_restorations++
    [pscustomobject]@{result='PASS';result_code='RESTORE_API_SUCCEEDED';mutation_possible=$true;win32_error=0}
}

function Invoke-ChatpadFakeRestartExactDevice {
    param([Parameter(Mandatory)][object]$Adapter,[Parameter(Mandatory)][string]$CanonicalInstanceId)
    $canonical=ConvertTo-ChatpadCanonicalInstanceId $CanonicalInstanceId
    $Adapter.counters.synthetic_exact_restart_attempts++
    $Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'restart-exact-device' $canonical
    [pscustomobject]@{result='PASS';result_code='SYNTHETIC_RESTART_SUCCEEDED'}
}

function Invoke-ChatpadFakeBroadOperation {
    param(
        [Parameter(Mandatory)][object]$Adapter,
        [ValidateSet('install-all-matching','remove-package-globally')][string]$Operation
    )
    if($Operation-eq'install-all-matching'){$Adapter.counters.broad_installation_attempts++}else{$Adapter.counters.broad_rollback_attempts++}
    $Adapter.counters.blocked_operations++;$Adapter.counters.controlled_failures++;$Adapter.counters.synthetic_operations++
    Add-ChatpadFakeAdapterCall $Adapter 'broad-operation-rejected' '' ([pscustomobject]@{requested_operation=$Operation}) 'rejected'
    [pscustomobject]@{result='BLOCKED';result_code='BROAD_OPERATION_PROHIBITED'}
}

function Get-ChatpadFakeDeviceBytes {
    param([Parameter(Mandatory)][object]$Device)
    [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-ChatpadExactCanonicalJson $Device))
}

Export-ModuleMember -Function *-Chatpad*
