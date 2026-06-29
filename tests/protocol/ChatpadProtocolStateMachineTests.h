#ifndef CHATPAD_PROTOCOL_STATE_MACHINE_TESTS_H
#define CHATPAD_PROTOCOL_STATE_MACHINE_TESTS_H

typedef struct ChatpadStateMachineTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadStateMachineTestSummary;

ChatpadStateMachineTestSummary RunChatpadProtocolStateMachineTests(void);

#endif
