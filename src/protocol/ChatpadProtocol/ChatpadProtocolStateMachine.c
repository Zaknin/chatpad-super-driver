#include "ChatpadProtocolStateMachine.h"

static void ChatpadClearTransition(ChatpadProtocolTransition *transition)
{
    transition->PreviousState = CHATPAD_PROTOCOL_STATE_INVALID;
    transition->CurrentState = CHATPAD_PROTOCOL_STATE_INVALID;
    transition->Event = CHATPAD_PROTOCOL_EVENT_INVALID;
    transition->StateChanged = 0;
}

static int ChatpadProtocolStateIsValid(ChatpadProtocolState state)
{
    return state >= CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION &&
        state <= CHATPAD_PROTOCOL_STATE_UNRESOLVED_CONTROL_STATUS;
}

static int ChatpadProtocolEventIsValid(ChatpadProtocolEvent event)
{
    return event >= CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET &&
        event <= CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET;
}

static ChatpadProtocolState ChatpadProtocolStateForEvent(ChatpadProtocolEvent event)
{
    switch (event) {
    case CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET:
        return CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA;
    case CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET:
        return CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT;
    case CHATPAD_PROTOCOL_EVENT_POLICY_REJECTED_PACKET:
        return CHATPAD_PROTOCOL_STATE_POLICY_REJECTED;
    case CHATPAD_PROTOCOL_EVENT_UNRESOLVED_CONTROL_STATUS:
        return CHATPAD_PROTOCOL_STATE_UNRESOLVED_CONTROL_STATUS;
    case CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET:
        return CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION;
    default:
        return CHATPAD_PROTOCOL_STATE_INVALID;
    }
}

ChatpadStateMachineResult ChatpadProtocolStateMachineInitialize(
    ChatpadProtocolStateMachine *stateMachine)
{
    if (stateMachine == 0) {
        return CHATPAD_STATE_MACHINE_NULL_STATE;
    }

    stateMachine->CurrentState = CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION;
    return CHATPAD_STATE_MACHINE_OK;
}

ChatpadStateMachineResult ChatpadProtocolStateMachineReset(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolTransition *transition)
{
    return ChatpadProtocolStateMachineApply(
        stateMachine,
        CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET,
        transition);
}

ChatpadStateMachineResult ChatpadProtocolStateMachineApply(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolEvent event,
    ChatpadProtocolTransition *transition)
{
    ChatpadProtocolState previousState;
    ChatpadProtocolState nextState;

    if (transition == 0) {
        return CHATPAD_STATE_MACHINE_NULL_OUTPUT;
    }

    ChatpadClearTransition(transition);

    if (stateMachine == 0) {
        return CHATPAD_STATE_MACHINE_NULL_STATE;
    }

    if (!ChatpadProtocolStateIsValid(stateMachine->CurrentState)) {
        return CHATPAD_STATE_MACHINE_INVALID_STATE;
    }

    if (!ChatpadProtocolEventIsValid(event)) {
        return CHATPAD_STATE_MACHINE_INVALID_EVENT;
    }

    previousState = stateMachine->CurrentState;
    nextState = ChatpadProtocolStateForEvent(event);

    transition->PreviousState = previousState;
    transition->CurrentState = nextState;
    transition->Event = event;
    transition->StateChanged = (ChatpadUInt8)(previousState != nextState);
    stateMachine->CurrentState = nextState;

    return CHATPAD_STATE_MACHINE_OK;
}

ChatpadStateMachineResult ChatpadProtocolEventFromParseResult(
    ChatpadParseResult parseResult,
    ChatpadProtocolEvent *event)
{
    if (event == 0) {
        return CHATPAD_STATE_MACHINE_NULL_OUTPUT;
    }

    *event = CHATPAD_PROTOCOL_EVENT_INVALID;

    switch (parseResult) {
    case CHATPAD_PARSE_OK:
        *event = CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET;
        return CHATPAD_STATE_MACHINE_OK;
    case CHATPAD_PARSE_UNSUPPORTED_TYPE:
        *event = CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET;
        return CHATPAD_STATE_MACHINE_OK;
    case CHATPAD_PARSE_POLICY_REJECTED_MODIFIER:
        *event = CHATPAD_PROTOCOL_EVENT_POLICY_REJECTED_PACKET;
        return CHATPAD_STATE_MACHINE_OK;
    case CHATPAD_PARSE_NULL_OUTPUT:
    case CHATPAD_PARSE_NULL_INPUT:
    case CHATPAD_PARSE_TRUNCATED:
    case CHATPAD_PARSE_OVERSIZED:
        return CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED;
    default:
        return CHATPAD_STATE_MACHINE_INVALID_PARSE_RESULT;
    }
}
