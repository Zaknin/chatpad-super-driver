using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace ChatpadVirtualXbox;

internal sealed record PhysicalDeviceRecoveryResult(bool Success, string Code, string Detail);

internal interface IPhysicalDeviceRecovery
{
    Task<PhysicalDeviceRecoveryResult> RestartExactTargetAsync(CancellationToken stopping);
}

internal sealed record PhysicalDeviceCandidate(string InstanceId, string Service, IReadOnlyList<string> HardwareIds, uint DevInst);

internal static class PhysicalDeviceIdentity
{
    public static string UniqueTargetError(IReadOnlyList<PhysicalDeviceCandidate> candidates)
        => candidates.Count switch { 0 => "broker_physical_target_not_found", 1 => string.Empty, _ => "broker_physical_target_ambiguous" };

    public static bool IsExactWinUsbTarget(PhysicalDeviceCandidate candidate)
    {
        const string instancePrefix = "USB\\VID_045E&PID_028E\\";
        const string hardwarePrefix = "USB\\VID_045E&PID_028E";
        return candidate.InstanceId.StartsWith(instancePrefix, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(candidate.Service, "WinUSB", StringComparison.OrdinalIgnoreCase) &&
            candidate.HardwareIds.Any(id => string.Equals(id, hardwarePrefix, StringComparison.OrdinalIgnoreCase) ||
                id.StartsWith(hardwarePrefix + "&", StringComparison.OrdinalIgnoreCase));
    }
}

internal sealed class WindowsPhysicalDeviceRecovery : IPhysicalDeviceRecovery
{
    private static readonly Guid WinUsbInterfaceGuid = new("B6A5D05E-7E18-4DF1-8E47-12F072DE2C36");
    private const uint DigcfPresent = 0x00000002;
    private const uint DigcfDeviceInterface = 0x00000010;
    private const uint SpdrpHardwareId = 0x00000000;
    private const uint SpdrpService = 0x00000004;
    private const uint RegSz = 1;
    private const uint RegMultiSz = 7;
    private const uint CrSuccess = 0;
    private const uint CmLocateDevNodeNormal = 0;
    private const uint CmDisableUiNotOk = 0x00000002;
    private const uint DnStarted = 0x00000008;
    private static readonly IntPtr InvalidHandle = new(-1);

    public async Task<PhysicalDeviceRecoveryResult> RestartExactTargetAsync(CancellationToken stopping)
    {
        if (!OperatingSystem.IsWindows()) return Failed("broker_physical_recovery_unsupported", "Windows Configuration Manager is unavailable.");
        List<PhysicalDeviceCandidate> targets;
        try { targets = EnumerateTargets(); }
        catch (Exception error) { return Failed("broker_physical_target_enumeration_failed", error.Message); }
        string selectionError = PhysicalDeviceIdentity.UniqueTargetError(targets);
        if (selectionError.Length != 0)
            return Failed(selectionError, "Expected exactly one present USB 045E:028E WinUSB interface; found " + targets.Count + ".");
        if (stopping.IsCancellationRequested) return Failed("broker_physical_recovery_cancelled", "Service stop was requested before the device restart began.");

        var target = targets[0];
        uint disabled = CM_Disable_DevNode(target.DevInst, CmDisableUiNotOk);
        if (disabled != CrSuccess) return Failed("broker_physical_disable_failed", "CM_Disable_DevNode returned CONFIGRET 0x" + disabled.ToString("X8") + ".");

        // Once disabled, always issue the matching enable even if service stop arrives.
        uint enabled = CM_Enable_DevNode(target.DevInst, 0);
        if (enabled != CrSuccess) return Failed("broker_physical_enable_failed", "CM_Enable_DevNode returned CONFIGRET 0x" + enabled.ToString("X8") + " after a successful disable.");

        long deadline = Environment.TickCount64 + 15_000;
        while (Environment.TickCount64 < deadline)
        {
            if (stopping.IsCancellationRequested)
                return Failed("broker_physical_recovery_wait_cancelled", "The device was re-enabled, but service stop interrupted post-restart readiness verification.");
            try
            {
                var present = EnumerateTargets();
                if (present.Count == 1 && string.Equals(present[0].InstanceId, target.InstanceId, StringComparison.OrdinalIgnoreCase) &&
                    CM_Locate_DevNodeW(out uint devInst, present[0].InstanceId, CmLocateDevNodeNormal) == CrSuccess &&
                    CM_Get_DevNode_Status(out uint status, out uint problem, devInst, 0) == CrSuccess && problem == 0 && (status & DnStarted) != 0)
                    return new(true, string.Empty, "exact_winusb_target_restarted_and_started");
            }
            catch (Exception error) { return Failed("broker_physical_recovery_verify_failed", error.Message); }
            try { await Task.Delay(250, stopping).ConfigureAwait(false); }
            catch (OperationCanceledException) when (stopping.IsCancellationRequested)
            {
                return Failed("broker_physical_recovery_wait_cancelled", "The device was re-enabled, but service stop interrupted post-restart readiness verification.");
            }
        }
        return Failed("broker_physical_recovery_not_started", "The exact target was re-enabled, but it did not return to started/problem-zero state within 15 seconds.");
    }

