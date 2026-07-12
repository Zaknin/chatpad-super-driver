#include "driver.h"
#include "ChatpadActivationSequence.h"
#include "ChatpadKeyboardParser.h"
#include "ChatpadLiveTransferPolicy.h"
#include "ChatpadLiveRuntime.h"

#include <usbioctl.h>
#include <usbdlib.h>

static const UCHAR ChatpadKeyboardReportDescriptor[] = {
    0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x05, 0x07,
    0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x08, 0x81, 0x02, 0x95, 0x01,
    0x75, 0x08, 0x81, 0x01, 0x95, 0x06, 0x75, 0x08,
    0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00,
    0x29, 0x65, 0x81, 0x00, 0xC0
};

static const WCHAR ChatpadSupportedHardwareId[] = L"USB\\VID_045E&PID_028E";

static const WCHAR *const ChatpadActivationNtStatusNames[] = {
    L"ActivationStep0NtStatus", L"ActivationStep1NtStatus",
    L"ActivationStep2NtStatus", L"ActivationStep3NtStatus",
    L"ActivationStep4NtStatus", L"ActivationStep5NtStatus"
};
static const WCHAR *const ChatpadActivationUsbdStatusNames[] = {
    L"ActivationStep0UsbdStatus", L"ActivationStep1UsbdStatus",
    L"ActivationStep2UsbdStatus", L"ActivationStep3UsbdStatus",
    L"ActivationStep4UsbdStatus", L"ActivationStep5UsbdStatus"
};
static const WCHAR *const ChatpadActivationBytesNames[] = {
    L"ActivationStep0Bytes", L"ActivationStep1Bytes",
    L"ActivationStep2Bytes", L"ActivationStep3Bytes",
    L"ActivationStep4Bytes", L"ActivationStep5Bytes"
};
static const WCHAR *const ChatpadActivationExpectedStallNames[] = {
    L"ActivationStep0ExpectedStall", L"ActivationStep1ExpectedStall",
    L"ActivationStep2ExpectedStall", L"ActivationStep3ExpectedStall",
    L"ActivationStep4ExpectedStall", L"ActivationStep5ExpectedStall"
};
static const WCHAR *const ChatpadActivationSetup0Names[] = {
    L"ActivationStep0Setup0", L"ActivationStep1Setup0",
    L"ActivationStep2Setup0", L"ActivationStep3Setup0",
    L"ActivationStep4Setup0", L"ActivationStep5Setup0"
};
static const WCHAR *const ChatpadActivationSetup1Names[] = {
    L"ActivationStep0Setup1", L"ActivationStep1Setup1",
    L"ActivationStep2Setup1", L"ActivationStep3Setup1",
    L"ActivationStep4Setup1", L"ActivationStep5Setup1"
};

static void ChatpadLiveReleaseAllKeys(PCHATPAD_LIVE_RUNTIME runtime);

static void ChatpadLiveTrace(
    _In_z_ const char *eventName,
    NTSTATUS status,
    ULONG data0,
    ULONG data1)
{
    UNREFERENCED_PARAMETER(eventName);
    UNREFERENCED_PARAMETER(status);
    UNREFERENCED_PARAMETER(data0);
    UNREFERENCED_PARAMETER(data1);
    KdPrintEx((DPFLTR_IHVDRIVER_ID,
        NT_SUCCESS(status) ? DPFLTR_INFO_LEVEL : DPFLTR_ERROR_LEVEL,
        "ChatpadLive: Event=%s Status=0x%08X Data0=%lu Data1=%lu\n",
        eventName, (ULONG)status, data0, data1));
}

static void ChatpadLiveDiagnosticUlong(
    PCHATPAD_LIVE_RUNTIME runtime,
    _In_z_ const WCHAR *name,
    ULONG value)
{
    UNICODE_STRING valueName;

    if (runtime->DiagnosticKey == NULL || KeGetCurrentIrql() != PASSIVE_LEVEL) {
        return;
    }
    RtlInitUnicodeString(&valueName, name);
    (void)WdfRegistryAssignULong(runtime->DiagnosticKey, &valueName, value);
}

static void ChatpadLiveDiagnosticStatus(
    PCHATPAD_LIVE_RUNTIME runtime,
    _In_z_ const WCHAR *name,
    NTSTATUS status)
{
    ChatpadLiveDiagnosticUlong(runtime, name, (ULONG)status);
}

static void ChatpadLiveOpenDiagnostics(PCHATPAD_LIVE_RUNTIME runtime)
{
    WDFKEY deviceKey;
    WDFKEY diagnosticKey;
    WDF_OBJECT_ATTRIBUTES attributes;
    UNICODE_STRING subkeyName;
    NTSTATUS status;

    deviceKey = NULL;
    diagnosticKey = NULL;
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = runtime->Device;
    status = WdfDriverOpenParametersRegistryKey(
        WdfDeviceGetDriver(runtime->Device),
        KEY_READ | KEY_WRITE,
        &attributes,
        &deviceKey);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveTrace("DiagnosticParametersKeyOpenFailed", status, 0u, 0u);
        return;
    }

    RtlInitUnicodeString(&subkeyName, L"ChatpadRuntimeDiagnostics");
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = runtime->Device;
    status = WdfRegistryCreateKey(
        deviceKey,
        &subkeyName,
        KEY_READ | KEY_WRITE,
        REG_OPTION_NON_VOLATILE,
        NULL,
        &attributes,
        &diagnosticKey);
    WdfRegistryClose(deviceKey);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveTrace("DiagnosticSubkeyCreateFailed", status, 0u, 0u);
        return;
    }
    runtime->DiagnosticKey = diagnosticKey;
    ChatpadLiveDiagnosticUlong(runtime, L"SchemaVersion", CHATPAD_RUNTIME_DIAGNOSTIC_SCHEMA);
    ChatpadLiveDiagnosticUlong(runtime, L"TransportArchitecture", 7u);
    ChatpadLiveDiagnosticUlong(runtime, L"DefaultPipeTransferFlag", 1u);
    ChatpadLiveDiagnosticUlong(runtime, L"ControllerInputReadinessGate", 1u);
    ChatpadLiveDiagnosticUlong(runtime, L"DeviceAddEntered", 1u);
}

static void ChatpadLiveRecordSetup(
    PCHATPAD_LIVE_RUNTIME runtime,
    ULONG stepIndex,
    const ChatpadActivationSequenceStep *step)
{
    ULONG setup0;
    ULONG setup1;

    if (stepIndex >= RTL_NUMBER_OF(ChatpadActivationSetup0Names)) {
        return;
    }
    setup0 = ((ULONG)step->Request.RawRequest) |
        ((ULONG)step->Request.RawValue << 8);
    setup1 = ((ULONG)step->Request.RawIndex) |
        ((ULONG)step->Request.RawLength << 16) |
        ((ULONG)step->Request.Direction << 31);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationSetup0Names[stepIndex], setup0);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationSetup1Names[stepIndex], setup1);
}

static void ChatpadLiveRecordActivationResult(
    PCHATPAD_LIVE_RUNTIME runtime,
    ULONG stepIndex,
    NTSTATUS status,
    USBD_STATUS usbdStatus,
    ULONG bytesTransferred,
    BOOLEAN expectedStall)
{
    if (stepIndex >= RTL_NUMBER_OF(ChatpadActivationNtStatusNames)) {
        return;
    }
    ChatpadLiveDiagnosticStatus(runtime, ChatpadActivationNtStatusNames[stepIndex], status);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationUsbdStatusNames[stepIndex], usbdStatus);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationBytesNames[stepIndex], bytesTransferred);
    ChatpadLiveDiagnosticUlong(
        runtime,
        ChatpadActivationExpectedStallNames[stepIndex],
        expectedStall ? 1u : 0u);
}

/*
 * The physical filter is the VHF source device supported by Microsoft's VHF
 * contract.  The virtual keyboard is nevertheless an optional sub-lifecycle:
 * decoded reports cross this bounded queue, and no VHF/queue failure is ever
 * returned through the physical device's PnP or power callbacks.
 */
