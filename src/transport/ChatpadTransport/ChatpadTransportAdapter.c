#include "ChatpadTransportAdapter.h"

static void ChatpadTransportClearOperation(ChatpadTransportOperation *operation)
{
    if (operation != 0) {
        operation->Type = CHATPAD_TRANSPORT_OPERATION_INVALID;
        operation->DeviceGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
        operation->ActivationStepIndex = 0;
        operation->Token.DeviceGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
        operation->Token.OperationSequence = CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE;
        operation->Request.RawBmRequestType = 0;
        operation->Request.RawRequest = 0;
        operation->Request.RawValue = 0;
        operation->Request.RawIndex = 0;
        operation->Request.RawLength = 0;
        operation->Request.Direction = CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE;
        operation->Request.OutboundPayloadLength = 0;
        operation->Request.ExpectedInboundDataLength = 0;
        operation->Request.OutboundPayload[0] = 0;
        operation->Request.OutboundPayload[1] = 0;
        operation->DelayMilliseconds = 0;
    }
}

static void ChatpadTransportClearSnapshot(ChatpadTransportSnapshot *snapshot)
{
    if (snapshot != 0) {
        snapshot->CurrentGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
        snapshot->LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_INVALID;
        snapshot->CancellationRequested = 0;
        snapshot->NextOperationSequence = CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE;
        snapshot->AcceptedOperationCount = 0;
        snapshot->CompletedOperationCount = 0;
        snapshot->RejectedStaleOperationCount = 0;
    }
}

static void ChatpadTransportSetInactive(ChatpadTransportAdapterState *state)
{
    state->CurrentGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
    state->LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_INACTIVE;
    state->CancellationRequested = 0;
    state->NextOperationSequence = 1u;
    state->AcceptedOperationCount = 0;
    state->CompletedOperationCount = 0;
    state->RejectedStaleOperationCount = 0;
    state->CompletedOperationMask = 0;
}

static ChatpadTransportResult ChatpadTransportValidateActiveGeneration(
    const ChatpadTransportAdapterState *state,
    uint64_t generation)
{
    if (generation == CHATPAD_TRANSPORT_INVALID_GENERATION) {
        return CHATPAD_TRANSPORT_INVALID_GENERATION_ID;
    }
    if (state->CurrentGeneration != generation) {
        return CHATPAD_TRANSPORT_STALE_GENERATION;
    }
    if (state->LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING ||
        state->CancellationRequested != 0) {
        return CHATPAD_TRANSPORT_GENERATION_CANCELLED;
    }
    if (state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE) {
        return CHATPAD_TRANSPORT_INVALID_STATE;
    }
    return CHATPAD_TRANSPORT_OK;
}

