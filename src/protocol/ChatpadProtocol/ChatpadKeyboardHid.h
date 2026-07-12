#ifndef CHATPAD_KEYBOARD_HID_H
#define CHATPAD_KEYBOARD_HID_H

#include "ChatpadProtocolTypes.h"

#define CHATPAD_HID_BOOT_REPORT_LENGTH ((ChatpadSize)8)
#define CHATPAD_HID_LEFT_SHIFT ((ChatpadUInt8)0x02)

typedef struct ChatpadHidKeyboardReport {
    ChatpadUInt8 Bytes[CHATPAD_HID_BOOT_REPORT_LENGTH];
} ChatpadHidKeyboardReport;

typedef enum ChatpadHidMapResult {
    CHATPAD_HID_MAP_OK = 0,
    CHATPAD_HID_MAP_NULL_PACKET,
    CHATPAD_HID_MAP_NULL_REPORT,
    CHATPAD_HID_MAP_UNSUPPORTED_KEY,
    CHATPAD_HID_MAP_UNSUPPORTED_MODIFIER
} ChatpadHidMapResult;

typedef struct ChatpadHidReportState {
    ChatpadHidKeyboardReport Previous;
    ChatpadUInt8 Initialized;
} ChatpadHidReportState;

ChatpadHidMapResult ChatpadMapKeyboardPacketToHid(
    const ChatpadKeyboardPacket *packet,
    ChatpadHidKeyboardReport *report);

void ChatpadInitializeHidReportState(ChatpadHidReportState *state);

int ChatpadHidReportStateUpdate(
    ChatpadHidReportState *state,
    const ChatpadHidKeyboardReport *report);

void ChatpadBuildAllKeysReleasedReport(ChatpadHidKeyboardReport *report);

#endif
