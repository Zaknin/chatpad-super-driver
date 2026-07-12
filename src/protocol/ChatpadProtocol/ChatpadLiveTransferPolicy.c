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

int ChatpadIsExpectedActivationPreambleStall(
    ChatpadSize stepIndex,
    int statusSucceeded,
    int timedOut,
    int cancelled,
    int usbdStatusIsStall,
    ChatpadSize bytesTransferred,
    ChatpadSize expectedBytes)
{
    return stepIndex < (ChatpadSize)3u &&
        !statusSucceeded &&
        !timedOut &&
        !cancelled &&
        usbdStatusIsStall &&
        bytesTransferred == (ChatpadSize)0u &&
        expectedBytes == (ChatpadSize)0u;
}
