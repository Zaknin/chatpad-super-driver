using System;
using System.Runtime.CompilerServices;
using System.Threading;

namespace Chatpad.LiveAuthorization {
    internal sealed class Record {
        internal readonly string Fingerprint;
        private int consumed;
        internal Record(string fingerprint) { Fingerprint = fingerprint; }
        internal bool TryConsume(string fingerprint) {
            if (!String.Equals(Fingerprint, fingerprint, StringComparison.Ordinal)) return false;
            return Interlocked.CompareExchange(ref consumed, 1, 0) == 0;
        }
    }

    public sealed class LiveNativeApplyAuthorization {
        internal LiveNativeApplyAuthorization() {}
    }

    public static class LiveAuthorizationRegistry {
        private static readonly ConditionalWeakTable<LiveNativeApplyAuthorization, Record> records = new ConditionalWeakTable<LiveNativeApplyAuthorization, Record>();

        public static LiveNativeApplyAuthorization CreateOneShotLiveNativeApplyAuthorization(string fingerprint) {
            if (fingerprint == null) throw new ArgumentNullException("fingerprint");
            var authorization = new LiveNativeApplyAuthorization();
            records.Add(authorization, new Record(fingerprint));
            return authorization;
        }

        public static bool TryConsumeOneShotLiveNativeApplyAuthorization(LiveNativeApplyAuthorization authorization, string fingerprint) {
            Record record;
            if (authorization == null || fingerprint == null || !records.TryGetValue(authorization, out record) || !record.TryConsume(fingerprint)) return false;
            return true;
        }
    }
}
