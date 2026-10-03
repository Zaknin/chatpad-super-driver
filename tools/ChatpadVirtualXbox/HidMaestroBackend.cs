#if HIDMAESTRO
using HIDMaestro;

namespace ChatpadVirtualXbox;

// Source-only in the C2 build. Public SDK calls only; no copied private ABI.
public sealed class HidMaestroBackend(bool allowLive) : IVirtualXboxController
{
    private HMContext? context;
    private HMController? controller;
    private Action<Rumble>? callback;
    public void Create()
    {
        if (!allowLive) throw new BackendException("live_virtual_not_authorized", "--allow-live-virtual required before ANY HMContext construction (its constructor has service/resource side effects).");
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
