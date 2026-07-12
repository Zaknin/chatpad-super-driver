#pragma once

typedef struct ChatpadFailOpenPolicyTestSummary {
    int Passed;
    int Total;
} ChatpadFailOpenPolicyTestSummary;

ChatpadFailOpenPolicyTestSummary RunChatpadFailOpenPolicyTests(void);
