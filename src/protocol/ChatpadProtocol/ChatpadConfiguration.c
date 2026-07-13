#include "ChatpadConfiguration.h"

/*
 * The standard-HID Green/Orange subset is independently re-expressed from
 * the MIT-licensed GAFBlizzard Chatpad Super Driver default profile. Symbols
 * that require layout-dependent Unicode injection remain disabled.
 */

static void ChatpadClearBytes(void *target, ChatpadSize length)
{
    ChatpadUInt8 *bytes;
    ChatpadSize index;
    bytes = (ChatpadUInt8 *)target;
    for (index = 0; index < length; ++index) {
        bytes[index] = 0;
    }
}

static ChatpadMappingAction ChatpadKeyboardAction(ChatpadUInt8 usage, ChatpadUInt8 modifiers)
{
    ChatpadMappingAction action;
    action.Type = CHATPAD_MAPPING_ACTION_KEYBOARD;
    action.Usage = usage;
    action.Modifiers = modifiers;
    action.Reserved = 0;
    return action;
}

static void ChatpadSetBase(ChatpadConfiguration *configuration, ChatpadUInt8 rawKey, ChatpadUInt8 usage)
{
    configuration->Base[rawKey] = ChatpadKeyboardAction(usage, 0);
}

static void ChatpadSetGreen(
    ChatpadConfiguration *configuration,
    ChatpadUInt8 rawKey,
    ChatpadUInt8 usage,
    ChatpadUInt8 modifiers)
{
    configuration->Green[rawKey] = ChatpadKeyboardAction(usage, modifiers);
}

static void ChatpadSetOrange(
    ChatpadConfiguration *configuration,
    ChatpadUInt8 rawKey,
    ChatpadUInt8 usage,
    ChatpadUInt8 modifiers)
{
    configuration->Orange[rawKey] = ChatpadKeyboardAction(usage, modifiers);
}

int ChatpadIsSupportedPhysicalKey(ChatpadUInt8 rawKey)
{
    switch (rawKey) {
    case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17:
    case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27:
    case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x36: case 0x37:
    case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x46:
    case 0x51: case 0x52: case 0x53: case 0x54: case 0x55:
    case 0x62: case 0x63: case 0x64: case 0x65: case 0x66: case 0x67:
    case 0x71: case 0x72: case 0x75: case 0x76: case 0x77:
    case CHATPAD_PSEUDO_KEY_SHIFT:
        return 1;
    default:
        return 0;
    }
}

