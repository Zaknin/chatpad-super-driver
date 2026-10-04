using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Text.Json;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;

namespace ChatpadVirtualXbox;

[SupportedOSPlatform("windows")]
internal sealed class BrokerPipeServer
{
    public const string PipeName = "ChatpadHidMaestroBroker.v1";
    public const string ServiceName = "ChatpadHidMaestroBroker";
    internal const uint FirstPipeInstanceFlag = 0x00080000u;
    internal const uint RejectRemoteClientsFlag = 0x00000008u;
    internal const uint PipeOpenMode = 0x00000003u | 0x40000000u | FirstPipeInstanceFlag;
    internal const uint PipeMode = RejectRemoteClientsFlag;
    private const string AuthorizationFileName = "BrokerAuthorization.json";
    private const string ParametersKey = @"SYSTEM\CurrentControlSet\Services\ChatpadHidMaestroBroker\Parameters";

    private readonly string installRoot;
    private readonly Func<IVirtualXboxController> backendFactory;

    public BrokerPipeServer(string installRoot, Func<IVirtualXboxController> backendFactory)
    {
        this.installRoot = BrokerRuntimePaths.ValidateInstallRoot(installRoot);
        this.backendFactory = backendFactory;
    }

    public async Task RunAsync(CancellationToken stopping)
    {
        var authorization = LoadAuthorization();
        while (!stopping.IsCancellationRequested)
        {
            using var pipe = CreateFirstLocalPipe(authorization.AuthorizedSid);
            try { await pipe.WaitForConnectionAsync(stopping).ConfigureAwait(false); }
            catch (OperationCanceledException) when (stopping.IsCancellationRequested) { break; }

            var peer = WindowsClientIdentity.Capture(pipe);
            if (!authorization.Policy.IsAuthorized(peer))
            {
                Console.Error.WriteLine("broker rejected peer outside the authorized active local console session");
                continue;
            }

            await using var session = new BrokerSession(backendFactory, (line, token) => WriteFrameAsync(pipe, line, token));
            using var connectionStop = CancellationTokenSource.CreateLinkedTokenSource(stopping);
            var reader = ReadClientAsync(pipe, session, connectionStop.Token);
            var stopWait = Task.Delay(Timeout.InfiniteTimeSpan, connectionStop.Token);
            var completed = await Task.WhenAny(reader, session.Faulted, stopWait).ConfigureAwait(false);
            if (completed == session.Faulted)
                throw new BackendException("broker_session_failed", session.Faulted.Result.Message);
            if (completed == reader)
            {
                try { await reader.ConfigureAwait(false); }
                catch (OperationCanceledException) when (stopping.IsCancellationRequested) { }
                catch (Exception e) when (!stopping.IsCancellationRequested) { Console.Error.WriteLine("broker client ended: " + e.Message); }
            }
            connectionStop.Cancel();
            await session.StopAsync().ConfigureAwait(false);
            if (stopping.IsCancellationRequested) break;
        }
    }

