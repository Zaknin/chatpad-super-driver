#include "driver.h"

_Use_decl_annotations_
NTSTATUS
ChatpadEvtDeviceAdd(
    WDFDRIVER Driver,
    PWDFDEVICE_INIT DeviceInit
    )
{
    WDFDEVICE device;
    NTSTATUS status;

    UNREFERENCED_PARAMETER(Driver);

    KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_INFO_LEVEL,
        "ChatpadFilter: compile-only skeleton EvtDeviceAdd\n"));

    WdfFdoInitSetFilter(DeviceInit);

    status = WdfDeviceCreate(
        &DeviceInit,
        WDF_NO_OBJECT_ATTRIBUTES,
        &device);
    if (!NT_SUCCESS(status)) {
        KdPrintEx((DPFLTR_IHVDRIVER_ID, DPFLTR_ERROR_LEVEL,
            "ChatpadFilter: WdfDeviceCreate failed (0x%08X)\n",
            (unsigned int)status));
        return status;
    }

    UNREFERENCED_PARAMETER(device);
    return status;
}