static void ChatpadLiveDisableOptionalFeature(
    PCHATPAD_LIVE_RUNTIME runtime,
    ChatpadOptionalFailureStage stage,
    NTSTATUS status,
    BOOLEAN permanentFailure)
{
    ChatpadHidKeyboardReport releaseReport;
    HID_XFER_PACKET releasePacket;
    NTSTATUS releaseStatus;
    LONG firstStage;

    if (stage != CHATPAD_OPTIONAL_STAGE_KEYBOARD_SUBMISSION &&
        runtime->VhfHandle != NULL &&
        InterlockedCompareExchange(&runtime->VirtualKeyboardAvailable, 0, 0) != 0 &&
        KeGetCurrentIrql() == PASSIVE_LEVEL) {
        ChatpadBuildAllKeysReleasedReport(&releaseReport);
        releasePacket.reportBuffer = (PUCHAR)releaseReport.Bytes;
        releasePacket.reportBufferLen = (ULONG)CHATPAD_HID_BOOT_REPORT_LENGTH;
        releasePacket.reportId = 0;
        releaseStatus = VhfReadReportSubmit(runtime->VhfHandle, &releasePacket);
        ChatpadLiveDiagnosticStatus(runtime, L"ForcedReleaseNtStatus", releaseStatus);
    }
    if (runtime->StateLock != NULL) {
        WdfSpinLockAcquire(runtime->StateLock);
        ChatpadFailOpenRecordFailure(
            &runtime->FailOpenState,
            stage,
            (ChatpadFailOpenInt32)status,
            permanentFailure ? 1 : 0);
        runtime->KeyboardQueueHead = 0u;
        runtime->KeyboardQueueTail = 0u;
        runtime->KeyboardQueueCount = 0u;
        ChatpadInitializeHidReportState(&runtime->HidState);
        WdfSpinLockRelease(runtime->StateLock);
    }
    InterlockedExchange(&runtime->ChatpadFeatureDisabled, 1);
    InterlockedExchange(&runtime->VirtualKeyboardAvailable, 0);
    firstStage = InterlockedCompareExchange(
        &runtime->FirstOptionalFailureStage,
        (LONG)stage,
        (LONG)CHATPAD_OPTIONAL_STAGE_NONE);
    if (firstStage == (LONG)CHATPAD_OPTIONAL_STAGE_NONE) {
        runtime->FirstOptionalFailureNtStatus = status;
    }
    ChatpadLiveDiagnosticUlong(runtime, L"PhysicalStartResult", 0u);
    ChatpadLiveDiagnosticUlong(runtime, L"ControllerForwardingEnabled", 1u);
    ChatpadLiveDiagnosticUlong(runtime, L"ChatpadFeatureState", 2u);
    ChatpadLiveDiagnosticUlong(runtime, L"CHATPAD_VIRTUAL_KEYBOARD_UNAVAILABLE", 1u);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"FirstOptionalFailureStage",
        (ULONG)InterlockedCompareExchange(&runtime->FirstOptionalFailureStage, 0, 0));
    ChatpadLiveDiagnosticStatus(
        runtime,
        L"FirstOptionalFailureNtStatus",
        runtime->FirstOptionalFailureNtStatus);
    if (KeGetCurrentIrql() != PASSIVE_LEVEL && runtime->DiagnosticWorkItem != NULL &&
        InterlockedCompareExchange(&runtime->DiagnosticQueued, 1, 0) == 0) {
        WdfWorkItemEnqueue(runtime->DiagnosticWorkItem);
    }
    ChatpadLiveTrace("OptionalFeatureDisabled", status, (ULONG)stage, permanentFailure ? 1u : 0u);
}

static void ChatpadLiveQueueReport(
    PCHATPAD_LIVE_RUNTIME runtime,
    const ChatpadHidKeyboardReport *report,
    BOOLEAN force)
{
    int changed;
    BOOLEAN enqueueWorker;

    if (runtime->StateLock == NULL || runtime->KeyboardWorkItem == NULL ||
        runtime->VhfHandle == NULL ||
        InterlockedCompareExchange(&runtime->VirtualKeyboardAvailable, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->ChatpadFeatureDisabled, 0, 0) != 0) {
        return;
    }
    enqueueWorker = FALSE;
    WdfSpinLockAcquire(runtime->StateLock);
    changed = ChatpadHidReportStateUpdate(&runtime->HidState, report);
    if (!force && changed == 0) {
        WdfSpinLockRelease(runtime->StateLock);
        return;
    }
    if (runtime->KeyboardQueueCount >= CHATPAD_KEYBOARD_QUEUE_CAPACITY) {
        WdfSpinLockRelease(runtime->StateLock);
        ChatpadLiveDisableOptionalFeature(
            runtime,
            CHATPAD_OPTIONAL_STAGE_KEYBOARD_QUEUE_OVERFLOW,
            STATUS_INSUFFICIENT_RESOURCES,
            FALSE);
        return;
    }
    runtime->KeyboardQueue[runtime->KeyboardQueueTail] = *report;
    runtime->KeyboardQueueTail =
        (runtime->KeyboardQueueTail + 1u) % (ULONG)CHATPAD_KEYBOARD_QUEUE_CAPACITY;
    ++runtime->KeyboardQueueCount;
    (void)ChatpadFailOpenQueueKeyboardReport(&runtime->FailOpenState);
    enqueueWorker = InterlockedCompareExchange(&runtime->KeyboardWorkQueued, 1, 0) == 0;
    WdfSpinLockRelease(runtime->StateLock);
    if (enqueueWorker) {
        WdfWorkItemEnqueue(runtime->KeyboardWorkItem);
    }
}

static void ChatpadLiveReleaseAllKeys(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadHidKeyboardReport report;
    ChatpadBuildAllKeysReleasedReport(&report);
    ChatpadLiveQueueReport(runtime, &report, TRUE);
}

static void ChatpadLiveReleaseKeysIfNeeded(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadHidKeyboardReport report;
    ChatpadBuildAllKeysReleasedReport(&report);
    ChatpadLiveQueueReport(runtime, &report, FALSE);
}

_Use_decl_annotations_
void ChatpadLiveEvtKeyboardWorkItem(WDFWORKITEM workItem)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PCHATPAD_LIVE_RUNTIME runtime;
    ChatpadHidKeyboardReport report;
    ChatpadHidKeyboardReport releaseReport;
    HID_XFER_PACKET packet;
    NTSTATUS status;
    NTSTATUS releaseStatus;
    BOOLEAN haveReport;

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    for (;;) {
        haveReport = FALSE;
        WdfSpinLockAcquire(runtime->StateLock);
        if (runtime->KeyboardQueueCount != 0u) {
            report = runtime->KeyboardQueue[runtime->KeyboardQueueHead];
            runtime->KeyboardQueueHead =
                (runtime->KeyboardQueueHead + 1u) % (ULONG)CHATPAD_KEYBOARD_QUEUE_CAPACITY;
            --runtime->KeyboardQueueCount;
            ChatpadFailOpenCompleteKeyboardReport(&runtime->FailOpenState);
            haveReport = TRUE;
        } else {
            InterlockedExchange(&runtime->KeyboardWorkQueued, 0);
        }
        WdfSpinLockRelease(runtime->StateLock);
        if (!haveReport) {
            break;
        }
        if (runtime->VhfHandle == NULL ||
            InterlockedCompareExchange(&runtime->VirtualKeyboardAvailable, 0, 0) == 0) {
            continue;
        }
        packet.reportBuffer = (PUCHAR)report.Bytes;
        packet.reportBufferLen = (ULONG)CHATPAD_HID_BOOT_REPORT_LENGTH;
        packet.reportId = 0;
        status = VhfReadReportSubmit(runtime->VhfHandle, &packet);
        if (InterlockedCompareExchange(&runtime->FirstVhfSubmissionRecorded, 1, 0) == 0) {
            ChatpadLiveDiagnosticStatus(runtime, L"FirstKeyboardReportNtStatus", status);
        }
        if (NT_SUCCESS(status)) {
            InterlockedIncrement((volatile LONG *)&runtime->InputReportCount);
        } else {
            InterlockedIncrement((volatile LONG *)&runtime->InputEmissionFailureCount);
            ChatpadBuildAllKeysReleasedReport(&releaseReport);
            packet.reportBuffer = (PUCHAR)releaseReport.Bytes;
            releaseStatus = VhfReadReportSubmit(runtime->VhfHandle, &packet);
            ChatpadLiveDiagnosticStatus(runtime, L"ForcedReleaseNtStatus", releaseStatus);
            ChatpadLiveDisableOptionalFeature(
                runtime,
                CHATPAD_OPTIONAL_STAGE_KEYBOARD_SUBMISSION,
                status,
                FALSE);
            break;
        }
    }
}

