#ifndef CHATPAD_CONTROL_DEVICE_H
#define CHATPAD_CONTROL_DEVICE_H

#include <ntddk.h>
#include <wdf.h>

NTSTATUS ChatpadControlCreate(WDFDEVICE device);
EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL ChatpadControlEvtIoDeviceControl;

#endif
