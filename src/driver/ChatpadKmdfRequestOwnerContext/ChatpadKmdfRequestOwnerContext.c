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

void ChatpadKmdfRequestOwnerInitializeRequestAttributes(
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(
        attributes,
        ChatpadKmdfActivationRequestContext);
}

void ChatpadKmdfRequestOwnerInitializePlainMemoryAttributes(
    WDF_OBJECT_ATTRIBUTES *attributes)
{
    WDF_OBJECT_ATTRIBUTES_INIT(attributes);
}
