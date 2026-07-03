// Source-level declarations only. This file is intentionally not referenced by
// any project and must not be compiled, loaded, or invoked in this phase.

using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Chatpad.ExactInstance.NativeInterop
{
    internal static class SetupApiNewdevDeclarations
    {
        internal const int MaxPath = 260;
        internal const int LineLength = 256;
        internal const int AnySizeArray = 1;

        internal const uint SPDIT_COMPATDRIVER = 0x00000002;
        internal const uint DIGCF_PRESENT = 0x00000002;
        internal const uint ERROR_INSUFFICIENT_BUFFER = 122;
        internal const uint ERROR_NO_MORE_ITEMS = 259;
        internal const int INVALID_HANDLE_VALUE = -1;

        [DllImport("setupapi.dll", EntryPoint = "SetupDiCreateDeviceInfoList", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        internal static extern IntPtr SetupDiCreateDeviceInfoList(
            ref Guid ClassGuid,
            IntPtr hwndParent);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiDestroyDeviceInfoList", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiDestroyDeviceInfoList(
            IntPtr DeviceInfoSet);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiOpenDeviceInfoW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiOpenDeviceInfoW(
            IntPtr DeviceInfoSet,
            string DeviceInstanceId,
            IntPtr hwndParent,
            uint OpenFlags,
            ref SP_DEVINFO_DATA DeviceInfoData);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDeviceInstanceIdW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDeviceInstanceIdW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            StringBuilder DeviceInstanceId,
            uint DeviceInstanceIdSize,
            out uint RequiredSize);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDevicePropertyW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDevicePropertyW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref DEVPROPKEY PropertyKey,
            out uint PropertyType,
            IntPtr PropertyBuffer,
            uint PropertyBufferSize,
            out uint RequiredSize,
            uint Flags);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDeviceRegistryPropertyW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDeviceRegistryPropertyW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            uint Property,
            out uint PropertyRegDataType,
            IntPtr PropertyBuffer,
            uint PropertyBufferSize,
            out uint RequiredSize);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiBuildDriverInfoList", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiBuildDriverInfoList(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            uint DriverType);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiDestroyDriverInfoList", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiDestroyDriverInfoList(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            uint DriverType);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiEnumDriverInfoW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiEnumDriverInfoW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            uint DriverType,
            uint MemberIndex,
            ref SP_DRVINFO_DATA_W DriverInfoData);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDriverInfoDetailW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDriverInfoDetailW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DRVINFO_DATA_W DriverInfoData,
            IntPtr DriverInfoDetailData,
            uint DriverInfoDetailDataSize,
            out uint RequiredSize);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiGetDriverInstallParamsW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiGetDriverInstallParamsW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DRVINFO_DATA_W DriverInfoData,
            ref SP_DEVINSTALL_PARAMS_W DriverInstallParams);

        [DllImport("setupapi.dll", EntryPoint = "SetupDiSetSelectedDriverW", ExactSpelling = true, CharSet = CharSet.Unicode, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool SetupDiSetSelectedDriverW(
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DRVINFO_DATA_W DriverInfoData);

        [DllImport("newdev.dll", EntryPoint = "DiInstallDevice", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool DiInstallDevice(
            IntPtr hwndParent,
            IntPtr DeviceInfoSet,
            ref SP_DEVINFO_DATA DeviceInfoData,
            ref SP_DRVINFO_DATA_W DriverInfoData,
            uint Flags,
            [MarshalAs(UnmanagedType.Bool)] out bool NeedReboot);
    }

    [StructLayout(LayoutKind.Sequential)]
    internal readonly struct ChatpadDeviceInfoSetHandleToken
    {
        internal ChatpadDeviceInfoSetHandleToken(IntPtr value) { Value = value; }
        internal IntPtr Value { get; }
        internal bool IsInvalid => Value == IntPtr.Zero || Value.ToInt64() == SetupApiNewdevDeclarations.INVALID_HANDLE_VALUE;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct SP_DEVINFO_DATA
    {
        internal uint cbSize;
        internal Guid ClassGuid;
        internal uint DevInst;
        internal UIntPtr Reserved;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct SP_DEVINSTALL_PARAMS_W
    {
        internal uint cbSize;
        internal uint Flags;
        internal uint FlagsEx;
        internal IntPtr hwndParent;
        internal IntPtr InstallMsgHandler;
        internal IntPtr InstallMsgHandlerContext;
        internal IntPtr FileQueue;
        internal UIntPtr ClassInstallReserved;
        internal uint Reserved;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.MaxPath)]
        internal string DriverPath;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct SP_DRVINFO_DATA_W
    {
        internal uint cbSize;
        internal uint DriverType;
        internal UIntPtr Reserved;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.LineLength)]
        internal string Description;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.LineLength)]
        internal string MfgName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.LineLength)]
        internal string ProviderName;

        internal System.Runtime.InteropServices.ComTypes.FILETIME DriverDate;
        internal ulong DriverVersion;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct SP_DRVINFO_DETAIL_DATA_W
    {
        internal uint cbSize;
        internal System.Runtime.InteropServices.ComTypes.FILETIME InfDate;
        internal uint CompatIDsOffset;
        internal uint CompatIDsLength;
        internal UIntPtr Reserved;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.LineLength)]
        internal string SectionName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.MaxPath)]
        internal string InfFileName;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.LineLength)]
        internal string DrvDescription;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = SetupApiNewdevDeclarations.AnySizeArray)]
        internal string HardwareID;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct DEVPROPKEY
    {
        internal Guid fmtid;
        internal uint pid;
    }
}
