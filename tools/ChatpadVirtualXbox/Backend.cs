namespace ChatpadVirtualXbox;

public readonly record struct XboxState(ushort Buttons, byte LeftTrigger, byte RightTrigger, short Lx, short Ly, short Rx, short Ry);
public readonly record struct Rumble(ushort LeftMotor, ushort RightMotor);
public sealed class BackendException(string code, string detail) : Exception(detail)
{
    public string Code { get; } = code;
}

public interface IVirtualXboxController : IDisposable
{
    void Create();
    void SubmitState(XboxState state);
    void SetRumbleCallback(Action<Rumble> callback);
    void Disconnect();
}

public sealed class UnavailableBackend : IVirtualXboxController
{
    private static BackendException Missing() => new("backend_unavailable", "HIDMaestro is not compiled in. Requires pinned external HIDMaestro.Core DLL, .NET 10 SDK/runtime and separately authorized installed UMDF2/XUSB components; no installation is attempted.");
    public void Create() => throw Missing();
    public void SubmitState(XboxState state) => throw Missing();
    public void SetRumbleCallback(Action<Rumble> callback) { }
    public void Disconnect() { }
    public void Dispose() => Disconnect();
}

public sealed class MockBackend : IVirtualXboxController
{
    private Action<Rumble>? callback;
    public bool Connected { get; private set; }
    public XboxState LastState { get; private set; }
    public void Create()
    {
        if (Connected) throw new BackendException("already_connected", "Disconnect before recreating.");
        LastState = default; Connected = true;
    }
    public void SubmitState(XboxState state)
    {
        RequireConnected(); LastState = state;
    }
    public void SetRumbleCallback(Action<Rumble> value) => callback = value;
    public void EmitRumble(Rumble value) { RequireConnected(); callback?.Invoke(value); }
    private void RequireConnected()
    {
        if (!Connected) throw new BackendException("not_connected", "Create the virtual controller first.");
    }
    public void Disconnect() { Connected = false; LastState = default; callback = null; }
    public void Dispose() => Disconnect();
}

// Pure state conversion; these constants describe public HMButton/HMHat values.
// No SDK internal/shared-memory layout is replicated here.
public static class StateConversion
{
    // The pinned SDK truncates normalized axes when packing its XInput state.
    // Round upward only if float precision would otherwise lose an integer unit.
    private static float NormalizeUp(int value, int maximum)
    {
        float normalized = (float)value / maximum;
        return (double)normalized * maximum < value ? MathF.BitIncrement(normalized) : normalized;
    }
    public static float Axis(short value) => NormalizeUp(value + 32768, 65535);
    // The SDK's Xbox companion inverts Y; physical/XInput Y is positive upward.
    public static float AxisY(short value) => NormalizeUp(32767 - value, 65535);
    // The pinned SDK packs 10-bit triggers then converts back with floor(*255/1023).
    public static float Trigger(byte value) => NormalizeUp((value * 1023 + 254) / 255, 1023);
    public static uint Buttons(ushort bits)
    {
        ReadOnlySpan<ushort> masks = [0x1000, 0x2000, 0x4000, 0x8000, 0x0100, 0x0200, 0x0020, 0x0010, 0x0040, 0x0080, 0x0400];
        uint result = 0;
        for (int i = 0; i < masks.Length; i++) if ((bits & masks[i]) != 0) result |= 1u << i;
        return result;
    }
    public static byte Hat(ushort bits) => (bits & 15) switch
    {
        1 => 1, 9 => 2, 8 => 3, 10 => 4, 2 => 5, 6 => 6, 4 => 7, 5 => 8, _ => 0
    };
    // Pinned upstream fixture uses [00 00 lo hi 00]. Normal Windows XInput
    // qualification also captured [00 00 lo hi 02] for the motor command.
    // Reject LED/other IOCTLs and any other framing; raw output remains logged.
    public static bool TryRumble(byte source, byte reportId, ReadOnlySpan<byte> data, out Rumble value)
    {
        value = default;
        if (source != 2 || reportId != 0 || data.Length != 5 || data[0] != 0 || data[1] != 0 || (data[4] != 0 && data[4] != 2)) return false;
        value = new((ushort)(data[2] * 257), (ushort)(data[3] * 257));
        return true;
    }
}
