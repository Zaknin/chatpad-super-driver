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

typedef enum ChatpadKmdfRequestOwnerStorageResult {
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK = 0,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_OWNER,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_NULL_VALIDATION,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_SIGNATURE,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_UNSUPPORTED_VERSION,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_INITIALIZATION_MASK,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_MODEL_INITIALIZATION_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_MODEL_STATE,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_FRAMEWORK_HANDLE_PRESENT,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OWNER_READY_PREMATURE,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ACTIVE_OPERATION_OR_LIFECYCLE,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_COMPLETION_SNAPSHOT,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVALID_TRANSFER_STORAGE,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_INVARIANT_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_ALREADY_INITIALIZED
} ChatpadKmdfRequestOwnerStorageResult;

typedef enum ChatpadKmdfRequestOwnerStorageValidationFlag {
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NONE = 0x00000000u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_SIGNATURE = 0x00000001u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_VERSION = 0x00000002u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MASK = 0x00000004u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_READY = 0x00000008u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NO_FRAMEWORK_HANDLES = 0x00000010u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_NOT_OWNER_READY = 0x00000020u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_MODEL_BASELINE = 0x00000040u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_COMPLETION_SNAPSHOT = 0x00000080u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_TRANSFER_STORAGE = 0x00000100u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_CAPACITY = 0x00000200u,
    CHATPAD_KMDF_REQUEST_OWNER_STORAGE_VALIDATION_PRE_OBJECT_READY = 0x00000400u
} ChatpadKmdfRequestOwnerStorageValidationFlag;

typedef enum ChatpadKmdfRequestOwnerAttributeResult {
    CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_OK = 0,
    CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_ATTRIBUTES,
    CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_DEVICE_PARENT,
    CHATPAD_KMDF_REQUEST_OWNER_ATTRIBUTES_NULL_REQUEST_PARENT
} ChatpadKmdfRequestOwnerAttributeResult;

typedef enum ChatpadKmdfRequestOwnerCreationState {
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_PRE_OBJECT = 0,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_LOCK_REQUEST_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_OUTBOUND_MEMORY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_ALL_MEMORY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY
} ChatpadKmdfRequestOwnerCreationState;

typedef enum ChatpadKmdfRequestOwnerCreationResult {
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK = 0,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_OWNER,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_PARENT_DEVICE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_NULL_FRAMEWORK_STATUS,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_SIGNATURE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_VERSION,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_INITIALIZATION_MASK,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_PRE_OBJECT_STATE_INVALID,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_ALREADY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_ALREADY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_SPINLOCK_REQUIRED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_REQUIRED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_ALREADY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_INBOUND_MEMORY_ALREADY_CREATED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_OUTBOUND_MEMORY_REQUIRED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_MEMORY_HANDLE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_INVALID_BACKING_BUFFER_CAPACITY,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNEXPECTED_FRAMEWORK_HANDLE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_MEMORY_STATE_PRESENT,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_OWNER_READY_PREMATURE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_ACTIVE_OPERATION_OR_LIFECYCLE,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_ATTRIBUTE_PREPARATION_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_SPINLOCK_CREATE_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_REQUEST_CREATE_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_WDF_MEMORY_CREATE_PREALLOCATED_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_REQUEST_CONTEXT_INVALID,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_POST_CREATION_INVARIANT_FAILED,
    CHATPAD_KMDF_REQUEST_OWNER_CREATION_UNSUPPORTED_OR_INCONSISTENT_STATE
} ChatpadKmdfRequestOwnerCreationResult;

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

typedef struct ChatpadKmdfRequestOwnerStorageValidation {
    ChatpadKmdfRequestOwnerStorageResult Result;
    ULONG InvariantMask;
    ChatpadRequestOwnerInvariantResult ModelInvariantResult;
    ChatpadRequestOwnerSnapshot ModelSnapshot;
} ChatpadKmdfRequestOwnerStorageValidation;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(
    ChatpadKmdfActivationRequestContext,
    ChatpadKmdfGetActivationRequestContext)

ChatpadKmdfRequestOwnerStorageResult ChatpadKmdfRequestOwnerInitializeStorage(
    ChatpadKmdfActivationRequestOwner *owner);

ChatpadKmdfRequestOwnerStorageResult ChatpadKmdfRequestOwnerValidatePreObjectState(
    const ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerStorageValidation *validation);

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes(
    WDFDEVICE device,
    WDF_OBJECT_ATTRIBUTES *attributes);

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes(
    WDFDEVICE device,
    WDF_OBJECT_ATTRIBUTES *attributes);

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes);

ChatpadKmdfRequestOwnerAttributeResult
ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes(
    WDFREQUEST request,
    WDF_OBJECT_ATTRIBUTES *attributes);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerValidateCreationState(
    const ChatpadKmdfActivationRequestOwner *owner,
    const ChatpadKmdfActivationRequestContext *requestContext,
    ChatpadKmdfRequestOwnerCreationState expectedState);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateReusableRequest(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateOutboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateInboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

#ifdef __cplusplus
}
#endif

#endif
