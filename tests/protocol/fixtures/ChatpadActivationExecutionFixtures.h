#ifndef CHATPAD_ACTIVATION_EXECUTION_FIXTURES_H
#define CHATPAD_ACTIVATION_EXECUTION_FIXTURES_H

#include <stddef.h>
#include <stdint.h>

#include "ChatpadActivationExecutor.h"

#define CHATPAD_ACTIVATION_EXECUTION_FIXTURE_CAPACITY ((size_t)12)
#define CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION ((size_t)-1)

typedef enum ChatpadActivationRecorderOperationKind {
    CHATPAD_ACTIVATION_RECORDER_OPERATION_NONE = 0,
    CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST,
    CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA
} ChatpadActivationRecorderOperationKind;

typedef struct ChatpadActivationRecordedOperation {
    ChatpadActivationRecorderOperationKind Kind;
    size_t SequencePosition;
    size_t StepIndex;
    ChatpadActivationRequest Request;
    uint16_t DelayAfterMilliseconds;
} ChatpadActivationRecordedOperation;

typedef struct ChatpadActivationExecutionRecorder {
    ChatpadActivationRecordedOperation Records[CHATPAD_ACTIVATION_EXECUTION_FIXTURE_CAPACITY];
    size_t Capacity;
    size_t AcceptedOperationCount;
    size_t CallbackAttemptCount;
    size_t RequestAttemptCount;
    size_t DelayAttemptCount;
    size_t RejectSequencePosition;
    ChatpadActivationRecorderOperationKind RejectKind;
    size_t RejectStepIndex;
    ChatpadActivationRecorderOperationKind LastRejectedKind;
    size_t LastRejectedStepIndex;
    size_t LastRejectedSequencePosition;
} ChatpadActivationExecutionRecorder;

static void ChatpadActivationExecutionRecorderInitialize(ChatpadActivationExecutionRecorder *recorder)
{
    size_t index;

    recorder->Capacity = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_CAPACITY;
    recorder->AcceptedOperationCount = 0;
    recorder->CallbackAttemptCount = 0;
    recorder->RequestAttemptCount = 0;
    recorder->DelayAttemptCount = 0;
    recorder->RejectSequencePosition = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;
    recorder->RejectKind = CHATPAD_ACTIVATION_RECORDER_OPERATION_NONE;
    recorder->RejectStepIndex = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;
    recorder->LastRejectedKind = CHATPAD_ACTIVATION_RECORDER_OPERATION_NONE;
    recorder->LastRejectedStepIndex = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;
    recorder->LastRejectedSequencePosition = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;

    for (index = 0; index < CHATPAD_ACTIVATION_EXECUTION_FIXTURE_CAPACITY; ++index) {
        recorder->Records[index].Kind = CHATPAD_ACTIVATION_RECORDER_OPERATION_NONE;
        recorder->Records[index].SequencePosition = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;
        recorder->Records[index].StepIndex = CHATPAD_ACTIVATION_EXECUTION_FIXTURE_NO_REJECTION;
        recorder->Records[index].Request.RawBmRequestType = 0;
        recorder->Records[index].Request.RawRequest = 0;
        recorder->Records[index].Request.RawValue = 0;
        recorder->Records[index].Request.RawIndex = 0;
        recorder->Records[index].Request.RawLength = 0;
        recorder->Records[index].Request.Direction = CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE;
        recorder->Records[index].Request.OutboundPayloadLength = 0;
        recorder->Records[index].Request.ExpectedInboundDataLength = 0;
        recorder->Records[index].Request.OutboundPayload[0] = 0;
        recorder->Records[index].Request.OutboundPayload[1] = 0;
        recorder->Records[index].DelayAfterMilliseconds = 0;
    }
}

