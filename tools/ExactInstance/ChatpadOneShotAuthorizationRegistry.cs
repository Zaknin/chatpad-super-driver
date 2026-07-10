using System;
using System.Runtime.CompilerServices;
using System.Threading;

namespace Chatpad.OneShotAuthorization {
    internal sealed class Record {
        internal readonly string Fingerprint;
        private int consumed;
        internal Record(string fingerprint) { Fingerprint = fingerprint; }
        internal bool TryConsume(string fingerprint) {
            if (!String.Equals(Fingerprint, fingerprint, StringComparison.Ordinal)) return false;
            return Interlocked.CompareExchange(ref consumed, 1, 0) == 0;
        }
    }
    public static class Registry {
        private static readonly ConditionalWeakTable<object, Record> records = new ConditionalWeakTable<object, Record>();
        public static void CreateRecordingAuthorization(object key, string fingerprint) { records.Add(key, new Record(fingerprint)); }
        public static bool TryConsume(object key, string fingerprint) {
            Record record;
            if (key == null || !records.TryGetValue(key, out record) || !record.TryConsume(fingerprint)) return false;
            return true;
        }
    }
}
