#if HIDMAESTRO
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace ChatpadVirtualXbox;

internal static class EnumControllerIndexGuard
{
    private const int ControllerIndex = 0;
    private static readonly string[] EnumRoots = ["ROOT", "SWD"];

    internal static bool HasPresentIndexZero(RegistryKey localMachine, Func<string, bool> isPresent)
    {
        foreach (string enumRoot in EnumRoots)
        {
            using var root = localMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Enum\" + enumRoot);
            foreach (string enumerator in root?.GetSubKeyNames() ?? [])
            {
                if (!enumerator.StartsWith("VID_", StringComparison.OrdinalIgnoreCase) &&
                    !enumerator.StartsWith("HIDMAESTRO", StringComparison.OrdinalIgnoreCase)) continue;
                using var group = root!.OpenSubKey(enumerator);
                foreach (string instance in group?.GetSubKeyNames() ?? [])
                {
                    using var parameters = group!.OpenSubKey(instance + @"\Device Parameters");
                    object? value = parameters?.GetValue("ControllerIndex");
                    if (value is int index && IsConflict(index, isPresent,
                            enumRoot + "\\" + enumerator + "\\" + instance)) return true;
                }
            }
        }
        return false;
    }

    internal static bool HasPresentIndexZero(IEnumerable<(string InstanceId, object? Index)> entries,
        Func<string, bool> isPresent)
    {
        foreach (var entry in entries)
            if (entry.Index is int index && IsConflict(index, isPresent, entry.InstanceId)) return true;
        return false;
    }

    private static bool IsConflict(int index, Func<string, bool> isPresent, string instanceId) =>
        index == ControllerIndex && isPresent(instanceId);
}

internal static class DeviceNodePresence
{
    private const uint CrSuccess = 0x00000000;
    private const uint CrInvalidDevnode = 0x0000000C;
    private const uint CrNoSuchDevnode = 0x0000000D;
    private const uint DnPresent = 0x00000002;

    internal static bool IsPresent(string instanceId)
    {
        if (!OperatingSystem.IsWindows())
            throw new BackendException("virtual_scope_probe_failed", "Windows device-node presence API is unavailable.");

        uint result = CM_Locate_DevNodeW(out uint devInst, instanceId, 0);
        if (result is CrInvalidDevnode or CrNoSuchDevnode) return false;
        if (result != CrSuccess)
            throw new BackendException("virtual_scope_probe_failed", $"CM_Locate_DevNode failed for {instanceId} with CONFIGRET 0x{result:X8}.");

        result = CM_Get_DevNode_Status(out uint status, out _, devInst, 0);
        if (result is CrInvalidDevnode or CrNoSuchDevnode) return false;
        if (result != CrSuccess)
            throw new BackendException("virtual_scope_probe_failed", $"CM_Get_DevNode_Status failed for {instanceId} with CONFIGRET 0x{result:X8}.");
        return (status & DnPresent) != 0;
    }

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Locate_DevNodeW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Locate_DevNodeW(out uint devInst, string deviceId, uint flags);

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_DevNode_Status", ExactSpelling = true)]
    private static extern uint CM_Get_DevNode_Status(out uint status, out uint problemNumber, uint devInst, uint flags);
}
#endif
