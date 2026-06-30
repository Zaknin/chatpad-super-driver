#include "driver.h"

static NTSTATUS
ChatpadOwnerInitializationResultToStatus(
    ChatpadKmdfRequestOwnerStorageResult result
    )
{
    switch (result) {
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK:
        return STATUS_SUCCESS;
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION:
        return STATUS_INVALID_PARAMETER;
    default:
        return STATUS_INVALID_DEVICE_STATE;
    }
}

static NTSTATUS
ChatpadLifecycleResultToStatus(
    ChatpadFilterLifecycleResult result
    )
{
    switch (result) {
    case CHATPAD_FILTER_LIFECYCLE_OK:
        return STATUS_SUCCESS;
    case CHATPAD_FILTER_LIFECYCLE_NULL_STATE:
    case CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT:
    case CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID:
    case CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION:
        return STATUS_INVALID_PARAMETER;
    case CHATPAD_FILTER_LIFECYCLE_GENERATION_EXHAUSTED:
    case CHATPAD_FILTER_LIFECYCLE_OUTSTANDING_OVERFLOW:
        return STATUS_INTEGER_OVERFLOW;
    case CHATPAD_FILTER_LIFECYCLE_RUNDOWN_INCOMPLETE:
    case CHATPAD_FILTER_LIFECYCLE_ADMISSION_CLOSED:
        return STATUS_DEVICE_BUSY;
    case CHATPAD_FILTER_LIFECYCLE_NOT_MARKED:
    case CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE:
    case CHATPAD_FILTER_LIFECYCLE_NO_OUTSTANDING_OPERATION:
    default:
        return STATUS_INVALID_DEVICE_STATE;
    }
}

