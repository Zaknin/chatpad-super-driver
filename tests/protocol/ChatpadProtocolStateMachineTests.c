#include <stdint.h>
#include <stdio.h>

#include "ChatpadProtocolStateMachine.h"
#include "ChatpadProtocolStateMachineFixtures.h"
#include "ChatpadProtocolStateMachineTests.h"

static ChatpadStateMachineTestSummary Summary;

static void AssertTrue(const char *name, int condition)
{
    ++Summary.Total;
    if (condition != 0) {
        ++Summary.Passed;
        printf("PASS: %s\n", name);
    }
    else {
        ++Summary.Failed;
        printf("FAIL: %s\n", name);
    }
}

static void AssertResult(
    const char *name,
    ChatpadStateMachineResult expected,
    ChatpadStateMachineResult actual)
{
    ++Summary.Total;
    if (expected == actual) {
        ++Summary.Passed;
        printf("PASS: %s\n", name);
    }
    else {
        ++Summary.Failed;
        printf("FAIL: %s expected=%d actual=%d\n", name, (int)expected, (int)actual);
    }
}

static void PoisonTransition(ChatpadProtocolTransition *transition)
{
    transition->PreviousState = (ChatpadProtocolState)0x55;
    transition->CurrentState = (ChatpadProtocolState)0x55;
    transition->Event = (ChatpadProtocolEvent)0x55;
    transition->StateChanged = 0x55;
}

static void AssertTransitionCleared(
    const char *name,
    const ChatpadProtocolTransition *transition)
{
    AssertTrue(
        name,
        transition->PreviousState == CHATPAD_PROTOCOL_STATE_INVALID &&
        transition->CurrentState == CHATPAD_PROTOCOL_STATE_INVALID &&
        transition->Event == CHATPAD_PROTOCOL_EVENT_INVALID &&
        transition->StateChanged == 0);
}

static void AssertClassificationTransition(
    const char *prefix,
    ChatpadProtocolEvent event,
    ChatpadProtocolState expectedState)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolTransition transition;
    ChatpadStateMachineResult result;
    char name[96];

    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    result = ChatpadProtocolStateMachineApply(&stateMachine, event, &transition);

    (void)sprintf_s(name, sizeof(name), "%s result", prefix);
    AssertResult(name, CHATPAD_STATE_MACHINE_OK, result);
    (void)sprintf_s(name, sizeof(name), "%s state", prefix);
    AssertTrue(name, stateMachine.CurrentState == expectedState);
    (void)sprintf_s(name, sizeof(name), "%s previous", prefix);
    AssertTrue(name, transition.PreviousState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    (void)sprintf_s(name, sizeof(name), "%s current", prefix);
    AssertTrue(name, transition.CurrentState == expectedState);
    (void)sprintf_s(name, sizeof(name), "%s event", prefix);
    AssertTrue(name, transition.Event == event);
    (void)sprintf_s(name, sizeof(name), "%s changed", prefix);
    AssertTrue(name, transition.StateChanged == 1);
}

static void TestInitializationAndClassifications(void)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadStateMachineResult result;

    stateMachine.CurrentState = CHATPAD_PROTOCOL_STATE_INVALID;
    result = ChatpadProtocolStateMachineInitialize(&stateMachine);
    AssertResult("state initialize result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "state initialize awaiting classification",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertResult(
        "state initialize null state",
        CHATPAD_STATE_MACHINE_NULL_STATE,
        ChatpadProtocolStateMachineInitialize(0));

    AssertClassificationTransition(
        "accepted keyboard event",
        SyntheticAcceptedKeyboardEvent,
        CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertClassificationTransition(
        "unsupported packet event",
        SyntheticUnsupportedPacketEvent,
        CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT);
    AssertClassificationTransition(
        "policy rejected event",
        SyntheticPolicyRejectedPacketEvent,
        CHATPAD_PROTOCOL_STATE_POLICY_REJECTED);
    AssertClassificationTransition(
        "unresolved control status event",
        SyntheticUnresolvedControlStatusEvent,
        CHATPAD_PROTOCOL_STATE_UNRESOLVED_CONTROL_STATUS);
}

