#include "ChatpadFailOpenPolicy.h"

void ChatpadFailOpenInitialize(ChatpadFailOpenState *state)
{
    ChatpadFailOpenState zero = { 0 };
    if (state == 0) {
        return;
    }
    *state = zero;
    state->ControllerForwardingEnabled = 1;
    state->ChatpadFeatureEnabled = 1;
}

void ChatpadFailOpenBeginD0(ChatpadFailOpenState *state)
{
    if (state == 0) {
        return;
    }
    ++state->D0Generation;
    state->ActivationAttemptConsumed = 0;
    state->ActivationInProgress = 0;
    state->Removing = 0;
    state->VirtualKeyboardAvailable = 0;
    state->ChatpadFeatureEnabled = state->PermanentFailure == 0;
}

void ChatpadFailOpenForceReleaseAndFlush(ChatpadFailOpenState *state)
{
    if (state == 0) {
        return;
    }
    if (state->VirtualKeyboardAvailable != 0) {
        ++state->ForcedReleaseCount;
    }
    state->QueuedReportCount = 0u;
}

void ChatpadFailOpenEndD0(ChatpadFailOpenState *state)
{
    if (state == 0) {
        return;
    }
    ChatpadFailOpenForceReleaseAndFlush(state);
    state->ActivationInProgress = 0;
    state->VirtualKeyboardAvailable = 0;
    state->ChatpadFeatureEnabled = 0;
}

void ChatpadFailOpenRecordFailure(
    ChatpadFailOpenState *state,
    ChatpadOptionalFailureStage stage,
    ChatpadFailOpenInt32 status,
    int permanentFailure)
{
    if (state == 0 || stage == CHATPAD_OPTIONAL_STAGE_NONE) {
        return;
    }
    if (state->FirstFailureStage == CHATPAD_OPTIONAL_STAGE_NONE) {
        state->FirstFailureStage = stage;
        state->FirstFailureStatus = status;
    }
    ChatpadFailOpenForceReleaseAndFlush(state);
    state->VirtualKeyboardAvailable = 0;
    state->ChatpadFeatureEnabled = 0;
    if (permanentFailure != 0) {
        state->PermanentFailure = 1;
    }
    state->ControllerForwardingEnabled = 1;
}

ChatpadFailOpenInt32 ChatpadFailOpenPrepareHardwareResult(const ChatpadFailOpenState *state)
{
    (void)state;
    return 0;
}

ChatpadFailOpenInt32 ChatpadFailOpenD0EntryResult(const ChatpadFailOpenState *state)
{
    (void)state;
    return 0;
}

int ChatpadFailOpenTryBeginActivation(ChatpadFailOpenState *state)
{
    if (state == 0 || state->ChatpadFeatureEnabled == 0 ||
        state->Removing != 0 || state->ActivationAttemptConsumed != 0) {
        return 0;
    }
    state->ActivationAttemptConsumed = 1;
    state->ActivationInProgress = 1;
    return 1;
}

void ChatpadFailOpenCompleteActivation(ChatpadFailOpenState *state)
{
    if (state != 0) {
        state->ActivationInProgress = 0;
    }
}

void ChatpadFailOpenSetVirtualKeyboardAvailable(ChatpadFailOpenState *state, int available)
{
    if (state == 0) {
        return;
    }
    if (available == 0 && state->VirtualKeyboardAvailable != 0) {
        ChatpadFailOpenForceReleaseAndFlush(state);
    }
    state->VirtualKeyboardAvailable =
        available != 0 && state->ChatpadFeatureEnabled != 0 && state->Removing == 0;
}

int ChatpadFailOpenQueueKeyboardReport(ChatpadFailOpenState *state)
{
    if (state == 0 || state->ChatpadFeatureEnabled == 0 ||
        state->VirtualKeyboardAvailable == 0 || state->Removing != 0) {
        return 0;
    }
    if (state->QueuedReportCount >= CHATPAD_KEYBOARD_QUEUE_CAPACITY) {
        ChatpadFailOpenRecordFailure(
            state,
            CHATPAD_OPTIONAL_STAGE_KEYBOARD_QUEUE_OVERFLOW,
            -1,
            0);
        return 0;
    }
    ++state->QueuedReportCount;
    return 1;
}

void ChatpadFailOpenCompleteKeyboardReport(ChatpadFailOpenState *state)
{
    if (state != 0 && state->QueuedReportCount != 0u) {
        --state->QueuedReportCount;
    }
}

void ChatpadFailOpenBeginRemoval(ChatpadFailOpenState *state)
{
    if (state == 0) {
        return;
    }
    ChatpadFailOpenForceReleaseAndFlush(state);
    state->ActivationInProgress = 0;
    state->Removing = 1;
    state->VirtualKeyboardAvailable = 0;
    state->ChatpadFeatureEnabled = 0;
}
