using System.Runtime.InteropServices;

namespace ChatpadVirtualXbox;

public readonly record struct XInputSample(uint ReturnCode, uint PacketNumber, XboxState State);
public readonly record struct Observation(bool Matched, uint Slot, int Attempts, uint LastReturnCode, uint ElapsedMs, XInputSample LastSample);
public interface IXInputReader { XInputSample Read(uint slot); }

public static class XInputObserver
{
    public static Observation Observe(IXInputReader reader, uint slot, XboxState expected, int timeoutMs, int pollMs,
        Func<uint> milliseconds, Action<int> sleep)
    {
        if (slot > 3 || timeoutMs < 1 || timeoutMs > 120000 || pollMs < 1 || pollMs > timeoutMs)
            throw new BackendException("invalid_observer_options", "Explicit slot 0..3, timeout 1..120000 ms, poll 1..timeout are required.");
        uint start = milliseconds(); int attempts = 0; XInputSample sample = default;
        while (unchecked(milliseconds() - start) < timeoutMs)
        {
            sample = reader.Read(slot); attempts++;
            uint elapsed = unchecked(milliseconds() - start);
            if (sample.ReturnCode == 0 && sample.State == expected && elapsed <= timeoutMs)
                return new(true, slot, attempts, sample.ReturnCode, elapsed, sample);
            if (elapsed >= timeoutMs) break;
            sleep(Math.Min(pollMs, timeoutMs - (int)elapsed));
        }
        return new(false, slot, attempts, sample.ReturnCode, unchecked(milliseconds() - start), sample);
    }
}

public sealed class WindowsXInputReader : IXInputReader
{
    [StructLayout(LayoutKind.Sequential)]
    private struct Gamepad
    {
        public ushort Buttons;
        public byte LeftTrigger, RightTrigger;
        public short Lx, Ly, Rx, Ry;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct State { public uint Packet; public Gamepad Gamepad; }
    [DllImport("xinput1_4.dll", ExactSpelling = true)]
    private static extern uint XInputGetState(uint userIndex, out State state);
    public XInputSample Read(uint slot)
    {
        if (slot > 3) throw new BackendException("invalid_slot", "XInput slot must be 0..3.");
        uint code = XInputGetState(slot, out var state);
        var g = state.Gamepad;
        return new(code, state.Packet, new(g.Buttons, g.LeftTrigger, g.RightTrigger, g.Lx, g.Ly, g.Rx, g.Ry));
    }
}
