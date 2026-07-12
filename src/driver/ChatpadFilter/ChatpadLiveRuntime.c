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
    ChatpadLiveDiagnosticUlong(runtime, L"TransportArchitecture", 2u);
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
    ULONG bytesTransferred)
{
    if (stepIndex >= RTL_NUMBER_OF(ChatpadActivationNtStatusNames)) {
        return;
    }
    ChatpadLiveDiagnosticStatus(runtime, ChatpadActivationNtStatusNames[stepIndex], status);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationUsbdStatusNames[stepIndex], usbdStatus);
    ChatpadLiveDiagnosticUlong(runtime, ChatpadActivationBytesNames[stepIndex], bytesTransferred);
}

static void ChatpadLiveSubmitReport(
    PCHATPAD_LIVE_RUNTIME runtime,
    const ChatpadHidKeyboardReport *report,
    BOOLEAN force)
{
    HID_XFER_PACKET packet;
    NTSTATUS status;
    int changed;

    if (runtime->VhfHandle == NULL) {
        return;
    }
    WdfSpinLockAcquire(runtime->StateLock);
    changed = ChatpadHidReportStateUpdate(&runtime->HidState, report);
    WdfSpinLockRelease(runtime->StateLock);
    if (!force && changed == 0) {
        return;
    }

    packet.reportBuffer = (PUCHAR)report->Bytes;
    packet.reportBufferLen = (ULONG)CHATPAD_HID_BOOT_REPORT_LENGTH;
    packet.reportId = 0;
    status = VhfReadReportSubmit(runtime->VhfHandle, &packet);
    if (InterlockedCompareExchange(&runtime->FirstVhfSubmissionRecorded, 1, 0) == 0) {
        ChatpadLiveDiagnosticStatus(runtime, L"FirstKeyboardReportNtStatus", status);
    }
    if (NT_SUCCESS(status)) {
        InterlockedIncrement((volatile LONG *)&runtime->InputReportCount);
    } else if (InterlockedIncrement((volatile LONG *)&runtime->InputEmissionFailureCount) <= 8) {
        ChatpadLiveTrace("VhfReportRejected", status, runtime->InputPacketCount, 0u);
    }
}

static void ChatpadLiveReleaseAllKeys(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadHidKeyboardReport report;
    ChatpadBuildAllKeysReleasedReport(&report);
    ChatpadLiveSubmitReport(runtime, &report, TRUE);
}

static void ChatpadLiveReleaseKeysIfNeeded(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadHidKeyboardReport report;
    ChatpadBuildAllKeysReleasedReport(&report);
    ChatpadLiveSubmitReport(runtime, &report, FALSE);
}

