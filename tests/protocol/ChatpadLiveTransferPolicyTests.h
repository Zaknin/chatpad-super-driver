#ifndef CHATPAD_LIVE_TRANSFER_POLICY_TESTS_H
#define CHATPAD_LIVE_TRANSFER_POLICY_TESTS_H

typedef struct ChatpadLiveTransferPolicyTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadLiveTransferPolicyTestSummary;

ChatpadLiveTransferPolicyTestSummary RunChatpadLiveTransferPolicyTests(void);

#endif
