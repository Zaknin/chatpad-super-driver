#include "ChatpadActivationRequests.h"

typedef struct ChatpadActivationRequestDefinition {
    uint8_t rawBmRequestType;
    uint8_t rawRequest;
    uint16_t rawValue;
    uint16_t rawIndex;
    uint16_t rawLength;
    ChatpadControlDirection direction;
    uint16_t outboundPayloadLength;
    uint16_t expectedInboundDataLength;
    uint8_t outboundPayload[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH];
} ChatpadActivationRequestDefinition;

static const ChatpadActivationRequestDefinition ChatpadActivationRequestTable[CHATPAD_ACTIVATION_REQUEST_COUNT] = {
    { 0x40u, 0xA9u, 0xA30Cu, 0x4423u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0x40u, 0xA9u, 0x2344u, 0x7F03u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0x40u, 0xA9u, 0x5839u, 0x6832u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0xC0u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST, 0x0000u, 0x0002u, { 0x00u, 0x00u } },
    { 0x40u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0002u, 0x0000u, { 0x09u, 0x00u } },
    { 0xC0u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST, 0x0000u, 0x0002u, { 0x00u, 0x00u } }
};

static void ChatpadClearActivationRequest(ChatpadActivationRequest *output)
{
    output->RawBmRequestType = 0;
    output->RawRequest = 0;
    output->RawValue = 0;
    output->RawIndex = 0;
    output->RawLength = 0;
    output->Direction = CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE;
    output->OutboundPayloadLength = 0;
    output->ExpectedInboundDataLength = 0;
    output->OutboundPayload[0] = 0;
    output->OutboundPayload[1] = 0;
}

size_t ChatpadGetActivationRequestCount(void)
{
    return CHATPAD_ACTIVATION_REQUEST_COUNT;
}

ChatpadActivationBuildResult ChatpadBuildActivationRequest(
    size_t requestIndex,
    ChatpadActivationRequest *output)
{
    const ChatpadActivationRequestDefinition *definition;

    if (output == 0) {
        return CHATPAD_ACTIVATION_BUILD_NULL_OUTPUT;
    }

    ChatpadClearActivationRequest(output);

    if (requestIndex >= CHATPAD_ACTIVATION_REQUEST_COUNT) {
        return CHATPAD_ACTIVATION_BUILD_INVALID_INDEX;
    }

    definition = &ChatpadActivationRequestTable[requestIndex];
    output->RawBmRequestType = definition->rawBmRequestType;
    output->RawRequest = definition->rawRequest;
    output->RawValue = definition->rawValue;
    output->RawIndex = definition->rawIndex;
    output->RawLength = definition->rawLength;
    output->Direction = definition->direction;
    output->OutboundPayloadLength = definition->outboundPayloadLength;
    output->ExpectedInboundDataLength = definition->expectedInboundDataLength;
    output->OutboundPayload[0] = definition->outboundPayload[0];
    output->OutboundPayload[1] = definition->outboundPayload[1];

    return CHATPAD_ACTIVATION_BUILD_OK;
}
