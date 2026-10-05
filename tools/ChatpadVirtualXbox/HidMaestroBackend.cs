#if HIDMAESTRO
using HIDMaestro;
using Microsoft.Win32;
using System.Reflection;

namespace ChatpadVirtualXbox;

public static class HidMaestroRuntime
{
    // Reflection/resource reads and filesystem hashes only. In particular,
    // never instantiate HMContext or call any upstream installer/presence API.
    public static BackendAvailability Probe()
    {
        try
        {
            if (!Environment.Is64BitOperatingSystem || System.Runtime.InteropServices.RuntimeInformation.OSArchitecture != System.Runtime.InteropServices.Architecture.X64)
                return new(true, false, "C3 package requires Windows x64.");
            RuntimePackageIdentity.VerifyCurrentTrust();
            foreach (var package in RuntimePackageIdentity.Packages) RuntimePackageIdentity.Find(package);
            return new(true, true, "Exact C2R3 catalog-signed INF/CAT/DLL bytes and current machine trust verified. Live load qualification is recorded separately.");
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
    private bool ownsMetadata;
    private static readonly string[] MetadataKeys = [
        @"SYSTEM\CurrentControlSet\Control\GameInput\Devices\045E028E00010005",
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\GameInput\Devices\045E028E00010005",
        @"SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_045E&PID_028E" ];
    public void Create()
    {
        if (controller != null) throw new BackendException("already_connected", "Disconnect first.");
        string phase = "construct_context";
        try
        {
            context = new HMContext();
            phase = "verify_driver";
            if (!context.IsDriverInstalled) throw new BackendException("backend_unavailable", "Install and independently verify the pinned SDK drivers in a separately authorized task. Helper never calls InstallDriver.");
            phase = "prepare_qualified_package";
            PrepareQualifiedPackage();
            phase = "load_profiles";
            context.LoadDefaultProfiles();
            phase = "validate_xbox_profile";
            var profile = context.GetProfile("xbox-360-wired") ?? throw new BackendException("profile_unavailable", "Pinned xbox-360-wired profile absent.");
            if (profile.RequiresUsbipBackend) throw new BackendException("wrong_backend", "Composite/USBIP profiles are forbidden.");
            // SDK creates shared VID/PID metadata. Refuse to overwrite existing
            // application metadata; remove only these initially absent keys at
            // teardown, including failed creation. No physical Enum/USB key touched.
            phase = "check_shared_metadata";
            foreach (var key in MetadataKeys)
            {
                using var existing = Registry.LocalMachine.OpenSubKey(key);
                if (existing != null) throw new BackendException("metadata_conflict", "Shared Xbox profile metadata already exists; no device creation attempted.");
            }
            phase = "check_present_controller_scope";
            string? conflictingInstance = EnumControllerIndexGuard.FindPresentIndexZero(Registry.LocalMachine,
                DeviceNodePresence.IsPresent);
            if (conflictingInstance is not null)
                throw new BackendException("virtual_scope_conflict", "Existing present ROOT/SWD controller index zero would be touched by upstream profile sweep: " + conflictingInstance + ".");
            ownsMetadata = true;
            phase = "create_virtual_controller";
            controller = context.CreateController(profile, "chatpad360-winusb-poc");
            phase = "verify_xusb_interface";
            var instanceIdProperty = typeof(HMController).GetProperty("InstanceId", BindingFlags.Instance | BindingFlags.NonPublic)
                ?? throw new BackendException("xusb_instance_id_unavailable", "Pinned HIDMaestro runtime no longer exposes its qualified controller instance identity.");
            string instanceId = instanceIdProperty.GetValue(controller) as string
                ?? throw new BackendException("xusb_instance_id_unavailable", "HIDMaestro returned no controller instance identity.");
            if (!XusbInterfaceQualification.WaitForExpectedInterface(instanceId, 1000))
            {
                string token = XusbInterfaceQualification.GetControllerToken(instanceId) ?? "invalid";
                throw new BackendException("xusb_companion_unavailable", $"HIDMaestro returned a controller, but the matching XUSB interface SWD#HIDMAESTRO#{token}#{{{XusbInterfaceQualification.InterfaceClass:D}}} is not present.");
            }
            phase = "subscribe_controller_output";
            controller.OutputReceived += OnOutput;
        }
        catch (Exception e)
        {
            Disconnect();
            if (e is BackendException) throw;
            throw new BackendException("backend_create_failed", phase + ":" + e.GetType().Name + ":" + e.Message);
        }
    }
    private static void PrepareQualifiedPackage()
    {
        // Public extraction API serializes the constructor's prewarm. The SDK
        // subsequently binds this INF path. Supply only frozen, qualified package
        // bytes; never call FullDeploy/InstallDriver or modify any runtime DLL.
        var directory = HIDMaestro.Internal.DriverBuilder.EnsureExtracted();
        var parent = Path.GetFullPath(Path.GetTempPath());
        if (!Path.GetFullPath(directory).StartsWith(parent, StringComparison.OrdinalIgnoreCase) ||
            !System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(directory), "^HIDMaestro_[0-9a-fA-F]{16}$") ||
            (File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0)
            throw new BackendException("unsafe_staging", "Unexpected public SDK extraction directory.");
        foreach (var package in RuntimePackageIdentity.Packages)
        {
            var installed = RuntimePackageIdentity.Find(package);
            foreach (var file in package.Files)
            {
                var target = Path.Combine(directory, file.Key);
                if (File.Exists(target) && (File.GetAttributes(target) & FileAttributes.ReparsePoint) != 0)
                    throw new BackendException("unsafe_staging", "SDK payload reparse point refused.");
                if (file.Key.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
                {
                    if (RuntimePackageIdentity.Hash(target) != file.Value)
                        throw new BackendException("payload_mismatch", "Extracted runtime DLL differs from exact pin.");
                }
                else File.Copy(Path.Combine(installed, file.Key), target, true);
                if (RuntimePackageIdentity.Hash(target) != file.Value)
                    throw new BackendException("payload_mismatch", "Qualified SDK package materialization failed.");
            }
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
        try
        {
            if (target != null) { target.OutputReceived -= OnOutput; target.Dispose(); }
            var owner = context; context = null; owner?.Dispose();
        }
        finally
        {
            if (ownsMetadata)
            {
                foreach (var key in MetadataKeys) Registry.LocalMachine.DeleteSubKeyTree(key, false);
                ownsMetadata = false;
            }
        }
    }
    public void Dispose() => Disconnect();
}
#endif
