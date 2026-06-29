#ifndef CHATPAD_KEYBOARD_PARSER_H
#define CHATPAD_KEYBOARD_PARSER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_KEYBOARD_PACKET_LENGTH ((size_t)5)

typedef struct ChatpadKeyboardPacket {
    uint8_t RawType;
    uint8_t RawModifiers;
    uint8_t RawKey0;
    uint8_t RawKey1;
    uint8_t RawByte4;
} ChatpadKeyboardPacket;

typedef enum ChatpadParseResult {
    CHATPAD_PARSE_OK = 0,
    CHATPAD_PARSE_NULL_OUTPUT,
    CHATPAD_PARSE_NULL_INPUT,
    CHATPAD_PARSE_TRUNCATED,
    CHATPAD_PARSE_OVERSIZED,
    CHATPAD_PARSE_UNSUPPORTED_TYPE,
    CHATPAD_PARSE_POLICY_REJECTED_MODIFIER
} ChatpadParseResult;

ChatpadParseResult ChatpadParseKeyboardPacket(
    const uint8_t *input,
    size_t length,
    ChatpadKeyboardPacket *output);

#ifdef __cplusplus
}
#endif

#endif
