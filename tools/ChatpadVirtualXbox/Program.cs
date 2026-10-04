using System.Text;
using System.Text.Json;

namespace ChatpadVirtualXbox;

internal static class Program
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
    public static async Task<int> Main(string[] args)
    {
        try
        {
            if (args.Length == 1 && args[0] == "self-test") return OfflineTests.Run();
            if (args.Length == 0) { Usage(); return 2; }
            var options = ParseOptions(args.Skip(1).ToArray());
            switch (args[0])
            {
#if HIDMAESTRO
                case "qualify":
                    RequireKeys(options, "allow-live-virtual", "report-file");
                    if (!options.ContainsKey("allow-live-virtual") || !options.TryGetValue("report-file", out var reportFile))
                        throw new BackendException("live_not_authorized", "Explicit --allow-live-virtual and --report-file required.");
                    return VirtualQualification.Run(Path.GetFullPath(reportFile));
#endif
                case "backend-status":
                    RequireKeys(options);
#if HIDMAESTRO
                    var availability = HidMaestroRuntime.Probe();
#else
                    var availability = new BackendAvailability(false, false, "HIDMaestro SDK is not compiled in.");
#endif
                    Console.WriteLine(JsonSerializer.Serialize(new { availability, contextConstructed = false, liveDeviceCreated = false, readOnly = true,
#if HIDMAESTRO
                        runtimeQualificationRequired = true
#else
                        runtimeQualificationRequired = false
#endif
                    }, JsonOptions));
                    return availability.RuntimeReady ? 0 : 3;
                case "helper":
                    RequireKeys(options, "backend", "duration-ms", "idle-ms", "allow-live-virtual");
                    return await Helper(options);
                case "service":
                    RequireKeys(options);
#if HIDMAESTRO
                    return WindowsServiceHost.Run();
#else
                    throw new BackendException("service_unavailable", "Service mode is available only in the self-contained pinned HIDMaestro build.");
#endif
                case "snapshot":
                    RequireKeys(options, "slot");
                    uint slot = (uint)Integer(options, "slot", -1, 0, 3);
                    var sample = new WindowsXInputReader().Read(slot);
                    Console.WriteLine(JsonSerializer.Serialize(new { slot, sample, identityProven = false, purpose = "selected-slot read-only snapshot" }, JsonOptions));
                    return sample.ReturnCode == 0 ? 0 : 3;
                case "observe":
                    RequireKeys(options, "slot", "timeout-ms", "poll-ms", "expect-file");
                    uint intended = (uint)Integer(options, "slot", -1, 0, 3);
                    if (!options.TryGetValue("expect-file", out string? file)) throw new BackendException("invalid_arguments", "--expect-file required for exact state comparison.");
                    var bytes = File.ReadAllBytes(file);
                    if (bytes.Length > 4096) throw new BackendException("invalid_arguments", "Expected state file exceeds 4096 bytes.");
                    using (var doc = JsonDocument.Parse(bytes))
                    {
                        var expected = IpcSession.ParseState(doc.RootElement);
                        if ((expected.Buttons & 0x0400) != 0) throw new BackendException("unsupported_guide_observation", "Documented XInputGetState excludes Guide. Verify that separate feature later.");
                        int timeout = Integer(options, "timeout-ms", 1000, 1, 120000);
                        int poll = Integer(options, "poll-ms", 10, 1, timeout);
                        var result = XInputObserver.Observe(new WindowsXInputReader(), intended, expected, timeout, poll, () => unchecked((uint)Environment.TickCount64), Thread.Sleep);
                        Console.WriteLine(JsonSerializer.Serialize(new { result, expected, identityProven = false, notice = "Exact supplied slot/state verified; associate slot with intended virtual instance independently. No first-connected fallback." }, JsonOptions));
                        return result.Matched ? 0 : 3;
                    }
                default: Usage(); return 2;
            }
        }
        catch (Exception e)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { ok = false, error = e is BackendException be ? be.Code : "helper_error", detail = e.Message }));
            return 2;
        }
    }
    private static async Task<int> Helper(Dictionary<string, string> options)
    {
        int duration = Integer(options, "duration-ms", 30000, 1, 604800000);
        int idle = Integer(options, "idle-ms", 1000, 1, duration);
        IVirtualXboxController backend = options.GetValueOrDefault("backend", "unavailable") switch
        {
            "mock" => new MockBackend(), "unavailable" => new UnavailableBackend(),
#if HIDMAESTRO
            "hidmaestro" => new HidMaestroBackend(options.ContainsKey("allow-live-virtual")),
#else
            "hidmaestro" => new UnavailableBackend(),
#endif
            _ => throw new BackendException("invalid_arguments", "--backend must be unavailable, mock or hidmaestro.")
        };
        var protocolOutput = Console.Out;
#if HIDMAESTRO
        // Upstream lifecycle logs use Console.WriteLine. Keep them off the IPC channel.
        if (options.GetValueOrDefault("backend") == "hidmaestro") Console.SetOut(Console.Error);
#endif
        using var session = new IpcSession(backend, protocolOutput.WriteLine);
        using var lifetime = new CancellationTokenSource(duration);
        Console.CancelKeyPress += (_, e) => { e.Cancel = true; lifetime.Cancel(); };
        using var input = Console.OpenStandardInput();
        var utf8 = new UTF8Encoding(false, true);
        int requests = 0;
        try
        {
            while (true)
            {
                using var lineDeadline = CancellationTokenSource.CreateLinkedTokenSource(lifetime.Token);
                lineDeadline.CancelAfter(idle);
                // Windows console/redirected-pipe streams do not reliably honor ReadAsync
                // cancellation. Bound the foreground wait; an abandoned reader is a
                // background task and the process exits without starting a second read.
                var line = await Task.Run(() => ReadLine(input)).WaitAsync(lineDeadline.Token);
                if (line is null) return 0;
                if (++requests > 10000) { protocolOutput.WriteLine("{\"id\":null,\"ok\":false,\"error\":\"request_limit\"}"); return 4; }
                if (!session.Process(utf8.GetString(line))) return 0;
                if (lifetime.IsCancellationRequested) throw new OperationCanceledException();
            }
        }
        catch (OperationCanceledException)
        {
            protocolOutput.WriteLine("{\"id\":null,\"ok\":false,\"error\":\"deadline_or_cancellation\"}"); return 4;
        }
        catch (BackendException e)
        {
            protocolOutput.WriteLine(JsonSerializer.Serialize(new { id = (int?)null, ok = false, error = e.Code, detail = e.Message })); return 4;
        }
    }
    private static byte[]? ReadLine(Stream input)
    {
        var bytes = new List<byte>(IpcSession.MaximumLineBytes);
        while (true)
        {
            int value = input.ReadByte();
            if (value < 0)
            {
                if (bytes.Count != 0) throw new BackendException("unterminated_request", "EOF before LF.");
                return null;
            }
            if (value == 10) break;
            bytes.Add((byte)value);
            if (bytes.Count > IpcSession.MaximumLineBytes) throw new BackendException("line_too_long", "4096-byte bound exceeded.");
        }
        if (bytes.Count != 0 && bytes[^1] == 13) bytes.RemoveAt(bytes.Count - 1);
        return bytes.ToArray();
    }
    private static Dictionary<string, string> ParseOptions(string[] args)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        for (int i = 0; i < args.Length; i++)
        {
            if (!args[i].StartsWith("--", StringComparison.Ordinal)) throw new BackendException("invalid_arguments", "Options require --name value.");
            string name = args[i][2..];
            string value = name == "allow-live-virtual" ? "true" : ++i < args.Length ? args[i] : throw new BackendException("invalid_arguments", "Missing option value.");
            if (!result.TryAdd(name, value)) throw new BackendException("invalid_arguments", "Duplicate option.");
        }
        return result;
    }
    private static void RequireKeys(Dictionary<string, string> options, params string[] keys)
    {
        foreach (string key in options.Keys) if (!keys.Contains(key, StringComparer.Ordinal)) throw new BackendException("invalid_arguments", "Unknown option: " + key);
    }
    private static int Integer(Dictionary<string, string> options, string name, int fallback, int min, int max)
    {
        int value = options.TryGetValue(name, out var raw) && int.TryParse(raw, out int parsed) ? parsed : !options.ContainsKey(name) ? fallback : -1;
        if (value < min || value > max) throw new BackendException("invalid_arguments", name + " outside " + min + ".." + max);
        return value;
    }
    private static void Usage() => Console.Error.WriteLine("self-test | helper [--backend unavailable|mock|hidmaestro] [--duration-ms 30000] [--idle-ms 1000] | snapshot --slot 0..3 | observe --slot 0..3 --expect-file state.json [--timeout-ms 1000] [--poll-ms 10]");
}