    private (BrokerPeerAuthorization Policy, string AuthorizedSid) LoadAuthorization()
    {
        string path = BrokerRuntimePaths.Member(installRoot, AuthorizationFileName);
        BrokerRuntimePaths.RequireRegularFile(path);
        byte[] bytes = File.ReadAllBytes(path);
        if (bytes.Length > BrokerProtocol.MaximumFrameBytes) throw new BackendException("broker_configuration_invalid", "Authorization configuration is too large.");
        string expectedHash;
        using (var key = Registry.LocalMachine.OpenSubKey(ParametersKey, writable: false))
            expectedHash = key?.GetValue("AuthorizationSha256") as string ?? string.Empty;
        string actualHash = Convert.ToHexString(SHA256.HashData(bytes));
        if (!string.Equals(expectedHash, actualHash, StringComparison.OrdinalIgnoreCase))
            throw new BackendException("broker_configuration_integrity", "Protected authorization configuration SHA-256 does not match the service Parameters record.");
        using var document = JsonDocument.Parse(bytes, new JsonDocumentOptions { MaxDepth = 4 });
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object || root.EnumerateObject().Count() != 2 ||
            !root.TryGetProperty("version", out var version) || !version.TryGetInt32(out int schema) || schema != 1 ||
            !root.TryGetProperty("authorizedUserSid", out var sidNode) || sidNode.ValueKind != JsonValueKind.String)
            throw new BackendException("broker_configuration_invalid", "Authorization configuration schema is invalid.");
        string sid = sidNode.GetString()!;
        return (new BrokerPeerAuthorization(sid), sid);
    }

    private static NamedPipeServerStream CreateFirstLocalPipe(string authorizedSid)
    {
        string sddl = "D:P(A;;GA;;;SY)(A;;GRGW;;;" + authorizedSid + ")";
        if (!ConvertStringSecurityDescriptorToSecurityDescriptor(sddl, 1, out IntPtr securityDescriptor, out _))
            throw new BackendException("broker_pipe_acl_failed", "Unable to build the fixed SYSTEM/authorized-user pipe ACL.");
        try
        {
            var attributes = new SecurityAttributes
            {
                Length = Marshal.SizeOf<SecurityAttributes>(),
                SecurityDescriptor = securityDescriptor,
                InheritHandle = false
            };
            using var pinned = new PinnedStructure<SecurityAttributes>(attributes);
            IntPtr raw = CreateNamedPipeW(
                @"\\.\pipe\" + PipeName,
                PipeOpenMode, // duplex, overlapped, FILE_FLAG_FIRST_PIPE_INSTANCE
                PipeMode, // PIPE_REJECT_REMOTE_CLIENTS
                1,
                BrokerProtocol.MaximumFrameBytes + 1,
                BrokerProtocol.MaximumFrameBytes + 1,
                0,
                pinned.Pointer);
            if (raw == new IntPtr(-1))
                throw new BackendException("broker_pipe_create_failed", "First-instance local pipe creation failed with Win32 " + Marshal.GetLastWin32Error() + ".");
            var handle = new SafePipeHandle(raw, ownsHandle: true);
            try { return new NamedPipeServerStream(PipeDirection.InOut, isAsync: true, isConnected: false, handle); }
            catch { handle.Dispose(); throw; }
        }
        finally { LocalFree(securityDescriptor); }
    }

    internal static bool TestRejectPipeSquatting()
    {
        if (!OperatingSystem.IsWindows()) return true;
        using var identity = WindowsIdentity.GetCurrent();
        string sid = identity.User?.Value ?? throw new BackendException("broker_test_identity_missing", "Self-test cannot obtain the current user SID.");
        using var squatter = new NamedPipeServerStream(PipeName, PipeDirection.InOut, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
        try
        {
            using var unexpected = CreateFirstLocalPipe(sid);
            return false;
        }
        catch (BackendException e)
        {
            return e.Code == "broker_pipe_create_failed" && e.Message.Contains("Win32 ", StringComparison.Ordinal);
        }
    }

    private static async Task ReadClientAsync(NamedPipeServerStream pipe, BrokerSession session, CancellationToken stopping)
    {
        var bytes = new List<byte>(BrokerProtocol.MaximumFrameBytes);
        var one = new byte[1];
        var utf8 = new UTF8Encoding(false, true);
        while (!stopping.IsCancellationRequested)
        {
            int count = await pipe.ReadAsync(one, stopping).ConfigureAwait(false);
            if (count == 0)
            {
                if (bytes.Count != 0) throw new BackendException("broker_unterminated_frame", "Client disconnected mid-frame.");
                return;
            }
            if (one[0] == (byte)'\n')
            {
                if (bytes.Count != 0 && bytes[^1] == (byte)'\r') bytes.RemoveAt(bytes.Count - 1);
                string frame;
                try { frame = utf8.GetString(bytes.ToArray()); }
                catch (DecoderFallbackException e) { throw new BackendException("broker_invalid_utf8", e.Message); }
                bytes.Clear();
                await session.HandleLineAsync(frame).WaitAsync(TimeSpan.FromSeconds(30), stopping).ConfigureAwait(false);
                continue;
            }
            bytes.Add(one[0]);
            if (bytes.Count > BrokerProtocol.MaximumFrameBytes) throw new BackendException("broker_frame_too_large", "Named-pipe frame exceeded 4096 bytes.");
        }
    }

    private static async ValueTask WriteFrameAsync(NamedPipeServerStream pipe, string line, CancellationToken token)
    {
        byte[] payload = Encoding.UTF8.GetBytes(line + "\n");
        if (payload.Length > BrokerProtocol.MaximumFrameBytes + 1) throw new BackendException("broker_frame_too_large", "Server frame exceeded the fixed bound.");
        await pipe.WriteAsync(payload, token).ConfigureAwait(false);
        await pipe.FlushAsync(token).ConfigureAwait(false);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SecurityAttributes
    {
        public int Length;
        public IntPtr SecurityDescriptor;
        [MarshalAs(UnmanagedType.Bool)] public bool InheritHandle;
    }

    private sealed class PinnedStructure<T> : IDisposable where T : struct
    {
        private readonly IntPtr pointer;
        public PinnedStructure(T value)
        {
            pointer = Marshal.AllocHGlobal(Marshal.SizeOf<T>());
            Marshal.StructureToPtr(value, pointer, false);
        }
        public IntPtr Pointer => pointer;
        public void Dispose() => Marshal.FreeHGlobal(pointer);
    }

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "ConvertStringSecurityDescriptorToSecurityDescriptorW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ConvertStringSecurityDescriptorToSecurityDescriptor(string sddl, uint revision, out IntPtr descriptor, out uint size);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "CreateNamedPipeW")]
    private static extern IntPtr CreateNamedPipeW(string name, uint openMode, uint pipeMode, uint maxInstances, uint outBuffer, uint inBuffer, uint defaultTimeout, IntPtr securityAttributes);

    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);
}

