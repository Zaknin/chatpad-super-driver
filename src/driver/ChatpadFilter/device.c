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
    context->RuntimeDiagnostics.TraceSequence += 1u;
    return context->RuntimeDiagnostics.TraceSequence;
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
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_ORCHESTRATION) {
        ChatpadTrace(level, CHATPAD_TRACE_ORCHESTRATION, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_READINESS) {
        ChatpadTrace(level, CHATPAD_TRACE_READINESS, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_LIFECYCLE) {
        ChatpadTrace(level, CHATPAD_TRACE_LIFECYCLE, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_CLEANUP) {
        ChatpadTrace(level, CHATPAD_TRACE_CLEANUP, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_INVARIANT) {
        ChatpadTrace(level, CHATPAD_TRACE_INVARIANT, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence, CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else {
        ChatpadTrace(level, CHATPAD_TRACE_TERMINAL, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
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
    uint64_t sequence;

    snapshot = ChatpadRuntimeCaptureObjectSnapshot(
        &context->ActivationRequestOwner,
        structuralReadyResult);
    sequence = ChatpadNextDeviceTraceSequence(context);
    if (flags == CHATPAD_TRACE_OWNER) {
        ChatpadTrace(level, CHATPAD_TRACE_OWNER, "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence,
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
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence,
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
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence,
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
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence,
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
            (unsigned long long)context->RuntimeDiagnostics.AttemptId,
            (unsigned long long)sequence,
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

typedef enum ChatpadRuntimeDiagnosticTransition {
    CHATPAD_RUNTIME_TRANSITION_ROLLBACK_STARTED = 1,
    CHATPAD_RUNTIME_TRANSITION_ROLLBACK_COMPLETED,
    CHATPAD_RUNTIME_TRANSITION_TERMINAL_SUCCESS,
    CHATPAD_RUNTIME_TRANSITION_TERMINAL_FAILURE,
    CHATPAD_RUNTIME_TRANSITION_CLEANUP_ENTERED,
    CHATPAD_RUNTIME_TRANSITION_CLEANUP_SNAPSHOT,
    CHATPAD_RUNTIME_TRANSITION_CLEANUP_COMPLETED
} ChatpadRuntimeDiagnosticTransition;

static ChatpadRuntimeCounterSnapshot
ChatpadCaptureCounterSnapshot(
    _In_ const ChatpadRuntimeProhibitedCounters *counters
    )
{
    ChatpadRuntimeCounterSnapshot snapshot;
    ULONG index;

    RtlZeroMemory(&snapshot, sizeof(snapshot));
    for (index = 0u; index < CHATPAD_RUNTIME_COUNTER_KIND_COUNT; ++index) {
        snapshot.Value[index] = (ULONG)InterlockedCompareExchange(
            (volatile LONG *)&counters->Value[index],
            0,
            0);
    }
    snapshot.FirstTransitionMask = (ULONG)InterlockedCompareExchange(
        (volatile LONG *)&counters->FirstTransitionMask,
        0,
        0);
    snapshot.OverflowMask = (ULONG)InterlockedCompareExchange(
        (volatile LONG *)&counters->OverflowMask,
        0,
        0);
    return snapshot;
}

static void
ChatpadEmitProhibitedCounterEvent(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadRuntimeProhibitedCounterKind counterKind,
    ULONG value
    )
{
    switch (counterKind) {
    case CHATPAD_RUNTIME_COUNTER_TARGET_DISCOVERY:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_TARGET_DISCOVERY_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_TARGET_OPEN:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_TARGET_OPEN_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_TARGET_ASSIGNMENT:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_TARGET_ASSIGNMENT_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_REQUEST_FORMAT:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_REQUEST_FORMAT_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_REQUEST_REUSE:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_REQUEST_REUSE_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_REQUEST_SEND:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_REQUEST_SEND_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_COMPLETION:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_COMPLETION_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_CANCELLATION:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_CANCELLATION_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_PROTOCOL_TRAFFIC:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_PROTOCOL_TRAFFIC_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_KEYBOARD_INJECTION:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_KEYBOARD_INJECTION_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_D0_OWNER_OBSERVATION:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_D0_OWNER_OBSERVER_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    case CHATPAD_RUNTIME_COUNTER_REMOVAL_RUNDOWN:
        ChatpadTraceDeviceEvent(context, TRACE_LEVEL_ERROR, CHATPAD_TRACE_PROHIBITED_COUNTERS, CHATPAD_RUNTIME_EVENT_REMOVAL_RUNDOWN_COUNTER_NONZERO, STATUS_INVALID_DEVICE_STATE, 0u, value, 0u);
        break;
    default:
        break;
    }
}

static void
ChatpadValidateProhibitedCounters(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context
    )
{
    ChatpadRuntimeCounterSnapshot snapshot;
    ULONG index;

    snapshot = ChatpadCaptureCounterSnapshot(
        &context->RuntimeDiagnostics.ProhibitedCounters);
    for (index = 0u; index < CHATPAD_RUNTIME_COUNTER_KIND_COUNT; ++index) {
        if (snapshot.Value[index] != 0u) {
            ChatpadEmitProhibitedCounterEvent(
                context,
                (ChatpadRuntimeProhibitedCounterKind)index,
                snapshot.Value[index]);
        }
    }
}

void
ChatpadRuntimeIncrementProhibitedCounter(
    PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadRuntimeProhibitedCounterKind counterKind
    )
{
    volatile LONG *counter;
    LONG current;
    LONG updated;
    LONG mask;

    if (context == NULL ||
        counterKind < CHATPAD_RUNTIME_COUNTER_TARGET_DISCOVERY ||
        counterKind >= CHATPAD_RUNTIME_COUNTER_KIND_COUNT) {
        return;
    }

    counter = &context->RuntimeDiagnostics.ProhibitedCounters.Value[counterKind];
    mask = (LONG)(1u << (ULONG)counterKind);
    for (;;) {
        current = InterlockedCompareExchange(counter, 0, 0);
        if (current == MAXLONG) {
            InterlockedOr(
                &context->RuntimeDiagnostics.ProhibitedCounters.OverflowMask,
                mask);
            ChatpadTraceDeviceEvent(
                context,
                TRACE_LEVEL_ERROR,
                CHATPAD_TRACE_INVARIANT,
                CHATPAD_RUNTIME_EVENT_COUNTER_OVERFLOW,
                STATUS_INTEGER_OVERFLOW,
                0u,
                (ULONG)counterKind,
                (ULONG)current);
            return;
        }
        updated = current + 1;
        if (InterlockedCompareExchange(counter, updated, current) == current) {
            break;
        }
    }

    if (current == 0) {
        InterlockedOr(
            &context->RuntimeDiagnostics.ProhibitedCounters.FirstTransitionMask,
            mask);
        ChatpadEmitProhibitedCounterEvent(context, counterKind, (ULONG)updated);
    }
}

static void
ChatpadEmitCounterSnapshot(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context
    )
{
    ChatpadRuntimeCounterSnapshot snapshot;
    uint64_t sequence;

    snapshot = ChatpadCaptureCounterSnapshot(
        &context->RuntimeDiagnostics.ProhibitedCounters);
    sequence = ChatpadNextDeviceTraceSequence(context);
    context->RuntimeDiagnostics.CounterSnapshotEmitted = 1u;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_PROHIBITED_COUNTERS,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu FirstTransitionMask=0x%08X OverflowMask=0x%08X",
        (ULONG)CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT),
        (unsigned long long)context->RuntimeDiagnostics.AttemptId,
        (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_TARGET_DISCOVERY],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_TARGET_OPEN],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_TARGET_ASSIGNMENT],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_FORMAT],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_REUSE],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_SEND],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_COMPLETION],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_CANCELLATION],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_PROTOCOL_TRAFFIC],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_KEYBOARD_INJECTION],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_D0_OWNER_OBSERVATION],
        snapshot.Value[CHATPAD_RUNTIME_COUNTER_REMOVAL_RUNDOWN],
        snapshot.FirstTransitionMask,
        snapshot.OverflowMask);
}

