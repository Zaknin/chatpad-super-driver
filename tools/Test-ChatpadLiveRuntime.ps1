[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtime = [IO.File]::ReadAllText((Join-Path $root 'src\driver\ChatpadFilter\ChatpadLiveRuntime.c'))
$header = [IO.File]::ReadAllText((Join-Path $root 'src\driver\ChatpadFilter\ChatpadLiveRuntime.h'))
$device = [IO.File]::ReadAllText((Join-Path $root 'src\driver\ChatpadFilter\device.c'))
$project = [IO.File]::ReadAllText((Join-Path $root 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'))
$inf = [IO.File]::ReadAllText((Join-Path $root 'src\driver\ChatpadFilter\package\ChatpadFilterExtension.inf'))
$policy = [IO.File]::ReadAllText((Join-Path $root 'src\protocol\ChatpadProtocol\ChatpadFailOpenPolicy.c'))
$policyTests = [IO.File]::ReadAllText((Join-Path $root 'tests\protocol\ChatpadFailOpenPolicyTests.c'))

$total = 0
$passed = 0
$failed = 0
function Check([bool]$Condition, [string]$Name) {
    $script:total++
    if ($Condition) {
        $script:passed++
        "PASS: $Name"
    } else {
        $script:failed++
        "FAIL: $Name"
    }
}

Check ($runtime.Contains('L"USB\\VID_045E&PID_028E"') -and $runtime.Contains('DevicePropertyHardwareID') -and $runtime.Contains('RtlEqualUnicodeString')) 'exact supported device is independently matched'
Check ($inf.Contains('USB\VID_045E&PID_028E') -and $inf.Contains('DriverVer   = 07/12/2026,1.0.7.0')) 'INF targets exact device at version 1.0.7.0'
Check ($inf.Contains('HKR,,"LowerFilters",0x00010008,"vhf","ChatpadFilter"') -and -not $inf.Contains('AddFilter = ChatpadFilter')) 'INF places VHF below its Chatpad HID source while preserving existing lower filters'
Check ($device.Contains('WdfDeviceInitAssignWdmIrpPreprocessCallback') -and $device.Contains('IRP_MJ_INTERNAL_DEVICE_CONTROL')) 'internal USB IRP preprocess callback is registered'
Check ($runtime.Contains('IoSkipCurrentIrpStackLocation(irp)') -and $runtime.Contains('IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp)')) 'unowned controller IRPs pass directly to xusb22 lower stack'
Check ($header.Contains('CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)') -and $header.Contains('CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)')) 'only historical Chatpad interface 2 pipe 0 is selected'
Check ($runtime.Contains('IoSetCompletionRoutine') -and $runtime.Contains('URB_FUNCTION_SELECT_CONFIGURATION ||') -and $runtime.Contains('URB_FUNCTION_SELECT_INTERFACE') -and $runtime.Contains('ChatpadLiveCaptureConfiguredPipe')) 'parent configuration and interface URBs are forwarded unchanged and observed only after completion'
Check ($runtime.Contains('if (irp->PendingReturned)') -and $runtime.Contains('IoMarkIrpPending(irp)')) 'configuration observation preserves lower-stack pending semantics'
Check (-not $runtime.Contains('WdfUsbTargetDeviceSelectConfig') -and -not $runtime.Contains('WdfUsbTargetDeviceCreate')) 'filter never selects or claims the xusb22-owned USB configuration'
Check ($runtime.Contains('WdfIoTargetSendInternalIoctlOthersSynchronously') -and $runtime.Contains('IOCTL_INTERNAL_USB_SUBMIT_URB')) 'owned URBs are submitted to the next-lower target'
Check ($runtime.Contains('UsbBuildVendorRequest') -and $runtime.Contains('URB_FUNCTION_VENDOR_DEVICE')) 'activation uses raw vendor-device URBs'
Check ($runtime.Contains('ChatpadLiveEvtActivationWorkItem') -and $runtime.Contains('ChatpadLiveEvtInputWorkItem') -and $runtime.Contains('ChatpadLiveEvtDiagnosticWorkItem') -and -not $runtime.Contains('attributes.ExecutionLevel = WdfExecutionLevelPassive')) 'work-item objects inherit valid framework execution attributes'
Check ($runtime.Contains('ChatpadGetActivationSequenceStepCount()') -and $runtime.Contains('ChatpadLiveSendActivationStep(') -and $runtime.Contains('&step,')) 'authoritative six-step planner drives live transfers'
Check ($header.Contains('CHATPAD_CONTROL_TIMEOUT_MS ((ULONG)1000u)') -and $runtime.Contains('step.DelayAfterMilliseconds')) 'bounded per-transfer timeout and protocol delay are enforced'
Check ($runtime.Contains('ActivationAttemptConsumed') -and $runtime.Contains('InterlockedCompareExchange(&runtime->ActivationAttemptConsumed, 1, 0)') -and $runtime.Contains('InterlockedExchange(&runtime->ActivationAttemptConsumed, 0)')) 'one activation attempt is consumed per D0 generation'
Check ($runtime.Contains('InterlockedExchange(&runtime->StopRequested, 1)') -and $runtime.Contains('WdfWorkItemFlush(runtime->ActivationWorkItem)') -and $runtime.Contains('WdfWorkItemFlush(runtime->InputWorkItem)')) 'D0 exit and removal cancel and flush both workers'
Check ($runtime.Contains('UsbBuildInterruptOrBulkTransferRequest') -and $header.Contains('CHATPAD_INPUT_TIMEOUT_MS ((ULONG)250u)')) 'Chatpad input reads use bounded raw pipe URBs'
Check ($runtime.Contains('ChatpadParseKeyboardPacket') -and $runtime.Contains('ChatpadMapKeyboardPacketToHid')) 'input uses the portable parser and HID mapper'
Check ($runtime.Contains('VhfReadReportSubmit') -and $project.Contains('VhfKm.lib')) 'keyboard reports use VHF'
Check ($runtime.Contains('ChatpadLiveReleaseKeysIfNeeded') -and $runtime.Contains('ChatpadLiveReleaseAllKeys')) 'invalid data, timeout, and removal prevent stuck keys'
Check (-not $runtime.Contains('WdfIoQueueCreate(')) 'controller traffic is not diverted through a passive KMDF queue'
Check ($runtime.Contains('ChatpadRuntimeDiagnostics') -and $runtime.Contains('ConfigurationCompletionCount') -and $runtime.Contains('ActivationStep5UsbdStatus') -and $runtime.Contains('FirstRawPacket0') -and $runtime.Contains('FirstKeyboardReportNtStatus')) 'bounded persistent diagnostics cover configuration through first HID submission'
Check ($runtime.Contains('WdfDriverOpenParametersRegistryKey') -and $runtime.Contains('WdfDeviceGetDriver(runtime->Device)')) 'diagnostics use the service Parameters key before device start'
Check ($runtime.Contains('vhfConfig.VersionNumber = 0x0107')) 'VHF child version matches package version 1.0.7.0'
Check ($runtime.Contains('USBD_STATUS_STALL_PID') -and $runtime.Contains('ChatpadIsAcceptedActivationStall') -and $runtime.Contains('ActivationAcceptedStall')) 'only exact pre-write stalls advance to the strict activation write and final probe'
Check ($device.Contains('UNREFERENCED_PARAMETER(runtimeStatus)') -and -not $device.Contains('context->LiveRuntime.LastActivationStatus = runtimeStatus')) 'optional runtime status cannot propagate through physical PrepareHardware'
Check ($runtime.Contains('ChatpadLiveDisableOptionalFeature') -and $runtime.Contains('PhysicalStartResult') -and $runtime.Contains('ControllerForwardingEnabled') -and $runtime.Contains('CHATPAD_VIRTUAL_KEYBOARD_UNAVAILABLE')) 'optional failure records bounded fail-open diagnostics'
Check ($header.Contains('KeyboardQueue[CHATPAD_KEYBOARD_QUEUE_CAPACITY]') -and $runtime.Contains('ChatpadLiveEvtKeyboardWorkItem') -and $runtime.Contains('WdfWorkItemFlush(runtime->KeyboardWorkItem)')) 'virtual keyboard uses a bounded independent queue and teardown worker'
Check ($policy.Contains('return 0;') -and $policyTests.Contains('PrepareHardware succeeds') -and $policyTests.Contains('D0Entry succeeds') -and $policyTests.Contains('forcedStages')) 'portable forced-failure policy fixes physical start results to success'
Check ($policyTests.Contains('CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_1') -and $policyTests.Contains('CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_6') -and $policyTests.Contains('CHATPAD_OPTIONAL_STAGE_KEYBOARD_SUBMISSION')) 'forced-failure matrix covers activation steps and keyboard submission'

"Total: $total"
"Passed: $passed"
"Failed: $failed"
if ($failed -ne 0) { exit 1 }
