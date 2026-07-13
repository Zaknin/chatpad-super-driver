#include "driver.h"
#include "ChatpadControlDevice.h"
#include "ChatpadControlInterface.h"

static NTSTATUS ChatpadControlCopyOutput(
    WDFREQUEST request,
    size_t outputBufferLength,
    const void *source,
    size_t sourceLength)
{
    void *output;
    NTSTATUS status;
    if (outputBufferLength < sourceLength) return STATUS_BUFFER_TOO_SMALL;
    status = WdfRequestRetrieveOutputBuffer(request, sourceLength, &output, NULL);
    if (!NT_SUCCESS(status)) return status;
    RtlCopyMemory(output, source, sourceLength);
    WdfRequestSetInformation(request, sourceLength);
    return STATUS_SUCCESS;
}

_Use_decl_annotations_
void ChatpadControlEvtIoDeviceControl(
    WDFQUEUE queue,
    WDFREQUEST request,
    size_t outputBufferLength,
    size_t inputBufferLength,
    ULONG ioControlCode)
{
    WDFDEVICE device;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadControlStatus controlStatus;
    ChatpadControlDiagnostics diagnostics;
    ChatpadConfiguration configuration;
    const ChatpadConfiguration *input;
    ChatpadConfigurationValidationResult validation;
    NTSTATUS status;

    device = WdfIoQueueGetDevice(queue);
    context = ChatpadFilterGetDeviceContext(device);
    status = STATUS_INVALID_DEVICE_REQUEST;
    WdfRequestSetInformation(request, 0);

    switch (ioControlCode) {
    case IOCTL_CHATPAD_GET_STATUS:
        if (inputBufferLength != 0) { status = STATUS_INVALID_PARAMETER; break; }
        ChatpadLiveGetControlStatus(&context->LiveRuntime, &controlStatus);
        status = ChatpadControlCopyOutput(
            request, outputBufferLength, &controlStatus, sizeof(controlStatus));
        break;
    case IOCTL_CHATPAD_GET_CONFIGURATION:
        if (inputBufferLength != 0) { status = STATUS_INVALID_PARAMETER; break; }
        ChatpadLiveGetConfiguration(&context->LiveRuntime, &configuration);
        status = ChatpadControlCopyOutput(
            request, outputBufferLength, &configuration, sizeof(configuration));
        break;
    case IOCTL_CHATPAD_SET_CONFIGURATION:
        if (inputBufferLength != sizeof(ChatpadConfiguration) || outputBufferLength != 0) {
            status = STATUS_INFO_LENGTH_MISMATCH;
            break;
        }
        status = WdfRequestRetrieveInputBuffer(
            request, sizeof(ChatpadConfiguration), (void **)&input, NULL);
        if (!NT_SUCCESS(status)) break;
        validation = ChatpadLiveApplyConfiguration(&context->LiveRuntime, input);
        status = validation == CHATPAD_CONFIGURATION_VALID
            ? STATUS_SUCCESS
            : STATUS_INVALID_PARAMETER;
        break;
    case IOCTL_CHATPAD_RESET_CONFIGURATION:
        if (inputBufferLength != 0 || outputBufferLength != 0) {
            status = STATUS_INFO_LENGTH_MISMATCH;
            break;
        }
        ChatpadLiveResetConfiguration(&context->LiveRuntime);
        status = STATUS_SUCCESS;
        break;
    case IOCTL_CHATPAD_GET_DIAGNOSTICS:
        if (inputBufferLength != 0) { status = STATUS_INVALID_PARAMETER; break; }
        ChatpadLiveGetDiagnostics(&context->LiveRuntime, &diagnostics);
        status = ChatpadControlCopyOutput(
            request, outputBufferLength, &diagnostics, sizeof(diagnostics));
        break;
    default:
        WdfRequestFormatRequestUsingCurrentType(request);
        if (WdfRequestSend(
                request,
                WdfDeviceGetIoTarget(device),
                WDF_NO_SEND_OPTIONS)) {
            return;
        }
        status = WdfRequestGetStatus(request);
        break;
    }
    WdfRequestComplete(request, status);
}

NTSTATUS ChatpadControlCreate(WDFDEVICE device)
{
    WDF_IO_QUEUE_CONFIG queueConfig;
    WDF_OBJECT_ATTRIBUTES attributes;
    WDFQUEUE queue;
    NTSTATUS status;

    WDF_IO_QUEUE_CONFIG_INIT(&queueConfig, WdfIoQueueDispatchParallel);
    queueConfig.PowerManaged = WdfFalse;
    queueConfig.EvtIoDeviceControl = ChatpadControlEvtIoDeviceControl;
    WDF_OBJECT_ATTRIBUTES_INIT(&attributes);
    attributes.ParentObject = device;
    status = WdfIoQueueCreate(device, &queueConfig, &attributes, &queue);
    if (!NT_SUCCESS(status)) return status;
    status = WdfDeviceConfigureRequestDispatching(device, queue, WdfRequestTypeDeviceControl);
    if (!NT_SUCCESS(status)) return status;
    return WdfDeviceCreateDeviceInterface(device, &CHATPAD_CONTROL_INTERFACE_GUID, NULL);
}