static void TestInvalidArgumentsAndDeterministicFailure(void)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolTransition transition;
    ChatpadStateMachineResult result;

    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    PoisonTransition(&transition);
    result = ChatpadProtocolStateMachineApply(
        &stateMachine,
        (ChatpadProtocolEvent)0x55,
        &transition);
    AssertResult("invalid event result", CHATPAD_STATE_MACHINE_INVALID_EVENT, result);
    AssertTrue(
        "invalid event leaves state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertTransitionCleared("invalid event clears transition", &transition);

    PoisonTransition(&transition);
    result = ChatpadProtocolStateMachineApply(
        0,
        SyntheticAcceptedKeyboardEvent,
        &transition);
    AssertResult("null state result", CHATPAD_STATE_MACHINE_NULL_STATE, result);
    AssertTransitionCleared("null state clears transition", &transition);

    result = ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticAcceptedKeyboardEvent,
        0);
    AssertResult("null transition result", CHATPAD_STATE_MACHINE_NULL_OUTPUT, result);
    AssertTrue(
        "null transition leaves state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);

    stateMachine.CurrentState = CHATPAD_PROTOCOL_STATE_INVALID;
    PoisonTransition(&transition);
    result = ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticAcceptedKeyboardEvent,
        &transition);
    AssertResult("invalid state result", CHATPAD_STATE_MACHINE_INVALID_STATE, result);
    AssertTrue(
        "invalid state remains invalid",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_INVALID);
    AssertTransitionCleared("invalid state clears transition", &transition);
}

