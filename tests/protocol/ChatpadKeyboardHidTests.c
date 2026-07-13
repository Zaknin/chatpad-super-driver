#include <stdio.h>
#include <string.h>

#include "ChatpadKeyboardHid.h"
#include "ChatpadConfiguration.h"
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
    ChatpadConfiguration configuration;
    ChatpadConfiguration candidate;
    ChatpadConfigurationStore store;
    ChatpadLayeredMappingState layeredState;
    ChatpadHidKeyboardReport legacyReport;
    ChatpadHidKeyboardReport layeredReport;
    unsigned int rawKey;
    unsigned int baseCount = 0;
    unsigned int greenCount = 0;
    unsigned int orangeCount = 0;

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

    ChatpadBuildDefaultConfiguration(&configuration);
    Check(&summary, "default configuration validates",
        ChatpadValidateConfiguration(&configuration) == CHATPAD_CONFIGURATION_VALID);
    Check(&summary, "default schema version", configuration.SchemaVersion == CHATPAD_CONFIGURATION_SCHEMA_VERSION);
    Check(&summary, "default ABI version", configuration.AbiVersion == CHATPAD_CONFIGURATION_ABI_VERSION);
    Check(&summary, "default People action disabled", configuration.PeopleAction == CHATPAD_PEOPLE_ACTION_DISABLED);

    for (rawKey = 1; rawKey < 0xF1; ++rawKey) {
        ChatpadHidMapResult legacyResult;
        ChatpadHidMapResult layeredResult;
        packet.RawModifiers = 0;
        packet.RawKey0 = (ChatpadUInt8)rawKey;
        packet.RawKey1 = 0;
        legacyResult = ChatpadMapKeyboardPacketToHid(&packet, &legacyReport);
        ChatpadInitializeLayeredMappingState(&layeredState);
        layeredResult = ChatpadMapKeyboardPacketWithConfiguration(
            &packet, &configuration, &layeredState, &layeredReport);
        if (legacyResult == CHATPAD_HID_MAP_OK) {
            ++baseCount;
            Check(&summary, "default base action remains byte-identical",
                layeredResult == CHATPAD_HID_MAP_OK &&
                memcmp(legacyReport.Bytes, layeredReport.Bytes, CHATPAD_HID_BOOT_REPORT_LENGTH) == 0);
        }
    }
    Check(&summary, "all 43 base raw keys covered", baseCount == 43);

    for (rawKey = 1; rawKey < 0xF1; ++rawKey) {
        if (configuration.Green[rawKey].Type == CHATPAD_MAPPING_ACTION_KEYBOARD) ++greenCount;
        if (configuration.Orange[rawKey].Type == CHATPAD_MAPPING_ACTION_KEYBOARD) ++orangeCount;
    }
    Check(&summary, "deterministic Green subset count", greenCount == 23);
    Check(&summary, "deterministic Orange physical subset count", orangeCount == 7);
    Check(&summary, "Orange Shift maps Caps Lock",
        configuration.Orange[CHATPAD_PSEUDO_KEY_SHIFT].Type == CHATPAD_MAPPING_ACTION_KEYBOARD &&
        configuration.Orange[CHATPAD_PSEUDO_KEY_SHIFT].Usage == 0x39);

    for (rawKey = 1; rawKey < 0xF1; ++rawKey) {
        const ChatpadMappingAction *expected;
        ChatpadHidMapResult result;
        if (!ChatpadIsSupportedPhysicalKey((ChatpadUInt8)rawKey)) continue;
        packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
        packet.RawKey0 = (ChatpadUInt8)rawKey;
        packet.RawKey1 = 0;
        ChatpadInitializeLayeredMappingState(&layeredState);
        expected = &configuration.Green[rawKey];
        result = ChatpadMapKeyboardPacketWithConfiguration(
            &packet, &configuration, &layeredState, &report);
        Check(&summary, "every Green physical key follows its configured action",
            (expected->Type == CHATPAD_MAPPING_ACTION_KEYBOARD && result == CHATPAD_HID_MAP_OK &&
             report.Bytes[0] == expected->Modifiers && report.Bytes[2] == expected->Usage) ||
            (expected->Type == CHATPAD_MAPPING_ACTION_DISABLED && result == CHATPAD_HID_MAP_UNSUPPORTED_KEY &&
             report.Bytes[0] == 0 && report.Bytes[2] == 0));

        packet.RawModifiers = CHATPAD_MODIFIER_ORANGE;
        ChatpadInitializeLayeredMappingState(&layeredState);
        expected = &configuration.Orange[rawKey];
        result = ChatpadMapKeyboardPacketWithConfiguration(
            &packet, &configuration, &layeredState, &report);
        Check(&summary, "every Orange physical key follows its configured action",
            (expected->Type == CHATPAD_MAPPING_ACTION_KEYBOARD && result == CHATPAD_HID_MAP_OK &&
             report.Bytes[0] == expected->Modifiers && report.Bytes[2] == expected->Usage) ||
            (expected->Type == CHATPAD_MAPPING_ACTION_DISABLED && result == CHATPAD_HID_MAP_UNSUPPORTED_KEY &&
             report.Bytes[0] == 0 && report.Bytes[2] == 0));
    }

    ChatpadInitializeLayeredMappingState(&layeredState);
    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x27;
    packet.RawKey1 = 0;
    Check(&summary, "Green Q maps",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK);
    Check(&summary, "Green Q is exclamation HID chord",
        report.Bytes[0] == CHATPAD_HID_LEFT_SHIFT && report.Bytes[2] == 0x1E);
    packet.RawModifiers = 0;
    Check(&summary, "layer release before key release keeps latched action",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[0] == CHATPAD_HID_LEFT_SHIFT && report.Bytes[2] == 0x1E);
    packet.RawKey0 = 0;
    Check(&summary, "mapped key release clears latched action",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);

    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x27;
    Check(&summary, "Green key can be pressed before key-first release",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK);
    packet.RawKey0 = 0;
    Check(&summary, "mapped key released before layer modifier emits release",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);
    packet.RawModifiers = 0;
    Check(&summary, "later layer release remains released",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);

    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x27;
    (void)ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report);
    ChatpadInitializeLayeredMappingState(&layeredState);
    ChatpadBuildAllKeysReleasedReport(&report);
    packet.RawModifiers = 0;
    packet.RawKey0 = 0;
    Check(&summary, "forced all-keys release clears layered latch",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &legacyReport) == CHATPAD_HID_MAP_OK &&
        memcmp(report.Bytes, legacyReport.Bytes, CHATPAD_HID_BOOT_REPORT_LENGTH) == 0);

    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x27;
    (void)ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report);
    packet.RawModifiers = 0;
    packet.RawKey0 = 0xFF;
    Check(&summary, "unknown layered key fails safely",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_UNSUPPORTED_KEY &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);
    packet.RawKey0 = 0x27;
    Check(&summary, "unknown key clears prior layered latch",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0x14);

    packet.RawModifiers = CHATPAD_MODIFIER_ORANGE | CHATPAD_MODIFIER_SHIFT;
    packet.RawKey0 = 0;
    Check(&summary, "Orange Shift modifier-only combo maps",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK);
    Check(&summary, "Orange Shift emits unshifted Caps Lock",
        report.Bytes[0] == 0 && report.Bytes[2] == 0x39);

    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x27;
    packet.RawKey1 = 0x26;
    ChatpadInitializeLayeredMappingState(&layeredState);
    Check(&summary, "simultaneous Green keys map",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK);
    Check(&summary, "simultaneous Green usages preserved",
        report.Bytes[0] == CHATPAD_HID_LEFT_SHIFT && report.Bytes[2] == 0x1E && report.Bytes[3] == 0x1F);
    Check(&summary, "repeated report is deterministic",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &legacyReport) == CHATPAD_HID_MAP_OK &&
        memcmp(report.Bytes, legacyReport.Bytes, CHATPAD_HID_BOOT_REPORT_LENGTH) == 0);

    packet.RawModifiers = CHATPAD_MODIFIER_GREEN | CHATPAD_MODIFIER_ORANGE;
    Check(&summary, "combined Green Orange rejected safely",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_UNSUPPORTED_MODIFIER &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);
    packet.RawModifiers = CHATPAD_MODIFIER_GREEN;
    packet.RawKey0 = 0x25;
    packet.RawKey1 = 0;
    Check(&summary, "layout-dependent Green legend rejected safely",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_UNSUPPORTED_KEY &&
        report.Bytes[0] == 0 && report.Bytes[2] == 0);
    packet.RawModifiers = CHATPAD_MODIFIER_PEOPLE;
    packet.RawKey0 = 0x37;
    Check(&summary, "disabled People action does not disrupt base key",
        ChatpadMapKeyboardPacketWithConfiguration(&packet, &configuration, &layeredState, &report) == CHATPAD_HID_MAP_OK &&
        report.Bytes[2] == 0x04);

    ChatpadInitializeConfigurationStore(&store);
    candidate = store.Active;
    candidate.SchemaVersion = 99;
    Check(&summary, "unsupported schema rejected",
        ChatpadApplyConfiguration(&store, &candidate) == CHATPAD_CONFIGURATION_UNSUPPORTED_SCHEMA);
    Check(&summary, "schema rejection retains old mapping",
        store.Generation == 1 && store.Active.SchemaVersion == CHATPAD_CONFIGURATION_SCHEMA_VERSION);
    candidate = store.Active;
    candidate.Base[0x37].Usage = 0x05;
    candidate.ProfileName[0] = 't'; candidate.ProfileName[1] = 'e'; candidate.ProfileName[2] = 's';
    candidate.ProfileName[3] = 't'; candidate.ProfileName[4] = 0;
    Check(&summary, "valid profile applies atomically",
        ChatpadApplyConfiguration(&store, &candidate) == CHATPAD_CONFIGURATION_VALID &&
        store.Generation == 2 && store.Active.Base[0x37].Usage == 0x05);
    candidate = store.Active;
    candidate.Base[0x37].Usage = 0xFF;
    Check(&summary, "invalid action rejected",
        ChatpadApplyConfiguration(&store, &candidate) == CHATPAD_CONFIGURATION_INVALID_ACTION);
    Check(&summary, "invalid action retains active mapping",
        store.Generation == 2 && store.Active.Base[0x37].Usage == 0x05);
    candidate = store.Active;
    candidate.Base[0x01] = candidate.Base[0x37];
    Check(&summary, "unsupported physical key rejected",
        ChatpadApplyConfiguration(&store, &candidate) == CHATPAD_CONFIGURATION_UNSUPPORTED_PHYSICAL_KEY);
    Check(&summary, "unsupported key rejection remains atomic",
        store.Generation == 2 && store.Active.Base[0x37].Usage == 0x05);
    ChatpadResetConfigurationStore(&store);
    Check(&summary, "reset restores built-in defaults",
        store.Generation == 3 && store.Active.Base[0x37].Usage == 0x04 &&
        strcmp(store.Active.ProfileName, "built-in-qwerty") == 0);

    return summary;
}
