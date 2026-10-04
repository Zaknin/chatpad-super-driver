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
        var brokerSessionTests = BrokerSessionTests.Run();
        passed += brokerSessionTests.Passed;
        failed += brokerSessionTests.Failed;
        failures.AddRange(brokerSessionTests.Failures);
        Check("broker service failure log records UTC time, exception type, and cause", () =>
        {
            var timestamp = new DateTimeOffset(2026, 10, 4, 18, 47, 0, TimeSpan.Zero);
            string record = BrokerServiceDiagnostics.FormatFailure(new InvalidOperationException("create failed"), timestamp);
            return record.StartsWith("2026-10-04T18:47:00.0000000+00:00 System.InvalidOperationException: create failed", StringComparison.Ordinal) &&
                !record.Contains('\r') && !record.Contains('\n');
        });
        Check("broker service failure log bounds long exception details to one line", () =>
        {
            string record = BrokerServiceDiagnostics.FormatFailure(new InvalidOperationException(new string('x', 20000)), DateTimeOffset.UtcNow);
            return record.Length <= BrokerServiceDiagnostics.MaximumRecordCharacters &&
                !record.Contains('\r') && !record.Contains('\n') && record.EndsWith("[truncated]", StringComparison.Ordinal);
        });
        Check("broker pipe uses first-instance and rejects remote clients", () =>
            (BrokerPipeServer.PipeOpenMode & BrokerPipeServer.FirstPipeInstanceFlag) != 0 &&
            (BrokerPipeServer.PipeMode & BrokerPipeServer.RejectRemoteClientsFlag) != 0);
        Check("Windows local named-pipe result 229 is classified as local", () =>
            WindowsClientIdentity.ResolveLocality(false, null, 229, "FUCKTORYVR") == true);
        Check("Windows named-pipe locality query matches the local computer name", () =>
            WindowsClientIdentity.ResolveLocality(true, "FUCKTORYVR", 0, "FUCKTORYVR") == true);
        Check("Windows named-pipe locality query rejects a different computer", () =>
            WindowsClientIdentity.ResolveLocality(true, "OTHERPC", 0, "FUCKTORYVR") == false);
        Check("Windows named-pipe locality query fails closed on errors other than local-pipe 229", () =>
            WindowsClientIdentity.ResolveLocality(false, null, 233, "FUCKTORYVR") is null);
        Check("broker reads the initial client frame before impersonating the named-pipe peer", () =>
        {
            bool initialFrameRead = false;
            var expectedPeer = new BrokerPeerSnapshot("S-1-5-21-100-200-300-1001", 4, 4, true, false, false);
            var policy = new BrokerPeerAuthorization(expectedPeer.UserSid);
            var result = BrokerPipeServer.ReadFirstFrameAndAuthorizeAsync(
                _ => { initialFrameRead = true; return Task.FromResult<string?>("{\"version\":1,\"id\":1,\"op\":\"ping\"}"); },
                () => initialFrameRead ? expectedPeer : throw new InvalidOperationException("RunAsClient called before pipe read"),
                policy, (_, _) => ValueTask.CompletedTask, CancellationToken.None).GetAwaiter().GetResult();
            return initialFrameRead && result?.InitialFrame == "{\"version\":1,\"id\":1,\"op\":\"ping\"}" && result.Peer == expectedPeer;
        });
        Check("broker peer identity exception returns a bounded fault without escaping the connection loop", () =>
        {
            var frames = new List<string>();
            var policy = new BrokerPeerAuthorization("S-1-5-21-100-200-300-1001");
            var result = BrokerPipeServer.ReadFirstFrameAndAuthorizeAsync(
                _ => Task.FromResult<string?>("{\"version\":1,\"id\":1,\"op\":\"ping\"}"),
                () => throw new InvalidOperationException("client session unavailable"), policy,
                (line, _) => { frames.Add(line); return ValueTask.CompletedTask; }, CancellationToken.None).GetAwaiter().GetResult();
            if (result is not null || frames.Count != 1) return false;
            using var fault = JsonDocument.Parse(frames[0]);
            var root = fault.RootElement;
            return root.EnumerateObject().Count() == 4 && root.GetProperty("version").GetInt32() == 1 &&
                root.GetProperty("op").GetString() == "fault" &&
                root.GetProperty("error").GetString() == "broker_peer_identity_failed" &&
                root.GetProperty("detail").GetString() == "client session unavailable";
        });
        Check("broker peer pipe write failure cannot escape connection handling", () =>
        {
            var policy = new BrokerPeerAuthorization("S-1-5-21-100-200-300-1001");
            var result = BrokerPipeServer.ReadFirstFrameAndAuthorizeAsync(
                _ => Task.FromResult<string?>("{\"version\":1,\"id\":1,\"op\":\"ping\"}"),
                () => throw new InvalidOperationException("client session unavailable"), policy,
                (_, _) => ValueTask.FromException(new IOException("client disconnected")), CancellationToken.None).GetAwaiter().GetResult();
            return result is null;
        });
        Check("broker session exceptions preserve the narrow backend code in a protocol fault", () =>
        {
            using var fault = JsonDocument.Parse(BrokerPipeServer.CreateSessionFault(new BackendException("backend_create_failed", "virtual device creation failed")));
            var root = fault.RootElement;
            return root.EnumerateObject().Count() == 4 && root.GetProperty("version").GetInt32() == 1 &&
                root.GetProperty("op").GetString() == "fault" &&
                root.GetProperty("error").GetString() == "backend_create_failed" &&
                root.GetProperty("detail").GetString() == "virtual device creation failed";
        });
        Check("broker pipe refuses a pre-created local pipe-name squatter", () => BrokerPipeServer.TestRejectPipeSquatting());
        var neutral = new XboxState(0, 0, 0, 0, 0, 0, 0);
        Check("broker ping exact v1 control frame", () =>
        {
            var request = BrokerProtocol.ParseControlRequest("{\"version\":1,\"id\":7,\"op\":\"ping\"}");
            return request.Id == 7 && request.Operation == BrokerOperation.Ping;
        });
        Check("broker state uses unsigned 64-bit sequence", () =>
        {
            var state = BrokerProtocol.ParseStateFrame("{\"version\":1,\"sequence\":18446744073709551615,\"op\":\"submit-state\",\"buttons\":65535,\"leftTrigger\":255,\"rightTrigger\":0,\"lx\":-32768,\"ly\":32767,\"rx\":0,\"ry\":-1}");
            return state.Sequence == ulong.MaxValue && state.State == new XboxState(65535, 255, 0, -32768, 32767, 0, -1);
        });
        Check("broker sequence is strictly monotonic and does not wrap", () =>
        {
            var sequence = new BrokerSequenceTracker();
            return sequence.TryAccept(ulong.MaxValue) && !sequence.TryAccept(0) && !sequence.TryAccept(ulong.MaxValue);
        });
        foreach (string invalidBrokerControl in new[]
        {
            "{}", "{", "[]", "{\"version\":2,\"id\":1,\"op\":\"ping\"}",
            "{\"version\":1,\"id\":-1,\"op\":\"ping\"}",
            "{\"version\":1,\"id\":1,\"id\":2,\"op\":\"ping\"}",
            "{\"version\":1,\"id\":1,\"op\":\"ping\",\"extra\":true}",
            "{\"version\":1,\"id\":1,\"op\":\"quit\"}",
            "{\"version\":1,\"id\":1,\"op\":\"ping\",\"sequence\":0}"
        })
        {
            string bad = invalidBrokerControl;
            Throws("broker rejects non-exact control schema " + passed, () => BrokerProtocol.ParseControlRequest(bad));
        }
        foreach (string invalidBrokerState in new[]
        {
            "{\"version\":1,\"sequence\":-1,\"op\":\"submit-state\",\"buttons\":0,\"leftTrigger\":0,\"rightTrigger\":0,\"lx\":0,\"ly\":0,\"rx\":0,\"ry\":0}",
            "{\"version\":1,\"sequence\":18446744073709551616,\"op\":\"submit-state\",\"buttons\":0,\"leftTrigger\":0,\"rightTrigger\":0,\"lx\":0,\"ly\":0,\"rx\":0,\"ry\":0}",
            "{\"version\":1,\"sequence\":0,\"op\":\"submit-state\",\"buttons\":65536,\"leftTrigger\":0,\"rightTrigger\":0,\"lx\":0,\"ly\":0,\"rx\":0,\"ry\":0}",
            "{\"version\":1,\"sequence\":0,\"op\":\"submit-state\",\"buttons\":0,\"leftTrigger\":0,\"rightTrigger\":0,\"lx\":0,\"ly\":0,\"rx\":0,\"ry\":0,\"ry\":0}",
            "{\"version\":1,\"sequence\":0,\"op\":\"submit-state\",\"buttons\":0,\"leftTrigger\":0,\"rightTrigger\":0,\"lx\":0,\"ly\":0,\"rx\":0,\"ry\":0,\"id\":1}"
        })
        {
            string bad = invalidBrokerState;
            Throws("broker rejects invalid state schema " + passed, () => BrokerProtocol.ParseStateFrame(bad));
        }
        Check("broker authorization accepts exact installed SID in active local console", () =>
        {
            var policy = new BrokerPeerAuthorization("S-1-5-21-100-200-300-1001");
            return policy.IsAuthorized(new("S-1-5-21-100-200-300-1001", 4, 4, true, false, false));
        });
        foreach (var peer in new[]
        {
            new BrokerPeerSnapshot("S-1-5-21-100-200-300-1002", 4, 4, true, false, false),
            new BrokerPeerSnapshot("S-1-5-21-100-200-300-1001", 3, 4, true, false, false),
            new BrokerPeerSnapshot("S-1-5-21-100-200-300-1001", 4, 4, false, false, false),
            new BrokerPeerSnapshot("S-1-5-21-100-200-300-1001", 4, 4, true, true, false),
            new BrokerPeerSnapshot("S-1-5-21-100-200-300-1001", 4, 4, true, false, true)
        })
            Check("broker authorization rejects wrong SID, stale session, RDP, anonymous, or remote", () => !new BrokerPeerAuthorization("S-1-5-21-100-200-300-1001").IsAuthorized(peer));
        Throws("broker authorization rejects missing authorized SID", () => new BrokerPeerAuthorization(""));
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
        const string staleHidMaestroNode = @"SWD\HIDMAESTRO\HM_622C184E37F6891E";
        Check("stale non-present HIDMaestro Enum index zero does not block restart", () =>
        {
            bool exactStaleIdChecked = false;
            bool conflict = EnumControllerIndexGuard.HasPresentIndexZero(
                [(staleHidMaestroNode, (object?)0)], id => { exactStaleIdChecked = id == staleHidMaestroNode; return false; });
            return !conflict && exactStaleIdChecked;
        });
        Check("present HIDMaestro index zero still blocks profile sweep", () =>
            EnumControllerIndexGuard.HasPresentIndexZero(
                [(staleHidMaestroNode, (object?)0)], id => id == staleHidMaestroNode));
        Check("present controller scope conflict identifies its exact instance ID", () =>
            EnumControllerIndexGuard.FindPresentIndexZero(
                [(staleHidMaestroNode, (object?)0)], id => id == staleHidMaestroNode) == staleHidMaestroNode);
        Check("stale HIDMaestro instance is absent from present-device ID list", () =>
            !DeviceNodePresence.ContainsInstanceId("USB\\VID_045E&PID_028E\\1C21F10\0\0", staleHidMaestroNode));
        Check("present-device ID matching is exact and case-insensitive", () =>
            DeviceNodePresence.ContainsInstanceId("USB\\VID_045E&PID_028E\\1C21F10\0SWD\\HIDMAESTRO\\HM_622C184E37F6891E\0\0",
                staleHidMaestroNode.ToLowerInvariant()));
        Check("present-device ID matching does not accept prefixes", () =>
            !DeviceNodePresence.ContainsInstanceId("SWD\\HIDMAESTRO\\HM_622C184E37F6891E_EXTRA\0\0", staleHidMaestroNode));
        Check("present-device multi-string parsing stops at its double-null terminator", () =>
        {
            char[] chars = "SWD\\HIDMAESTRO\\HM_622C184E37F6891E\0\0SPURIOUS\0\0".ToCharArray();
            IntPtr buffer = System.Runtime.InteropServices.Marshal.AllocHGlobal(chars.Length * sizeof(char));
            try
            {
                for (int i = 0; i < chars.Length; i++) System.Runtime.InteropServices.Marshal.WriteInt16(buffer, i * sizeof(char), chars[i]);
                string multiString = DeviceNodePresence.ReadMultiString(buffer, (uint)chars.Length);
                return DeviceNodePresence.ContainsInstanceId(multiString, staleHidMaestroNode) &&
                    !DeviceNodePresence.ContainsInstanceId(multiString, "SPURIOUS");
            }
            finally { System.Runtime.InteropServices.Marshal.FreeHGlobal(buffer); }
        });
        Check("present nonzero controller index does not conflict", () =>
            !EnumControllerIndexGuard.HasPresentIndexZero(
                [(staleHidMaestroNode, (object?)1)], _ => true));
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
        Check("normal Windows captured XUSB motor packet", () => StateConversion.TryRumble(2, 0, [0, 0, 128, 64, 2], out var r) && r == new Rumble(32896, 16448));
        Check("normal Windows captured XUSB stop packet", () => StateConversion.TryRumble(2, 0, [0, 0, 0, 0, 2], out var r) && r == default);
        Check("XUSB LED packet refused", () => !StateConversion.TryRumble(2, 0, [0, 6, 0, 0, 1], out _));
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
        var package = RuntimePackageIdentity.Packages[0];
        var hashes = new Dictionary<string, string>(package.Files, StringComparer.OrdinalIgnoreCase);
        Check("qualified package exact manifest", () => RuntimePackageIdentity.Matches(package, hashes, RuntimePackageIdentity.Signer));
        Check("qualified package wrong signer", () => !RuntimePackageIdentity.Matches(package, hashes, new string('0', 40)));
        foreach (var name in package.Files.Keys)
        {
            var missingHash = new Dictionary<string, string>(hashes); missingHash.Remove(name);
            Check("qualified package missing " + name, () => !RuntimePackageIdentity.Matches(package, missingHash, RuntimePackageIdentity.Signer));
            var changedHash = new Dictionary<string, string>(hashes) { [name] = new string('0', 64) };
            Check("qualified package altered " + name, () => !RuntimePackageIdentity.Matches(package, changedHash, RuntimePackageIdentity.Signer));
        }
        var extraHash = new Dictionary<string, string>(hashes) { ["foreign.dll"] = new string('0', 64) };
        Check("qualified package extra file", () => !RuntimePackageIdentity.Matches(package, extraHash, RuntimePackageIdentity.Signer));
        Check("isolated slot delta", () => VirtualQualification.SelectSlot([false,false,true,false], [false,true,true,false]) == 1);
        Throws("slot ambiguity refused", () => VirtualQualification.SelectSlot([false,false,false,false], [true,true,false,false]));
        Throws("slot absent refused", () => VirtualQualification.SelectSlot([false,false,false,false], [false,false,false,false]));
        Throws("existing slot loss refused", () => VirtualQualification.SelectSlot([true,false,false,false], [false,true,false,false]));
        Console.WriteLine(JsonSerializer.Serialize(new { suite = "virtual-xbox-offline", passed, failed, failures, liveBackendCreated = false, xinputCalled = false }));
        return failed == 0 ? 0 : 1;
    }

    private sealed class FakeXInput(Func<uint, XInputSample> read) : IXInputReader
    {
        public XInputSample Read(uint slot) => read(slot);
    }
}
