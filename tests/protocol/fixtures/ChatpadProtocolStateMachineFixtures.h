#ifndef CHATPAD_PROTOCOL_STATE_MACHINE_FIXTURES_H
#define CHATPAD_PROTOCOL_STATE_MACHINE_FIXTURES_H

#include "ChatpadProtocolStateMachine.h"

/*
 * These are synthetic abstract classifications, not wire packets or hardware
 * captures. They assign no meaning to unresolved initialization/status bytes.
 */

static const ChatpadProtocolEvent SyntheticAcceptedKeyboardEvent =
    CHATPAD_PROTOCOL_EVENT_ACCEPTED_KEYBOARD_PACKET;
static const ChatpadProtocolEvent SyntheticUnsupportedPacketEvent =
    CHATPAD_PROTOCOL_EVENT_UNSUPPORTED_PACKET;
static const ChatpadProtocolEvent SyntheticPolicyRejectedPacketEvent =
    CHATPAD_PROTOCOL_EVENT_POLICY_REJECTED_PACKET;
static const ChatpadProtocolEvent SyntheticUnresolvedControlStatusEvent =
    CHATPAD_PROTOCOL_EVENT_UNRESOLVED_CONTROL_STATUS;

#endif
