#ifndef CHATPAD_ACTIVATION_REQUESTS_TESTS_H
#define CHATPAD_ACTIVATION_REQUESTS_TESTS_H

typedef struct ChatpadActivationRequestTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadActivationRequestTestSummary;

ChatpadActivationRequestTestSummary RunChatpadActivationRequestTests(void);

#endif