static void
ChatpadValidateDiagnosticTransition(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadRuntimeDiagnosticTransition transition
    )
{
    ULONG violation;

    violation = 0u;
    if (context->RuntimeDiagnostics.Initialized == 0u) {
        violation |= 0x00000001u;
    }
    if ((transition == CHATPAD_RUNTIME_TRANSITION_TERMINAL_SUCCESS ||
         transition == CHATPAD_RUNTIME_TRANSITION_TERMINAL_FAILURE) &&
        context->RuntimeDiagnostics.TerminalEmitted != 0u) {
        violation |= 0x00000002u;
    }
    if (transition == CHATPAD_RUNTIME_TRANSITION_TERMINAL_SUCCESS &&
        context->RuntimeDiagnostics.FailureRecorded != 0u) {
        violation |= 0x00000004u;
    }
    if (transition == CHATPAD_RUNTIME_TRANSITION_ROLLBACK_COMPLETED &&
        context->RuntimeDiagnostics.RollbackStarted == 0u) {
        violation |= 0x00000008u;
    }
    if (transition == CHATPAD_RUNTIME_TRANSITION_CLEANUP_COMPLETED &&
        context->RuntimeDiagnostics.CleanupEntered == 0u) {
        violation |= 0x00000010u;
    }
    if (transition == CHATPAD_RUNTIME_TRANSITION_CLEANUP_ENTERED &&
        context->RuntimeDiagnostics.CleanupEntered != 0u) {
        violation |= 0x00000020u;
    }

    if (violation != 0u) {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_EVENT_SEQUENCE_GAP_DETECTED,
            STATUS_INVALID_DEVICE_STATE,
            0u,
            (ULONG)transition,
            violation);
    }

    if (transition == CHATPAD_RUNTIME_TRANSITION_ROLLBACK_STARTED) {
        context->RuntimeDiagnostics.RollbackStarted = 1u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_ROLLBACK_COMPLETED) {
        context->RuntimeDiagnostics.RollbackCompleted = 1u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_TERMINAL_FAILURE) {
        context->RuntimeDiagnostics.FailureRecorded = 1u;
        context->RuntimeDiagnostics.TerminalEmitted = 1u;
        context->RuntimeDiagnostics.TerminalSucceeded = 0u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_TERMINAL_SUCCESS) {
        context->RuntimeDiagnostics.TerminalEmitted = 1u;
        context->RuntimeDiagnostics.TerminalSucceeded = 1u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_CLEANUP_ENTERED) {
        context->RuntimeDiagnostics.CleanupEntered = 1u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_CLEANUP_SNAPSHOT) {
        context->RuntimeDiagnostics.CleanupSnapshotEmitted = 1u;
    } else if (transition == CHATPAD_RUNTIME_TRANSITION_CLEANUP_COMPLETED) {
        context->RuntimeDiagnostics.CleanupCompleted = 1u;
    }
}

