using System.Text.Json;
using System.Threading.Channels;

namespace ChatpadVirtualXbox;

internal sealed class BrokerSession : IAsyncDisposable
{
    private readonly Func<IVirtualXboxController> backendFactory;
    private readonly Func<string, CancellationToken, ValueTask> writeLine;
    private readonly Channel<string> output = Channel.CreateBounded<string>(new BoundedChannelOptions(32)
    {
        FullMode = BoundedChannelFullMode.Wait, SingleReader = true, SingleWriter = false
    });
    private readonly Channel<BrokerStateFrame> states = Channel.CreateBounded<BrokerStateFrame>(new BoundedChannelOptions(1)
    {
        FullMode = BoundedChannelFullMode.DropOldest, SingleReader = true, SingleWriter = false
    });
    private readonly CancellationTokenSource stopped = new();
    private readonly SemaphoreSlim controls = new(1, 1);
    private readonly SemaphoreSlim backendGate = new(1, 1);
    private readonly Task outputPump;
    private readonly Task statePump;
    private readonly TaskCompletionSource<Exception> fault = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private volatile IVirtualXboxController? backend;
    private BrokerSequenceTracker sequence = new();
    private int lastControlId = -1;
    private volatile bool connected;
    private bool backendCreated;
    private bool disposed;

    public BrokerSession(Func<IVirtualXboxController> backendFactory, Func<string, CancellationToken, ValueTask> writeLine)
    {
        this.backendFactory = backendFactory;
        this.writeLine = writeLine;
        outputPump = OutputLoopAsync();
        statePump = StateLoopAsync();
    }

    public Task<Exception> Faulted => fault.Task;

    public async Task HandleLineAsync(string line)
    {
        ThrowIfStopped();
        string operation = BrokerProtocol.PeekOperation(line);
        if (operation == "submit-state")
        {
            var frame = BrokerProtocol.ParseStateFrame(line);
            if (!connected || backend is null) throw new BackendException("broker_not_created", "submit-state requires a created virtual controller.");
            if (!sequence.TryAccept(frame.Sequence)) throw new BackendException("broker_sequence_rejected", "State sequence must increase without rollover for this lease.");
            if (!states.Writer.TryWrite(frame)) throw new BackendException("broker_state_queue_closed", "State stream is no longer accepting frames.");
            return;
        }

        var request = BrokerProtocol.ParseControlRequest(line);
        await controls.WaitAsync(stopped.Token).ConfigureAwait(false);
        try
        {
            ThrowIfStopped();
            if (request.Id <= lastControlId) throw new BackendException("broker_control_id_rejected", "Control correlation IDs must increase within the connection.");
            lastControlId = request.Id;
            switch (request.Operation)
            {
                case BrokerOperation.Ping:
                    await QueueAsync(new { version = BrokerProtocol.Version, id = request.Id, ok = true }).ConfigureAwait(false);
                    break;
                case BrokerOperation.Create:
                    await CreateAsync(request.Id).ConfigureAwait(false);
                    break;
                case BrokerOperation.Destroy:
                    await DestroyAsync().ConfigureAwait(false);
                    await QueueAsync(new { version = BrokerProtocol.Version, id = request.Id, ok = true }).ConfigureAwait(false);
                    break;
                default:
                    throw new BackendException("broker_protocol_error", "Unsupported control operation.");
            }
        }
        finally { controls.Release(); }
    }

    private async Task CreateAsync(int id)
    {
        if (connected) throw new BackendException("broker_already_created", "This pipe lease already owns a virtual controller.");
        var instance = backendFactory();
        backend = instance;
        try
        {
            await backendGate.WaitAsync(stopped.Token).ConfigureAwait(false);
            try
            {
                instance.Create();
                backendCreated = true;
                instance.SetRumbleCallback(OnRumble);
            }
            finally { backendGate.Release(); }
            connected = true;
            sequence = new BrokerSequenceTracker();
            await QueueAsync(new { version = BrokerProtocol.Version, id, ok = true }).ConfigureAwait(false);
        }
        catch
        {
            connected = false;
            while (states.Reader.TryRead(out _)) { }
            await ReleaseBackendAsync(instance, backendCreated).ConfigureAwait(false);
            if (ReferenceEquals(backend, instance)) backend = null;
            backendCreated = false;
            throw;
        }
    }