static int ChatpadActivationExecutionRecorderShouldReject(
    ChatpadActivationExecutionRecorder *recorder,
    ChatpadActivationRecorderOperationKind kind,
    size_t stepIndex,
    size_t sequencePosition)
{
    if (recorder->RejectSequencePosition == sequencePosition ||
        (recorder->RejectKind == kind && recorder->RejectStepIndex == stepIndex)) {
        recorder->LastRejectedKind = kind;
        recorder->LastRejectedStepIndex = stepIndex;
        recorder->LastRejectedSequencePosition = sequencePosition;
        return 1;
    }

    if (recorder->AcceptedOperationCount >= recorder->Capacity) {
        recorder->LastRejectedKind = kind;
        recorder->LastRejectedStepIndex = stepIndex;
        recorder->LastRejectedSequencePosition = sequencePosition;
        return 1;
    }

    return 0;
}

static ChatpadActivationExecutionCallbackResult ChatpadActivationExecutionRecorderOnRequest(
    void *context,
    size_t stepIndex,
    const ChatpadActivationRequest *request)
{
    ChatpadActivationExecutionRecorder *recorder;
    ChatpadActivationRecordedOperation *record;
    size_t sequencePosition;

    if (context == 0 || request == 0) {
        return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
    }

    recorder = (ChatpadActivationExecutionRecorder *)context;
    sequencePosition = recorder->CallbackAttemptCount;
    ++recorder->CallbackAttemptCount;
    ++recorder->RequestAttemptCount;

    if (ChatpadActivationExecutionRecorderShouldReject(
            recorder,
            CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST,
            stepIndex,
            sequencePosition) != 0) {
        return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
    }

    record = &recorder->Records[recorder->AcceptedOperationCount];
    record->Kind = CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST;
    record->SequencePosition = sequencePosition;
    record->StepIndex = stepIndex;
    record->Request = *request;
    record->DelayAfterMilliseconds = 0;
    ++recorder->AcceptedOperationCount;

    return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED;
}

static ChatpadActivationExecutionCallbackResult ChatpadActivationExecutionRecorderOnDelayMetadata(
    void *context,
    size_t stepIndex,
    uint16_t delayAfterMilliseconds)
{
    ChatpadActivationExecutionRecorder *recorder;
    ChatpadActivationRecordedOperation *record;
    size_t sequencePosition;

    if (context == 0) {
        return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
    }

    recorder = (ChatpadActivationExecutionRecorder *)context;
    sequencePosition = recorder->CallbackAttemptCount;
    ++recorder->CallbackAttemptCount;
    ++recorder->DelayAttemptCount;

    if (ChatpadActivationExecutionRecorderShouldReject(
            recorder,
            CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA,
            stepIndex,
            sequencePosition) != 0) {
        return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED;
    }

    record = &recorder->Records[recorder->AcceptedOperationCount];
    record->Kind = CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA;
    record->SequencePosition = sequencePosition;
    record->StepIndex = stepIndex;
    record->Request.RawBmRequestType = 0;
    record->Request.RawRequest = 0;
    record->Request.RawValue = 0;
    record->Request.RawIndex = 0;
    record->Request.RawLength = 0;
    record->Request.Direction = CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE;
    record->Request.OutboundPayloadLength = 0;
    record->Request.ExpectedInboundDataLength = 0;
    record->Request.OutboundPayload[0] = 0;
    record->Request.OutboundPayload[1] = 0;
    record->DelayAfterMilliseconds = delayAfterMilliseconds;
    ++recorder->AcceptedOperationCount;

    return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED;
}

static ChatpadActivationExecutionSink ChatpadActivationExecutionRecorderCreateSink(
    ChatpadActivationExecutionRecorder *recorder)
{
    ChatpadActivationExecutionSink sink;

    sink.Context = recorder;
    sink.OnRequest = ChatpadActivationExecutionRecorderOnRequest;
    sink.OnDelayMetadata = ChatpadActivationExecutionRecorderOnDelayMetadata;

    return sink;
}

#endif