internal static class BrokerRuntimePaths
{
    public static string InstallRoot => ValidateInstallRoot(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "ChatpadBridge"));

    public static string ValidateInstallRoot(string path)
    {
        if (!Path.IsPathFullyQualified(path)) throw new BackendException("broker_path_invalid", "Service installation root must be absolute.");
        string programFiles = Path.GetFullPath(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string root = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
        if (!root.StartsWith(programFiles, StringComparison.OrdinalIgnoreCase) || !string.Equals(Path.GetFileName(root), "ChatpadBridge", StringComparison.OrdinalIgnoreCase))
            throw new BackendException("broker_path_invalid", "Service root must be the protected ChatpadBridge directory under Program Files.");
        if (Directory.Exists(root) && (File.GetAttributes(root) & FileAttributes.ReparsePoint) != 0)
            throw new BackendException("broker_path_invalid", "Service root cannot be a reparse point.");
        return root;
    }

    public static string Member(string root, string fileName)
    {
        if (Path.IsPathRooted(fileName) || fileName.Contains(Path.DirectorySeparatorChar) || fileName.Contains(Path.AltDirectorySeparatorChar))
            throw new BackendException("broker_path_invalid", "Runtime member must be a single fixed name.");
        string path = Path.GetFullPath(Path.Combine(ValidateInstallRoot(root), fileName));
        if (!path.StartsWith(root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new BackendException("broker_path_invalid", "Runtime path escaped the protected installation root.");
        return path;
    }

    public static void RequireRegularFile(string path)
    {
        if (!Path.IsPathFullyQualified(path) || !File.Exists(path) || (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            throw new BackendException("broker_path_invalid", "Required service file is absent, relative, or a reparse point.");
    }
}
