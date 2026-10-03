#if HIDMAESTRO
using HIDMaestro;
using System.Security.Cryptography;

namespace ChatpadVirtualXbox;

public static class HidMaestroRuntime
{
    // Reflection/resource reads and filesystem hashes only. In particular,
    // never instantiate HMContext or call any upstream installer/presence API.
    public static BackendAvailability Probe()
    {
        try
        {
            var sdk = typeof(HMContext).Assembly;
            if (!Environment.Is64BitOperatingSystem || System.Runtime.InteropServices.RuntimeInformation.OSArchitecture != System.Runtime.InteropServices.Architecture.X64)
                return new(true, false, "C3 package requires Windows x64.");
            var repository = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "DriverStore", "FileRepository");
            foreach (var requirement in new[] {
                (Inf: "hidmaestro.inf", Binary: "HIDMaestro.dll"),
                (Inf: "hidmaestro_xusb.inf", Binary: "HMXInput.dll") })
            {
                string ResourceHash(string file)
                {
                    using var stream = sdk.GetManifestResourceStream("HIDMaestro.Native.x64." + file)
                        ?? throw new BackendException("backend_unavailable", "SDK driver payload missing: " + file);
                    return Convert.ToHexString(SHA256.HashData(stream));
                }
                var infHash = ResourceHash(requirement.Inf);
                var binaryHash = ResourceHash(requirement.Binary);
                bool matching = Directory.Exists(repository) && Directory.EnumerateDirectories(repository, requirement.Inf + "_amd64_*").Any(directory =>
                {
                    var inf = Path.Combine(directory, requirement.Inf);
                    var binary = Path.Combine(directory, requirement.Binary);
                    if (!File.Exists(inf) || !File.Exists(binary)) return false;
                    using var infStream = File.OpenRead(inf);
                    using var binaryStream = File.OpenRead(binary);
                    return Convert.ToHexString(SHA256.HashData(infStream)) == infHash && Convert.ToHexString(SHA256.HashData(binaryStream)) == binaryHash;
                });
                if (!matching) return new(true, false, "Pinned HIDMaestro runtime not installed or package bytes mismatch: " + requirement.Inf + ". No installation/context/device creation attempted.");
            }
            return new(true, true, "Pinned driver INF/DLL bytes found in Driver Store. This does not prove Windows load/trust acceptance; independently preflight that before C3.");
        }
        catch (Exception e) { return new(true, false, "Read-only runtime probe failed: " + e.Message); }
    }
}

public sealed class HidMaestroBackend : IVirtualXboxController
{
    private readonly GuardedBackend guard;
    public HidMaestroBackend(bool allowLive) : this(allowLive, HidMaestroRuntime.Probe, () => new SdkXboxController()) { }
    internal HidMaestroBackend(bool allowLive, Func<BackendAvailability> probe, Func<IVirtualXboxController> factory) => guard = new(allowLive, probe, factory);
    public BackendAvailability Availability() => guard.Availability();
    public void Create() => guard.Create();
    public void SubmitState(XboxState state) => guard.SubmitState(state);
    public void SetRumbleCallback(Action<Rumble> callback) => guard.SetRumbleCallback(callback);
    public void Disconnect() => guard.Disconnect();
    public void Dispose() => guard.Dispose();
}

// Public SDK calls only; context construction occurs strictly after the guard.
internal sealed class SdkXboxController : IVirtualXboxController
{
    private HMContext? context;
    private HMController? controller;
    private Action<Rumble>? callback;
    public void Create()
    {
        if (controller != null) throw new BackendException("already_connected", "Disconnect first.");
        try
        {
            context = new HMContext();
            if (!context.IsDriverInstalled) throw new BackendException("backend_unavailable", "Install and independently verify the pinned SDK drivers in a separately authorized task. Helper never calls InstallDriver.");
            context.LoadDefaultProfiles();
            var profile = context.GetProfile("xbox-360-wired") ?? throw new BackendException("profile_unavailable", "Pinned xbox-360-wired profile absent.");
            if (profile.RequiresUsbipBackend) throw new BackendException("wrong_backend", "Composite/USBIP profiles are forbidden.");
            controller = context.CreateController(profile, "chatpad360-winusb-poc");
            controller.OutputReceived += OnOutput;
        }
        catch (Exception e)
        {
            Disconnect();
            if (e is BackendException) throw;
            throw new BackendException("backend_create_failed", e.Message);
        }
    }
    public void SubmitState(XboxState state)
    {
        var target = controller ?? throw new BackendException("not_connected", "Create first.");
        var mapped = new HMGamepadState
        {
            Buttons = (HMButton)StateConversion.Buttons(state.Buttons), Hat = (HMHat)StateConversion.Hat(state.Buttons),
            Axes = HMGamepadStateHelpers.StandardAxes(target.Profile, StateConversion.Axis(state.Lx), StateConversion.AxisY(state.Ly),
                StateConversion.Axis(state.Rx), StateConversion.AxisY(state.Ry), StateConversion.Trigger(state.LeftTrigger), StateConversion.Trigger(state.RightTrigger))
        };
        target.SubmitState(mapped);
    }
    public void SetRumbleCallback(Action<Rumble> value) => callback = value;
    private void OnOutput(HMController _, HMOutputPacket packet)
    {
        if (StateConversion.TryRumble((byte)packet.Source, packet.ReportId, packet.Data.Span, out var value)) callback?.Invoke(value);
        else Console.Error.WriteLine("Unrecognized SDK output: source=" + packet.Source + " report=" + packet.ReportId + " bytes=" + Convert.ToHexString(packet.Data.Span));
    }
    public void Disconnect()
    {
        var target = controller; controller = null; callback = null;
        if (target != null) { target.OutputReceived -= OnOutput; target.Dispose(); }
        var owner = context; context = null; owner?.Dispose();
    }
    public void Dispose() => Disconnect();
}
#endif
