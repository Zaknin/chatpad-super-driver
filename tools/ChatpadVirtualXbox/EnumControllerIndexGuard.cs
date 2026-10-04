#if HIDMAESTRO
using Microsoft.Win32;
using System.Runtime.InteropServices;

namespace ChatpadVirtualXbox;

internal static class EnumControllerIndexGuard
{
    private const int ControllerIndex = 0;
    private static readonly string[] EnumRoots = ["ROOT", "SWD"];

    internal static bool HasPresentIndexZero(RegistryKey localMachine, Func<string, bool> isPresent)
        => FindPresentIndexZero(localMachine, isPresent) is not null;

    internal static string? FindPresentIndexZero(RegistryKey localMachine, Func<string, bool> isPresent)
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
                    if (value is int index && index == ControllerIndex)
                    {
                        string instanceId = enumRoot + "\\" + enumerator + "\\" + instance;
                        if (isPresent(instanceId)) return instanceId;
                    }
                }
            }
        }
        return null;
    }

    internal static bool HasPresentIndexZero(IEnumerable<(string InstanceId, object? Index)> entries,
        Func<string, bool> isPresent)
        => FindPresentIndexZero(entries, isPresent) is not null;

    internal static string? FindPresentIndexZero(IEnumerable<(string InstanceId, object? Index)> entries,
        Func<string, bool> isPresent)
    {
        foreach (var entry in entries)
            if (entry.Index is int index && index == ControllerIndex && isPresent(entry.InstanceId)) return entry.InstanceId;
        return null;
    }
}

internal static class DeviceNodePresence
{
    private const uint CrSuccess = 0x00000000;
    private const uint CmGetIdListFilterPresent = 0x00000100;

    internal static bool IsPresent(string instanceId)
    {
        if (!OperatingSystem.IsWindows())
            throw new BackendException("virtual_scope_probe_failed", "Windows device-node presence API is unavailable.");

        uint result = CM_Get_Device_ID_List_SizeW(out uint characterCount, null, CmGetIdListFilterPresent);
        if (result != CrSuccess)
            throw new BackendException("virtual_scope_probe_failed", $"CM_Get_Device_ID_List_Size failed with CONFIGRET 0x{result:X8}.");
        if (characterCount == 0 || characterCount > int.MaxValue / sizeof(char))
            throw new BackendException("virtual_scope_probe_failed", "CM_Get_Device_ID_List_Size returned an invalid character count.");

        IntPtr buffer = Marshal.AllocHGlobal(checked((int)characterCount * sizeof(char)));
        try
        {
            result = CM_Get_Device_ID_ListW(IntPtr.Zero, buffer, characterCount, CmGetIdListFilterPresent);
            if (result != CrSuccess)
                throw new BackendException("virtual_scope_probe_failed", $"CM_Get_Device_ID_List failed with CONFIGRET 0x{result:X8}.");
            string multiString = ReadMultiString(buffer, characterCount);
            return ContainsInstanceId(multiString, instanceId);
        }
        finally { Marshal.FreeHGlobal(buffer); }
    }

    internal static string ReadMultiString(IntPtr buffer, uint characterCount)
    {
        var entries = new List<string>();
        var current = new System.Text.StringBuilder();
        for (uint i = 0; i < characterCount; i++)
        {
            char value = (char)Marshal.ReadInt16(buffer, checked((int)i * sizeof(char)));
            if (value != '\0')
            {
                current.Append(value);
                continue;
            }
            if (current.Length == 0) return string.Join('\0', entries) + "\0\0";
            entries.Add(current.ToString());
            current.Clear();
        }
        throw new BackendException("virtual_scope_probe_failed", "CM_Get_Device_ID_List returned a non-terminated multi-string.");
    }

    internal static bool ContainsInstanceId(string multiString, string instanceId)
    {
        foreach (string candidate in multiString.Split('\0', StringSplitOptions.RemoveEmptyEntries))
            if (string.Equals(candidate, instanceId, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_Device_ID_List_SizeW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_ID_List_SizeW(out uint length, string? filter, uint flags);

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_Device_ID_ListW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_ID_ListW(IntPtr filter, IntPtr buffer, uint bufferLength, uint flags);
}
#endif