static void ChatpadLiveQueueActivationIfReady(PCHATPAD_LIVE_RUNTIME runtime)
{
    int policyAllowed;

    if (runtime->ActivationWorkItem == NULL ||
        InterlockedCompareExchange(&runtime->ChatpadFeatureDisabled, 0, 0) != 0 ||
        InterlockedCompareExchange(&runtime->VirtualKeyboardAvailable, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->InD0, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->ConfigurationReady, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->ControllerInputReady, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->StopRequested, 0, 0) != 0 ||
        InterlockedCompareExchange(&runtime->ActivationSucceeded, 0, 0) != 0 ||
        InterlockedCompareExchange(&runtime->ActivationAttemptConsumed, 0, 0) != 0) {
        return;
    }

    WdfSpinLockAcquire(runtime->StateLock);
    policyAllowed = ChatpadFailOpenTryBeginActivation(&runtime->FailOpenState);
    WdfSpinLockRelease(runtime->StateLock);
    if (!policyAllowed) {
        return;
    }

    if (InterlockedCompareExchange(&runtime->ActivationAttemptConsumed, 1, 0) == 0 &&
        InterlockedCompareExchange(&runtime->ActivationQueued, 1, 0) == 0) {
        ChatpadLiveTrace("ActivationQueued", STATUS_SUCCESS, runtime->D0Generation, 0u);
        WdfWorkItemEnqueue(runtime->ActivationWorkItem);
    }
}

static BOOLEAN ChatpadLiveCaptureConfiguredPipe(
    PCHATPAD_LIVE_RUNTIME runtime,
    PURB urb)
{
    PUCHAR cursor;
    PUCHAR end;
    PUSBD_INTERFACE_INFORMATION interfaceInformation;
    USBD_PIPE_INFORMATION pipeInformation;
    BOOLEAN chatpadPipeCaptured;

    if (urb == NULL || !USBD_SUCCESS(urb->UrbHeader.Status)) {
        return FALSE;
    }
    if (urb->UrbHeader.Function == URB_FUNCTION_SELECT_CONFIGURATION &&
        urb->UrbHeader.Length >= FIELD_OFFSET(struct _URB_SELECT_CONFIGURATION, Interface)) {
        cursor = (PUCHAR)&urb->UrbSelectConfiguration.Interface;
    } else if (urb->UrbHeader.Function == URB_FUNCTION_SELECT_INTERFACE &&
        urb->UrbHeader.Length >= FIELD_OFFSET(struct _URB_SELECT_INTERFACE, Interface)) {
        cursor = (PUCHAR)&urb->UrbSelectInterface.Interface;
    } else {
        return FALSE;
    }
    end = (PUCHAR)urb + urb->UrbHeader.Length;
    chatpadPipeCaptured = FALSE;
    while (cursor + FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) <= end) {
        interfaceInformation = (PUSBD_INTERFACE_INFORMATION)cursor;
        if (interfaceInformation->Length < FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) ||
            cursor + interfaceInformation->Length > end) {
            break;
        }
        if (interfaceInformation->InterfaceNumber == CHATPAD_CONTROLLER_INPUT_INTERFACE_INDEX &&
            interfaceInformation->NumberOfPipes > CHATPAD_CONTROLLER_INPUT_PIPE_INDEX &&
            interfaceInformation->Length >=
                FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) + sizeof(USBD_PIPE_INFORMATION)) {
            pipeInformation =
                interfaceInformation->Pipes[CHATPAD_CONTROLLER_INPUT_PIPE_INDEX];
            if (pipeInformation.PipeHandle != NULL &&
                (pipeInformation.PipeType == UsbdPipeTypeInterrupt ||
                 pipeInformation.PipeType == UsbdPipeTypeBulk) &&
                (pipeInformation.EndpointAddress & USB_ENDPOINT_DIRECTION_MASK) != 0) {
                InterlockedExchangePointer(
                    (PVOID volatile *)&runtime->ControllerInputPipeHandle,
                    pipeInformation.PipeHandle);
                InterlockedExchange(&runtime->ControllerInputPipeFound, 1);
            }
        }
        if (interfaceInformation->InterfaceNumber == CHATPAD_INPUT_INTERFACE_INDEX &&
            interfaceInformation->NumberOfPipes > CHATPAD_INPUT_PIPE_INDEX &&
            interfaceInformation->Length >=
                FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) + sizeof(USBD_PIPE_INFORMATION)) {
            InterlockedExchange(&runtime->Interface2Found, 1);
            pipeInformation = interfaceInformation->Pipes[CHATPAD_INPUT_PIPE_INDEX];
            if (pipeInformation.PipeHandle != NULL &&
                (pipeInformation.PipeType == UsbdPipeTypeInterrupt ||
                 pipeInformation.PipeType == UsbdPipeTypeBulk) &&
                (pipeInformation.EndpointAddress & USB_ENDPOINT_DIRECTION_MASK) != 0) {
                runtime->InputEndpointAddress = pipeInformation.EndpointAddress;
                runtime->InputMaximumPacketSize = pipeInformation.MaximumPacketSize;
                runtime->InputPipeType = (ULONG)pipeInformation.PipeType;
                InterlockedExchange(&runtime->Pipe0Found, 1);
                InterlockedExchangePointer(
                    (PVOID volatile *)&runtime->InputPipeHandle,
                    pipeInformation.PipeHandle);
                InterlockedExchange(&runtime->ConfigurationReady, 1);
                chatpadPipeCaptured = TRUE;
            }
        }
        cursor += interfaceInformation->Length;
    }
    return chatpadPipeCaptured;
}

_Use_decl_annotations_
void ChatpadLiveEvtDiagnosticWorkItem(WDFWORKITEM workItem)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PCHATPAD_LIVE_RUNTIME runtime;

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ConfigurationCompletionCount",
        (ULONG)InterlockedCompareExchange(&runtime->ConfigurationCompletionCount, 0, 0));
    ChatpadLiveDiagnosticStatus(
        runtime,
        L"ConfigurationNtStatus",
        runtime->LastConfigurationNtStatus);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ConfigurationUsbdStatus",
        runtime->LastConfigurationUsbdStatus);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ControllerInputPipeFound",
        (ULONG)InterlockedCompareExchange(&runtime->ControllerInputPipeFound, 0, 0));
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ControllerInputReady",
        (ULONG)InterlockedCompareExchange(&runtime->ControllerInputReady, 0, 0));
    ChatpadLiveDiagnosticStatus(
        runtime,
        L"ControllerInputCompletionNtStatus",
        runtime->LastControllerInputNtStatus);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ControllerInputCompletionUsbdStatus",
        runtime->LastControllerInputUsbdStatus);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"ControllerInputCompletionBytes",
        runtime->LastControllerInputBytes);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"Interface2Found",
        (ULONG)InterlockedCompareExchange(&runtime->Interface2Found, 0, 0));
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"Pipe0Found",
        (ULONG)InterlockedCompareExchange(&runtime->Pipe0Found, 0, 0));
    ChatpadLiveDiagnosticUlong(runtime, L"InputEndpointAddress", runtime->InputEndpointAddress);
    ChatpadLiveDiagnosticUlong(runtime, L"InputMaximumPacketSize", runtime->InputMaximumPacketSize);
    ChatpadLiveDiagnosticUlong(runtime, L"InputPipeType", runtime->InputPipeType);
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"FirstOptionalFailureStage",
        (ULONG)InterlockedCompareExchange(&runtime->FirstOptionalFailureStage, 0, 0));
    ChatpadLiveDiagnosticStatus(
        runtime,
        L"FirstOptionalFailureNtStatus",
        runtime->FirstOptionalFailureNtStatus);
    InterlockedExchange(&runtime->DiagnosticQueued, 0);
}

