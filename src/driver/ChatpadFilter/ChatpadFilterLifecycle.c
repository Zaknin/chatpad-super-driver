#include "ChatpadFilterLifecycle.h"

static int
ChatpadFilterLifecycleIsMarked(
    const ChatpadFilterLifecycleState *state
    )
{
    return state != 0 &&
        state->Signature == CHATPAD_FILTER_LIFECYCLE_SIGNATURE &&
        state->Version == CHATPAD_FILTER_LIFECYCLE_VERSION;
}

static void
ChatpadFilterLifecycleClearSnapshot(
    ChatpadFilterLifecycleSnapshot *snapshot
    )
{
    if (snapshot == 0) {
        return;
    }

    snapshot->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET;
    snapshot->CurrentGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
    snapshot->NextGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
    snapshot->OutstandingOperationCount = 0u;
    snapshot->OperationAdmissionOpen = 0u;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleInitialize(
    ChatpadFilterLifecycleState *state
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }

    state->Signature = CHATPAD_FILTER_LIFECYCLE_SIGNATURE;
    state->Version = CHATPAD_FILTER_LIFECYCLE_VERSION;
    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET;
    state->CurrentGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
    state->NextGeneration = 1u;
    state->OutstandingOperationCount = 0u;
    state->OperationAdmissionOpen = 0u;

    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleMarkDeviceCreated(
    ChatpadFilterLifecycleState *state
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }

    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_CREATED;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecyclePrepareHardware(
    ChatpadFilterLifecycleState *state
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_CREATED) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }

    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED;
    state->CurrentGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
    state->OutstandingOperationCount = 0u;
    state->OperationAdmissionOpen = 0u;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleEnterD0(
    ChatpadFilterLifecycleState *state,
    uint64_t *generation
    )
{
    if (generation == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT;
    }
    *generation = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;

    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED &&
        state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_D0_STOPPED) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (state->NextGeneration == CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION ||
        state->NextGeneration == CHATPAD_FILTER_UINT64_MAX) {
        return CHATPAD_FILTER_LIFECYCLE_GENERATION_EXHAUSTED;
    }

    state->CurrentGeneration = state->NextGeneration;
    state->NextGeneration += 1u;
    state->OutstandingOperationCount = 0u;
    state->OperationAdmissionOpen = 1u;
    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE;
    *generation = state->CurrentGeneration;

    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleTryAcquireOperation(
    ChatpadFilterLifecycleState *state,
    uint64_t generation
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (generation == CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (state->OperationAdmissionOpen == 0u) {
        return CHATPAD_FILTER_LIFECYCLE_ADMISSION_CLOSED;
    }
    if (generation != state->CurrentGeneration) {
        return CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION;
    }
    if (state->OutstandingOperationCount == CHATPAD_FILTER_UINT32_MAX) {
        return CHATPAD_FILTER_LIFECYCLE_OUTSTANDING_OVERFLOW;
    }

    state->OutstandingOperationCount += 1u;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleReleaseOperation(
    ChatpadFilterLifecycleState *state,
    uint64_t generation
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (generation == CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID;
    }
    if (generation != state->CurrentGeneration) {
        return CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE &&
        state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (state->OutstandingOperationCount == 0u) {
        return CHATPAD_FILTER_LIFECYCLE_NO_OUTSTANDING_OPERATION;
    }

    state->OutstandingOperationCount -= 1u;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleBeginD0Rundown(
    ChatpadFilterLifecycleState *state,
    uint64_t generation
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (generation == CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (generation != state->CurrentGeneration) {
        return CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION;
    }

    state->OperationAdmissionOpen = 0u;
    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleCompleteD0Exit(
    ChatpadFilterLifecycleState *state,
    uint64_t generation
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (generation == CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID;
    }
    if (generation != state->CurrentGeneration) {
        return CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (state->OutstandingOperationCount != 0u) {
        return CHATPAD_FILTER_LIFECYCLE_RUNDOWN_INCOMPLETE;
    }

    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_D0_STOPPED;
    state->CurrentGeneration = CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION;
    state->OperationAdmissionOpen = 0u;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleReleaseHardware(
    ChatpadFilterLifecycleState *state
    )
{
    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }
    if (state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED &&
        state->Phase != CHATPAD_FILTER_LIFECYCLE_PHASE_D0_STOPPED) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }
    if (state->CurrentGeneration != CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION ||
        state->OperationAdmissionOpen != 0u ||
        state->OutstandingOperationCount != 0u) {
        return CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE;
    }

    state->Phase = CHATPAD_FILTER_LIFECYCLE_PHASE_RELEASED;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}

ChatpadFilterLifecycleResult
ChatpadFilterLifecycleGetSnapshot(
    const ChatpadFilterLifecycleState *state,
    ChatpadFilterLifecycleSnapshot *snapshot
    )
{
    if (snapshot == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT;
    }
    ChatpadFilterLifecycleClearSnapshot(snapshot);

    if (state == 0) {
        return CHATPAD_FILTER_LIFECYCLE_NULL_STATE;
    }
    if (!ChatpadFilterLifecycleIsMarked(state)) {
        return CHATPAD_FILTER_LIFECYCLE_NOT_MARKED;
    }

    snapshot->Phase = state->Phase;
    snapshot->CurrentGeneration = state->CurrentGeneration;
    snapshot->NextGeneration = state->NextGeneration;
    snapshot->OutstandingOperationCount = state->OutstandingOperationCount;
    snapshot->OperationAdmissionOpen = state->OperationAdmissionOpen;
    return CHATPAD_FILTER_LIFECYCLE_OK;
}
