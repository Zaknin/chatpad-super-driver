#ifndef CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_H
#define CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_H

#include <ntddk.h>
#include <wdf.h>
#include <usb.h>
#include <usbdlib.h>
#include <wdfusb.h>

#include "ChatpadActivationPreparation.h"
#include "ChatpadRequestOwnerModel.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE ((ULONG)0x4b524f43u)
#define CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION ((ULONG)1u)

#define CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH
#define CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY ((uint16_t)2u)
#define CHATPAD_KMDF_ACTIVATION_MAX_STEP_INDEX ((uint32_t)(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT - 1u))

typedef enum ChatpadKmdfRequestOwnerInitializationFlag {
    CHATPAD_KMDF_REQUEST_OWNER_INIT_NONE = 0x00000000u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY = 0x00000001u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED = 0x00000002u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED = 0x00000004u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED = 0x00000008u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED = 0x00000010u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY = 0x00000020u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING = 0x00000040u,
    CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED = 0x00000080u
} ChatpadKmdfRequestOwnerInitializationFlag;

typedef enum ChatpadKmdfRequestOwnerTransferDirection {
    CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_NONE = 0,
    CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_OUTBOUND,
    CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_INBOUND
} ChatpadKmdfRequestOwnerTransferDirection;

typedef struct ChatpadKmdfActivationTransferStorage {
    uint8_t OutboundBytes[CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY];
    uint8_t InboundBytes[CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY];
} ChatpadKmdfActivationTransferStorage;

typedef struct ChatpadKmdfActivationCompletionSnapshot {
    NTSTATUS IoStatus;
    ULONG UsbStatus;
    size_t TransferredLength;
    uint16_t CapturedInboundLength;
    uint8_t CapturedInboundBytes[CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY];
    ChatpadRequestOwnerCompletionClass CompletionClass;
} ChatpadKmdfActivationCompletionSnapshot;

typedef struct ChatpadKmdfActivationRequestOwner {
    ULONG Signature;
    ULONG Version;
    ULONG InitializationMask;
    ChatpadActivationRequestOwner Model;
    WDFREQUEST Request;
    WDFMEMORY OutboundMemory;
    WDFMEMORY InboundMemory;
    WDFSPINLOCK BookkeepingLock;
    ChatpadKmdfActivationTransferStorage TransferStorage;
    ChatpadKmdfActivationCompletionSnapshot CompletionSnapshot;
} ChatpadKmdfActivationRequestOwner;

typedef struct ChatpadKmdfActivationRequestContext {
    ChatpadKmdfActivationRequestOwner *Owner;
    ChatpadTransportOperationToken OperationToken;
    uint64_t LifecycleGeneration;
    uint32_t ActivationStepIndex;
    ChatpadControlDataDirection DataDirection;
    ChatpadKmdfRequestOwnerTransferDirection TransferDirection;
    uint16_t TransferLength;
    uint16_t ExpectedInboundLength;
    WDFMEMORY ActiveTransferMemory;
    WDF_USB_CONTROL_SETUP_PACKET SetupPacket;
    ChatpadKmdfActivationCompletionSnapshot CompletionSnapshot;
} ChatpadKmdfActivationRequestContext;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(
    ChatpadKmdfActivationRequestContext,
    ChatpadKmdfGetActivationRequestContext)

void ChatpadKmdfRequestOwnerInitializeRequestAttributes(
    WDF_OBJECT_ATTRIBUTES *attributes);

void ChatpadKmdfRequestOwnerInitializePlainMemoryAttributes(
    WDF_OBJECT_ATTRIBUTES *attributes);

#ifdef __cplusplus
}
#endif

#endif