static NTSTATUS ChatpadLiveSelectConfigurationCompletion(
    PDEVICE_OBJECT deviceObject,
    PIRP irp,
    PVOID completionContext)
{
    PCHATPAD_LIVE_RUNTIME runtime;
    PURB urb;
    BOOLEAN captured;

    UNREFERENCED_PARAMETER(deviceObject);
    runtime = (PCHATPAD_LIVE_RUNTIME)completionContext;
    urb = URB_FROM_IRP(irp);
    captured = NT_SUCCESS(irp->IoStatus.Status) &&
        ChatpadLiveCaptureConfiguredPipe(runtime, urb);
    runtime->LastConfigurationNtStatus = irp->IoStatus.Status;
    runtime->LastConfigurationUsbdStatus =
        urb != NULL ? urb->UrbHeader.Status : USBD_STATUS_INVALID_PARAMETER;
    InterlockedIncrement(&runtime->ConfigurationCompletionCount);
    ChatpadLiveTrace(
        "ConfigurationCompletion",
        captured ? STATUS_SUCCESS : STATUS_DEVICE_CONFIGURATION_ERROR,
        urb != NULL ? urb->UrbHeader.Status : USBD_STATUS_INVALID_PARAMETER,
        runtime->InputEndpointAddress);
    if (captured) {
        ChatpadLiveQueueActivationIfReady(runtime);
    } else if (urb != NULL &&
        urb->UrbHeader.Function == URB_FUNCTION_SELECT_CONFIGURATION &&
        NT_SUCCESS(irp->IoStatus.Status)) {
        ChatpadLiveDisableOptionalFeature(
            runtime,
            CHATPAD_OPTIONAL_STAGE_INTERFACE_PIPE_DISCOVERY,
            STATUS_DEVICE_CONFIGURATION_ERROR,
            FALSE);
    }
    if (runtime->DiagnosticWorkItem != NULL &&
        InterlockedCompareExchange(&runtime->DiagnosticQueued, 1, 0) == 0) {
        WdfWorkItemEnqueue(runtime->DiagnosticWorkItem);
    }
    if (irp->PendingReturned) {
        IoMarkIrpPending(irp);
    }
    return STATUS_CONTINUE_COMPLETION;
}

static BOOLEAN ChatpadLiveIsControllerInputUrb(
    PCHATPAD_LIVE_RUNTIME runtime,
    PURB urb)
{
    USBD_PIPE_HANDLE controllerInputPipeHandle;

    if (urb == NULL ||
        urb->UrbHeader.Function != URB_FUNCTION_BULK_OR_INTERRUPT_TRANSFER ||
        urb->UrbHeader.Length < sizeof(struct _URB_BULK_OR_INTERRUPT_TRANSFER) ||
        InterlockedCompareExchange(&runtime->InD0, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->ControllerInputReady, 0, 0) != 0) {
        return FALSE;
    }
    controllerInputPipeHandle =
        (USBD_PIPE_HANDLE)InterlockedCompareExchangePointer(
            (PVOID volatile *)&runtime->ControllerInputPipeHandle,
            NULL,
            NULL);
    return controllerInputPipeHandle != NULL &&
        urb->UrbBulkOrInterruptTransfer.PipeHandle == controllerInputPipeHandle;
}

static NTSTATUS ChatpadLiveControllerInputCompletion(
    PDEVICE_OBJECT deviceObject,
    PIRP irp,
    PVOID completionContext)
{
    PCHATPAD_LIVE_RUNTIME runtime;
    PURB urb;
    BOOLEAN ready;

    UNREFERENCED_PARAMETER(deviceObject);
    runtime = (PCHATPAD_LIVE_RUNTIME)completionContext;
    urb = URB_FROM_IRP(irp);
    runtime->LastControllerInputNtStatus = irp->IoStatus.Status;
    runtime->LastControllerInputUsbdStatus =
        urb != NULL ? urb->UrbHeader.Status : USBD_STATUS_INVALID_PARAMETER;
    runtime->LastControllerInputBytes =
        urb != NULL ? urb->UrbBulkOrInterruptTransfer.TransferBufferLength : 0u;
    ready = NT_SUCCESS(irp->IoStatus.Status) &&
        urb != NULL &&
        USBD_SUCCESS(urb->UrbHeader.Status) &&
        urb->UrbBulkOrInterruptTransfer.TransferBufferLength != 0u &&
        InterlockedCompareExchange(&runtime->InD0, 0, 0) != 0;
    if (ready &&
        InterlockedCompareExchange(&runtime->ControllerInputReady, 1, 0) == 0) {
        ChatpadLiveTrace(
            "ControllerInputReady",
            STATUS_SUCCESS,
            urb->UrbBulkOrInterruptTransfer.TransferBufferLength,
            runtime->D0Generation);
        ChatpadLiveQueueActivationIfReady(runtime);
    }
    if (runtime->DiagnosticWorkItem != NULL &&
        InterlockedCompareExchange(&runtime->DiagnosticQueued, 1, 0) == 0) {
        WdfWorkItemEnqueue(runtime->DiagnosticWorkItem);
    }
    if (irp->PendingReturned) {
        IoMarkIrpPending(irp);
    }
    return STATUS_CONTINUE_COMPLETION;
}

_Use_decl_annotations_
NTSTATUS ChatpadLiveEvtWdmIrpPreprocess(
    WDFDEVICE device,
    PIRP irp)
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PIO_STACK_LOCATION stack;
    PURB urb;

    context = ChatpadFilterGetDeviceContext(device);
    stack = IoGetCurrentIrpStackLocation(irp);
    urb = NULL;
    if (stack->Parameters.DeviceIoControl.IoControlCode == IOCTL_INTERNAL_USB_SUBMIT_URB) {
        urb = URB_FROM_IRP(irp);
    }
    if (ChatpadLiveIsControllerInputUrb(&context->LiveRuntime, urb)) {
        IoCopyCurrentIrpStackLocationToNext(irp);
        IoSetCompletionRoutine(
            irp,
            ChatpadLiveControllerInputCompletion,
            &context->LiveRuntime,
            TRUE,
            TRUE,
            TRUE);
        return IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp);
    }
    if (urb != NULL &&
        (urb->UrbHeader.Function == URB_FUNCTION_SELECT_CONFIGURATION ||
         urb->UrbHeader.Function == URB_FUNCTION_SELECT_INTERFACE)) {
        IoCopyCurrentIrpStackLocationToNext(irp);
        IoSetCompletionRoutine(
            irp,
            ChatpadLiveSelectConfigurationCompletion,
            &context->LiveRuntime,
            TRUE,
            TRUE,
            TRUE);
        return IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp);
    }

    IoSkipCurrentIrpStackLocation(irp);
    return IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp);
}

static NTSTATUS ChatpadLiveSubmitUrbSynchronously(
    PCHATPAD_LIVE_RUNTIME runtime,
    PURB urb,
    ULONG timeoutMilliseconds)
{
    WDF_MEMORY_DESCRIPTOR urbDescriptor;
    WDF_REQUEST_SEND_OPTIONS options;

    WDF_MEMORY_DESCRIPTOR_INIT_BUFFER(&urbDescriptor, urb, urb->UrbHeader.Length);
    WDF_REQUEST_SEND_OPTIONS_INIT(&options, WDF_REQUEST_SEND_OPTION_TIMEOUT);
    WDF_REQUEST_SEND_OPTIONS_SET_TIMEOUT(
        &options,
        WDF_REL_TIMEOUT_IN_MS(timeoutMilliseconds));
    return WdfIoTargetSendInternalIoctlOthersSynchronously(
        WdfDeviceGetIoTarget(runtime->Device),
        NULL,
        IOCTL_INTERNAL_USB_SUBMIT_URB,
        &urbDescriptor,
        NULL,
        NULL,
        &options,
        NULL);
}

