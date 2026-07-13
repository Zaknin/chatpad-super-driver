#pragma once

#include <wdf.h>
#include <usb.h>
#include <vhf.h>

#include "ChatpadKeyboardHid.h"
#include "ChatpadConfiguration.h"
#include "ChatpadControlInterface.h"
#include "ChatpadFailOpenPolicy.h"

#define CHATPAD_LIVE_RUNTIME_SIGNATURE ((ULONG)0x52504C43u)
#define CHATPAD_CONTROLLER_INPUT_INTERFACE_INDEX ((UCHAR)0u)
#define CHATPAD_CONTROLLER_INPUT_PIPE_INDEX ((UCHAR)0u)
#define CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)
#define CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)
#define CHATPAD_CONTROL_TIMEOUT_MS ((ULONG)1000u)
#define CHATPAD_INPUT_TIMEOUT_MS ((ULONG)250u)
#define CHATPAD_KEEPALIVE_INTERVAL_MS ((ULONG)1000u)
#define CHATPAD_KEEPALIVE_VALUE_A ((USHORT)0x001Fu)
#define CHATPAD_KEEPALIVE_VALUE_B ((USHORT)0x001Eu)
#define CHATPAD_BACKLIGHT_ENABLE_VALUE ((USHORT)0x001Bu)
#define CHATPAD_RUNTIME_DIAGNOSTIC_SCHEMA ((ULONG)4u)

typedef struct _CHATPAD_LIVE_RUNTIME {
    ULONG Signature;
    WDFDEVICE Device;
    WDFKEY DiagnosticKey;
    WDFWORKITEM ActivationWorkItem;
    WDFWORKITEM InputWorkItem;
    WDFWORKITEM KeyboardWorkItem;
    WDFWORKITEM DiagnosticWorkItem;
    WDFSPINLOCK StateLock;
    WDFSPINLOCK ConfigurationLock;
    VHFHANDLE VhfHandle;
    ChatpadHidReportState HidState;
    ChatpadConfigurationStore ConfigurationStore;
    ChatpadLayeredMappingState LayeredMappingState;
    ChatpadFailOpenState FailOpenState;
    ChatpadHidKeyboardReport KeyboardQueue[CHATPAD_KEYBOARD_QUEUE_CAPACITY];
    USBD_PIPE_HANDLE ControllerInputPipeHandle;
    USBD_PIPE_HANDLE InputPipeHandle;
    volatile LONG StopRequested;
    volatile LONG InD0;
    volatile LONG ConfigurationReady;
    volatile LONG ActivationQueued;
    volatile LONG ActivationAttemptConsumed;
    volatile LONG ActivationSucceeded;
    volatile LONG ReaderStarted;
    volatile LONG BacklightCommandSent;
    volatile LONG FirstInputCompletionRecorded;
    volatile LONG FirstKeepAliveRecorded;
    volatile LONG FirstRawPacketRecorded;
    volatile LONG FirstDecodeRecorded;
    volatile LONG FirstVhfSubmissionRecorded;
    volatile LONG DiagnosticQueued;
    volatile LONG KeyboardWorkQueued;
    volatile LONG ChatpadFeatureDisabled;
    volatile LONG VirtualKeyboardAvailable;
    volatile LONG FirstOptionalFailureStage;
    volatile LONG ControllerInputPipeFound;
    volatile LONG ControllerInputReady;
    volatile LONG Interface2Found;
    volatile LONG Pipe0Found;
    volatile LONG ConfigurationCompletionCount;
    ULONG InputEndpointAddress;
    ULONG InputMaximumPacketSize;
    ULONG InputPipeType;
    ULONG D0Generation;
    ULONG ActivationAttemptCount;
    ULONG ActivationSuccessCount;
    ULONG InputPacketCount;
    ULONG InputReportCount;
    ULONG KeepAliveAttemptCount;
    ULONG InputEmissionFailureCount;
    ULONG KeyboardQueueHead;
    ULONG KeyboardQueueTail;
    ULONG KeyboardQueueCount;
    ULONG ParseFailureCount;
    ULONG ConfigurationApplyCount;
    ULONG ConfigurationRejectCount;
    ULONGLONG NextKeepAliveDue;
    USHORT NextKeepAliveValue;
    NTSTATUS LastActivationStatus;
    ULONG LastActivationStep;
    ULONG LastBytesTransferred;
    USBD_STATUS LastUsbdStatus;
    NTSTATUS LastConfigurationNtStatus;
    NTSTATUS LastControllerInputNtStatus;
    NTSTATUS FirstOptionalFailureNtStatus;
    USBD_STATUS LastConfigurationUsbdStatus;
    USBD_STATUS LastControllerInputUsbdStatus;
    ULONG LastControllerInputBytes;
} CHATPAD_LIVE_RUNTIME, *PCHATPAD_LIVE_RUNTIME;

NTSTATUS ChatpadLiveRuntimeInitialize(
    WDFDEVICE device,
    PCHATPAD_LIVE_RUNTIME runtime);

NTSTATUS ChatpadLiveRuntimePrepareHardware(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeReleaseHardware(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeEnterD0(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeExitD0(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeCleanup(PCHATPAD_LIVE_RUNTIME runtime);

void ChatpadLiveGetControlStatus(
    PCHATPAD_LIVE_RUNTIME runtime,
    ChatpadControlStatus *status);
void ChatpadLiveGetConfiguration(
    PCHATPAD_LIVE_RUNTIME runtime,
    ChatpadConfiguration *configuration);
ChatpadConfigurationValidationResult ChatpadLiveApplyConfiguration(
    PCHATPAD_LIVE_RUNTIME runtime,
    const ChatpadConfiguration *configuration);
void ChatpadLiveResetConfiguration(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveGetDiagnostics(
    PCHATPAD_LIVE_RUNTIME runtime,
    ChatpadControlDiagnostics *diagnostics);

EVT_WDFDEVICE_WDM_IRP_PREPROCESS ChatpadLiveEvtWdmIrpPreprocess;
EVT_WDF_WORKITEM ChatpadLiveEvtActivationWorkItem;
EVT_WDF_WORKITEM ChatpadLiveEvtInputWorkItem;
EVT_WDF_WORKITEM ChatpadLiveEvtKeyboardWorkItem;
EVT_WDF_WORKITEM ChatpadLiveEvtDiagnosticWorkItem;
