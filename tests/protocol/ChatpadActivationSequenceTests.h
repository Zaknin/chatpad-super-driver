#ifndef CHATPAD_ACTIVATION_SEQUENCE_TESTS_H
#define CHATPAD_ACTIVATION_SEQUENCE_TESTS_H

typedef struct ChatpadActivationSequenceTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadActivationSequenceTestSummary;

ChatpadActivationSequenceTestSummary RunChatpadActivationSequenceTests(void);

#endif