static NTSTATUS ChatpadLiveSendActivationStep(
    PCHATPAD_LIVE_RUNTIME runtime,
    const ChatpadActivationSequenceStep *step,
    PULONG bytesTransferred,
    USBD_STATUS *usbdStatus,
    PNTSTATUS rawNtStatus,
    PBOOLEAN expectedStall)
{
    URB urb;
    UCHAR buffer[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH] = { 0 };
    ULONG transferFlags;
    NTSTATUS status;
    ChatpadLiveTransferResult transferResult;

    RtlZeroMemory(&urb, sizeof(urb));
    transferFlags = USBD_DEFAULT_PIPE_TRANSFER;
    if (step->Request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST) {
        transferFlags |= USBD_TRANSFER_DIRECTION_IN | USBD_SHORT_TRANSFER_OK;
    } else if (step->Request.RawLength != 0u) {
        RtlCopyMemory(
            buffer,
            step->Request.OutboundPayload,
            step->Request.OutboundPayloadLength);
    }
    urb.UrbControlTransfer.Hdr.Length =
        (USHORT)sizeof(struct _URB_CONTROL_TRANSFER);
    urb.UrbControlTransfer.Hdr.Function = URB_FUNCTION_CONTROL_TRANSFER;
    urb.UrbControlTransfer.PipeHandle = NULL;
    urb.UrbControlTransfer.TransferFlags = transferFlags;
    urb.UrbControlTransfer.TransferBufferLength = step->Request.RawLength;
    urb.UrbControlTransfer.TransferBuffer =
        step->Request.RawLength != 0u ? buffer : NULL;
    urb.UrbControlTransfer.TransferBufferMDL = NULL;
    urb.UrbControlTransfer.UrbLink = NULL;
    urb.UrbControlTransfer.SetupPacket[0] = step->Request.RawBmRequestType;
    urb.UrbControlTransfer.SetupPacket[1] = step->Request.RawRequest;
    urb.UrbControlTransfer.SetupPacket[2] =
        (UCHAR)(step->Request.RawValue & 0x00FFu);
    urb.UrbControlTransfer.SetupPacket[3] =
        (UCHAR)((step->Request.RawValue >> 8) & 0x00FFu);
    urb.UrbControlTransfer.SetupPacket[4] =
        (UCHAR)(step->Request.RawIndex & 0x00FFu);
    urb.UrbControlTransfer.SetupPacket[5] =
        (UCHAR)((step->Request.RawIndex >> 8) & 0x00FFu);
    urb.UrbControlTransfer.SetupPacket[6] =
        (UCHAR)(step->Request.RawLength & 0x00FFu);
    urb.UrbControlTransfer.SetupPacket[7] =
        (UCHAR)((step->Request.RawLength >> 8) & 0x00FFu);
    status = ChatpadLiveSubmitUrbSynchronously(runtime, &urb, CHATPAD_CONTROL_TIMEOUT_MS);
    *usbdStatus = urb.UrbHeader.Status;
    *bytesTransferred = urb.UrbControlTransfer.TransferBufferLength;
    if (NT_SUCCESS(status) && !USBD_SUCCESS(*usbdStatus)) {
        status = STATUS_UNSUCCESSFUL;
    }
    *rawNtStatus = status;
    *expectedStall = ChatpadIsAcceptedActivationStall(
        step->SequenceIndex,
        NT_SUCCESS(status),
        status == STATUS_IO_TIMEOUT || status == STATUS_TIMEOUT,
        status == STATUS_CANCELLED,
        *usbdStatus == USBD_STATUS_STALL_PID,
        *bytesTransferred,
        step->Request.RawLength) ? TRUE : FALSE;
    if (*expectedStall) {
        return STATUS_SUCCESS;
    }
    transferResult = ChatpadValidateLiveTransferOutcome(
        NT_SUCCESS(status),
        status == STATUS_IO_TIMEOUT || status == STATUS_TIMEOUT,
        status == STATUS_CANCELLED,
        *bytesTransferred,
        step->Request.RawLength);
    if (transferResult == CHATPAD_LIVE_TRANSFER_BYTE_COUNT_MISMATCH) {
        status = STATUS_DEVICE_DATA_ERROR;
    } else if (transferResult == CHATPAD_LIVE_TRANSFER_TIMED_OUT) {
        status = STATUS_IO_TIMEOUT;
    } else if (transferResult == CHATPAD_LIVE_TRANSFER_CANCELLED) {
        status = STATUS_CANCELLED;
    }
    if (NT_SUCCESS(status) && step->SequenceIndex == 5u &&
        (buffer[0] != 0x09u || buffer[1] != 0x00u)) {
        status = STATUS_DEVICE_PROTOCOL_ERROR;
    }
    return status;
}

_Use_decl_annotations_
void ChatpadLiveEvtActivationWorkItem(WDFWORKITEM workItem)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PCHATPAD_LIVE_RUNTIME runtime;
    ChatpadActivationSequenceStep step;
    size_t stepIndex;
    ULONG bytesTransferred;
    USBD_STATUS usbdStatus;
    LARGE_INTEGER delay;
    NTSTATUS status;
    NTSTATUS rawNtStatus;
    BOOLEAN expectedStall;

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    status = STATUS_SUCCESS;
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationWorkerEntered", 1u);
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationAttemptGeneration", runtime->D0Generation);
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationLastAttemptedStep", MAXULONG);
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationCompleted", 0u);
    ChatpadLiveDiagnosticUlong(runtime, L"ReaderStarted", 0u);
    InterlockedIncrement((volatile LONG *)&runtime->ActivationAttemptCount);

    for (stepIndex = 0; stepIndex < ChatpadGetActivationSequenceStepCount(); ++stepIndex) {
        if (InterlockedCompareExchange(&runtime->StopRequested, 0, 0) != 0 ||
            InterlockedCompareExchange(&runtime->InD0, 0, 0) == 0) {
            status = STATUS_CANCELLED;
            break;
        }
        if (ChatpadGetActivationSequenceStep(stepIndex, &step) != CHATPAD_ACTIVATION_SEQUENCE_OK) {
            status = STATUS_INVALID_DEVICE_STATE;
            break;
        }
        ChatpadLiveRecordSetup(runtime, (ULONG)stepIndex, &step);
        bytesTransferred = 0u;
        usbdStatus = USBD_STATUS_INVALID_PARAMETER;
        rawNtStatus = STATUS_UNSUCCESSFUL;
        expectedStall = FALSE;
        ChatpadLiveDiagnosticUlong(
            runtime,
            L"ActivationLastAttemptedStep",
            (ULONG)stepIndex);
        status = ChatpadLiveSendActivationStep(
            runtime,
            &step,
            &bytesTransferred,
            &usbdStatus,
            &rawNtStatus,
            &expectedStall);
        runtime->LastActivationStep = (ULONG)stepIndex;
        runtime->LastBytesTransferred = bytesTransferred;
        runtime->LastUsbdStatus = usbdStatus;
        ChatpadLiveRecordActivationResult(
            runtime,
            (ULONG)stepIndex,
            rawNtStatus,
            usbdStatus,
            bytesTransferred,
            expectedStall);
        ChatpadLiveTrace(
            expectedStall ? "ActivationAcceptedStall" : "ActivationStep",
            expectedStall ? STATUS_SUCCESS : status,
            (ULONG)stepIndex,
            bytesTransferred);
        if (!NT_SUCCESS(status)) {
            ChatpadLiveDisableOptionalFeature(
                runtime,
                (ChatpadOptionalFailureStage)(CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_1 + stepIndex),
                status,
                FALSE);
            break;
        }
        if (step.DelayAfterMilliseconds != 0u) {
            delay.QuadPart = -((LONGLONG)step.DelayAfterMilliseconds * 10 * 1000);
            KeDelayExecutionThread(KernelMode, FALSE, &delay);
        }
    }

    runtime->LastActivationStatus = status;
    ChatpadLiveDiagnosticStatus(runtime, L"ActivationFinalNtStatus", status);
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationFinalUsbdStatus", runtime->LastUsbdStatus);
    if (NT_SUCCESS(status) &&
        InterlockedCompareExchange(&runtime->StopRequested, 0, 0) == 0) {
        InterlockedExchange(&runtime->ActivationSucceeded, 1);
        InterlockedIncrement((volatile LONG *)&runtime->ActivationSuccessCount);
        ChatpadLiveDiagnosticUlong(runtime, L"ActivationCompleted", 1u);
        ChatpadLiveTrace("ActivationCompleted", status, runtime->ActivationAttemptCount, runtime->D0Generation);
        if (runtime->InputWorkItem != NULL &&
            InterlockedCompareExchange(&runtime->ReaderStarted, 1, 0) == 0) {
            ChatpadLiveDiagnosticUlong(runtime, L"ReaderStarted", 1u);
            WdfWorkItemEnqueue(runtime->InputWorkItem);
        }
    } else {
        ChatpadLiveReleaseAllKeys(runtime);
        ChatpadLiveTrace("ActivationFailed", status, runtime->LastActivationStep, runtime->LastBytesTransferred);
    }
    InterlockedExchange(&runtime->ActivationQueued, 0);
    WdfSpinLockAcquire(runtime->StateLock);
    ChatpadFailOpenCompleteActivation(&runtime->FailOpenState);
    WdfSpinLockRelease(runtime->StateLock);
}

