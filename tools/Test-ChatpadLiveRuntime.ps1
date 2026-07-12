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
Check ($inf.Contains('USB\VID_045E&PID_028E') -and $inf.Contains('DriverVer   = 07/12/2026,1.0.1.0')) 'INF targets exact device at version 1.0.1.0'
Check ($device.Contains('WdfDeviceInitAssignWdmIrpPreprocessCallback') -and $device.Contains('IRP_MJ_INTERNAL_DEVICE_CONTROL')) 'internal USB IRP preprocess callback is registered'
Check ($runtime.Contains('IoSkipCurrentIrpStackLocation(irp)') -and $runtime.Contains('IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp)')) 'unowned controller IRPs pass directly to xusb22 lower stack'
Check ($header.Contains('CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)') -and $header.Contains('CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)')) 'only historical Chatpad interface 2 pipe 0 is selected'
Check ($runtime.Contains('WDF_USB_DEVICE_SELECT_CONFIG_PARAMS_INIT_URB(&selectParams, urb)') -and $runtime.Contains('WdfUsbTargetDeviceSelectConfig')) 'parent configuration URB is reused'
Check ($runtime.Contains('attributes.ExecutionLevel = WdfExecutionLevelPassive') -and $runtime.Contains('ChatpadLiveEvtActivationWorkItem') -and $runtime.Contains('ChatpadLiveEvtInputWorkItem')) 'activation and input workers run at passive level'
Check ($runtime.Contains('ChatpadGetActivationSequenceStepCount()') -and $runtime.Contains('ChatpadLiveSendActivationStep(runtime, &step, &bytesTransferred)')) 'authoritative six-step planner drives live transfers'
Check ($header.Contains('CHATPAD_CONTROL_TIMEOUT_MS ((ULONG)1000u)') -and $runtime.Contains('step.DelayAfterMilliseconds')) 'bounded per-transfer timeout and protocol delay are enforced'
Check ($runtime.Contains('ActivationAttemptConsumed') -and $runtime.Contains('InterlockedCompareExchange(&runtime->ActivationAttemptConsumed, 1, 0)') -and $runtime.Contains('InterlockedExchange(&runtime->ActivationAttemptConsumed, 0)')) 'one activation attempt is consumed per D0 generation'
Check ($runtime.Contains('InterlockedExchange(&runtime->StopRequested, 1)') -and $runtime.Contains('WdfWorkItemFlush(runtime->ActivationWorkItem)') -and $runtime.Contains('WdfWorkItemFlush(runtime->InputWorkItem)')) 'D0 exit and removal cancel and flush both workers'
Check ($runtime.Contains('WdfUsbTargetPipeReadSynchronously') -and $runtime.Contains('WDF_REL_TIMEOUT_IN_MS(250)')) 'Chatpad input reads are bounded'
Check ($runtime.Contains('ChatpadParseKeyboardPacket') -and $runtime.Contains('ChatpadMapKeyboardPacketToHid')) 'input uses the portable parser and HID mapper'
Check ($runtime.Contains('VhfReadReportSubmit') -and $project.Contains('VhfKm.lib')) 'keyboard reports use VHF'
Check ($runtime.Contains('ChatpadLiveReleaseKeysIfNeeded') -and $runtime.Contains('ChatpadLiveReleaseAllKeys')) 'invalid data, timeout, and removal prevent stuck keys'
Check (-not $runtime.Contains('WdfIoQueueCreate(')) 'controller traffic is not diverted through a passive KMDF queue'

"Total: $total"
"Passed: $passed"
"Failed: $failed"
if ($failed -ne 0) { exit 1 }
