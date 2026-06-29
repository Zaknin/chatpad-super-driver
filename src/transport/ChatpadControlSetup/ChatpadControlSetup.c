#include "ChatpadControlSetup.h"

#define CHATPAD_CONTROL_SETUP_DIRECTION_MASK ((uint8_t)0x80)

static void ChatpadClearControlSetupTranslation(ChatpadControlSetupTranslation *output)
{
    uint8_t *bytes;
    size_t index;

    if (output == 0) {
        return;
    }

    bytes = (uint8_t *)output;
    for (index = 0; index < sizeof(*output); ++index) {
        bytes[index] = 0;
    }
}

static int ChatpadControlDirectionIsValid(ChatpadControlDirection direction)
{
    return direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE ||
        direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST;
}

static int ChatpadControlDirectionMatchesType(const ChatpadActivationRequest *request)
{
    const int typeIsDeviceToHost =
        (request->RawBmRequestType & CHATPAD_CONTROL_SETUP_DIRECTION_MASK) != 0;

    return (request->Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST) ==
        typeIsDeviceToHost;
}

static void ChatpadEncodeSetupPacket(
    const ChatpadActivationRequest *request,
    ChatpadControlSetupTranslation *output)
{
    output->SetupPacketBytes[0] = request->RawBmRequestType;
    output->SetupPacketBytes[1] = request->RawRequest;
    output->SetupPacketBytes[2] = (uint8_t)(request->RawValue & 0x00FFu);
    output->SetupPacketBytes[3] = (uint8_t)((request->RawValue >> 8) & 0x00FFu);
    output->SetupPacketBytes[4] = (uint8_t)(request->RawIndex & 0x00FFu);
    output->SetupPacketBytes[5] = (uint8_t)((request->RawIndex >> 8) & 0x00FFu);
    output->SetupPacketBytes[6] = (uint8_t)(request->RawLength & 0x00FFu);
    output->SetupPacketBytes[7] = (uint8_t)((request->RawLength >> 8) & 0x00FFu);
}

ChatpadControlSetupResult ChatpadTranslateActivationRequest(
    const ChatpadActivationRequest *request,
    ChatpadControlSetupTranslation *output)
{
    uint16_t index;

    if (output == 0) {
        return CHATPAD_CONTROL_SETUP_NULL_OUTPUT;
    }
    ChatpadClearControlSetupTranslation(output);

    if (request == 0) {
        return CHATPAD_CONTROL_SETUP_NULL_REQUEST;
    }
    if (!ChatpadControlDirectionIsValid(request->Direction)) {
        return CHATPAD_CONTROL_SETUP_INVALID_DIRECTION;
    }
    if (!ChatpadControlDirectionMatchesType(request)) {
        return CHATPAD_CONTROL_SETUP_DIRECTION_MISMATCH;
    }

    if (request->Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE) {
        if (request->ExpectedInboundDataLength != 0) {
            return CHATPAD_CONTROL_SETUP_INVALID_PAYLOAD_LENGTH;
        }
        if (request->RawLength > CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH ||
            request->OutboundPayloadLength > CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH) {
            return CHATPAD_CONTROL_SETUP_PAYLOAD_CAPACITY_EXCEEDED;
        }
        if (request->OutboundPayloadLength != request->RawLength) {
            return CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH;
        }
    }
    else {
        if (request->OutboundPayloadLength != 0) {
            return CHATPAD_CONTROL_SETUP_INVALID_PAYLOAD_LENGTH;
        }
        if (request->ExpectedInboundDataLength != request->RawLength) {
            return CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH;
        }
    }

    ChatpadEncodeSetupPacket(request, output);
    if (request->RawLength == 0) {
        output->DataDirection = CHATPAD_CONTROL_DATA_DIRECTION_NONE;
    }
    else if (request->Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE) {
        output->DataDirection = CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE;
    }
    else {
        output->DataDirection = CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST;
    }

    if (request->Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE) {
        output->OutboundPayloadLength = request->OutboundPayloadLength;
        for (index = 0; index < request->OutboundPayloadLength; ++index) {
            output->OutboundPayload[index] = request->OutboundPayload[index];
        }
    }
    else {
        output->ExpectedInboundLength = request->ExpectedInboundDataLength;
    }

    return CHATPAD_CONTROL_SETUP_OK;
}
