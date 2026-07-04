using System.Globalization;
using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Chatpad.StaticMetadataParser;

internal static class Program
{
    private const string SchemaVersion = "chatpad-static-metadata-parser-evidence-v1";
    private const string ToolName = "Chatpad.StaticMetadataParser";
    private const string ToolVersion = "1.0.0";
    private const long MaxInputBytes = 64L * 1024L * 1024L;

    public static int Main(string[] args)
    {
        ParserOptions options;
        try
        {
            options = ParserOptions.Parse(args);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex.Message);
            return 64;
        }

        Evidence evidence = Evidence.Create(options);
        try
        {
            Run(options, evidence);
        }
        catch (Exception ex)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "UNEXPECTED_PARSER_FAILURE";
            evidence.Diagnostics.Add(Diagnostic.Error("unexpected-parser-failure", ex.GetType().FullName, ex.Message));
            evidence.Defects.Add(Defect.Create("UNEXPECTED_PARSER_FAILURE", "parser", "No unexpected parser failure", ex.GetType().FullName, ex.Message));
        }
        int writeFailureExitCode = 0;
        try
        {
            WriteEvidence(options.OutputPath, evidence);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("Failed to write evidence: " + ex.Message);
            writeFailureExitCode = 65;
        }

        if (writeFailureExitCode != 0)
        {
            return writeFailureExitCode;
        }

        return evidence.Result == "PASS" ? 0 : 2;
    }

    private static void Run(ParserOptions options, Evidence evidence)
    {
        ValidateSafetyPolicy(options, evidence);
        ValidateInputPath(options.InputPath, evidence);
        ValidateOutputPath(options.OutputPath, evidence);

        ExpectedMetadata? expected = null;
        if (!string.IsNullOrWhiteSpace(options.ExpectedPath))
        {
            expected = ExpectedMetadata.Load(options.ExpectedPath);
            evidence.InputIdentitySource = expected.InputIdentitySource;
            evidence.ExpectedDeclarationCount = expected.ExpectedDeclarations.Count;
            evidence.ExpectedModules = expected.ExpectedDeclarations
                .Select(item => item.Module)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(item => item, StringComparer.OrdinalIgnoreCase)
                .ToArray();
        }

        if (evidence.Defects.Count != 0)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "PREFLIGHT_REJECTED";
            return;
        }

        byte[] bytes;
        try
        {
            bytes = File.ReadAllBytes(options.InputPath);
            evidence.ArtifactBytesRead = true;
            evidence.SafetyCounters.ArtifactBytesRead = 1;
            evidence.InputSize = bytes.LongLength;
            evidence.InputSha256 = Convert.ToHexString(SHA256.HashData(bytes));
            evidence.ArtifactHashComputed = true;
            evidence.SafetyCounters.ArtifactHashComputed = 1;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "INPUT_READ_FAILED";
            evidence.Defects.Add(Defect.Create("INPUT_READ_FAILED", "input", "Readable regular file", ex.GetType().Name, ex.Message));
            return;
        }

        try
        {
            using MemoryStream stream = new(bytes, writable: false);
            using PEReader peReader = new(stream, PEStreamOptions.LeaveOpen);
            if (!peReader.HasMetadata)
            {
                evidence.InputClassification = "PE_WITHOUT_CLI_METADATA";
                evidence.Result = "FAIL";
                evidence.ResultCode = "CLI_METADATA_MISSING";
                evidence.Defects.Add(Defect.Create("CLI_METADATA_MISSING", "input", "Managed CLI metadata", "missing", "The input PE does not contain CLI metadata."));
                return;
            }

            MetadataReader reader = peReader.GetMetadataReader();
            evidence.MetadataParsed = true;
            evidence.SafetyCounters.MetadataParsed = 1;
            evidence.InputClassification = "MANAGED_PE_CLI_METADATA";
            PopulateMetadata(peReader, reader, evidence);
            ApplyExpectedChecks(expected, evidence);
        }
        catch (BadImageFormatException ex)
        {
            evidence.InputClassification = "INVALID_PE_OR_CLI_METADATA";
            evidence.Result = "FAIL";
            evidence.ResultCode = "INVALID_PE_OR_CLI_METADATA";
            evidence.Defects.Add(Defect.Create("INVALID_PE_OR_CLI_METADATA", "input", "Valid PE/CLI metadata", "malformed", ex.Message));
            return;
        }

        if (evidence.Defects.Count == 0)
        {
            evidence.Result = "PASS";
            evidence.ResultCode = "STATIC_METADATA_VALIDATED";
        }
        else
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "STATIC_METADATA_DEFECTS_FOUND";
        }
    }

    private static void ValidateSafetyPolicy(ParserOptions options, Evidence evidence)
    {
        if (!options.NoLoad || !options.NoReflection || !options.NoExecute || !options.NoNativeInvoke)
        {
            evidence.Defects.Add(Defect.Create("UNSAFE_OPTION_REJECTED", "options", "All safety flags true", "one or more false", "The parser only supports no-load, no-reflection, no-execute, and no-native-invoke mode."));
        }
    }

    private static void ValidateInputPath(string inputPath, Evidence evidence)
    {
        if (!Path.IsPathFullyQualified(inputPath))
        {
            evidence.Defects.Add(Defect.Create("INPUT_PATH_NOT_ABSOLUTE", "input", "Absolute path", inputPath, "Input path must be absolute."));
            return;
        }

        if (HasAlternateDataStreamSyntax(inputPath))
        {
            evidence.Defects.Add(Defect.Create("INPUT_PATH_UNSAFE", "input", "No alternate data stream syntax", inputPath, "Input path contains unsupported colon syntax."));
            return;
        }

        FileInfo info = new(inputPath);
        if (!info.Exists)
        {
            evidence.Defects.Add(Defect.Create("INPUT_MISSING", "input", "Existing file", inputPath, "Input file does not exist."));
            return;
        }

        if ((info.Attributes & FileAttributes.Directory) != 0)
        {
            evidence.Defects.Add(Defect.Create("INPUT_NOT_FILE", "input", "Regular file", inputPath, "Input path is a directory."));
        }

        if ((info.Attributes & FileAttributes.ReparsePoint) != 0)
        {
            evidence.Defects.Add(Defect.Create("INPUT_REPARSE_POINT", "input", "Non-reparse regular file", inputPath, "Reparse points are rejected."));
        }

        if (info.Length <= 0)
        {
            evidence.Defects.Add(Defect.Create("INPUT_EMPTY", "input", "Non-empty file", info.Length.ToString(CultureInfo.InvariantCulture), "Input file is empty."));
        }

        if (info.Length > MaxInputBytes)
        {
            evidence.Defects.Add(Defect.Create("INPUT_TOO_LARGE", "input", MaxInputBytes.ToString(CultureInfo.InvariantCulture), info.Length.ToString(CultureInfo.InvariantCulture), "Input exceeds parser size limit."));
        }
    }

    private static void ValidateOutputPath(string outputPath, Evidence evidence)
    {
        if (!Path.IsPathFullyQualified(outputPath))
        {
            evidence.Defects.Add(Defect.Create("OUTPUT_PATH_NOT_ABSOLUTE", "output", "Absolute path", outputPath, "Output path must be absolute."));
            return;
        }

        string? parent = Path.GetDirectoryName(outputPath);
        if (string.IsNullOrWhiteSpace(parent) || !Directory.Exists(parent))
        {
            evidence.Defects.Add(Defect.Create("OUTPUT_PARENT_MISSING", "output", "Existing output directory", outputPath, "Output directory must already exist."));
        }
    }

    private static bool HasAlternateDataStreamSyntax(string path)
    {
        string full = Path.GetFullPath(path);
        int start = Path.GetPathRoot(full)?.Length ?? 0;
        return full.IndexOf(':', start) >= 0;
    }

    private static void PopulateMetadata(PEReader peReader, MetadataReader reader, Evidence evidence)
    {
        PEHeaders headers = peReader.PEHeaders;
        CorHeader? corHeader = headers.CorHeader;
        int entryPointValue = corHeader?.EntryPointTokenOrRelativeVirtualAddress ?? 0;
        bool hasEntryPoint = entryPointValue != 0;

        evidence.PeCliSummary = new PeCliSummary(
            PeKind: headers.PEHeader?.Magic.ToString() ?? "UNKNOWN",
            CoffMachine: headers.CoffHeader.Machine.ToString(),
            CliHeaderPresent: corHeader is not null,
            MetadataPresent: true,
            ModuleKind: hasEntryPoint ? "ConsoleOrWindowsExecutable" : "DllOrModule",
            CliFlags: corHeader?.Flags.ToString() ?? "NONE",
            EntryPointTokenOrRva: entryPointValue == 0 ? "" : "0x" + entryPointValue.ToString("X8", CultureInfo.InvariantCulture),
            EntryPointPresent: hasEntryPoint);

        if (hasEntryPoint)
        {
            evidence.Defects.Add(Defect.Create("ENTRY_POINT_PRESENT", "pe_cli_summary.entry_point_present", "false", "true", "Managed executable entry points are rejected."));
        }

        if (reader.IsAssembly)
        {
            AssemblyDefinition assembly = reader.GetAssemblyDefinition();
            string culture = assembly.Culture.IsNil ? "" : reader.GetString(assembly.Culture);
            evidence.AssemblyIdentity = new AssemblyIdentity(
                Name: reader.GetString(assembly.Name),
                Version: assembly.Version.ToString(),
                Culture: culture,
                PublicKeyToken: GetPublicKeyToken(reader, assembly.PublicKey));

            foreach (CustomAttributeHandle attributeHandle in assembly.GetCustomAttributes())
            {
                string? target = TryReadTargetFramework(reader, attributeHandle);
                if (!string.IsNullOrWhiteSpace(target))
                {
                    evidence.ArtifactTargetFramework = target;
                    break;
                }
            }
        }

        foreach (TypeDefinitionHandle handle in reader.TypeDefinitions)
        {
            TypeDefinition definition = reader.GetTypeDefinition(handle);
            evidence.TypeDefinitions.Add(new TypeRecord(reader.GetString(definition.Namespace), reader.GetString(definition.Name)));
            foreach (MethodDefinitionHandle methodHandle in definition.GetMethods())
            {
                MethodDefinition method = reader.GetMethodDefinition(methodHandle);
                string methodName = reader.GetString(method.Name);
                string declaringType = JoinTypeName(reader.GetString(definition.Namespace), reader.GetString(definition.Name));
                evidence.MethodDefinitions.Add(new MethodRecord(declaringType, methodName));

                MethodImport import = method.GetImport();
                if (!import.Module.IsNil)
                {
                    ModuleReference moduleReference = reader.GetModuleReference(import.Module);
                    string moduleName = reader.GetString(moduleReference.Name);
                    string entryPoint = import.Name.IsNil ? methodName : reader.GetString(import.Name);
                    evidence.PInvokeSummary.Add(new PInvokeRecord(
                        Module: moduleName,
                        EntryPoint: entryPoint,
                        DeclaringType: declaringType,
                        MethodName: methodName,
                        Attributes: import.Attributes.ToString(),
                        ExactSpelling: import.Attributes.HasFlag(System.Reflection.MethodImportAttributes.ExactSpelling),
                        SetLastError: import.Attributes.HasFlag(System.Reflection.MethodImportAttributes.SetLastError),
                        CharSet: GetCharSet(import.Attributes),
                        CallingConvention: GetCallingConvention(import.Attributes)));
                }
            }
        }

        evidence.TypeDefinitions = evidence.TypeDefinitions
            .OrderBy(item => item.Namespace, StringComparer.Ordinal)
            .ThenBy(item => item.Name, StringComparer.Ordinal)
            .ToList();
        evidence.MethodDefinitions = evidence.MethodDefinitions
            .OrderBy(item => item.DeclaringType, StringComparer.Ordinal)
            .ThenBy(item => item.Name, StringComparer.Ordinal)
            .ToList();
        evidence.PInvokeSummary = evidence.PInvokeSummary
            .OrderBy(item => item.Module, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.EntryPoint, StringComparer.Ordinal)
            .ThenBy(item => item.DeclaringType, StringComparer.Ordinal)
            .ThenBy(item => item.MethodName, StringComparer.Ordinal)
            .ToList();
        evidence.ActualDeclarationCount = evidence.PInvokeSummary.Count;
        evidence.ActualModules = evidence.PInvokeSummary
            .Select(item => item.Module)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(item => item, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static void ApplyExpectedChecks(ExpectedMetadata? expected, Evidence evidence)
    {
        if (expected is null)
        {
            evidence.Diagnostics.Add(Diagnostic.Info("expected-metadata-not-supplied", "No expected declaration file was supplied."));
            return;
        }

        if (expected.RequireNoEntryPoint && evidence.PeCliSummary?.EntryPointPresent == true)
        {
            evidence.DeclarationChecks.Add(CheckRecord.Fail("entry-point-absence", "No executable entry point", "present"));
        }
        else
        {
            evidence.DeclarationChecks.Add(CheckRecord.Pass("entry-point-absence"));
        }

        foreach (ExpectedDeclaration expectedDeclaration in expected.ExpectedDeclarations)
        {
            PInvokeRecord? match = evidence.PInvokeSummary.FirstOrDefault(actual =>
                string.Equals(actual.Module, expectedDeclaration.Module, StringComparison.OrdinalIgnoreCase) &&
                string.Equals(actual.EntryPoint, expectedDeclaration.EntryPoint, StringComparison.Ordinal));
            if (match is null)
            {
                evidence.DeclarationChecks.Add(CheckRecord.Fail("expected-declaration:" + expectedDeclaration.Module + ":" + expectedDeclaration.EntryPoint, "present", "missing"));
                evidence.Defects.Add(Defect.Create("EXPECTED_DECLARATION_MISSING", "pinvoke_summary", expectedDeclaration.Module + "!" + expectedDeclaration.EntryPoint, "missing", "Expected P/Invoke declaration is absent."));
            }
            else
            {
                evidence.DeclarationChecks.Add(CheckRecord.Pass("expected-declaration:" + expectedDeclaration.Module + ":" + expectedDeclaration.EntryPoint));
            }
        }

        foreach (PInvokeRecord actual in evidence.PInvokeSummary)
        {
            bool expectedMatch = expected.ExpectedDeclarations.Any(item =>
                string.Equals(item.Module, actual.Module, StringComparison.OrdinalIgnoreCase) &&
                string.Equals(item.EntryPoint, actual.EntryPoint, StringComparison.Ordinal));
            if (!expectedMatch)
            {
                evidence.DeclarationChecks.Add(CheckRecord.Fail("unexpected-declaration:" + actual.Module + ":" + actual.EntryPoint, "not present", "present"));
                evidence.Defects.Add(Defect.Create("UNEXPECTED_DECLARATION", "pinvoke_summary", "Allowlisted declaration", actual.Module + "!" + actual.EntryPoint, "Unexpected P/Invoke declaration was found."));
            }
        }

        if (expected.ExpectedDeclarations.Count != evidence.PInvokeSummary.Count)
        {
            evidence.DeclarationChecks.Add(CheckRecord.Fail("declaration-count", expected.ExpectedDeclarations.Count.ToString(CultureInfo.InvariantCulture), evidence.PInvokeSummary.Count.ToString(CultureInfo.InvariantCulture)));
            evidence.Defects.Add(Defect.Create("DECLARATION_COUNT_MISMATCH", "pinvoke_summary.count", expected.ExpectedDeclarations.Count.ToString(CultureInfo.InvariantCulture), evidence.PInvokeSummary.Count.ToString(CultureInfo.InvariantCulture), "Actual P/Invoke declaration count differs from expectation."));
        }
        else
        {
            evidence.DeclarationChecks.Add(CheckRecord.Pass("declaration-count"));
        }
    }

    private static string JoinTypeName(string ns, string name) => string.IsNullOrEmpty(ns) ? name : ns + "." + name;

    private static string GetPublicKeyToken(MetadataReader reader, BlobHandle publicKeyHandle)
    {
        if (publicKeyHandle.IsNil)
        {
            return "";
        }

        byte[] publicKey = reader.GetBlobBytes(publicKeyHandle);
        byte[] hash = SHA1.HashData(publicKey);
        byte[] token = hash.TakeLast(8).Reverse().ToArray();
        return Convert.ToHexString(token).ToLowerInvariant();
    }

    private static string? TryReadTargetFramework(MetadataReader reader, CustomAttributeHandle attributeHandle)
    {
        CustomAttribute attribute = reader.GetCustomAttribute(attributeHandle);
        string typeName = "";
        EntityHandle constructor = attribute.Constructor;
        if (constructor.Kind == HandleKind.MemberReference)
        {
            MemberReference member = reader.GetMemberReference((MemberReferenceHandle)constructor);
            EntityHandle parent = member.Parent;
            if (parent.Kind == HandleKind.TypeReference)
            {
                TypeReference type = reader.GetTypeReference((TypeReferenceHandle)parent);
                typeName = JoinTypeName(reader.GetString(type.Namespace), reader.GetString(type.Name));
            }
        }
        else if (constructor.Kind == HandleKind.MethodDefinition)
        {
            MethodDefinition method = reader.GetMethodDefinition((MethodDefinitionHandle)constructor);
            TypeDefinition type = reader.GetTypeDefinition(method.GetDeclaringType());
            typeName = JoinTypeName(reader.GetString(type.Namespace), reader.GetString(type.Name));
        }

        if (!string.Equals(typeName, "System.Runtime.Versioning.TargetFrameworkAttribute", StringComparison.Ordinal))
        {
            return null;
        }

        BlobReader blobReader = reader.GetBlobReader(attribute.Value);
        if (blobReader.Length < 3 || blobReader.ReadUInt16() != 1)
        {
            return null;
        }

        return blobReader.ReadSerializedString();
    }

    private static string GetCharSet(System.Reflection.MethodImportAttributes attributes)
    {
        const System.Reflection.MethodImportAttributes mask =
            System.Reflection.MethodImportAttributes.CharSetAnsi |
            System.Reflection.MethodImportAttributes.CharSetUnicode |
            System.Reflection.MethodImportAttributes.CharSetAuto;
        return (attributes & mask) switch
        {
            System.Reflection.MethodImportAttributes.CharSetAnsi => "Ansi",
            System.Reflection.MethodImportAttributes.CharSetUnicode => "Unicode",
            System.Reflection.MethodImportAttributes.CharSetAuto => "Auto",
            _ => "NotSpecified"
        };
    }

    private static string GetCallingConvention(System.Reflection.MethodImportAttributes attributes)
    {
        const System.Reflection.MethodImportAttributes mask =
            System.Reflection.MethodImportAttributes.CallingConventionCDecl |
            System.Reflection.MethodImportAttributes.CallingConventionFastCall |
            System.Reflection.MethodImportAttributes.CallingConventionStdCall |
            System.Reflection.MethodImportAttributes.CallingConventionThisCall |
            System.Reflection.MethodImportAttributes.CallingConventionWinApi;
        return (attributes & mask) switch
        {
            System.Reflection.MethodImportAttributes.CallingConventionCDecl => "CDecl",
            System.Reflection.MethodImportAttributes.CallingConventionFastCall => "FastCall",
            System.Reflection.MethodImportAttributes.CallingConventionStdCall => "StdCall",
            System.Reflection.MethodImportAttributes.CallingConventionThisCall => "ThisCall",
            System.Reflection.MethodImportAttributes.CallingConventionWinApi => "WinApi",
            _ => "NotSpecified"
        };
    }

    private static void WriteEvidence(string outputPath, Evidence evidence)
    {
        JsonSerializerOptions jsonOptions = new()
        {
            WriteIndented = true
        };
        string json = JsonSerializer.Serialize(evidence, jsonOptions);
        File.WriteAllText(outputPath, json + Environment.NewLine, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
    }
}

internal sealed class ParserOptions
{
    public required string InputPath { get; init; }
    public required string OutputPath { get; init; }
    public string ExpectedPath { get; init; } = "";
    public string ParserSourceCommit { get; init; } = "UNKNOWN";
    public string ParserBuildIdentity { get; init; } = "UNKNOWN";
    public bool NoLoad { get; init; } = true;
    public bool NoReflection { get; init; } = true;
    public bool NoExecute { get; init; } = true;
    public bool NoNativeInvoke { get; init; } = true;

    public static ParserOptions Parse(string[] args)
    {
        Dictionary<string, string> values = new(StringComparer.Ordinal);
        HashSet<string> flags = new(StringComparer.Ordinal);
        for (int i = 0; i < args.Length; i++)
        {
            string arg = args[i];
            switch (arg)
            {
                case "--input":
                case "--output":
                case "--expected":
                case "--parser-source-commit":
                case "--parser-build-identity":
                    if (i + 1 >= args.Length)
                    {
                        throw new ArgumentException("Missing value for " + arg);
                    }

                    values[arg] = args[++i];
                    break;
                case "--no-load":
                case "--no-reflection":
                case "--no-execute":
                case "--no-native-invoke":
                    flags.Add(arg);
                    break;
                default:
                    throw new ArgumentException("Unsupported option: " + arg);
            }
        }

        if (!values.TryGetValue("--input", out string? input) || string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("--input is required.");
        }

        if (!values.TryGetValue("--output", out string? output) || string.IsNullOrWhiteSpace(output))
        {
            throw new ArgumentException("--output is required.");
        }

        return new ParserOptions
        {
            InputPath = Path.GetFullPath(input),
            OutputPath = Path.GetFullPath(output),
            ExpectedPath = values.TryGetValue("--expected", out string? expected) ? Path.GetFullPath(expected) : "",
            ParserSourceCommit = values.TryGetValue("--parser-source-commit", out string? commit) ? commit : "UNKNOWN",
            ParserBuildIdentity = values.TryGetValue("--parser-build-identity", out string? identity) ? identity : "UNKNOWN",
            NoLoad = true,
            NoReflection = true,
            NoExecute = true,
            NoNativeInvoke = true
        };
    }
}

internal sealed class ExpectedMetadata
{
    public string InputIdentitySource { get; private init; } = "SYNTHETIC_FIXTURE";
    public bool RequireNoEntryPoint { get; private init; } = true;
    public List<ExpectedDeclaration> ExpectedDeclarations { get; } = [];

    public static ExpectedMetadata Load(string path)
    {
        using FileStream stream = File.OpenRead(path);
        using JsonDocument document = JsonDocument.Parse(stream);
        JsonElement root = document.RootElement;
        ExpectedMetadata expected = new()
        {
            InputIdentitySource = root.TryGetProperty("input_identity_source", out JsonElement identity) ? identity.GetString() ?? "SYNTHETIC_FIXTURE" : "SYNTHETIC_FIXTURE",
            RequireNoEntryPoint = !root.TryGetProperty("require_no_entry_point", out JsonElement noEntryPoint) || noEntryPoint.GetBoolean()
        };

        if (root.TryGetProperty("expected_declarations", out JsonElement declarations) && declarations.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement declaration in declarations.EnumerateArray())
            {
                expected.ExpectedDeclarations.Add(new ExpectedDeclaration(
                    declaration.GetProperty("module").GetString() ?? "",
                    declaration.GetProperty("entry_point").GetString() ?? ""));
            }
        }

        return expected;
    }
}

internal sealed record ExpectedDeclaration(string Module, string EntryPoint);

internal sealed class Evidence
{
    public string SchemaVersion { get; init; } = ProgramEvidence.SchemaVersion;
    public string GeneratedUtc { get; init; } = DateTimeOffset.UtcNow.ToString("o", CultureInfo.InvariantCulture);
    public string Result { get; set; } = "FAIL";
    public string ResultCode { get; set; } = "NOT_EVALUATED";
    public string ParserToolName { get; init; } = ProgramEvidence.ToolName;
    public string ParserToolVersion { get; init; } = ProgramEvidence.ToolVersion;
    public string ParserSourceCommit { get; init; } = "";
    public string ParserBuildIdentity { get; init; } = "";
    public string ParserTargetFramework { get; init; } = "net9.0";
    public string SystemReflectionMetadataVersion { get; init; } = typeof(PEReader).Assembly.GetName().Version?.ToString() ?? "";
    public string InputPath { get; init; } = "";
    public string InputClassification { get; set; } = "NOT_CLASSIFIED";
    public long InputSize { get; set; }
    public string InputSha256 { get; set; } = "";
    public string InputIdentitySource { get; set; } = "SYNTHETIC_FIXTURE";
    public bool MetadataParsed { get; set; }
    public bool ArtifactBytesRead { get; set; }
    public bool ArtifactHashComputed { get; set; }
    public bool StaticOnly { get; init; } = true;
    public bool NoLoadGuarantee { get; init; } = true;
    public bool NoRuntimeReflectionGuarantee { get; init; } = true;
    public bool NoExecutionGuarantee { get; init; } = true;
    public bool NoNativeInvocationGuarantee { get; init; } = true;
    public bool NoDeviceQueryGuarantee { get; init; } = true;
    public bool NoWindowsMutationGuarantee { get; init; } = true;
    public bool AssemblyLoadOccurred { get; init; }
    public bool RuntimeReflectionOccurred { get; init; }
    public bool CompiledArtifactExecutionOccurred { get; init; }
    public bool NativeDllLoadOccurred { get; init; }
    public bool EntryPointResolutionOccurred { get; init; }
    public bool NativeInvocationOccurred { get; init; }
    public bool SetupApiNewdevInvocationOccurred { get; init; }
    public bool DeviceQueryOccurred { get; init; }
    public bool HardwareAccessOccurred { get; init; }
    public bool WindowsMutationOccurred { get; init; }
    public bool DriverActionsOccurred { get; init; }
    public PeCliSummary? PeCliSummary { get; set; }
    public AssemblyIdentity? AssemblyIdentity { get; set; }
    public string ArtifactTargetFramework { get; set; } = "";
    public List<TypeRecord> TypeDefinitions { get; set; } = [];
    public List<MethodRecord> MethodDefinitions { get; set; } = [];
    public List<PInvokeRecord> PInvokeSummary { get; set; } = [];
    public int ExpectedDeclarationCount { get; set; }
    public int ActualDeclarationCount { get; set; }
    public string[] ExpectedModules { get; set; } = [];
    public string[] ActualModules { get; set; } = [];
    public List<CheckRecord> DeclarationChecks { get; } = [];
    public List<Diagnostic> Diagnostics { get; } = [];
    public List<Defect> Defects { get; } = [];
    public SafetyCounters SafetyCounters { get; } = new();

    public static Evidence Create(ParserOptions options) => new()
    {
        ParserSourceCommit = options.ParserSourceCommit,
        ParserBuildIdentity = options.ParserBuildIdentity,
        InputPath = options.InputPath
    };
}

internal static class ProgramEvidence
{
    public const string SchemaVersion = "chatpad-static-metadata-parser-evidence-v1";
    public const string ToolName = "Chatpad.StaticMetadataParser";
    public const string ToolVersion = "1.0.0";
}

internal sealed record PeCliSummary(string PeKind, string CoffMachine, bool CliHeaderPresent, bool MetadataPresent, string ModuleKind, string CliFlags, string EntryPointTokenOrRva, bool EntryPointPresent);
internal sealed record AssemblyIdentity(string Name, string Version, string Culture, string PublicKeyToken);
internal sealed record TypeRecord(string Namespace, string Name);
internal sealed record MethodRecord(string DeclaringType, string Name);
internal sealed record PInvokeRecord(string Module, string EntryPoint, string DeclaringType, string MethodName, string Attributes, bool ExactSpelling, bool SetLastError, string CharSet, string CallingConvention);
internal sealed record CheckRecord(string Id, string Result, string Expected, string Actual)
{
    public static CheckRecord Pass(string id) => new(id, "PASS", "", "");
    public static CheckRecord Fail(string id, string expected, string actual) => new(id, "FAIL", expected, actual);
}

internal sealed record Diagnostic(string Severity, string Code, string Message)
{
    public static Diagnostic Info(string code, string message) => new("INFO", code, message);
    public static Diagnostic Error(string code, string location, string message) => new("ERROR", code, location + ": " + message);
}

internal sealed record Defect(string Code, string Location, string Expected, string Actual, string Message)
{
    public static Defect Create(string code, string location, string expected, string actual, string message) => new(code, location, expected, actual, message);
}

internal sealed class SafetyCounters
{
    public int ArtifactBytesRead { get; set; }
    public int ArtifactHashComputed { get; set; }
    public int MetadataParsed { get; set; }
    public int AssemblyLoad { get; set; }
    public int RuntimeReflection { get; set; }
    public int CompiledArtifactExecution { get; set; }
    public int NativeDllLoad { get; set; }
    public int EntryPointResolution { get; set; }
    public int NativeInvocation { get; set; }
    public int SetupApiNewdevInvocation { get; set; }
    public int DeviceQuery { get; set; }
    public int HardwareAccess { get; set; }
    public int WindowsMutation { get; set; }
    public int DriverBuild { get; set; }
    public int DriverLink { get; set; }
    public int DriverSign { get; set; }
    public int DriverCatGeneration { get; set; }
    public int DriverPackage { get; set; }
    public int DriverStage { get; set; }
    public int DriverInstall { get; set; }
    public int DriverLoad { get; set; }
    public int DriverUnload { get; set; }
    public int DriverBind { get; set; }
    public int DriverRestore { get; set; }
    public int DriverRestart { get; set; }
}
