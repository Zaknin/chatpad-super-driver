#ifndef CHATPAD_ACTIVATION_SEQUENCE_H
#define CHATPAD_ACTIVATION_SEQUENCE_H

#include "ChatpadActivationRequests.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT CHATPAD_ACTIVATION_REQUEST_COUNT

typedef enum ChatpadActivationSequenceResult {
    CHATPAD_ACTIVATION_SEQUENCE_OK = 0,
    CHATPAD_ACTIVATION_SEQUENCE_NULL_OUTPUT,
    CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX,
    CHATPAD_ACTIVATION_SEQUENCE_REQUEST_BUILD_FAILED
} ChatpadActivationSequenceResult;

typedef struct ChatpadActivationSequenceStep {
    size_t SequenceIndex;
    size_t RequestIndex;
    ChatpadActivationRequest Request;
    uint16_t DelayBeforeMilliseconds;
    uint16_t DelayAfterMilliseconds;
} ChatpadActivationSequenceStep;

size_t ChatpadGetActivationSequenceStepCount(void);

ChatpadActivationSequenceResult ChatpadGetActivationSequenceStep(
    size_t stepIndex,
    ChatpadActivationSequenceStep *output);

#ifdef __cplusplus
}
#endif

#endif
