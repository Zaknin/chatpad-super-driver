#pragma once

#include <wdf.h>
#include <usb.h>
#include <vhf.h>

#include "ChatpadKeyboardHid.h"

#define CHATPAD_LIVE_RUNTIME_SIGNATURE ((ULONG)0x52504C43u)
#define CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)
#define CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)
#define CHATPAD_CONTROL_TIMEOUT_MS ((ULONG)1000u)
#define CHATPAD_INPUT_TIMEOUT_MS ((ULONG)250u)
#define CHATPAD_RUNTIME_DIAGNOSTIC_SCHEMA ((ULONG)2u)

typedef struct _CHATPAD_LIVE_RUNTIME {
    ULONG Signature;
    WDFDEVICE Device;
    WDFKEY DiagnosticKey;
    WDFWORKITEM ActivationWorkItem;
    WDFWORKITEM InputWorkItem;
    WDFWORKITEM DiagnosticWorkItem;
    WDFSPINLOCK StateLock;
    VHFHANDLE VhfHandle;
    ChatpadHidReportState HidState;
    USBD_PIPE_HANDLE InputPipeHandle;
    volatile LONG StopRequested;
    volatile LONG InD0;
    volatile LONG ConfigurationReady;
    volatile LONG ActivationQueued;
    volatile LONG ActivationAttemptConsumed;
    volatile LONG ActivationSucceeded;
    volatile LONG ReaderStarted;
    volatile LONG FirstInputCompletionRecorded;
    volatile LONG FirstRawPacketRecorded;
    volatile LONG FirstDecodeRecorded;
    volatile LONG FirstVhfSubmissionRecorded;
    volatile LONG DiagnosticQueued;
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
    ULONG InputEmissionFailureCount;
    ULONG ParseFailureCount;
    NTSTATUS LastActivationStatus;
    ULONG LastActivationStep;
    ULONG LastBytesTransferred;
    USBD_STATUS LastUsbdStatus;
    NTSTATUS LastConfigurationNtStatus;
    USBD_STATUS LastConfigurationUsbdStatus;
} CHATPAD_LIVE_RUNTIME, *PCHATPAD_LIVE_RUNTIME;

NTSTATUS ChatpadLiveRuntimeInitialize(
    WDFDEVICE device,
    PCHATPAD_LIVE_RUNTIME runtime);

NTSTATUS ChatpadLiveRuntimePrepareHardware(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeReleaseHardware(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeEnterD0(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeExitD0(PCHATPAD_LIVE_RUNTIME runtime);
void ChatpadLiveRuntimeCleanup(PCHATPAD_LIVE_RUNTIME runtime);

EVT_WDFDEVICE_WDM_IRP_PREPROCESS ChatpadLiveEvtWdmIrpPreprocess;
EVT_WDF_WORKITEM ChatpadLiveEvtActivationWorkItem;
EVT_WDF_WORKITEM ChatpadLiveEvtInputWorkItem;
EVT_WDF_WORKITEM ChatpadLiveEvtDiagnosticWorkItem;
