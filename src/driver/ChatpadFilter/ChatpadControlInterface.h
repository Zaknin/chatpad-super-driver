#ifndef CHATPAD_CONTROL_INTERFACE_H
#define CHATPAD_CONTROL_INTERFACE_H

#include "ChatpadConfiguration.h"

#if defined(_KERNEL_MODE)
#include <devioctl.h>
#else
#include <Windows.h>
#include <winioctl.h>
#endif

/* {63B66B53-8AAE-4F7D-919B-7E1A4F167A04} */
static const GUID CHATPAD_CONTROL_INTERFACE_GUID =
    { 0x63b66b53, 0x8aae, 0x4f7d, { 0x91, 0x9b, 0x7e, 0x1a, 0x4f, 0x16, 0x7a, 0x04 } };

#define CHATPAD_CONTROL_INTERFACE_VERSION ((ULONG)1)
#define CHATPAD_CONTROL_DRIVER_VERSION_MAJOR ((ULONG)1)
#define CHATPAD_CONTROL_DRIVER_VERSION_MINOR ((ULONG)0)
#define CHATPAD_CONTROL_DRIVER_VERSION_PATCH ((ULONG)14)
#define CHATPAD_CONTROL_DRIVER_VERSION_BUILD ((ULONG)0)

typedef struct ChatpadControlStatus {
    ULONG StructureSize;
    ULONG InterfaceVersion;
    ULONG DriverVersionMajor;
    ULONG DriverVersionMinor;
    ULONG DriverVersionPatch;
    ULONG DriverVersionBuild;
    ULONG ConfigurationGeneration;
    ULONG ConfigurationSchemaVersion;
    ULONG ConfigurationAbiVersion;
    ULONG Layout;
    ULONG PeopleAction;
    ULONG ChatpadFeatureAvailable;
    char ActiveProfile[CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH];
} ChatpadControlStatus;

typedef struct ChatpadControlDiagnostics {
    ChatpadControlStatus Status;
    ULONG InputPacketCount;
    ULONG InputReportCount;
    ULONG ParseFailureCount;
    ULONG ConfigurationApplyCount;
    ULONG ConfigurationRejectCount;
} ChatpadControlDiagnostics;

#define IOCTL_CHATPAD_GET_STATUS CTL_CODE(FILE_DEVICE_UNKNOWN, 0x800, METHOD_BUFFERED, FILE_READ_ACCESS)
#define IOCTL_CHATPAD_GET_CONFIGURATION CTL_CODE(FILE_DEVICE_UNKNOWN, 0x801, METHOD_BUFFERED, FILE_READ_ACCESS)
#define IOCTL_CHATPAD_SET_CONFIGURATION CTL_CODE(FILE_DEVICE_UNKNOWN, 0x802, METHOD_BUFFERED, FILE_WRITE_ACCESS)
#define IOCTL_CHATPAD_RESET_CONFIGURATION CTL_CODE(FILE_DEVICE_UNKNOWN, 0x803, METHOD_BUFFERED, FILE_WRITE_ACCESS)
#define IOCTL_CHATPAD_GET_DIAGNOSTICS CTL_CODE(FILE_DEVICE_UNKNOWN, 0x804, METHOD_BUFFERED, FILE_READ_ACCESS)

#endif