static void
ChatpadTraceDeviceTerminal(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    NTSTATUS status
    )
{
    ChatpadRuntimeDiagnosticTransition transition;

    transition = NT_SUCCESS(status)
        ? CHATPAD_RUNTIME_TRANSITION_TERMINAL_SUCCESS
        : CHATPAD_RUNTIME_TRANSITION_TERMINAL_FAILURE;
    ChatpadValidateDiagnosticTransition(context, transition);
    context->RuntimeDiagnostics.TerminalStatus = status;
    ChatpadValidateProhibitedCounters(context);
    ChatpadEmitCounterSnapshot(context);
    ChatpadTraceDeviceSnapshot(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_TERMINAL,
        NT_SUCCESS(status)
            ? CHATPAD_RUNTIME_EVENT_DEVICE_ADD_SUCCESS
            : CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FAILURE,
        status,
        NT_SUCCESS(status) ? 1u : 0u);
    context->RuntimeDiagnostics.FinalSnapshotEmitted = 1u;
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
    _Inout_ ChatpadRuntimeAttemptState *attempt,
    NTSTATUS status
    )
{
    ChatpadRuntimeTraceEventId terminalEvent;
    ChatpadRuntimeStatusClass statusClass;
    uint64_t sequence;

    terminalEvent = NT_SUCCESS(status)
        ? CHATPAD_RUNTIME_EVENT_DEVICE_ADD_SUCCESS
        : CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FAILURE;
    statusClass = ChatpadRuntimeClassifyStatus(status);
    sequence = ++attempt->TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_PROHIBITED_COUNTERS,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu FirstTransitionMask=0x%08X OverflowMask=0x%08X",
        (ULONG)CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT),
        (unsigned long long)attempt->AttemptId,
        (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u);
    sequence = ++attempt->TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)terminalEvent, ChatpadRuntimeTraceEventName(terminalEvent),
        (unsigned long long)attempt->AttemptId, (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)statusClass, (ULONG)status, 0u, (ULONG)statusClass, 0u);
    sequence = ++attempt->TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FINAL_SUMMARY,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_FINAL_SUMMARY),
        (unsigned long long)attempt->AttemptId, (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)statusClass, (ULONG)status, 0u, (ULONG)statusClass, 0u);
    sequence = ++attempt->TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_TERMINAL,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_RETURNED_STATUS,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_RETURNED_STATUS),
        (unsigned long long)attempt->AttemptId, (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)statusClass, (ULONG)status, 0u, (ULONG)statusClass, 0u);
}

