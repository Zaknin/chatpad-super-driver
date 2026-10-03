using System.Text.Json;

namespace ChatpadVirtualXbox;

internal static class OfflineTests
{
    public static int Run()
    {
        int passed = 0, failed = 0;
        var failures = new List<string>();
        void Check(string name, Func<bool> test)
        {
            try { if (!test()) throw new InvalidOperationException("assertion failed"); passed++; }
            catch (Exception e) { failed++; failures.Add(name + ": " + e.Message); }
        }
        void Throws(string name, Action action) => Check(name, () =>
        {
            try { action(); return false; }
            catch (BackendException) { return true; }
        });
        var neutral = new XboxState(0, 0, 0, 0, 0, 0, 0);
        int contextFactories = 0;
        var runtimeMock = new MockBackend();
        IVirtualXboxController Factory() { contextFactories++; return runtimeMock; }
        using var missingRuntime = new GuardedBackend(true, () => new(true, false, "missing runtime"), Factory);
        Check("compiled SDK missing runtime refuses before context", () =>
        {
            try { missingRuntime.Create(); return false; }
            catch (BackendException e) { return e.Code == "backend_unavailable" && contextFactories == 0; }
        });
        using var presentUnauthorized = new GuardedBackend(false, () => new(true, true, "mock present"), Factory);
        Check("present runtime without permission refuses before context", () =>
        {
            try { presentUnauthorized.Create(); return false; }
            catch (BackendException e) { return e.Code == "live_virtual_not_authorized" && contextFactories == 0; }
        });
        using var presentRuntime = new GuardedBackend(true, () => new(true, true, "mock present"), Factory);
        Check("present runtime probe is read only", () => presentRuntime.Availability().RuntimeReady && contextFactories == 0);
        Check("present runtime mock creates through factory", () => { presentRuntime.Create(); return contextFactories == 1 && runtimeMock.Connected; });
        Check("present runtime mock submit", () => { presentRuntime.SubmitState(neutral); return runtimeMock.LastState == neutral; });
        Check("present runtime mock cleanup", () => { presentRuntime.Disconnect(); return !runtimeMock.Connected; });
#if HIDMAESTRO
        Check("actual SDK availability probe does not construct context", () =>
        {
            var availability = HidMaestroRuntime.Probe();
            return availability.SdkCompiled && !string.IsNullOrWhiteSpace(availability.Reason);
        });
        Check("real adapter absent runtime mock avoids SDK factory", () =>
        {
            int calls = 0;
            using var adapter = new HidMaestroBackend(true, () => new(true, false, "mock missing"), () => { calls++; return new MockBackend(); });
            try { adapter.Create(); return false; }
            catch (BackendException e) { return e.Code == "backend_unavailable" && calls == 0; }
        });
        Check("real adapter present runtime mock creates mock only", () =>
        {
            using var backend = new MockBackend();
            using var adapter = new HidMaestroBackend(true, () => new(true, true, "mock present"), () => backend);
            adapter.Create(); adapter.SubmitState(neutral); adapter.Disconnect();
            return !backend.Connected;
        });
#endif
        var mock = new MockBackend();
        Throws("submit before create", () => mock.SubmitState(neutral));
        Check("create", () => { mock.Create(); return mock.Connected; });
        Throws("duplicate create", mock.Create);
        Check("submit extrema", () =>
        {
            var state = new XboxState(0xF7FF, 255, 0, short.MinValue, short.MaxValue, 0, -1);
            mock.SubmitState(state); return mock.LastState == state;
        });
        Rumble? heard = null;
        mock.SetRumbleCallback(value => heard = value);
        Check("rumble callback", () => { mock.EmitRumble(new(1, 65535)); return heard == new Rumble(1, 65535); });
        Check("disconnect", () => { mock.Disconnect(); return !mock.Connected && mock.LastState == neutral; });
        Throws("submit after disconnect", () => mock.SubmitState(neutral));
        Throws("rumble after disconnect", () => mock.EmitRumble(new(2, 2)));
        Check("disconnect idempotent", () => { mock.Disconnect(); return !mock.Connected; });
        Check("reconnect", () => { mock.Create(); return mock.Connected; });
        heard = null;
        Check("callback cleared on disconnect", () => { mock.EmitRumble(new(1, 1)); return heard is null; });
        Throws("unavailable create", () => new UnavailableBackend().Create());
        Throws("unavailable submit", () => new UnavailableBackend().SubmitState(neutral));
        Check("axis min", () => StateConversion.Axis(short.MinValue) == 0);
        Check("axis max", () => StateConversion.Axis(short.MaxValue) == 1);
        Check("axis center exact quantization", () => Math.Abs(StateConversion.Axis(0) - 32768f / 65535f) < 0.000001f);
        Check("trigger extrema", () => StateConversion.Trigger(0) == 0 && StateConversion.Trigger(255) == 1);
        Check("axis exact SDK source-model roundtrip all 65536 values", () =>
        {
            for (int value = short.MinValue; value <= short.MaxValue; value++)
                if ((int)((double)StateConversion.Axis((short)value) * 65535) - 32768 != value) return false;
            return true;
        });
        Check("Y exact SDK source-model roundtrip all 65536 values", () =>
        {
            for (int value = short.MinValue; value <= short.MaxValue; value++)
                if (32767 - (int)((double)StateConversion.AxisY((short)value) * 65535) != value) return false;
            return true;
        });
        Check("trigger exact SDK source-model roundtrip all 256 values", () =>
        {
            for (int value = 0; value <= 255; value++)
                if ((int)((double)StateConversion.Trigger((byte)value) * 1023) * 255 / 1023 != value) return false;
            return true;
        });
        ushort[] masks = [0x1000, 0x2000, 0x4000, 0x8000, 0x0100, 0x0200, 0x0020, 0x0010, 0x0040, 0x0080, 0x0400];
        for (int i = 0; i < masks.Length; i++)
        {
            int index = i;
            Check("button mapping " + i, () => StateConversion.Buttons(masks[index]) == (1u << index));
        }
        byte[] hats = [0, 1, 5, 0, 7, 8, 6, 0, 3, 2, 4, 0, 0, 0, 0, 0];
        for (ushort i = 0; i < 16; i++)
        {
            ushort index = i;
            Check("dpad mapping " + i, () => StateConversion.Hat(index) == hats[index]);
        }
        Check("rumble validated fixture", () => StateConversion.TryRumble(2, 0, [0, 0, 128, 255, 0], out var r) && r == new Rumble(32896, 65535));
        Check("rumble stop", () => StateConversion.TryRumble(2, 0, [0, 0, 0, 0, 0], out var r) && r == new Rumble(0, 0));
        Check("rumble source rejected", () => !StateConversion.TryRumble(0, 0, [0, 0, 1, 1, 0], out _));
        Check("rumble report rejected", () => !StateConversion.TryRumble(2, 1, [0, 0, 1, 1, 0], out _));
        for (int size = 0; size < 8; size++)
        {
            int length = size;
            if (size != 5) Check("rumble length " + size, () => !StateConversion.TryRumble(2, 0, new byte[length], out _));
        }
        foreach (int index in new[] { 0, 1, 4 })
        {
            int position = index;
            Check("rumble reserved " + index, () => { byte[] data = [0, 0, 1, 2, 0]; data[position] = 1; return !StateConversion.TryRumble(2, 0, data, out _); });
        }
        var responses = new List<string>();
        using var session = new IpcSession(new MockBackend(), responses.Add);
        Check("ipc create", () => session.Process("{\"id\":1,\"op\":\"create\"}") && responses[^1].Contains("\"ok\":true"));
        const string frame = "{\"id\":2,\"op\":\"submit\",\"buttons\":65535,\"leftTrigger\":255,\"rightTrigger\":0,\"lx\":-32768,\"ly\":32767,\"rx\":0,\"ry\":-1}";
        Check("ipc submit", () => session.Process(frame) && responses[^1].Contains("\"ok\":true"));
        foreach (string invalid in new[] { "{}", "{", "[]", "{\"id\":1,\"op\":\"unknown\"}", frame.Replace("65535", "65536"), frame.Replace("255", "256"), frame.Replace("-32768", "-32769"), frame.Replace("32767", "32768"), frame.Replace("\"rx\":0,", ""), frame.Replace("\"rx\":0", "\"rx\":0.5"), frame.Replace("\"id\":2", "\"id\":-1"), frame.Replace("\"id\":2", "\"id\":2,\"id\":3"), frame.Replace("\"op\":\"submit\"", "\"op\":\"submit\",\"extra\":1") })
        {
            string bad = invalid;
            Check("ipc invalid " + passed, () => session.Process(bad) && responses[^1].Contains("\"ok\":false"));
        }
        Check("ipc unavailable", () => { using var s = new IpcSession(new UnavailableBackend(), responses.Add); s.Process("{\"id\":9,\"op\":\"create\"}"); return responses[^1].Contains("backend_unavailable"); });
        Check("ipc quit", () => !session.Process("{\"id\":3,\"op\":\"quit\"}"));
        Check("oversize line", () => session.Process(new string('x', 4097)) && responses[^1].Contains("invalid_request"));
        var reads = new List<uint>();
        uint clock = 0;
        var missing = new FakeXInput(slot => { reads.Add(slot); return new(1167, 0, neutral); });
        Check("observer finite missing selected slot", () =>
        {
            var result = XInputObserver.Observe(missing, 3, neutral, 25, 10, () => clock, ms => clock += (uint)ms);
            return !result.Matched && result.LastReturnCode == 1167 && result.Attempts == 3 && reads.All(slot => slot == 3) && clock == 25;
        });
        clock = 0;
        Check("observer return code overrides matching payload", () => !XInputObserver.Observe(missing, 0, neutral, 10, 5, () => clock, ms => clock += (uint)ms).Matched);
        clock = 0;
        var wrong = new FakeXInput(_ => new(0, 1, neutral with { Buttons = 0x1000 }));
        Check("observer mismatch times out", () => !XInputObserver.Observe(wrong, 2, neutral, 10, 5, () => clock, ms => clock += (uint)ms).Matched);
        clock = 0;
        Check("observer exact expected state", () => XInputObserver.Observe(new FakeXInput(_ => new(0, 7, neutral)), 1, neutral, 10, 5, () => clock, ms => clock += (uint)ms).Matched);
        Throws("observer slot rejection", () => XInputObserver.Observe(missing, 4, neutral, 10, 5, () => 0, _ => { }));
        Throws("observer timeout rejection", () => XInputObserver.Observe(missing, 0, neutral, 0, 5, () => 0, _ => { }));
        Console.WriteLine(JsonSerializer.Serialize(new { suite = "virtual-xbox-offline", passed, failed, failures, liveBackendCreated = false, xinputCalled = false }));
        return failed == 0 ? 0 : 1;
    }

    private sealed class FakeXInput(Func<uint, XInputSample> read) : IXInputReader
    {
        public XInputSample Read(uint slot) => read(slot);
    }
}
