#include "ChatpadKmdfRequestOwnerContext.h"
#include "ChatpadRuntimeDiagnostics.h"
#include "ChatpadKmdfRequestOwnerContext.tmh"

C_ASSERT(CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY == 2u);
C_ASSERT(CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY == 2u);
C_ASSERT(CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH == CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY);
C_ASSERT(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT == 6u);
C_ASSERT(CHATPAD_KMDF_ACTIVATION_MAX_STEP_INDEX == 5u);
C_ASSERT(sizeof(ChatpadActivationRequestOwner) != 0u);
C_ASSERT(sizeof(ChatpadKmdfActivationRequestOwner) != 0u);
C_ASSERT(sizeof(ChatpadKmdfActivationRequestContext) != 0u);
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->Model) ==
    sizeof(ChatpadActivationRequestOwner));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->OperationToken) ==
    sizeof(ChatpadTransportOperationToken));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->LifecycleGeneration) >=
    sizeof(((ChatpadTransportOperationToken *)0)->DeviceGeneration));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->ActivationStepIndex) >=
    sizeof(uint32_t));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->TransferLength) >=
    sizeof(uint16_t));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->ExpectedInboundLength) >=
    sizeof(uint16_t));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->TransferStorage.OutboundBytes) ==
    CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY);
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->TransferStorage.InboundBytes) ==
    CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY);
C_ASSERT(FIELD_OFFSET(ChatpadKmdfActivationTransferStorage, OutboundBytes) !=
    FIELD_OFFSET(ChatpadKmdfActivationTransferStorage, InboundBytes));
C_ASSERT(sizeof(((ChatpadKmdfActivationCompletionSnapshot *)0)->CapturedInboundBytes) ==
    CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY);
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->Request) == sizeof(WDFREQUEST));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->OutboundMemory) == sizeof(WDFMEMORY));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->InboundMemory) == sizeof(WDFMEMORY));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->BookkeepingLock) == sizeof(WDFSPINLOCK));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->ActiveTransferMemory) == sizeof(WDFMEMORY));
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY >
    CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING !=
    CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_SIGNATURE !=
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_PRE_OBJECT_READY);

#define CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK \
    (CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED)

#define CHATPAD_KMDF_REQUEST_OWNER_PRE_OBJECT_INIT_MASK \
    CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY

#define CHATPAD_KMDF_REQUEST_OWNER_CREATED_INIT_MASK \
    (CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED)

#define CHATPAD_KMDF_REQUEST_OWNER_ROLLED_BACK_INIT_MASK \
    (CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY | \
     CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED)

static void
ChatpadKmdfTraceOwnerEvent(
    ChatpadKmdfActivationRequestOwner *owner,
    UCHAR level,
    ULONG flags,
    ChatpadRuntimeTraceEventId eventId,
    NTSTATUS status,
    ULONG stage,
    ULONG data0,
    ULONG data1
    )
{
    uint64_t attemptId;
    uint64_t sequence;

    attemptId = owner != NULL ? owner->DiagnosticAttemptId : 0u;
    sequence = ChatpadRuntimeNextOwnerSequence(owner);
    if (flags == CHATPAD_TRACE_CLEANUP) {
        ChatpadTrace(level, CHATPAD_TRACE_CLEANUP,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)attemptId, (unsigned long long)sequence,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else if (flags == CHATPAD_TRACE_INVARIANT) {
        ChatpadTrace(level, CHATPAD_TRACE_INVARIANT,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)attemptId, (unsigned long long)sequence,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    } else {
        ChatpadTrace(level, CHATPAD_TRACE_ORCHESTRATION,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)attemptId, (unsigned long long)sequence,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            stage, data0, data1);
    }
}

