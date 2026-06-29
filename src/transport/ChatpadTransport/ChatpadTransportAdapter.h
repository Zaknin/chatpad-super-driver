#ifndef CHATPAD_TRANSPORT_ADAPTER_H
#define CHATPAD_TRANSPORT_ADAPTER_H

#include "ChatpadActivationExecutor.h"

#if defined(_MSC_VER) && defined(_KERNEL_MODE)
typedef unsigned __int32 uint32_t;
typedef unsigned __int64 uint64_t;
#ifndef UINT64_C
#define UINT64_C(value) value##ui64
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_TRANSPORT_INVALID_GENERATION ((uint64_t)0)
#define CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE ((uint32_t)0)
#define CHATPAD_TRANSPORT_MAX_TRACKED_OPERATIONS ((uint32_t)64)

typedef enum ChatpadTransportResult {
    CHATPAD_TRANSPORT_OK = 0,
    CHATPAD_TRANSPORT_NULL_STATE,
    CHATPAD_TRANSPORT_NULL_OUTPUT,
    CHATPAD_TRANSPORT_NULL_OPERATION,
    CHATPAD_TRANSPORT_NULL_SINK,
    CHATPAD_TRANSPORT_MISSING_OPERATION_CALLBACK,
    CHATPAD_TRANSPORT_INVALID_GENERATION_ID,
    CHATPAD_TRANSPORT_INVALID_STATE,
    CHATPAD_TRANSPORT_INVALID_OPERATION,
    CHATPAD_TRANSPORT_ACTIVE_GENERATION_EXISTS,
    CHATPAD_TRANSPORT_GENERATION_CANCELLED,
    CHATPAD_TRANSPORT_STALE_GENERATION,
    CHATPAD_TRANSPORT_STALE_COMPLETION,
    CHATPAD_TRANSPORT_DUPLICATE_COMPLETION,
    CHATPAD_TRANSPORT_UNKNOWN_COMPLETION,
    CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION,
    CHATPAD_TRANSPORT_EXECUTOR_FAILED
} ChatpadTransportResult;

typedef enum ChatpadTransportLifecycleState {
    CHATPAD_TRANSPORT_LIFECYCLE_INVALID = 0,
    CHATPAD_TRANSPORT_LIFECYCLE_INACTIVE,
    CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE,
    CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING,
    CHATPAD_TRANSPORT_LIFECYCLE_CLOSED
} ChatpadTransportLifecycleState;

typedef enum ChatpadTransportOperationType {
    CHATPAD_TRANSPORT_OPERATION_INVALID = 0,
    CHATPAD_TRANSPORT_OPERATION_ACTIVATION_REQUEST,
    CHATPAD_TRANSPORT_OPERATION_DELAY_METADATA
} ChatpadTransportOperationType;

typedef enum ChatpadTransportCompletionDisposition {
    CHATPAD_TRANSPORT_COMPLETION_INVALID = 0,
    CHATPAD_TRANSPORT_COMPLETION_ACCEPTED,
    CHATPAD_TRANSPORT_COMPLETION_STALE,
    CHATPAD_TRANSPORT_COMPLETION_DUPLICATE,
    CHATPAD_TRANSPORT_COMPLETION_UNKNOWN,
    CHATPAD_TRANSPORT_COMPLETION_CANCELLED
} ChatpadTransportCompletionDisposition;

typedef struct ChatpadTransportOperationToken {
    uint64_t DeviceGeneration;
    uint32_t OperationSequence;
} ChatpadTransportOperationToken;

typedef struct ChatpadTransportOperation {
    ChatpadTransportOperationType Type;
    uint64_t DeviceGeneration;
    uint32_t ActivationStepIndex;
    ChatpadTransportOperationToken Token;
    ChatpadActivationRequest Request;
    uint16_t DelayMilliseconds;
} ChatpadTransportOperation;

typedef ChatpadTransportResult (*ChatpadTransportOperationCallback)(
    void *context,
    const ChatpadTransportOperation *operation);

typedef struct ChatpadTransportOperationSink {
    void *Context;
    ChatpadTransportOperationCallback OnOperation;
} ChatpadTransportOperationSink;

typedef struct ChatpadTransportAdapterState {
    uint64_t CurrentGeneration;
    ChatpadTransportLifecycleState LifecycleState;
    uint8_t CancellationRequested;
    uint32_t NextOperationSequence;
    uint32_t AcceptedOperationCount;
    uint32_t CompletedOperationCount;
    uint32_t RejectedStaleOperationCount;
    uint64_t CompletedOperationMask;
} ChatpadTransportAdapterState;

typedef struct ChatpadTransportSnapshot {
    uint64_t CurrentGeneration;
    ChatpadTransportLifecycleState LifecycleState;
    uint8_t CancellationRequested;
    uint32_t NextOperationSequence;
    uint32_t AcceptedOperationCount;
    uint32_t CompletedOperationCount;
    uint32_t RejectedStaleOperationCount;
} ChatpadTransportSnapshot;

ChatpadTransportResult ChatpadTransportInitialize(ChatpadTransportAdapterState *state);

ChatpadTransportResult ChatpadTransportReset(ChatpadTransportAdapterState *state);

ChatpadTransportResult ChatpadTransportBeginGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation);

ChatpadTransportResult ChatpadTransportCancelGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation);

ChatpadTransportResult ChatpadTransportCloseGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation);

ChatpadTransportResult ChatpadTransportSubmitActivationRequest(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    uint32_t stepIndex,
    const ChatpadActivationRequest *request,
    ChatpadTransportOperation *operation);

ChatpadTransportResult ChatpadTransportSubmitDelayMetadata(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    uint32_t stepIndex,
    uint16_t delayMilliseconds,
    ChatpadTransportOperation *operation);

ChatpadTransportResult ChatpadTransportCompleteOperation(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    ChatpadTransportOperationToken token,
    ChatpadTransportCompletionDisposition *disposition);

ChatpadTransportResult ChatpadTransportGetSnapshot(
    const ChatpadTransportAdapterState *state,
    ChatpadTransportSnapshot *snapshot);

ChatpadTransportResult ChatpadTransportEmitActivationPlan(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    const ChatpadTransportOperationSink *sink,
    ChatpadActivationExecutionSummary *summary);

#ifdef __cplusplus
}
#endif

#endif