void ChatpadBuildDefaultConfiguration(ChatpadConfiguration *configuration)
{
    static const char defaultName[] = "built-in-qwerty";
    ChatpadSize index;

    if (configuration == 0) {
        return;
    }
    ChatpadClearBytes(configuration, sizeof(*configuration));
    configuration->SchemaVersion = CHATPAD_CONFIGURATION_SCHEMA_VERSION;
    configuration->AbiVersion = CHATPAD_CONFIGURATION_ABI_VERSION;
    configuration->Layout = CHATPAD_PROFILE_LAYOUT_QWERTY;
    configuration->PeopleAction = CHATPAD_PEOPLE_ACTION_DISABLED;
    for (index = 0; index + 1 < sizeof(defaultName); ++index) {
        configuration->ProfileName[index] = defaultName[index];
    }

    ChatpadSetBase(configuration, 0x11, 0x24); ChatpadSetBase(configuration, 0x12, 0x23);
    ChatpadSetBase(configuration, 0x13, 0x22); ChatpadSetBase(configuration, 0x14, 0x21);
    ChatpadSetBase(configuration, 0x15, 0x20); ChatpadSetBase(configuration, 0x16, 0x1F);
    ChatpadSetBase(configuration, 0x17, 0x1E); ChatpadSetBase(configuration, 0x21, 0x18);
    ChatpadSetBase(configuration, 0x22, 0x1C); ChatpadSetBase(configuration, 0x23, 0x17);
    ChatpadSetBase(configuration, 0x24, 0x15); ChatpadSetBase(configuration, 0x25, 0x08);
    ChatpadSetBase(configuration, 0x26, 0x1A); ChatpadSetBase(configuration, 0x27, 0x14);
    ChatpadSetBase(configuration, 0x31, 0x0D); ChatpadSetBase(configuration, 0x32, 0x0B);
    ChatpadSetBase(configuration, 0x33, 0x0A); ChatpadSetBase(configuration, 0x34, 0x09);
    ChatpadSetBase(configuration, 0x35, 0x07); ChatpadSetBase(configuration, 0x36, 0x16);
    ChatpadSetBase(configuration, 0x37, 0x04); ChatpadSetBase(configuration, 0x41, 0x11);
    ChatpadSetBase(configuration, 0x42, 0x05); ChatpadSetBase(configuration, 0x43, 0x19);
    ChatpadSetBase(configuration, 0x44, 0x06); ChatpadSetBase(configuration, 0x45, 0x1B);
    ChatpadSetBase(configuration, 0x46, 0x1D); ChatpadSetBase(configuration, 0x51, 0x4F);
    ChatpadSetBase(configuration, 0x52, 0x10); ChatpadSetBase(configuration, 0x53, 0x37);
    ChatpadSetBase(configuration, 0x54, 0x2C); ChatpadSetBase(configuration, 0x55, 0x50);
    ChatpadSetBase(configuration, 0x62, 0x36); ChatpadSetBase(configuration, 0x63, 0x28);
    ChatpadSetBase(configuration, 0x64, 0x13); ChatpadSetBase(configuration, 0x65, 0x27);
    ChatpadSetBase(configuration, 0x66, 0x26); ChatpadSetBase(configuration, 0x67, 0x25);
    ChatpadSetBase(configuration, 0x71, 0x2A); ChatpadSetBase(configuration, 0x72, 0x0F);
    ChatpadSetBase(configuration, 0x75, 0x12); ChatpadSetBase(configuration, 0x76, 0x0C);
    ChatpadSetBase(configuration, 0x77, 0x0E);

    ChatpadSetGreen(configuration, 0x27, 0x1E, CHATPAD_HID_LEFT_SHIFT); /* ! */
    ChatpadSetGreen(configuration, 0x26, 0x1F, CHATPAD_HID_LEFT_SHIFT); /* @ */
    ChatpadSetGreen(configuration, 0x24, 0x20, CHATPAD_HID_LEFT_SHIFT); /* # */
    ChatpadSetGreen(configuration, 0x23, 0x22, CHATPAD_HID_LEFT_SHIFT); /* % */
    ChatpadSetGreen(configuration, 0x22, 0x23, CHATPAD_HID_LEFT_SHIFT); /* ^ */
    ChatpadSetGreen(configuration, 0x21, 0x24, CHATPAD_HID_LEFT_SHIFT); /* & */
    ChatpadSetGreen(configuration, 0x76, 0x25, CHATPAD_HID_LEFT_SHIFT); /* * */
    ChatpadSetGreen(configuration, 0x75, 0x26, CHATPAD_HID_LEFT_SHIFT); /* ( */
    ChatpadSetGreen(configuration, 0x64, 0x27, CHATPAD_HID_LEFT_SHIFT); /* ) */
    ChatpadSetGreen(configuration, 0x37, 0x35, CHATPAD_HID_LEFT_SHIFT); /* ~ */
    ChatpadSetGreen(configuration, 0x35, 0x2F, CHATPAD_HID_LEFT_SHIFT); /* { */
    ChatpadSetGreen(configuration, 0x34, 0x30, CHATPAD_HID_LEFT_SHIFT); /* } */
    ChatpadSetGreen(configuration, 0x32, 0x38, 0);                    /* / */
    ChatpadSetGreen(configuration, 0x31, 0x34, 0);                    /* apostrophe */
    ChatpadSetGreen(configuration, 0x77, 0x2F, 0);                    /* [ */
    ChatpadSetGreen(configuration, 0x72, 0x30, 0);                    /* ] */
    ChatpadSetGreen(configuration, 0x62, 0x33, CHATPAD_HID_LEFT_SHIFT); /* : */
    ChatpadSetGreen(configuration, 0x46, 0x35, 0);                    /* grave */
    ChatpadSetGreen(configuration, 0x43, 0x2D, 0);                    /* - */
    ChatpadSetGreen(configuration, 0x42, 0x31, CHATPAD_HID_LEFT_SHIFT); /* | */
    ChatpadSetGreen(configuration, 0x41, 0x36, CHATPAD_HID_LEFT_SHIFT); /* < */
    ChatpadSetGreen(configuration, 0x52, 0x37, CHATPAD_HID_LEFT_SHIFT); /* > */
    ChatpadSetGreen(configuration, 0x53, 0x38, CHATPAD_HID_LEFT_SHIFT); /* ? */

    /* Layout-dependent printed glyphs stay disabled; only deterministic HID output is built in. */
    ChatpadSetOrange(configuration, 0x24, 0x21, CHATPAD_HID_LEFT_SHIFT); /* $ */
    ChatpadSetOrange(configuration, 0x64, 0x2E, 0);                    /* = */
    ChatpadSetOrange(configuration, 0x32, 0x31, 0);                    /* backslash */
    ChatpadSetOrange(configuration, 0x31, 0x34, CHATPAD_HID_LEFT_SHIFT); /* quote */
    ChatpadSetOrange(configuration, 0x62, 0x33, 0);                    /* semicolon */
    ChatpadSetOrange(configuration, 0x43, 0x2D, CHATPAD_HID_LEFT_SHIFT); /* underscore */
    ChatpadSetOrange(configuration, 0x42, 0x2E, CHATPAD_HID_LEFT_SHIFT); /* plus */
    ChatpadSetOrange(configuration, CHATPAD_PSEUDO_KEY_SHIFT, 0x39, 0); /* Caps Lock */
}

