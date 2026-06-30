#include "ChatpadRequestOwnerModel.h"

#include <string.h>

#define A CHATPAD_REQUEST_OWNER_TRANSITION_ACCEPTED
#define I CHATPAD_REQUEST_OWNER_TRANSITION_IDEMPOTENT
#define R CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED
#define F CHATPAD_REQUEST_OWNER_TRANSITION_TO_FAULTED

static const uint8_t ChatpadRequestOwnerTransitionTable
    [CHATPAD_REQUEST_OWNER_STATE_COUNT][CHATPAD_REQUEST_OWNER_EVENT_COUNT] = {
    /* UNAVAILABLE */ { A, I, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, F },
    /* IDLE */        { I, A, A, A, R, R, R, R, R, R, R, R, R, R, R, R, R, A, F },
    /* PREPARING */   { R, R, R, R, A, A, R, R, R, R, R, A, R, R, R, R, R, A, F },
    /* READY */       { R, R, R, R, R, R, A, A, R, R, R, A, R, R, R, R, R, A, F },
    /* FORMATTED */   { R, R, R, R, R, R, R, R, A, R, R, A, R, R, R, R, R, A, F },
    /* SUBMITTING */  { R, R, R, R, R, R, R, R, R, A, A, A, R, R, A, R, R, A, R },
    /* IN_FLIGHT */   { R, R, R, R, R, R, R, R, R, R, R, A, R, R, A, R, R, A, R },
    /* CANCEL_CALLING */ { R, R, R, R, R, R, R, R, R, R, R, I, I, A, A, R, R, A, R },
    /* CANCEL_PENDING */ { R, R, R, R, R, R, R, R, R, R, R, I, A, R, A, R, R, A, R },
    /* COMPLETING */  { R, R, R, R, R, R, R, R, R, R, R, A, R, R, I, A, R, A, R },
    /* AWAITING_CALL_RETURN */ { R, R, R, R, R, R, R, R, R, A, F, I, I, A, I, R, R, A, R },
    /* RETIRING */    { R, R, R, R, R, R, R, R, R, R, R, R, R, R, I, R, A, A, R },
    /* DRAINING */    { A, A, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, I, F },
    /* FAULTED */     { R, A, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, R, I }
};

#undef A
#undef I
#undef R
#undef F

static void ChatpadRequestOwnerClearEffects(ChatpadRequestOwnerEffects *effects)
{
    if (effects != 0) {
        (void)memset(effects, 0, sizeof(*effects));
    }
}

static void ChatpadRequestOwnerClearEventValues(ChatpadRequestOwnerEvent *event)
{
    event->CurrentLifecycleGeneration = CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    event->OperationToken.DeviceGeneration = CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    event->OperationToken.OperationSequence = CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE;
    event->ActivationStepIndex = CHATPAD_REQUEST_OWNER_INVALID_STEP;
    event->CompletionClass = CHATPAD_REQUEST_OWNER_COMPLETION_NONE;
}

static void ChatpadRequestOwnerClearOperation(ChatpadActivationRequestOwner *owner)
{
    owner->LifecycleGeneration = CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    owner->OperationToken.DeviceGeneration = CHATPAD_REQUEST_OWNER_INVALID_GENERATION;
    owner->OperationToken.OperationSequence = CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE;
    owner->ActivationStepIndex = CHATPAD_REQUEST_OWNER_INVALID_STEP;
    owner->TerminalClass = CHATPAD_REQUEST_OWNER_COMPLETION_NONE;
    owner->RetirementOwner = CHATPAD_REQUEST_OWNER_RETIREMENT_NONE;
    owner->OperationActive = 0u;
    owner->LifecycleObligationHeld = 0u;
    owner->SubmissionPublished = 0u;
    owner->SendAccepted = 0u;
    owner->CompletionObserved = 0u;
    owner->CancellationRequested = 0u;
    owner->CancellationCallPublished = 0u;
    owner->SendCallPinned = 0u;
    owner->CancelCallPinned = 0u;
    owner->TerminalProcessed = 0u;
    owner->SequenceAdvanceEligible = 0u;
    owner->ReleaseEffectEmitted = 0u;
    owner->StaleCompletionObserved = 0u;
}

