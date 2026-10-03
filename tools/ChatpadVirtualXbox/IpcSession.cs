using System.Text.Json;

namespace ChatpadVirtualXbox;

public sealed class IpcSession(IVirtualXboxController backend, Action<string> output) : IDisposable
{
    private readonly object outputLock = new();
    public const int MaximumLineBytes = 4096;
    private void Write(object data) { lock (outputLock) output(JsonSerializer.Serialize(data)); }
    public bool Process(string line)
    {
        int? id = null;
        try
        {
            if (System.Text.Encoding.UTF8.GetByteCount(line) > MaximumLineBytes) throw Invalid("Maximum request size is 4096 UTF-8 bytes.");
            using var doc = JsonDocument.Parse(line, new JsonDocumentOptions { MaxDepth = 3 });
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw Invalid("Request must be an object.");
            if (!root.TryGetProperty("id", out var idValue) || !idValue.TryGetInt32(out int requestId) || requestId < 0) throw Invalid("id must be a nonnegative int32.");
            id = requestId;
            if (!root.TryGetProperty("op", out var opValue) || opValue.ValueKind != JsonValueKind.String) throw Invalid("op must be a string.");
            string op = opValue.GetString()!;
            string[] permitted = op == "submit" ? ["id", "op", "buttons", "leftTrigger", "rightTrigger", "lx", "ly", "rx", "ry"] : ["id", "op"];
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in root.EnumerateObject())
                if (!seen.Add(property.Name) || !permitted.Contains(property.Name, StringComparer.Ordinal)) throw Invalid("Duplicate or unknown property: " + property.Name);
            switch (op)
            {
                case "create":
                    backend.Create();
                    backend.SetRumbleCallback(r => Write(new { @event = "rumble", leftMotor = r.LeftMotor, rightMotor = r.RightMotor }));
                    break;
                case "submit": backend.SubmitState(ParseState(root)); break;
                case "disconnect": backend.Disconnect(); break;
                case "quit": backend.Disconnect(); Write(new { id, ok = true, operation = op }); return false;
                default: throw Invalid("Unknown operation.");
            }
            Write(new { id, ok = true, operation = op });
        }
        catch (BackendException e) { Write(new { id, ok = false, error = e.Code, detail = e.Message }); }
        catch (Exception e) when (e is JsonException or FormatException or InvalidOperationException or OverflowException)
        { Write(new { id, ok = false, error = "invalid_request", detail = e.Message }); }
        return true;
    }
    public static XboxState ParseState(JsonElement root) => new(
        (ushort)Number(root, "buttons", 0, 65535), (byte)Number(root, "leftTrigger", 0, 255), (byte)Number(root, "rightTrigger", 0, 255),
        (short)Number(root, "lx", -32768, 32767), (short)Number(root, "ly", -32768, 32767), (short)Number(root, "rx", -32768, 32767), (short)Number(root, "ry", -32768, 32767));
    private static int Number(JsonElement root, string name, int min, int max)
    {
        if (!root.TryGetProperty(name, out var value) || !value.TryGetInt32(out int result) || result < min || result > max)
            throw Invalid(name + " missing or outside integer range.");
        return result;
    }
    private static BackendException Invalid(string message) => new("invalid_request", message);
    public void Dispose() => backend.Dispose();
}
