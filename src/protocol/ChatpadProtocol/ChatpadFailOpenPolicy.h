#pragma once

#include "ChatpadProtocolTypes.h"

#if defined(_MSC_VER)
typedef unsigned __int32 ChatpadFailOpenUInt32;
typedef signed __int32 ChatpadFailOpenInt32;
#else
typedef uint32_t ChatpadFailOpenUInt32;
typedef int32_t ChatpadFailOpenInt32;
#endif

#define CHATPAD_KEYBOARD_QUEUE_CAPACITY ((ChatpadSize)8u)

typedef enum ChatpadOptionalFailureStage {
    CHATPAD_OPTIONAL_STAGE_NONE = 0,
    CHATPAD_OPTIONAL_STAGE_VIRTUAL_CHILD_CREATE,
    CHATPAD_OPTIONAL_STAGE_VHF_CREATE,
    CHATPAD_OPTIONAL_STAGE_VHF_START,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_WORKER_CREATE,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_1,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_2,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_3,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_4,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_5,
    CHATPAD_OPTIONAL_STAGE_ACTIVATION_STEP_6,
    CHATPAD_OPTIONAL_STAGE_INTERFACE_PIPE_DISCOVERY,
    CHATPAD_OPTIONAL_STAGE_CONTINUOUS_READER_SETUP,
    CHATPAD_OPTIONAL_STAGE_INPUT_READ,
    CHATPAD_OPTIONAL_STAGE_DECODER_INITIALIZATION,
    CHATPAD_OPTIONAL_STAGE_KEYBOARD_SUBMISSION,
    CHATPAD_OPTIONAL_STAGE_KEYBOARD_QUEUE_OVERFLOW
} ChatpadOptionalFailureStage;

typedef struct ChatpadFailOpenState {
    int ControllerForwardingEnabled;
    int ChatpadFeatureEnabled;
    int VirtualKeyboardAvailable;
    int PermanentFailure;
    int ActivationAttemptConsumed;
    int ActivationInProgress;
    int Removing;
    ChatpadFailOpenUInt32 D0Generation;
    ChatpadFailOpenUInt32 ForcedReleaseCount;
    ChatpadSize QueuedReportCount;
    ChatpadOptionalFailureStage FirstFailureStage;
    ChatpadFailOpenInt32 FirstFailureStatus;
} ChatpadFailOpenState;

void ChatpadFailOpenInitialize(ChatpadFailOpenState *state);
void ChatpadFailOpenBeginD0(ChatpadFailOpenState *state);
void ChatpadFailOpenEndD0(ChatpadFailOpenState *state);
void ChatpadFailOpenRecordFailure(
    ChatpadFailOpenState *state,
    ChatpadOptionalFailureStage stage,
    ChatpadFailOpenInt32 status,
    int permanentFailure);
ChatpadFailOpenInt32 ChatpadFailOpenPrepareHardwareResult(const ChatpadFailOpenState *state);
ChatpadFailOpenInt32 ChatpadFailOpenD0EntryResult(const ChatpadFailOpenState *state);
int ChatpadFailOpenTryBeginActivation(ChatpadFailOpenState *state);
void ChatpadFailOpenSetVirtualKeyboardAvailable(ChatpadFailOpenState *state, int available);
void ChatpadFailOpenCompleteActivation(ChatpadFailOpenState *state);
int ChatpadFailOpenQueueKeyboardReport(ChatpadFailOpenState *state);
void ChatpadFailOpenCompleteKeyboardReport(ChatpadFailOpenState *state);
void ChatpadFailOpenForceReleaseAndFlush(ChatpadFailOpenState *state);
void ChatpadFailOpenBeginRemoval(ChatpadFailOpenState *state);