static int ChatpadProfileNameIsValid(const char *name)
{
    ChatpadSize index;
    int terminated;
    terminated = 0;
    for (index = 0; index < CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH; ++index) {
        unsigned char value = (unsigned char)name[index];
        if (value == 0) {
            terminated = 1;
            break;
        }
        if (!((value >= 'A' && value <= 'Z') ||
              (value >= 'a' && value <= 'z') ||
              (value >= '0' && value <= '9') || value == '-' || value == '_' || value == '.')) {
            return 0;
        }
    }
    if (!terminated || index == 0) {
        return 0;
    }
    if ((index == 1 && name[0] == '.') ||
        (index == 2 && name[0] == '.' && name[1] == '.')) {
        return 0;
    }
    return 1;
}

static int ChatpadActionIsValid(const ChatpadMappingAction *action)
{
    if (action->Reserved != 0) {
        return 0;
    }
    if (action->Type == CHATPAD_MAPPING_ACTION_DISABLED) {
        return action->Usage == 0 && action->Modifiers == 0;
    }
    if (action->Type != CHATPAD_MAPPING_ACTION_KEYBOARD) {
        return 0;
    }
    return action->Usage > 0 && action->Usage <= 0x65;
}

ChatpadConfigurationValidationResult ChatpadValidateConfiguration(
    const ChatpadConfiguration *configuration)
{
    ChatpadSize index;
    ChatpadSize reservedIndex;
    if (configuration == 0) return CHATPAD_CONFIGURATION_NULL;
    if (configuration->SchemaVersion != CHATPAD_CONFIGURATION_SCHEMA_VERSION)
        return CHATPAD_CONFIGURATION_UNSUPPORTED_SCHEMA;
    if (configuration->AbiVersion != CHATPAD_CONFIGURATION_ABI_VERSION)
        return CHATPAD_CONFIGURATION_UNSUPPORTED_ABI;
    if (configuration->Layout > CHATPAD_PROFILE_LAYOUT_AZERTY)
        return CHATPAD_CONFIGURATION_UNSUPPORTED_LAYOUT;
    if (configuration->PeopleAction != CHATPAD_PEOPLE_ACTION_DISABLED)
        return CHATPAD_CONFIGURATION_UNSUPPORTED_PEOPLE_ACTION;
    for (reservedIndex = 0; reservedIndex < sizeof(configuration->Reserved); ++reservedIndex) {
        if (configuration->Reserved[reservedIndex] != 0)
            return CHATPAD_CONFIGURATION_RESERVED_NONZERO;
    }
    if (!ChatpadProfileNameIsValid(configuration->ProfileName))
        return CHATPAD_CONFIGURATION_INVALID_PROFILE_NAME;
    for (index = 0; index < CHATPAD_CONFIGURATION_MAP_SIZE; ++index) {
        const ChatpadMappingAction *base = &configuration->Base[index];
        const ChatpadMappingAction *green = &configuration->Green[index];
        const ChatpadMappingAction *orange = &configuration->Orange[index];
        if (!ChatpadIsSupportedPhysicalKey((ChatpadUInt8)index) &&
            (base->Type != CHATPAD_MAPPING_ACTION_DISABLED ||
             green->Type != CHATPAD_MAPPING_ACTION_DISABLED ||
             orange->Type != CHATPAD_MAPPING_ACTION_DISABLED)) {
            return CHATPAD_CONFIGURATION_UNSUPPORTED_PHYSICAL_KEY;
        }
        if (!ChatpadActionIsValid(base) || !ChatpadActionIsValid(green) || !ChatpadActionIsValid(orange))
            return CHATPAD_CONFIGURATION_INVALID_ACTION;
    }
    return CHATPAD_CONFIGURATION_VALID;
}

void ChatpadInitializeLayeredMappingState(ChatpadLayeredMappingState *state)
{
    if (state != 0) {
        ChatpadClearBytes(state, sizeof(*state));
    }
}

static const ChatpadMappingAction *ChatpadSelectAction(
    const ChatpadConfiguration *configuration,
    ChatpadUInt8 layer,
    ChatpadUInt8 rawKey)
{
    if (layer == CHATPAD_MODIFIER_GREEN) return &configuration->Green[rawKey];
    if (layer == CHATPAD_MODIFIER_ORANGE) return &configuration->Orange[rawKey];
    return &configuration->Base[rawKey];
}