static void
ChatpadKmdfTraceOwnerSnapshot(
    ChatpadKmdfActivationRequestOwner *owner,
    UCHAR level,
    ULONG flags,
    ChatpadRuntimeTraceEventId eventId,
    NTSTATUS status,
    ULONG structuralReadyResult
    )
{
    ChatpadRuntimeObjectSnapshot snapshot;

    snapshot = ChatpadRuntimeCaptureObjectSnapshot(owner, structuralReadyResult);
    if (flags == CHATPAD_TRACE_CLEANUP) {
        ChatpadTrace(level, CHATPAD_TRACE_CLEANUP,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)(owner != NULL ? owner->DiagnosticAttemptId : 0u),
            (unsigned long long)ChatpadRuntimeNextOwnerSequence(owner),
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
        ChatpadTrace(level, CHATPAD_TRACE_ORCHESTRATION,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X BookkeepingLockPresent=%u ReusableRequestPresent=%u OutboundMemoryPresent=%u InboundMemoryPresent=%u OwnerReady=%u Faulted=%u ObjectGraphComplete=%u InitializationMask=0x%08X StructuralReadyResult=%lu",
            (ULONG)eventId, ChatpadRuntimeTraceEventName(eventId),
            (unsigned long long)(owner != NULL ? owner->DiagnosticAttemptId : 0u),
            (unsigned long long)ChatpadRuntimeNextOwnerSequence(owner),
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

static int ChatpadKmdfRequestOwnerModelIsMarked(
    const ChatpadActivationRequestOwner *model)
{
    return model != NULL &&
        model->Signature == CHATPAD_REQUEST_OWNER_SIGNATURE &&
        model->Version == CHATPAD_REQUEST_OWNER_VERSION;
}

static int ChatpadKmdfRequestOwnerModelHasActiveOperationOrLifecycle(
    const ChatpadActivationRequestOwner *model)
{
    if (!ChatpadKmdfRequestOwnerModelIsMarked(model)) {
        return 0;
    }

    return
        model->State >= CHATPAD_REQUEST_OWNER_STATE_PREPARING ||
        model->LifecycleGeneration != CHATPAD_REQUEST_OWNER_INVALID_GENERATION ||
        model->OperationToken.DeviceGeneration != CHATPAD_REQUEST_OWNER_INVALID_GENERATION ||
        model->OperationToken.OperationSequence != CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE ||
        model->ActivationStepIndex != CHATPAD_REQUEST_OWNER_INVALID_STEP ||
        model->OperationActive != 0u ||
        model->LifecycleObligationHeld != 0u ||
        model->SubmissionPublished != 0u ||
        model->SendAccepted != 0u ||
        model->CompletionObserved != 0u ||
        model->CancellationRequested != 0u ||
        model->CancellationCallPublished != 0u ||
        model->SendCallPinned != 0u ||
        model->CancelCallPinned != 0u ||
        model->TerminalProcessed != 0u ||
        model->SequenceAdvanceEligible != 0u ||
        model->ReleaseEffectEmitted != 0u ||
        model->StaleCompletionObserved != 0u;
}

static int ChatpadKmdfRequestOwnerHasFrameworkHandle(
    const ChatpadKmdfActivationRequestOwner *owner)
{
    return owner->Request != NULL ||
        owner->OutboundMemory != NULL ||
        owner->InboundMemory != NULL ||
        owner->BookkeepingLock != NULL;
}

static int ChatpadKmdfRequestOwnerTransferStorageIsZero(
    const ChatpadKmdfActivationTransferStorage *storage)
{
    size_t index;

    for (index = 0u; index < CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY; ++index) {
        if (storage->OutboundBytes[index] != 0u) {
            return 0;
        }
    }
    for (index = 0u; index < CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY; ++index) {
        if (storage->InboundBytes[index] != 0u) {
            return 0;
        }
    }
    return 1;
}

static int ChatpadKmdfRequestOwnerCompletionSnapshotIsZero(
    const ChatpadKmdfActivationCompletionSnapshot *snapshot)
{
    size_t index;

    if (snapshot->IoStatus != STATUS_SUCCESS ||
        snapshot->UsbStatus != 0u ||
        snapshot->TransferredLength != 0u ||
        snapshot->CapturedInboundLength != 0u ||
        snapshot->CompletionClass != CHATPAD_REQUEST_OWNER_COMPLETION_NONE) {
        return 0;
    }
    for (index = 0u; index < CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY; ++index) {
        if (snapshot->CapturedInboundBytes[index] != 0u) {
            return 0;
        }
    }
    return 1;
}

static int ChatpadKmdfRequestOwnerSnapshotIsPreObjectBaseline(
    const ChatpadRequestOwnerSnapshot *snapshot)
{
    return snapshot->State == CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE &&
        snapshot->LifecycleGeneration == CHATPAD_REQUEST_OWNER_INVALID_GENERATION &&
        snapshot->OperationToken.DeviceGeneration == CHATPAD_REQUEST_OWNER_INVALID_GENERATION &&
        snapshot->OperationToken.OperationSequence == CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE &&
        snapshot->ActivationStepIndex == CHATPAD_REQUEST_OWNER_INVALID_STEP &&
        snapshot->TransitionCount == 0u &&
        snapshot->TerminalClass == CHATPAD_REQUEST_OWNER_COMPLETION_NONE &&
        snapshot->RetirementOwner == CHATPAD_REQUEST_OWNER_RETIREMENT_NONE &&
        snapshot->Available == 0u &&
        snapshot->DrainingRequested == 0u &&
        snapshot->OperationActive == 0u &&
        snapshot->LifecycleObligationHeld == 0u &&
        snapshot->SubmissionPublished == 0u &&
        snapshot->SendAccepted == 0u &&
        snapshot->CompletionObserved == 0u &&
        snapshot->CancellationRequested == 0u &&
        snapshot->CancellationCallPublished == 0u &&
        snapshot->SendCallPinned == 0u &&
        snapshot->CancelCallPinned == 0u &&
        snapshot->TerminalProcessed == 0u &&
        snapshot->SequenceAdvanceEligible == 0u &&
        snapshot->ReuseEligible == 0u &&
        snapshot->ReleaseEffectEmitted == 0u &&
        snapshot->StaleCompletionObserved == 0u;
}

static ChatpadKmdfRequestOwnerStorageResult ChatpadKmdfRequestOwnerSetValidationResult(
    ChatpadKmdfRequestOwnerStorageValidation *validation,
    ChatpadKmdfRequestOwnerStorageResult result)
{
    validation->Result = result;
    return result;
}

ChatpadKmdfRequestOwnerStorageResult ChatpadKmdfRequestOwnerValidatePreObjectState(
    const ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerStorageValidation *validation)
{
    ChatpadRequestOwnerResult snapshotResult;

    if (validation == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION;
    }

    RtlZeroMemory(validation, sizeof(*validation));
    validation->ModelInvariantResult = CHATPAD_REQUEST_OWNER_INVARIANT_NULL_OWNER;
    validation->ModelSnapshot.State = CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE;
    validation->ModelSnapshot.ActivationStepIndex = CHATPAD_REQUEST_OWNER_INVALID_STEP;

    if (owner == NULL) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER);
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_SIGNATURE);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_SIGNATURE;

    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_UNSUPPORTED_VERSION);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_VERSION;

    if ((owner->InitializationMask & ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_INITIALIZATION_MASK);
    }

    if ((owner->InitializationMask & CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OWNER_READY_PREMATURE);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NOT_OWNER_READY;

    if (owner->InitializationMask != CHATPAD_KMDF_REQUEST_OWNER_PRE_OBJECT_INIT_MASK) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_INITIALIZATION_MASK);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MASK;
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_READY;

    if (ChatpadKmdfRequestOwnerHasFrameworkHandle(owner)) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_FRAMEWORK_HANDLE_PRESENT);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NO_FRAMEWORK_HANDLES;

    if (!ChatpadKmdfRequestOwnerTransferStorageIsZero(&owner->TransferStorage)) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_TRANSFER_STORAGE);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_TRANSFER_STORAGE;

    if (!ChatpadKmdfRequestOwnerCompletionSnapshotIsZero(&owner->CompletionSnapshot)) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_COMPLETION_SNAPSHOT);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_COMPLETION_SNAPSHOT;

    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_CAPACITY;

    validation->ModelInvariantResult = ChatpadRequestOwnerValidateInvariant(&owner->Model);
    if (validation->ModelInvariantResult != CHATPAD_REQUEST_OWNER_INVARIANT_OK) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_MODEL_STATE);
    }

    snapshotResult = ChatpadRequestOwnerGetSnapshot(
        &owner->Model,
        &validation->ModelSnapshot);
    if (snapshotResult != CHATPAD_REQUEST_OWNER_OK) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_MODEL_STATE);
    }
    if (ChatpadKmdfRequestOwnerModelHasActiveOperationOrLifecycle(&owner->Model)) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ACTIVE_OPERATION_OR_LIFECYCLE);
    }
    if (!ChatpadKmdfRequestOwnerSnapshotIsPreObjectBaseline(&validation->ModelSnapshot)) {
        return ChatpadKmdfRequestOwnerSetValidationResult(
            validation,
            CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_MODEL_STATE);
    }
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_BASELINE;
    validation->InvariantMask |= CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_PRE_OBJECT_READY;

    return ChatpadKmdfRequestOwnerSetValidationResult(
        validation,
        CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK);
}

