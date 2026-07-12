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
Check ($inf.Contains('USB\VID_045E&PID_028E') -and $inf.Contains('DriverVer   = 07/12/2026,1.0.3.0')) 'INF targets exact device at version 1.0.3.0'
Check ($inf.Contains('HKR,,"LowerFilters",0x00010008,"ChatpadFilter","vhf"') -and -not $inf.Contains('AddFilter = ChatpadFilter')) 'INF orders ChatpadFilter above required VHF while preserving existing lower filters'
Check ($device.Contains('WdfDeviceInitAssignWdmIrpPreprocessCallback') -and $device.Contains('IRP_MJ_INTERNAL_DEVICE_CONTROL')) 'internal USB IRP preprocess callback is registered'
Check ($runtime.Contains('IoSkipCurrentIrpStackLocation(irp)') -and $runtime.Contains('IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp)')) 'unowned controller IRPs pass directly to xusb22 lower stack'
Check ($header.Contains('CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)') -and $header.Contains('CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)')) 'only historical Chatpad interface 2 pipe 0 is selected'
Check ($runtime.Contains('IoSetCompletionRoutine') -and $runtime.Contains('URB_FUNCTION_SELECT_CONFIGURATION ||') -and $runtime.Contains('URB_FUNCTION_SELECT_INTERFACE') -and $runtime.Contains('ChatpadLiveCaptureConfiguredPipe')) 'parent configuration and interface URBs are forwarded unchanged and observed only after completion'
Check ($runtime.Contains('if (irp->PendingReturned)') -and $runtime.Contains('IoMarkIrpPending(irp)')) 'configuration observation preserves lower-stack pending semantics'
Check (-not $runtime.Contains('WdfUsbTargetDeviceSelectConfig') -and -not $runtime.Contains('WdfUsbTargetDeviceCreate')) 'filter never selects or claims the xusb22-owned USB configuration'
Check ($runtime.Contains('WdfIoTargetSendInternalIoctlOthersSynchronously') -and $runtime.Contains('IOCTL_INTERNAL_USB_SUBMIT_URB')) 'owned URBs are submitted to the next-lower target'
Check ($runtime.Contains('UsbBuildVendorRequest') -and $runtime.Contains('URB_FUNCTION_VENDOR_DEVICE')) 'activation uses raw vendor-device URBs'
Check ($runtime.Contains('attributes.ExecutionLevel = WdfExecutionLevelPassive') -and $runtime.Contains('ChatpadLiveEvtActivationWorkItem') -and $runtime.Contains('ChatpadLiveEvtInputWorkItem')) 'activation and input workers run at passive level'
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
Check ($runtime.Contains('vhfConfig.VersionNumber = 0x0103')) 'VHF child version matches package version 1.0.3.0'

"Total: $total"
"Passed: $passed"
"Failed: $failed"
if ($failed -ne 0) { exit 1 }
