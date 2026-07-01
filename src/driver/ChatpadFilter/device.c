#include "driver.h"
#include "device.tmh"

static volatile LONGLONG g_ChatpadRuntimeDeviceAddAttemptSequence = 0;

static uint64_t
ChatpadAllocateDeviceAddAttemptId(
    _Out_ UCHAR *wrapped
    )
{
    LONGLONG value;

    *wrapped = 0u;
    value = InterlockedIncrement64(&g_ChatpadRuntimeDeviceAddAttemptSequence);
    if (value <= 0) {
        *wrapped = 1u;
        return 0u;
    }
    return (uint64_t)value;
}

static uint64_t
ChatpadNextDeviceTraceSequence(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context
    )
{
    context->RuntimeTraceSequence += 1u;
    return context->RuntimeTraceSequence;
}

static void
ChatpadTraceDeviceEvent(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    UCHAR level,
    ULONG flags,
    ChatpadRuntimeTraceEventId eventId,
    NTSTATUS status,
    ULONG stage,
    ULONG data0,
    ULONG data1
    )
{
    uint64_t sequence;

    sequence = ChatpadNextDeviceTraceSequence(context);
    if (flags == CHATPAD_TRACE_OWNER) {
        ChatpadTrace(level, CHATPAD_TRACE_OWNER, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_ORCHESTRATION) {
        ChatpadTrace(level, CHATPAD_TRACE_ORCHESTRATION, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_READINESS) {
        ChatpadTrace(level, CHATPAD_TRACE_READINESS, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_LIFECYCLE) {
        ChatpadTrace(level, CHATPAD_TRACE_LIFECYCLE, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_CLEANUP) {
        ChatpadTrace(level, CHATPAD_TRACE_CLEANUP, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_INVARIANT) {
        ChatpadTrace(level, CHATPAD_TRACE_INVARIANT, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else {
        ChatpadTrace(level, CHATPAD_TRACE_TERMINAL, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    }
}

static void
ChatpadTraceDeviceSnapshot(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    UCHAR level,
    ULONG flags,
    ChatpadRuntimeTraceEventId eventId,
    NTSTATUS status,
    ULONG structuralReadyResult
    )
{
    ChatpadRuntimeObjectSnapshot snapshot;

    snapshot = ChatpadRuntimeCaptureObjectSnapshot(
        &context->ActivationRequestOwner,
        structuralReadyResult);
    if (flags == CHATPAD_TRACE_OWNER) {
        ChatpadTrace(level, CHATPAD_TRACE_OWNER, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)ChatpadNextDeviceTraceSequence(context),
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            (unsigned int)snapshot.BookkeepingLockPresent,
            (unsigned int)snapshot.ReusableRequestPresent,
            (unsigned int)snapshot.OutboundMemoryPresent,
            (unsigned int)snapshot.InboundMemoryPresent,
            (unsigned int)snapshot.OwnerReady,
            (unsigned int)snapshot.Faulted,
            (unsigned int)snapshot.ObjectGraphComplete,
            snapshot.InitializationMask,
            snapshot.StructuralReadyResult);
    } else if (flags == CHATPAD_TRACE_ORCHESTRATION) {
        ChatpadTrace(level, CHATPAD_TRACE_ORCHESTRATION, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)ChatpadNextDeviceTraceSequence(context),
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            (unsigned int)snapshot.BookkeepingLockPresent,
            (unsigned int)snapshot.ReusableRequestPresent,
            (unsigned int)snapshot.OutboundMemoryPresent,
            (unsigned int)snapshot.InboundMemoryPresent,
            (unsigned int)snapshot.OwnerReady,
            (unsigned int)snapshot.Faulted,
            (unsigned int)snapshot.ObjectGraphComplete,
            snapshot.InitializationMask,
            snapshot.StructuralReadyResult);
    } else if (flags == CHATPAD_TRACE_READINESS) {
        ChatpadTrace(level, CHATPAD_TRACE_READINESS, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)ChatpadNextDeviceTraceSequence(context),
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            (unsigned int)snapshot.BookkeepingLockPresent,
            (unsigned int)snapshot.ReusableRequestPresent,
            (unsigned int)snapshot.OutboundMemoryPresent,
            (unsigned int)snapshot.InboundMemoryPresent,
            (unsigned int)snapshot.OwnerReady,
            (unsigned int)snapshot.Faulted,
            (unsigned int)snapshot.ObjectGraphComplete,
            snapshot.InitializationMask,
            snapshot.StructuralReadyResult);
    } else if (flags == CHATPAD_TRACE_CLEANUP) {
        ChatpadTrace(level, CHATPAD_TRACE_CLEANUP, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)ChatpadNextDeviceTraceSequence(context),
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            (unsigned int)snapshot.BookkeepingLockPresent,
            (unsigned int)snapshot.ReusableRequestPresent,
            (unsigned int)snapshot.OutboundMemoryPresent,
            (unsigned int)snapshot.InboundMemoryPresent,
            (unsigned int)snapshot.OwnerReady,
            (unsigned int)snapshot.Faulted,
            (unsigned int)snapshot.ObjectGraphComplete,
            snapshot.InitializationMask,
            snapshot.StructuralReadyResult);
    } else {
        ChatpadTrace(level, CHATPAD_TRACE_TERMINAL, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeAttemptId,
            (unsigned long long)ChatpadNextDeviceTraceSequence(context),
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            (unsigned int)snapshot.BookkeepingLockPresent,
            (unsigned int)snapshot.ReusableRequestPresent,
            (unsigned int)snapshot.OutboundMemoryPresent,
            (unsigned int)snapshot.InboundMemoryPresent,
            (unsigned int)snapshot.OwnerReady,
            (unsigned int)snapshot.Faulted,
            (unsigned int)snapshot.ObjectGraphComplete,
            snapshot.InitializationMask,
            snapshot.StructuralReadyResult);
    }
}

static void
ChatpadTraceDeviceTerminal(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    NTSTATUS status
    )
{
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_PROHIBITED_COUNTERS,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT,
        ChatpadRuntimeTraceEventName(
            CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT),
        (unsigned long long)context->RuntimeAttemptId,
        (unsigned long long)ChatpadNextDeviceTraceSequence(context),
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        context->RuntimeProhibitedCounters.TargetDiscovery,
        context->RuntimeProhibitedCounters.TargetOpen,
        context->RuntimeProhibitedCounters.TargetAssignment,
        context->RuntimeProhibitedCounters.RequestFormat,
        context->RuntimeProhibitedCounters.RequestReuse,
        context->RuntimeProhibitedCounters.RequestSend,
        context->RuntimeProhibitedCounters.Completion,
        context->RuntimeProhibitedCounters.Cancellation,
        context->RuntimeProhibitedCounters.ProtocolTraffic,
        context->RuntimeProhibitedCounters.KeyboardInjection,
        context->RuntimeProhibitedCounters.D0OwnerObservation,
        context->RuntimeProhibitedCounters.RemovalRundownObservation);
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_TERMINAL,
        NT_SUCCESS(status)
            ? CHATPAD_RUNTIME_EVENT_DEVICE_ADD_SUCCESS
            : CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FAILURE,
        status,
        NT_SUCCESS(status) ? 1u : 0u);
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_TERMINAL,
        CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FINAL_SUMMARY,
        status,
        NT_SUCCESS(status) ? 1u : 0u);
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_TERMINAL,
        CHATPAD_RUNTIME_EVENT_DEVICE_ADD_RETURNED_STATUS,
        status,
        0u,
        (ULONG)ChatpadRuntimeClassifyStatus(status),
        0u);
}

