#include "ChatpadKmdfRequestOwnerContext.h"

C_ASSERT(CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY == 2u);
C_ASSERT(CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY == 2u);
C_ASSERT(CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY == CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH);
C_ASSERT(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT == 6u);
C_ASSERT(CHATPAD_KMDF_ACTIVATION_MAX_STEP_INDEX >=
    (uint32_t)(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT - 1u));
C_ASSERT(sizeof(ChatpadActivationRequestOwner) != 0u);
C_ASSERT(sizeof(ChatpadKmdfActivationRequestOwner) != 0u);
C_ASSERT(sizeof(ChatpadKmdfActivationRequestContext) != 0u);
C_ASSERT(sizeof(WDF_OBJECT_ATTRIBUTES) != 0u);
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->Model) ==
    sizeof(ChatpadActivationRequestOwner));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->Request) == sizeof(WDFREQUEST));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->OutboundMemory) == sizeof(WDFMEMORY));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->InboundMemory) == sizeof(WDFMEMORY));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->BookkeepingLock) == sizeof(WDFSPINLOCK));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->TransferStorage.OutboundBytes) == 2u);
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestOwner *)0)->TransferStorage.InboundBytes) == 2u);
C_ASSERT(FIELD_OFFSET(ChatpadKmdfActivationTransferStorage, OutboundBytes) !=
    FIELD_OFFSET(ChatpadKmdfActivationTransferStorage, InboundBytes));
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
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->SetupPacket) ==
    sizeof(WDF_USB_CONTROL_SETUP_PACKET));
C_ASSERT(sizeof(((ChatpadKmdfActivationRequestContext *)0)->ActiveTransferMemory) ==
    sizeof(WDFMEMORY));
C_ASSERT(sizeof(((ChatpadKmdfActivationCompletionSnapshot *)0)->TransferredLength) >=
    sizeof(uint16_t));
C_ASSERT(sizeof(((ChatpadKmdfActivationCompletionSnapshot *)0)->CapturedInboundBytes) == 2u);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER !=
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_PRE_OBJECT_READY >
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_BASELINE);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_DEVICE_PARENT !=
    CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_REQUEST_PARENT);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK == 0);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_SPINLOCK_CREATE_FAILED !=
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_REQUEST_CREATE_FAILED);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_MEMORY_CREATE_PREALLOCATED_FAILED !=
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_REQUEST_CREATE_FAILED);
C_ASSERT(CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED !=
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED);

typedef ChatpadKmdfRequestOwnerCreationResult
(*ChatpadKmdfRequestOwnerSpinLockCreationSignature)(
    WDFDEVICE,
    ChatpadKmdfActivationRequestOwner *,
    NTSTATUS *);

typedef ChatpadKmdfRequestOwnerCreationResult
(*ChatpadKmdfRequestOwnerRequestCreationSignature)(
    WDFDEVICE,
    ChatpadKmdfActivationRequestOwner *,
    NTSTATUS *);

typedef ChatpadKmdfRequestOwnerCreationResult
(*ChatpadKmdfRequestOwnerMemoryCreationSignature)(
    ChatpadKmdfActivationRequestOwner *,
    NTSTATUS *);

typedef ChatpadKmdfRequestOwnerCreationResult
(*ChatpadKmdfRequestOwnerCreationValidationSignature)(
    const ChatpadKmdfActivationRequestOwner *,
    const ChatpadKmdfActivationRequestContext *,
    ChatpadKmdfRequestOwnerCreationState);

void ChatpadKmdfRequestOwnerContextCompileCheckCreationSignatures(void)
{
    ChatpadKmdfRequestOwnerSpinLockCreationSignature spinLockCreation;
    ChatpadKmdfRequestOwnerRequestCreationSignature requestCreation;
    ChatpadKmdfRequestOwnerMemoryCreationSignature outboundMemoryCreation;
    ChatpadKmdfRequestOwnerMemoryCreationSignature inboundMemoryCreation;
    ChatpadKmdfRequestOwnerCreationValidationSignature creationValidation;

    spinLockCreation = ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock;
    requestCreation = ChatpadKmdfRequestOwnerCreateReusableRequest;
    outboundMemoryCreation = ChatpadKmdfRequestOwnerCreateOutboundMemory;
    inboundMemoryCreation = ChatpadKmdfRequestOwnerCreateInboundMemory;
    creationValidation = ChatpadKmdfRequestOwnerValidateCreationState;

    UNREFERENCED_PARAMETER(spinLockCreation);
    UNREFERENCED_PARAMETER(requestCreation);
    UNREFERENCED_PARAMETER(outboundMemoryCreation);
    UNREFERENCED_PARAMETER(inboundMemoryCreation);
    UNREFERENCED_PARAMETER(creationValidation);
}

void ChatpadKmdfRequestOwnerContextCompileCheckAttributes(
    WDFDEVICE device,
    WDFREQUEST request)
{
    WDF_OBJECT_ATTRIBUTES lockAttributes;
    WDF_OBJECT_ATTRIBUTES requestAttributes;
    WDF_OBJECT_ATTRIBUTES outboundMemoryAttributes;
    WDF_OBJECT_ATTRIBUTES inboundMemoryAttributes;
    ChatpadKmdfRequestOwnerAttributeResult attributeResult;

    attributeResult = ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes(
        device,
        &lockAttributes);
    attributeResult = ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes(
        device,
        &requestAttributes);
    attributeResult = ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes(
        request,
        &outboundMemoryAttributes);
    attributeResult = ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes(
        request,
        &inboundMemoryAttributes);
    UNREFERENCED_PARAMETER(attributeResult);
}

void ChatpadKmdfRequestOwnerContextCompileCheckTypes(void)
{
    ChatpadKmdfActivationRequestOwner owner;
    ChatpadKmdfActivationRequestContext requestContext;
    ChatpadKmdfRequestOwnerStorageValidation validation;
    ChatpadActivationPreparation preparation;
    ChatpadRequestOwnerEvent event;
    ChatpadKmdfRequestOwnerStorageResult storageResult;

    UNREFERENCED_PARAMETER(requestContext);
    UNREFERENCED_PARAMETER(preparation);

    RtlZeroMemory(&owner, sizeof(owner));
    storageResult = ChatpadKmdfRequestOwnerInitializeStorage(&owner);
    if (storageResult == CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
        storageResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
            &owner,
            &validation);
    }
    UNREFERENCED_PARAMETER(storageResult);
    UNREFERENCED_PARAMETER(validation);

    ChatpadRequestOwnerEventInitialize(
        &event,
        CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE);
}

void ChatpadKmdfRequestOwnerContextCompileCheckStorageResults(
    ChatpadKmdfRequestOwnerStorageResult result)
{
    switch (result) {
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_SIGNATURE:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_UNSUPPORTED_VERSION:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_INITIALIZATION_MASK:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_MODEL_INITIALIZATION_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_MODEL_STATE:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_FRAMEWORK_HANDLE_PRESENT:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OWNER_READY_PREMATURE:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ACTIVE_OPERATION_OR_LIFECYCLE:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_COMPLETION_SNAPSHOT:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_TRANSFER_STORAGE:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVARIANT_FAILED:
    case CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ALREADY_INITIALIZED:
        break;
    default:
        break;
    }
}
