namespace ChatpadVirtualXbox;

internal sealed record BrokerPeerSnapshot(
    string UserSid,
    int SessionId,
    int ActiveConsoleSessionId,
    bool IsLocalConsoleSession,
    bool IsAnonymous,
    bool IsRemoteClient);

internal sealed class BrokerPeerAuthorization
{
    private readonly string authorizedSid;

    public BrokerPeerAuthorization(string authorizedSid)
    {
        if (!IsUserSid(authorizedSid)) throw new BackendException("broker_configuration_invalid", "Authorized user SID is missing or invalid.");
        this.authorizedSid = authorizedSid;
    }

    public bool IsAuthorized(BrokerPeerSnapshot peer) =>
        !peer.IsAnonymous && !peer.IsRemoteClient && peer.SessionId >= 0 &&
        string.Equals(peer.UserSid, authorizedSid, StringComparison.OrdinalIgnoreCase);

    private static bool IsUserSid(string? sid) => sid is not null &&
        System.Text.RegularExpressions.Regex.IsMatch(sid, @"\AS-1-5-21-(?:[0-9]+-){2}[0-9]+-[0-9]+\z", System.Text.RegularExpressions.RegexOptions.CultureInvariant);
}