static void
ChatpadTracePreContextTerminal(
    uint64_t attemptId,
    NTSTATUS status
    )
{
    ChatpadRuntimeTraceEventId terminalEvent;

    terminalEvent = NT_SUCCESS(status)
        ? CHATPAD_RUNTIME_EVENT_DEVICE_ADD_SUCCESS
        : CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FAILURE;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)terminalEvent, ChatpadRuntimeTraceEventName(terminalEvent),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
        0u, (ULONG)ChatpadRuntimeClassifyStatus(status), 0u);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FINAL_SUMMARY,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FINAL_SUMMARY),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
        0u, (ULONG)ChatpadRuntimeClassifyStatus(status), 0u);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_RETURNED_STATUS,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_RETURNED_STATUS),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
        0u, (ULONG)ChatpadRuntimeClassifyStatus(status), 0u);
}

static NTSTATUS
ChatpadOrchestrationResultToStatus(
    ChatpadKmdfRequestOwnerOrchestrationResult result,
    _In_ const ChatpadKmdfRequestOwnerOrchestrationReport *report
    )
{
    switch (result) {
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK:
        return STATUS_SUCCESS;
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_OWNER:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_PARENT_DEVICE:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_REPORT:
        return STATUS_INVALID_PARAMETER;
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_SPINLOCK_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OUTBOUND_MEMORY_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INBOUND_MEMORY_FAILED:
        if (report != NULL && !NT_SUCCESS(report->FrameworkStatus)) {
            return report->FrameworkStatus;
        }
        return STATUS_INVALID_DEVICE_STATE;
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_SIGNATURE:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_UNSUPPORTED_VERSION:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_READY:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_FAULTED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PARTIAL_STATE_PRESENT:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PRE_READY_VALIDATION_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_READY_VALIDATION_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED:
    default:
        return STATUS_INVALID_DEVICE_STATE;
    }
}

