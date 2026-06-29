#ifndef CHATPAD_ACTIVATION_EXECUTOR_H
#define CHATPAD_ACTIVATION_EXECUTOR_H

#include "ChatpadActivationSequence.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_ACTIVATION_EXECUTION_NO_STEP ((size_t)-1)

typedef enum ChatpadActivationExecutionResult {
    CHATPAD_ACTIVATION_EXECUTION_OK = 0,
    CHATPAD_ACTIVATION_EXECUTION_NULL_SINK,
    CHATPAD_ACTIVATION_EXECUTION_MISSING_REQUEST_CALLBACK,
    CHATPAD_ACTIVATION_EXECUTION_MISSING_DELAY_CALLBACK,
    CHATPAD_ACTIVATION_EXECUTION_NULL_SUMMARY,
    CHATPAD_ACTIVATION_EXECUTION_PLANNER_FAILED,
    CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED,
    CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED
} ChatpadActivationExecutionResult;

typedef enum ChatpadActivationExecutionCallbackResult {
    CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED = 0,
    CHATPAD_ACTIVATION_EXECUTION_CALLBACK_REJECTED
} ChatpadActivationExecutionCallbackResult;

typedef enum ChatpadActivationExecutionOperationKind {
    CHATPAD_ACTIVATION_EXECUTION_OPERATION_NONE = 0,
    CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST,
    CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA,
    CHATPAD_ACTIVATION_EXECUTION_OPERATION_PLANNER
} ChatpadActivationExecutionOperationKind;

typedef ChatpadActivationExecutionCallbackResult (*ChatpadActivationExecutionRequestCallback)(
    void *context,
    size_t stepIndex,
    const ChatpadActivationRequest *request);

typedef ChatpadActivationExecutionCallbackResult (*ChatpadActivationExecutionDelayMetadataCallback)(
    void *context,
    size_t stepIndex,
    uint16_t delayAfterMilliseconds);

typedef struct ChatpadActivationExecutionSink {
    void *Context;
    ChatpadActivationExecutionRequestCallback OnRequest;
    ChatpadActivationExecutionDelayMetadataCallback OnDelayMetadata;
} ChatpadActivationExecutionSink;

typedef struct ChatpadActivationExecutionSummary {
    size_t PlannedStepCount;
    size_t EmittedRequestCount;
    size_t EmittedDelayMetadataCount;
    size_t LastCompletedStepIndex;
    ChatpadActivationExecutionOperationKind RejectedOperation;
    size_t RejectedStepIndex;
} ChatpadActivationExecutionSummary;

ChatpadActivationExecutionResult ChatpadExecuteActivationPlan(
    const ChatpadActivationExecutionSink *sink,
    ChatpadActivationExecutionSummary *summary);

#ifdef __cplusplus
}
#endif

#endif