ChatpadKmdfRequestOwnerStorageResult ChatpadKmdfRequestOwnerInitializeStorage(
    ChatpadKmdfActivationRequestOwner *owner)
{
    ChatpadRequestOwnerResult modelResult;
    ChatpadKmdfRequestOwnerStorageValidation validation;
    ChatpadKmdfRequestOwnerStorageResult validationResult;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER;
    }
    if (ChatpadKmdfRequestOwnerHasFrameworkHandle(owner)) {
        return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_FRAMEWORK_HANDLE_PRESENT;
    }
    if (ChatpadKmdfRequestOwnerModelHasActiveOperationOrLifecycle(&owner->Model)) {
        return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ACTIVE_OPERATION_OR_LIFECYCLE;
    }
    if (owner->Signature == CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE &&
        owner->Version == CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        if ((owner->InitializationMask & ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
            return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_INITIALIZATION_MASK;
        }
        if ((owner->InitializationMask & CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u) {
            return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OWNER_READY_PREMATURE;
        }
        if (owner->InitializationMask != CHATPAD_KMDF_REQUEST_OWNER_INIT_NONE) {
            return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ALREADY_INITIALIZED;
        }
    }

    RtlZeroMemory(owner, sizeof(*owner));
    owner->Signature = CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE;
    owner->Version = CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION;
    owner->InitializationMask = CHATPAD_KMDF_REQUEST_OWNER_INIT_NONE;
    owner->Request = NULL;
    owner->OutboundMemory = NULL;
    owner->InboundMemory = NULL;
    owner->BookkeepingLock = NULL;
    RtlZeroMemory(&owner->TransferStorage, sizeof(owner->TransferStorage));
    RtlZeroMemory(&owner->CompletionSnapshot, sizeof(owner->CompletionSnapshot));

    modelResult = ChatpadRequestOwnerInitialize(&owner->Model);
    if (modelResult != CHATPAD_REQUEST_OWNER_OK) {
        owner->InitializationMask = CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED;
        return CHATPAD_KMDF_REQUEST_OWNER_STORAGE_MODEL_INITIALIZATION_FAILED;
    }

    owner->InitializationMask = CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY;
    validationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
        owner,
        &validation);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        owner->InitializationMask = CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED;
    }
    return validationResult;
}

static ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerValidateDeviceAttributeArguments(
    WDFDEVICE device,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    if (attributes == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_ATTRIBUTES;
    }
    if (device == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_DEVICE_PARENT;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK;
}

static ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerValidateRequestAttributeArguments(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    if (attributes == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_ATTRIBUTES;
    }
    if (request == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_REQUEST_PARENT;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK;
}

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes(
    WDFDEVICE device,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    ChatpadKmdfRequestOwnerAttributeResult result;

    result = ChatpadKmdfRequestOwnerValidateDeviceAttributeArguments(
        device,
        attributes);
    if (result != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return result;
    }

    WDF_OBJECT_ATTRIBUTES_INIT(attributes);
    attributes->ParentObject = device;
    attributes->SynchronizationScope = WdfSynchronizationScopeNone;
    return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK;
}

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes(
    WDFDEVICE device,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    ChatpadKmdfRequestOwnerAttributeResult result;

    result = ChatpadKmdfRequestOwnerValidateDeviceAttributeArguments(
        device,
        attributes);
    if (result != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return result;
    }

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(
        attributes,
        ChatpadKmdfActivationRequestContext);
    attributes->ParentObject = device;
    attributes->SynchronizationScope = WdfSynchronizationScopeNone;
    return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK;
}

static ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareMemoryAttributes(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    ChatpadKmdfRequestOwnerAttributeResult result;

    result = ChatpadKmdfRequestOwnerValidateRequestAttributeArguments(
        request,
        attributes);
    if (result != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return result;
    }

    WDF_OBJECT_ATTRIBUTES_INIT(attributes);
    attributes->ParentObject = request;
    attributes->SynchronizationScope = WdfSynchronizationScopeNone;
    return CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK;
}

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    return ChatpadKmdfRequestOwnerPrepareMemoryAttributes(
        request,
        attributes);
}

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    return ChatpadKmdfRequestOwnerPrepareMemoryAttributes(
        request,
        attributes);
}

static int ChatpadKmdfRequestOwnerBufferIsZero(
    const void *buffer,
    size_t length)
{
    const uint8_t *bytes;
    size_t index;

    bytes = (const uint8_t *)buffer;
    for (index = 0u; index < length; ++index) {
        if (bytes[index] != 0u) {
            return 0;
        }
    }
    return 1;
}

static int ChatpadKmdfRequestOwnerBackingCapacityIsExact(
    size_t arraySize,
    size_t declaredCapacity)
{
    return arraySize == 2u &&
        declaredCapacity == 2u &&
        arraySize == declaredCapacity;
}

static void ChatpadKmdfRequestOwnerInitializeDormantRequestContext(
    ChatpadKmdfActivationRequestContext *requestContext,
    ChatpadKmdfActivationRequestOwner *owner)
{
    RtlZeroMemory(requestContext, sizeof(*requestContext));
    requestContext->Owner = owner;
    requestContext->OperationToken.DeviceGeneration =
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    requestContext->OperationToken.OperationSequence =
        CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE;
    requestContext->LifecycleGeneration =
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    requestContext->ActivationStepIndex =
        CHATPAD_REQUEST_OWNER_INVALID_STEP;
    requestContext->DataDirection =
        CHATPAD_CONTROL_DATA_DIRECTION_NONE;
    requestContext->TransferDirection =
        CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_NONE;
    requestContext->TransferLength = 0u;
    requestContext->ExpectedInboundLength = 0u;
    requestContext->ActiveTransferMemory = NULL;
    RtlZeroMemory(
        &requestContext->SetupPacket,
        sizeof(requestContext->SetupPacket));
    RtlZeroMemory(
        &requestContext->CompletionSnapshot,
        sizeof(requestContext->CompletionSnapshot));
    requestContext->CompletionSnapshot.CompletionClass =
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE;
}

