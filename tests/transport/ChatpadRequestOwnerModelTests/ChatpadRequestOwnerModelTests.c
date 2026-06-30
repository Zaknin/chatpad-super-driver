#include <stdio.h>
#include <string.h>

#include "ChatpadRequestOwnerModel.h"

#define EXPLORATION_MAX_NODES 4096u
#define EXPLORATION_MAX_DEPTH 10u

typedef struct ExplorationNode {
    ChatpadActivationRequestOwner Owner;
    uint32_t Depth;
    uint32_t ReleaseCountForOperation;
} ExplorationNode;

static uint32_t g_totalAssertions;
static uint32_t g_failedAssertions;
static uint32_t g_scenarioCount;
static uint32_t g_classificationAccepted;
static uint32_t g_classificationIdempotent;
static uint32_t g_classificationRejected;
static uint32_t g_classificationFaulting;
static uint32_t g_explorationAttempts;
static uint32_t g_explorationUniqueSnapshots;

static const ChatpadRequestOwnerEventType g_allEventTypes[CHATPAD_REQUEST_OWNER_EVENT_COUNT] = {
    CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE,
    CHATPAD_REQUEST_OWNER_EVENT_MAKE_UNAVAILABLE,
    CHATPAD_REQUEST_OWNER_EVENT_REQUEST_ADMISSION,
    CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION,
    CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_SUCCEEDED,
    CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
    CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_SUCCEEDED,
    CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_FAILED,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_FALSE,
    CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
    CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_RETURNED,
    CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_FINISHES,
    CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
    CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
    CHATPAD_REQUEST_OWNER_EVENT_FAULT
};

static void RecordAssertion(const char *name, int passed)
{
    g_totalAssertions += 1u;
    if (!passed) {
        g_failedAssertions += 1u;
        (void)printf("FAIL: %s\n", name);
    }
}

static void BeginScenario(const char *name)
{
    g_scenarioCount += 1u;
    RecordAssertion(name, name != 0 && name[0] != '\0');
}

static int EffectsAreClear(const ChatpadRequestOwnerEffects *effects)
{
    const unsigned char *bytes = (const unsigned char *)effects;
    size_t index;
    for (index = 0u; index < sizeof(*effects); ++index) {
        if (bytes[index] != 0u) {
            return 0;
        }
    }
    return 1;
}

static void ExpectResult(
    const char *name,
    ChatpadRequestOwnerResult actual,
    ChatpadRequestOwnerResult expected)
{
    RecordAssertion(name, actual == expected);
}

static void ExpectState(
    const char *name,
    const ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerState expected)
{
    RecordAssertion(name, owner->State == expected);
}

static void ExpectInvariant(const char *name, const ChatpadActivationRequestOwner *owner)
{
    RecordAssertion(
        name,
        ChatpadRequestOwnerValidateInvariant(owner) == CHATPAD_REQUEST_OWNER_INVARIANT_OK);
}

static void FillEventForOwner(
    const ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEventType type,
    ChatpadRequestOwnerEvent *event)
{
    ChatpadRequestOwnerEventInitialize(event, type);
    event->CurrentLifecycleGeneration = 1u;
    event->OperationToken.DeviceGeneration = 1u;
    event->OperationToken.OperationSequence = 1u;
    event->ActivationStepIndex = 0u;
    event->CompletionClass = CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS;
    if (owner != 0 && owner->OperationActive != 0u) {
        event->CurrentLifecycleGeneration = owner->LifecycleGeneration;
        event->OperationToken = owner->OperationToken;
        event->ActivationStepIndex = owner->ActivationStepIndex;
    }
}

static ChatpadRequestOwnerResult Dispatch(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerEventType type,
    ChatpadRequestOwnerCompletionClass completionClass,
    uint64_t currentGeneration,
    ChatpadRequestOwnerEffects *effects)
{
    ChatpadRequestOwnerEvent event;
    FillEventForOwner(owner, type, &event);
    if (completionClass != CHATPAD_REQUEST_OWNER_COMPLETION_NONE) {
        event.CompletionClass = completionClass;
    }
    if (currentGeneration != CHATPAD_REQUEST_OWNER_INVALID_GENERATION) {
        event.CurrentLifecycleGeneration = currentGeneration;
    }
    return ChatpadRequestOwnerDispatch(owner, &event, effects);
}