    private async Task DestroyAsync()
    {
        var instance = backend;
        if (instance is null) { connected = false; return; }
        connected = false;
        while (states.Reader.TryRead(out _)) { }
        await ReleaseBackendAsync(instance, backendCreated).ConfigureAwait(false);
        if (ReferenceEquals(backend, instance)) backend = null;
        backendCreated = false;
        sequence = new BrokerSequenceTracker();
    }

    private async Task ReleaseBackendAsync(IVirtualXboxController instance, bool neutralizeState)
    {
        await backendGate.WaitAsync().ConfigureAwait(false);
        try
        {
            var errors = new List<Exception>();
            if (neutralizeState)
            {
                try { instance.SubmitState(default); } catch (Exception e) { errors.Add(e); }
            }
            try { instance.SetRumbleCallback(_ => { }); } catch (Exception e) { errors.Add(e); }
            try { instance.Disconnect(); } catch (Exception e) { errors.Add(e); }
            try { instance.Dispose(); } catch (Exception e) { errors.Add(e); }
            if (errors.Count != 0) throw new BackendException("broker_backend_cleanup_failed", string.Join(" | ", errors.Select(e => e.Message)));
        }
        finally { backendGate.Release(); }
    }

    private void OnRumble(Rumble value)
    {
        if (!connected || stopped.IsCancellationRequested) return;
        if (!output.Writer.TryWrite(JsonSerializer.Serialize(new { version = BrokerProtocol.Version, op = "rumble", leftMotor = value.LeftMotor, rightMotor = value.RightMotor })))
            SignalFault(new BackendException("broker_output_backpressure", "Bounded rumble/control output queue is full."));
    }

    private async Task StateLoopAsync()
    {
        try
        {
            await foreach (var frame in states.Reader.ReadAllAsync(stopped.Token).ConfigureAwait(false))
            {
                var target = backend;
                if (!connected || target is null) continue;
                await backendGate.WaitAsync(stopped.Token).ConfigureAwait(false);
                try
                {
                    if (connected && ReferenceEquals(target, backend)) target.SubmitState(frame.State);
                }
                finally { backendGate.Release(); }
            }
        }
        catch (OperationCanceledException) when (stopped.IsCancellationRequested) { }
        catch (Exception e) { SignalFault(e); }
    }

    private async Task OutputLoopAsync()
    {
        try
        {
            await foreach (var line in output.Reader.ReadAllAsync(stopped.Token).ConfigureAwait(false))
                await writeLine(line, stopped.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (stopped.IsCancellationRequested) { }
        catch (Exception e) { SignalFault(e); }
    }

    private async ValueTask QueueAsync<T>(T value)
    {
        try { await output.Writer.WriteAsync(JsonSerializer.Serialize(value), stopped.Token).ConfigureAwait(false); }
        catch (ChannelClosedException e) { throw new BackendException("broker_output_closed", e.Message); }
    }

    private void SignalFault(Exception error)
    {
        if (fault.TrySetResult(error)) stopped.Cancel();
    }

    private void ThrowIfStopped()
    {
        if (disposed || stopped.IsCancellationRequested)
            throw new BackendException("broker_session_closed", fault.Task.IsCompletedSuccessfully ? fault.Task.Result.Message : "Broker session has closed.");
    }

    public async Task StopAsync()
    {
        if (disposed) return;
        disposed = true;
        connected = false;
        stopped.Cancel();
        states.Writer.TryComplete();
        await controls.WaitAsync().ConfigureAwait(false);
        try
        {
            var instance = backend;
            backend = null;
            bool wasCreated = backendCreated;
            backendCreated = false;
            if (instance is not null) await ReleaseBackendAsync(instance, wasCreated).ConfigureAwait(false);
        }
        finally { controls.Release(); }
        output.Writer.TryComplete();
        try { await Task.WhenAll(outputPump, statePump).WaitAsync(TimeSpan.FromSeconds(5)).ConfigureAwait(false); }
        catch (OperationCanceledException) { }
        catch (TimeoutException) { SignalFault(new TimeoutException("Broker session pumps did not stop within five seconds.")); }
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync().ConfigureAwait(false);
        backendGate.Dispose(); controls.Dispose(); stopped.Dispose();
    }
}
