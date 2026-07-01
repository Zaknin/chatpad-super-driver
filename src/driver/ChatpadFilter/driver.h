#pragma once

#include <ntddk.h>
#include <wdf.h>

#include "ChatpadFilterLifecycle.h"
#include "ChatpadKmdfRequestOwnerContext.h"
#include "ChatpadRuntimeDiagnostics.h"

#define CHATPAD_FILTER_DEVICE_CONTEXT_SIGNATURE ((ULONG)0x46444350u)
#define CHATPAD_FILTER_DEVICE_CONTEXT_VERSION ((ULONG)1u)

typedef struct _CHATPAD_FILTER_DEVICE_CONTEXT {
    ULONG Signature;
    ULONG Version;
    ULONG DiagnosticSequence;
    ULONG RuntimeTraceSchemaVersion;
    ChatpadRuntimeAttemptState RuntimeDiagnostics;
    ChatpadFilterLifecycleState Lifecycle;
    ChatpadKmdfActivationRequestOwner ActivationRequestOwner;
} CHATPAD_FILTER_DEVICE_CONTEXT, *PCHATPAD_FILTER_DEVICE_CONTEXT;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(CHATPAD_FILTER_DEVICE_CONTEXT, ChatpadFilterGetDeviceContext)

DRIVER_INITIALIZE DriverEntry;
EVT_WDF_DRIVER_DEVICE_ADD ChatpadEvtDeviceAdd;
EVT_WDF_DEVICE_PREPARE_HARDWARE ChatpadEvtDevicePrepareHardware;
EVT_WDF_DEVICE_RELEASE_HARDWARE ChatpadEvtDeviceReleaseHardware;
EVT_WDF_DEVICE_D0_ENTRY ChatpadEvtDeviceD0Entry;
EVT_WDF_DEVICE_D0_EXIT ChatpadEvtDeviceD0Exit;
EVT_WDF_OBJECT_CONTEXT_CLEANUP ChatpadEvtDeviceContextCleanup;

void ChatpadRuntimeIncrementProhibitedCounter(
    PCHATPAD_FILTER_DEVICE_CONTEXT context,
    ChatpadRuntimeProhibitedCounterKind counterKind);
