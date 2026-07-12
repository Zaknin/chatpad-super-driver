#include "driver.h"
#include "ChatpadActivationSequence.h"
#include "ChatpadKeyboardParser.h"
#include "ChatpadLiveTransferPolicy.h"
#include "ChatpadLiveRuntime.h"

#include <usb.h>
#include <usbioctl.h>

static const UCHAR ChatpadKeyboardReportDescriptor[] = {
    0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x05, 0x07,
    0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x08, 0x81, 0x02, 0x95, 0x01,
    0x75, 0x08, 0x81, 0x01, 0x95, 0x06, 0x75, 0x08,
    0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00,
    0x29, 0x65, 0x81, 0x00, 0xC0
};

static const WCHAR ChatpadSupportedHardwareId[] = L"USB\\VID_045E&PID_028E";

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
    KdPrintEx((DPFLTR_IHVDRIVER_ID, NT_SUCCESS(status) ? DPFLTR_INFO_LEVEL : DPFLTR_ERROR_LEVEL,
        "ChatpadLive: Event=%s Status=0x%08X Data0=%lu Data1=%lu\n",
        eventName, (ULONG)status, data0, data1));
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
    if (NT_SUCCESS(status)) {
        InterlockedIncrement((volatile LONG *)&runtime->InputReportCount);
    } else {
        if (InterlockedIncrement((volatile LONG *)&runtime->InputEmissionFailureCount) <= 8) {
            ChatpadLiveTrace("VhfReportRejected", status, runtime->InputPacketCount, 0u);
        }
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

static NTSTATUS ChatpadLiveConfigureInputPipe(PCHATPAD_LIVE_RUNTIME runtime)
{
    WDFUSBINTERFACE usbInterface;
    WDF_USB_PIPE_INFORMATION pipeInformation;
    UCHAR interfaceCount;

    interfaceCount = WdfUsbTargetDeviceGetNumInterfaces(runtime->UsbDevice);
    if (interfaceCount <= CHATPAD_INPUT_INTERFACE_INDEX) {
        return STATUS_DEVICE_CONFIGURATION_ERROR;
    }

    usbInterface = WdfUsbTargetDeviceGetInterface(
        runtime->UsbDevice,
        CHATPAD_INPUT_INTERFACE_INDEX);
    WDF_USB_PIPE_INFORMATION_INIT(&pipeInformation);
    runtime->InputPipe = WdfUsbInterfaceGetConfiguredPipe(
        usbInterface,
        CHATPAD_INPUT_PIPE_INDEX,
        &pipeInformation);
    if (runtime->InputPipe == NULL || !WdfUsbTargetPipeIsInEndpoint(runtime->InputPipe)) {
        runtime->InputPipe = NULL;
        return STATUS_DEVICE_CONFIGURATION_ERROR;
    }

    InterlockedExchange(&runtime->ConfigurationReady, 1);
    ChatpadLiveTrace("InputPipeReady", STATUS_SUCCESS, pipeInformation.EndpointAddress, pipeInformation.MaximumPacketSize);
    return STATUS_SUCCESS;
}

_Use_decl_annotations_
NTSTATUS ChatpadLiveEvtWdmIrpPreprocess(
    WDFDEVICE device,
    PIRP irp)
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PIO_STACK_LOCATION stack;
    PURB urb;
    WDF_USB_DEVICE_SELECT_CONFIG_PARAMS selectParams;
    NTSTATUS status;

    context = ChatpadFilterGetDeviceContext(device);
    stack = IoGetCurrentIrpStackLocation(irp);

    /*
     * xusb22 owns interface 0 and the ordinary controller path.  Reusing its
     * select-configuration URB gives KMDF the same configuration/pipe handles;
     * every other IRP is sent directly to the next-lower driver without a KMDF
     * queue transition, preserving the latency and contents of controller I/O.
     */
    if (stack->Parameters.DeviceIoControl.IoControlCode == IOCTL_INTERNAL_USB_SUBMIT_URB &&
        context->LiveRuntime.UsbDevice != NULL) {
        urb = URB_FROM_IRP(irp);
        if (urb != NULL &&
            urb->UrbHeader.Function == URB_FUNCTION_SELECT_CONFIGURATION &&
            KeGetCurrentIrql() == PASSIVE_LEVEL) {
            WDF_USB_DEVICE_SELECT_CONFIG_PARAMS_INIT_URB(&selectParams, urb);
            status = WdfUsbTargetDeviceSelectConfig(
                context->LiveRuntime.UsbDevice,
                WDF_NO_OBJECT_ATTRIBUTES,
                &selectParams);
            if (NT_SUCCESS(status)) {
                status = ChatpadLiveConfigureInputPipe(&context->LiveRuntime);
            }
            ChatpadLiveTrace("ConfigurationObserved", status, urb->UrbHeader.Function, 0u);
            irp->IoStatus.Status = status;
            irp->IoStatus.Information = 0;
            IoCompleteRequest(irp, IO_NO_INCREMENT);
            if (NT_SUCCESS(status)) {
                ChatpadLiveQueueActivationIfReady(&context->LiveRuntime);
            }
            return status;
        }
    }

    IoSkipCurrentIrpStackLocation(irp);
    return IoCallDriver(WdfDeviceWdmGetAttachedDevice(device), irp);
}

