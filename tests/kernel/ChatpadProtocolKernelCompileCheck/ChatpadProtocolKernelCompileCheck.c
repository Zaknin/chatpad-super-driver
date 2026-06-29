#include "ChatpadActivationRequests.h"
#include "ChatpadActivationExecutor.h"
#include "ChatpadActivationSequence.h"
#include "ChatpadKeyboardParser.h"
#include "ChatpadProtocolStateMachine.h"

typedef char ChatpadCompileCheckByteIsEightBits[(sizeof(ChatpadUInt8) == 1) ? 1 : -1];
typedef char ChatpadCompileCheckSizeMatchesPointer[(sizeof(ChatpadSize) == sizeof(void *)) ? 1 : -1];
typedef char ChatpadCompileCheckPacketLength[(CHATPAD_KEYBOARD_PACKET_LENGTH == 5) ? 1 : -1];

ChatpadParseResult ChatpadProtocolKernelCompileCheck(void)
{
    const ChatpadUInt8 input[CHATPAD_KEYBOARD_PACKET_LENGTH] = { 0, 0, 0, 0, 0 };
    ChatpadKeyboardPacket output;

    return ChatpadParseKeyboardPacket(input, CHATPAD_KEYBOARD_PACKET_LENGTH, &output);
}

ChatpadStateMachineResult ChatpadProtocolKernelStateMachineCompileCheck(void)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolTransition transition;
    ChatpadProtocolEvent event;
    ChatpadStateMachineResult result;

    result = ChatpadProtocolStateMachineInitialize(&stateMachine);
    if (result != CHATPAD_STATE_MACHINE_OK) {
        return result;
    }

    result = ChatpadProtocolEventFromParseResult(CHATPAD_PARSE_OK, &event);
    if (result != CHATPAD_STATE_MACHINE_OK) {
        return result;
    }

    return ChatpadProtocolStateMachineApply(&stateMachine, event, &transition);
}

ChatpadActivationBuildResult ChatpadProtocolKernelActivationRequestCompileCheck(void)
{
    ChatpadActivationRequest request;

    if (ChatpadGetActivationRequestCount() != CHATPAD_ACTIVATION_REQUEST_COUNT) {
        return CHATPAD_ACTIVATION_BUILD_INVALID_INDEX;
    }

    return ChatpadBuildActivationRequest(4u, &request);
}

ChatpadActivationSequenceResult ChatpadProtocolKernelActivationSequenceCompileCheck(void)
{
    ChatpadActivationSequenceStep step;

    if (ChatpadGetActivationSequenceStepCount() != ChatpadGetActivationRequestCount()) {
        return CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX;
    }

    return ChatpadGetActivationSequenceStep(4u, &step);
}

static ChatpadActivationExecutionCallbackResult ChatpadProtocolKernelActivationExecutorRequestCallback(
    void *context,
    size_t stepIndex,
    const ChatpadActivationRequest *request)
{
    (void)context;
    (void)stepIndex;
    (void)request;
    return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED;
}

static ChatpadActivationExecutionCallbackResult ChatpadProtocolKernelActivationExecutorDelayCallback(
    void *context,
    size_t stepIndex,
    uint16_t delayAfterMilliseconds)
{
    (void)context;
    (void)stepIndex;
    (void)delayAfterMilliseconds;
    return CHATPAD_ACTIVATION_EXECUTION_CALLBACK_ACCEPTED;
}

ChatpadActivationExecutionResult ChatpadProtocolKernelActivationExecutorCompileCheck(void)
{
    ChatpadActivationExecutionSink sink;
    ChatpadActivationExecutionSummary summary;

    sink.Context = 0;
    sink.OnRequest = ChatpadProtocolKernelActivationExecutorRequestCallback;
    sink.OnDelayMetadata = ChatpadProtocolKernelActivationExecutorDelayCallback;

    return ChatpadExecuteActivationPlan(&sink, &summary);
}
