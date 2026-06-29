#include "ChatpadKeyboardParser.h"

typedef char ChatpadCompileCheckByteIsEightBits[(sizeof(ChatpadUInt8) == 1) ? 1 : -1];
typedef char ChatpadCompileCheckSizeMatchesPointer[(sizeof(ChatpadSize) == sizeof(void *)) ? 1 : -1];
typedef char ChatpadCompileCheckPacketLength[(CHATPAD_KEYBOARD_PACKET_LENGTH == 5) ? 1 : -1];

ChatpadParseResult ChatpadProtocolKernelCompileCheck(void)
{
    const ChatpadUInt8 input[CHATPAD_KEYBOARD_PACKET_LENGTH] = { 0, 0, 0, 0, 0 };
    ChatpadKeyboardPacket output;

    return ChatpadParseKeyboardPacket(input, CHATPAD_KEYBOARD_PACKET_LENGTH, &output);
}
