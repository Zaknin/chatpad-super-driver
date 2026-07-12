#include "ChatpadKeyboardHid.h"

static ChatpadUInt8 ChatpadRawKeyToHidUsage(ChatpadUInt8 rawKey)
{
    switch (rawKey) {
    case 0x00: return 0x00;
    case 0x11: return 0x24; /* 7 */
    case 0x12: return 0x23; /* 6 */
    case 0x13: return 0x22; /* 5 */
    case 0x14: return 0x21; /* 4 */
    case 0x15: return 0x20; /* 3 */
    case 0x16: return 0x1F; /* 2 */
    case 0x17: return 0x1E; /* 1 */
    case 0x21: return 0x18; /* U */
    case 0x22: return 0x1C; /* Y */
    case 0x23: return 0x17; /* T */
    case 0x24: return 0x15; /* R */
    case 0x25: return 0x08; /* E */
    case 0x26: return 0x1A; /* W */
    case 0x27: return 0x14; /* Q */
    case 0x31: return 0x0D; /* J */
    case 0x32: return 0x0B; /* H */
    case 0x33: return 0x0A; /* G */
    case 0x34: return 0x09; /* F */
    case 0x35: return 0x07; /* D */
    case 0x36: return 0x16; /* S */
    case 0x37: return 0x04; /* A */
    case 0x41: return 0x11; /* N */
    case 0x42: return 0x05; /* B */
    case 0x43: return 0x19; /* V */
    case 0x44: return 0x06; /* C */
    case 0x45: return 0x1B; /* X */
    case 0x46: return 0x1D; /* Z */
    case 0x51: return 0x4F; /* Right */
    case 0x52: return 0x10; /* M */
    case 0x53: return 0x37; /* Period */
    case 0x54: return 0x2C; /* Space */
    case 0x55: return 0x50; /* Left */
    case 0x62: return 0x36; /* Comma */
    case 0x63: return 0x28; /* Enter */
    case 0x64: return 0x13; /* P */
    case 0x65: return 0x27; /* 0 */
    case 0x66: return 0x26; /* 9 */
    case 0x67: return 0x25; /* 8 */
    case 0x71: return 0x2A; /* Backspace */
    case 0x72: return 0x0F; /* L */
    case 0x75: return 0x12; /* O */
    case 0x76: return 0x0C; /* I */
    case 0x77: return 0x0E; /* K */
    default: return 0xFF;
    }
}

void ChatpadBuildAllKeysReleasedReport(ChatpadHidKeyboardReport *report)
{
    ChatpadSize index;
    if (report == 0) {
        return;
    }
    for (index = 0; index < CHATPAD_HID_BOOT_REPORT_LENGTH; ++index) {
        report->Bytes[index] = 0;
    }
}

ChatpadHidMapResult ChatpadMapKeyboardPacketToHid(
    const ChatpadKeyboardPacket *packet,
    ChatpadHidKeyboardReport *report)
{
    ChatpadUInt8 key0;
    ChatpadUInt8 key1;

    if (packet == 0) {
        return CHATPAD_HID_MAP_NULL_PACKET;
    }
    if (report == 0) {
        return CHATPAD_HID_MAP_NULL_REPORT;
    }

    ChatpadBuildAllKeysReleasedReport(report);
    if ((packet->RawModifiers & 0x0Eu) != 0) {
        return CHATPAD_HID_MAP_UNSUPPORTED_MODIFIER;
    }
    key0 = ChatpadRawKeyToHidUsage(packet->RawKey0);
    key1 = ChatpadRawKeyToHidUsage(packet->RawKey1);
    if (key0 == 0xFF || key1 == 0xFF) {
        return CHATPAD_HID_MAP_UNSUPPORTED_KEY;
    }

    if ((packet->RawModifiers & 0x01u) != 0) {
        report->Bytes[0] = CHATPAD_HID_LEFT_SHIFT;
    }
    report->Bytes[2] = key0;
    if (key1 != key0) {
        report->Bytes[3] = key1;
    }
    return CHATPAD_HID_MAP_OK;
}

void ChatpadInitializeHidReportState(ChatpadHidReportState *state)
{
    if (state == 0) {
        return;
    }
    ChatpadBuildAllKeysReleasedReport(&state->Previous);
    state->Initialized = 0;
}

int ChatpadHidReportStateUpdate(
    ChatpadHidReportState *state,
    const ChatpadHidKeyboardReport *report)
{
    ChatpadSize index;
    int changed;

    if (state == 0 || report == 0) {
        return 0;
    }

    changed = state->Initialized == 0;
    for (index = 0; index < CHATPAD_HID_BOOT_REPORT_LENGTH; ++index) {
        if (state->Previous.Bytes[index] != report->Bytes[index]) {
            changed = 1;
        }
        state->Previous.Bytes[index] = report->Bytes[index];
    }
    state->Initialized = 1;
    return changed;
}
