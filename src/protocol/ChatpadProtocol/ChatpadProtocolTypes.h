#ifndef CHATPAD_PROTOCOL_TYPES_H
#define CHATPAD_PROTOCOL_TYPES_H

#if defined(_MSC_VER)
typedef unsigned __int8 ChatpadUInt8;
#if defined(_WIN64)
typedef unsigned __int64 ChatpadSize;
#else
typedef unsigned int ChatpadSize;
#endif
#else
#include <stddef.h>
#include <stdint.h>
typedef uint8_t ChatpadUInt8;
typedef size_t ChatpadSize;
#endif

#define CHATPAD_KEYBOARD_PACKET_LENGTH ((ChatpadSize)5)

typedef struct ChatpadKeyboardPacket {
    ChatpadUInt8 RawType;
    ChatpadUInt8 RawModifiers;
    ChatpadUInt8 RawKey0;
    ChatpadUInt8 RawKey1;
    ChatpadUInt8 RawByte4;
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

#endif
