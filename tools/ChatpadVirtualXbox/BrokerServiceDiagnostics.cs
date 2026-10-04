using System.Text;

namespace ChatpadVirtualXbox;

internal static class BrokerServiceDiagnostics
{
    internal const int MaximumRecordCharacters = 8192;
    private const long MaximumLogBytes = 65536;
    private const string LogFileName = "ChatpadBrokerService.log";

    internal static string FormatFailure(Exception error, DateTimeOffset timestamp)
    {
        ArgumentNullException.ThrowIfNull(error);
        string detail = error.ToString().Replace("\r", "\\r", StringComparison.Ordinal)
            .Replace("\n", "\\n", StringComparison.Ordinal);
        string record = timestamp.ToUniversalTime().ToString("O") + " " + detail;
        if (record.Length <= MaximumRecordCharacters) return record;
        const string suffix = "[truncated]";
        return record[..(MaximumRecordCharacters - suffix.Length)] + suffix;
    }

    internal static void AppendFailure(string installRoot, Exception error)
    {
        string path = BrokerRuntimePaths.Member(installRoot, LogFileName);
        if (File.Exists(path) && (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            throw new BackendException("broker_diagnostics_path_invalid", "Service diagnostic log cannot be a reparse point.");

        byte[] bytes = new UTF8Encoding(false).GetBytes(FormatFailure(error, DateTimeOffset.UtcNow) + Environment.NewLine);
        bool reset = File.Exists(path) && new FileInfo(path).Length + bytes.Length > MaximumLogBytes;
        using var stream = new FileStream(path, reset ? FileMode.Create : FileMode.Append, FileAccess.Write, FileShare.Read);
        stream.Write(bytes);
        stream.Flush(flushToDisk: true);
    }
}