static void InitializeAvailable(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    (void)memset(owner, 0, sizeof(*owner));
    (void)ChatpadRequestOwnerInitialize(owner);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static void BeginOperation(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_REQUEST_ADMISSION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static void BuildToReady(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    InitializeAvailable(owner);
    BeginOperation(owner);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_SUCCEEDED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static void BuildToFormatted(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    BuildToReady(owner);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_SUCCEEDED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static void BuildToSubmitting(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    BuildToFormatted(owner);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static void BuildToInFlight(ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;
    BuildToSubmitting(owner);
    (void)Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &effects);
}

static ChatpadRequestOwnerResult FinishCompletion(
    ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerCompletionClass completionClass,
    uint64_t currentGeneration,
    ChatpadRequestOwnerEffects *finishEffects)
{
    ChatpadRequestOwnerEffects beginEffects;
    ChatpadRequestOwnerResult beginResult;
    beginResult = Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE,
        CHATPAD_REQUEST_OWNER_INVALID_GENERATION,
        &beginEffects);
    if (beginResult != CHATPAD_REQUEST_OWNER_OK) {
        return beginResult;
    }
    return Dispatch(
        owner,
        CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_FINISHES,
        completionClass,
        currentGeneration,
        finishEffects);
}

static void BuildCanonicalState(
    ChatpadRequestOwnerState target,
    ChatpadActivationRequestOwner *owner)
{
    ChatpadRequestOwnerEffects effects;

    (void)memset(owner, 0, sizeof(*owner));
    (void)ChatpadRequestOwnerInitialize(owner);
    if (target == CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE) {
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_IDLE) {
        return;
    }
    if (target == CHATPAD_REQUEST_OWNER_STATE_DRAINING) {
        (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
            CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
        return;
    }
    if (target == CHATPAD_REQUEST_OWNER_STATE_FAULTED) {
        (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_FAULT,
            CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
        return;
    }

    BeginOperation(owner);
    if (target == CHATPAD_REQUEST_OWNER_STATE_PREPARING) {
        return;
    }
    if (target == CHATPAD_REQUEST_OWNER_STATE_RETIRING) {
        (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
            CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_SUCCEEDED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_READY) {
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_SUCCEEDED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_FORMATTED) {
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_SUBMITTING) {
        return;
    }
    if (target == CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN) {
        (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
            CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
        (void)FinishCompletion(owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
        owner->CancelCallPinned = 1u;
        owner->CancellationCallPublished = 1u;
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_IN_FLIGHT) {
        return;
    }
    if (target == CHATPAD_REQUEST_OWNER_STATE_COMPLETING) {
        (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
            CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING) {
        return;
    }
    (void)Dispatch(owner, CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    if (target == CHATPAD_REQUEST_OWNER_STATE_CANCEL_CALLING) {
        return;
    }
}

static void TestInitializationSnapshotAndInvariants(void)
{
    ChatpadActivationRequestOwner owner;
    ChatpadRequestOwnerSnapshot snapshot;
    ChatpadRequestOwnerEvent event;
    ChatpadRequestOwnerEffects effects;

    (void)memset(&owner, 0, sizeof(owner));
    ExpectResult("initialize null rejected", ChatpadRequestOwnerInitialize(0),
        CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT);
    ExpectResult("initialize owner", ChatpadRequestOwnerInitialize(&owner),
        CHATPAD_REQUEST_OWNER_OK);
    ExpectState("initialized unavailable", &owner, CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE);
    RecordAssertion("initialized no generation", owner.LifecycleGeneration == 0u);
    RecordAssertion("initialized no operation", owner.OperationActive == 0u);
    RecordAssertion("initialized invalid step", owner.ActivationStepIndex == CHATPAD_REQUEST_OWNER_INVALID_STEP);
    RecordAssertion("initialized no obligation", owner.LifecycleObligationHeld == 0u);
    RecordAssertion("initialized no pins", owner.SendCallPinned == 0u && owner.CancelCallPinned == 0u);
    RecordAssertion("initialized no advance", owner.SequenceAdvanceEligible == 0u);
    ExpectInvariant("initialized invariant", &owner);

    (void)memset(&snapshot, 0xA5, sizeof(snapshot));
    ExpectResult("snapshot valid", ChatpadRequestOwnerGetSnapshot(&owner, &snapshot),
        CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("snapshot state", snapshot.State == CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE);
    RecordAssertion("snapshot step cleared", snapshot.ActivationStepIndex == CHATPAD_REQUEST_OWNER_INVALID_STEP);
    ExpectResult("snapshot null owner", ChatpadRequestOwnerGetSnapshot(0, &snapshot),
        CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT);
    RecordAssertion("failed snapshot cleared", snapshot.OperationActive == 0u && snapshot.LifecycleGeneration == 0u);

    ChatpadRequestOwnerEventInitialize(&event, CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE);
    (void)memset(&effects, 0xA5, sizeof(effects));
    ExpectResult("dispatch null owner", ChatpadRequestOwnerDispatch(0, &event, &effects),
        CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT);
    RecordAssertion("null owner clears effects", EffectsAreClear(&effects));
    ExpectResult("dispatch null event", ChatpadRequestOwnerDispatch(&owner, 0, &effects),
        CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT);
    RecordAssertion("null event clears effects", EffectsAreClear(&effects));
    ExpectResult("dispatch null effects", ChatpadRequestOwnerDispatch(&owner, &event, 0),
        CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT);
}

static void TestExhaustiveStateEventClassification(void)
{
    ChatpadRequestOwnerState state;
    uint32_t eventIndex;

    for (state = CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE;
         state < CHATPAD_REQUEST_OWNER_STATE_COUNT;
         state = (ChatpadRequestOwnerState)(state + 1)) {
        for (eventIndex = 0u; eventIndex < CHATPAD_REQUEST_OWNER_EVENT_COUNT; ++eventIndex) {
            ChatpadActivationRequestOwner owner;
            ChatpadActivationRequestOwner before;
            ChatpadRequestOwnerEvent event;
            ChatpadRequestOwnerEffects effects;
            ChatpadRequestOwnerResult result;
            ChatpadRequestOwnerTransitionClass expected;
            ChatpadRequestOwnerTransitionClass actual;
            ChatpadRequestOwnerEventType eventType = g_allEventTypes[eventIndex];

            BuildCanonicalState(state, &owner);
            ExpectInvariant("canonical state invariant", &owner);
            before = owner;
            FillEventForOwner(&owner, eventType, &event);
            (void)memset(&effects, 0xA5, sizeof(effects));
            expected = ChatpadRequestOwnerGetExpectedTransitionClass(state, eventType);
            result = ChatpadRequestOwnerDispatch(&owner, &event, &effects);
            actual = ChatpadRequestOwnerClassifyResult(result);
            if (actual != expected) {
                (void)printf(
                    "CLASSIFICATION MISMATCH: state=%u event=%u expected=%u actual=%u result=%u\n",
                    (unsigned int)state,
                    (unsigned int)eventType,
                    (unsigned int)expected,
                    (unsigned int)actual,
                    (unsigned int)result);
            }
            RecordAssertion("state/event classification", actual == expected);

            switch (expected) {
            case CHATPAD_REQUEST_OWNER_TRANSITION_ACCEPTED:
                g_classificationAccepted += 1u;
                break;
            case CHATPAD_REQUEST_OWNER_TRANSITION_IDEMPOTENT:
                g_classificationIdempotent += 1u;
                break;
            case CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED:
                g_classificationRejected += 1u;
                RecordAssertion("rejected transition preserves state",
                    memcmp(&owner, &before, sizeof(owner)) == 0);
                RecordAssertion("rejected transition clears effects", EffectsAreClear(&effects));
                break;
            case CHATPAD_REQUEST_OWNER_TRANSITION_TO_FAULTED:
                g_classificationFaulting += 1u;
                RecordAssertion("fault transition enters faulted",
                    owner.State == CHATPAD_REQUEST_OWNER_STATE_FAULTED);
                RecordAssertion("fault transition records diagnostic",
                    effects.RecordDiagnosticFault != 0u);
                break;
            default:
                RecordAssertion("classification enum valid", 0);
                break;
            }
            ExpectInvariant("post-classification invariant", &owner);
        }
    }

    RecordAssertion("classification state count", CHATPAD_REQUEST_OWNER_STATE_COUNT == 14);
    RecordAssertion("classification event count", CHATPAD_REQUEST_OWNER_EVENT_COUNT == 19);
    RecordAssertion("classification combination count",
        (g_classificationAccepted + g_classificationIdempotent +
         g_classificationRejected + g_classificationFaulting) ==
        (uint32_t)(CHATPAD_REQUEST_OWNER_STATE_COUNT * CHATPAD_REQUEST_OWNER_EVENT_COUNT));
}

static void TestRaceScenarios(void)
{
    ChatpadActivationRequestOwner owner;
    ChatpadActivationRequestOwner before;
    ChatpadRequestOwnerEffects effects;
    ChatpadRequestOwnerEffects reusedEffects;
    ChatpadRequestOwnerEvent event;
    ChatpadRequestOwnerResult result;
    uint32_t releaseCount;
    ChatpadRequestOwnerCompletionClass failureClasses[] = {
        CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED,
        CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED,
        CHATPAD_REQUEST_OWNER_COMPLETION_STALE_GENERATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_INVALID_TRANSFER_LENGTH
    };
    size_t index;

    BeginScenario("1 normal accepted send and successful completion");
    BuildToInFlight(&owner);
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
    ExpectResult("normal completion result", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("normal completion release", effects.ReleaseLifecycleAdmission == 1u);
    RecordAssertion("normal completion advances", effects.SequenceMayAdvance == 1u);
    ExpectState("normal completion retiring", &owner, CHATPAD_REQUEST_OWNER_STATE_RETIRING);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("normal completion reusable", &owner, CHATPAD_REQUEST_OWNER_STATE_IDLE);

    BeginScenario("2 completion before accepted send returns");
    BuildToSubmitting(&owner);
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
    ExpectResult("immediate completion pending", result,
        CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN);
    ExpectState("immediate completion awaits send", &owner,
        CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN);
    RecordAssertion("immediate completion waits send", effects.WaitForSendCallReturn == 1u);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("accepted return after completion", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("accepted return does not release twice", effects.ReleaseLifecycleAdmission == 0u);
    RecordAssertion("accepted return publishes advance", effects.SequenceMayAdvance == 1u);

    BeginScenario("3 false send with no completion");
    BuildToSubmitting(&owner);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_FALSE,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("false send result", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("false send releases", effects.ReleaseLifecycleAdmission == 1u);
    RecordAssertion("false send initiator retires", effects.InitiatorOwnsTerminalRetirement == 1u);
    RecordAssertion("false send aborts", effects.SequenceMustAbort == 1u && effects.SequenceMayAdvance == 0u);

    BeginScenario("4 preparation failure before formatting");
    InitializeAvailable(&owner);
    BeginOperation(&owner);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("preparation failure", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("preparation failure release", effects.ReleaseLifecycleAdmission == 1u);

    BeginScenario("5 formatting failure before submission");
    BuildToReady(&owner);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_FAILED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("formatting failure", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("formatting failure release", effects.ReleaseLifecycleAdmission == 1u);

    BeginScenario("6 cancellation requested while in flight");
    BuildToInFlight(&owner);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("cancel request", result, CHATPAD_REQUEST_OWNER_OK);
    ExpectState("cancel request pending", &owner, CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING);
    RecordAssertion("cancel request no release", effects.ReleaseLifecycleAdmission == 0u);
    RecordAssertion("cancel call permitted", effects.CallerMayBeginCancelCall == 1u);

    BeginScenario("7 completion wins cancellation race");
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
    ExpectResult("completion wins cancel result", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("cancel race classified cancelled",
        owner.TerminalClass == CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED);
    RecordAssertion("cancel race no advance", effects.SequenceMayAdvance == 0u);

    BeginScenario("8 cancel call remains pinned after completion");
    BuildToInFlight(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED, 1u, &effects);
    ExpectResult("completion while cancel pinned", result,
        CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN);
    RecordAssertion("wait cancel pin", effects.WaitForCancelCallReturn == 1u);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_RETURNED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("cancel return after completion", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("cancel return no second release", effects.ReleaseLifecycleAdmission == 0u);

    BeginScenario("9 completion remains terminal owner after accepted send");
    BuildToInFlight(&owner);
    RecordAssertion("accepted send completion owner",
        owner.RetirementOwner == CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION);
    RecordAssertion("accepted send obligation held", owner.LifecycleObligationHeld == 1u);

    BeginScenario("10 duplicate cancellation request");
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    before = owner;
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("duplicate cancellation typed", result, CHATPAD_REQUEST_OWNER_ALREADY_CANCELLED);
    RecordAssertion("duplicate cancellation no effects", EffectsAreClear(&effects));
    RecordAssertion("duplicate cancellation only diagnostic counter",
        owner.TransitionCount == before.TransitionCount + 1u);

    BeginScenario("11 duplicate completion after normal completion");
    BuildToInFlight(&owner);
    (void)FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("duplicate normal completion", result, CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION);
    RecordAssertion("duplicate normal no release", effects.ReleaseLifecycleAdmission == 0u);

    BeginScenario("12 duplicate completion after cancellation");
    BuildToInFlight(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED, 1u, &effects);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("duplicate cancelled completion", result, CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION);
    RecordAssertion("duplicate cancelled no release", effects.ReleaseLifecycleAdmission == 0u);

    BeginScenario("13 stale completion");
    BuildToInFlight(&owner);
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 2u, &effects);
    ExpectResult("stale completion accepted for cleanup", result, CHATPAD_REQUEST_OWNER_OK);
    RecordAssertion("stale completion consumed", effects.StaleCompletionConsumed == 1u);
    RecordAssertion("stale completion releases once", effects.ReleaseLifecycleAdmission == 1u);
    RecordAssertion("stale completion no advance", effects.SequenceMayAdvance == 0u);

    BeginScenario("14 drain before admission");
    InitializeAvailable(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("drain before admission state", &owner, CHATPAD_REQUEST_OWNER_STATE_DRAINING);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("draining rejects admission", result, CHATPAD_REQUEST_OWNER_INVALID_STATE);

    BeginScenario("15 drain during preparation");
    InitializeAvailable(&owner);
    BeginOperation(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    RecordAssertion("preparation drain recorded", owner.DrainingRequested == 1u);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("preparation drain ends draining", &owner, CHATPAD_REQUEST_OWNER_STATE_DRAINING);

    BeginScenario("16 drain during submitting state");
    BuildToSubmitting(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    RecordAssertion("submitting drain keeps send pin", owner.SendCallPinned == 1u);
    RecordAssertion("submitting drain aborts", effects.SequenceMustAbort == 1u);

    BeginScenario("17 drain while request in flight");
    BuildToInFlight(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("inflight drain requests cancel", &owner, CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING);
    RecordAssertion("inflight drain cancel effect", effects.CallerMayBeginCancelCall == 1u);

    BeginScenario("18 completion during drain");
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED, 1u, &effects);
    ExpectResult("completion during drain result", result, CHATPAD_REQUEST_OWNER_OK);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("completion during drain terminal", &owner, CHATPAD_REQUEST_OWNER_STATE_DRAINING);

    BeginScenario("19 false send during drain");
    BuildToSubmitting(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_FALSE,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("false send during drain result", result, CHATPAD_REQUEST_OWNER_OK);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectState("false send during drain terminal", &owner, CHATPAD_REQUEST_OWNER_STATE_DRAINING);

    BeginScenario("20 new generation admission before prior pin return");
    BuildToSubmitting(&owner);
    (void)FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &effects);
    before = owner;
    ChatpadRequestOwnerEventInitialize(&event, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION);
    event.CurrentLifecycleGeneration = 2u;
    event.OperationToken.DeviceGeneration = 2u;
    event.OperationToken.OperationSequence = 2u;
    event.ActivationStepIndex = 1u;
    result = ChatpadRequestOwnerDispatch(&owner, &event, &effects);
    ExpectResult("new generation blocked by send pin", result, CHATPAD_REQUEST_OWNER_INVALID_STATE);
    RecordAssertion("new generation rejection preserves", memcmp(&owner, &before, sizeof(owner)) == 0);

    BeginScenario("21 reuse only after send pin returns");
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("retire blocked by send pin", result, CHATPAD_REQUEST_OWNER_INVALID_STATE);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    RecordAssertion("reuse after send return", owner.ReuseEligible == 1u);

    BeginScenario("22 reuse only after cancel pin returns");
    BuildToInFlight(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED, 1u, &effects);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("retire blocked by cancel pin", result, CHATPAD_REQUEST_OWNER_INVALID_STATE);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_RETURNED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    RecordAssertion("reuse after cancel return", owner.ReuseEligible == 1u);

    BeginScenario("23 both send and cancel pins outstanding at completion");
    BuildToSubmitting(&owner);
    owner.CancellationRequested = 1u;
    owner.CancellationCallPublished = 1u;
    owner.CancelCallPinned = 1u;
    ExpectInvariant("dual pin injected state valid", &owner);
    result = FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED, 1u, &effects);
    ExpectResult("dual pin completion pending", result,
        CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN);
    RecordAssertion("dual pin waits both",
        effects.WaitForSendCallReturn == 1u && effects.WaitForCancelCallReturn == 1u);

    BeginScenario("24 operation identity mismatch");
    BuildToInFlight(&owner);
    FillEventForOwner(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS, &event);
    event.OperationToken.OperationSequence += 1u;
    before = owner;
    result = ChatpadRequestOwnerDispatch(&owner, &event, &effects);
    ExpectResult("operation mismatch typed", result, CHATPAD_REQUEST_OWNER_OPERATION_MISMATCH);
    RecordAssertion("operation mismatch preserves", memcmp(&owner, &before, sizeof(owner)) == 0);

    BeginScenario("25 generation mismatch before submission");
    BuildToFormatted(&owner);
    FillEventForOwner(&owner, CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS, &event);
    event.CurrentLifecycleGeneration = 2u;
    before = owner;
    result = ChatpadRequestOwnerDispatch(&owner, &event, &effects);
    ExpectResult("generation mismatch typed", result, CHATPAD_REQUEST_OWNER_GENERATION_MISMATCH);
    RecordAssertion("generation mismatch preserves", memcmp(&owner, &before, sizeof(owner)) == 0);

    BeginScenario("26 faulted owner rejects future admission");
    InitializeAvailable(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_FAULT,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    ExpectResult("faulted admission rejected", result, CHATPAD_REQUEST_OWNER_OWNER_FAULTED);

    BeginScenario("27 repeated initialize and reset behavior");
    (void)memset(&owner, 0, sizeof(owner));
    ExpectResult("first initialize", ChatpadRequestOwnerInitialize(&owner), CHATPAD_REQUEST_OWNER_OK);
    ExpectResult("repeated inactive initialize", ChatpadRequestOwnerInitialize(&owner), CHATPAD_REQUEST_OWNER_OK);
    InitializeAvailable(&owner);
    BeginOperation(&owner);
    before = owner;
    ExpectResult("active initialize rejected", ChatpadRequestOwnerInitialize(&owner),
        CHATPAD_REQUEST_OWNER_INVALID_STATE);
    RecordAssertion("active initialize preserves", memcmp(&owner, &before, sizeof(owner)) == 0);

    BeginScenario("28 stale effects cleared on invalid event");
    InitializeAvailable(&owner);
    (void)memset(&reusedEffects, 0xA5, sizeof(reusedEffects));
    result = Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_FINISHES,
        CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS, 1u, &reusedEffects);
    ExpectResult("invalid event rejected", result, CHATPAD_REQUEST_OWNER_INVALID_STATE);
    RecordAssertion("invalid event effects cleared", EffectsAreClear(&reusedEffects));

    BeginScenario("29 exact accounting on every terminal path");
    releaseCount = 0u;
    InitializeAvailable(&owner);
    BeginOperation(&owner);
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    releaseCount += effects.ReleaseLifecycleAdmission;
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    releaseCount += effects.ReleaseLifecycleAdmission;
    RecordAssertion("local failure exactly one release", releaseCount == 1u);
    BuildToInFlight(&owner);
    releaseCount = 0u;
    (void)FinishCompletion(&owner, CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED, 1u, &effects);
    releaseCount += effects.ReleaseLifecycleAdmission;
    (void)Dispatch(&owner, CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
        CHATPAD_REQUEST_OWNER_COMPLETION_NONE, 0u, &effects);
    releaseCount += effects.ReleaseLifecycleAdmission;
    RecordAssertion("completion failure exactly one release", releaseCount == 1u);

    BeginScenario("30 no advancement across terminal failure classes");
    for (index = 0u; index < sizeof(failureClasses) / sizeof(failureClasses[0]); ++index) {
        BuildToInFlight(&owner);
        (void)FinishCompletion(&owner, failureClasses[index],
            failureClasses[index] == CHATPAD_REQUEST_OWNER_COMPLETION_STALE_GENERATION ? 2u : 1u,
            &effects);
        RecordAssertion("terminal failure never advances",
            effects.SequenceMayAdvance == 0u && owner.SequenceAdvanceEligible == 0u);
    }

    RecordAssertion("exact scenario count", g_scenarioCount == 30u);
}

static void NormalizeOwnerForExploration(ChatpadActivationRequestOwner *owner)
{
    owner->TransitionCount = 0u;
}

static int ExplorationNodeExists(
    const ExplorationNode *nodes,
    uint32_t nodeCount,
    const ChatpadActivationRequestOwner *owner,
    uint32_t releaseCount)
{
    ChatpadActivationRequestOwner normalized = *owner;
    uint32_t index;
    NormalizeOwnerForExploration(&normalized);
    for (index = 0u; index < nodeCount; ++index) {
        ChatpadActivationRequestOwner existing = nodes[index].Owner;
        NormalizeOwnerForExploration(&existing);
        if (nodes[index].ReleaseCountForOperation == releaseCount &&
            memcmp(&existing, &normalized, sizeof(existing)) == 0) {
            return 1;
        }
    }
    return 0;
}

static void TestBoundedSequenceExploration(void)
{
    static ExplorationNode nodes[EXPLORATION_MAX_NODES];
    uint32_t nodeCount = 1u;
    uint32_t cursor = 0u;

    (void)memset(nodes, 0, sizeof(nodes));
    (void)ChatpadRequestOwnerInitialize(&nodes[0].Owner);
    nodes[0].Depth = 0u;
    nodes[0].ReleaseCountForOperation = 0u;

    while (cursor < nodeCount) {
        ExplorationNode current = nodes[cursor++];
        ChatpadRequestOwnerEventType eventType;
        if (current.Depth >= EXPLORATION_MAX_DEPTH) {
            continue;
        }
        for (eventType = CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE;
             eventType < CHATPAD_REQUEST_OWNER_EVENT_COUNT;
             eventType = (ChatpadRequestOwnerEventType)(eventType + 1)) {
            ChatpadActivationRequestOwner next = current.Owner;
            ChatpadActivationRequestOwner before = next;
            ChatpadRequestOwnerEvent event;
            ChatpadRequestOwnerEffects effects;
            ChatpadRequestOwnerResult result;
            ChatpadRequestOwnerTransitionClass resultClass;
            uint32_t releaseCount = current.ReleaseCountForOperation;

            FillEventForOwner(&next, eventType, &event);
            result = ChatpadRequestOwnerDispatch(&next, &event, &effects);
            resultClass = ChatpadRequestOwnerClassifyResult(result);
            g_explorationAttempts += 1u;
            RecordAssertion("exploration invariant",
                ChatpadRequestOwnerValidateInvariant(&next) == CHATPAD_REQUEST_OWNER_INVARIANT_OK);

            if (resultClass == CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED) {
                RecordAssertion("exploration rejection preserves",
                    memcmp(&next, &before, sizeof(next)) == 0);
                RecordAssertion("exploration rejection effects clear", EffectsAreClear(&effects));
                continue;
            }
            if (eventType == CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION &&
                resultClass == CHATPAD_REQUEST_OWNER_TRANSITION_ACCEPTED) {
                releaseCount = 0u;
            }
            releaseCount += effects.ReleaseLifecycleAdmission;
            RecordAssertion("exploration at most one release", releaseCount <= 1u);
            if (effects.OwnerMayBeReused != 0u) {
                RecordAssertion("exploration reuse has no pin or obligation",
                    next.SendCallPinned == 0u && next.CancelCallPinned == 0u &&
                    next.LifecycleObligationHeld == 0u);
            }
            if (effects.SequenceMayAdvance != 0u) {
                RecordAssertion("exploration advance requires success",
                    next.TerminalProcessed != 0u &&
                    next.TerminalClass == CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS &&
                    next.CancellationRequested == 0u &&
                    next.StaleCompletionObserved == 0u);
            }
            if (!ExplorationNodeExists(nodes, nodeCount, &next, releaseCount)) {
                RecordAssertion("exploration node capacity", nodeCount < EXPLORATION_MAX_NODES);
                if (nodeCount < EXPLORATION_MAX_NODES) {
                    nodes[nodeCount].Owner = next;
                    nodes[nodeCount].Depth = current.Depth + 1u;
                    nodes[nodeCount].ReleaseCountForOperation = releaseCount;
                    nodeCount += 1u;
                }
            }
        }
    }
    g_explorationUniqueSnapshots = nodeCount;
    RecordAssertion("exploration reached multiple states", nodeCount > CHATPAD_REQUEST_OWNER_STATE_COUNT);
    RecordAssertion("exploration bounded", nodeCount <= EXPLORATION_MAX_NODES);
}

static void TestInvariantFailures(void)
{
    ChatpadActivationRequestOwner owner;

    RecordAssertion("null invariant typed",
        ChatpadRequestOwnerValidateInvariant(0) == CHATPAD_REQUEST_OWNER_INVARIANT_NULL_OWNER);
    InitializeAvailable(&owner);
    owner.Signature = 0u;
    RecordAssertion("signature invariant typed",
        ChatpadRequestOwnerValidateInvariant(&owner) == CHATPAD_REQUEST_OWNER_INVARIANT_INVALID_SIGNATURE);
    InitializeAvailable(&owner);
    owner.ReuseEligible = 1u;
    owner.SendCallPinned = 1u;
    RecordAssertion("reuse pin invariant typed",
        ChatpadRequestOwnerValidateInvariant(&owner) == CHATPAD_REQUEST_OWNER_INVARIANT_IDLE_OWNS_OPERATION ||
        ChatpadRequestOwnerValidateInvariant(&owner) == CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_PIN);
    BuildToInFlight(&owner);
    owner.SequenceAdvanceEligible = 1u;
    RecordAssertion("premature advance invariant typed",
        ChatpadRequestOwnerValidateInvariant(&owner) == CHATPAD_REQUEST_OWNER_INVARIANT_ADVANCE_WITHOUT_SUCCESS);
}

int main(void)
{
    TestInitializationSnapshotAndInvariants();
    TestExhaustiveStateEventClassification();
    TestRaceScenarios();
    TestBoundedSequenceExploration();
    TestInvariantFailures();

    (void)printf("Transition states: %u\n", (unsigned int)CHATPAD_REQUEST_OWNER_STATE_COUNT);
    (void)printf("Transition event classes: %u\n", (unsigned int)CHATPAD_REQUEST_OWNER_EVENT_COUNT);
    (void)printf("Transition combinations: %u\n",
        (unsigned int)(CHATPAD_REQUEST_OWNER_STATE_COUNT * CHATPAD_REQUEST_OWNER_EVENT_COUNT));
    (void)printf("Transition accepted: %u\n", g_classificationAccepted);
    (void)printf("Transition idempotent: %u\n", g_classificationIdempotent);
    (void)printf("Transition rejected: %u\n", g_classificationRejected);
    (void)printf("Transition faulting: %u\n", g_classificationFaulting);
    (void)printf("Scenario count: %u\n", g_scenarioCount);
    (void)printf("Exploration depth: %u\n", EXPLORATION_MAX_DEPTH);
    (void)printf("Exploration attempts: %u\n", g_explorationAttempts);
    (void)printf("Exploration unique snapshots: %u\n", g_explorationUniqueSnapshots);
    (void)printf("Total: %u\n", g_totalAssertions);
    (void)printf("Passed: %u\n", g_totalAssertions - g_failedAssertions);
    (void)printf("Failed: %u\n", g_failedAssertions);
    return g_failedAssertions == 0u ? 0 : 1;
}
