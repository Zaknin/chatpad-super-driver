using System;
using System.Runtime.CompilerServices;
using System.Threading;

namespace Chatpad.OneShotAuthorization {
    internal sealed class Record {
        internal readonly string Fingerprint;
        internal readonly object Provider;
        private int consumed;
        internal Record(string fingerprint, object provider) { Fingerprint = fingerprint; Provider = provider; }
        internal bool TryConsume(string fingerprint) {
            if (!String.Equals(Fingerprint, fingerprint, StringComparison.Ordinal)) return false;
            return Interlocked.CompareExchange(ref consumed, 1, 0) == 0;
        }
    }
    public static class Registry {
        private static readonly ConditionalWeakTable<object, Record> records = new ConditionalWeakTable<object, Record>();
        public static void Register(object key, string fingerprint, object provider) { records.Add(key, new Record(fingerprint, provider)); }
        public static bool TryConsume(object key, string fingerprint, out object provider) {
            provider = null; Record record;
            if (key == null || !records.TryGetValue(key, out record) || !record.TryConsume(fingerprint)) return false;
            provider = record.Provider; return true;
        }
    }
}
