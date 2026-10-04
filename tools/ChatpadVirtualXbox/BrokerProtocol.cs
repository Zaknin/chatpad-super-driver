using System.Text;
using System.Text.Json;

namespace ChatpadVirtualXbox;

internal enum BrokerOperation { Ping, Create, Destroy }

internal sealed record BrokerControlRequest(int Id, BrokerOperation Operation);
internal sealed record BrokerStateFrame(ulong Sequence, XboxState State);

internal static class BrokerProtocol
{
    public const int Version = 1;
    public const int MaximumFrameBytes = 4096;

    public static string PeekOperation(string json)
    {
        using var document = Parse(json);
        return String(document.RootElement, "op");
    }

    public static BrokerControlRequest ParseControlRequest(string json)
    {
        using var document = Parse(json);
        var root = document.RootElement;
        ExactProperties(root, "version", "id", "op");
        RequireVersion(root);
        int id = Integer(root, "id", 0, int.MaxValue);
        string operation = String(root, "op");
        var parsed = operation switch
        {
            "ping" => BrokerOperation.Ping,
            "create" => BrokerOperation.Create,
            "destroy" => BrokerOperation.Destroy,
            _ => throw Invalid("Unknown broker control operation.")
        };
        return new BrokerControlRequest(id, parsed);
    }

    public static BrokerStateFrame ParseStateFrame(string json)
    {
        using var document = Parse(json);
        var root = document.RootElement;
        ExactProperties(root, "version", "sequence", "op", "buttons", "leftTrigger", "rightTrigger", "lx", "ly", "rx", "ry");
        RequireVersion(root);
        if (String(root, "op") != "submit-state") throw Invalid("Expected submit-state operation.");
        ulong sequence = Unsigned64(root, "sequence");
        var state = new XboxState(
            (ushort)Integer(root, "buttons", 0, ushort.MaxValue),
            (byte)Integer(root, "leftTrigger", 0, byte.MaxValue),
            (byte)Integer(root, "rightTrigger", 0, byte.MaxValue),
            (short)Integer(root, "lx", short.MinValue, short.MaxValue),
            (short)Integer(root, "ly", short.MinValue, short.MaxValue),
            (short)Integer(root, "rx", short.MinValue, short.MaxValue),
            (short)Integer(root, "ry", short.MinValue, short.MaxValue));
        return new BrokerStateFrame(sequence, state);
    }

    private static JsonDocument Parse(string json)
    {
        if (json is null || Encoding.UTF8.GetByteCount(json) > MaximumFrameBytes)
            throw Invalid("Broker frame exceeds 4096 UTF-8 bytes.");
        try
        {
            var document = JsonDocument.Parse(json, new JsonDocumentOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow, MaxDepth = 8 });
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                document.Dispose();
                throw Invalid("Broker frame must be a JSON object.");
            }
            return document;
        }
        catch (JsonException e) { throw new BackendException("broker_protocol_error", "Malformed broker JSON: " + e.Message); }
    }

    private static void ExactProperties(JsonElement root, params string[] expected)
    {
        var names = new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in root.EnumerateObject())
            if (!names.Add(property.Name)) throw Invalid("Duplicate broker property.");
        if (names.Count != expected.Length || expected.Any(name => !names.Contains(name)))
            throw Invalid("Broker frame has missing or unknown properties.");
    }

    private static void RequireVersion(JsonElement root)
    {
        if (Integer(root, "version", 1, 1) != Version) throw Invalid("Unsupported broker protocol version.");
    }

    private static string String(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String)
            throw Invalid("Broker property must be a string: " + name);
        return value.GetString()!;
    }

    private static int Integer(JsonElement root, string name, int min, int max)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out int parsed) || parsed < min || parsed > max)
            throw Invalid("Broker property is outside its integer range: " + name);
        return parsed;
    }

    private static ulong Unsigned64(JsonElement root, string name)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Number || !value.TryGetUInt64(out ulong parsed))
            throw Invalid("Broker property is outside its unsigned 64-bit range: " + name);
        return parsed;
    }

    private static BackendException Invalid(string detail) => new("broker_protocol_error", detail);
}

// Sequence rollover is forbidden within a lease. A client reconnects before
// exhausting UInt64; accepting zero after UInt64.MaxValue would replay stale state.
internal sealed class BrokerSequenceTracker
{
    private bool hasValue;
    private ulong last;

    public bool TryAccept(ulong value)
    {
        if (hasValue && value <= last) return false;
        last = value;
        hasValue = true;
        return true;
    }
}