static NTSTATUS ChatpadLiveReadInput(
    PCHATPAD_LIVE_RUNTIME runtime,
    PUCHAR bytes,
    ULONG capacity,
    PULONG bytesTransferred,
    USBD_STATUS *usbdStatus)
{
    URB urb;
    USBD_PIPE_HANDLE pipeHandle;
    NTSTATUS status;

    pipeHandle = (USBD_PIPE_HANDLE)InterlockedCompareExchangePointer(
        (PVOID volatile *)&runtime->InputPipeHandle,
        NULL,
        NULL);
    if (pipeHandle == NULL) {
        *bytesTransferred = 0u;
        *usbdStatus = USBD_STATUS_INVALID_PIPE_HANDLE;
        return STATUS_DEVICE_NOT_READY;
    }
    RtlZeroMemory(&urb, sizeof(urb));
    UsbBuildInterruptOrBulkTransferRequest(
        &urb,
        sizeof(struct _URB_BULK_OR_INTERRUPT_TRANSFER),
        pipeHandle,
        bytes,
        NULL,
        capacity,
        USBD_TRANSFER_DIRECTION_IN | USBD_SHORT_TRANSFER_OK,
        NULL);
    status = ChatpadLiveSubmitUrbSynchronously(runtime, &urb, CHATPAD_INPUT_TIMEOUT_MS);
    *usbdStatus = urb.UrbHeader.Status;
    *bytesTransferred = urb.UrbBulkOrInterruptTransfer.TransferBufferLength;
    if (NT_SUCCESS(status) && !USBD_SUCCESS(*usbdStatus)) {
        status = STATUS_UNSUCCESSFUL;
    }
    return status;
}

static NTSTATUS ChatpadLiveSendKeepAlive(
    PCHATPAD_LIVE_RUNTIME runtime,
    USHORT value,
    PULONG bytesTransferred,
    USBD_STATUS *usbdStatus)
{
    URB urb;
    UCHAR setupPacket[8];
    NTSTATUS status;

    RtlZeroMemory(&urb, sizeof(urb));
    RtlZeroMemory(setupPacket, sizeof(setupPacket));
    setupPacket[0] = 0x41u;
    setupPacket[1] = 0x00u;
    setupPacket[2] = (UCHAR)(value & 0x00FFu);
    setupPacket[3] = (UCHAR)((value >> 8) & 0x00FFu);
    setupPacket[4] = 0x02u;
    setupPacket[5] = 0x00u;
    setupPacket[6] = 0x00u;
    setupPacket[7] = 0x00u;
    urb.UrbControlTransfer.Hdr.Length =
        (USHORT)sizeof(struct _URB_CONTROL_TRANSFER);
    urb.UrbControlTransfer.Hdr.Function = URB_FUNCTION_CONTROL_TRANSFER;
    urb.UrbControlTransfer.PipeHandle = NULL;
    urb.UrbControlTransfer.TransferFlags = USBD_DEFAULT_PIPE_TRANSFER;
    urb.UrbControlTransfer.TransferBufferLength = 0u;
    urb.UrbControlTransfer.TransferBuffer = NULL;
    urb.UrbControlTransfer.TransferBufferMDL = NULL;
    urb.UrbControlTransfer.UrbLink = NULL;
    RtlCopyMemory(urb.UrbControlTransfer.SetupPacket, setupPacket, sizeof(setupPacket));

    status = ChatpadLiveSubmitUrbSynchronously(
        runtime,
        &urb,
        CHATPAD_CONTROL_TIMEOUT_MS);
    *usbdStatus = urb.UrbHeader.Status;
    *bytesTransferred = urb.UrbControlTransfer.TransferBufferLength;
    if (NT_SUCCESS(status) && !USBD_SUCCESS(*usbdStatus)) {
        status = STATUS_UNSUCCESSFUL;
    }
    if (NT_SUCCESS(status) && *bytesTransferred != 0u) {
        status = STATUS_DEVICE_DATA_ERROR;
    }
    return status;
}