static void ChatpadLiveQueueActivationIfReady(PCHATPAD_LIVE_RUNTIME runtime)
{
    if (InterlockedCompareExchange(&runtime->InD0, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->ConfigurationReady, 0, 0) == 0 ||
        InterlockedCompareExchange(&runtime->StopRequested, 0, 0) != 0 ||
        InterlockedCompareExchange(&runtime->ActivationSucceeded, 0, 0) != 0 ||
        InterlockedCompareExchange(&runtime->ActivationAttemptConsumed, 0, 0) != 0) {
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
    while (cursor + FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) <= end) {
        interfaceInformation = (PUSBD_INTERFACE_INFORMATION)cursor;
        if (interfaceInformation->Length < FIELD_OFFSET(USBD_INTERFACE_INFORMATION, Pipes) ||
            cursor + interfaceInformation->Length > end) {
            break;
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
                return TRUE;
            }
        }
        cursor += interfaceInformation->Length;
    }
    return FALSE;
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
        L"Interface2Found",
        (ULONG)InterlockedCompareExchange(&runtime->Interface2Found, 0, 0));
    ChatpadLiveDiagnosticUlong(
        runtime,
        L"Pipe0Found",
        (ULONG)InterlockedCompareExchange(&runtime->Pipe0Found, 0, 0));
    ChatpadLiveDiagnosticUlong(runtime, L"InputEndpointAddress", runtime->InputEndpointAddress);
    ChatpadLiveDiagnosticUlong(runtime, L"InputMaximumPacketSize", runtime->InputMaximumPacketSize);
    ChatpadLiveDiagnosticUlong(runtime, L"InputPipeType", runtime->InputPipeType);
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
    if (InterlockedCompareExchange(&runtime->DiagnosticQueued, 1, 0) == 0) {
        WdfWorkItemEnqueue(runtime->DiagnosticWorkItem);
    }
    if (captured) {
        ChatpadLiveQueueActivationIfReady(runtime);
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
    USBD_STATUS *usbdStatus)
{
    URB urb;
    UCHAR buffer[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH] = { 0 };
    ULONG transferFlags;
    NTSTATUS status;
    ChatpadLiveTransferResult transferResult;

    RtlZeroMemory(&urb, sizeof(urb));
    transferFlags = 0u;
    if (step->Request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST) {
        transferFlags = USBD_TRANSFER_DIRECTION_IN | USBD_SHORT_TRANSFER_OK;
    } else if (step->Request.RawLength != 0u) {
        RtlCopyMemory(
            buffer,
            step->Request.OutboundPayload,
            step->Request.OutboundPayloadLength);
    }
    UsbBuildVendorRequest(
        &urb,
        URB_FUNCTION_VENDOR_DEVICE,
        sizeof(struct _URB_CONTROL_VENDOR_OR_CLASS_REQUEST),
        transferFlags,
        0u,
        step->Request.RawRequest,
        step->Request.RawValue,
        step->Request.RawIndex,
        step->Request.RawLength != 0u ? buffer : NULL,
        NULL,
        step->Request.RawLength,
        NULL);
    status = ChatpadLiveSubmitUrbSynchronously(runtime, &urb, CHATPAD_CONTROL_TIMEOUT_MS);
    *usbdStatus = urb.UrbHeader.Status;
    *bytesTransferred = urb.UrbControlVendorClassRequest.TransferBufferLength;
    if (NT_SUCCESS(status) && !USBD_SUCCESS(*usbdStatus)) {
        status = STATUS_UNSUCCESSFUL;
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

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    status = STATUS_SUCCESS;
    ChatpadLiveDiagnosticUlong(runtime, L"ActivationWorkerEntered", 1u);
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
        status = ChatpadLiveSendActivationStep(
            runtime,
            &step,
            &bytesTransferred,
            &usbdStatus);
        runtime->LastActivationStep = (ULONG)stepIndex;
        runtime->LastBytesTransferred = bytesTransferred;
        runtime->LastUsbdStatus = usbdStatus;
        ChatpadLiveRecordActivationResult(
            runtime,
            (ULONG)stepIndex,
            status,
            usbdStatus,
            bytesTransferred);
        ChatpadLiveTrace("ActivationStep", status, (ULONG)stepIndex, bytesTransferred);
        if (!NT_SUCCESS(status)) {
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
        if (InterlockedCompareExchange(&runtime->ReaderStarted, 1, 0) == 0) {
            ChatpadLiveDiagnosticUlong(runtime, L"ReaderStarted", 1u);
            WdfWorkItemEnqueue(runtime->InputWorkItem);
        }
    } else {
        ChatpadLiveReleaseAllKeys(runtime);
        ChatpadLiveTrace("ActivationFailed", status, runtime->LastActivationStep, runtime->LastBytesTransferred);
    }
    InterlockedExchange(&runtime->ActivationQueued, 0);
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

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    ChatpadLiveTrace("InputLoopStarted", STATUS_SUCCESS, runtime->D0Generation, 0u);

    while (InterlockedCompareExchange(&runtime->StopRequested, 0, 0) == 0 &&
           InterlockedCompareExchange(&runtime->InD0, 0, 0) != 0 &&
           InterlockedCompareExchange(&runtime->ActivationSucceeded, 0, 0) != 0) {
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
        ChatpadLiveSubmitReport(runtime, &report, FALSE);
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
    runtime->LastConfigurationUsbdStatus = USBD_STATUS_INVALID_PARAMETER;
    ChatpadInitializeHidReportState(&runtime->HidState);
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
        return status;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtActivationWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->ActivationWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"ActivationWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        return status;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtInputWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->InputWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"InputWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        return status;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtDiagnosticWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->DiagnosticWorkItem);
    ChatpadLiveDiagnosticStatus(runtime, L"DiagnosticWorkerCreateNtStatus", status);
    if (!NT_SUCCESS(status)) {
        return status;
    }
    ChatpadLiveDiagnosticStatus(runtime, L"RuntimeInitializeNtStatus", STATUS_SUCCESS);
    return STATUS_SUCCESS;
}

NTSTATUS ChatpadLiveRuntimePrepareHardware(PCHATPAD_LIVE_RUNTIME runtime)
{
    VHF_CONFIG vhfConfig;
    NTSTATUS status;

    InterlockedExchange(&runtime->StopRequested, 0);
    ChatpadLiveDiagnosticUlong(runtime, L"PrepareHardwareEntered", 1u);
    if (runtime->VhfHandle == NULL) {
        VHF_CONFIG_INIT(
            &vhfConfig,
            WdfDeviceWdmGetDeviceObject(runtime->Device),
            (USHORT)sizeof(ChatpadKeyboardReportDescriptor),
            (PUCHAR)ChatpadKeyboardReportDescriptor);
        vhfConfig.VendorID = 0x045E;
        vhfConfig.ProductID = 0x028E;
        vhfConfig.VersionNumber = 0x0104;
        status = VhfCreate(&vhfConfig, &runtime->VhfHandle);
        ChatpadLiveDiagnosticStatus(runtime, L"VhfCreateNtStatus", status);
        if (NT_SUCCESS(status)) {
            status = VhfStart(runtime->VhfHandle);
            ChatpadLiveDiagnosticStatus(runtime, L"VhfStartNtStatus", status);
        }
        if (!NT_SUCCESS(status)) {
            if (runtime->VhfHandle != NULL) {
                VhfDelete(runtime->VhfHandle, TRUE);
                runtime->VhfHandle = NULL;
            }
            ChatpadLiveTrace("VhfInitializationFailed", status, 0u, 0u);
            return status;
        }
    }
    ChatpadLiveDiagnosticStatus(runtime, L"PrepareHardwareNtStatus", STATUS_SUCCESS);
    return STATUS_SUCCESS;
}

void ChatpadLiveRuntimeEnterD0(PCHATPAD_LIVE_RUNTIME runtime)
{
    InterlockedExchange(&runtime->StopRequested, 0);
    InterlockedExchange(&runtime->InD0, 1);
    InterlockedExchange(&runtime->ActivationSucceeded, 0);
    InterlockedExchange(&runtime->ActivationQueued, 0);
    InterlockedExchange(&runtime->ActivationAttemptConsumed, 0);
    ++runtime->D0Generation;
    ChatpadLiveDiagnosticUlong(runtime, L"D0EntryCount", runtime->D0Generation);
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
    if (runtime->DiagnosticWorkItem != NULL) {
        WdfWorkItemFlush(runtime->DiagnosticWorkItem);
    }
    ChatpadLiveReleaseAllKeys(runtime);
    InterlockedExchange(&runtime->ActivationQueued, 0);
    InterlockedExchange(&runtime->ActivationSucceeded, 0);
}

void ChatpadLiveRuntimeReleaseHardware(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadLiveRuntimeExitD0(runtime);
    ChatpadLiveTrace("ReleaseHardware", STATUS_SUCCESS, runtime->D0Generation, runtime->InputPacketCount);
    InterlockedExchange(&runtime->ConfigurationReady, 0);
    InterlockedExchangePointer((PVOID volatile *)&runtime->InputPipeHandle, NULL);
}

void ChatpadLiveRuntimeCleanup(PCHATPAD_LIVE_RUNTIME runtime)
{
    ChatpadLiveRuntimeExitD0(runtime);
    if (runtime->VhfHandle != NULL) {
        VhfDelete(runtime->VhfHandle, TRUE);
        runtime->VhfHandle = NULL;
    }
    ChatpadLiveTrace("RuntimeCleanup", STATUS_SUCCESS, runtime->ActivationAttemptCount, runtime->InputReportCount);
}
