#ifndef CHATPAD_ACTIVATION_EXECUTOR_TESTS_H
#define CHATPAD_ACTIVATION_EXECUTOR_TESTS_H

typedef struct ChatpadActivationExecutorTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadActivationExecutorTestSummary;

ChatpadActivationExecutorTestSummary RunChatpadActivationExecutorTests(void);

#endif