static int ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
    const ChatpadKmdfActivationRequestContext *requestContext,
    const ChatpadKmdfActivationRequestOwner *owner)
{
    return requestContext != NULL &&
        requestContext->Owner == owner &&
        requestContext->OperationToken.DeviceGeneration ==
            CHATPAD_REQUEST_OWNER_INVALID_GENERATION &&
        requestContext->OperationToken.OperationSequence ==
            CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE &&
        requestContext->LifecycleGeneration ==
            CHATPAD_REQUEST_OWNER_INVALID_GENERATION &&
        requestContext->ActivationStepIndex ==
            CHATPAD_REQUEST_OWNER_INVALID_STEP &&
        requestContext->DataDirection ==
            CHATPAD_CONTROL_DATA_DIRECTION_NONE &&
        requestContext->TransferDirection ==
            CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_NONE &&
        requestContext->TransferLength == 0u &&
        requestContext->ExpectedInboundLength == 0u &&
        requestContext->ActiveTransferMemory == NULL &&
        ChatpadKmdfRequestOwnerBufferIsZero(
            &requestContext->SetupPacket,
            sizeof(requestContext->SetupPacket)) &&
        ChatpadKmdfRequestOwnerCompletionSnapshotIsZero(
            &requestContext->CompletionSnapshot);
}

static ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerValidateCreationCommon(
    const ChatpadKmdfActivationRequestOwner *owner,
    int allowOwnerReady)
{
    ChatpadRequestOwnerInvariantResult modelInvariantResult;
    ChatpadRequestOwnerSnapshot modelSnapshot;
    ChatpadRequestOwnerResult snapshotResult;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u &&
        !allowOwnerReady) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OWNER_READY_PREMATURE;
    }
    if ((owner->InitializationMask &
         (CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING |
          CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED)) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }
    if (!ChatpadKmdfRequestOwnerTransferStorageIsZero(&owner->TransferStorage) ||
        !ChatpadKmdfRequestOwnerCompletionSnapshotIsZero(
            &owner->CompletionSnapshot)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }

    modelInvariantResult = ChatpadRequestOwnerValidateInvariant(&owner->Model);
    if (modelInvariantResult != CHATPAD_REQUEST_OWNER_INVARIANT_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }
    if (ChatpadKmdfRequestOwnerModelHasActiveOperationOrLifecycle(
            &owner->Model)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_ACTIVE_OPERATION_OR_LIFECYCLE;
    }

    RtlZeroMemory(&modelSnapshot, sizeof(modelSnapshot));
    snapshotResult = ChatpadRequestOwnerGetSnapshot(
        &owner->Model,
        &modelSnapshot);
    if (snapshotResult != CHATPAD_REQUEST_OWNER_OK ||
        !ChatpadKmdfRequestOwnerSnapshotIsPreObjectBaseline(&modelSnapshot)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerValidateCreationState(
    const ChatpadKmdfActivationRequestOwner *owner,
    const ChatpadKmdfActivationRequestContext *requestContext,
    ChatpadKmdfRequestOwnerCreationState expectedState)
{
    ChatpadKmdfRequestOwnerCreationResult commonResult;
    ULONG expectedMask;

    commonResult = ChatpadKmdfRequestOwnerValidateCreationCommon(
        owner,
        expectedState == CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY);
    if (commonResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return commonResult;
    }

    switch (expectedState) {
    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_PRE_OBJECT:
        expectedMask = CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY;
        if (owner->BookkeepingLock != NULL ||
            owner->Request != NULL ||
            owner->OutboundMemory != NULL ||
            owner->InboundMemory != NULL ||
            requestContext != NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_FRAMEWORK_HANDLE;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_CREATED:
        expectedMask =
            CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED;
        if (owner->BookkeepingLock == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
        }
        if (owner->Request != NULL ||
            owner->OutboundMemory != NULL ||
            owner->InboundMemory != NULL ||
            requestContext != NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_FRAMEWORK_HANDLE;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_REQUEST_CREATED:
        expectedMask =
            CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED;
        if (owner->BookkeepingLock == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
        }
        if (owner->Request == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
        }
        if (owner->OutboundMemory != NULL ||
            owner->InboundMemory != NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
        }
        if (!ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
                requestContext,
                owner)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED:
        expectedMask =
            CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED;
        if (owner->BookkeepingLock == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
        }
        if (owner->Request == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
        }
        if (owner->OutboundMemory == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_REQUIRED;
        }
        if (owner->InboundMemory != NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
        }
        if (!ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
                requestContext,
                owner)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED:
        expectedMask =
            CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED;
        if (owner->BookkeepingLock == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
        }
        if (owner->Request == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
        }
        if (owner->OutboundMemory == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_REQUIRED;
        }
        if (owner->InboundMemory == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
        }
        if (!ChatpadKmdfRequestOwnerBackingCapacityIsExact(
                sizeof(owner->TransferStorage.OutboundBytes),
                CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY) ||
            !ChatpadKmdfRequestOwnerBackingCapacityIsExact(
                sizeof(owner->TransferStorage.InboundBytes),
                CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_BACKING_BUFFER_CAPACITY;
        }
        if (!ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
                requestContext,
                owner)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY:
        expectedMask =
            CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED |
            CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY;
        if (owner->BookkeepingLock == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
        }
        if (owner->Request == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
        }
        if (owner->OutboundMemory == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_REQUIRED;
        }
        if (owner->InboundMemory == NULL) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
        }
        if (!ChatpadKmdfRequestOwnerBackingCapacityIsExact(
                sizeof(owner->TransferStorage.OutboundBytes),
                CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY) ||
            !ChatpadKmdfRequestOwnerBackingCapacityIsExact(
                sizeof(owner->TransferStorage.InboundBytes),
                CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_BACKING_BUFFER_CAPACITY;
        }
        if (!ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
                requestContext,
                owner)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
        }
        break;

    default:
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }

    if (owner->InitializationMask != expectedMask) {
        if (expectedState ==
            CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_PRE_OBJECT) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_PRE_OBJECT_STATE_INVALID;
        }
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDFSPINLOCK spinlock;
    NTSTATUS status;
    ChatpadKmdfRequestOwnerAttributeResult attributeResult;
    ChatpadKmdfRequestOwnerCreationResult validationResult;

    if (frameworkStatus == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_FRAMEWORK_STATUS;
    }
    *frameworkStatus = STATUS_INVALID_DEVICE_STATE;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER;
    }
    if (parentDevice == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_PARENT_DEVICE;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED) != 0u ||
        owner->BookkeepingLock != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_ALREADY_CREATED;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED) != 0u ||
        owner->Request != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_ALREADY_CREATED;
    }

    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        NULL,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_PRE_OBJECT);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }

    attributeResult =
        ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes(
            parentDevice,
            &attributes);
    if (attributeResult != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_ATTRIBUTE_PREPARATION_FAILED;
    }

    spinlock = NULL;
    status = WdfSpinLockCreate(&attributes, &spinlock);
    *frameworkStatus = status;
    if (!NT_SUCCESS(status)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_SPINLOCK_CREATE_FAILED;
    }
    if (spinlock == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }

    owner->BookkeepingLock = spinlock;
    owner->InitializationMask |=
        CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED;

    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        NULL,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateReusableRequest(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDFREQUEST request;
    ChatpadKmdfActivationRequestContext *requestContext;
    NTSTATUS status;
    ChatpadKmdfRequestOwnerAttributeResult attributeResult;
    ChatpadKmdfRequestOwnerCreationResult validationResult;

    if (frameworkStatus == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_FRAMEWORK_STATUS;
    }
    *frameworkStatus = STATUS_INVALID_DEVICE_STATE;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER;
    }
    if (parentDevice == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_PARENT_DEVICE;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED) != 0u ||
        owner->Request != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_ALREADY_CREATED;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED) == 0u ||
        owner->BookkeepingLock == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
    }

    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        NULL,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }

    attributeResult =
        ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes(
            parentDevice,
            &attributes);
    if (attributeResult != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_ATTRIBUTE_PREPARATION_FAILED;
    }

    request = NULL;
    status = WdfRequestCreate(
        &attributes,
        WDF_NO_HANDLE,
        &request);
    *frameworkStatus = status;
    if (!NT_SUCCESS(status)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_REQUEST_CREATE_FAILED;
    }
    if (request == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }

    requestContext = ChatpadKmdfGetActivationRequestContext(request);
    if (requestContext != NULL) {
        ChatpadKmdfRequestOwnerInitializeDormantRequestContext(
            requestContext,
            owner);
    }

    owner->Request = request;
    owner->InitializationMask |=
        CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED;

    if (requestContext == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
    }
    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_REQUEST_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateOutboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDFMEMORY memory;
    ChatpadKmdfActivationRequestContext *requestContext;
    NTSTATUS status;
    ChatpadKmdfRequestOwnerAttributeResult attributeResult;
    ChatpadKmdfRequestOwnerCreationResult validationResult;

    if (frameworkStatus == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_FRAMEWORK_STATUS;
    }
    *frameworkStatus = STATUS_INVALID_DEVICE_STATE;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    validationResult = ChatpadKmdfRequestOwnerValidateCreationCommon(owner, 0);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_ALREADY_CREATED;
    }
    if (owner->OutboundMemory != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INBOUND_MEMORY_ALREADY_CREATED;
    }
    if (owner->InboundMemory != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED) == 0u ||
        owner->BookkeepingLock == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED) == 0u ||
        owner->Request == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
    }
    if (!ChatpadKmdfRequestOwnerBackingCapacityIsExact(
            sizeof(owner->TransferStorage.OutboundBytes),
            CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_BACKING_BUFFER_CAPACITY;
    }

    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_REQUEST_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }

    attributeResult =
        ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes(
            owner->Request,
            &attributes);
    if (attributeResult != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_ATTRIBUTE_PREPARATION_FAILED;
    }

    memory = NULL;
    status = WdfMemoryCreatePreallocated(
        &attributes,
        owner->TransferStorage.OutboundBytes,
        sizeof(owner->TransferStorage.OutboundBytes),
        &memory);
    *frameworkStatus = status;
    if (!NT_SUCCESS(status)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_MEMORY_CREATE_PREALLOCATED_FAILED;
    }
    if (memory == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }

    owner->OutboundMemory = memory;
    owner->InitializationMask |=
        CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED;

    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateInboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus)
{
    WDF_OBJECT_ATTRIBUTES attributes;
    WDFMEMORY memory;
    ChatpadKmdfActivationRequestContext *requestContext;
    NTSTATUS status;
    ChatpadKmdfRequestOwnerAttributeResult attributeResult;
    ChatpadKmdfRequestOwnerCreationResult validationResult;

    if (frameworkStatus == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_FRAMEWORK_STATUS;
    }
    *frameworkStatus = STATUS_INVALID_DEVICE_STATE;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK;
    }
    validationResult = ChatpadKmdfRequestOwnerValidateCreationCommon(owner, 0);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INBOUND_MEMORY_ALREADY_CREATED;
    }
    if (owner->InboundMemory != NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED) == 0u ||
        owner->BookkeepingLock == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED) == 0u ||
        owner->Request == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED) == 0u ||
        owner->OutboundMemory == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_REQUIRED;
    }
    if (!ChatpadKmdfRequestOwnerBackingCapacityIsExact(
            sizeof(owner->TransferStorage.InboundBytes),
            CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_BACKING_BUFFER_CAPACITY;
    }

    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return validationResult;
    }

    attributeResult =
        ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes(
            owner->Request,
            &attributes);
    if (attributeResult != CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_ATTRIBUTE_PREPARATION_FAILED;
    }

    memory = NULL;
    status = WdfMemoryCreatePreallocated(
        &attributes,
        owner->TransferStorage.InboundBytes,
        sizeof(owner->TransferStorage.InboundBytes),
        &memory);
    *frameworkStatus = status;
    if (!NT_SUCCESS(status)) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_MEMORY_CREATE_PREALLOCATED_FAILED;
    }
    if (memory == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }

    owner->InboundMemory = memory;
    owner->InitializationMask |=
        CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED;

    validationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED);
    if (validationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK;
}