static void ChatpadRequestOwnerIncrementTransitionCount(ChatpadActivationRequestOwner *owner)
{
    if (owner->TransitionCount != UINT32_MAX) {
        owner->TransitionCount += 1u;
    }
}

static int ChatpadRequestOwnerIsMarked(const ChatpadActivationRequestOwner *owner)
{
    return owner != 0 &&
        owner->Signature == CHATPAD_REQUEST_OWNER_SIGNATURE &&
        owner->Version == CHATPAD_REQUEST_OWNER_VERSION;
}

static int ChatpadRequestOwnerIsActiveState(ChatpadRequestOwnerState state)
{
    return state >= CHATPAD_REQUEST_OWNER_STATE_PREPARING &&
        state <= CHATPAD_REQUEST_OWNER_STATE_RETIRING;
}

static int ChatpadRequestOwnerIdentityIsValid(const ChatpadRequestOwnerEvent *event)
{
    return event->CurrentLifecycleGeneration != CHATPAD_REQUEST_OWNER_INVALID_GENERATION &&
        event->OperationToken.DeviceGeneration == event->CurrentLifecycleGeneration &&
        event->OperationToken.OperationSequence != CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE &&
        event->ActivationStepIndex != CHATPAD_REQUEST_OWNER_INVALID_STEP;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerValidateOperationEvent(
    const ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    int compareCurrentGeneration)
{
    if (event->OperationToken.DeviceGeneration != owner->OperationToken.DeviceGeneration ||
        event->OperationToken.OperationSequence != owner->OperationToken.OperationSequence ||
        event->ActivationStepIndex != owner->ActivationStepIndex) {
        return CHATPAD_REQUEST_OWNER_OPERATION_MISMATCH;
    }
    if (compareCurrentGeneration != 0 &&
        event->CurrentLifecycleGeneration != owner->LifecycleGeneration) {
        return CHATPAD_REQUEST_OWNER_GENERATION_MISMATCH;
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerEmitRelease(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->LifecycleObligationHeld == 0u) {
        return CHATPAD_REQUEST_OWNER_NO_LIFECYCLE_OBLIGATION;
    }
    if (owner->ReleaseEffectEmitted != 0u) {
        return CHATPAD_REQUEST_OWNER_NO_LIFECYCLE_OBLIGATION;
    }
    owner->LifecycleObligationHeld = 0u;
    owner->ReleaseEffectEmitted = 1u;
    effects->ReleaseLifecycleAdmission = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static void ChatpadRequestOwnerPopulateTerminalSequenceEffects(
    const ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->SequenceAdvanceEligible != 0u) {
        effects->SequenceMayAdvance = 1u;
    }
    else {
        effects->SequenceMustAbort = 1u;
    }
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerRetireLocally(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerCompletionClass terminalClass,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult releaseResult;

    owner->TerminalClass = terminalClass;
    owner->TerminalProcessed = 1u;
    owner->RetirementOwner = CHATPAD_REQUEST_OWNER_RETIREMENT_INITIATOR;
    owner->SequenceAdvanceEligible = 0u;
    releaseResult = ChatpadRequestOwnerEmitRelease(owner, effects);
    if (releaseResult != CHATPAD_REQUEST_OWNER_OK) {
        return releaseResult;
    }
    owner->State = CHATPAD_REQUEST_OWNER_STATE_RETIRING;
    effects->InitiatorOwnsTerminalRetirement = 1u;
    effects->SequenceMustAbort = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

void ChatpadRequestOwnerEventInitialize(
    ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEventType type)
{
    if (event == 0) {
        return;
    }
    event->Type = type;
    ChatpadRequestOwnerClearEventValues(event);
}

ChatpadRequestOwnerResult ChatpadRequestOwnerInitialize(
    ChatpadActivationRequestOwner *owner)
{
    if (owner == 0) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    if (ChatpadRequestOwnerIsMarked(owner) &&
        (owner->OperationActive != 0u ||
         owner->LifecycleObligationHeld != 0u ||
         owner->SendCallPinned != 0u ||
         owner->CancelCallPinned != 0u)) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }

    (void)memset(owner, 0, sizeof(*owner));
    owner->Signature = CHATPAD_REQUEST_OWNER_SIGNATURE;
    owner->Version = CHATPAD_REQUEST_OWNER_VERSION;
    owner->State = CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE;
    owner->ActivationStepIndex = CHATPAD_REQUEST_OWNER_INVALID_STEP;
    return CHATPAD_REQUEST_OWNER_OK;
}

ChatpadRequestOwnerTransitionClass ChatpadRequestOwnerGetExpectedTransitionClass(
    ChatpadRequestOwnerState state,
    ChatpadRequestOwnerEventType eventType)
{
    if (state < CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE ||
        state >= CHATPAD_REQUEST_OWNER_STATE_COUNT ||
        eventType < CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE ||
        eventType >= CHATPAD_REQUEST_OWNER_EVENT_COUNT) {
        return CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED;
    }
    return (ChatpadRequestOwnerTransitionClass)
        ChatpadRequestOwnerTransitionTable[state][eventType];
}

ChatpadRequestOwnerTransitionClass ChatpadRequestOwnerClassifyResult(
    ChatpadRequestOwnerResult result)
{
    switch (result) {
    case CHATPAD_REQUEST_OWNER_OK:
    case CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN:
        return CHATPAD_REQUEST_OWNER_TRANSITION_ACCEPTED;
    case CHATPAD_REQUEST_OWNER_ACCEPTED_IDEMPOTENTLY:
    case CHATPAD_REQUEST_OWNER_ALREADY_DRAINING:
    case CHATPAD_REQUEST_OWNER_ALREADY_CANCELLED:
    case CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION:
    case CHATPAD_REQUEST_OWNER_SEND_CALL_ALREADY_PINNED:
    case CHATPAD_REQUEST_OWNER_CANCEL_CALL_ALREADY_PINNED:
        return CHATPAD_REQUEST_OWNER_TRANSITION_IDEMPOTENT;
    case CHATPAD_REQUEST_OWNER_TRANSITION_FAULTED:
        return CHATPAD_REQUEST_OWNER_TRANSITION_TO_FAULTED;
    default:
        return CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED;
    }
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerApplyIdempotent(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEventType eventType,
    ChatpadRequestOwnerEffects *effects)
{
    (void)effects;
    ChatpadRequestOwnerIncrementTransitionCount(owner);
    switch (eventType) {
    case CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN:
        return CHATPAD_REQUEST_OWNER_ALREADY_DRAINING;
    case CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION:
        return CHATPAD_REQUEST_OWNER_ALREADY_CANCELLED;
    case CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS:
        return CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION;
    case CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS:
        return CHATPAD_REQUEST_OWNER_SEND_CALL_ALREADY_PINNED;
    case CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS:
        return CHATPAD_REQUEST_OWNER_CANCEL_CALL_ALREADY_PINNED;
    default:
        return CHATPAD_REQUEST_OWNER_ACCEPTED_IDEMPOTENTLY;
    }
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerApplyFault(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult releaseResult = CHATPAD_REQUEST_OWNER_OK;

    if (owner->LifecycleObligationHeld != 0u) {
        releaseResult = ChatpadRequestOwnerEmitRelease(owner, effects);
    }
    if (releaseResult != CHATPAD_REQUEST_OWNER_OK) {
        return releaseResult;
    }
    ChatpadRequestOwnerClearOperation(owner);
    owner->State = CHATPAD_REQUEST_OWNER_STATE_FAULTED;
    owner->Available = 0u;
    owner->DrainingRequested = 0u;
    owner->ReuseEligible = 0u;
    owner->TerminalClass = CHATPAD_REQUEST_OWNER_COMPLETION_OWNER_FAULT;
    effects->SequenceMustAbort = 1u;
    effects->RecordDiagnosticFault = 1u;
    return CHATPAD_REQUEST_OWNER_TRANSITION_FAULTED;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleMakeAvailable(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerClearOperation(owner);
    owner->State = CHATPAD_REQUEST_OWNER_STATE_IDLE;
    owner->Available = 1u;
    owner->DrainingRequested = 0u;
    owner->ReuseEligible = 1u;
    effects->OwnerMayBeReused = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleMakeUnavailable(
    ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerClearOperation(owner);
    owner->State = CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE;
    owner->Available = 0u;
    owner->DrainingRequested = 0u;
    owner->ReuseEligible = 0u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleRequestAdmission(
    const ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->Available == 0u || owner->DrainingRequested != 0u ||
        owner->ReuseEligible == 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    if (!ChatpadRequestOwnerIdentityIsValid(event)) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    effects->AcquireLifecycleAdmission = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleBeginOperation(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    if (!ChatpadRequestOwnerIdentityIsValid(event)) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    owner->LifecycleGeneration = event->CurrentLifecycleGeneration;
    owner->OperationToken = event->OperationToken;
    owner->ActivationStepIndex = event->ActivationStepIndex;
    owner->OperationActive = 1u;
    owner->LifecycleObligationHeld = 1u;
    owner->ReuseEligible = 0u;
    owner->State = CHATPAD_REQUEST_OWNER_STATE_PREPARING;
    effects->CallerMayPrepare = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandlePreparationSucceeded(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 1);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->DrainingRequested != 0u || owner->CancellationRequested != 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->State = CHATPAD_REQUEST_OWNER_STATE_READY;
    effects->CallerMayFormat = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleFormattingSucceeded(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 1);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->DrainingRequested != 0u || owner->CancellationRequested != 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->State = CHATPAD_REQUEST_OWNER_STATE_FORMATTED;
    effects->CallerMayBeginSendCall = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleSendCallBegins(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 1);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->SendCallPinned != 0u) {
        return CHATPAD_REQUEST_OWNER_SEND_CALL_ALREADY_PINNED;
    }
    if (owner->DrainingRequested != 0u || owner->CancellationRequested != 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->SubmissionPublished = 1u;
    owner->SendCallPinned = 1u;
    owner->State = CHATPAD_REQUEST_OWNER_STATE_SUBMITTING;
    effects->CallerMayBeginSendCall = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleSendReturnedAccepted(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->SendCallPinned == 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->SendCallPinned = 0u;
    owner->SendAccepted = 1u;
    owner->RetirementOwner = CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION;
    effects->CompletionOwnsTerminalRetirement = 1u;

    if (owner->TerminalProcessed != 0u) {
        if (owner->CancelCallPinned != 0u) {
            owner->State = CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN;
            effects->WaitForCancelCallReturn = 1u;
            return CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN;
        }
        owner->State = CHATPAD_REQUEST_OWNER_STATE_RETIRING;
        ChatpadRequestOwnerPopulateTerminalSequenceEffects(owner, effects);
        return CHATPAD_REQUEST_OWNER_OK;
    }

    if (owner->CancellationRequested != 0u) {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING;
        effects->CallerMayBeginCancelCall = 1u;
    }
    else {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_IN_FLIGHT;
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleSendReturnedFalse(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->SendCallPinned == 0u || owner->CompletionObserved != 0u) {
        return ChatpadRequestOwnerApplyFault(owner, effects);
    }
    owner->SendCallPinned = 0u;
    owner->SendAccepted = 0u;
    return ChatpadRequestOwnerRetireLocally(
        owner,
        CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED,
        effects);
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleRequestCancellation(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->CancellationRequested != 0u) {
        return CHATPAD_REQUEST_OWNER_ALREADY_CANCELLED;
    }
    owner->CancellationRequested = 1u;
    owner->SequenceAdvanceEligible = 0u;
    effects->SequenceMustAbort = 1u;
    if (owner->SendAccepted != 0u && owner->TerminalProcessed == 0u) {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING;
        effects->CallerMayBeginCancelCall = 1u;
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleCancelCallBegins(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->CancelCallPinned != 0u) {
        return CHATPAD_REQUEST_OWNER_CANCEL_CALL_ALREADY_PINNED;
    }
    if (owner->CancellationRequested == 0u || owner->SendAccepted == 0u ||
        owner->TerminalProcessed != 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->CancellationCallPublished = 1u;
    owner->CancelCallPinned = 1u;
    owner->State = CHATPAD_REQUEST_OWNER_STATE_CANCEL_CALLING;
    effects->CallerMayBeginCancelCall = 1u;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleCancelCallReturned(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->CancelCallPinned == 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    owner->CancelCallPinned = 0u;
    if (owner->TerminalProcessed != 0u) {
        if (owner->SendCallPinned != 0u) {
            owner->State = CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN;
            effects->WaitForSendCallReturn = 1u;
            return CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN;
        }
        owner->State = CHATPAD_REQUEST_OWNER_STATE_RETIRING;
        ChatpadRequestOwnerPopulateTerminalSequenceEffects(owner, effects);
    }
    else {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING;
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleCompletionBegins(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event)
{
    ChatpadRequestOwnerResult validation =
        ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (owner->CompletionObserved != 0u || owner->TerminalProcessed != 0u) {
        return CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION;
    }
    owner->CompletionObserved = 1u;
    owner->SendAccepted = 1u;
    owner->RetirementOwner = CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION;
    owner->State = CHATPAD_REQUEST_OWNER_STATE_COMPLETING;
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleCompletionFinishes(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerResult validation;
    ChatpadRequestOwnerResult releaseResult;
    ChatpadRequestOwnerCompletionClass terminalClass;
    int stale;

    validation = ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
    if (validation != CHATPAD_REQUEST_OWNER_OK) {
        return validation;
    }
    if (event->CompletionClass <= CHATPAD_REQUEST_OWNER_COMPLETION_NONE ||
        event->CompletionClass > CHATPAD_REQUEST_OWNER_COMPLETION_INVALID_TRANSFER_LENGTH) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }

    stale = event->CurrentLifecycleGeneration != owner->LifecycleGeneration ||
        event->CompletionClass == CHATPAD_REQUEST_OWNER_COMPLETION_STALE_GENERATION;
    terminalClass = event->CompletionClass;
    if (stale) {
        terminalClass = CHATPAD_REQUEST_OWNER_COMPLETION_STALE_GENERATION;
        owner->StaleCompletionObserved = 1u;
        effects->StaleCompletionConsumed = 1u;
    }
    else if (owner->CancellationRequested != 0u) {
        terminalClass = CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED;
    }

    owner->TerminalClass = terminalClass;
    owner->TerminalProcessed = 1u;
    owner->RetirementOwner = CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION;
    owner->SequenceAdvanceEligible =
        terminalClass == CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS &&
        owner->CancellationRequested == 0u &&
        stale == 0;

    releaseResult = ChatpadRequestOwnerEmitRelease(owner, effects);
    if (releaseResult != CHATPAD_REQUEST_OWNER_OK) {
        return releaseResult;
    }
    effects->CompletionOwnsTerminalRetirement = 1u;

    if (owner->SendCallPinned != 0u || owner->CancelCallPinned != 0u) {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN;
        effects->WaitForSendCallReturn = owner->SendCallPinned;
        effects->WaitForCancelCallReturn = owner->CancelCallPinned;
        return CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN;
    }

    owner->State = CHATPAD_REQUEST_OWNER_STATE_RETIRING;
    ChatpadRequestOwnerPopulateTerminalSequenceEffects(owner, effects);
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleRetirementCompletes(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->LifecycleObligationHeld != 0u) {
        return CHATPAD_REQUEST_OWNER_NO_LIFECYCLE_OBLIGATION;
    }
    if (owner->SendCallPinned != 0u || owner->CancelCallPinned != 0u) {
        return CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN;
    }
    if (owner->TerminalProcessed == 0u) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }

    ChatpadRequestOwnerClearOperation(owner);
    if (owner->DrainingRequested != 0u) {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_DRAINING;
        owner->ReuseEligible = 0u;
    }
    else {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_IDLE;
        owner->ReuseEligible = 1u;
        effects->OwnerMayBeReused = 1u;
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

static ChatpadRequestOwnerResult ChatpadRequestOwnerHandleBeginDrain(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEffects *effects)
{
    if (owner->DrainingRequested != 0u ||
        owner->State == CHATPAD_REQUEST_OWNER_STATE_DRAINING) {
        return CHATPAD_REQUEST_OWNER_ALREADY_DRAINING;
    }
    owner->DrainingRequested = 1u;
    owner->ReuseEligible = 0u;
    effects->SequenceMustAbort = owner->OperationActive;
    if (owner->OperationActive == 0u) {
        owner->State = CHATPAD_REQUEST_OWNER_STATE_DRAINING;
    }
    else if (owner->SendAccepted != 0u && owner->TerminalProcessed == 0u) {
        owner->CancellationRequested = 1u;
        if (owner->SendCallPinned == 0u && owner->CancelCallPinned == 0u) {
            owner->State = CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING;
            effects->CallerMayBeginCancelCall = 1u;
        }
    }
    return CHATPAD_REQUEST_OWNER_OK;
}

ChatpadRequestOwnerResult ChatpadRequestOwnerDispatch(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerTransitionClass expectedClass;
    ChatpadRequestOwnerResult result;

    ChatpadRequestOwnerClearEffects(effects);
    if (owner == 0 || event == 0 || effects == 0) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    if (!ChatpadRequestOwnerIsMarked(owner)) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    if (event->Type < CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE ||
        event->Type >= CHATPAD_REQUEST_OWNER_EVENT_COUNT) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_FAULTED &&
        event->Type != CHATPAD_REQUEST_OWNER_EVENT_MAKE_UNAVAILABLE &&
        event->Type != CHATPAD_REQUEST_OWNER_EVENT_FAULT) {
        return CHATPAD_REQUEST_OWNER_OWNER_FAULTED;
    }

    expectedClass = ChatpadRequestOwnerGetExpectedTransitionClass(
        owner->State,
        event->Type);
    if (expectedClass == CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED) {
        return CHATPAD_REQUEST_OWNER_INVALID_STATE;
    }
    if (expectedClass == CHATPAD_REQUEST_OWNER_TRANSITION_IDEMPOTENT) {
        return ChatpadRequestOwnerApplyIdempotent(owner, event->Type, effects);
    }
    if (expectedClass == CHATPAD_REQUEST_OWNER_TRANSITION_TO_FAULTED) {
        result = ChatpadRequestOwnerApplyFault(owner, effects);
        if (result == CHATPAD_REQUEST_OWNER_TRANSITION_FAULTED) {
            ChatpadRequestOwnerIncrementTransitionCount(owner);
        }
        return result;
    }

    switch (event->Type) {
    case CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE:
        result = ChatpadRequestOwnerHandleMakeAvailable(owner, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_MAKE_UNAVAILABLE:
        result = ChatpadRequestOwnerHandleMakeUnavailable(owner);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_REQUEST_ADMISSION:
        result = ChatpadRequestOwnerHandleRequestAdmission(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION:
        result = ChatpadRequestOwnerHandleBeginOperation(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_SUCCEEDED:
        result = ChatpadRequestOwnerHandlePreparationSucceeded(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED:
        result = ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
        if (result == CHATPAD_REQUEST_OWNER_OK) {
            result = ChatpadRequestOwnerRetireLocally(
                owner,
                CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED,
                effects);
        }
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_SUCCEEDED:
        result = ChatpadRequestOwnerHandleFormattingSucceeded(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_FAILED:
        result = ChatpadRequestOwnerValidateOperationEvent(owner, event, 0);
        if (result == CHATPAD_REQUEST_OWNER_OK) {
            result = ChatpadRequestOwnerRetireLocally(
                owner,
                CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED,
                effects);
        }
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS:
        result = ChatpadRequestOwnerHandleSendCallBegins(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED:
        result = ChatpadRequestOwnerHandleSendReturnedAccepted(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_FALSE:
        result = ChatpadRequestOwnerHandleSendReturnedFalse(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION:
        result = ChatpadRequestOwnerHandleRequestCancellation(owner, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS:
        result = ChatpadRequestOwnerHandleCancelCallBegins(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_RETURNED:
        result = ChatpadRequestOwnerHandleCancelCallReturned(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS:
        result = ChatpadRequestOwnerHandleCompletionBegins(owner, event);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_FINISHES:
        result = ChatpadRequestOwnerHandleCompletionFinishes(owner, event, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES:
        result = ChatpadRequestOwnerHandleRetirementCompletes(owner, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN:
        result = ChatpadRequestOwnerHandleBeginDrain(owner, effects);
        break;
    case CHATPAD_REQUEST_OWNER_EVENT_FAULT:
        result = ChatpadRequestOwnerApplyFault(owner, effects);
        break;
    default:
        result = CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
        break;
    }

    if (ChatpadRequestOwnerClassifyResult(result) != CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED) {
        ChatpadRequestOwnerIncrementTransitionCount(owner);
    }
    return result;
}

ChatpadRequestOwnerResult ChatpadRequestOwnerGetSnapshot(
    const ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerSnapshot *snapshot)
{
    if (snapshot == 0) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }
    (void)memset(snapshot, 0, sizeof(*snapshot));
    snapshot->State = CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE;
    snapshot->ActivationStepIndex = CHATPAD_REQUEST_OWNER_INVALID_STEP;
    if (!ChatpadRequestOwnerIsMarked(owner)) {
        return CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT;
    }

    snapshot->State = owner->State;
    snapshot->LifecycleGeneration = owner->LifecycleGeneration;
    snapshot->OperationToken = owner->OperationToken;
    snapshot->ActivationStepIndex = owner->ActivationStepIndex;
    snapshot->TransitionCount = owner->TransitionCount;
    snapshot->TerminalClass = owner->TerminalClass;
    snapshot->RetirementOwner = owner->RetirementOwner;
    snapshot->Available = owner->Available;
    snapshot->DrainingRequested = owner->DrainingRequested;
    snapshot->OperationActive = owner->OperationActive;
    snapshot->LifecycleObligationHeld = owner->LifecycleObligationHeld;
    snapshot->SubmissionPublished = owner->SubmissionPublished;
    snapshot->SendAccepted = owner->SendAccepted;
    snapshot->CompletionObserved = owner->CompletionObserved;
    snapshot->CancellationRequested = owner->CancellationRequested;
    snapshot->CancellationCallPublished = owner->CancellationCallPublished;
    snapshot->SendCallPinned = owner->SendCallPinned;
    snapshot->CancelCallPinned = owner->CancelCallPinned;
    snapshot->TerminalProcessed = owner->TerminalProcessed;
    snapshot->SequenceAdvanceEligible = owner->SequenceAdvanceEligible;
    snapshot->ReuseEligible = owner->ReuseEligible;
    snapshot->ReleaseEffectEmitted = owner->ReleaseEffectEmitted;
    snapshot->StaleCompletionObserved = owner->StaleCompletionObserved;
    return CHATPAD_REQUEST_OWNER_OK;
}

ChatpadRequestOwnerInvariantResult ChatpadRequestOwnerValidateInvariant(
    const ChatpadActivationRequestOwner *owner)
{
    int activeState;

    if (owner == 0) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_NULL_OWNER;
    }
    if (!ChatpadRequestOwnerIsMarked(owner)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_INVALID_SIGNATURE;
    }
    if (owner->State < CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE ||
        owner->State >= CHATPAD_REQUEST_OWNER_STATE_COUNT) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_INVALID_STATE;
    }
    if ((owner->State == CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE ||
         owner->State == CHATPAD_REQUEST_OWNER_STATE_FAULTED) &&
        owner->Available != 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_AVAILABILITY_MISMATCH;
    }
    if (owner->State != CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE &&
        owner->State != CHATPAD_REQUEST_OWNER_STATE_FAULTED &&
        owner->Available == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_AVAILABILITY_MISMATCH;
    }

    activeState = ChatpadRequestOwnerIsActiveState(owner->State);
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_IDLE &&
        (owner->OperationActive != 0u ||
         owner->LifecycleGeneration != CHATPAD_REQUEST_OWNER_INVALID_GENERATION ||
         owner->LifecycleObligationHeld != 0u ||
         owner->SendCallPinned != 0u ||
         owner->CancelCallPinned != 0u)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_IDLE_OWNS_OPERATION;
    }
    if (activeState && owner->OperationActive == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_ACTIVE_MISSING_IDENTITY;
    }
    if (owner->OperationActive != 0u &&
        owner->OperationToken.OperationSequence == CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_ACTIVE_MISSING_IDENTITY;
    }
    if (owner->OperationActive != 0u &&
        (owner->LifecycleGeneration == CHATPAD_REQUEST_OWNER_INVALID_GENERATION ||
         owner->OperationToken.DeviceGeneration != owner->LifecycleGeneration)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_ACTIVE_MISSING_GENERATION;
    }
    if (owner->LifecycleObligationHeld != 0u && owner->OperationActive == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_OBLIGATION_WITHOUT_OPERATION;
    }
    if (owner->LifecycleObligationHeld != 0u && owner->ReleaseEffectEmitted != 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_RELEASE_DUPLICATION;
    }
    if (owner->ReuseEligible != 0u &&
        (owner->SendCallPinned != 0u || owner->CancelCallPinned != 0u)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_PIN;
    }
    if (owner->ReuseEligible != 0u && owner->LifecycleObligationHeld != 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_OBLIGATION;
    }
    if (owner->ReuseEligible != 0u && owner->OperationActive != 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_OPERATION;
    }
    if (owner->SequenceAdvanceEligible != 0u &&
        (owner->TerminalProcessed == 0u ||
         owner->TerminalClass != CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS ||
         owner->CancellationRequested != 0u ||
         owner->StaleCompletionObserved != 0u)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_ADVANCE_WITHOUT_SUCCESS;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_SUBMITTING &&
        owner->SendCallPinned == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_SUBMITTING_WITHOUT_SEND_PIN;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_CANCEL_CALLING &&
        owner->CancelCallPinned == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_CANCEL_CALLING_WITHOUT_PIN;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_COMPLETING &&
        owner->CompletionObserved == 0u) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_COMPLETING_WITHOUT_COMPLETION;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN &&
        (owner->SendCallPinned == 0u && owner->CancelCallPinned == 0u)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_AWAITING_WITHOUT_PIN;
    }
    if (owner->State == CHATPAD_REQUEST_OWNER_STATE_RETIRING &&
        (owner->TerminalProcessed == 0u ||
         owner->LifecycleObligationHeld != 0u ||
         owner->SendCallPinned != 0u ||
         owner->CancelCallPinned != 0u)) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_RETIRING_NOT_TERMINAL;
    }
    if (owner->SendAccepted != 0u && owner->TerminalProcessed == 0u &&
        owner->RetirementOwner != CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_RETIREMENT_OWNER_MISMATCH;
    }
    if (owner->SendAccepted == 0u && owner->TerminalProcessed != 0u &&
        owner->RetirementOwner == CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION) {
        return CHATPAD_REQUEST_OWNER_INVARIANT_RETIREMENT_OWNER_MISMATCH;
    }
    return CHATPAD_REQUEST_OWNER_INVARIANT_OK;
}
