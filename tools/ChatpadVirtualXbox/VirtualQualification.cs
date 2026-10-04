using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace ChatpadVirtualXbox;

public static class VirtualQualification
{
    public static uint SelectSlot(bool[] before, bool[] after)
    {
        if (before.Length != 4 || after.Length != 4 || Enumerable.Range(0,4).Any(i => before[i] && !after[i]))
            throw new BackendException("slot_ambiguity", "Existing XInput topology changed.");
        var delta = Enumerable.Range(0,4).Where(i => !before[i] && after[i]).ToArray();
        if (delta.Length != 1) throw new BackendException("slot_ambiguity", "Exactly one new XInput slot required.");
        return (uint)delta[0];
    }

#if HIDMAESTRO
    [StructLayout(LayoutKind.Sequential)]
    private struct Vibration { public ushort Left, Right; }
    [DllImport("xinput1_4.dll", ExactSpelling = true)]
    private static extern uint XInputSetState(uint slot, ref Vibration vibration);

    private static JsonElement Devices()
    {
        // Read-only; the SDK's device lifecycle remains in the real adapter.
        const string script = """
            & {
              $ErrorActionPreference='Stop'
              $present=@(Get-PnpDevice -PresentOnly)
              $devices=@($present | Where-Object { $_.InstanceId -like 'ROOT\VID_045E&PID_028E&IG_00\*' -or $_.InstanceId -like 'SWD\HIDMAESTRO*' -or $_.FriendlyName -like '*HIDMaestro*' } | ForEach-Object {
                $d=$_
                [pscustomobject]@{InstanceId=$d.InstanceId;Name=$d.FriendlyName;Inf=(Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction SilentlyContinue).Data;Service=(Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_Service -ErrorAction SilentlyContinue).Data;Problem=(Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue).Data;Status=$d.Status}
              })
              [pscustomobject]@{Devices=$devices;Physical=@($present | Where-Object InstanceId -like 'USB\VID_045E&PID_028E\*' | ForEach-Object { $id=$_.InstanceId; [pscustomobject]@{InstanceId=$id;Properties=@(Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_DriverInfPath,DEVPKEY_Device_Service,DEVPKEY_Device_ProblemCode,DEVPKEY_Device_LowerFilters,DEVPKEY_Device_UpperFilters,DEVPKEY_Device_LastArrivalDate -ErrorAction SilentlyContinue | Select-Object KeyName,Data)} });UmdfHosts=@(Get-Process WUDFHost -ErrorAction SilentlyContinue | Select-Object Id,ProcessName)} | ConvertTo-Json -Depth 6 -Compress
            }
            """;
        var start = new ProcessStartInfo("powershell.exe") { UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true };
        foreach (var arg in new[] { "-NoProfile", "-NonInteractive", "-EncodedCommand", Convert.ToBase64String(Encoding.Unicode.GetBytes(script)) }) start.ArgumentList.Add(arg);
        using var process = Process.Start(start) ?? throw new BackendException("health_probe", "Read-only PnP probe failed to start.");
        var stdout=process.StandardOutput.ReadToEndAsync(); var stderr=process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit(20000)) { process.Kill(); throw new BackendException("health_probe", "Read-only PnP probe timed out."); }
        if (process.ExitCode != 0) throw new BackendException("health_probe", stderr.GetAwaiter().GetResult());
        using var document=JsonDocument.Parse(stdout.GetAwaiter().GetResult());
        return document.RootElement.Clone();
    }

    public static int Run(string reportPath)
    {
        var reader = new WindowsXInputReader();
        var states = new (string Name, XboxState State)[] {
            ("neutral", default), ("A", new(0x1000,0,0,0,0,0,0)), ("B",new(0x2000,0,0,0,0,0,0)),
            ("Dpad",new(0x0009,0,0,0,0,0,0)), ("LT_RT",new(0,173,241,0,0,0,0)),
            ("left_stick",new(0,0,0,short.MinValue,short.MaxValue,0,0)),
            ("right_stick",new(0,0,0,0,0,short.MaxValue,short.MinValue)), ("neutral_final", default) };
        var report = new Dictionary<string,object?> { ["result"]="BLOCKED", ["profile"]="xbox-360-wired", ["physicalInputUsed"]=false, ["observations"]=new List<object>() };
        var observations=(List<object>)report["observations"]!;
        var before=Enumerable.Range(0,4).Select(i => reader.Read((uint)i)).ToArray();
        var connected=before.Select(s=>s.ReturnCode==0).ToArray(); report["before"]=before;
        uint? slot=null; bool created=false; bool statePass=false;
        var callbacks=new System.Collections.Concurrent.ConcurrentQueue<Rumble>();
        using var backend=new HidMaestroBackend(true);
        try
        {
            var initial=Devices(); report["pnpBefore"]=initial;
            if (initial.GetProperty("Devices").GetArrayLength()!=0 || connected.All(x=>x))
                throw new BackendException("unsafe_baseline", "Existing HIDMaestro devices or all XInput slots occupied; no creation attempted.");
            backend.SetRumbleCallback(callbacks.Enqueue);
            backend.Create(); created=true; report["adapterInitialized"]=true;
            var after=Enumerable.Range(0,4).Select(i=>reader.Read((uint)i).ReturnCode==0).ToArray();
            slot=SelectSlot(connected,after); report["slot"]=slot;
            var health=Devices(); report["pnpActive"]=health;
            var devices=health.GetProperty("Devices").EnumerateArray().ToArray();
            if (!devices.Any(d=>RuntimePackageIdentity.Hash(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "INF", d.GetProperty("Inf").GetString()!))==RuntimePackageIdentity.Packages[0].Files["hidmaestro.inf"]) ||
                !devices.Any(d=>RuntimePackageIdentity.Hash(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "INF", d.GetProperty("Inf").GetString()!))==RuntimePackageIdentity.Packages[1].Files["hidmaestro_xusb.inf"]) ||
                devices.Any(d=>d.GetProperty("Problem").ValueKind!=JsonValueKind.Number || d.GetProperty("Problem").GetInt32()!=0))
                throw new BackendException("umdf_health", "Exact qualified packages must bind with problem code zero.");
            if (initial.GetProperty("Physical").GetRawText()!=health.GetProperty("Physical").GetRawText()) throw new BackendException("physical_changed", "Physical stack changed; qualification stops.");
            report["umdfHealthy"]=true;
            foreach(var test in states)
            {
                backend.SubmitState(test.State);
                var observed=XInputObserver.Observe(reader,slot.Value,test.State,2500,10,()=>unchecked((uint)Environment.TickCount64),Thread.Sleep);
                observations.Add(new { test.Name, Expected=test.State, Observation=observed });
                if (!observed.Matched) throw new BackendException("state_mismatch", "Exact XInput state mismatch: "+test.Name);
            }
            statePass=true;
            var vibration=new Vibration { Left=32896, Right=16448 };
            var code=XInputSetState(slot.Value,ref vibration);
            var deadline=Stopwatch.StartNew();
            while(deadline.ElapsedMilliseconds<2500 && !callbacks.Contains(new Rumble(32896,16448))) Thread.Sleep(10);
            report["rumble"]=new { ReturnCode=code, Matched=callbacks.Contains(new Rumble(32896,16448)), Callbacks=callbacks.ToArray(), Optional=true };
            vibration=default; report["rumbleStopReturnCode"]=XInputSetState(slot.Value,ref vibration);
            backend.SubmitState(default);
        }
        catch(Exception e) { report["error"]=new { Code=e is BackendException be?be.Code:"qualification_error", Detail=e.Message }; }
        finally
        {
            if (created && slot.HasValue) { var stop=new Vibration(); XInputSetState(slot.Value,ref stop); }
            try { backend.Disconnect(); report["disconnectReturned"]=true; }
            catch(Exception e) { report["cleanupError"]=e.Message; }
            Thread.Sleep(1500);
            report["after"]=Enumerable.Range(0,4).Select(i=>reader.Read((uint)i)).ToArray();
            try
            {
                var final=Devices(); report["pnpAfter"]=final;
                bool cleanup=final.GetProperty("Devices").GetArrayLength()==0 &&
                    Enumerable.Range(0,4).All(i=>(reader.Read((uint)i).ReturnCode==0)==connected[i]);
                report["cleanupPassed"]=cleanup;
                if(statePass && cleanup && !report.ContainsKey("error") && !report.ContainsKey("cleanupError")) report["result"]="PASS";
            }
            catch(Exception e) { report["cleanupProbeError"]=e.Message; }
            File.WriteAllText(reportPath,JsonSerializer.Serialize(report,new JsonSerializerOptions { WriteIndented=true }),new UTF8Encoding(false));
        }
        return (string)report["result"]! == "PASS" ? 0 : 2;
    }
#endif
}