ChatpadKmdfRequestOwnerRollbackResult
ChatpadKmdfRequestOwnerClassifyRollbackState(
    const ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerRollbackState *state)
{
    ChatpadRequestOwnerInvariantResult modelInvariantResult;
    ChatpadRequestOwnerSnapshot modelSnapshot;
    ChatpadRequestOwnerResult snapshotResult;
    int lockCreated;
    int requestCreated;
    int outboundMemoryCreated;
    int inboundMemoryCreated;

    if (state == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_NULL_STATE;
    }
    *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_INVALID;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_NULL_OWNER;
    }
    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u ||
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY) == 0u ||
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INVALID_INITIALIZATION_MASK;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u) {
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_OWNER_READY;
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OWNER_READY;
    }

    modelInvariantResult = ChatpadRequestOwnerValidateInvariant(&owner->Model);
    if (modelInvariantResult != CHATPAD_REQUEST_OWNER_INVARIANT_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INVALID_MODEL_STATE;
    }
    if (ChatpadKmdfRequestOwnerModelHasActiveOperationOrLifecycle(
            &owner->Model)) {
        *state =
            CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ACTIVE_OPERATION_OR_LIFECYCLE;
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_ACTIVE_OPERATION_OR_LIFECYCLE;
    }
    RtlZeroMemory(&modelSnapshot, sizeof(modelSnapshot));
    snapshotResult = ChatpadRequestOwnerGetSnapshot(
        &owner->Model,
        &modelSnapshot);
    if (snapshotResult != CHATPAD_REQUEST_OWNER_OK ||
        !ChatpadKmdfRequestOwnerSnapshotIsPreObjectBaseline(&modelSnapshot) ||
        !ChatpadKmdfRequestOwnerTransferStorageIsZero(&owner->TransferStorage) ||
        !ChatpadKmdfRequestOwnerCompletionSnapshotIsZero(
            &owner->CompletionSnapshot)) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INVALID_MODEL_STATE;
    }

    lockCreated =
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED) != 0u;
    requestCreated =
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED) != 0u;
    outboundMemoryCreated =
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED) != 0u;
    inboundMemoryCreated =
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED) != 0u;

    if (lockCreated != (owner->BookkeepingLock != NULL)) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INCONSISTENT_LOCK_STATE;
    }
    if (requestCreated != (owner->Request != NULL) ||
        (requestCreated && !lockCreated)) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INCONSISTENT_REQUEST_STATE;
    }
    if (outboundMemoryCreated != (owner->OutboundMemory != NULL) ||
        inboundMemoryCreated != (owner->InboundMemory != NULL) ||
        (outboundMemoryCreated && !requestCreated) ||
        (inboundMemoryCreated && !outboundMemoryCreated)) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INCONSISTENT_MEMORY_STATE;
    }
    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED) != 0u) {
        if (owner->InitializationMask !=
                CHATPAD_KMDF_REQUEST_OWNER_ROLLED_BACK_INIT_MASK ||
            lockCreated || requestCreated ||
            outboundMemoryCreated || inboundMemoryCreated) {
            return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_INVALID_INITIALIZATION_MASK;
        }
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED;
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK;
    }

    switch (owner->InitializationMask) {
    case CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY:
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_CLEAN_MODEL_READY;
        break;
    case CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED:
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_LOCK_CREATED;
        break;
    case CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED:
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_LOCK_REQUEST_CREATED;
        break;
    case CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED:
        *state =
            CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_OUTBOUND_MEMORY_CREATED;
        break;
    case CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED |
         CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED:
        *state = CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ALL_MEMORY_CREATED;
        break;
    default:
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_UNSUPPORTED_OR_INCONSISTENT_STATE;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK;
}

ChatpadKmdfRequestOwnerRollbackResult
ChatpadKmdfRequestOwnerRollbackPartialCreation(
    ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerRollbackEffects *effects)
{
    ChatpadKmdfRequestOwnerRollbackResult result;
    ChatpadKmdfRequestOwnerRollbackState state;
    WDFREQUEST request;
    WDFSPINLOCK spinlock;

    if (effects == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_NULL_EFFECTS;
    }
    RtlZeroMemory(effects, sizeof(*effects));

    result = ChatpadKmdfRequestOwnerClassifyRollbackState(owner, &state);
    if (result != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK) {
        return result;
    }

    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_ROLLBACK_STARTED,
        STATUS_SUCCESS,
        (ULONG)state,
        (ULONG)owner->InitializationMask,
        0u);
    ChatpadKmdfTraceOwnerSnapshot(
        owner,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_ROLLBACK_OBJECT_SNAPSHOT_BEFORE,
        STATUS_SUCCESS,
        0u);

    if (state == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_CLEAN_MODEL_READY ||
        state == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED) {
        effects->PriorInitializationMask = owner->InitializationMask;
        effects->ResultingInitializationMask = owner->InitializationMask;
        effects->AlreadyClean = 1u;
        ChatpadKmdfTraceOwnerEvent(
            owner,
            TRACE_LEVEL_INFORMATION,
            CHATPAD_TRACE_CLEANUP,
            CHATPAD_RUNTIME_EVENT_ROLLBACK_COMPLETED,
            STATUS_SUCCESS,
            (ULONG)state,
            effects->PriorInitializationMask,
            effects->ResultingInitializationMask);
        ChatpadKmdfTraceOwnerSnapshot(
            owner,
            TRACE_LEVEL_INFORMATION,
            CHATPAD_TRACE_CLEANUP,
            CHATPAD_RUNTIME_EVENT_ROLLBACK_OBJECT_SNAPSHOT_AFTER,
            STATUS_SUCCESS,
            0u);
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_ALREADY_CLEAN;
    }

    effects->PriorInitializationMask = owner->InitializationMask;
    effects->OutboundMemoryRepresented = owner->OutboundMemory != NULL;
    effects->InboundMemoryRepresented = owner->InboundMemory != NULL;
    request = owner->Request;
    spinlock = owner->BookkeepingLock;

    if (request != NULL) {
        WdfObjectDelete(request);
        owner->Request = NULL;
        owner->OutboundMemory = NULL;
        owner->InboundMemory = NULL;
        owner->InitializationMask &=
            ~(CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED |
              CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED |
              CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED);
        effects->RequestHierarchyDeletionInitiated = 1u;
    }

    if (spinlock != NULL) {
        WdfObjectDelete(spinlock);
        owner->BookkeepingLock = NULL;
        owner->InitializationMask &=
            ~CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED;
        effects->SpinlockDeletionInitiated = 1u;
    }

    owner->InitializationMask &=
        ~CHATPAD_KMDF_REQUEST_OWNER_CREATED_INIT_MASK;
    owner->InitializationMask |=
        CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED;
    effects->ResultingInitializationMask = owner->InitializationMask;

    result = ChatpadKmdfRequestOwnerClassifyRollbackState(owner, &state);
    if (result != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK ||
        state != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED) {
        ChatpadKmdfTraceOwnerEvent(
            owner,
            TRACE_LEVEL_ERROR,
            CHATPAD_TRACE_INVARIANT,
            CHATPAD_RUNTIME_EVENT_OBJECT_SNAPSHOT_INCONSISTENT,
            STATUS_INVALID_DEVICE_STATE,
            (ULONG)state,
            effects->PriorInitializationMask,
            effects->ResultingInitializationMask);
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_POST_ROLLBACK_INVARIANT_FAILED;
    }
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_ROLLBACK_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)state,
        effects->PriorInitializationMask,
        effects->ResultingInitializationMask);
    ChatpadKmdfTraceOwnerSnapshot(
        owner,
        TRACE_LEVEL_INFORMATION,
        CHATPAD_TRACE_CLEANUP,
        CHATPAD_RUNTIME_EVENT_ROLLBACK_OBJECT_SNAPSHOT_AFTER,
        STATUS_SUCCESS,
        0u);
    return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK;
}

