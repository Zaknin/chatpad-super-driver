using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Principal;
using System.Threading.Channels;

namespace ChatpadVirtualXbox;

[SupportedOSPlatform("windows")]
internal static class WindowsServiceHost
{
    private const string ServiceName = BrokerPipeServer.ServiceName;
    private const uint ServiceWin32OwnProcess = 0x00000010;
    private const uint ServiceStopped = 1;
    private const uint ServiceStartPending = 2;
    private const uint ServiceStopPending = 3;
    private const uint ServiceRunning = 4;
    private const uint ServiceAcceptStop = 1;
    private const uint ServiceAcceptShutdown = 4;
    private const uint ServiceAcceptPowerEvent = 0x00000040;
    private const uint ControlStop = 1;
    private const uint ControlShutdown = 5;
    private const uint ControlPreshutdown = 15;
    private const uint ControlPowerEvent = 13;
    private static readonly ServiceMainCallback MainCallback = ServiceMain;
    private static readonly ServiceHandlerCallback HandlerCallback = HandleControl;
    private static readonly CancellationTokenSource Stop = new();
    private static readonly Channel<(uint EventType, long Tick)> PowerEventSignals = Channel.CreateUnbounded<(uint, long)>(new UnboundedChannelOptions { SingleReader = true, SingleWriter = false });
    private static IntPtr statusHandle;
    private static ServiceStatus status;
    private static uint serviceExitCode;

    public static int Run()
    {
        var table = new[]
        {
            new ServiceTableEntry { ServiceName = ServiceName, ServiceMain = MainCallback },
            new ServiceTableEntry { ServiceName = null, ServiceMain = null }
        };
        if (!StartServiceCtrlDispatcher(table)) return Marshal.GetLastWin32Error();
        return checked((int)serviceExitCode);
    }

