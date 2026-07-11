// Supplemental source-level declarations for a future exact single-INF APPLY flow.
// This file is intentionally not referenced by any project and must be compiled
// only together with Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs after
// TASK 8H authorization validation and atomic authorization consumption.
//
// Authoritative provenance: Windows SDK 10.0.26100.0.
// - um/setupapi.h: SetupDiGetDeviceInstallParamsW and
//   SetupDiSetDeviceInstallParamsW are WINSETUPAPI BOOL WINAPI functions in
//   setupapi.dll. Their ordered native parameters are HDEVINFO,
//   PSP_DEVINFO_DATA (optional), and PSP_DEVINSTALL_PARAMS_W; the get buffer is
//   _Out_ and the set buffer is _In_. The managed binding uses IntPtr followed
//   by ref SP_DEVINFO_DATA and ref SP_DEVINSTALL_PARAMS_W, Unicode W entry
//   points, Winapi calling convention, BOOL return marshaling, and preserved
//   last-error state. All three native parameters have pointer semantics.
// - shared/devpropdef.h and shared/devpkey.h: DEVPROPKEY is a GUID plus ULONG
//   property id. DEVPKEY_Device_ContainerId is DEVPROP_TYPE_GUID with fmtid
//   {8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c} and pid 2. The managed value reuses
//   the accepted DEVPROPKEY structure (Guid fmtid; uint pid).
// - um/setupapi.h: the selected SPDRP_* values are DWORD registry-property
//   identifiers passed to SetupDiGetDeviceRegistryPropertyW. HARDWAREID and
//   COMPATIBLEIDS validate candidate matching; CLASSGUID validates class
//   continuity; SERVICE and DRIVER validate the installed binding; MFG,
//   FRIENDLYNAME, and DEVICEDESC provide candidate/result identity diagnostics.
// - um/setupapi.h: DI_ENUMSINGLEINF (0x00010000) constrains DriverPath discovery
//   to one INF; DI_FLAGSEX_SEARCH_PUBLISHED_INFS (0x80000000) expresses a
//   published-INF search; DI_NEEDRESTART (0x00000080) and DI_NEEDREBOOT
//   (0x00000100) are returned installation-state flags. These are uint values;
//   they have no Unicode, pointer, or SetLastError behavior.

using System;
using System.Runtime.InteropServices;

namespace Chatpad.ExactInstance.NativeInterop
{
    internal static class SetupApiNewdevLiveApplyExtensions
    {
        internal static readonly DEVPROPKEY DEVPKEY_Device_ContainerId = new DEVPROPKEY
        {
            fmtid = new Guid("8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c"),
            pid = 2
        };

        internal const uint SPDRP_DEVICEDESC = 0x00000000;
        internal const uint SPDRP_HARDWAREID = 0x00000001;
        internal const uint SPDRP_COMPATIBLEIDS = 0x00000002;
        internal const uint SPDRP_SERVICE = 0x00000004;
        internal const uint SPDRP_CLASSGUID = 0x00000008;
        internal const uint SPDRP_DRIVER = 0x00000009;
        internal const uint SPDRP_MFG = 0x0000000B;
        internal const uint SPDRP_FRIENDLYNAME = 0x0000000C;

        internal const uint DI_NEEDRESTART = 0x00000080;
        internal const uint DI_NEEDREBOOT = 0x00000100;
        internal const uint DI_ENUMSINGLEINF = 0x00010000;
        internal const uint DI_FLAGSEX_SEARCH_PUBLISHED_INFS = 0x80000000;

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDeviceInstallParamsW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDeviceInstallParamsW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DEVINSTALL_PARAMS_W DeviceInstallParams);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiSetDeviceInstallParamsW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiSetDeviceInstallParamsW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DEVINSTALL_PARAMS_W DeviceInstallParams);
    }
}