static NTSTATUS ChatpadLiveSendActivationStep(
    PCHATPAD_LIVE_RUNTIME runtime,
    const ChatpadActivationSequenceStep *step,
    PULONG bytesTransferred)
{
    WDF_USB_CONTROL_SETUP_PACKET setupPacket;
    WDF_REQUEST_SEND_OPTIONS options;
    WDF_MEMORY_DESCRIPTOR descriptor;
    WDF_MEMORY_DESCRIPTOR *descriptorPointer;
    UCHAR buffer[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH] = { 0 };
    WDF_USB_BMREQUEST_DIRECTION direction;
    NTSTATUS status;
    ChatpadLiveTransferResult transferResult;

    direction = step->Request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST
        ? BmRequestDeviceToHost
        : BmRequestHostToDevice;
    WDF_USB_CONTROL_SETUP_PACKET_INIT_VENDOR(
        &setupPacket,
        direction,
        BmRequestToDevice,
        step->Request.RawRequest,
        step->Request.RawValue,
        step->Request.RawIndex);

    descriptorPointer = NULL;
    if (step->Request.RawLength != 0) {
        if (step->Request.Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE) {
            RtlCopyMemory(buffer, step->Request.OutboundPayload, step->Request.OutboundPayloadLength);
        }
        WDF_MEMORY_DESCRIPTOR_INIT_BUFFER(&descriptor, buffer, step->Request.RawLength);
        descriptorPointer = &descriptor;
    }

    WDF_REQUEST_SEND_OPTIONS_INIT(&options, WDF_REQUEST_SEND_OPTION_TIMEOUT);
    WDF_REQUEST_SEND_OPTIONS_SET_TIMEOUT(&options, WDF_REL_TIMEOUT_IN_MS(CHATPAD_CONTROL_TIMEOUT_MS));
    *bytesTransferred = 0;
    status = WdfUsbTargetDeviceSendControlTransferSynchronously(
        runtime->UsbDevice,
        NULL,
        &options,
        &setupPacket,
        descriptorPointer,
        bytesTransferred);
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
    LARGE_INTEGER delay;
    NTSTATUS status;

    device = (WDFDEVICE)WdfWorkItemGetParentObject(workItem);
    context = ChatpadFilterGetDeviceContext(device);
    runtime = &context->LiveRuntime;
    status = STATUS_SUCCESS;
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
        status = ChatpadLiveSendActivationStep(runtime, &step, &bytesTransferred);
        runtime->LastActivationStep = (ULONG)stepIndex;
        runtime->LastBytesTransferred = bytesTransferred;
        ChatpadLiveTrace("ActivationStep", status, (ULONG)stepIndex, bytesTransferred);
        if (!NT_SUCCESS(status)) {
            break;
        }
        if (step.DelayAfterMilliseconds != 0) {
            delay.QuadPart = -((LONGLONG)step.DelayAfterMilliseconds * 10 * 1000);
            KeDelayExecutionThread(KernelMode, FALSE, &delay);
        }
    }

    runtime->LastActivationStatus = status;
    if (NT_SUCCESS(status) &&
        InterlockedCompareExchange(&runtime->StopRequested, 0, 0) == 0) {
        InterlockedExchange(&runtime->ActivationSucceeded, 1);
        InterlockedIncrement((volatile LONG *)&runtime->ActivationSuccessCount);
        ChatpadLiveTrace("ActivationCompleted", status, runtime->ActivationAttemptCount, runtime->D0Generation);
        if (InterlockedCompareExchange(&runtime->ReaderStarted, 1, 0) == 0) {
            WdfWorkItemEnqueue(runtime->InputWorkItem);
        }
    } else {
        ChatpadLiveReleaseAllKeys(runtime);
        ChatpadLiveTrace("ActivationFailed", status, runtime->LastActivationStep, runtime->LastBytesTransferred);
    }
    InterlockedExchange(&runtime->ActivationQueued, 0);
}