static NTSTATUS
ChatpadOrchestrationResultToStatus(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
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
        return STATUS_INVALID_DEVICE_STATE;
    default:
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_UNEXPECTED_STATUS_MAPPING,
            STATUS_INVALID_DEVICE_STATE,
            report != NULL ? (ULONG)report->FailedStage : 0u,
            (ULONG)result,
            report != NULL ? (ULONG)report->Result : 0u);
        return STATUS_INVALID_DEVICE_STATE;
    }
}

static UCHAR
ChatpadOrchestrationEnumsAreValid(
    ChatpadKmdfRequestOwnerOrchestrationResult result,
    _In_ const ChatpadKmdfRequestOwnerOrchestrationReport *report
    )
{
    return
        result >= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK &&
        result <= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED &&
        report->Result >= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK &&
        report->Result <= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED &&
        report->LastStageEntered >= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_NONE &&
        report->LastStageEntered <= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_ROLLBACK &&
        report->LastCompletedStage >= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_NONE &&
        report->LastCompletedStage <= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_ROLLBACK &&
        report->FailedStage >= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_NONE &&
        report->FailedStage <= CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_ROLLBACK;
}

static UCHAR
ChatpadTraceUnexpectedOrchestrationEnum(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadKmdfRequestOwnerOrchestrationResult result,
    _In_ const ChatpadKmdfRequestOwnerOrchestrationReport *report
    )
{
    if (ChatpadOrchestrationEnumsAreValid(result, report) == 0u) {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_UNEXPECTED_ENUM,
            STATUS_INVALID_DEVICE_STATE,
            (ULONG)report->LastStageEntered,
            (ULONG)result,
            (ULONG)report->Result);
        return 0u;
    }
    return 1u;
}

