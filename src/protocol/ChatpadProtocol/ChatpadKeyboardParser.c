#include "ChatpadKeyboardParser.h"

#define CHATPAD_PHASE1_SUPPORTED_TYPE ((uint8_t)0x00)
#define CHATPAD_PHASE1_MODIFIER_UPPER_MASK ((uint8_t)0xF0)

static void ChatpadClearKeyboardPacket(ChatpadKeyboardPacket *output)
{
    output->RawType = 0;
    output->RawModifiers = 0;
    output->RawKey0 = 0;
    output->RawKey1 = 0;
    output->RawByte4 = 0;
}

ChatpadParseResult ChatpadParseKeyboardPacket(
    const uint8_t *input,
    size_t length,
    ChatpadKeyboardPacket *output)
{
    if (output == NULL) {
        return CHATPAD_PARSE_NULL_OUTPUT;
    }

    ChatpadClearKeyboardPacket(output);

    if (input == NULL && length != 0) {
        return CHATPAD_PARSE_NULL_INPUT;
    }

    if (length < CHATPAD_KEYBOARD_PACKET_LENGTH) {
        return CHATPAD_PARSE_TRUNCATED;
    }

    if (length > CHATPAD_KEYBOARD_PACKET_LENGTH) {
        return CHATPAD_PARSE_OVERSIZED;
    }

    if (input[0] != CHATPAD_PHASE1_SUPPORTED_TYPE) {
        return CHATPAD_PARSE_UNSUPPORTED_TYPE;
    }

    if ((input[1] & CHATPAD_PHASE1_MODIFIER_UPPER_MASK) != 0) {
        return CHATPAD_PARSE_POLICY_REJECTED_MODIFIER;
    }

    output->RawType = input[0];
    output->RawModifiers = input[1];
    output->RawKey0 = input[2];
    output->RawKey1 = input[3];
    output->RawByte4 = input[4];

    return CHATPAD_PARSE_OK;
}