_Use_decl_annotations_
void ChatpadLiveEvtInputWorkItem(WDFWORKITEM workItem)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    PCHATPAD_LIVE_RUNTIME runtime;
    UCHAR bytes[32];
    WDF_MEMORY_DESCRIPTOR descriptor;
    WDF_REQUEST_SEND_OPTIONS options;
    ULONG bytesTransferred;
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
        WDF_MEMORY_DESCRIPTOR_INIT_BUFFER(&descriptor, bytes, sizeof(bytes));
        WDF_REQUEST_SEND_OPTIONS_INIT(&options, WDF_REQUEST_SEND_OPTION_TIMEOUT);
        WDF_REQUEST_SEND_OPTIONS_SET_TIMEOUT(&options, WDF_REL_TIMEOUT_IN_MS(250));
        bytesTransferred = 0;
        status = WdfUsbTargetPipeReadSynchronously(
            runtime->InputPipe,
            NULL,
            &options,
            &descriptor,
            &bytesTransferred);
        if (status == STATUS_IO_TIMEOUT || status == STATUS_TIMEOUT) {
            ChatpadLiveReleaseKeysIfNeeded(runtime);
            continue;
        }
        if (!NT_SUCCESS(status)) {
            ChatpadLiveTrace("InputReadFailed", status, bytesTransferred, 0u);
            break;
        }
        if (bytesTransferred < CHATPAD_KEYBOARD_PACKET_LENGTH) {
            InterlockedIncrement((volatile LONG *)&runtime->ParseFailureCount);
            continue;
        }
        InterlockedIncrement((volatile LONG *)&runtime->InputPacketCount);
        parseResult = ChatpadParseKeyboardPacket(bytes, CHATPAD_KEYBOARD_PACKET_LENGTH, &keyboardPacket);
        if (parseResult != CHATPAD_PARSE_OK) {
            if (InterlockedIncrement((volatile LONG *)&runtime->ParseFailureCount) <= 8) {
                ChatpadLiveTrace("DecodeRejected", STATUS_DEVICE_DATA_ERROR, (ULONG)parseResult, bytesTransferred);
            }
            ChatpadLiveReleaseKeysIfNeeded(runtime);
            continue;
        }
        if (InterlockedCompareExchange(&runtime->FirstValidInputLogged, 1, 0) == 0) {
            ChatpadLiveTrace("FirstValidInput", STATUS_SUCCESS, bytes[1], ((ULONG)bytes[2] << 8) | bytes[3]);
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
    VHF_CONFIG vhfConfig;
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
    ChatpadInitializeHidReportState(&runtime->HidState);

    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfDeviceAllocAndQueryProperty(
        device,
        DevicePropertyHardwareID,
        PagedPool,
        &attributes,
        &hardwareIdsMemory);
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
    if (!matched) {
        ChatpadLiveTrace("DeviceRejected", STATUS_NOT_SUPPORTED, (ULONG)hardwareIdsLength, 0u);
        return STATUS_NOT_SUPPORTED;
    }
    ChatpadLiveTrace("DeviceMatched", STATUS_SUCCESS, 0x045Eu, 0x028Eu);

    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfSpinLockCreate(&attributes, &runtime->StateLock);
    if (!NT_SUCCESS(status)) {
        return status;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtActivationWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    attributes.ExecutionLevel = WdfExecutionLevelPassive;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->ActivationWorkItem);
    if (!NT_SUCCESS(status)) {
        return status;
    }

    WDF_WORKITEM_CONFIG_INIT(&workItemConfig, ChatpadLiveEvtInputWorkItem);
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    attributes.ExecutionLevel = WdfExecutionLevelPassive;
    status = WdfWorkItemCreate(&workItemConfig, &attributes, &runtime->InputWorkItem);
    if (!NT_SUCCESS(status)) {
        return status;
    }

    VHF_CONFIG_INIT(
        &vhfConfig,
        WdfDeviceWdmGetDeviceObject(device),
        (USHORT)sizeof(ChatpadKeyboardReportDescriptor),
        (PUCHAR)ChatpadKeyboardReportDescriptor);
    vhfConfig.VendorID = 0x045E;
    vhfConfig.ProductID = 0x028E;
    vhfConfig.VersionNumber = 0x0101;
    status = VhfCreate(&vhfConfig, &runtime->VhfHandle);
    if (!NT_SUCCESS(status)) {
        return status;
    }
    status = VhfStart(runtime->VhfHandle);
    ChatpadLiveTrace("RuntimeInitialized", status, 0u, 0u);
    return status;
}

NTSTATUS ChatpadLiveRuntimePrepareHardware(PCHATPAD_LIVE_RUNTIME runtime)
{
    NTSTATUS status;
    InterlockedExchange(&runtime->StopRequested, 0);
    ChatpadLiveTrace("PrepareHardware", STATUS_SUCCESS, runtime->D0Generation, 0u);
    if (runtime->UsbDevice == NULL) {
        status = WdfUsbTargetDeviceCreate(
            runtime->Device,
            WDF_NO_OBJECT_ATTRIBUTES,
            &runtime->UsbDevice);
        ChatpadLiveTrace("UsbTargetCreated", status, 0u, 0u);
        return status;
    }
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
    ChatpadLiveTrace("D0Entry", STATUS_SUCCESS, runtime->D0Generation, runtime->ConfigurationReady);
    ChatpadLiveQueueActivationIfReady(runtime);
}

void ChatpadLiveRuntimeExitD0(PCHATPAD_LIVE_RUNTIME runtime)
{
    InterlockedExchange(&runtime->StopRequested, 1);
    InterlockedExchange(&runtime->InD0, 0);
    ChatpadLiveTrace("D0ExitCancellation", STATUS_CANCELLED, runtime->D0Generation, runtime->ActivationQueued);
    if (runtime->ActivationWorkItem != NULL) {
        WdfWorkItemFlush(runtime->ActivationWorkItem);
    }
    if (runtime->InputWorkItem != NULL) {
        WdfWorkItemFlush(runtime->InputWorkItem);
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
    runtime->InputPipe = NULL;
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
