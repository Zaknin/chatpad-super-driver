#include "ChatpadLiveTransferPolicy.h"

ChatpadLiveTransferResult ChatpadValidateLiveTransferOutcome(
    int statusSucceeded,
    int timedOut,
    int cancelled,
    ChatpadSize bytesTransferred,
    ChatpadSize expectedBytes)
{
    if (cancelled) {
        return CHATPAD_LIVE_TRANSFER_CANCELLED;
    }
    if (timedOut) {
        return CHATPAD_LIVE_TRANSFER_TIMED_OUT;
    }
    if (!statusSucceeded) {
        return CHATPAD_LIVE_TRANSFER_STATUS_FAILED;
    }
    if (bytesTransferred != expectedBytes) {
        return CHATPAD_LIVE_TRANSFER_BYTE_COUNT_MISMATCH;
    }
    return CHATPAD_LIVE_TRANSFER_ACCEPTED;
}

int ChatpadIsAcceptedActivationStall(
    ChatpadSize stepIndex,
    int statusSucceeded,
    int timedOut,
    int cancelled,
    int usbdStatusIsStall,
    ChatpadSize bytesTransferred,
    ChatpadSize expectedBytes)
{
    if (statusSucceeded ||
        timedOut ||
        cancelled ||
        !usbdStatusIsStall ||
        bytesTransferred != (ChatpadSize)0u) {
        return 0;
    }
    return (stepIndex < (ChatpadSize)3u &&
            expectedBytes == (ChatpadSize)0u) ||
        (stepIndex == (ChatpadSize)3u &&
            expectedBytes == (ChatpadSize)2u);
}
