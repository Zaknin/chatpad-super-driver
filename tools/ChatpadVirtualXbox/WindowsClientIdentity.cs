using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace ChatpadVirtualXbox;

[SupportedOSPlatform("windows")]
internal static class WindowsClientIdentity
{
    private const int WtsActive = 0;
    private const int WtsClientProtocolType = 16;
    private const int WtsConnectState = 8;
    private const int ConsoleProtocol = 0;
    private const int ErrorPipeLocal = 229; // GetNamedPipeClientComputerName reports ERROR_PIPE_LOCAL for a local connection.
    private static readonly string MachineName = Environment.MachineName;

    public static BrokerPeerSnapshot Capture(NamedPipeServerStream pipe)
    {
        string? sid = null;
        bool anonymous = true;
        pipe.RunAsClient(() =>
        {
            using var identity = WindowsIdentity.GetCurrent();
            sid = identity.User?.Value;
            anonymous = identity.IsAnonymous || string.Equals(sid, "S-1-5-7", StringComparison.OrdinalIgnoreCase);
        });

        if (!GetNamedPipeClientSessionId(pipe.SafePipeHandle, out uint session))
            throw new BackendException("broker_peer_identity_failed", "Unable to read the connected client's token session.");
        uint active = WTSGetActiveConsoleSessionId();
        var clientMachine = new StringBuilder(256);
        bool computerNameAvailable = GetNamedPipeClientComputerName(pipe.SafePipeHandle, clientMachine, (uint)clientMachine.Capacity);
        int computerNameError = computerNameAvailable ? 0 : Marshal.GetLastWin32Error();
        bool? localClient = ResolveLocality(computerNameAvailable, clientMachine.ToString(), computerNameError, MachineName);
        if (localClient is null)
            throw new BackendException("broker_peer_identity_failed", "Unable to verify local named-pipe client locality (Win32 " + computerNameError + ").");
        bool activeSession = active != uint.MaxValue && active == session && ReadWtsInt((int)session, WtsConnectState) == WtsActive;
        bool consoleProtocol = activeSession && ReadWtsUShort((int)session, WtsClientProtocolType) == ConsoleProtocol;
        return new BrokerPeerSnapshot(sid ?? string.Empty, checked((int)session), active == uint.MaxValue ? -1 : checked((int)active), consoleProtocol, anonymous, !localClient.Value);
    }

    internal static bool? ResolveLocality(bool querySucceeded, string? clientComputerName, int errorCode, string localMachineName)
    {
        if (querySucceeded)
            return string.Equals(clientComputerName, localMachineName, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(clientComputerName, localMachineName + ".", StringComparison.OrdinalIgnoreCase);
        return errorCode == ErrorPipeLocal ? true : null;
    }

    private static int ReadWtsInt(int sessionId, int infoClass)
    {
        IntPtr buffer = IntPtr.Zero;
        try
        {
            if (!WTSQuerySessionInformation(IntPtr.Zero, sessionId, infoClass, out buffer, out _)) return -1;
            return Marshal.ReadInt32(buffer);
        }
        finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
    }

    private static int ReadWtsUShort(int sessionId, int infoClass)
    {
        IntPtr buffer = IntPtr.Zero;
        try
        {
            if (!WTSQuerySessionInformation(IntPtr.Zero, sessionId, infoClass, out buffer, out _)) return -1;
            return unchecked((ushort)Marshal.ReadInt16(buffer));
        }
        finally { if (buffer != IntPtr.Zero) WTSFreeMemory(buffer); }
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetNamedPipeClientSessionId(SafePipeHandle pipe, out uint sessionId);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "GetNamedPipeClientComputerNameW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetNamedPipeClientComputerName(SafePipeHandle pipe, StringBuilder computerName, uint bufferSize);

    [DllImport("kernel32.dll")]
    private static extern uint WTSGetActiveConsoleSessionId();

    [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "WTSQuerySessionInformationW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool WTSQuerySessionInformation(IntPtr server, int sessionId, int infoClass, out IntPtr buffer, out int bytesReturned);

    [DllImport("wtsapi32.dll")]
    private static extern void WTSFreeMemory(IntPtr memory);
}
