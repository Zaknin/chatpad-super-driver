#ifndef CHATPAD_ACTIVATION_REQUESTS_H
#define CHATPAD_ACTIVATION_REQUESTS_H

#if defined(_MSC_VER) && defined(_KERNEL_MODE)
typedef unsigned __int8 uint8_t;
typedef unsigned __int16 uint16_t;
#ifndef _SIZE_T_DEFINED
#if defined(_WIN64)
typedef unsigned __int64 size_t;
#else
typedef unsigned int size_t;
#endif
#define _SIZE_T_DEFINED
#endif
#else
#include <stddef.h>
#include <stdint.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_ACTIVATION_REQUEST_COUNT ((size_t)6)
#define CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH ((uint16_t)2)

typedef enum ChatpadControlDirection {
    CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE = 0,
    CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST = 1
} ChatpadControlDirection;

typedef enum ChatpadActivationBuildResult {
    CHATPAD_ACTIVATION_BUILD_OK = 0,
    CHATPAD_ACTIVATION_BUILD_NULL_OUTPUT,
    CHATPAD_ACTIVATION_BUILD_INVALID_INDEX
} ChatpadActivationBuildResult;

typedef struct ChatpadActivationRequest {
    uint8_t RawBmRequestType;
    uint8_t RawRequest;
    uint16_t RawValue;
    uint16_t RawIndex;
    uint16_t RawLength;
    ChatpadControlDirection Direction;
    uint16_t OutboundPayloadLength;
    uint16_t ExpectedInboundDataLength;
    uint8_t OutboundPayload[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH];
} ChatpadActivationRequest;

size_t ChatpadGetActivationRequestCount(void);

ChatpadActivationBuildResult ChatpadBuildActivationRequest(
    size_t requestIndex,
    ChatpadActivationRequest *output);

#ifdef __cplusplus
}
#endif

#endif
