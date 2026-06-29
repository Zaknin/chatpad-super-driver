#ifndef CHATPAD_CONTROL_SETUP_H
#define CHATPAD_CONTROL_SETUP_H

#include "ChatpadActivationRequests.h"

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_CONTROL_SETUP_PACKET_LENGTH ((uint16_t)8)

typedef enum ChatpadControlDataDirection {
    CHATPAD_CONTROL_DATA_DIRECTION_NONE = 0,
    CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE,
    CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST
} ChatpadControlDataDirection;

typedef enum ChatpadControlSetupResult {
    CHATPAD_CONTROL_SETUP_OK = 0,
    CHATPAD_CONTROL_SETUP_NULL_REQUEST,
    CHATPAD_CONTROL_SETUP_NULL_OUTPUT,
    CHATPAD_CONTROL_SETUP_INVALID_DIRECTION,
    CHATPAD_CONTROL_SETUP_DIRECTION_MISMATCH,
    CHATPAD_CONTROL_SETUP_INVALID_PAYLOAD_LENGTH,
    CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH,
    CHATPAD_CONTROL_SETUP_PAYLOAD_CAPACITY_EXCEEDED
} ChatpadControlSetupResult;

typedef struct ChatpadControlSetupTranslation {
    uint8_t SetupPacketBytes[CHATPAD_CONTROL_SETUP_PACKET_LENGTH];
    ChatpadControlDataDirection DataDirection;
    uint16_t OutboundPayloadLength;
    uint16_t ExpectedInboundLength;
    uint8_t OutboundPayload[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH];
} ChatpadControlSetupTranslation;

ChatpadControlSetupResult ChatpadTranslateActivationRequest(
    const ChatpadActivationRequest *request,
    ChatpadControlSetupTranslation *output);

#ifdef __cplusplus
}
#endif

#endif