static NTSTATUS
ChatpadValidateOrchestrationReadyState(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    _In_ const ChatpadKmdfRequestOwnerOrchestrationReport *report
    )
{
    ChatpadKmdfActivationRequestContext *requestContext;
    ChatpadKmdfRequestOwnerCreationResult readyValidationResult;

    if (report->ReadyPublicationAttempted == 0u ||
        report->ReadyPublished == 0u ||
        report->ObjectGraphComplete == 0u ||
        context->ActivationRequestOwner.Request == NULL) {
        return STATUS_INVALID_DEVICE_STATE;
    }

    requestContext =
        ChatpadKmdfGetActivationRequestContext(context->ActivationRequestOwner.Request);
    readyValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        &context->ActivationRequestOwner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY);
    if (readyValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return STATUS_INVALID_DEVICE_STATE;
    }
    return STATUS_SUCCESS;
}

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
    ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };
    ChatpadKmdfRequestOwnerOrchestrationResult orchestrationResult;
    uint64_t attemptId;
    UCHAR attemptWrapped;
    NTSTATUS status;

    UNREFERENCED_PARAMETER(Driver);

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilter: lifecycle scaffold EvtDeviceAdd\n"));

    attemptId = ChatpadAllocateDeviceAddAttemptId(&attemptWrapped);
    if (attemptWrapped != 0u) {
        status = STATUS_INTEGER_OVERFLOW;
        ChatpadTrace(TRACE_LEVEL_ERROR, CHATPAD_TRACE_INVARIANT,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)CHATPAD_RUNTIME_EVENT_ATTEMPT_ID_WRAPAROUND,
            ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_ATTEMPT_ID_WRAPAROUND),
            (unsigned long long)attemptId, (unsigned long long)0u,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            0u, 0u, 0u);
        ChatpadTracePreContextTerminal(attemptId, status);
        return status;
    }
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_ENTERED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_ENTERED),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, 0u, 0u);

    WdfFdoInitSetFilter(DeviceInit);

    WDF_PNPPOWER_EVENT_CALLBACKS_INIT(&pnpPowerCallbacks);
    pnpPowerCallbacks.EvtDevicePrepareHardware = ChatpadEvtDevicePrepareHardware;
    pnpPowerCallbacks.EvtDeviceReleaseHardware = ChatpadEvtDeviceReleaseHardware;
    pnpPowerCallbacks.EvtDeviceD0Entry = ChatpadEvtDeviceD0Entry;
    pnpPowerCallbacks.EvtDeviceD0Exit = ChatpadEvtDeviceD0Exit;
    WdfDeviceInitSetPnpPowerEventCallbacks(DeviceInit, &pnpPowerCallbacks);

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&objectAttributes, CHATPAD_FILTER_DEVICE_CONTEXT);
    objectAttributes.EvtCleanupCallback = ChatpadEvtDeviceContextCleanup;

    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_ATTEMPTED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_ATTEMPTED),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, 0u, 0u);
    status = WdfDeviceCreate(
        &DeviceInit,
        &objectAttributes,
        &device);
    if (!NT_SUCCESS(status)) {
        KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_ERROR_LEVEL,
            "ChatpadFilter: WdfDeviceCreate failed (0x%08X)\n",
            (unsigned int)status));
        ChatpadTrace(TRACE_LEVEL_ERROR, CHATPAD_TRACE_DEVICE_ADD,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_FAILED,
            ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_FAILED),
            (unsigned long long)attemptId, (unsigned long long)0u,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            0u, 0u, 0u);
        ChatpadTracePreContextTerminal(attemptId, status);
        return status;
    }

    context = ChatpadFilterGetDeviceContext(device);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_INITIALIZING,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_INITIALIZING),
        (unsigned long long)attemptId, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, CHATPAD_FILTER_DEVICE_CONTEXT_VERSION,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION);
    context->Signature = CHATPAD_FILTER_DEVICE_CONTEXT_SIGNATURE;
    context->Version = CHATPAD_FILTER_DEVICE_CONTEXT_VERSION;
    context->DiagnosticSequence = 0u;
    context->RuntimeAttemptId = attemptId;
    context->RuntimeTraceSequence = 0u;
    context->RuntimeTraceSchemaVersion = CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION;
    context->RuntimeCleanupObserved = 0u;
    RtlZeroMemory(
        &context->RuntimeProhibitedCounters,
        sizeof(context->RuntimeProhibitedCounters));
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_PROHIBITED_COUNTERS,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_INITIALIZED,
        ChatpadRuntimeTraceEventName(
            CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_INITIALIZED),
        (unsigned long long)context->RuntimeAttemptId,
        (unsigned long long)ChatpadNextDeviceTraceSequence(context),
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        context->RuntimeProhibitedCounters.TargetDiscovery,
        context->RuntimeProhibitedCounters.TargetOpen,
        context->RuntimeProhibitedCounters.TargetAssignment,
        context->RuntimeProhibitedCounters.RequestFormat,
        context->RuntimeProhibitedCounters.RequestReuse,
        context->RuntimeProhibitedCounters.RequestSend,
        context->RuntimeProhibitedCounters.Completion,
        context->RuntimeProhibitedCounters.Cancellation,
        context->RuntimeProhibitedCounters.ProtocolTraffic,
        context->RuntimeProhibitedCounters.KeyboardInjection,
        context->RuntimeProhibitedCounters.D0OwnerObservation,
        context->RuntimeProhibitedCounters.RemovalRundownObservation);
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_DEVICE_ADD,
        CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_READY,
        STATUS_SUCCESS,
        0u,
        context->Version,
        context->RuntimeTraceSchemaVersion);
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_DEVICE_ADD,
        CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_COMPLETED,
        STATUS_SUCCESS,
        0u,
        0u,
        0u);

    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_OWNER,
        CHATPAD_RUNTIME_EVENT_OWNER_STORAGE_INIT_STARTED,
        STATUS_SUCCESS,
        0u);
    ownerStorageResult =
        ChatpadKmdfRequestOwnerInitializeStorage(&context->ActivationRequestOwner);
    context->ActivationRequestOwner.DiagnosticAttemptId = attemptId;
    context->ActivationRequestOwner.DiagnosticTraceSequence =
        context->RuntimeTraceSequence;
    if (ownerStorageResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        status = ChatpadOwnerInitializationResultToStatus(ownerStorageResult);
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_OWNER,
            CHATPAD_RUNTIME_EVENT_OWNER_STORAGE_INIT_FAILED,
            status,
            0u,
            (ULONG)ownerStorageResult,
            0u);
        ChatpadTraceDeviceTerminal(context, status);
        return status;
    }
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_OWNER,
        CHATPAD_RUNTIME_EVENT_OWNER_STORAGE_INIT_COMPLETED,
        STATUS_SUCCESS,
        0u);

    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_OWNER,
        CHATPAD_RUNTIME_EVENT_PRE_OBJECT_VALIDATION_STARTED,
        STATUS_SUCCESS,
        0u);
    ownerValidationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
        &context->ActivationRequestOwner,
        &ownerStorageValidation);
    if (ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        status = STATUS_INVALID_DEVICE_STATE;
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_OWNER,
            CHATPAD_RUNTIME_EVENT_PRE_OBJECT_VALIDATION_FAILED,
            status,
            0u,
            (ULONG)ownerValidationResult,
            ownerStorageValidation.InvariantMask);
        ChatpadTraceDeviceTerminal(context, status);
        return STATUS_INVALID_DEVICE_STATE;
    }
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_OWNER,
        CHATPAD_RUNTIME_EVENT_PRE_OBJECT_VALIDATION_COMPLETED,
        STATUS_SUCCESS,
        0u);

    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STARTED,
        STATUS_SUCCESS,
        0u);
    orchestrationResult = ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
        device,
        &context->ActivationRequestOwner,
        &orchestrationReport);
    context->RuntimeTraceSequence =
        context->ActivationRequestOwner.DiagnosticTraceSequence;
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_RETURNED,
        orchestrationReport.FrameworkStatus,
        (ULONG)orchestrationReport.LastCompletedStage,
        (ULONG)orchestrationResult,
        (ULONG)orchestrationReport.Result);
    ChatpadTraceDeviceEvent(
        context,
        orchestrationResult == CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK
            ? TRACE_LEVEL_INFORMATION
            : TRACE_LEVEL_ERROR,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_FUNCTION_RESULT,
        orchestrationReport.FrameworkStatus,
        (ULONG)orchestrationReport.LastCompletedStage,
        (ULONG)orchestrationResult,
        0u);
    ChatpadTraceDeviceEvent(
        context,
        orchestrationReport.Result == CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK
            ? TRACE_LEVEL_INFORMATION
            : TRACE_LEVEL_ERROR,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_REPORT_RESULT,
        orchestrationReport.FrameworkStatus,
        (ULONG)orchestrationReport.LastCompletedStage,
        (ULONG)orchestrationReport.Result,
        0u);
    if (orchestrationResult != orchestrationReport.Result) {
        status = STATUS_INVALID_DEVICE_STATE;
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_FUNCTION_REPORT_MISMATCH,
            status,
            (ULONG)orchestrationReport.LastCompletedStage,
            (ULONG)orchestrationResult,
            (ULONG)orchestrationReport.Result);
        ChatpadTraceDeviceTerminal(context, status);
        return status;
    }
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_FUNCTION_REPORT_MATCHED,
        STATUS_SUCCESS,
        (ULONG)orchestrationReport.LastCompletedStage,
        (ULONG)orchestrationResult,
        0u);
    if (orchestrationResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
        status = ChatpadOrchestrationResultToStatus(
            orchestrationResult,
            &orchestrationReport);
        ChatpadTraceDeviceSnapshot(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_REPORT_SUMMARY,
            status,
            0u);
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STATUS_MAPPED,
            status,
            (ULONG)orchestrationReport.FailedStage,
            (ULONG)orchestrationResult,
            (ULONG)ChatpadRuntimeClassifyStatus(status));
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_TERMINAL_CATEGORY,
            status,
            (ULONG)orchestrationReport.FailedStage,
            (ULONG)orchestrationResult,
            (ULONG)orchestrationReport.RollbackResult);
        ChatpadTraceDeviceTerminal(context, status);
        return status;
    }
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_READY_PUBLISHED,
        STATUS_SUCCESS,
        (ULONG)orchestrationReport.LastCompletedStage,
        orchestrationReport.ReadyPublicationAttempted,
        orchestrationReport.ReadyPublished);
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_READINESS,
        CHATPAD_RUNTIME_EVENT_READY_VALIDATION_STARTED,
        STATUS_SUCCESS,
        0u);
    status = ChatpadValidateOrchestrationReadyState(context, &orchestrationReport);
    if (!NT_SUCCESS(status)) {
        ChatpadTraceDeviceSnapshot(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_READINESS,
            CHATPAD_RUNTIME_EVENT_READY_VALIDATION_FAILED,
            status,
            0u);
        if (context->ActivationRequestOwner.Request == NULL ||
            orchestrationReport.ObjectGraphComplete == 0u) {
            ChatpadTraceDeviceSnapshot(
                context,
                TRACE_LEVEL_ERROR,
                CHATPAD_TRACE_READINESS,
                CHATPAD_RUNTIME_EVENT_READY_VALIDATION_MISSING_OBJECT,
                status,
                0u);
        } else {
            ChatpadTraceDeviceSnapshot(
                context,
                TRACE_LEVEL_ERROR,
                CHATPAD_TRACE_READINESS,
                CHATPAD_RUNTIME_EVENT_READY_VALIDATION_INVARIANT_FAILED,
                status,
                0u);
        }
        ChatpadTraceDeviceTerminal(context, status);
        return status;
    }
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_READINESS,
        CHATPAD_RUNTIME_EVENT_READY_VALIDATION_PASSED,
        STATUS_SUCCESS,
        1u);

    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_LIFECYCLE,
        CHATPAD_RUNTIME_EVENT_LIFECYCLE_INIT_STARTED,
        STATUS_SUCCESS,
        0u,
        0u,
        0u);
    lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
    if (lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK) {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_INFORMATION,
            CHATPAD_TRACE_LIFECYCLE,
            CHATPAD_RUNTIME_EVENT_LIFECYCLE_INIT_PASSED,
            STATUS_SUCCESS,
            0u,
            (ULONG)lifecycleResult,
            0u);
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_INFORMATION,
            CHATPAD_TRACE_LIFECYCLE,
            CHATPAD_RUNTIME_EVENT_MARK_DEVICE_CREATED_STARTED,
            STATUS_SUCCESS,
            0u,
            0u,
            0u);
        lifecycleResult = ChatpadFilterLifecycleMarkDeviceCreated(&context->Lifecycle);
        ChatpadTraceDeviceEvent(
            context,
            lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK
                ? TRACE_LEVEL_INFORMATION
                : TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_LIFECYCLE,
            lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK
                ? CHATPAD_RUNTIME_EVENT_MARK_DEVICE_CREATED_PASSED
                : CHATPAD_RUNTIME_EVENT_MARK_DEVICE_CREATED_FAILED,
            ChatpadLifecycleResultToStatus(lifecycleResult),
            0u,
            (ULONG)lifecycleResult,
            0u);
    } else {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_LIFECYCLE,
            CHATPAD_RUNTIME_EVENT_LIFECYCLE_INIT_FAILED,
            ChatpadLifecycleResultToStatus(lifecycleResult),
            0u,
            (ULONG)lifecycleResult,
            0u);
    }

    ChatpadLogLifecycle("EvtDeviceAdd", device, lifecycleResult);
    status = ChatpadLifecycleResultToStatus(lifecycleResult);
    ChatpadTraceDeviceTerminal(context, status);
    return status;
}

_Use_decl_annotations_
void
ChatpadEvtDeviceContextCleanup(
    WDFOBJECT DeviceObject
    )
{
    PCHATPAD_FILTER_DEVICE_CONTEXT context;

    context = ChatpadFilterGetDeviceContext((WDFDEVICE)DeviceObject);
    context->RuntimeCleanupObserved = 1u;
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_ENTERED,
        STATUS_SUCCESS,
        0u,
        0u,
        0u);
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_SNAPSHOT,
        STATUS_SUCCESS,
        0u);
    if (context->RuntimeTraceSchemaVersion != CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION) {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_TRACE_SCHEMA_VERSION_MISMATCH,
            STATUS_INVALID_DEVICE_STATE,
            0u,
            context->RuntimeTraceSchemaVersion,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION);
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_CLEANUP,
            CHATPAD_RUNTIME_EVENT_CLEANUP_INVARIANT_VIOLATION,
            STATUS_INVALID_DEVICE_STATE,
            0u,
            context->RuntimeTraceSchemaVersion,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION);
    }
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_COMPLETED,
        STATUS_SUCCESS,
        0u,
        0u,
        0u);
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
