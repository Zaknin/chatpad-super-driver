#ifndef CHATPAD_LIVE_TRANSFER_POLICY_H
#define CHATPAD_LIVE_TRANSFER_POLICY_H

#include "ChatpadProtocolTypes.h"

typedef enum ChatpadLiveTransferResult {
    CHATPAD_LIVE_TRANSFER_ACCEPTED = 0,
    CHATPAD_LIVE_TRANSFER_STATUS_FAILED,
    CHATPAD_LIVE_TRANSFER_TIMED_OUT,
    CHATPAD_LIVE_TRANSFER_CANCELLED,
    CHATPAD_LIVE_TRANSFER_BYTE_COUNT_MISMATCH
} ChatpadLiveTransferResult;

ChatpadLiveTransferResult ChatpadValidateLiveTransferOutcome(
    int statusSucceeded,
    int timedOut,
    int cancelled,
    ChatpadSize bytesTransferred,
    ChatpadSize expectedBytes);

int ChatpadIsExpectedActivationPreambleStall(
    ChatpadSize stepIndex,
    int statusSucceeded,
    int timedOut,
    int cancelled,
    int usbdStatusIsStall,
    ChatpadSize bytesTransferred,
    ChatpadSize expectedBytes);

#endif