_Use_decl_annotations_
void ChatpadLiveEvtInputWorkItem(WDFWORKITEM workItem)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PCHATPAD_LIVE_RUNTIME runtime;
    UCHAR bytes[32];
    ULONG bytesTransferred;
    USBD_STATUS usbdStatus;
    ChatpadKeyboardPacket keyboardPacket;
    ChatpadHidKeyboardReport report;
    ChatpadParseResult parseResult;
    ChatpadHidMapResult mapResult;
    NTSTATUS status;
    NTSTATUS keepAliveStatus;
    USBD_STATUS keepAliveUsbdStatus;
    ULONG keepAliveBytes;
    USHORT keepAliveValue;
    ULONGLONG now;

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    ChatpadLiveTrace("InputLoopStarted", STATUS_SUCCESS, runtime->D0Generation, 0u);

    while (InterlockedCompareExchange(&runtime->StopRequested, 0, 0) == 0 &&
           InterlockedCompareExchange(&runtime->InD0, 0, 0) != 0 &&
           InterlockedCompareExchange(&runtime->ActivationSucceeded, 0, 0) != 0) {
        now = KeQueryInterruptTime();
        if (runtime->NextKeepAliveDue == 0u || now >= runtime->NextKeepAliveDue) {
            keepAliveValue = runtime->NextKeepAliveValue;
            keepAliveBytes = 0u;
            keepAliveUsbdStatus = USBD_STATUS_INVALID_PARAMETER;
            keepAliveStatus = ChatpadLiveSendKeepAlive(
                runtime,
                keepAliveValue,
                &keepAliveBytes,
                &keepAliveUsbdStatus);
            runtime->KeepAliveAttemptCount++;
            if (runtime->KeepAliveAttemptCount <= 8u) {
                ChatpadLiveDiagnosticUlong(
                    runtime,
                    L"KeepAliveAttemptCount",
                    runtime->KeepAliveAttemptCount);
            }
            if (InterlockedCompareExchange(&runtime->FirstKeepAliveRecorded, 1, 0) == 0) {
                ChatpadLiveDiagnosticStatus(
                    runtime,
                    L"FirstKeepAliveNtStatus",
                    keepAliveStatus);
                ChatpadLiveDiagnosticUlong(
                    runtime,
                    L"FirstKeepAliveUsbdStatus",
                    keepAliveUsbdStatus);
                ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveBytes", keepAliveBytes);
                ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveValue", keepAliveValue);
            }
            ChatpadLiveTrace(
                "KeepAlive",
                keepAliveStatus,
                keepAliveValue,
                runtime->KeepAliveAttemptCount);
            if (!NT_SUCCESS(keepAliveStatus)) {
                ChatpadLiveDisableOptionalFeature(
                    runtime,
                    CHATPAD_OPTIONAL_STAGE_KEEPALIVE,
                    keepAliveStatus,
                    FALSE);
                break;
            }
            runtime->NextKeepAliveValue =
                runtime->NextKeepAliveValue == CHATPAD_KEEPALIVE_VALUE_A ?
                CHATPAD_KEEPALIVE_VALUE_B : CHATPAD_KEEPALIVE_VALUE_A;
            runtime->NextKeepAliveDue = now +
                ((ULONGLONG)CHATPAD_KEEPALIVE_INTERVAL_MS * 10u * 1000u);
        }
        RtlZeroMemory(bytes, sizeof(bytes));
        bytesTransferred = 0u;
        usbdStatus = USBD_STATUS_INVALID_PARAMETER;
        status = ChatpadLiveReadInput(
            runtime,
            bytes,
            sizeof(bytes),
            &bytesTransferred,
            &usbdStatus);
        if (InterlockedCompareExchange(&runtime->FirstInputCompletionRecorded, 1, 0) == 0) {
            ChatpadLiveDiagnosticStatus(runtime, L"FirstInputNtStatus", status);
            ChatpadLiveDiagnosticUlong(runtime, L"FirstInputUsbdStatus", usbdStatus);
            ChatpadLiveDiagnosticUlong(runtime, L"FirstInputBytes", bytesTransferred);
        }
        if (status == STATUS_IO_TIMEOUT || status == STATUS_TIMEOUT) {
            ChatpadLiveReleaseKeysIfNeeded(runtime);
            continue;
        }
        if (!NT_SUCCESS(status)) {
            ChatpadLiveTrace("InputReadFailed", status, bytesTransferred, usbdStatus);
            ChatpadLiveDisableOptionalFeature(
                runtime,
                CHATPAD_OPTIONAL_STAGE_INPUT_READ,
                status,
                FALSE);
            break;
        }
        if (bytesTransferred < CHATPAD_KEYBOARD_PACKET_LENGTH) {
            InterlockedIncrement((volatile LONG *)&runtime->ParseFailureCount);
            continue;
        }
        if (InterlockedCompareExchange(&runtime->FirstRawPacketRecorded, 1, 0) == 0) {
            ChatpadLiveDiagnosticUlong(
                runtime,
                L"FirstRawPacket0",
                ((ULONG)bytes[0]) | ((ULONG)bytes[1] << 8) |
                ((ULONG)bytes[2] << 16) | ((ULONG)bytes[3] << 24));
            ChatpadLiveDiagnosticUlong(runtime, L"FirstRawPacket1", bytes[4]);
        }
        InterlockedIncrement((volatile LONG *)&runtime->InputPacketCount);
        parseResult = ChatpadParseKeyboardPacket(bytes, CHATPAD_KEYBOARD_PACKET_LENGTH, &keyboardPacket);
        if (InterlockedCompareExchange(&runtime->FirstDecodeRecorded, 1, 0) == 0) {
            ChatpadLiveDiagnosticUlong(runtime, L"FirstDecodeResult", (ULONG)parseResult);
        }
        if (parseResult != CHATPAD_PARSE_OK) {
            if (InterlockedIncrement((volatile LONG *)&runtime->ParseFailureCount) <= 8) {
                ChatpadLiveTrace("DecodeRejected", STATUS_DEVICE_DATA_ERROR, (ULONG)parseResult, bytesTransferred);
            }
            ChatpadLiveReleaseKeysIfNeeded(runtime);
            continue;
        }
        mapResult = ChatpadMapKeyboardPacketToHid(&keyboardPacket, &report);
        if (mapResult != CHATPAD_HID_MAP_OK) {
            if (InterlockedIncrement((volatile LONG *)&runtime->ParseFailureCount) <= 8) {
                ChatpadLiveTrace("KeyMapRejected", STATUS_NOT_SUPPORTED, (ULONG)mapResult, bytes[2]);
            }
            ChatpadLiveReleaseKeysIfNeeded(runtime);
            continue;
        }
        ChatpadLiveQueueReport(runtime, &report, FALSE);
    }
    InterlockedExchange(&runtime->ReaderStarted, 0);
    ChatpadLiveReleaseAllKeys(runtime);
    ChatpadLiveTrace("InputLoopStopped", STATUS_SUCCESS, runtime->InputPacketCount, runtime->InputReportCount);
}

NTSTATUS ChatpadLiveRuntimeInitialize(
    WDFDEVICE device,
    PCHATPAD_LIVE_RUNTIME runtime)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDF_WORKITEM_CONFIG workItemConfig;
    NTSTATUS status;
    WDFMEMORY hardwareIdsMemory;
    PWSTR hardwareId;
    size_t hardwareIdsLength;
    UNICODE_STRING candidateId;
    UNICODE_STRING supportedId;
    BOOLEAN matched;

    RtlZeroMemory(runtime, sizeof(*runtime));
    runtime->Signature = CHATPAD_LIVE_RUNTIME_SIGNATURE;
    runtime->Device = device;
    runtime->LastActivationStatus = STATUS_DEVICE_NOT_READY;
    runtime->LastUsbdStatus = USBD_STATUS_INVALID_PARAMETER;
    runtime->LastConfigurationNtStatus = STATUS_DEVICE_NOT_READY;
    runtime->LastControllerInputNtStatus = STATUS_DEVICE_NOT_READY;
    runtime->LastConfigurationUsbdStatus = USBD_STATUS_INVALID_PARAMETER;
    runtime->LastControllerInputUsbdStatus = USBD_STATUS_INVALID_PARAMETER;
    ChatpadInitializeHidReportState(&runtime->HidState);
    ChatpadFailOpenInitialize(&runtime->FailOpenState);
    ChatpadLiveOpenDiagnostics(runtime);

    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfDeviceAllocAndQueryProperty(
        device,
        DevicePropertyHardwareID,
        PagedPool,
        &attributes,
        &hardwareIdsMemory);
    ChatpadLiveDiagnosticStatus(runtime, L"HardwareIdQueryNtStatus", status);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveTrace("DeviceMatchQueryFailed", status, 0u, 0u);
        return status;
    }
    hardwareId = (PWSTR)WdfMemoryGetBuffer(hardwareIdsMemory, &hardwareIdsLength);
    RtlInitUnicodeString(&supportedId, ChatpadSupportedHardwareId);
    matched = FALSE;
    while (hardwareId != NULL && *hardwareId != L'\0') {
        RtlInitUnicodeString(&candidateId, hardwareId);
        if (RtlEqualUnicodeString(&candidateId, &supportedId, TRUE)) {
            matched = TRUE;
            break;
        }
        hardwareId += candidateId.Length / sizeof(WCHAR) + 1;
    }
    ChatpadLiveDiagnosticUlong(runtime, L"ExactDeviceMatched", matched ? 1u : 0u);
    if (!matched) {
        ChatpadLiveTrace("DeviceRejected", STATUS_NOT_SUPPORTED, (ULONG)hardwareIdsLength, 0u);
        return STATUS_NOT_SUPPORTED;
    }

    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfSpinLockCreate(&attributes, &runtime->StateLock);
    ChatpadLiveDiagnosticStatus(runtime, L"SpinLockCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        InterlockedExchange(&runtime->ChatpadFeatureDisabled, 1);
        ChatpadLiveDiagnosticUlong(runtime, L"ControllerForwardingEnabled", 1u);
        ChatpadLiveDiagnosticUlong(runtime, L"ChatpadFeatureState", 2u);
        ChatpadLiveDiagnosticStatus(runtime, L"RuntimeInitializeNtStatus", STATUS_SUCCESS);
        return STATUS_SUCCESS;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtActivationWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->ActivationWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"ActivationWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveDisableOptionalFeature(
            runtime,
            CHATPAD_OPTIONAL_STAGE_ACTIVATION_WORKER_CREATE,
            status,
            TRUE);
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtInputWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->InputWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"InputWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveDisableOptionalFeature(
            runtime,
            CHATPAD_OPTIONAL_STAGE_CONTINUOUS_READER_SETUP,
            status,
            TRUE);
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtKeyboardWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->KeyboardWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"KeyboardWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveDisableOptionalFeature(
            runtime,
            CHATPAD_OPTIONAL_STAGE_VIRTUAL_CHILD_CREATE,
            status,
            TRUE);
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtDiagnosticWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->DiagnosticWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"DiagnosticWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        ChatpadLiveTrace("DiagnosticWorkerUnavailable", status, 0u, 0u);
    }
    ChatpadLiveDiagnosticStatus(runtime, L"RuntimeInitializeNtStatus", STATUS_SUCCESS);
    return STATUS_SUCCESS;
}

