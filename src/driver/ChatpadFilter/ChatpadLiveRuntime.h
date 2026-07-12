#pragma once

#include <wdf.h>
#include <wdfusb.h>
#include <vhf.h>

#include "ChatpadKeyboardHid.h"

#define CHATPAD_LIVE_RUNTIME_SIGNATURE ((ULONG)0x52504C43u)
#define CHATPAD_INPUT_INTERFACE_INDEX ((UCHAR)2u)
#define CHATPAD_INPUT_PIPE_INDEX ((UCHAR)0u)
#define CHATPAD_CONTROL_TIMEOUT_MS ((ULONG)1000u)

typedef struct _CHATPAD_LIVE_RUNTIME {
    ULONG Signature;
    WDFDEVICE Device;
    WDFUSBDEVICE UsbDevice;
    WDFUSBPIPE InputPipe;
    WDFWORKITEM ActivationWorkItem;
    WDFWORKITEM InputWorkItem;
    WDFSPINLOCK StateLock;
    VHFHANDLE VhfHandle;
    ChatpadHidReportState HidState;
    volatile LONG StopRequested;
    volatile LONG InD0;
    volatile LONG ConfigurationReady;
    volatile LONG ActivationQueued;
    volatile LONG ActivationAttemptConsumed;
    volatile LONG ActivationSucceeded;
    volatile LONG ReaderStarted;
    ULONG D0Generation;
    ULONG ActivationAttemptCount;
    ULONG ActivationSuccessCount;
    ULONG InputPacketCount;
    ULONG InputReportCount;
    ULONG InputEmissionFailureCount;
    ULONG ParseFailureCount;
    volatile LONG FirstValidInputLogged;
    NTSTATUS LastActivationStatus;
    ULONG LastActivationStep;
    ULONG LastBytesTransferred;
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
