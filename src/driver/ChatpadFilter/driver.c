#include "driver.h"
#include "driver.tmh"

EVT_WDF_OBJECT_CONTEXT_CLEANUP ChatpadEvtDriverContextCleanup;

_Use_decl_annotations_
void
ChatpadEvtDriverContextCleanup(
    WDFOBJECT DriverObject
    )
{
    WPP_CLEANUP(WdfDriverWdmGetDriverObject((WDFDRIVER)DriverObject));
}

_Use_decl_annotations_
NTSTATUS
DriverEntry(
    PDRIVER_OBJECT DriverObject,
    PUNICODE_STRING RegistryPath
    )
{
    WDF_DRIVER_CONFIG config;
    WDF_OBJECT_ATTRIBUTES driverAttributes;
    NTSTATUS status;

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilter: compile-only skeleton DriverEntry\n"));

    WPP_INIT_TRACING(DriverObject, RegistryPath);
    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DRIVER_ENTRY,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DRIVER_ENTRY_STARTED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DRIVER_ENTRY_STARTED),
        (unsigned long long)0u, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, 0u, 0u);

    WDF_DRIVER_CONFIG_INIT(&config, ChatpadEvtDeviceAdd);
    WDF_OBJECT_ATTRIBUTES_INIT(&driverAttributes);
    driverAttributes.EvtCleanupCallback = ChatpadEvtDriverContextCleanup;

    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DRIVER_ENTRY,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_WDF_DRIVER_CREATE_ATTEMPTED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_WDF_DRIVER_CREATE_ATTEMPTED),
        (unsigned long long)0u, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)CHATPAD_RUNTIME_STATUS_CLASS_SUCCESS, (ULONG)STATUS_SUCCESS,
        0u, 0u, 0u);
    status = WdfDriverCreate(
        DriverObject,
        RegistryPath,
        &driverAttributes,
        &config,
        WDF_NO_HANDLE);
    if (!NT_SUCCESS(status)) {
        KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_ERROR_LEVEL,
            "ChatpadFilter: WdfDriverCreate failed (0x%08X)\n",
            (unsigned int)status));
        ChatpadTrace(TRACE_LEVEL_ERROR, CHATPAD_TRACE_DRIVER_ENTRY,
            "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
            (ULONG)CHATPAD_RUNTIME_EVENT_WDF_DRIVER_CREATE_FAILED,
            ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_WDF_DRIVER_CREATE_FAILED),
            (unsigned long long)0u, (unsigned long long)0u,
            CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
            (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
            0u, 0u, 0u);
        WPP_CLEANUP(DriverObject);
        return status;
    }

    ChatpadTrace(TRACE_LEVEL_INFORMATION, CHATPAD_TRACE_DRIVER_ENTRY,
        "EventId=%lu EventName=%s AttemptId=%I64u Sequence=%I64u SchemaVersion=%lu StatusClass=%lu NtStatus=0x%08X Stage=%lu Data0=%lu Data1=%lu",
        (ULONG)CHATPAD_RUNTIME_EVENT_DRIVER_ENTRY_COMPLETED,
        ChatpadRuntimeTraceEventName(CHATPAD_RUNTIME_EVENT_DRIVER_ENTRY_COMPLETED),
        (unsigned long long)0u, (unsigned long long)0u,
        CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION,
        (ULONG)ChatpadRuntimeClassifyStatus(status), (ULONG)status,
        0u, 0u, 0u);
    return status;
}