NTSTATUS ChatpadLiveRuntimePrepareHardware(PCHATPAD_LIVE_RUNTIME runtime)
{
    VHF_CONFIG vhfConfig;
    NTSTATUS status;
    BOOLEAN vhfCreated;

    InterlockedExchange(&runtime->StopRequested, 0);
    vhfCreated = FALSE;
    ChatpadLiveDiagnosticUlong(runtime, L"PrepareHardwareEntered", 1u);
    if (InterlockedCompareExchange(&runtime->ChatpadFeatureDisabled, 0, 0) == 0 &&
        runtime->VhfHandle == NULL) {
        VHF_CONFIG_INIT(
            &vhfConfig,
            WdfDeviceWdmGetDeviceObject(runtime->Device),
            (USHORT)sizeof(ChatpadKeyboardReportDescriptor),
            (PUCHAR)ChatpadKeyboardReportDescriptor);
        vhfConfig.VendorID = 0x045E;
        vhfConfig.ProductID = 0x028E;
        vhfConfig.VersionNumber = 0x010C;
        status = VhfCreate(&vhfConfig, &runtime->VhfHandle);
        ChatpadLiveDiagnosticStatus(runtime, L"VhfCreateNtStatus", status);
        if (NT_SUCCESS(status)) {
            vhfCreated = TRUE;
            status = VhfStart(runtime->VhfHandle);
            ChatpadLiveDiagnosticStatus(runtime, L"VhfStartNtStatus", status);
            if (NT_SUCCESS(status)) {
                InterlockedExchange(&runtime->VirtualKeyboardAvailable, 1);
                WdfSpinLockAcquire(runtime->StateLock);
                ChatpadFailOpenSetVirtualKeyboardAvailable(&runtime->FailOpenState, 1);
                WdfSpinLockRelease(runtime->StateLock);
                ChatpadLiveDiagnosticUlong(runtime, L"ChatpadFeatureState", 1u);
            }
        }
        if (!NT_SUCCESS(status)) {
            if (runtime->VhfHandle != NULL) {
                VhfDelete(runtime->VhfHandle, TRUE);
                runtime->VhfHandle = NULL;
            }
            ChatpadLiveTrace("VhfInitializationFailed", status, 0u, 0u);
            ChatpadLiveDisableOptionalFeature(
                runtime,
                vhfCreated
                    ? CHATPAD_OPTIONAL_STAGE_VHF_START
                    : CHATPAD_OPTIONAL_STAGE_VHF_CREATE,
                status,
                TRUE);
        }
    }
    ChatpadLiveDiagnosticStatus(runtime, L"PrepareHardwareNtStatus", STATUS_SUCCESS);
    ChatpadLiveDiagnosticUlong(runtime, L"PhysicalStartResult", 0u);
    ChatpadLiveDiagnosticUlong(runtime, L"ControllerForwardingEnabled", 1u);
    return STATUS_SUCCESS;
}

void ChatpadLiveRuntimeEnterD0(PCHATPAD_LIVE_RUNTIME runtime)
{
    if (runtime->StateLock != NULL) {
        WdfSpinLockAcquire(runtime->StateLock);
        ChatpadFailOpenBeginD0(&runtime->FailOpenState);
        InterlockedExchange(
            &runtime->ChatpadFeatureDisabled,
            runtime->FailOpenState.ChatpadFeatureEnabled ? 0 : 1);
        ChatpadFailOpenSetVirtualKeyboardAvailable(
            &runtime->FailOpenState,
            runtime->VhfHandle != NULL ? 1 : 0);
        WdfSpinLockRelease(runtime->StateLock);
    }
    InterlockedExchange(&runtime->VirtualKeyboardAvailable, runtime->VhfHandle != NULL ? 1 : 0);
    InterlockedExchange(&runtime->StopRequested, 0);
    InterlockedExchange(&runtime->InD0, 1);
    InterlockedExchange(&runtime->ActivationSucceeded, 0);
    InterlockedExchange(&runtime->ActivationQueued, 0);
    InterlockedExchange(&runtime->ActivationAttemptConsumed, 0);
    InterlockedExchange(&runtime->ControllerInputReady, 0);
    InterlockedExchange(&runtime->FirstInputCompletionRecorded, 0);
    InterlockedExchange(&runtime->FirstRawPacketRecorded, 0);
    InterlockedExchange(&runtime->FirstDecodeRecorded, 0);
    InterlockedExchange(&runtime->FirstKeepAliveRecorded, 0);
    runtime->KeepAliveAttemptCount = 0u;
    runtime->NextKeepAliveDue = 0u;
    runtime->NextKeepAliveValue = CHATPAD_KEEPALIVE_VALUE_A;
    ++runtime->D0Generation;
    ChatpadLiveDiagnosticUlong(runtime, L"D0EntryCount", runtime->D0Generation);
    ChatpadLiveDiagnosticUlong(runtime, L"ControllerInputReady", 0u);
    ChatpadLiveDiagnosticUlong(runtime, L"KeepAliveAttemptCount", 0u);
    ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveNtStatus", MAXULONG);
    ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveUsbdStatus", MAXULONG);
    ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveBytes", MAXULONG);
    ChatpadLiveDiagnosticUlong(runtime, L"FirstKeepAliveValue", MAXULONG);
    ChatpadLiveTrace("D0Entry", STATUS_SUCCESS, runtime->D0Generation, runtime->ConfigurationReady);
    ChatpadLiveQueueActivationIfReady(runtime);
}

void ChatpadLiveRuntimeExitD0(PCHATPAD_LIVE_RUNTIME runtime)
{
    InterlockedExchange(&runtime->StopRequested, 1);
    InterlockedExchange(&runtime->InD0, 0);
    ChatpadLiveDiagnosticUlong(runtime, L"CancellationRequested", 1u);
    ChatpadLiveTrace("D0ExitCancellation", STATUS_CANCELLED, runtime->D0Generation, runtime->ActivationQueued);
    if (runtime->ActivationWorkItem != NULL) {
        WdfWorkItemFlush(runtime->ActivationWorkItem);
    }
    if (runtime->InputWorkItem != NULL) {
        WdfWorkItemFlush(runtime->InputWorkItem);
    }
    ChatpadLiveReleaseAllKeys(runtime);
    if (runtime->KeyboardWorkItem != NULL) {
        WdfWorkItemFlush(runtime->KeyboardWorkItem);
    }
    if (runtime->DiagnosticWorkItem != NULL) {
        WdfWorkItemFlush(runtime->DiagnosticWorkItem);
    }
    if (runtime->StateLock != NULL) {
        WdfSpinLockAcquire(runtime->StateLock);
        ChatpadFailOpenEndD0(&runtime->FailOpenState);
        runtime->KeyboardQueueHead = 0u;
        runtime->KeyboardQueueTail = 0u;
        runtime->KeyboardQueueCount = 0u;
        WdfSpinLockRelease(runtime->StateLock);
    }
    InterlockedExchange(&runtime->VirtualKeyboardAvailable, 0);
    InterlockedExchange(&runtime->ActivationQueued, 0);
    InterlockedExchange(&runtime->ActivationSucceeded, 0);
}

void ChatpadLiveRuntimeReleaseHardware(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadLiveRuntimeExitD0(runtime);
    ChatpadLiveTrace("ReleaseHardware", STATUS_SUCCESS, runtime->D0Generation, runtime->InputPacketCount);
    InterlockedExchange(&runtime->ConfigurationReady, 0);
    InterlockedExchange(&runtime->ControllerInputPipeFound, 0);
    InterlockedExchange(&runtime->ControllerInputReady, 0);
    InterlockedExchangePointer(
        (PVOID volatile *)&runtime->ControllerInputPipeHandle,
        NULL);
    InterlockedExchangePointer((PVOID volatile *)&runtime->InputPipeHandle, NULL);
}

void ChatpadLiveRuntimeCleanup(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadLiveRuntimeExitD0(runtime);
    if (runtime->StateLock != NULL) {
        WdfSpinLockAcquire(runtime->StateLock);
        ChatpadFailOpenBeginRemoval(&runtime->FailOpenState);
        WdfSpinLockRelease(runtime->StateLock);
    }
    if (runtime->VhfHandle != NULL) {
        VhfDelete(runtime->VhfHandle, TRUE);
        runtime->VhfHandle = NULL;
    }
    ChatpadLiveTrace("RuntimeCleanup", STATUS_SUCCESS, runtime->ActivationAttemptCount, runtime->InputReportCount);
}