    private static void ServiceMain(uint argumentCount, IntPtr arguments)
    {
        statusHandle = RegisterServiceCtrlHandlerEx(ServiceName, HandlerCallback, IntPtr.Zero);
        if (statusHandle == IntPtr.Zero) { serviceExitCode = (uint)Marshal.GetLastWin32Error(); return; }
        Report(ServiceStartPending, 0, 30000, 1);
        string? diagnosticRoot = null;
        Task? powerWorker = null;
        try
        {
            string root = ValidateServiceProcess();
            diagnosticRoot = root;
            Directory.SetCurrentDirectory(root);
            string scratch = Path.Combine(root, "Temp");
            Directory.CreateDirectory(scratch);
            Environment.SetEnvironmentVariable("TEMP", scratch, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable("TMP", scratch, EnvironmentVariableTarget.Process);
            var powerEpoch = new BrokerPowerEpochTracker();
            powerWorker = ProcessPowerEventsAsync(powerEpoch, Stop.Token);
            Report(ServiceRunning, ServiceAcceptStop | ServiceAcceptShutdown | ServiceAcceptPowerEvent, 0, 0);
#if HIDMAESTRO
            var server = new BrokerPipeServer(root, () => new HidMaestroBackend(allowLive: true), powerEpoch);
            server.RunAsync(Stop.Token).GetAwaiter().GetResult();
#else
            throw new BackendException("service_unavailable", "Service host was built without the pinned HIDMaestro runtime.");
#endif
            Stop.Cancel();
            powerWorker.GetAwaiter().GetResult();
        }
        catch (Exception e)
        {
            serviceExitCode = 1;
            try
            {
                if (diagnosticRoot is not null) BrokerServiceDiagnostics.AppendFailure(diagnosticRoot, e);
            }
            catch (Exception logError)
            {
                Console.Error.WriteLine("broker service diagnostic log failure: " + logError.GetType().Name + ": " + logError.Message);
            }
            Console.Error.WriteLine("broker service failure: " + e.GetType().Name + ": " + e.Message);
        }
        finally
        {
            Stop.Cancel();
            if (powerWorker is not null)
            {
                try { powerWorker.GetAwaiter().GetResult(); }
                catch (OperationCanceledException) { }
            }
            Report(ServiceStopped, 0, 0, 0);
        }
    }

    private static string ValidateServiceProcess()
    {
        using var identity = WindowsIdentity.GetCurrent();
        if (!string.Equals(identity.User?.Value, "S-1-5-18", StringComparison.OrdinalIgnoreCase))
            throw new BackendException("broker_service_identity_invalid", "Service process must run as LocalSystem.");
        string root = BrokerRuntimePaths.InstallRoot;
        string image = Environment.ProcessPath ?? throw new BackendException("broker_service_path_invalid", "Service process path is unavailable.");
        if (!Path.IsPathFullyQualified(image) || !string.Equals(Path.GetFullPath(image), Path.Combine(root, "ChatpadVirtualXbox.exe"), StringComparison.OrdinalIgnoreCase))
            throw new BackendException("broker_service_path_invalid", "Service executable must be the packaged apphost inside protected Program Files\\ChatpadBridge.");
        BrokerRuntimePaths.RequireRegularFile(image);
        return root;
    }

    private static uint HandleControl(uint control, uint eventType, IntPtr eventData, IntPtr context)
    {
        if (control == ControlPowerEvent)
        {
            if (eventType is BrokerPowerEpochTracker.SuspendEvent or BrokerPowerEpochTracker.ResumeAutomaticEvent or BrokerPowerEpochTracker.ResumeSuspendEvent)
                _ = PowerEventSignals.Writer.TryWrite((eventType, Environment.TickCount64));
            return 0;
        }
        if (control is ControlStop or ControlShutdown or ControlPreshutdown)
        {
            Report(ServiceStopPending, 0, 30000, 1);
            Stop.Cancel();
            return 0;
        }
        return 120; // ERROR_CALL_NOT_IMPLEMENTED
    }

    private static async Task ProcessPowerEventsAsync(BrokerPowerEpochTracker tracker, CancellationToken stopping)
    {
        try
        {
            await foreach (var notification in PowerEventSignals.Reader.ReadAllAsync(stopping).ConfigureAwait(false))
                _ = tracker.Observe(notification.EventType, notification.Tick);
        }
        catch (OperationCanceledException) when (stopping.IsCancellationRequested) { }
    }

    private static void Report(uint state, uint acceptedControls, uint waitHint, uint checkpoint)
    {
        if (statusHandle == IntPtr.Zero) return;
        status = new ServiceStatus
        {
            ServiceType = ServiceWin32OwnProcess,
            CurrentState = state,
            ControlsAccepted = acceptedControls,
            Win32ExitCode = serviceExitCode,
            ServiceSpecificExitCode = 0,
            CheckPoint = checkpoint,
            WaitHint = waitHint
        };
        _ = SetServiceStatus(statusHandle, ref status);
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct ServiceTableEntry
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string? ServiceName;
        public ServiceMainCallback? ServiceMain;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ServiceStatus
    {
        public uint ServiceType;
        public uint CurrentState;
        public uint ControlsAccepted;
        public uint Win32ExitCode;
        public uint ServiceSpecificExitCode;
        public uint CheckPoint;
        public uint WaitHint;
    }

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate void ServiceMainCallback(uint argumentCount, IntPtr arguments);
    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    private delegate uint ServiceHandlerCallback(uint control, uint eventType, IntPtr eventData, IntPtr context);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "StartServiceCtrlDispatcherW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool StartServiceCtrlDispatcher([In] ServiceTableEntry[] table);

    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true, EntryPoint = "RegisterServiceCtrlHandlerExW")]
    private static extern IntPtr RegisterServiceCtrlHandlerEx(string serviceName, ServiceHandlerCallback handler, IntPtr context);

    [DllImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetServiceStatus(IntPtr handle, ref ServiceStatus status);
}
