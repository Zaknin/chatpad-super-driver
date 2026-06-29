#ifndef CHATPAD_KEYBOARD_PARSER_H
#define CHATPAD_KEYBOARD_PARSER_H

#include "ChatpadProtocolTypes.h"

#ifdef __cplusplus
extern "C" {
#endif

ChatpadParseResult ChatpadParseKeyboardPacket(
    const ChatpadUInt8 *input,
    ChatpadSize length,
    ChatpadKeyboardPacket *output);

#ifdef __cplusplus
}
#endif

#endif
