#include "ChatpadActivationExecutor.h"

static void ChatpadClearActivationExecutionSummary(ChatpadActivationExecutionSummary *summary)
{
    summary->PlannedStepCount = 0;
    summary->EmittedRequestCount = 0;
    summary->EmittedDelayMetadataCount = 0;
    summary->LastCompletedStepIndex = CHATPAD_ACTIVATION_EXECUTION_NO_STEP;
    summary->RejectedOperation = CHATPAD_ACTIVATION_EXECUTION_OPERATION_NONE;
    summary->RejectedStepIndex = CHATPAD_ACTIVATION_EXECUTION_NO_STEP;
}

ChatpadActivationExecutionResult ChatpadExecuteActivationPlan(
    const ChatpadActivationExecutionSink *sink,
    ChatpadActivationExecutionSummary *summary)
{
    size_t stepCount;
    size_t stepIndex;

    if (sink == 0) {
        if (summary != 0) {
            ChatpadClearActivationExecutionSummary(summary);
        }
        return CHATPAD_ACTIVATION_EXECUTION_NULL_SINK;
    }

    if (summary == 0) {
        return CHATPAD_ACTIVATION_EXECUTION_NULL_SUMMARY;
    }

    ChatpadClearActivationExecutionSummary(summary);

    if (sink->OnRequest == 0) {
        return CHATPAD_ACTIVATION_EXECUTION_MISSING_REQUEST_CALLBACK;
    }

    if (sink->OnDelayMetadata == 0) {
        return CHATPAD_ACTIVATION_EXECUTION_MISSING_DELAY_CALLBACK;
    }

    stepCount = ChatpadGetActivationSequenceStepCount();
    summary->PlannedStepCount = stepCount;

    for (stepIndex = 0; stepIndex < stepCount; ++stepIndex) {
        ChatpadActivationSequenceStep step;
        ChatpadActivationSequenceResult plannerResult;
        ChatpadActivationExecutionCallbackResult callbackResult;

        plannerResult = ChatpadGetActivationSequenceStep(stepIndex, &step);
        if (plannerResult != CHATPAD_ACTIVATION_SEQUENCE_OK) {
            summary->RejectedOperation = CHATPAD_ACTIVATION_EXECUTION_OPERATION_PLANNER;
            summary->RejectedStepIndex = stepIndex;
            return CHATPAD_ACTIVATION_EXECUTION_PLANNER_FAILED;
        }

        callbackResult = sink->OnRequest(sink->Context, step.SequenceIndex, &step.Request);
        if (callbackResult != CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED) {
            summary->RejectedOperation = CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST;
            summary->RejectedStepIndex = step.SequenceIndex;
            return CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED;
        }
        ++summary->EmittedRequestCount;

        if (step.DelayAfterMilliseconds != 0) {
            callbackResult = sink->OnDelayMetadata(
                sink->Context,
                step.SequenceIndex,
                step.DelayAfterMilliseconds);
            if (callbackResult != CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED) {
                summary->RejectedOperation = CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA;
                summary->RejectedStepIndex = step.SequenceIndex;
                return CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED;
            }
            ++summary->EmittedDelayMetadataCount;
        }

        summary->LastCompletedStepIndex = step.SequenceIndex;
    }

    return CHATPAD_ACTIVATION_EXECUTION_OK;
}
