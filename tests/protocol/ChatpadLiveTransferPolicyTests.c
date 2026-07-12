#include <stdio.h>

#include "ChatpadActivationSequence.h"
#include "ChatpadLiveTransferPolicy.h"
#include "ChatpadLiveTransferPolicyTests.h"

static void Check(ChatpadLiveTransferPolicyTestSummary *summary, const char *name, int condition)
{
    ++summary->Total;
    if (condition) {
        ++summary->Passed;
        printf("PASS: %s\n", name);
    } else {
        ++summary->Failed;
        printf("FAIL: %s\n", name);
    }
}

static unsigned int ExecuteMockTransfers(
    unsigned int failureStep,
    ChatpadLiveTransferResult failureResult)
{
    unsigned int completed = 0;
    size_t index;
    for (index = 0; index < ChatpadGetActivationSequenceStepCount(); ++index) {
        ChatpadActivationSequenceStep step;
        ChatpadLiveTransferResult result;
        ChatpadGetActivationSequenceStep(index, &step);
        result = index == failureStep
            ? failureResult
            : ChatpadValidateLiveTransferOutcome(1, 0, 0, step.Request.RawLength, step.Request.RawLength);
        if (result != CHATPAD_LIVE_TRANSFER_ACCEPTED) {
            break;
        }
        ++completed;
    }
    return completed;
}

ChatpadLiveTransferPolicyTestSummary RunChatpadLiveTransferPolicyTests(void)
{
    ChatpadLiveTransferPolicyTestSummary summary = { 0 };
    Check(&summary, "live transfer exact bytes accepted",
        ChatpadValidateLiveTransferOutcome(1, 0, 0, 2, 2) == CHATPAD_LIVE_TRANSFER_ACCEPTED);
    Check(&summary, "live transfer timeout classified",
        ChatpadValidateLiveTransferOutcome(0, 1, 0, 0, 2) == CHATPAD_LIVE_TRANSFER_TIMED_OUT);
    Check(&summary, "live transfer cancellation precedes timeout",
        ChatpadValidateLiveTransferOutcome(0, 1, 1, 0, 2) == CHATPAD_LIVE_TRANSFER_CANCELLED);
    Check(&summary, "live transfer failed status classified",
        ChatpadValidateLiveTransferOutcome(0, 0, 0, 0, 0) == CHATPAD_LIVE_TRANSFER_STATUS_FAILED);
    Check(&summary, "live transfer short count rejected",
        ChatpadValidateLiveTransferOutcome(1, 0, 0, 1, 2) == CHATPAD_LIVE_TRANSFER_BYTE_COUNT_MISMATCH);
    Check(&summary, "six successful hardware outcomes complete",
        ExecuteMockTransfers(99, CHATPAD_LIVE_TRANSFER_STATUS_FAILED) == 6);
    Check(&summary, "failed step terminates without later transfer",
        ExecuteMockTransfers(3, CHATPAD_LIVE_TRANSFER_STATUS_FAILED) == 3);
    Check(&summary, "timeout terminates without retry",
        ExecuteMockTransfers(1, CHATPAD_LIVE_TRANSFER_TIMED_OUT) == 1);
    return summary;
}
