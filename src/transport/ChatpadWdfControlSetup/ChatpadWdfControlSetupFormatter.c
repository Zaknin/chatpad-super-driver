#include "ChatpadWdfControlSetupFormatter.h"

#define CHATPAD_WDF_CONTROL_SETUP_DIRECTION_MASK ((uint8_t)0x80)

static uint16_t ChatpadWdfControlSetupGetLength(
    const ChatpadControlSetupTranslation *translation)
{
    return (uint16_t)(
        (uint16_t)translation->SetupPacketBytes[6] |
        ((uint16_t)translation->SetupPacketBytes[7] << 8));
}

static ChatpadWdfControlSetupResult ChatpadWdfControlSetupValidate(
    const ChatpadControlSetupTranslation *translation)
{
    const uint16_t setupLength = ChatpadWdfControlSetupGetLength(translation);
    const int setupIsDeviceToHost =
        (translation->SetupPacketBytes[0] & CHATPAD_WDF_CONTROL_SETUP_DIRECTION_MASK) != 0;

    switch (translation->DataDirection) {
    case CHATPAD_CONTROL_DATA_DIRECTION_NONE:
        if (setupLength != 0 ||
            translation->OutboundPayloadLength != 0 ||
            translation->ExpectedInboundLength != 0) {
            return CHATPAD_WDF_CONTROL_SETUP_LENGTH_MISMATCH;
        }
        break;

    case CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE:
        if (setupIsDeviceToHost) {
            return CHATPAD_WDF_CONTROL_SETUP_INVALID_DIRECTION;
        }
        if (translation->OutboundPayloadLength > CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH) {
            return CHATPAD_WDF_CONTROL_SETUP_UNSUPPORTED_REPRESENTATION;
        }
        if (translation->ExpectedInboundLength != 0 ||
            setupLength != translation->OutboundPayloadLength) {
            return CHATPAD_WDF_CONTROL_SETUP_LENGTH_MISMATCH;
        }
        break;

    case CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST:
        if (!setupIsDeviceToHost) {
            return CHATPAD_WDF_CONTROL_SETUP_INVALID_DIRECTION;
        }
        if (translation->OutboundPayloadLength != 0 ||
            setupLength != translation->ExpectedInboundLength) {
            return CHATPAD_WDF_CONTROL_SETUP_LENGTH_MISMATCH;
        }
        break;

    default:
        return CHATPAD_WDF_CONTROL_SETUP_INVALID_DIRECTION;
    }

    return CHATPAD_WDF_CONTROL_SETUP_OK;
}

ChatpadWdfControlSetupResult ChatpadFormatWdfControlSetupPacket(
    const ChatpadControlSetupTranslation *translation,
    WDF_USB_CONTROL_SETUP_PACKET *output)
{
    ChatpadWdfControlSetupResult result;
    uint16_t index;

    if (output == 0) {
        return CHATPAD_WDF_CONTROL_SETUP_NULL_OUTPUT;
    }
    RtlZeroMemory(output, sizeof(*output));

    if (translation == 0) {
        return CHATPAD_WDF_CONTROL_SETUP_NULL_TRANSLATION;
    }

    result = ChatpadWdfControlSetupValidate(translation);
    if (result != CHATPAD_WDF_CONTROL_SETUP_OK) {
        return result;
    }

    for (index = 0; index < CHATPAD_CONTROL_SETUP_PACKET_LENGTH; ++index) {
        output->Generic.Bytes[index] = translation->SetupPacketBytes[index];
    }

    return CHATPAD_WDF_CONTROL_SETUP_OK;
}