static void TestRepeatedSequentialAndReset(void)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolTransition transition;
    ChatpadStateMachineResult result;

    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    (void)ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticAcceptedKeyboardEvent,
        &transition);
    result = ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticAcceptedKeyboardEvent,
        &transition);
    AssertResult("repeated event result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "repeated event state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertTrue(
        "repeated event previous",
        transition.PreviousState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertTrue(
        "repeated event current",
        transition.CurrentState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertTrue(
        "repeated event preserved",
        transition.Event == CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET);
    AssertTrue("repeated event unchanged", transition.StateChanged == 0);

    result = ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticUnsupportedPacketEvent,
        &transition);
    AssertResult("sequential event result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "sequential event state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT);
    AssertTrue(
        "sequential event previous",
        transition.PreviousState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertTrue(
        "sequential event current",
        transition.CurrentState == CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT);
    AssertTrue(
        "sequential event preserved",
        transition.Event == CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET);
    AssertTrue("sequential event changed", transition.StateChanged == 1);

    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    (void)ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticAcceptedKeyboardEvent,
        &transition);
    result = ChatpadProtocolStateMachineReset(&stateMachine, &transition);
    AssertResult("reset after accepted result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "reset after accepted state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertTrue(
        "reset after accepted previous",
        transition.PreviousState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);
    AssertTrue(
        "reset after accepted current",
        transition.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertTrue(
        "reset after accepted event",
        transition.Event == CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET);
    AssertTrue("reset after accepted changed", transition.StateChanged == 1);

    (void)ChatpadProtocolStateMachineApply(
        &stateMachine,
        SyntheticUnsupportedPacketEvent,
        &transition);
    result = ChatpadProtocolStateMachineReset(&stateMachine, &transition);
    AssertResult("reset after unsupported result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "reset after unsupported state",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertTrue(
        "reset after unsupported previous",
        transition.PreviousState == CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT);
    AssertTrue(
        "reset after unsupported current",
        transition.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
    AssertTrue(
        "reset after unsupported event",
        transition.Event == CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET);
    AssertTrue("reset after unsupported changed", transition.StateChanged == 1);
}

static void TestNoRetainedExternalStateAndSentinels(void)
{
    typedef struct GuardedStateMachine {
        uint32_t Before;
        ChatpadProtocolStateMachine StateMachine;
        uint32_t After;
    } GuardedStateMachine;
    typedef struct GuardedTransition {
        uint32_t Before;
        ChatpadProtocolTransition Transition;
        uint32_t After;
    } GuardedTransition;

    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolTransition transition;
    ChatpadProtocolEvent event;
    GuardedStateMachine guardedState;
    GuardedTransition guardedTransition;
    ChatpadStateMachineResult result;

    event = SyntheticAcceptedKeyboardEvent;
    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    result = ChatpadProtocolStateMachineApply(&stateMachine, event, &transition);
    event = SyntheticUnsupportedPacketEvent;
    AssertResult("event copied by value result", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "event variable change not retained",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA);

    guardedState.Before = UINT32_C(0x11223344);
    guardedState.After = UINT32_C(0x55667788);
    guardedState.StateMachine.CurrentState = CHATPAD_PROTOCOL_STATE_INVALID;
    result = ChatpadProtocolStateMachineInitialize(&guardedState.StateMachine);
    AssertResult("guarded state initialize", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "guarded state before unchanged",
        guardedState.Before == UINT32_C(0x11223344));
    AssertTrue(
        "guarded state after unchanged",
        guardedState.After == UINT32_C(0x55667788));

    guardedTransition.Before = UINT32_C(0x99AABBCC);
    guardedTransition.After = UINT32_C(0xDDEEFF00);
    result = ChatpadProtocolStateMachineApply(
        &guardedState.StateMachine,
        SyntheticAcceptedKeyboardEvent,
        &guardedTransition.Transition);
    AssertResult("guarded transition apply", CHATPAD_STATE_MACHINE_OK, result);
    AssertTrue(
        "guarded transition before unchanged",
        guardedTransition.Before == UINT32_C(0x99AABBCC));
    AssertTrue(
        "guarded transition after unchanged",
        guardedTransition.After == UINT32_C(0xDDEEFF00));
}

static void AssertParseMapping(
    const char *resultName,
    const char *eventName,
    ChatpadParseResult parseResult,
    ChatpadStateMachineResult expectedResult,
    ChatpadProtocolEvent expectedEvent)
{
    ChatpadProtocolEvent event = (ChatpadProtocolEvent)0x55;
    ChatpadStateMachineResult result = ChatpadProtocolEventFromParseResult(parseResult, &event);

    AssertResult(resultName, expectedResult, result);
    AssertTrue(eventName, event == expectedEvent);
}

static void TestParserResultMapping(void)
{
    ChatpadProtocolStateMachine stateMachine;
    ChatpadProtocolEvent event;
    ChatpadStateMachineResult result;

    AssertParseMapping(
        "map accepted parser result",
        "map accepted event",
        CHATPAD_PARSE_OK,
        CHATPAD_STATE_MACHINE_OK,
        CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET);
    AssertParseMapping(
        "map unsupported parser result",
        "map unsupported event",
        CHATPAD_PARSE_UNSUPPORTED_TYPE,
        CHATPAD_STATE_MACHINE_OK,
        CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET);
    AssertParseMapping(
        "map policy parser result",
        "map policy event",
        CHATPAD_PARSE_POLICY_REJECTED_MODIFIER,
        CHATPAD_STATE_MACHINE_OK,
        CHATPAD_PROTOCOL_EVENT_POLICY_REJECTED_PACKET);
    AssertParseMapping(
        "map null output parser result",
        "map null output invalid event",
        CHATPAD_PARSE_NULL_OUTPUT,
        CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED,
        CHATPAD_PROTOCOL_EVENT_INVALID);
    AssertParseMapping(
        "map null input parser result",
        "map null input invalid event",
        CHATPAD_PARSE_NULL_INPUT,
        CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED,
        CHATPAD_PROTOCOL_EVENT_INVALID);
    AssertParseMapping(
        "map truncated parser result",
        "map truncated invalid event",
        CHATPAD_PARSE_TRUNCATED,
        CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED,
        CHATPAD_PROTOCOL_EVENT_INVALID);
    AssertParseMapping(
        "map oversized parser result",
        "map oversized invalid event",
        CHATPAD_PARSE_OVERSIZED,
        CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED,
        CHATPAD_PROTOCOL_EVENT_INVALID);
    AssertParseMapping(
        "map invalid parser result",
        "map invalid parser event",
        (ChatpadParseResult)0x55,
        CHATPAD_STATE_MACHINE_INVALID_PARSE_RESULT,
        CHATPAD_PROTOCOL_EVENT_INVALID);

    AssertResult(
        "map null event output",
        CHATPAD_STATE_MACHINE_NULL_OUTPUT,
        ChatpadProtocolEventFromParseResult(CHATPAD_PARSE_OK, 0));

    (void)ChatpadProtocolStateMachineInitialize(&stateMachine);
    event = (ChatpadProtocolEvent)0x55;
    result = ChatpadProtocolEventFromParseResult(CHATPAD_PARSE_TRUNCATED, &event);
    AssertResult(
        "malformed parser result remains unclassified",
        CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED,
        result);
    AssertTrue(
        "malformed parser result yields invalid event",
        event == CHATPAD_PROTOCOL_EVENT_INVALID);
    AssertTrue(
        "malformed parser result causes no transition",
        stateMachine.CurrentState == CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION);
}

ChatpadStateMachineTestSummary RunChatpadProtocolStateMachineTests(void)
{
    Summary.Total = 0;
    Summary.Passed = 0;
    Summary.Failed = 0;

    TestInitializationAndClassifications();
    TestInvalidArgumentsAndDeterministicFailure();
    TestRepeatedSequentialAndReset();
    TestNoRetainedExternalStateAndSentinels();
    TestParserResultMapping();

    return Summary;
}