static ChatpadKmdfRequestOwnerOrchestrationResult
ChatpadKmdfRequestOwnerValidateOrchestrationBaseline(
    const ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerOrchestrationReport *report)
{
    ChatpadKmdfActivationRequestContext *requestContext;
    ChatpadKmdfRequestOwnerRollbackResult rollbackResult;
    ChatpadKmdfRequestOwnerRollbackState rollbackState;
    ChatpadKmdfRequestOwnerStorageValidation baselineValidation;
    ULONG createdMask;

    if (owner == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_OWNER;
    }
    report->InitialInitializationMask = owner->InitializationMask;
    report->HighestPartialInitializationMask = owner->InitializationMask;
    report->FinalInitializationMask = owner->InitializationMask;

    if (owner->Signature != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_SIGNATURE;
    }
    if (owner->Version != CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_UNSUPPORTED_VERSION;
    }
    if ((owner->InitializationMask &
         ~CHATPAD_KMDF_REQUEST_OWNER_KNOWN_INIT_MASK) != 0u) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE;
    }

    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u) {
        requestContext = NULL;
        if (owner->Request != NULL) {
            requestContext = ChatpadKmdfGetActivationRequestContext(
                owner->Request);
        }
        report->ValidationResult =
            ChatpadKmdfRequestOwnerValidateCreationState(
                owner,
                requestContext,
                CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY);
        if (report->ValidationResult ==
            CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
            report->ReadyPublished = 1u;
            report->ObjectGraphComplete = 1u;
            return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_READY;
        }
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE;
    }

    if ((owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED) != 0u) {
        rollbackResult = ChatpadKmdfRequestOwnerClassifyRollbackState(
            owner,
            &rollbackState);
        if (rollbackResult == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK &&
            rollbackState ==
                CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED) {
            return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_FAULTED;
        }
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE;
    }

    createdMask = owner->InitializationMask &
        CHATPAD_KMDF_REQUEST_OWNER_CREATED_INIT_MASK;
    if (createdMask != 0u || ChatpadKmdfRequestOwnerHasFrameworkHandle(owner)) {
        rollbackResult = ChatpadKmdfRequestOwnerClassifyRollbackState(
            owner,
            &rollbackState);
        if (rollbackResult == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK &&
            rollbackState !=
                CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_CLEAN_MODEL_READY) {
            return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PARTIAL_STATE_PRESENT;
        }
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE;
    }

    report->BaselineValidationResult =
        ChatpadKmdfRequestOwnerValidatePreObjectState(
            owner,
            &baselineValidation);
    if (report->BaselineValidationResult !=
        CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK;
}

static int ChatpadKmdfRequestOwnerMarkFaultedWithoutObjects(
    ChatpadKmdfActivationRequestOwner *owner)
{
    ChatpadKmdfRequestOwnerRollbackResult rollbackResult;
    ChatpadKmdfRequestOwnerRollbackState rollbackState;
    ChatpadKmdfRequestOwnerStorageValidation validation;

    if (ChatpadKmdfRequestOwnerValidatePreObjectState(owner, &validation) !=
        CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        return 0;
    }
    owner->InitializationMask =
        CHATPAD_KMDF_REQUEST_OWNER_ROLLED_BACK_INIT_MASK;
    rollbackResult = ChatpadKmdfRequestOwnerClassifyRollbackState(
        owner,
        &rollbackState);
    return rollbackResult == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK &&
        rollbackState ==
            CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED;
}

