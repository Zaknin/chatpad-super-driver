#ifndef CHATPAD_TRANSPORT_MOCK_H
#define CHATPAD_TRANSPORT_MOCK_H

#include "ChatpadTransportAdapter.h"

#define CHATPAD_TRANSPORT_MOCK_MAX_OPERATIONS ((uint32_t)16)

typedef struct ChatpadTransportMockSink {
    ChatpadTransportOperation Operations[CHATPAD_TRANSPORT_MOCK_MAX_OPERATIONS];
    uint32_t Capacity;
    uint32_t OperationCount;
    uint32_t RejectAtSequence;
    ChatpadTransportResult LastResult;
} ChatpadTransportMockSink;

static void ChatpadTransportMockInitialize(ChatpadTransportMockSink *mock)
{
    uint32_t index;

    mock->Capacity = CHATPAD_TRANSPORT_MOCK_MAX_OPERATIONS;
    mock->OperationCount = 0;
    mock->RejectAtSequence = 0;
    mock->LastResult = CHATPAD_TRANSPORT_OK;
    for (index = 0; index < CHATPAD_TRANSPORT_MOCK_MAX_OPERATIONS; ++index) {
        mock->Operations[index].Type = CHATPAD_TRANSPORT_OPERATION_INVALID;
        mock->Operations[index].DeviceGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
        mock->Operations[index].ActivationStepIndex = 0;
        mock->Operations[index].Token.DeviceGeneration = CHATPAD_TRANSPORT_INVALID_GENERATION;
        mock->Operations[index].Token.OperationSequence = CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE;
        mock->Operations[index].DelayMilliseconds = 0;
    }
}

static ChatpadTransportResult ChatpadTransportMockOnOperation(
    void *context,
    const ChatpadTransportOperation *operation)
{
    ChatpadTransportMockSink *mock = (ChatpadTransportMockSink *)context;

    if (mock == 0 || operation == 0) {
        return CHATPAD_TRANSPORT_NULL_OPERATION;
    }
    if (mock->RejectAtSequence != 0 &&
        operation->Token.OperationSequence == mock->RejectAtSequence) {
        mock->LastResult = CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
        return CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
    }
    if (mock->OperationCount >= mock->Capacity ||
        mock->OperationCount >= CHATPAD_TRANSPORT_MOCK_MAX_OPERATIONS) {
        mock->LastResult = CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
        return CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION;
    }

    mock->Operations[mock->OperationCount] = *operation;
    mock->OperationCount += 1u;
    mock->LastResult = CHATPAD_TRANSPORT_OK;
    return CHATPAD_TRANSPORT_OK;
}

static ChatpadTransportOperationSink ChatpadTransportMockCreateSink(ChatpadTransportMockSink *mock)
{
    ChatpadTransportOperationSink sink;

    sink.Context = mock;
    sink.OnOperation = ChatpadTransportMockOnOperation;
    return sink;
}

#endif
