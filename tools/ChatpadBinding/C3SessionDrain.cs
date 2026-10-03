using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;

namespace Chatpad.C3 {
    // No PowerShell callback is run on these reader threads. Pipes are drained
    // even while the operator is idle or the caller waits for process exit.
    public sealed class SessionDrain {
        readonly object gate = new object();
        readonly List<string> queue = new List<string>();
        readonly StringBuilder errors = new StringBuilder();
        readonly Thread stdout, stderr;
        readonly int capacity;
        long dropped;
        long errorCharactersDropped;
        string fault;
        bool outputEnded;
        public SessionDrain(StreamReader output, StreamReader error, int capacity) {
            if (capacity < 16) throw new ArgumentOutOfRangeException("capacity");
            this.capacity = capacity;
            stdout = new Thread(delegate() { ReadOutput(output); });
            stderr = new Thread(delegate() { ReadError(error); });
            stdout.IsBackground = stderr.IsBackground = true;
            stdout.Start(); stderr.Start();
        }
        public static bool IsTelemetry(string line) {
            return line.Contains("\"event\":\"controller\"") || line.Contains("\"event\":\"chatpad\"");
        }
        void ReadOutput(StreamReader reader) {
            try {
                string line;
                while ((line = reader.ReadLine()) != null) {
                    lock (gate) {
                        if (line.Length > 16384) { fault = "Oversized session event"; continue; }
                        if (queue.Count == capacity) {
                            // Keep control/terminal evidence, drop only repeated
                            // report telemetry. The retained first report remains.
                            int victim = -1;
                            for (int i = 1; i < queue.Count; ++i) if (IsTelemetry(queue[i])) { victim = i; break; }
                            if (victim >= 0) { queue.RemoveAt(victim); ++dropped; }
                            else if (IsTelemetry(line)) { ++dropped; continue; }
                            else { fault = "Session control event queue overflow"; continue; }
                        }
                        queue.Add(line);
                    }
                }
            } catch (Exception ex) { lock (gate) fault = "Session stdout drain failed: " + ex.Message; }
            finally { lock (gate) outputEnded = true; }
        }
        void ReadError(StreamReader reader) {
            try {
                char[] buffer = new char[4096]; int count;
                while ((count = reader.Read(buffer, 0, buffer.Length)) > 0) {
                    lock (gate) {
                        int keep = Math.Min(count, 1048576 - errors.Length);
                        if (keep > 0) errors.Append(buffer, 0, keep);
                        errorCharactersDropped += count - keep;
                    }
                }
            } catch (Exception ex) { lock (gate) fault = "Session stderr drain failed: " + ex.Message; }
        }
        public string[] Take() { lock (gate) { string[] result = queue.ToArray(); queue.Clear(); return result; } }
        public bool Join(int milliseconds) { return stdout.Join(milliseconds) && stderr.Join(milliseconds); }
        public long Dropped { get { lock (gate) return dropped; } }
        public string Fault { get { lock (gate) return fault; } }
        public bool OutputEnded { get { lock (gate) return outputEnded; } }
        public string Errors { get { lock (gate) return errors.ToString(); } }
        public long ErrorCharactersDropped { get { lock (gate) return errorCharactersDropped; } }
    }
}
