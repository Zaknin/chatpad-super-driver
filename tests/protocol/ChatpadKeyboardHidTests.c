#include <stdio.h>

#include "ChatpadKeyboardHid.h"
#include "ChatpadKeyboardHidTests.h"

static void Check(ChatpadKeyboardHidTestSummary *summary, const char *name, int condition)
{
    ++summary->Total;
    if (condition) {
        ++summary->Passed;
        printf("PASS: %s\n", name);
    } else {
        ++summary->Failed;
        printf("FAIL: %s\n", name);
    }
}

ChatpadKeyboardHidTestSummary RunChatpadKeyboardHidTests(void)
{
    ChatpadKeyboardHidTestSummary summary = { 0 };
    ChatpadKeyboardPacket packet = { 0 };
    ChatpadHidKeyboardReport report;
    ChatpadHidReportState state;

    packet.RawKey0 = 0x37;
    Check(&summary, "A maps", ChatpadMapKeyboardPacketToHid(&packet, &report) == CHATPAD_HID_MAP_OK);
    Check(&summary, "A usage", report.Bytes[2] == 0x04);

    packet.RawModifiers = 0x01;
    packet.RawKey0 = 0x27;
    packet.RawKey1 = 0x21;
    Check(&summary, "shift Q U maps", ChatpadMapKeyboardPacketToHid(&packet, &report) == CHATPAD_HID_MAP_OK);
    Check(&summary, "left shift modifier", report.Bytes[0] == CHATPAD_HID_LEFT_SHIFT);
    Check(&summary, "Q first usage", report.Bytes[2] == 0x14);
    Check(&summary, "U second usage", report.Bytes[3] == 0x18);

    packet.RawModifiers = 0;
    packet.RawKey0 = 0xFF;
    packet.RawKey1 = 0;
    Check(&summary, "unknown key rejected", ChatpadMapKeyboardPacketToHid(&packet, &report) == CHATPAD_HID_MAP_UNSUPPORTED_KEY);

    packet.RawModifiers = 0x02;
    packet.RawKey0 = 0x37;
    Check(&summary, "unimplemented green layer rejected", ChatpadMapKeyboardPacketToHid(&packet, &report) == CHATPAD_HID_MAP_UNSUPPORTED_MODIFIER);

    ChatpadInitializeHidReportState(&state);
    ChatpadBuildAllKeysReleasedReport(&report);
    Check(&summary, "first release submitted", ChatpadHidReportStateUpdate(&state, &report) != 0);
    Check(&summary, "duplicate release suppressed", ChatpadHidReportStateUpdate(&state, &report) == 0);
    report.Bytes[2] = 0x04;
    Check(&summary, "make submitted", ChatpadHidReportStateUpdate(&state, &report) != 0);
    ChatpadBuildAllKeysReleasedReport(&report);
    Check(&summary, "break submitted", ChatpadHidReportStateUpdate(&state, &report) != 0);

    return summary;
}