static const ChatpadLayeredHeldKey *ChatpadFindHeld(
    const ChatpadLayeredMappingState *state,
    ChatpadUInt8 rawKey)
{
    ChatpadSize index;
    for (index = 0; index < 2; ++index) {
        if (rawKey != 0 && state->Held[index].RawKey == rawKey) return &state->Held[index];
    }
    return 0;
}

ChatpadHidMapResult ChatpadMapKeyboardPacketWithConfiguration(
    const ChatpadKeyboardPacket *packet,
    const ChatpadConfiguration *configuration,
    ChatpadLayeredMappingState *state,
    ChatpadHidKeyboardReport *report)
{
    ChatpadUInt8 rawKeys[2];
    ChatpadUInt8 layer;
    ChatpadUInt8 reportIndex;
    ChatpadSize index;
    ChatpadLayeredMappingState nextState;

    if (packet == 0) return CHATPAD_HID_MAP_NULL_PACKET;
    if (report == 0 || configuration == 0 || state == 0) return CHATPAD_HID_MAP_NULL_REPORT;
    ChatpadBuildAllKeysReleasedReport(report);
    ChatpadInitializeLayeredMappingState(&nextState);
    layer = packet->RawModifiers & (CHATPAD_MODIFIER_GREEN | CHATPAD_MODIFIER_ORANGE);
    if (layer == (CHATPAD_MODIFIER_GREEN | CHATPAD_MODIFIER_ORANGE)) {
        ChatpadInitializeLayeredMappingState(state);
        return CHATPAD_HID_MAP_UNSUPPORTED_MODIFIER;
    }
    rawKeys[0] = packet->RawKey0;
    rawKeys[1] = packet->RawKey1 == packet->RawKey0 ? 0 : packet->RawKey1;
    reportIndex = 2;
    for (index = 0; index < 2; ++index) {
        const ChatpadLayeredHeldKey *held;
        const ChatpadMappingAction *action;
        ChatpadUInt8 rawKey = rawKeys[index];
        if (rawKey == 0) continue;
        if (!ChatpadIsSupportedPhysicalKey(rawKey)) {
            ChatpadInitializeLayeredMappingState(state);
            return CHATPAD_HID_MAP_UNSUPPORTED_KEY;
        }
        held = ChatpadFindHeld(state, rawKey);
        action = held != 0 ? &held->Action : ChatpadSelectAction(configuration, layer, rawKey);
        if (action->Type != CHATPAD_MAPPING_ACTION_KEYBOARD) {
            ChatpadInitializeLayeredMappingState(state);
            return CHATPAD_HID_MAP_UNSUPPORTED_KEY;
        }
        nextState.Held[index].RawKey = rawKey;
        nextState.Held[index].Action = *action;
        report->Bytes[0] |= action->Modifiers;
        if (reportIndex < CHATPAD_HID_BOOT_REPORT_LENGTH) report->Bytes[reportIndex++] = action->Usage;
    }

    if ((packet->RawModifiers & CHATPAD_MODIFIER_SHIFT) != 0) {
        const ChatpadMappingAction *shiftAction = ChatpadSelectAction(
            configuration, layer, CHATPAD_PSEUDO_KEY_SHIFT);
        if (layer != 0 && shiftAction->Type == CHATPAD_MAPPING_ACTION_KEYBOARD) {
            report->Bytes[0] |= shiftAction->Modifiers;
            if (reportIndex < CHATPAD_HID_BOOT_REPORT_LENGTH) report->Bytes[reportIndex++] = shiftAction->Usage;
        } else {
            report->Bytes[0] |= CHATPAD_HID_LEFT_SHIFT;
        }
    }
    *state = nextState;
    return CHATPAD_HID_MAP_OK;
}

void ChatpadInitializeConfigurationStore(ChatpadConfigurationStore *store)
{
    if (store == 0) return;
    ChatpadBuildDefaultConfiguration(&store->Active);
    store->Generation = 1;
}

ChatpadConfigurationValidationResult ChatpadApplyConfiguration(
    ChatpadConfigurationStore *store,
    const ChatpadConfiguration *candidate)
{
    ChatpadConfigurationValidationResult result;
    if (store == 0 || candidate == 0) return CHATPAD_CONFIGURATION_NULL;
    result = ChatpadValidateConfiguration(candidate);
    if (result != CHATPAD_CONFIGURATION_VALID) return result;
    store->Active = *candidate;
    ++store->Generation;
    if (store->Generation == 0) store->Generation = 1;
    return CHATPAD_CONFIGURATION_VALID;
}

void ChatpadResetConfigurationStore(ChatpadConfigurationStore *store)
{
    unsigned long generation;
    if (store == 0) return;
    generation = store->Generation + 1;
    if (generation == 0) generation = 1;
    ChatpadBuildDefaultConfiguration(&store->Active);
    store->Generation = generation;
}
