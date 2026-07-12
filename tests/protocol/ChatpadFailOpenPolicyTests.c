#include "ChatpadFailOpenPolicyTests.h"

#include "ChatpadFailOpenPolicy.h"

#include <stdio.h>

static void Check(int condition, const char *name, ChatpadFailOpenPolicyTestSummary *summary)
{
    ++summary->Total;
    if (condition) {
        ++summary->Passed;
    } else {
        fprintf(stderr, "FAIL fail-open: %s\n", name);
    }
}

static void CheckForcedFailure(
    ChatpadOptionalFailureStage stage,
    ChatpadFailOpenPolicyTestSummary *summary)
{
    ChatpadFailOpenState state;
    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenSetVirtualKeyboardAvailable(&state, 1);
    ChatpadFailOpenRecordFailure(&state, stage, -1073741637, 0);
    Check(ChatpadFailOpenPrepareHardwareResult(&state) == 0, "PrepareHardware succeeds", summary);
    Check(ChatpadFailOpenD0EntryResult(&state) == 0, "D0Entry succeeds", summary);
    Check(state.ControllerForwardingEnabled == 1, "controller forwarding remains enabled", summary);
    Check(state.ChatpadFeatureEnabled == 0 && state.FirstFailureStage == stage,
        "specific Chatpad stage is disabled and retained", summary);
    Check(ChatpadFailOpenQueueKeyboardReport(&state) == 0,
        "failed optional stage produces no keyboard output", summary);
}

ChatpadFailOpenPolicyTestSummary RunChatpadFailOpenPolicyTests(void)
{
    static const ChatpadOptionalFailureStage forcedStages[] = {
        CHATPAD_OPTIONAL_STAGE_VIRTUAL_CHILD_CREATE,
        CHATPAD_OPTIONAL_STAGE_VHF_CREATE,
        CHATPAD_OPTIONAL_STAGE_VHF_START,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_WORKER_CREATE,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_1,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_2,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_3,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_4,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_5,
        CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_6,
        CHATPAD_OPTIONAL_STAGE_INTERFACE_PIPE_DISCOVERY,
        CHATPAD_OPTIONAL_STAGE_CONTINUOUS_READER_SETUP,
        CHATPAD_OPTIONAL_STAGE_KEEPALIVE,
        CHATPAD_OPTIONAL_STAGE_INPUT_READ,
        CHATPAD_OPTIONAL_STAGE_DECODER_INITIALIZATION,
        CHATPAD_OPTIONAL_STAGE_KEYBOARD_SUBMISSION
    };
    ChatpadFailOpenPolicyTestSummary summary = { 0, 0 };
    ChatpadFailOpenState state;
    size_t index;

    for (index = 0; index < sizeof(forcedStages) / sizeof(forcedStages[0]); ++index) {
        CheckForcedFailure(forcedStages[index], &summary);
    }

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    Check(ChatpadFailOpenTryBeginActivation(&state) == 1 &&
        ChatpadFailOpenTryBeginActivation(&state) == 0,
        "duplicate activation suppressed per D0 generation", &summary);
    ChatpadFailOpenEndD0(&state);
    Check(state.ActivationInProgress == 0,
        "D0 exit during activation cancels optional activation", &summary);
    ChatpadFailOpenBeginD0(&state);
    Check(ChatpadFailOpenTryBeginActivation(&state) == 1,
        "later D0 generation permits one new activation", &summary);
    ChatpadFailOpenRecordFailure(&state, CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_3, -1, 0);
    ChatpadFailOpenEndD0(&state);
    ChatpadFailOpenBeginD0(&state);
    Check(state.ChatpadFeatureEnabled == 1 && ChatpadFailOpenTryBeginActivation(&state) == 1,
        "transient activation failure can recover on D0 re-entry", &summary);

    ChatpadFailOpenRecordFailure(&state, CHATPAD_OPTIONAL_STAGE_VHF_CREATE, -1, 1);
    ChatpadFailOpenEndD0(&state);
    ChatpadFailOpenBeginD0(&state);
    Check(state.ChatpadFeatureEnabled == 0 && state.ControllerForwardingEnabled == 1,
        "permanent VHF unavailability remains fail-open", &summary);

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    (void)ChatpadFailOpenTryBeginActivation(&state);
    ChatpadFailOpenBeginRemoval(&state);
    Check(state.ActivationInProgress == 0 && state.ControllerForwardingEnabled == 1,
        "device removal during activation cancels without controller-path failure", &summary);

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenSetVirtualKeyboardAvailable(&state, 1);
    (void)ChatpadFailOpenQueueKeyboardReport(&state);
    ChatpadFailOpenSetVirtualKeyboardAvailable(&state, 0);
    Check(state.QueuedReportCount == 0u && state.ForcedReleaseCount == 1u,
        "virtual keyboard removal before physical removal releases and flushes", &summary);

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenEndD0(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenEndD0(&state);
    ChatpadFailOpenBeginD0(&state);
    Check(state.D0Generation == 3u && state.ActivationAttemptConsumed == 0,
        "repeated D0 transitions retain generation and reset one-shot gate", &summary);

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenSetVirtualKeyboardAvailable(&state, 1);
    Check(ChatpadFailOpenQueueKeyboardReport(&state) == 1, "keyboard report queues when available", &summary);
    ChatpadFailOpenBeginRemoval(&state);
    Check(state.QueuedReportCount == 0u && state.ForcedReleaseCount == 1u &&
        ChatpadFailOpenQueueKeyboardReport(&state) == 0,
        "virtual teardown forces release and flushes queued reports", &summary);
    Check(state.ControllerForwardingEnabled == 1,
        "physical removal before report completion preserves forwarding invariant", &summary);

    ChatpadFailOpenInitialize(&state);
    ChatpadFailOpenBeginD0(&state);
    ChatpadFailOpenSetVirtualKeyboardAvailable(&state, 1);
    for (index = 0; index < CHATPAD_KEYBOARD_QUEUE_CAPACITY; ++index) {
        (void)ChatpadFailOpenQueueKeyboardReport(&state);
    }
    Check(ChatpadFailOpenQueueKeyboardReport(&state) == 0 &&
        state.FirstFailureStage == CHATPAD_OPTIONAL_STAGE_KEYBOARD_QUEUE_OVERFLOW &&
        state.QueuedReportCount == 0u,
        "bounded queue overflow disables output and flushes", &summary);

    return summary;
}
