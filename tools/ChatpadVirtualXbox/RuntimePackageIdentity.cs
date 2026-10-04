using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace ChatpadVirtualXbox;

public sealed record RuntimePackage(string Inf, IReadOnlyDictionary<string, string> Files);

public static class RuntimePackageIdentity
{
    public const string Signer = "885ADDC8018AC58E19B14668ACDAC9072BB6AE15";
    public const string PublicCertificateSha256 = "300238DB21F1ECD2F2C2E9F3A03EFF0147CBC419D474B1B3B89433569D5E6C96";
    public const string InfVersion = "1.10.0.142";
    // Frozen C2R3 catalogs: signatures and all member digests verified with WDK.
    // Rebuilding a catalog requires a new qualification and explicit hash update.
    public static readonly RuntimePackage[] Packages = [
        new("hidmaestro.inf", new Dictionary<string, string> {
            ["hidmaestro.inf"] = "92FEAC617024B5326F449B73EEF32516739F528190B7816CC2D81E7703F534FE",
            ["HIDMaestro.dll"] = "24B23EB1F572A83B9785AAD8386B379ACE916A6B22AD0CAB054D43DEE5AD7090",
            ["hidmaestro.cat"] = "4BCCC6F0542033169EA5650BE7470E70DF80E38AA3F1DE596309E3BE935CCF20" }),
        new("hidmaestro_xusb.inf", new Dictionary<string, string> {
            ["hidmaestro_xusb.inf"] = "E4B26FAD873E6DDF6A6A3E8B43294C3ABFC953FA560EBAED2E8C4CF31A20115B",
            ["HMXInput.dll"] = "B3760B79AFB98D2379AE29EE81B8C2B086F3635C426FDF42F0D34587EEE1B2E1",
            ["hidmaestro_xusb.cat"] = "C0E1EAFAB0D7014243F47AC1061B6B4D2AC425C15FA4E138FCBF57F34CE7EED8" }) ];

    public static bool Matches(RuntimePackage package, IReadOnlyDictionary<string, string> hashes, string signer) =>
        signer == Signer && hashes.Count == package.Files.Count && package.Files.All(file =>
            hashes.TryGetValue(file.Key, out var hash) && hash == file.Value);

    public static string Hash(string path)
    {
        using var stream = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(stream));
    }

    public static string Find(RuntimePackage package)
    {
        var repository = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "DriverStore", "FileRepository");
        var matches = Directory.EnumerateDirectories(repository, package.Inf + "_amd64_*").Where(directory =>
        {
            if ((File.GetAttributes(directory) & FileAttributes.ReparsePoint) != 0) return false;
            // Windows may generate PNF metadata; all deployable INF/CAT/DLL files
            // must still be exactly the three members in this frozen package.
            var files = Directory.EnumerateFiles(directory).Where(path =>
                new[] { ".inf", ".cat", ".dll" }.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase)).ToArray();
            if (files.Any(path => (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)) return false;
            var hashes = files.ToDictionary(path => Path.GetFileName(path), Hash, StringComparer.OrdinalIgnoreCase);
            return Matches(package, hashes, Signer);
        }).ToArray();
        if (matches.Length != 1) throw new BackendException("backend_unavailable", "Exact signed runtime package absent/ambiguous: " + package.Inf);
        return matches[0];
    }

    public static void VerifyCurrentTrust()
    {
        foreach (var name in new[] { StoreName.Root, StoreName.TrustedPublisher })
        {
            using var store = new X509Store(name, StoreLocation.LocalMachine);
            store.Open(OpenFlags.ReadOnly);
            var copies = store.Certificates.Cast<X509Certificate2>().Where(cert => cert.Thumbprint == Signer ||
                cert.Subject == "CN=Chatpad Super Driver Local Development Test Signing").ToArray();
            if (copies.Length != 1 || copies[0].Thumbprint != Signer || copies[0].HasPrivateKey ||
                Convert.ToHexString(SHA256.HashData(copies[0].RawData)) != PublicCertificateSha256)
                throw new BackendException("backend_unavailable", "Existing public trust copy missing/changed: " + name);
            using var chain = new X509Chain(true);
            chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
            chain.ChainPolicy.ApplicationPolicy.Add(new Oid("1.3.6.1.5.5.7.3.3"));
            if (!chain.Build(copies[0])) throw new BackendException("backend_unavailable", "Current machine Code Signing certificate chain rejected.");
        }
    }
}
