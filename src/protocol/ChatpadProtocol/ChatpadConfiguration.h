#ifndef CHATPAD_CONFIGURATION_H
#define CHATPAD_CONFIGURATION_H

#ifdef __cplusplus
extern "C" {
#endif

#include "ChatpadKeyboardHid.h"

#define CHATPAD_CONFIGURATION_SCHEMA_VERSION ((ChatpadUInt8)1)
#define CHATPAD_CONFIGURATION_ABI_VERSION ((ChatpadUInt8)1)
#define CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH ((ChatpadSize)64)
#define CHATPAD_CONFIGURATION_MAP_SIZE ((ChatpadSize)256)
#define CHATPAD_PSEUDO_KEY_SHIFT ((ChatpadUInt8)0xF1)

#define CHATPAD_MODIFIER_SHIFT ((ChatpadUInt8)0x01)
#define CHATPAD_MODIFIER_GREEN ((ChatpadUInt8)0x02)
#define CHATPAD_MODIFIER_ORANGE ((ChatpadUInt8)0x04)
#define CHATPAD_MODIFIER_PEOPLE ((ChatpadUInt8)0x08)

typedef enum ChatpadProfileLayout {
    CHATPAD_PROFILE_LAYOUT_QWERTY = 0,
    CHATPAD_PROFILE_LAYOUT_QWERTZ = 1,
    CHATPAD_PROFILE_LAYOUT_AZERTY = 2
} ChatpadProfileLayout;

typedef enum ChatpadPeopleAction {
    CHATPAD_PEOPLE_ACTION_DISABLED = 0
} ChatpadPeopleAction;

typedef enum ChatpadMappingActionType {
    CHATPAD_MAPPING_ACTION_DISABLED = 0,
    CHATPAD_MAPPING_ACTION_KEYBOARD = 1
} ChatpadMappingActionType;

typedef struct ChatpadMappingAction {
    ChatpadUInt8 Type;
    ChatpadUInt8 Usage;
    ChatpadUInt8 Modifiers;
    ChatpadUInt8 Reserved;
} ChatpadMappingAction;

typedef struct ChatpadConfiguration {
    ChatpadUInt8 SchemaVersion;
    ChatpadUInt8 AbiVersion;
    ChatpadUInt8 Layout;
    ChatpadUInt8 PeopleAction;
    ChatpadUInt8 Reserved[4];
    char ProfileName[CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH];
    ChatpadMappingAction Base[CHATPAD_CONFIGURATION_MAP_SIZE];
    ChatpadMappingAction Green[CHATPAD_CONFIGURATION_MAP_SIZE];
    ChatpadMappingAction Orange[CHATPAD_CONFIGURATION_MAP_SIZE];
} ChatpadConfiguration;

typedef enum ChatpadConfigurationValidationResult {
    CHATPAD_CONFIGURATION_VALID = 0,
    CHATPAD_CONFIGURATION_NULL,
    CHATPAD_CONFIGURATION_UNSUPPORTED_SCHEMA,
    CHATPAD_CONFIGURATION_UNSUPPORTED_ABI,
    CHATPAD_CONFIGURATION_UNSUPPORTED_LAYOUT,
    CHATPAD_CONFIGURATION_UNSUPPORTED_PEOPLE_ACTION,
    CHATPAD_CONFIGURATION_RESERVED_NONZERO,
    CHATPAD_CONFIGURATION_INVALID_PROFILE_NAME,
    CHATPAD_CONFIGURATION_UNSUPPORTED_PHYSICAL_KEY,
    CHATPAD_CONFIGURATION_INVALID_ACTION
} ChatpadConfigurationValidationResult;

typedef struct ChatpadLayeredHeldKey {
    ChatpadUInt8 RawKey;
    ChatpadMappingAction Action;
} ChatpadLayeredHeldKey;

typedef struct ChatpadLayeredMappingState {
    ChatpadLayeredHeldKey Held[2];
} ChatpadLayeredMappingState;

typedef struct ChatpadConfigurationStore {
    ChatpadConfiguration Active;
    unsigned long Generation;
} ChatpadConfigurationStore;

void ChatpadBuildDefaultConfiguration(ChatpadConfiguration *configuration);

ChatpadConfigurationValidationResult ChatpadValidateConfiguration(
    const ChatpadConfiguration *configuration);

void ChatpadInitializeLayeredMappingState(ChatpadLayeredMappingState *state);

ChatpadHidMapResult ChatpadMapKeyboardPacketWithConfiguration(
    const ChatpadKeyboardPacket *packet,
    const ChatpadConfiguration *configuration,
    ChatpadLayeredMappingState *state,
    ChatpadHidKeyboardReport *report);

int ChatpadIsSupportedPhysicalKey(ChatpadUInt8 rawKey);

void ChatpadInitializeConfigurationStore(ChatpadConfigurationStore *store);

ChatpadConfigurationValidationResult ChatpadApplyConfiguration(
    ChatpadConfigurationStore *store,
    const ChatpadConfiguration *candidate);

void ChatpadResetConfigurationStore(ChatpadConfigurationStore *store);

#ifdef __cplusplus
}
#endif

#endif
