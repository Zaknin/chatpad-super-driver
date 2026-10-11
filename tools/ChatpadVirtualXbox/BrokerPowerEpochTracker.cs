namespace ChatpadVirtualXbox;

internal sealed class BrokerPowerEpochTracker
{
    internal const uint SuspendEvent = 0x0004;
    internal const uint ResumeSuspendEvent = 0x0007;
    internal const uint ResumeAutomaticEvent = 0x0012;
    private const long DuplicateResumeWindowMilliseconds = 30_000;
    private readonly object gate = new();
    private ulong currentEpoch;
    private long lastResumeTick = -1;
    private bool suspended;
    private bool recoveryClaimed;

    public event Action<ulong>? Resumed;

    public ulong CurrentEpoch
    {
        get { lock (gate) return currentEpoch; }
    }

    public bool Observe(uint eventType, long monotonicMilliseconds)
    {
        ulong epoch;
        lock (gate)
        {
            if (eventType == SuspendEvent)
            {
                suspended = true;
                return false;
            }
            if (eventType is not (ResumeAutomaticEvent or ResumeSuspendEvent)) return false;
            bool duplicate = !suspended && lastResumeTick >= 0 && monotonicMilliseconds >= lastResumeTick &&
                monotonicMilliseconds - lastResumeTick <= DuplicateResumeWindowMilliseconds;
            if (duplicate) return false;
            if (currentEpoch == ulong.MaxValue)
                throw new InvalidOperationException("Broker resume epoch exhausted; refusing to wrap the recovery generation.");
            currentEpoch++;
            epoch = currentEpoch;
            suspended = false;
            lastResumeTick = monotonicMilliseconds;
            recoveryClaimed = false;
        }
        Resumed?.Invoke(epoch);
        return true;
    }

    public bool TryClaimPhysicalRecovery()
    {
        lock (gate)
        {
            if (recoveryClaimed) return false;
            recoveryClaimed = true;
            return true;
        }
    }
}
