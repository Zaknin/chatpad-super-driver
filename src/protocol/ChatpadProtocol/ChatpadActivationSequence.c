#include "ChatpadActivationSequence.h"

static void ChatpadClearActivationSequenceStep(ChatpadActivationSequenceStep *output)
{
    output->SequenceIndex = 0;
    output->RequestIndex = 0;
    output->Request.RawBmRequestType = 0;
    output->Request.RawRequest = 0;
    output->Request.RawValue = 0;
    output->Request.RawIndex = 0;
    output->Request.RawLength = 0;
    output->Request.Direction = CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE;
    output->Request.OutboundPayloadLength = 0;
    output->Request.ExpectedInboundDataLength = 0;
    output->Request.OutboundPayload[0] = 0;
    output->Request.OutboundPayload[1] = 0;
    output->DelayBeforeMilliseconds = 0;
    output->DelayAfterMilliseconds = 0;
}

static uint16_t ChatpadGetActivationSequenceDelayBeforeMilliseconds(size_t stepIndex)
{
    (void)stepIndex;
    return 0;
}

static uint16_t ChatpadGetActivationSequenceDelayAfterMilliseconds(size_t stepIndex)
{
    (void)stepIndex;
    return 12;
}

size_t ChatpadGetActivationSequenceStepCount(void)
{
    return ChatpadGetActivationRequestCount();
}

ChatpadActivationSequenceResult ChatpadGetActivationSequenceStep(
    size_t stepIndex,
    ChatpadActivationSequenceStep *output)
{
    ChatpadActivationRequest request;
    ChatpadActivationBuildResult buildResult;

    if (output == 0) {
        return CHATPAD_ACTIVATION_SEQUENCE_NULL_OUTPUT;
    }

    ChatpadClearActivationSequenceStep(output);

    if (stepIndex >= ChatpadGetActivationSequenceStepCount()) {
        return CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX;
    }

    buildResult = ChatpadBuildActivationRequest(stepIndex, &request);
    if (buildResult != CHATPAD_ACTIVATION_BUILD_OK) {
        return CHATPAD_ACTIVATION_SEQUENCE_REQUEST_BUILD_FAILED;
    }

    output->SequenceIndex = stepIndex;
    output->RequestIndex = stepIndex;
    output->Request = request;
    output->DelayBeforeMilliseconds = ChatpadGetActivationSequenceDelayBeforeMilliseconds(stepIndex);
    output->DelayAfterMilliseconds = ChatpadGetActivationSequenceDelayAfterMilliseconds(stepIndex);

    return CHATPAD_ACTIVATION_SEQUENCE_OK;
}