static void
ChatpadTraceOrchestrationReportSummary(
    _In_ PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadKmdfRequestOwnerOrchestrationResult functionResult,
    _In_ const ChatpadKmdfRequestOwnerOrchestrationReport *report,
    NTSTATUS mappedStatus
    )
{
    ChatpadRuntimeObjectSnapshot objects;
    ULONG functionReportMismatch;
    ULONG terminalStage;
    ULONG failedStage;
    ULONG terminalCategory;
    ULONG firstFailureClass;
    ULONG mappedStatusClass;
    ULONG rollbackAttempted;
    ULONG rollbackCompleted;
    ULONG structuralReady;
    ULONG readyAttempted;
    ULONG readyPublished;
    ULONG objectGraphComplete;
    ULONG finalInitializationMaskClass;
    uint64_t sequence;

    objects = ChatpadRuntimeCaptureObjectSnapshot(
        &context->ActivationRequestOwner,
        report->ReadyPublished != 0u && report->ObjectGraphComplete != 0u ? 1u : 0u);
    functionReportMismatch = functionResult != report->Result ? 1u : 0u;
    terminalStage = report->FailedStage != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_NONE
        ? (ULONG)report->FailedStage
        : (ULONG)report->LastCompletedStage;
    failedStage = (ULONG)report->FailedStage;
    if (functionReportMismatch != 0u) {
        terminalCategory = 1u;
    } else if (report->RollbackAttempted != 0u) {
        terminalCategory = 2u;
    } else if (report->CreationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        terminalCategory = 3u;
    } else if (!NT_SUCCESS(mappedStatus)) {
        terminalCategory = 4u;
    } else {
        terminalCategory = 0u;
    }
    if (report->CreationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        firstFailureClass = 1u;
    } else if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        firstFailureClass = 2u;
    } else if (report->RollbackResult != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK) {
        firstFailureClass = 3u;
    } else if (functionResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK ||
               report->Result != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
        firstFailureClass = 4u;
    } else {
        firstFailureClass = 0u;
    }
    mappedStatusClass = (ULONG)ChatpadRuntimeClassifyStatus(mappedStatus);
    rollbackAttempted = report->RollbackAttempted != 0u ? 1u : 0u;
    rollbackCompleted = report->RollbackSucceeded != 0u ? 1u : 0u;
    structuralReady = report->ReadyPublished != 0u &&
        report->ObjectGraphComplete != 0u ? 1u : 0u;
    readyAttempted = report->ReadyPublicationAttempted != 0u ? 1u : 0u;
    readyPublished = report->ReadyPublished != 0u ? 1u : 0u;
    objectGraphComplete = report->ObjectGraphComplete != 0u ? 1u : 0u;
    finalInitializationMaskClass = report->FinalInitializationMask;
    sequence = ChatpadNextDeviceTraceSequence(context);

    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_ORCHESTRATION,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu FunctionResult=%lu ReportResult=%lu FunctionReportMismatch=%lu TerminalStage=%lu FailedStage=%lu TerminalCategory=%lu FirstFailureClass=%lu MappedStatusClass=%lu RollbackAttempted=%lu RollbackCompleted=%lu SpinlockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u ReadyAttempted=%lu ReadyPublished=%lu ObjectGraphComplete=%lu StructuralReady=%lu FinalInitializationMaskClass=0x%08X",
        (ULONG)CHATPAD_RUNTIME_EVENT_ORCHESTRATION_REPORT_SUMMARY,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_ORCHESTRATION_REPORT_SUMMARY),
        (unsigned long long)context->RuntimeDiagnostics.AttemptId,
        (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)functionResult,
        (ULONG)report->Result,
        functionReportMismatch,
        terminalStage,
        failedStage,
        terminalCategory,
        firstFailureClass,
        mappedStatusClass,
        rollbackAttempted,
        rollbackCompleted,
        (unsigned int)objects.BookkeepingLockPresent,
        (unsigned int)objects.ReusableRequestPresent,
        (unsigned int)objects.OutboundMemoryPresent,
        (unsigned int)objects.InboundMemoryPresent,
        readyAttempted,
        readyPublished,
        objectGraphComplete,
        structuralReady,
        finalInitializationMaskClass);
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
    ChatpadRuntimeAttemptState attemptDiagnostics;
    uint64_t attemptId;
    uint64_t sequence;
    UCHAR attemptWrapped;
    UCHAR orchestrationEnumsValid;
    NTSTATUS mappedOrchestrationStatus;
    NTSTATUS status;

    UNREFERENCED_PARAMETER(Driver);
    RtlZeroMemory(&attemptDiagnostics, sizeof(attemptDiagnostics));
    attemptDiagnostics.Initialized = 1u;

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilter: live activation runtime EvtDeviceAdd\n"));

    attemptId = ChatpadAllocateDeviceAddAttemptId(&attemptWrapped);
    attemptDiagnostics.AttemptId = attemptId;
    if (attemptWrapped != 0u) {
        status = STATUS_INTEGER_OVERFLOW;
        sequence = ++attemptDiagnostics.TraceSequence;
        ChatpadTrace(TRACE_LEVEL_ERROR, CHATPAD_TRACE_INVARIANT,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)CHATPAD_RUNTIME_EVENT_ATTEMPT_ID_WRAPAROUND,
            ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_ATTEMPT_ID_WRAPAROUND),
            (unsigned long long)attemptId, (unsigned long long)sequence,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            0u, 0u, 0u);
        ChatpadTracePreContextTerminal(&attemptDiagnostics, status);
        return status;
    }
    sequence = ++attemptDiagnostics.TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_ADD_ENTERED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_ADD_ENTERED),
        (unsigned long long)attemptId, (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, 0u, 0u);

    WdfFdoInitSetFilter(DeviceInit);

    status = WdfDeviceInitAssignWdmIrpPreprocessCallback(
        DeviceInit,
        ChatpadLiveEvtWdmIrpPreprocess,
        IRP_MJ_INTERNAL_DEVICE_CONTROL,
        NULL,
        0);
    if (!NT_SUCCESS(status)) {
        ChatpadTracePreContextTerminal(&attemptDiagnostics, status);
        return status;
    }

    WDF_PNPPOWER_EVENT_CALLBACKS_INIT(&pnpPowerCallbacks);
    pnpPowerCallbacks.EvtDevicePrepareHardware = ChatpadEvtDevicePrepareHardware;
    pnpPowerCallbacks.EvtDeviceReleaseHardware = ChatpadEvtDeviceReleaseHardware;
    pnpPowerCallbacks.EvtDeviceD0Entry = ChatpadEvtDeviceD0Entry;
    pnpPowerCallbacks.EvtDeviceD0Exit = ChatpadEvtDeviceD0Exit;
    WdfDeviceInitSetPnpPowerEventCallbacks(DeviceInit, &pnpPowerCallbacks);

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&objectAttributes, CHATPAD_FILTER_DEVICE_CONTEXT);
    objectAttributes.EvtCleanupCallback = ChatpadEvtDeviceContextCleanup;

    sequence = ++attemptDiagnostics.TraceSequence;
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_ATTEMPTED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_ATTEMPTED),
        (unsigned long long)attemptId, (unsigned long long)sequence,
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
        sequence = ++attemptDiagnostics.TraceSequence;
        ChatpadTrace(TRACE_LEVEL_ERROR, CHATPAD_TRACE_DEVICE_ADD,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_FAILED,
            ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CREATE_FAILED),
            (unsigned long long)attemptId, (unsigned long long)sequence,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            0u, 0u, 0u);
        ChatpadTracePreContextTerminal(&attemptDiagnostics, status);
        return status;
    }

    context = ChatpadFilterGetDeviceContext(device);
    RtlCopyMemory(
        &context->RuntimeDiagnostics,
        &attemptDiagnostics,
        sizeof(context->RuntimeDiagnostics));
    sequence = ChatpadNextDeviceTraceSequence(context);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DEVICE_ADD,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_INITIALIZING,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_INITIALIZING),
        (unsigned long long)attemptId, (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, CHATPAD_FILTER_DEVICE_CONTEXT_VERSION,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION);
    context->Signature = CHATPAD_FILTER_DEVICE_CONTEXT_SIGNATURE;
    context->Version = CHATPAD_FILTER_DEVICE_CONTEXT_VERSION;
    context->DiagnosticSequence = 0u;
    context->RuntimeTraceSchemaVersion = CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION;
    RtlZeroMemory(
        &context->RuntimeDiagnostics.ProhibitedCounters,
        sizeof(context->RuntimeDiagnostics.ProhibitedCounters));
    sequence = ChatpadNextDeviceTraceSequence(context);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_PROHIBITED_COUNTERS,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu FirstTransitionMask=0x%08X OverflowMask=0x%08X",
        (ULONG)CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_INITIALIZED,
        ChatpadRuntimeTraceEventName(
            CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_INITIALIZED),
        (unsigned long long)context->RuntimeDiagnostics.AttemptId,
        (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u, 0u);
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
        context->RuntimeDiagnostics.TraceSequence;
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
    context->RuntimeDiagnostics.TraceSequence =
        context->ActivationRequestOwner.DiagnosticTraceSequence;
    if (orchestrationReport.RollbackAttempted != 0u) {
        ChatpadValidateDiagnosticTransition(
            context,
            CHATPAD_RUNTIME_TRANSITION_ROLLBACK_STARTED);
    }
    if (orchestrationReport.RollbackSucceeded != 0u) {
        ChatpadValidateDiagnosticTransition(
            context,
            CHATPAD_RUNTIME_TRANSITION_ROLLBACK_COMPLETED);
    }
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_RETURNED,
        orchestrationReport.FrameworkStatus,
        (ULONG)orchestrationReport.LastCompletedStage,
        (ULONG)orchestrationResult,
        (ULONG)orchestrationReport.Result);
    orchestrationEnumsValid = ChatpadTraceUnexpectedOrchestrationEnum(
        context,
        orchestrationResult,
        &orchestrationReport);
    mappedOrchestrationStatus = ChatpadOrchestrationResultToStatus(
        context,
        orchestrationResult,
        &orchestrationReport);
    if (orchestrationEnumsValid == 0u) {
        mappedOrchestrationStatus = STATUS_INVALID_DEVICE_STATE;
    }
    ChatpadTraceOrchestrationReportSummary(
        context,
        orchestrationResult,
        &orchestrationReport,
        mappedOrchestrationStatus);
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
    if (orchestrationEnumsValid == 0u ||
        orchestrationResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
        status = mappedOrchestrationStatus;
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
    context->RuntimeDiagnostics.StructuralReady = 1u;

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
    if (NT_SUCCESS(status)) {
        status = ChatpadLiveRuntimeInitialize(device, &context->LiveRuntime);
    }
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
    ChatpadRuntimeCounterSnapshot counters;
    ChatpadRuntimeObjectSnapshot objects;
    ULONG invariantMask;
    UCHAR duplicateCleanup;
    uint64_t sequence;

    context = ChatpadFilterGetDeviceContext((WDFDEVICE)DeviceObject);
    ChatpadLiveRuntimeCleanup(&context->LiveRuntime);
    duplicateCleanup = context->RuntimeDiagnostics.CleanupEntered;
    ChatpadValidateDiagnosticTransition(
        context,
        CHATPAD_RUNTIME_TRANSITION_CLEANUP_ENTERED);
    ChatpadTraceDeviceEvent(
        context,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_ENTERED,
        STATUS_SUCCESS,
        0u,
        0u,
        0u);
    ChatpadValidateProhibitedCounters(context);
    counters = ChatpadCaptureCounterSnapshot(
        &context->RuntimeDiagnostics.ProhibitedCounters);
    objects = ChatpadRuntimeCaptureObjectSnapshot(
        &context->ActivationRequestOwner,
        context->RuntimeDiagnostics.TerminalSucceeded);
    sequence = ChatpadNextDeviceTraceSequence(context);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_CLEANUP,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu TargetDiscovery=%lu TargetOpen=%lu TargetAssignment=%lu RequestFormat=%lu RequestReuse=%lu RequestSend=%lu Completion=%lu Cancellation=%lu ProtocolTraffic=%lu KeyboardInjection=%lu D0OwnerObservation=%lu RemovalRundownObservation=%lu FirstTransitionMask=0x%08X CounterOverflowMask=0x%08X CounterSnapshotEmitted=%u FinalSnapshotState=%u BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u StructuralReady=%u TerminalEmitted=%u TerminalSucceeded=%u TerminalStatus=0x%08X",
        (ULONG)CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_SNAPSHOT,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DEVICE_CONTEXT_CLEANUP_SNAPSHOT),
        (unsigned long long)context->RuntimeDiagnostics.AttemptId,
        (unsigned long long)sequence,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        counters.Value[CHATPAD_RUNTIME_COUNTER_TARGET_DISCOVERY],
        counters.Value[CHATPAD_RUNTIME_COUNTER_TARGET_OPEN],
        counters.Value[CHATPAD_RUNTIME_COUNTER_TARGET_ASSIGNMENT],
        counters.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_FORMAT],
        counters.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_REUSE],
        counters.Value[CHATPAD_RUNTIME_COUNTER_REQUEST_SEND],
        counters.Value[CHATPAD_RUNTIME_COUNTER_COMPLETION],
        counters.Value[CHATPAD_RUNTIME_COUNTER_CANCELLATION],
        counters.Value[CHATPAD_RUNTIME_COUNTER_PROTOCOL_TRAFFIC],
        counters.Value[CHATPAD_RUNTIME_COUNTER_KEYBOARD_INJECTION],
        counters.Value[CHATPAD_RUNTIME_COUNTER_D0_OWNER_OBSERVATION],
        counters.Value[CHATPAD_RUNTIME_COUNTER_REMOVAL_RUNDOWN],
        counters.FirstTransitionMask,
        counters.OverflowMask,
        (unsigned int)context->RuntimeDiagnostics.CounterSnapshotEmitted,
        (unsigned int)context->RuntimeDiagnostics.FinalSnapshotEmitted,
        (unsigned int)objects.BookkeepingLockPresent,
        (unsigned int)objects.ReusableRequestPresent,
        (unsigned int)objects.OutboundMemoryPresent,
        (unsigned int)objects.InboundMemoryPresent,
        (unsigned int)objects.OwnerReady,
        (unsigned int)objects.Faulted,
        (unsigned int)context->RuntimeDiagnostics.StructuralReady,
        (unsigned int)context->RuntimeDiagnostics.TerminalEmitted,
        (unsigned int)context->RuntimeDiagnostics.TerminalSucceeded,
        (ULONG)context->RuntimeDiagnostics.TerminalStatus);
    ChatpadValidateDiagnosticTransition(
        context,
        CHATPAD_RUNTIME_TRANSITION_CLEANUP_SNAPSHOT);

    invariantMask = 0u;
    if (duplicateCleanup != 0u) {
        invariantMask |= 0x00000001u;
    }
    if (context->RuntimeDiagnostics.TerminalEmitted == 0u) {
        invariantMask |= 0x00000002u;
    }
    if (context->RuntimeDiagnostics.CounterSnapshotEmitted == 0u ||
        context->RuntimeDiagnostics.FinalSnapshotEmitted == 0u) {
        invariantMask |= 0x00000004u;
    }
    if (context->RuntimeDiagnostics.RollbackStarted != 0u &&
        context->RuntimeDiagnostics.RollbackCompleted == 0u) {
        invariantMask |= 0x00000008u;
    }
    if (context->RuntimeDiagnostics.RollbackCompleted != 0u &&
        (objects.BookkeepingLockPresent != 0u ||
         objects.ReusableRequestPresent != 0u ||
         objects.OutboundMemoryPresent != 0u ||
         objects.InboundMemoryPresent != 0u)) {
        invariantMask |= 0x00000010u;
    }
    if (context->RuntimeDiagnostics.TraceSequence == 0u ||
        context->RuntimeDiagnostics.CleanupCompleted != 0u) {
        invariantMask |= 0x00000020u;
    }
    if (context->RuntimeDiagnostics.TerminalSucceeded != 0u) {
        ULONG counterIndex;
        for (counterIndex = 0u;
             counterIndex < CHATPAD_RUNTIME_COUNTER_KIND_COUNT;
             ++counterIndex) {
            if (counters.Value[counterIndex] != 0u) {
                invariantMask |= 0x00000040u;
                break;
            }
        }
    }
    if (context->RuntimeTraceSchemaVersion != CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION) {
        invariantMask |= 0x00000080u;
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_TRACE_SCHEMA_VERSION_MISMATCH,
            STATUS_INVALID_DEVICE_STATE,
            0u,
            context->RuntimeTraceSchemaVersion,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION);
    }
    if (invariantMask != 0u) {
        ChatpadTraceDeviceEvent(
            context,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_CLEANUP,
            CHATPAD_RUNTIME_EVENT_CLEANUP_INVARIANT_VIOLATION,
            STATUS_INVALID_DEVICE_STATE,
            0u,
            invariantMask,
            0u);
    }
    ChatpadValidateDiagnosticTransition(
        context,
        CHATPAD_RUNTIME_TRANSITION_CLEANUP_COMPLETED);
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
    NTSTATUS runtimeStatus;

    UNREFERENCED_PARAMETER(ResourcesRaw);
    UNREFERENCED_PARAMETER(ResourcesTranslated);

    context = ChatpadFilterGetDeviceContext(Device);
    runtimeStatus = ChatpadLiveRuntimePrepareHardware(&context->LiveRuntime);
    /* Chatpad/VHF is optional. Its degradation is diagnostic-only; only the
     * physical filter lifecycle may determine the Xbox start result. */
    UNREFERENCED_PARAMETER(runtimeStatus);
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
    ChatpadLiveRuntimeReleaseHardware(&context->LiveRuntime);
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
    if (lifecycleResult == CHATPAD_FILTER_LIFECYCLE_OK) {
        ChatpadLiveRuntimeEnterD0(&context->LiveRuntime);
    }
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
    ChatpadLiveRuntimeExitD0(&context->LiveRuntime);
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
