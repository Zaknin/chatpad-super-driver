namespace ChatpadVirtualXbox;

public sealed record BackendAvailability(bool SdkCompiled, bool RuntimeReady, string Reason);

// Probe first: the SDK context constructor schedules service/resource work.
// The factory is never called for missing dependencies or missing live consent.
public sealed class GuardedBackend(bool allowLive, Func<BackendAvailability> probe,
    Func<IVirtualXboxController> factory) : IVirtualXboxController
{
    private IVirtualXboxController? inner;
    private Action<Rumble>? callback;
    public BackendAvailability Availability() => probe();
    public void Create()
    {
        if (inner != null) throw new BackendException("already_connected", "Disconnect first.");
        var status = probe();
        if (!status.RuntimeReady) throw new BackendException("backend_unavailable", status.Reason);
        if (!allowLive) throw new BackendException("live_virtual_not_authorized", "Explicit live virtual permission required before SDK context construction.");
        var created = factory();
        try { if (callback != null) created.SetRumbleCallback(callback); created.Create(); inner = created; }
        catch { created.Dispose(); throw; }
    }
    public void SubmitState(XboxState state) => (inner ?? throw new BackendException("not_connected", "Create first.")).SubmitState(state);
    public void SetRumbleCallback(Action<Rumble> value) { callback = value; inner?.SetRumbleCallback(value); }
    public void Disconnect() { var owner = inner; inner = null; callback = null; owner?.Dispose(); }
    public void Dispose() => Disconnect();
}