    private static List<PhysicalDeviceCandidate> EnumerateTargets()
    {
        var interfaceGuid = WinUsbInterfaceGuid;
        IntPtr set = SetupDiGetClassDevsW(ref interfaceGuid, IntPtr.Zero, IntPtr.Zero, DigcfPresent | DigcfDeviceInterface);
        if (set == InvalidHandle) throw new Win32Exception(Marshal.GetLastWin32Error(), "SetupDiGetClassDevsW failed.");
        try
        {
            var targets = new List<PhysicalDeviceCandidate>();
            bool enumerationComplete = false;
            for (uint index = 0; index < 4096; index++)
            {
                var interfaceData = new SpDeviceInterfaceData { CbSize = (uint)Marshal.SizeOf<SpDeviceInterfaceData>() };
                interfaceGuid = WinUsbInterfaceGuid;
                if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref interfaceGuid, index, ref interfaceData))
                {
                    int error = Marshal.GetLastWin32Error();
                    if (error == 259) { enumerationComplete = true; break; }
                    throw new Win32Exception(error, "SetupDiEnumDeviceInterfaces failed.");
                }
                uint required;
                _ = SetupDiGetDeviceInterfaceDetailW(set, ref interfaceData, IntPtr.Zero, 0, out required, IntPtr.Zero);
                int sizeError = Marshal.GetLastWin32Error();
                if (sizeError != 122 || required < 8 || required > 65536)
                    throw new Win32Exception(sizeError, "Device-interface detail size was invalid.");
                IntPtr detail = Marshal.AllocHGlobal(checked((int)required));
                try
                {
                    Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6);
                    var deviceData = new SpDeviceInfoData { CbSize = (uint)Marshal.SizeOf<SpDeviceInfoData>() };
                    if (!SetupDiGetDeviceInterfaceDetailW(set, ref interfaceData, detail, required, out _, ref deviceData))
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "SetupDiGetDeviceInterfaceDetailW failed.");
                    string instanceId = ReadInstanceId(set, ref deviceData);
                    if (!instanceId.StartsWith("USB\\VID_045E&PID_028E\\", StringComparison.OrdinalIgnoreCase)) continue;
                    string service = ReadStringProperty(set, ref deviceData, SpdrpService);
                    string hardwareIdsRaw = ReadStringProperty(set, ref deviceData, SpdrpHardwareId);
                    var hardwareIds = hardwareIdsRaw.Split('\0', StringSplitOptions.RemoveEmptyEntries);
                    var candidate = new PhysicalDeviceCandidate(instanceId, service, hardwareIds, deviceData.DevInst);
                    if (PhysicalDeviceIdentity.IsExactWinUsbTarget(candidate)) targets.Add(candidate);
                }
                finally { Marshal.FreeHGlobal(detail); }
            }
            if (!enumerationComplete) throw new InvalidOperationException("WinUSB interface enumeration exceeded the fail-closed 4096-device bound.");
            return targets;
        }
        finally { SetupDiDestroyDeviceInfoList(set); }
    }

    private static string ReadInstanceId(IntPtr set, ref SpDeviceInfoData deviceData)
    {
        var buffer = new StringBuilder(1024);
        if (!SetupDiGetDeviceInstanceIdW(set, ref deviceData, buffer, (uint)buffer.Capacity, out _))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "SetupDiGetDeviceInstanceIdW failed.");
        return buffer.ToString();
    }

    private static string ReadStringProperty(IntPtr set, ref SpDeviceInfoData deviceData, uint property)
    {
        var buffer = new byte[4096];
        if (!SetupDiGetDeviceRegistryPropertyW(set, ref deviceData, property, out uint propertyType, buffer, (uint)buffer.Length, out uint required))
        {
            int error = Marshal.GetLastWin32Error();
            if (error != 122 || required == 0 || required > 65536) throw new Win32Exception(error, "SetupDiGetDeviceRegistryPropertyW failed.");
            buffer = new byte[checked((int)required)];
            if (!SetupDiGetDeviceRegistryPropertyW(set, ref deviceData, property, out propertyType, buffer, (uint)buffer.Length, out _))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "SetupDiGetDeviceRegistryPropertyW retry failed.");
        }
        uint expectedType = property == SpdrpHardwareId ? RegMultiSz : RegSz;
        if (propertyType != expectedType)
            throw new InvalidOperationException("Device identity property has unexpected registry type " + propertyType + ".");
        return Encoding.Unicode.GetString(buffer).TrimEnd('\0');
    }

    private static PhysicalDeviceRecoveryResult Failed(string code, string detail) => new(false, code, detail);

    [StructLayout(LayoutKind.Sequential)]
    private struct SpDeviceInterfaceData { public uint CbSize; public Guid InterfaceClassGuid; public uint Flags; public IntPtr Reserved; }
    [StructLayout(LayoutKind.Sequential)]
    private struct SpDeviceInfoData { public uint CbSize; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved; }

    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "SetupDiGetClassDevsW")]
    private static extern IntPtr SetupDiGetClassDevsW(ref Guid classGuid, IntPtr enumerator, IntPtr hwndParent, uint flags);
    [DllImport("setupapi.dll", SetLastError = true, EntryPoint = "SetupDiEnumDeviceInterfaces")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiEnumDeviceInterfaces(IntPtr deviceInfoSet, IntPtr deviceInfoData, ref Guid interfaceClassGuid, uint memberIndex, ref SpDeviceInterfaceData deviceInterfaceData);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "SetupDiGetDeviceInterfaceDetailW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiGetDeviceInterfaceDetailW(IntPtr deviceInfoSet, ref SpDeviceInterfaceData deviceInterfaceData, IntPtr detailData, uint detailDataSize, out uint requiredSize, IntPtr deviceInfoData);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "SetupDiGetDeviceInterfaceDetailW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiGetDeviceInterfaceDetailW(IntPtr deviceInfoSet, ref SpDeviceInterfaceData deviceInterfaceData, IntPtr detailData, uint detailDataSize, out uint requiredSize, ref SpDeviceInfoData deviceInfoData);
    [DllImport("setupapi.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiDestroyDeviceInfoList(IntPtr deviceInfoSet);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "SetupDiGetDeviceInstanceIdW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiGetDeviceInstanceIdW(IntPtr deviceInfoSet, ref SpDeviceInfoData deviceInfoData, StringBuilder deviceInstanceId, uint deviceInstanceIdSize, out uint requiredSize);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "SetupDiGetDeviceRegistryPropertyW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetupDiGetDeviceRegistryPropertyW(IntPtr deviceInfoSet, ref SpDeviceInfoData deviceInfoData, uint property, out uint propertyRegDataType, byte[] propertyBuffer, uint propertyBufferSize, out uint requiredSize);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode, EntryPoint = "CM_Locate_DevNodeW")]
    private static extern uint CM_Locate_DevNodeW(out uint devInst, string deviceId, uint flags);
    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Disable_DevNode")]
    private static extern uint CM_Disable_DevNode(uint devInst, uint flags);
    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Enable_DevNode")]
    private static extern uint CM_Enable_DevNode(uint devInst, uint flags);
    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_DevNode_Status")]
    private static extern uint CM_Get_DevNode_Status(out uint status, out uint problem, uint devInst, uint flags);
}
