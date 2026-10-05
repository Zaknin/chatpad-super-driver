using System.Runtime.InteropServices;
using System.Text;

namespace ChatpadVirtualXbox;

internal static class XusbInterfaceQualification
{
    internal static readonly Guid InterfaceClass = new("EC87F1E3-C13B-4100-B5F7-8B84D54260CB");
    private const uint CrSuccess = 0;
    private const uint CmGetDeviceInterfaceListPresent = 0;
    private const int MaximumCharacters = 65536;

    internal static bool HasExpectedInterface(IEnumerable<string> interfacePaths, string controllerInstanceId)
    {
        string? token = GetControllerToken(controllerInstanceId);
        if (token is null) return false;
        string expected = "\\\\?\\" + $"SWD#HIDMAESTRO#{token}#{{{InterfaceClass:D}}}";
        foreach (string path in interfacePaths)
        {
            if (string.Equals(path.TrimEnd('\\'), expected, StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    internal static string? GetControllerToken(string? instanceId)
    {
        if (string.IsNullOrWhiteSpace(instanceId)) return null;
        int separator = instanceId.LastIndexOf('\\');
        if (separator < 0 || separator == instanceId.Length - 1) return null;
        string token = instanceId[(separator + 1)..];
        if (token.Length > 64 || token.Any(c => !char.IsAsciiLetterOrDigit(c) && c != '_')) return null;
        return token;
    }

    internal static bool WaitForExpectedInterface(string controllerInstanceId, int timeoutMs)
    {
        if (timeoutMs < 0 || timeoutMs > 30000)
            throw new BackendException("xusb_probe_invalid_timeout", "XUSB interface wait must be between 0 and 30000 ms.");
        long stopAt = Environment.TickCount64 + timeoutMs;
        do
        {
            if (HasExpectedInterface(ReadPresentInterfacePaths(), controllerInstanceId)) return true;
            if (Environment.TickCount64 >= stopAt) break;
            Thread.Sleep(50);
        } while (true);
        return false;
    }

    private static IReadOnlyList<string> ReadPresentInterfacePaths()
    {
        if (!OperatingSystem.IsWindows())
            throw new BackendException("xusb_probe_failed", "Windows device-interface enumeration is unavailable.");

        Guid interfaceClass = InterfaceClass;
        uint result = CM_Get_Device_Interface_List_SizeW(out uint length, ref interfaceClass, null, CmGetDeviceInterfaceListPresent);
        if (result != CrSuccess)
            throw new BackendException("xusb_probe_failed", $"CM_Get_Device_Interface_List_Size failed with CONFIGRET 0x{result:X8}.");
        if (length == 0) return Array.Empty<string>();
        if (length > MaximumCharacters)
            throw new BackendException("xusb_probe_failed", "CM_Get_Device_Interface_List_Size returned an invalid character count.");

        for (int attempt = 0; attempt < 3; attempt++)
        {
            IntPtr buffer = Marshal.AllocHGlobal(checked((int)length * sizeof(char)));
            try
            {
                result = CM_Get_Device_Interface_ListW(ref interfaceClass, null, buffer, length, CmGetDeviceInterfaceListPresent);
                if (result == CrSuccess)
                    return ParseMultiString(buffer, length);
                if (result != 0x0000001A) // CR_BUFFER_SMALL
                    throw new BackendException("xusb_probe_failed", $"CM_Get_Device_Interface_List failed with CONFIGRET 0x{result:X8}.");
            }
            finally { Marshal.FreeHGlobal(buffer); }

            result = CM_Get_Device_Interface_List_SizeW(out length, ref interfaceClass, null, CmGetDeviceInterfaceListPresent);
            if (result != CrSuccess || length > MaximumCharacters)
                throw new BackendException("xusb_probe_failed", $"XUSB interface list changed and could not be re-sized (CONFIGRET 0x{result:X8}).");
            if (length == 0) return Array.Empty<string>();
        }
        throw new BackendException("xusb_probe_failed", "XUSB interface list changed repeatedly during enumeration.");
    }

    private static IReadOnlyList<string> ParseMultiString(IntPtr buffer, uint length)
    {
        var result = new List<string>();
        var item = new StringBuilder();
        for (uint i = 0; i < length; i++)
        {
            char current = (char)Marshal.ReadInt16(buffer, checked((int)i * sizeof(char)));
            if (current != '\0') { item.Append(current); continue; }
            if (item.Length == 0) return result;
            result.Add(item.ToString());
            item.Clear();
        }
        throw new BackendException("xusb_probe_failed", "CM_Get_Device_Interface_List returned an unterminated multi-string.");
    }

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_Device_Interface_List_SizeW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_Interface_List_SizeW(out uint length, ref Guid interfaceClassGuid, string? deviceInstanceId, uint flags);

    [DllImport("cfgmgr32.dll", EntryPoint = "CM_Get_Device_Interface_ListW", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern uint CM_Get_Device_Interface_ListW(ref Guid interfaceClassGuid, string? deviceInstanceId, IntPtr buffer, uint bufferLength, uint flags);
}