static void
ChatpadLogLifecycle(
    _In_z_ const char *callbackName,
    _In_ WDFDEVICE Device,
    _In_ ChatpadFilterLifecycleResult result
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadFilterLifecycleSnapshot snapshot;
    ChatpadFilterLifecycleResult snapshotResult;

    context = ChatpadFilterGetDeviceContext(Device);
    context->DiagnosticSequence += 1u;
    UNREFERENCED_PARAMETER(callbackName);
    UNREFERENCED_PARAMETER(result);

    snapshotResult = ChatpadFilterLifecycleGetSnapshot(&context->Lifecycle, &snapshot);
    if (snapshotResult != CHATPAD_FILTER_LIFECYCLE_OK) {
        snapshot.Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET;
        snapshot.CurrentGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
        snapshot.NextGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
        snapshot.OutstandingOperationCount = 0u;
        snapshot.OperationAdmissionOpen = 0u;
    }

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilterLifecycle: sequence=%lu callback=%s phase=%lu generation=%llu nextGeneration=%llu outstanding=%lu admission=%u result=%lu\n",
        context->DiagnosticSequence,
        callbackName,
        (unsigned long)snapshot.Phase,
        (unsigned long long)snapshot.CurrentGeneration,
        (unsigned long long)snapshot.NextGeneration,
        (unsigned long)snapshot.OutstandingOperationCount,
        (unsigned int)snapshot.OperationAdmissionOpen,
        (unsigned long)result));
}

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDeviceAdd(
    WDFDRIVER Driver,
    PWDFDEVICE_INIT DeviceInit
    )
{
    WDFDEVICE device;
    WDF_OBJECT_ATTRIBUTES objectAttributes;
    WDF_PNPPOWER_EVENT_CALLBACKS pnpPowerCallbacks;
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadKmdfRequestOwnerStorageResult ownerStorageResult;
    ChatpadKmdfRequestOwnerStorageValidation ownerStorageValidation;
    ChatpadKmdfRequestOwnerStorageResult ownerValidationResult;
    ChatpadFilterLifecycleResult lifecycleResult;
    NTSTATUS status;

    UNREFERENCED_PARAMETER(Driver);

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilter: lifecycle scaffold EvtDeviceAdd\n"));

    WdfFdoInitSetFilter(DeviceInit);

    WDF_PNPPOWER_EVENT_CALLBACKS_INIT(&pnpPowerCallbacks);
    pnpPowerCallbacks.EvtDevicePrepareHardware = ChatpadEvtDevicePrepareHardware;
    pnpPowerCallbacks.EvtDeviceReleaseHardware = ChatpadEvtDeviceReleaseHardware;
    pnpPowerCallbacks.EvtDeviceD0Entry = ChatpadEvtDeviceD0Entry;
    pnpPowerCallbacks.EvtDeviceD0Exit = ChatpadEvtDeviceD0Exit;
    WdfDeviceInitSetPnpPowerEventCallbacks(DeviceInit, &pnpPowerCallbacks);

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&objectAttributes, CHATPAD_FILTER_DEVICE_CONTEXT);

    status = WdfDeviceCreate(
        &DeviceInit,
        &objectAttributes,
        &device);
    if (!NT_SUCCESS(status)) {
        KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_ERROR_LEVEL,
            "ChatpadFilter: WdfDeviceCreate failed (0x%08X)\n",
            (unsigned int)status));
        return status;
    }

    context = ChatpadFilterGetDeviceContext(device);
    context->Signature = CHATPAD_FILTER_DEVICE_CONTEXT_SIGNATURE;
    context->Version = CHATPAD_FILTER_DEVICE_CONTEXT_VERSION;
    context->DiagnosticSequence = 0u;

    ownerStorageResult =
        ChatpadKmdfRequestOwnerInitializeStorage(&context->ActivationRequestOwner);
    if (ownerStorageResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        return ChatpadOwnerInitializationResultToStatus(ownerStorageResult);
    }

    ownerValidationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
        &context->ActivationRequestOwner,
        &ownerStorageValidation);
    if (ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        return STATUS_INVALID_DEVICE_STATE;
    }

    lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
    if (lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK) {
        lifecycleResult = ChatpadFilterLifecycleMarkDeviceCreated(&context->Lifecycle);
    }

    ChatpadLogLifecycle("EvtDeviceAdd", device, lifecycleResult);
    return ChatpadLifecycleResultToStatus(lifecycleResult);
}

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDevicePrepareHardware(
    WDFDEVICE Device,
    WDFCMRESLIST ResourcesRaw,
    WDFCMRESLIST ResourcesTranslated
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadFilterLifecycleResult lifecycleResult;

    UNREFERENCED_PARAMETER(ResourcesRaw);
    UNREFERENCED_PARAMETER(ResourcesTranslated);

    context = ChatpadFilterGetDeviceContext(Device);
    lifecycleResult = ChatpadFilterLifecyclePrepareHardware(&context->Lifecycle);
    ChatpadLogLifecycle("EvtDevicePrepareHardware", Device, lifecycleResult);
    return ChatpadLifecycleResultToStatus(lifecycleResult);
}

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDeviceReleaseHardware(
    WDFDEVICE Device,
    WDFCMRESLIST ResourcesTranslated
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadFilterLifecycleResult lifecycleResult;

    UNREFERENCED_PARAMETER(ResourcesTranslated);

    context = ChatpadFilterGetDeviceContext(Device);
    lifecycleResult = ChatpadFilterLifecycleReleaseHardware(&context->Lifecycle);
    ChatpadLogLifecycle("EvtDeviceReleaseHardware", Device, lifecycleResult);
    return ChatpadLifecycleResultToStatus(lifecycleResult);
}

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDeviceD0Entry(
    WDFDEVICE Device,
    WDF_POWER_DEVICE_STATE PreviousState
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadFilterLifecycleResult lifecycleResult;
    uint64_t generation;

    UNREFERENCED_PARAMETER(PreviousState);

    context = ChatpadFilterGetDeviceContext(Device);
    lifecycleResult = ChatpadFilterLifecycleEnterD0(&context->Lifecycle, &generation);
    ChatpadLogLifecycle("EvtDeviceD0Entry", Device, lifecycleResult);
    return ChatpadLifecycleResultToStatus(lifecycleResult);
}

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDeviceD0Exit(
    WDFDEVICE Device,
    WDF_POWER_DEVICE_STATE TargetState
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;
    ChatpadFilterLifecycleSnapshot snapshot;
    ChatpadFilterLifecycleResult lifecycleResult;
    uint64_t generation;

    UNREFERENCED_PARAMETER(TargetState);

    context = ChatpadFilterGetDeviceContext(Device);
    lifecycleResult = ChatpadFilterLifecycleGetSnapshot(&context->Lifecycle, &snapshot);
    if (lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK) {
        generation = snapshot.CurrentGeneration;
        lifecycleResult = ChatpadFilterLifecycleBeginD0Rundown(&context->Lifecycle, generation);
        if (lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK) {
            lifecycleResult = ChatpadFilterLifecycleCompleteD0Exit(&context->Lifecycle, generation);
        }
    }

    ChatpadLogLifecycle("EvtDeviceD0Exit", Device, lifecycleResult);
    return ChatpadLifecycleResultToStatus(lifecycleResult);
}
