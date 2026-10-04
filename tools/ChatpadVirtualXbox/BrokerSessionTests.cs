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

        Check("broker ping does not construct backend", async () =>
        {
            int factories = 0;
            var output = new List<string>();
            await using var session = new BrokerSession(() => { factories++; return new MockBackend(); }, (line, _) => { lock (output) output.Add(line); return ValueTask.CompletedTask; });
            await session.HandleLineAsync(Ping(1));
            await SpinWaitAsync(() => { lock (output) return output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true")); });
            return factories == 0 && output.Any(line => line.Contains("\"id\":1") && line.Contains("\"ok\":true"));
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
}

