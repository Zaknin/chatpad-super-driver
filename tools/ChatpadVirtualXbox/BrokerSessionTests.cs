namespace ChatpadVirtualXbox;

internal static class BrokerSessionTests
{
    public static (int Passed, int Failed, IReadOnlyList<string> Failures) Run()
    {
        int passed = 0, failed = 0;
        var failures = new List<string>();
        async Task Check(string name, Func<Task<bool>> test)
        {
            try { if (!await test().WaitAsync(TimeSpan.FromSeconds(3))) throw new InvalidOperationException("assertion failed"); passed++; }
            catch (Exception e) { failed++; failures.Add(name + ": " + e.Message); }
        }
        string Ping(int id) => $$"""{"version":1,"id":{{id}},"op":"ping"}""";
        string Create(int id) => $$"""{"version":1,"id":{{id}},"op":"create"}""";
        string Destroy(int id) => $$"""{"version":1,"id":{{id}},"op":"destroy"}""";
        string State(ulong sequence, ushort buttons) => $$"""{"version":1,"sequence":{{sequence}},"op":"submit-state","buttons":{{buttons}},"leftTrigger":0,"rightTrigger":0,"lx":0,"ly":0,"rx":0,"ry":0}""";

        Check("physical recovery control has no caller-selected target", () => Task.FromResult(
            BrokerProtocol.ParseControlRequest("{\"version\":1,\"id\":1,\"op\":\"recover-physical\"}").Operation.ToString() == "RecoverPhysical" &&
            RejectsControlTarget("{\"version\":1,\"id\":1,\"op\":\"recover-physical\",\"instanceId\":\"USB\\\\VID_045E&PID_028E\\\\anything\"}"))
        ).GetAwaiter().GetResult();
        Check("physical recovery identity accepts only exact WinUSB Xbox candidates", () => Task.FromResult(
            PhysicalDeviceIdentity.IsExactWinUsbTarget(new("USB\\VID_045E&PID_028E\\SERIAL", "WinUSB", new[] { "USB\\VID_045E&PID_028E&REV_0114" }, 1)) &&
            !PhysicalDeviceIdentity.IsExactWinUsbTarget(new("USB\\VID_045E&PID_028F\\SERIAL", "WinUSB", new[] { "USB\\VID_045E&PID_028F" }, 1)) &&
            !PhysicalDeviceIdentity.IsExactWinUsbTarget(new("USB\\VID_045E&PID_028E\\SERIAL", "HidUsb", new[] { "USB\\VID_045E&PID_028E" }, 1)) &&
            !PhysicalDeviceIdentity.IsExactWinUsbTarget(new("USB\\VID_045E&PID_028E\\SERIAL", "WinUSB", new[] { "USB\\VID_045E&PID_028EFAKE" }, 1)) &&
            !PhysicalDeviceIdentity.IsExactWinUsbTarget(new("USB\\VID_045E&PID_028E\\SERIAL", "WinUSB", new[] { "USB\\VID_0000&PID_0000" }, 1)))
        ).GetAwaiter().GetResult();
        Check("physical recovery decodes the SetupAPI hardware-ID property as REG_MULTI_SZ", () => Task.FromResult(
            DecodeHardwareIdProperty())).GetAwaiter().GetResult();
        Check("physical recovery requires exactly one matching candidate", () => Task.FromResult(
            PhysicalDeviceIdentity.UniqueTargetError(Array.Empty<PhysicalDeviceCandidate>()) == "broker_physical_target_not_found" &&
            PhysicalDeviceIdentity.UniqueTargetError(new[] { new PhysicalDeviceCandidate("USB\\VID_045E&PID_028E\\SERIAL", "WinUSB", new[] { "USB\\VID_045E&PID_028E" }, 1) }).Length == 0 &&
            PhysicalDeviceIdentity.UniqueTargetError(new[] {
                new PhysicalDeviceCandidate("USB\\VID_045E&PID_028E\\ONE", "WinUSB", new[] { "USB\\VID_045E&PID_028E" }, 1),
                new PhysicalDeviceCandidate("USB\\VID_045E&PID_028E\\TWO", "WinUSB", new[] { "USB\\VID_045E&PID_028E" }, 2)
            }) == "broker_physical_target_ambiguous")
        ).GetAwaiter().GetResult();

        Check("broker ping does not construct backend", async () =>
        {
            int factories = 0;
            var output = new List<string>();
            await using var session = new BrokerSession(() => { factories++; return new MockBackend(); }, (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; });
            await session.HandleLineAsync(Ping(1));
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true")); });
            return factories == 0 && output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true"));
        }).GetAwaiter().GetResult();
        Check("physical recovery runs only on an empty broker lease", async () =>
        {
            int recoveries = 0;
            var output = new List<string>();
            var recovery = new MockPhysicalDeviceRecovery(() => { recoveries++; return new(true, "", ""); });
            await using var session = new BrokerSession(() => new MockBackend(), (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; }, recovery);
            await session.HandleLineAsync("{\"version\":1,\"id\":1,\"op\":\"recover-physical\"}");
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true")); });
            bool repeatedRejected = false;
            try { await session.HandleLineAsync("{\"version\":1,\"id\":2,\"op\":\"recover-physical\"}"); }
            catch (BackendException e) { repeatedRejected = e.Code == "broker_physical_recovery_already_attempted"; }
            return recoveries == 1 && repeatedRejected && output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true"));
        }).GetAwaiter().GetResult();
        Check("broker session reports the retained resume epoch and receives live resume events", async () =>
        {
            var power = new BrokerPowerEpochTracker();
            var output = new List<string>();
            await using var session = new BrokerSession(() => new MockBackend(), (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; }, powerEpoch: power);
            await session.HandleLineAsync(Ping(1));
            await SpinWaitAsync(() => { lock (output) return output.Count >= 1; });
            power.Observe(BrokerPowerEpochTracker.SuspendEvent, 1000);
            power.Observe(BrokerPowerEpochTracker.ResumeAutomaticEvent, 2000);
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("power-resume") && line.Contains("\"epoch\":1")); });
            lock (output)
                return output.Any(line => line.Contains("\"resumeEpoch\":0")) && output.Any(line => line.Contains("power-resume") && line.Contains("\"epoch\":1"));
        }).GetAwaiter().GetResult();
        Check("broker ping recovers a resume epoch after the runner was disconnected during wake", async () =>
        {
            var power = new BrokerPowerEpochTracker();
            power.Observe(BrokerPowerEpochTracker.SuspendEvent, 1000);
            power.Observe(BrokerPowerEpochTracker.ResumeSuspendEvent, 2000);
            var output = new List<string>();
            await using var session = new BrokerSession(() => new MockBackend(), (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; }, powerEpoch: power);
            await session.HandleLineAsync(Ping(1));
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("\"resumeEpoch\":1")); });
            lock (output) return output.Any(line => line.Contains("\"resumeEpoch\":1"));
        }).GetAwaiter().GetResult();
        Check("physical recovery circuit resets for a new broker-wide resume epoch", async () =>
        {
            int recoveries = 0;
            var power = new BrokerPowerEpochTracker();
            var recovery = new MockPhysicalDeviceRecovery(() => { recoveries++; return new(true, "", ""); });
            await using var first = new BrokerSession(() => new MockBackend(), (_, _) => ValueTask.CompletedTask, recovery, power);
            await first.HandleLineAsync("{\"version\":1,\"id\":1,\"op\":\"recover-physical\"}");
            await first.StopAsync();
            await using var second = new BrokerSession(() => new MockBackend(), (_, _) => ValueTask.CompletedTask, recovery, power);
            bool sameEpochRejected = false;
            try { await second.HandleLineAsync("{\"version\":1,\"id\":1,\"op\":\"recover-physical\"}"); }
            catch (BackendException e) { sameEpochRejected = e.Code == "broker_physical_recovery_already_attempted"; }
            power.Observe(BrokerPowerEpochTracker.SuspendEvent, 1000);
            power.Observe(BrokerPowerEpochTracker.ResumeAutomaticEvent, 2000);
            await second.HandleLineAsync("{\"version\":1,\"id\":2,\"op\":\"recover-physical\"}");
            return sameEpochRejected && recoveries == 2;
        }).GetAwaiter().GetResult();
        Check("physical recovery cannot run while the virtual lease exists", async () =>
        {
            int recoveries = 0;
            var backend = new MockBackend();
            var recovery = new MockPhysicalDeviceRecovery(() => { recoveries++; return new(true, "", ""); });
            await using var session = new BrokerSession(() => backend, (_, _) => ValueTask.CompletedTask, recovery);
            await session.HandleLineAsync(Create(1));
            bool rejected = false;
            try { await session.HandleLineAsync("{\"version\":1,\"id\":2,\"op\":\"recover-physical\"}"); }
            catch (BackendException e) { rejected = e.Code == "broker_physical_recovery_requires_destroy"; }
            return rejected && recoveries == 0 && backend.Connected;
        }).GetAwaiter().GetResult();
        Check("failed physical recovery stays a visible failure", async () =>
        {
            var recovery = new MockPhysicalDeviceRecovery(() => new(false, "broker_physical_recovery_failed", "test failure"));
            await using var session = new BrokerSession(() => new MockBackend(), (_, _) => ValueTask.CompletedTask, recovery);
            try { await session.HandleLineAsync("{\"version\":1,\"id\":1,\"op\":\"recover-physical\"}"); return false; }
            catch (BackendException e) { return e.Code == "broker_physical_recovery_failed"; }
        }).GetAwaiter().GetResult();
        Check("broker create owns one backend and destroy is idempotent", async () =>
        {
            int factories = 0;
            var backend = new MockBackend();
            var output = new List<string>();
            await using var session = new BrokerSession(() => { factories++; return backend; }, (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; });
            await session.HandleLineAsync(Create(1));
            bool duplicateRejected = false;
            try { await session.HandleLineAsync(Create(2)); } catch (BackendException) { duplicateRejected = true; }
            await session.HandleLineAsync(Destroy(3));
            await session.HandleLineAsync(Destroy(4));
            await SpinWaitAsync(() => { lock (output) return output.Count == 3; });
            return factories == 1 && duplicateRejected && !backend.Connected && output.Count(line => line.Contains("\"ok\":true")) == 3;
        }).GetAwaiter().GetResult();
        Check("failed backend create cleans up without submitting controller state", async () =>
        {
            var backend = new FailingCreateBackend();
            await using var session = new BrokerSession(() => backend, (_, _) => ValueTask.CompletedTask);
            string? code = null;
            try { await session.HandleLineAsync(Create(1)); }
            catch (BackendException error) { code = error.Code; }
            try { await session.StopAsync(); }
            catch (BackendException) { return false; }
            return code == "test_create_failed" && backend.SubmitCalls == 0 &&
                backend.DisconnectCalls == 1 && backend.DisposeCalls == 1;
        }).GetAwaiter().GetResult();
        Check("broker streamed states coalesce while backend is blocked", async () =>
        {
            var backend = new BlockingBackend();
            var output = new List<string>();
            await using var session = new BrokerSession(() => backend, (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; });
            await session.HandleLineAsync(Create(1));
            await session.HandleLineAsync(State(1, 1));
            await backend.FirstSubmitStarted.Task.WaitAsync(TimeSpan.FromSeconds(1));
            int outputBeforeStates;
            lock (output) outputBeforeStates = output.Count;
            await session.HandleLineAsync(State(2, 2));
            await session.HandleLineAsync(State(3, 3));
            backend.ReleaseFirstSubmit.Set();
            await backend.LastStateIs(3).WaitAsync(TimeSpan.FromSeconds(1));
            lock (output) return output.Count == outputBeforeStates && backend.SubmitCount == 2 && backend.LastState.Buttons == 3;
        }).GetAwaiter().GetResult();
        Check("broker rejects stale sequence and control correlation", async () =>
        {
            var backend = new MockBackend();
            await using var session = new BrokerSession(() => backend, (_, _) => ValueTask.CompletedTask);
            await session.HandleLineAsync(Ping(2));
            bool staleControl = false, staleState = false;
            try { await session.HandleLineAsync(Ping(2)); } catch (BackendException) { staleControl = true; }
            await session.HandleLineAsync(Create(3));
            await session.HandleLineAsync(State(ulong.MaxValue, 1));
            try { await session.HandleLineAsync(State(0, 2)); } catch (BackendException) { staleState = true; }
            await SpinWaitAsync(() => backend.LastState.Buttons == 1);
            return staleControl && staleState && backend.LastState.Buttons == 1;
        }).GetAwaiter().GetResult();
        Check("broker rumble callback uses the serialized output writer", async () =>
        {
            var backend = new MockBackend();
            var output = new List<string>();
            await using var session = new BrokerSession(() => backend, (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; });
            await session.HandleLineAsync(Create(1));
            backend.EmitRumble(new(12, 34));
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("\"op\":\"rumble\"")); });
            lock (output) return output.Any(line => line.Contains("\"leftMotor\":12") && line.Contains("\"rightMotor\":34"));
        }).GetAwaiter().GetResult();
        Check("broker malformed stream releases owned backend", async () =>
        {
            var backend = new MockBackend();
            await using var session = new BrokerSession(() => backend, (_, _) => ValueTask.CompletedTask);
            await session.HandleLineAsync(Create(1));
            try { await session.HandleLineAsync("not-json"); } catch (BackendException) { }
            await session.StopAsync();
            return !backend.Connected;
        }).GetAwaiter().GetResult();
        Check("broker service stop neutralizes and releases the lease", async () =>
        {
            var backend = new MockBackend();
            var session = new BrokerSession(() => backend, (_, _) => ValueTask.CompletedTask);
            await session.HandleLineAsync(Create(1));
            await session.StopAsync();
            await session.DisposeAsync();
            return !backend.Connected && backend.LastState == default;
        }).GetAwaiter().GetResult();
        return (passed, failed, failures);
    }

    private static async Task SpinWaitAsync(Func<bool> predicate)
    {
        var deadline = DateTime.UtcNow.AddSeconds(1);
        while (!predicate())
        {
            if (DateTime.UtcNow >= deadline) throw new TimeoutException("condition was not observed");
            await Task.Delay(5);
        }
    }

    private static bool RejectsControlTarget(string request)
    {
        try { BrokerProtocol.ParseControlRequest(request); return false; }
        catch (BackendException e) { return e.Code == "broker_protocol_error"; }
    }

    private static bool DecodeHardwareIdProperty()
    {
        var decoder = typeof(WindowsPhysicalDeviceRecovery).GetMethod(
            "DecodeStringProperty", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        if (decoder is null) return false;
        const string first = "USB\\VID_045E&PID_028E&REV_0114";
        const string second = "USB\\VID_045E&PID_028E";
        byte[] raw = System.Text.Encoding.Unicode.GetBytes(first + "\0" + second + "\0\0");
        try
        {
            string? decoded = decoder.Invoke(null, new object[] { 1u, 7u, raw }) as string;
            return decoded == first + "\0" + second;
        }
        catch (System.Reflection.TargetInvocationException) { return false; }
    }

    private sealed class BlockingBackend : IVirtualXboxController
    {
        private readonly MockBackend inner = new();
        private int count;
        public readonly TaskCompletionSource FirstSubmitStarted = new(TaskCreationOptions.RunContinuationsAsynchronously);
        public readonly ManualResetEventSlim ReleaseFirstSubmit = new();
        public int SubmitCount => Volatile.Read(ref count);
        public XboxState LastState => inner.LastState;
        public void Create() => inner.Create();
        public void SubmitState(XboxState state)
        {
            if (Interlocked.Increment(ref count) == 1)
            {
                FirstSubmitStarted.TrySetResult();
                ReleaseFirstSubmit.Wait(TimeSpan.FromSeconds(2));
            }
            inner.SubmitState(state);
        }
        public Task LastStateIs(ushort buttons) => SpinWaitAsync(() => inner.LastState.Buttons == buttons);
        public void SetRumbleCallback(Action<Rumble> callback) => inner.SetRumbleCallback(callback);
        public void Disconnect() => inner.Disconnect();
        public void Dispose() { ReleaseFirstSubmit.Set(); inner.Dispose(); }
    }

    private sealed class MockPhysicalDeviceRecovery(Func<PhysicalDeviceRecoveryResult> result) : IPhysicalDeviceRecovery
    {
        public Task<PhysicalDeviceRecoveryResult> RestartExactTargetAsync(CancellationToken stopping) => Task.FromResult(result());
    }

    private sealed class FailingCreateBackend : IVirtualXboxController
    {
        public int SubmitCalls { get; private set; }
        public int DisconnectCalls { get; private set; }
        public int DisposeCalls { get; private set; }
        public void Create() => throw new BackendException("test_create_failed", "Expected create failure.");
        public void SubmitState(XboxState state) { SubmitCalls++; throw new BackendException("not_connected", "Create first."); }
        public void SetRumbleCallback(Action<Rumble> callback) { }
        public void Disconnect() => DisconnectCalls++;
        public void Dispose() => DisposeCalls++;
    }
}

