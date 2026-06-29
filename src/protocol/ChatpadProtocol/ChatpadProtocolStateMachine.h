#ifndef CHATPAD_PROTOCOL_STATE_MACHINE_H
#define CHATPAD_PROTOCOL_STATE_MACHINE_H

#include "ChatpadProtocolTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ChatpadProtocolState {
    CHATPAD_PROTOCOL_STATE_INVALID = 0,
    CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION,
    CHATPAD_PROTOCOL_STATE_ACCEPTED_KEYBOARD_DATA,
    CHATPAD_PROTOCOL_STATE_UNSUPPORTED_INPUT,
    CHATPAD_PROTOCOL_STATE_POLICY_REJECTED,
    CHATPAD_PROTOCOL_STATE_UNRESOLVED_CONTROL_STATUS
} ChatpadProtocolState;

typedef enum ChatpadProtocolEvent {
    CHATPAD_PROTOCOL_EVENT_INVALID = 0,
    CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET,
    CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET,
    CHATPAD_PROTOCOL_EVENT_POLICY_REJECTED_PACKET,
    CHATPAD_PROTOCOL_EVENT_UNRESOLVED_CONTROL_STATUS,
    CHATPAD_PROTOCOL_EVENT_EXPLICIT_RESET
} ChatpadProtocolEvent;

typedef enum ChatpadStateMachineResult {
    CHATPAD_STATE_MACHINE_OK = 0,
    CHATPAD_STATE_MACHINE_NULL_STATE,
    CHATPAD_STATE_MACHINE_NULL_OUTPUT,
    CHATPAD_STATE_MACHINE_INVALID_STATE,
    CHATPAD_STATE_MACHINE_INVALID_EVENT,
    CHATPAD_STATE_MACHINE_INVALID_PARSE_RESULT,
    CHATPAD_STATE_MACHINE_PARSE_RESULT_NOT_CLASSIFIED
} ChatpadStateMachineResult;

typedef struct ChatpadProtocolStateMachine {
    ChatpadProtocolState CurrentState;
} ChatpadProtocolStateMachine;

typedef struct ChatpadProtocolTransition {
    ChatpadProtocolState PreviousState;
    ChatpadProtocolState CurrentState;
    ChatpadProtocolEvent Event;
    ChatpadUInt8 StateChanged;
} ChatpadProtocolTransition;

ChatpadStateMachineResult ChatpadProtocolStateMachineInitialize(
    ChatpadProtocolStateMachine *stateMachine);

ChatpadStateMachineResult ChatpadProtocolStateMachineReset(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolTransition *transition);

ChatpadStateMachineResult ChatpadProtocolStateMachineApply(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolEvent event,
    ChatpadProtocolTransition *transition);

ChatpadStateMachineResult ChatpadProtocolEventFromParseResult(
    ChatpadParseResult parseResult,
    ChatpadProtocolEvent *event);

#ifdef __cplusplus
}
#endif

#endif