static ChatpadTransportResult ChatpadTransportReserveOperation(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    uint32_t stepIndex,
    ChatpadTransportOperationType type,
    ChatpadTransportOperation *operation)
{
    ChatpadTransportResult result;

    if (state == 0) {
        ChatpadTransportClearOperation(operation);
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (operation == 0) {
        return CHATPAD_TRANSPORT_NULL_OUTPUT;
    }
    ChatpadTransportClearOperation(operation);

    result = ChatpadTransportValidateActiveGeneration(state, generation);
    if (result != CHATPAD_TRANSPORT_OK) {
        if (result == CHATPAD_TRANSPORT_STALE_GENERATION) {
            state->RejectedStaleOperationCount += 1u;
        }
        return result;
    }
    if (state->NextOperationSequence == CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE ||
        state->NextOperationSequence > CHATPAD_TRANSPORT_MAX_TRACKED_OPERATIONS) {
        return CHATPAD_TRANSPORT_INVALID_OPERATION;
    }

    operation->Type = type;
    operation->DeviceGeneration = generation;
    operation->ActivationStepIndex = stepIndex;
    operation->Token.DeviceGeneration = generation;
    operation->Token.OperationSequence = state->NextOperationSequence;

    state->NextOperationSequence += 1u;
    state->AcceptedOperationCount += 1u;

    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportInitialize(ChatpadTransportAdapterState *state)
{
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }

    ChatpadTransportSetInactive(state);
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportReset(ChatpadTransportAdapterState *state)
{
    return ChatpadTransportInitialize(state);
}

ChatpadTransportResult ChatpadTransportBeginGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation)
{
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (generation == CHATPAD_TRANSPORT_INVALID_GENERATION) {
        return CHATPAD_TRANSPORT_INVALID_GENERATION_ID;
    }
    if (state->LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE ||
        state->LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING) {
        return CHATPAD_TRANSPORT_ACTIVE_GENERATION_EXISTS;
    }

    state->CurrentGeneration = generation;
    state->LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE;
    state->CancellationRequested = 0;
    state->NextOperationSequence = 1u;
    state->AcceptedOperationCount = 0;
    state->CompletedOperationCount = 0;
    state->RejectedStaleOperationCount = 0;
    state->CompletedOperationMask = 0;

    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportCancelGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation)
{
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (generation == CHATPAD_TRANSPORT_INVALID_GENERATION) {
        return CHATPAD_TRANSPORT_INVALID_GENERATION_ID;
    }
    if (state->CurrentGeneration != generation) {
        state->RejectedStaleOperationCount += 1u;
        return CHATPAD_TRANSPORT_STALE_GENERATION;
    }
    if (state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE &&
        state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING) {
        return CHATPAD_TRANSPORT_INVALID_STATE;
    }

    state->LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING;
    state->CancellationRequested = 1u;
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportCloseGeneration(
    ChatpadTransportAdapterState *state,
    uint64_t generation)
{
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (generation == CHATPAD_TRANSPORT_INVALID_GENERATION) {
        return CHATPAD_TRANSPORT_INVALID_GENERATION_ID;
    }
    if (state->CurrentGeneration != generation) {
        state->RejectedStaleOperationCount += 1u;
        return CHATPAD_TRANSPORT_STALE_GENERATION;
    }
    if (state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE &&
        state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING) {
        return CHATPAD_TRANSPORT_INVALID_STATE;
    }

    state->LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_CLOSED;
    state->CancellationRequested = 1u;
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportSubmitActivationRequest(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    uint32_t stepIndex,
    const ChatpadActivationRequest *request,
    ChatpadTransportOperation *operation)
{
    ChatpadTransportResult result;

    if (request == 0) {
        ChatpadTransportClearOperation(operation);
        return CHATPAD_TRANSPORT_NULL_OPERATION;
    }

    result = ChatpadTransportReserveOperation(
        state,
        generation,
        stepIndex,
        CHATPAD_TRANSPORT_OPERATION_ACTIVATION_REQUEST,
        operation);
    if (result != CHATPAD_TRANSPORT_OK) {
        return result;
    }

    operation->Request = *request;
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportSubmitDelayMetadata(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    uint32_t stepIndex,
    uint16_t delayMilliseconds,
    ChatpadTransportOperation *operation)
{
    ChatpadTransportResult result;

    result = ChatpadTransportReserveOperation(
        state,
        generation,
        stepIndex,
        CHATPAD_TRANSPORT_OPERATION_DELAY_METADATA,
        operation);
    if (result != CHATPAD_TRANSPORT_OK) {
        return result;
    }

    operation->DelayMilliseconds = delayMilliseconds;
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportCompleteOperation(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    ChatpadTransportOperationToken token,
    ChatpadTransportCompletionDisposition *disposition)
{
    uint64_t mask;

    if (disposition != 0) {
        *disposition = CHATPAD_TRANSPORT_COMPLETION_INVALID;
    }
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (disposition == 0) {
        return CHATPAD_TRANSPORT_NULL_OUTPUT;
    }
    if (generation == CHATPAD_TRANSPORT_INVALID_GENERATION ||
        token.DeviceGeneration == CHATPAD_TRANSPORT_INVALID_GENERATION) {
        return CHATPAD_TRANSPORT_INVALID_GENERATION_ID;
    }
    if (generation != state->CurrentGeneration ||
        token.DeviceGeneration != state->CurrentGeneration) {
        *disposition = CHATPAD_TRANSPORT_COMPLETION_STALE;
        state->RejectedStaleOperationCount += 1u;
        return CHATPAD_TRANSPORT_STALE_COMPLETION;
    }
    if (state->LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING ||
        state->CancellationRequested != 0) {
        *disposition = CHATPAD_TRANSPORT_COMPLETION_CANCELLED;
        return CHATPAD_TRANSPORT_GENERATION_CANCELLED;
    }
    if (state->LifecycleState != CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE) {
        return CHATPAD_TRANSPORT_INVALID_STATE;
    }
    if (token.OperationSequence == CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE ||
        token.OperationSequence >= state->NextOperationSequence ||
        token.OperationSequence > CHATPAD_TRANSPORT_MAX_TRACKED_OPERATIONS) {
        *disposition = CHATPAD_TRANSPORT_COMPLETION_UNKNOWN;
        return CHATPAD_TRANSPORT_UNKNOWN_COMPLETION;
    }

    mask = UINT64_C(1) << (token.OperationSequence - 1u);
    if ((state->CompletedOperationMask & mask) != 0) {
        *disposition = CHATPAD_TRANSPORT_COMPLETION_DUPLICATE;
        return CHATPAD_TRANSPORT_DUPLICATE_COMPLETION;
    }

    state->CompletedOperationMask |= mask;
    state->CompletedOperationCount += 1u;
    *disposition = CHATPAD_TRANSPORT_COMPLETION_ACCEPTED;
    return CHATPAD_TRANSPORT_OK;
}

ChatpadTransportResult ChatpadTransportGetSnapshot(
    const ChatpadTransportAdapterState *state,
    ChatpadTransportSnapshot *snapshot)
{
    if (snapshot == 0) {
        return CHATPAD_TRANSPORT_NULL_OUTPUT;
    }
    ChatpadTransportClearSnapshot(snapshot);
    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }

    snapshot->CurrentGeneration = state->CurrentGeneration;
    snapshot->LifecycleState = state->LifecycleState;
    snapshot->CancellationRequested = state->CancellationRequested;
    snapshot->NextOperationSequence = state->NextOperationSequence;
    snapshot->AcceptedOperationCount = state->AcceptedOperationCount;
    snapshot->CompletedOperationCount = state->CompletedOperationCount;
    snapshot->RejectedStaleOperationCount = state->RejectedStaleOperationCount;
    return CHATPAD_TRANSPORT_OK;
}

typedef struct ChatpadTransportExecutorBridge {
    ChatpadTransportAdapterState *State;
    uint64_t Generation;
    const ChatpadTransportOperationSink *Sink;
    ChatpadTransportResult LastResult;
} ChatpadTransportExecutorBridge;

static ChatpadActivationExecutionCallbackResult ChatpadTransportEmitRequest(
    void *context,
    size_t stepIndex,
    const ChatpadActivationRequest *request)
{
    ChatpadTransportExecutorBridge *bridge = (ChatpadTransportExecutorBridge *)context;
    ChatpadTransportOperation operation;
    ChatpadTransportResult result;

    result = ChatpadTransportSubmitActivationRequest(
        bridge->State,
        bridge->Generation,
        (uint32_t)stepIndex,
        request,
        &operation);
    if (result == CHATPAD_TRANSPORT_OK) {
        result = bridge->Sink->OnOperation(bridge->Sink->Context, &operation);
        if (result != CHATPAD_TRANSPORT_OK) {
            result = CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
        }
    }
    bridge->LastResult = result;
    return result == CHATPAD_TRANSPORT_OK ?
        CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED :
        CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
}

static ChatpadActivationExecutionCallbackResult ChatpadTransportEmitDelay(
    void *context,
    size_t stepIndex,
    uint16_t delayMilliseconds)
{
    ChatpadTransportExecutorBridge *bridge = (ChatpadTransportExecutorBridge *)context;
    ChatpadTransportOperation operation;
    ChatpadTransportResult result;

    result = ChatpadTransportSubmitDelayMetadata(
        bridge->State,
        bridge->Generation,
        (uint32_t)stepIndex,
        delayMilliseconds,
        &operation);
    if (result == CHATPAD_TRANSPORT_OK) {
        result = bridge->Sink->OnOperation(bridge->Sink->Context, &operation);
        if (result != CHATPAD_TRANSPORT_OK) {
            result = CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
        }
    }
    bridge->LastResult = result;
    return result == CHATPAD_TRANSPORT_OK ?
        CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED :
        CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
}

ChatpadTransportResult ChatpadTransportEmitActivationPlan(
    ChatpadTransportAdapterState *state,
    uint64_t generation,
    const ChatpadTransportOperationSink *sink,
    ChatpadActivationExecutionSummary *summary)
{
    ChatpadActivationExecutionSink executorSink;
    ChatpadTransportExecutorBridge bridge;
    ChatpadActivationExecutionResult executorResult;
    ChatpadTransportResult activeResult;

    if (state == 0) {
        return CHATPAD_TRANSPORT_NULL_STATE;
    }
    if (sink == 0) {
        return CHATPAD_TRANSPORT_NULL_SINK;
    }
    if (sink->OnOperation == 0) {
        return CHATPAD_TRANSPORT_MISSING_OPERATION_CALLBACK;
    }

    activeResult = ChatpadTransportValidateActiveGeneration(state, generation);
    if (activeResult != CHATPAD_TRANSPORT_OK) {
        if (activeResult == CHATPAD_TRANSPORT_STALE_GENERATION) {
            state->RejectedStaleOperationCount += 1u;
        }
        return activeResult;
    }

    bridge.State = state;
    bridge.Generation = generation;
    bridge.Sink = sink;
    bridge.LastResult = CHATPAD_TRANSPORT_OK;

    executorSink.Context = &bridge;
    executorSink.OnRequest = ChatpadTransportEmitRequest;
    executorSink.OnDelayMetadata = ChatpadTransportEmitDelay;

    executorResult = ChatpadExecuteActivationPlan(&executorSink, summary);
    if (executorResult == CHATPAD_ACTIVATION_EXECUTION_OK) {
        return CHATPAD_TRANSPORT_OK;
    }
    if (bridge.LastResult != CHATPAD_TRANSPORT_OK) {
        return bridge.LastResult;
    }

    return CHATPAD_TRANSPORT_EXECUTOR_FAILED;
}
