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

void ChatpadKmdfRequestOwnerContextCompileCheckAttributes(void)
{
    WDF_OBJECT_ATTRIBUTES requestAttributes;
    WDF_OBJECT_ATTRIBUTES memoryAttributes;

    ChatpadKmdfRequestOwnerInitializeRequestAttributes(&requestAttributes);
    ChatpadKmdfRequestOwnerInitializePlainMemoryAttributes(&memoryAttributes);
}

void ChatpadKmdfRequestOwnerContextCompileCheckTypes(void)
{
    ChatpadKmdfActivationRequestOwner owner;
    ChatpadKmdfActivationRequestContext requestContext;
    ChatpadActivationPreparation preparation;
    ChatpadRequestOwnerEvent event;

    UNREFERENCED_PARAMETER(owner);
    UNREFERENCED_PARAMETER(requestContext);
    UNREFERENCED_PARAMETER(preparation);

    ChatpadRequestOwnerEventInitialize(
        &event,
        CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE);
}