ChatpadKmdfRequestOwnerOrchestrationResult
ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerOrchestrationReport *report)
{
    ChatpadKmdfActivationRequestContext *requestContext;
    ChatpadKmdfRequestOwnerCreationResult creationResult;
    ChatpadKmdfRequestOwnerOrchestrationResult orchestrationResult;
    ChatpadKmdfRequestOwnerRollbackResult rollbackResult;
    ChatpadKmdfRequestOwnerRollbackState rollbackState;
    NTSTATUS frameworkStatus;
    int objectPublished;

    if (report == NULL) {
        return CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_REPORT;
    }
    RtlZeroMemory(report, sizeof(*report));
    report->Result = CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED;
    report->FrameworkStatus = STATUS_INVALID_DEVICE_STATE;

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_BASELINE;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    orchestrationResult = ChatpadKmdfRequestOwnerValidateOrchestrationBaseline(
        owner,
        report);
    if (orchestrationResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
        report->Result = orchestrationResult;
        report->FailedStage =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_BASELINE;
        return orchestrationResult;
    }
    if (parentDevice == NULL) {
        report->Result =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_PARENT_DEVICE;
        report->FailedStage =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_BASELINE;
        return report->Result;
    }
    report->LastCompletedStage =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_BASELINE;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->BaselineValidationResult,
        0u);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_SPINLOCK;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    frameworkStatus = STATUS_INVALID_DEVICE_STATE;
    creationResult = ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock(
        parentDevice,
        owner,
        &frameworkStatus);
    report->CreationHelperCalled = 1u;
    report->CreationResult = creationResult;
    report->FrameworkStatus = frameworkStatus;
    if (creationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_SPINLOCK_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        NULL,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_CREATED);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_SPINLOCK_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->LastCompletedStage = report->LastStageEntered;
    report->HighestPartialInitializationMask = owner->InitializationMask;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->CreationResult,
        report->HighestPartialInitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_REQUEST;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    frameworkStatus = STATUS_INVALID_DEVICE_STATE;
    creationResult = ChatpadKmdfRequestOwnerCreateReusableRequest(
        parentDevice,
        owner,
        &frameworkStatus);
    report->CreationResult = creationResult;
    report->FrameworkStatus = frameworkStatus;
    if (creationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_REQUEST_CREATED);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->LastCompletedStage = report->LastStageEntered;
    report->HighestPartialInitializationMask = owner->InitializationMask;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->CreationResult,
        report->HighestPartialInitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_OUTBOUND_MEMORY;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    frameworkStatus = STATUS_INVALID_DEVICE_STATE;
    creationResult = ChatpadKmdfRequestOwnerCreateOutboundMemory(
        owner,
        &frameworkStatus);
    report->CreationResult = creationResult;
    report->FrameworkStatus = frameworkStatus;
    if (creationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OUTBOUND_MEMORY_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OUTBOUND_MEMORY_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->LastCompletedStage = report->LastStageEntered;
    report->HighestPartialInitializationMask = owner->InitializationMask;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->CreationResult,
        report->HighestPartialInitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_INBOUND_MEMORY;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    frameworkStatus = STATUS_INVALID_DEVICE_STATE;
    creationResult = ChatpadKmdfRequestOwnerCreateInboundMemory(
        owner,
        &frameworkStatus);
    report->CreationResult = creationResult;
    report->FrameworkStatus = frameworkStatus;
    if (creationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INBOUND_MEMORY_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INBOUND_MEMORY_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->LastCompletedStage = report->LastStageEntered;
    report->HighestPartialInitializationMask = owner->InitializationMask;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->CreationResult,
        report->HighestPartialInitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_PRE_READY;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PRE_READY_VALIDATION_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }
    report->LastCompletedStage = report->LastStageEntered;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->ValidationResult,
        owner->InitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_PUBLISH_READY;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    report->ReadyPublicationAttempted = 1u;
    owner->InitializationMask |= CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY;
    report->LastCompletedStage = report->LastStageEntered;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        report->ReadyPublicationAttempted,
        owner->InitializationMask);

    report->LastStageEntered =
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_READY;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
        STATUS_SUCCESS,
        (ULONG)report->LastStageEntered,
        0u,
        0u);
    requestContext = ChatpadKmdfGetActivationRequestContext(owner->Request);
    report->ValidationResult = ChatpadKmdfRequestOwnerValidateCreationState(
        owner,
        requestContext,
        CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY);
    if (report->ValidationResult != CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK) {
        owner->InitializationMask &=
            ~CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY;
        orchestrationResult =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_READY_VALIDATION_FAILED;
        report->FailedStage = report->LastStageEntered;
        goto OrchestrationFailure;
    }

    report->LastCompletedStage = report->LastStageEntered;
    ChatpadKmdfTraceOwnerEvent(
        owner,
        TRACE_LEVEL_VERBOSE,
        CHATPAD_TRACE_ORCHESTRATION,
        CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
        STATUS_SUCCESS,
        (ULONG)report->LastCompletedStage,
        (ULONG)report->ValidationResult,
        owner->InitializationMask);
    report->FinalInitializationMask = owner->InitializationMask;
    report->ReadyPublished = 1u;
    report->ObjectGraphComplete = 1u;
    report->Result = CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK;
    return report->Result;

OrchestrationFailure:
    report->HighestPartialInitializationMask =
        owner->InitializationMask &
        ~CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY;
    owner->InitializationMask &=
        ~CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY;
    report->ReadyPublished = 0u;
    objectPublished =
        (owner->InitializationMask &
         CHATPAD_KMDF_REQUEST_OWNER_CREATED_INIT_MASK) != 0u ||
        ChatpadKmdfRequestOwnerHasFrameworkHandle(owner);

    if (objectPublished) {
        report->LastStageEntered =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_ROLLBACK;
        ChatpadKmdfTraceOwnerEvent(
            owner,
            TRACE_LEVEL_INFORMATION,
            CHATPAD_TRACE_CLEANUP,
            CHATPAD_RUNTIME_EVENT_ROLLBACK_REASON,
            STATUS_SUCCESS,
            (ULONG)report->FailedStage,
            (ULONG)orchestrationResult,
            report->HighestPartialInitializationMask);
        ChatpadKmdfTraceOwnerEvent(
            owner,
            TRACE_LEVEL_VERBOSE,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_ENTERED,
            STATUS_SUCCESS,
            (ULONG)report->LastStageEntered,
            (ULONG)orchestrationResult,
            0u);
        report->RollbackAttempted = 1u;
        rollbackResult = ChatpadKmdfRequestOwnerRollbackPartialCreation(
            owner,
            &report->RollbackEffects);
        report->RollbackResult = rollbackResult;
        if (rollbackResult != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK) {
            report->Result =
                CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED;
            report->FinalInitializationMask = owner->InitializationMask;
            return report->Result;
        }
        report->RollbackSucceeded = 1u;
        report->LastCompletedStage = report->LastStageEntered;
        ChatpadKmdfTraceOwnerEvent(
            owner,
            TRACE_LEVEL_VERBOSE,
            CHATPAD_TRACE_ORCHESTRATION,
            CHATPAD_RUNTIME_EVENT_ORCHESTRATION_STAGE_COMPLETED,
            STATUS_SUCCESS,
            (ULONG)report->LastCompletedStage,
            (ULONG)rollbackResult,
            owner->InitializationMask);
    } else if (!ChatpadKmdfRequestOwnerMarkFaultedWithoutObjects(owner)) {
        report->Result =
            CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED;
        report->FinalInitializationMask = owner->InitializationMask;
        return report->Result;
    }

    rollbackResult = ChatpadKmdfRequestOwnerClassifyRollbackState(
        owner,
        &rollbackState);
    if (rollbackResult != CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK ||
        rollbackState !=
            CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED) {
        report->Result = report->RollbackAttempted != 0u
            ? CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED
            : CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED;
        report->FinalInitializationMask = owner->InitializationMask;
        return report->Result;
    }

    report->FinalInitializationMask = owner->InitializationMask;
    report->Result = orchestrationResult;
    return report->Result;
}
