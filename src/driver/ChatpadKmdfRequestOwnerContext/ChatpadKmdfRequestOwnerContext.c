#include "ChatpadKmdfRequestOwnerContext.h"

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
    const ChatpadKmdfActivationRequestOwner *owner)
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
         CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY) != 0u) {
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

    commonResult = ChatpadKmdfRequestOwnerValidateCreationCommon(owner);
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
        if (!ChatpadKmdfRequestOwnerDormantRequestContextIsValid(
                requestContext,
                owner)) {
            return CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID;
        }
        break;

    case CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY:
        return CHATPAD_KMDF_REQUEST_OWNER_CREATION_OWNER_READY_PREMATURE;

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
    validationResult = ChatpadKmdfRequestOwnerValidateCreationCommon(owner);
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
    validationResult = ChatpadKmdfRequestOwnerValidateCreationCommon(owner);
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

    if (state == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_CLEAN_MODEL_READY ||
        state == CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_STATE_ROLLED_BACK_FAULTED) {
        effects->PriorInitializationMask = owner->InitializationMask;
        effects->ResultingInitializationMask = owner->InitializationMask;
        effects->AlreadyClean = 1u;
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
        return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_POST_ROLLBACK_INVARIANT_FAILED;
    }
    return CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_OK;
}
