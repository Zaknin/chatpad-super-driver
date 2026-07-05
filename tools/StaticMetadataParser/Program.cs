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
    private const string CurrentGate = "BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT";
    private const string RealArtifactAuthorizationGate = "BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION";
    private const string RuntimeBlocker = "BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED";
    private const string AcceptedParserImplementationStatus = "ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED";
    private const string AcceptedParserAuditCommit = "f0be4746ad4cc548334336c1e66f07007b71859f";
    private const string AcceptedReviewAuthorizationTransitionCommit = "baab23aece902cbb06e11a308d9092fdc0f9ce0d";
    private const string ImmutableSafetyPolicy = "IMMUTABLE_STATIC_ONLY";
    private const string SyntheticFixtureInputScope = "SYNTHETIC_FIXTURES_ONLY";
    private const string RealArtifactReviewInputScope = "REAL_ARTIFACT_STATIC_REVIEW_MANIFEST_AUTHORIZED";
    private const string RealArtifactReviewEvidenceScope = "REAL_ARTIFACT_STATIC_METADATA_REVIEW_EVIDENCE_ROOT";
    private const string RealArtifactRelativeRoot = "artifacts/compile-only/native-interop";
    private const string RealArtifactFileName = "Chatpad.NativeInterop.CompileOnlyValidation.dll";
    private const string CanonicalReadinessManifestPath = "docs/evidence/runtime-bringup-readiness-manifest.json";
    private const string RealArtifactReviewEvidenceRoot = "artifacts/logs/real-artifact-static-metadata-review";
    private const string PreflightFixtureManifestRoot = "artifacts/logs/static-parser-real-artifact-authorization-plumbing";

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
        ApplyFileScopePreflight(options, evidence);
        if (new[]
            {
                evidence.InputPathDecision,
                evidence.ExpectedPathDecision,
                evidence.OutputPathDecision
            }.Any(decision => decision.Decision == "REJECTED"))
        {
            WriteFilePreflightRejectionDiagnostic(evidence);
            return 64;
        }

        if (options.PreflightOnly)
        {
            WritePreflightOnlyDiagnostic(evidence);
            return 0;
        }

        try
        {
            Run(options, evidence);
        }
        catch (Exception ex)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "UNEXPECTED_PARSER_FAILURE";
            string exceptionType = ex.GetType().FullName ?? ex.GetType().Name;
            evidence.Diagnostics.Add(Diagnostic.Error("unexpected-parser-failure", exceptionType, ex.Message));
            evidence.Defects.Add(Defect.Create("UNEXPECTED_PARSER_FAILURE", "parser", "No unexpected parser failure", exceptionType, ex.Message));
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

        if (evidence.Defects.Count != 0)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "PREFLIGHT_REJECTED";
            return;
        }

        ValidateInputPath(options.InputPath, evidence);

        if (evidence.Defects.Count != 0)
        {
            evidence.Result = "FAIL";
            evidence.ResultCode = "PREFLIGHT_REJECTED";
            return;
        }

        ExpectedMetadata? expected = null;
        if (!string.IsNullOrWhiteSpace(options.ExpectedPath))
        {
            expected = ExpectedMetadata.Load(options.ExpectedPath, evidence);
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
            evidence.PeParseAttempted = true;
            evidence.SafetyCounters.PeParseAttempted = 1;
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

            evidence.MetadataParseAttempted = true;
            evidence.SafetyCounters.MetadataParseAttempted = 1;
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
        if (options.SafetyPolicyOptions.Count != 0)
        {
            foreach (string option in options.SafetyPolicyOptions)
            {
                evidence.Defects.Add(Defect.Create("PARSER_SAFETY.OPTION_NOT_SUPPORTED", "options", ImmutableSafetyPolicy, option, "Safety policy is immutable and is not user-controlled."));
            }
        }
    }

    private static void ApplyFileScopePreflight(ParserOptions options, Evidence evidence)
    {
        evidence.CurrentGate = CurrentGate;
        evidence.AllowedInputScope = SyntheticFixtureInputScope;
        evidence.OriginalInputPath = options.OriginalInputPath;
        evidence.InputNormalizedPath = options.InputPath;

        string? repositoryRoot = FindRepositoryRoot();
        if (string.IsNullOrWhiteSpace(repositoryRoot))
        {
            evidence.InputPathDecision = PathScopeDecision.Rejected("input", options.OriginalInputPath, options.InputPath, "REPOSITORY_ROOT_NOT_FOUND");
            evidence.ExpectedPathDecision = string.IsNullOrWhiteSpace(options.ExpectedPath)
                ? PathScopeDecision.NotProvided("expected")
                : PathScopeDecision.Rejected("expected", options.OriginalExpectedPath, options.ExpectedPath, "REPOSITORY_ROOT_NOT_FOUND");
            evidence.OutputPathDecision = PathScopeDecision.Rejected("output", options.OriginalOutputPath, options.OutputPath, "REPOSITORY_ROOT_NOT_FOUND");
            AddPathDefect(evidence, evidence.InputPathDecision);
            AddPathDefect(evidence, evidence.ExpectedPathDecision);
            AddPathDefect(evidence, evidence.OutputPathDecision);
            return;
        }

        string normalizedRoot = Path.GetFullPath(repositoryRoot);
        evidence.RepositoryRoot = normalizedRoot;
        RealArtifactAuthorizationContext realArtifactAuthorization = RealArtifactAuthorizationContext.NotRequested();
        if (options.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview)
        {
            realArtifactAuthorization = RealArtifactAuthorizationContext.Load(normalizedRoot, options);
        }

        ApplyAuthorizationContext(evidence, options, realArtifactAuthorization);
        evidence.InputPathDecision = ClassifyReadPath("input", options.OriginalInputPath, options.InputPath, normalizedRoot, options, realArtifactAuthorization);
        evidence.ExpectedPathDecision = string.IsNullOrWhiteSpace(options.ExpectedPath)
            ? PathScopeDecision.NotProvided("expected")
            : ClassifyReadPath("expected", options.OriginalExpectedPath, options.ExpectedPath, normalizedRoot, options, realArtifactAuthorization);
        evidence.OutputPathDecision = ClassifyWritePath(options.OriginalOutputPath, options.OutputPath, normalizedRoot, options);

        if (evidence.OutputPathDecision.Decision == "ALLOWED" &&
            (PathsEqual(options.OutputPath, options.InputPath) ||
             (!string.IsNullOrWhiteSpace(options.ExpectedPath) && PathsEqual(options.OutputPath, options.ExpectedPath))))
        {
            evidence.OutputPathDecision = PathScopeDecision.Rejected(
                "output",
                options.OriginalOutputPath,
                options.OutputPath,
                "READ_WRITE_PATH_COLLISION");
        }

        PathScopeDecision[] decisions =
        [
            evidence.InputPathDecision,
            evidence.ExpectedPathDecision,
            evidence.OutputPathDecision
        ];

        // All lexical classifications above complete before reparse/existence checks below.
        foreach (PathScopeDecision decision in decisions.Where(item => item.Decision == "ALLOWED" && item.Reason != "REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZED_BY_MANIFEST"))
        {
            string? reparsePoint = FindReparsePointInPath(normalizedRoot, decision.NormalizedPath);
            if (!string.IsNullOrWhiteSpace(reparsePoint))
            {
                PathScopeDecision rejected = PathScopeDecision.Rejected(
                    decision.Role,
                    decision.OriginalPath,
                    decision.NormalizedPath,
                    "REPARSE_POINT_NOT_AUTHORIZED");
                SetPathDecision(evidence, rejected);
            }
        }

        foreach (PathScopeDecision decision in new[]
                 {
                     evidence.InputPathDecision,
                     evidence.ExpectedPathDecision,
                     evidence.OutputPathDecision
                 })
        {
            AddPathDefect(evidence, decision);
        }

        evidence.InputClassification = evidence.InputPathDecision.Decision == "ALLOWED"
            ? options.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview ? "REAL_ARTIFACT_STATIC_REVIEW_CANDIDATE" : "SYNTHETIC_FIXTURE_CANDIDATE"
            : "INPUT_SCOPE_REJECTED";
        evidence.InputScopeDecision = evidence.InputPathDecision.Decision;
        evidence.InputScopeReason = evidence.InputPathDecision.Reason;
    }

    private static PathScopeDecision ClassifyReadPath(
        string role,
        string originalPath,
        string normalizedPath,
        string repositoryRoot,
        ParserOptions options,
        RealArtifactAuthorizationContext realArtifactAuthorization)
    {
        string normalizedRealRoot = Path.GetFullPath(Path.Combine(
            repositoryRoot,
            RealArtifactRelativeRoot.Replace('/', Path.DirectorySeparatorChar)));
        if (HasAlternateDataStreamSyntax(normalizedPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "ALTERNATE_DATA_STREAM_NOT_AUTHORIZED");
        }

        if (options.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview)
        {
            return ClassifyRealArtifactReviewReadPath(role, originalPath, normalizedPath, repositoryRoot, realArtifactAuthorization);
        }

        if (IsUnderDirectory(normalizedPath, normalizedRealRoot) ||
            ContainsProtectedArtifactName(normalizedPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "REAL_ARTIFACT_NOT_AUTHORIZED");
        }

        if (!Path.IsPathFullyQualified(originalPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "PATH_NOT_ABSOLUTE");
        }

        if (!IsAllowedSyntheticFixturePath(repositoryRoot, normalizedPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "OUTSIDE_SYNTHETIC_FIXTURE_SCOPE");
        }

        return PathScopeDecision.Allowed(role, originalPath, normalizedPath, "SYNTHETIC_FIXTURE_ROOT");
    }

    private static PathScopeDecision ClassifyWritePath(
        string originalPath,
        string normalizedPath,
        string repositoryRoot,
        ParserOptions options)
    {
        string normalizedRealRoot = Path.GetFullPath(Path.Combine(
            repositoryRoot,
            RealArtifactRelativeRoot.Replace('/', Path.DirectorySeparatorChar)));
        if (HasAlternateDataStreamSyntax(normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "ALTERNATE_DATA_STREAM_NOT_AUTHORIZED");
        }

        if (options.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview)
        {
            return ClassifyRealArtifactReviewWritePath(originalPath, normalizedPath, repositoryRoot);
        }

        if (IsUnderDirectory(normalizedPath, normalizedRealRoot) ||
            ContainsProtectedArtifactName(normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "REAL_ARTIFACT_NOT_AUTHORIZED");
        }

        if (!Path.IsPathFullyQualified(originalPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "PATH_NOT_ABSOLUTE");
        }

        if (!IsAllowedParserEvidencePath(repositoryRoot, normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTSIDE_PARSER_EVIDENCE_SCOPE");
        }

        string? parent = Path.GetDirectoryName(normalizedPath);
        if (string.IsNullOrWhiteSpace(parent) || !Directory.Exists(parent))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTPUT_PARENT_MISSING");
        }

        if (File.Exists(normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTPUT_ALREADY_EXISTS");
        }

        return PathScopeDecision.Allowed("output", originalPath, normalizedPath, "PARSER_EVIDENCE_ROOT");
    }

    private static PathScopeDecision ClassifyRealArtifactReviewReadPath(
        string role,
        string originalPath,
        string normalizedPath,
        string repositoryRoot,
        RealArtifactAuthorizationContext authorization)
    {
        if (!Path.IsPathFullyQualified(originalPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "PATH_NOT_ABSOLUTE");
        }

        if (!authorization.Authorized)
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, authorization.FailureReason);
        }

        if (role == "input")
        {
            if (!PathsEqual(normalizedPath, authorization.AcceptedArtifactPath))
            {
                return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "REAL_ARTIFACT_IDENTITY_MISMATCH");
            }

            return PathScopeDecision.Allowed(role, originalPath, normalizedPath, "REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZED_BY_MANIFEST");
        }

        if (!IsAllowedRealArtifactReviewEvidencePath(repositoryRoot, normalizedPath) ||
            ContainsProtectedArtifactName(normalizedPath))
        {
            return PathScopeDecision.Rejected(role, originalPath, normalizedPath, "OUTSIDE_REAL_ARTIFACT_REVIEW_EVIDENCE_SCOPE");
        }

        return PathScopeDecision.Allowed(role, originalPath, normalizedPath, "REAL_ARTIFACT_REVIEW_EXPECTATION_ROOT");
    }

    private static PathScopeDecision ClassifyRealArtifactReviewWritePath(
        string originalPath,
        string normalizedPath,
        string repositoryRoot)
    {
        if (!Path.IsPathFullyQualified(originalPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "PATH_NOT_ABSOLUTE");
        }

        if (!IsAllowedRealArtifactReviewEvidencePath(repositoryRoot, normalizedPath) ||
            ContainsProtectedArtifactName(normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTSIDE_REAL_ARTIFACT_REVIEW_EVIDENCE_SCOPE");
        }

        string? parent = Path.GetDirectoryName(normalizedPath);
        if (string.IsNullOrWhiteSpace(parent) || !Directory.Exists(parent))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTPUT_PARENT_MISSING");
        }

        if (File.Exists(normalizedPath))
        {
            return PathScopeDecision.Rejected("output", originalPath, normalizedPath, "OUTPUT_ALREADY_EXISTS");
        }

        return PathScopeDecision.Allowed("output", originalPath, normalizedPath, "REAL_ARTIFACT_REVIEW_EVIDENCE_ROOT");
    }

    private static void AddPathDefect(Evidence evidence, PathScopeDecision decision)
    {
        if (decision.Decision != "REJECTED")
        {
            return;
        }

        string code = decision.Role switch
        {
            "input" => "PARSER_INPUT_PATH.NOT_AUTHORIZED",
            "expected" => "PARSER_EXPECTED_PATH.NOT_AUTHORIZED",
            "output" => "PARSER_OUTPUT_PATH.NOT_AUTHORIZED",
            _ => "PARSER_FILE_PATH.NOT_AUTHORIZED"
        };
        evidence.Defects.Add(Defect.Create(
            code,
            decision.Role,
            decision.Role == "output" ? "Parser-specific ignored evidence path" : "Parser-specific synthetic fixture path",
            decision.NormalizedPath,
            "File path rejected before caller-selected file I/O: " + decision.Reason));
    }

    private static void ApplyAuthorizationContext(
        Evidence evidence,
        ParserOptions options,
        RealArtifactAuthorizationContext authorization)
    {
        evidence.ReviewScope = options.ReviewScope.Text;
        evidence.PreflightOnly = options.PreflightOnly;
        evidence.AuthorizationManifestPath = authorization.ManifestPath;
        evidence.RealArtifactAuthorizationStatus = authorization.Authorized ? "AUTHORIZED" : authorization.Status;
        evidence.RealArtifactAuthorizationReason = authorization.Authorized ? "MANIFEST_AND_IDENTITY_MATCHED" : authorization.FailureReason;
        evidence.RealArtifactAuthorizationGateMatched = authorization.GateMatched;
        evidence.RealArtifactAcceptedParserAuditCommitMatched = authorization.AcceptedParserAuditCommitMatched;
        evidence.RealArtifactTransitionCommitMatched = authorization.TransitionCommitMatched;
        evidence.RealArtifactIdentityMatched = authorization.IdentityMatched;
        evidence.RealArtifactExpectedRelativePath = authorization.AcceptedArtifactRelativePath;
        evidence.RealArtifactExpectedSha256 = authorization.AcceptedArtifactSha256;
        evidence.RealArtifactExpectedSize = authorization.AcceptedArtifactSize;
        evidence.RealArtifactExpectedIdentitySource = authorization.IdentitySource;

        if (options.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview)
        {
            evidence.AllowedInputScope = RealArtifactReviewInputScope;
            evidence.AllowedExpectedScope = RealArtifactReviewEvidenceScope;
            evidence.AllowedOutputScope = RealArtifactReviewEvidenceScope;
        }
        else
        {
            evidence.AllowedExpectedScope = SyntheticFixtureInputScope;
            evidence.AllowedOutputScope = "PARSER_EVIDENCE_ROOTS_ONLY";
        }
    }

    private static void SetPathDecision(Evidence evidence, PathScopeDecision decision)
    {
        switch (decision.Role)
        {
            case "input":
                evidence.InputPathDecision = decision;
                break;
            case "expected":
                evidence.ExpectedPathDecision = decision;
                break;
            case "output":
                evidence.OutputPathDecision = decision;
                break;
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

        if (info.Length <= 0)
        {
            evidence.Defects.Add(Defect.Create("INPUT_EMPTY", "input", "Non-empty file", info.Length.ToString(CultureInfo.InvariantCulture), "Input file is empty."));
        }

        if (info.Length > MaxInputBytes)
        {
            evidence.Defects.Add(Defect.Create("INPUT_TOO_LARGE", "input", MaxInputBytes.ToString(CultureInfo.InvariantCulture), info.Length.ToString(CultureInfo.InvariantCulture), "Input exceeds parser size limit."));
        }
    }

    private static bool HasAlternateDataStreamSyntax(string path)
    {
        string full = Path.GetFullPath(path);
        int start = Path.GetPathRoot(full)?.Length ?? 0;
        return full.IndexOf(':', start) >= 0;
    }

    private static bool IsAllowedSyntheticFixturePath(string repositoryRoot, string inputPath)
    {
        string artifactsLogs = Path.GetFullPath(Path.Combine(repositoryRoot, "artifacts", "logs"));
        if (!IsUnderDirectory(inputPath, artifactsLogs))
        {
            return false;
        }

        string relative = Path.GetRelativePath(artifactsLogs, inputPath);
        string[] segments = relative.Split(new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar }, StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 3 &&
            IsParserSpecificRootSegment(segments[0]) &&
            segments.Skip(1).Any(segment => string.Equals(segment, "fixtures", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsAllowedParserEvidencePath(string repositoryRoot, string outputPath)
    {
        string artifactsLogs = Path.GetFullPath(Path.Combine(repositoryRoot, "artifacts", "logs"));
        if (!IsUnderDirectory(outputPath, artifactsLogs))
        {
            return false;
        }

        string relative = Path.GetRelativePath(artifactsLogs, outputPath);
        string[] segments = relative.Split(
            new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar },
            StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 2 && IsParserSpecificRootSegment(segments[0]);
    }

    private static bool IsAllowedRealArtifactReviewEvidencePath(string repositoryRoot, string outputPath)
    {
        string reviewRoot = Path.GetFullPath(Path.Combine(
            repositoryRoot,
            RealArtifactReviewEvidenceRoot.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnderDirectory(outputPath, reviewRoot))
        {
            return false;
        }

        string relative = Path.GetRelativePath(reviewRoot, outputPath);
        string[] segments = relative.Split(
            new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar },
            StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 1 && segments.All(segment => segment != "." && segment != "..");
    }

    private static bool IsAllowedPreflightManifestFixturePath(string repositoryRoot, string manifestPath)
    {
        string fixtureRoot = Path.GetFullPath(Path.Combine(
            repositoryRoot,
            PreflightFixtureManifestRoot.Replace('/', Path.DirectorySeparatorChar)));
        return IsUnderDirectory(manifestPath, fixtureRoot) &&
            string.Equals(Path.GetExtension(manifestPath), ".json", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsParserSpecificRootSegment(string segment) =>
        ProgramPaths.IsApprovedParserRootSegment(segment);

    private static bool ContainsProtectedArtifactName(string path) =>
        path.Contains(RealArtifactFileName, StringComparison.OrdinalIgnoreCase);

    private static bool PathsEqual(string left, string right) =>
        string.Equals(Path.GetFullPath(left), Path.GetFullPath(right), StringComparison.OrdinalIgnoreCase);

    private static bool IsUnderDirectory(string candidatePath, string directoryPath)
    {
        string candidate = Path.GetFullPath(candidatePath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string directory = Path.GetFullPath(directoryPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return candidate.StartsWith(directory, StringComparison.OrdinalIgnoreCase);
    }

    private static string? FindReparsePointInPath(string repositoryRoot, string path)
    {
        string normalizedRoot = Path.GetFullPath(repositoryRoot).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string normalizedPath = Path.GetFullPath(path);
        FileInfo file = new(normalizedPath);
        if (file.Exists && (file.Attributes & FileAttributes.ReparsePoint) != 0)
        {
            return file.FullName;
        }

        DirectoryInfo? current = new(Path.GetDirectoryName(normalizedPath) ?? "");

        while (current is not null && IsUnderDirectory(current.FullName, normalizedRoot))
        {
            if (current.Exists && (current.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                return current.FullName;
            }

            if (string.Equals(
                current.FullName.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar),
                normalizedRoot,
                StringComparison.OrdinalIgnoreCase))
            {
                break;
            }

            current = current.Parent;
        }

        return null;
    }

    private static string? FindRepositoryRoot()
    {
        DirectoryInfo? current = new(Directory.GetCurrentDirectory());
        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, "AGENTS.md")) &&
                Directory.Exists(Path.Combine(current.FullName, "docs")) &&
                Directory.Exists(Path.Combine(current.FullName, "tools")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        return null;
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
        evidence.OutputWriteAttempted = true;
        evidence.OutputWriteCompleted = true;
        evidence.SafetyCounters.OutputWriteAttempted = 1;
        evidence.SafetyCounters.OutputWriteCompleted = 1;
        JsonSerializerOptions jsonOptions = new()
        {
            WriteIndented = true
        };
        string json = JsonSerializer.Serialize(evidence, jsonOptions);
        using FileStream stream = new(outputPath, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        using StreamWriter writer = new(stream, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        writer.Write(json);
        writer.Write(Environment.NewLine);
    }

    private static void WriteFilePreflightRejectionDiagnostic(Evidence evidence)
    {
        evidence.Result = "FAIL";
        evidence.ResultCode = "FILE_PREFLIGHT_REJECTED";
        evidence.EvidenceTransport = "CONSOLE_PREFLIGHT_REJECTION";
        foreach (Defect defect in evidence.Defects)
        {
            Console.Error.WriteLine(defect.Code + ": " + defect.Message);
        }

        Console.Out.WriteLine(JsonSerializer.Serialize(evidence));
    }

    private static void WritePreflightOnlyDiagnostic(Evidence evidence)
    {
        evidence.Result = "PASS";
        evidence.ResultCode = evidence.ReviewScope == ParserReviewScope.RealArtifactStaticMetadataReview.Text
            ? "REAL_ARTIFACT_STATIC_REVIEW_PREFLIGHT_AUTHORIZED_NO_ARTIFACT_IO"
            : "STATIC_METADATA_PARSER_PREFLIGHT_AUTHORIZED_NO_ARTIFACT_IO";
        evidence.EvidenceTransport = "CONSOLE_PREFLIGHT_ONLY";
        evidence.Diagnostics.Add(Diagnostic.Info(
            "preflight-only",
            "Preflight-only mode completed authorization and path checks without input open/read/hash/parse or output write."));
        Console.Out.WriteLine(JsonSerializer.Serialize(evidence));
    }
}

internal sealed class RealArtifactAuthorizationContext
{
    public bool Authorized { get; private init; }
    public string Status { get; private init; } = "NOT_REQUESTED";
    public string FailureReason { get; private init; } = "REAL_ARTIFACT_REVIEW_SCOPE_NOT_REQUESTED";
    public string ManifestPath { get; private init; } = "";
    public string AcceptedArtifactRelativePath { get; private init; } = "";
    public string AcceptedArtifactPath { get; private init; } = "";
    public string AcceptedArtifactSha256 { get; private init; } = "";
    public long AcceptedArtifactSize { get; private init; }
    public string IdentitySource { get; private init; } = "";
    public bool GateMatched { get; private init; }
    public bool AcceptedParserAuditCommitMatched { get; private init; }
    public bool TransitionCommitMatched { get; private init; }
    public bool IdentityMatched { get; private init; }

    public static RealArtifactAuthorizationContext NotRequested() => new();

    public static RealArtifactAuthorizationContext Load(string repositoryRoot, ParserOptions options)
    {
        string manifestPath = string.IsNullOrWhiteSpace(options.AuthorizationManifestPath)
            ? Path.GetFullPath(Path.Combine(
                repositoryRoot,
                ProgramConstants.CanonicalReadinessManifestPath.Replace('/', Path.DirectorySeparatorChar)))
            : options.AuthorizationManifestPath;

        if (!string.IsNullOrWhiteSpace(options.AuthorizationManifestPath) &&
            (!options.PreflightOnly || !ProgramPaths.IsAllowedPreflightManifestFixturePath(repositoryRoot, manifestPath)))
        {
            return Fail(manifestPath, "AUTHORIZATION_MANIFEST_PATH_NOT_CANONICAL");
        }

        if (!File.Exists(manifestPath))
        {
            return Fail(manifestPath, "AUTHORIZATION_MANIFEST_MISSING");
        }

        string compileEvidencePath = Path.GetFullPath(Path.Combine(
            repositoryRoot,
            "docs/evidence/native-interop-compile-only-validation.json".Replace('/', Path.DirectorySeparatorChar)));
        if (!File.Exists(compileEvidencePath))
        {
            return Fail(manifestPath, "COMPILE_ONLY_EVIDENCE_MISSING");
        }

        if (!TryLoadJsonDocument(manifestPath, out JsonDocument? loadedManifest) || loadedManifest is null)
        {
            return Fail(manifestPath, "AUTHORIZATION_MANIFEST_MALFORMED");
        }

        using JsonDocument manifestDocument = loadedManifest;
        JsonElement manifest = manifestDocument.RootElement;
        if (manifest.ValueKind != JsonValueKind.Object ||
            GetString(manifest, "schema_version") != ProgramConstants.ReadinessManifestSchemaVersion)
        {
            return Fail(manifestPath, "AUTHORIZATION_MANIFEST_SCHEMA_MISMATCH");
        }

        if (!TryGetObject(manifest, "compiled_artifact_metadata_review_design_gate", out JsonElement metadataGate) ||
            !TryGetObject(metadataGate, "static_metadata_parser_implementation", out JsonElement parserImplementation) ||
            !TryGetObject(metadataGate, "static_metadata_parser_implementation_design", out JsonElement parserDesign) ||
            !TryGetObject(manifest, "repository", out JsonElement repository))
        {
            return Fail(manifestPath, "AUTHORIZATION_MANIFEST_MALFORMED");
        }

        bool gateMatched =
            GetString(manifest, "current_gate") == ProgramConstants.RealArtifactAuthorizationGate &&
            GetString(metadataGate, "current_gate") == ProgramConstants.RealArtifactAuthorizationGate &&
            GetString(parserImplementation, "current_gate") == ProgramConstants.RealArtifactAuthorizationGate &&
            GetString(manifest, "capability_blocker") == ProgramConstants.RuntimeBlocker &&
            GetString(metadataGate, "runtime_blocker") == ProgramConstants.RuntimeBlocker &&
            GetString(manifest, "live_installation_readiness") == "BLOCKED" &&
            GetString(manifest, "native_execution_status") == "NOT_IMPLEMENTED";

        bool acceptedParserMatched =
            GetString(parserImplementation, "status") == ProgramConstants.AcceptedParserImplementationStatus &&
            GetString(parserDesign, "parser_implementation_status") == ProgramConstants.AcceptedParserImplementationStatus &&
            GetString(parserImplementation, "independent_implementation_audit_commit") == ProgramConstants.AcceptedParserAuditCommit;

        bool notPerformedMatched =
            GetString(parserImplementation, "parser_execution_status") == "REAL_ARTIFACT_NOT_PERFORMED" &&
            GetString(parserImplementation, "metadata_review_status") == "NOT_PERFORMED" &&
            GetString(parserImplementation, "real_artifact_open_parse_hash_write_status") == "NOT_PERFORMED" &&
            GetString(parserDesign, "parser_execution_status") == "REAL_ARTIFACT_NOT_PERFORMED" &&
            GetString(parserDesign, "metadata_review_status") == "NOT_PERFORMED" &&
            GetString(parserDesign, "artifact_opening_status") == "NOT_PERFORMED" &&
            GetString(parserDesign, "artifact_parsing_status") == "NOT_PERFORMED" &&
            GetString(parserDesign, "artifact_hash_verification_status") == "NOT_PERFORMED" &&
            GetString(parserDesign, "artifact_write_status") == "NOT_PERFORMED";

        bool transitionMatched =
            GetString(parserImplementation, "real_artifact_review_authorization_transition_commit") == ProgramConstants.AcceptedReviewAuthorizationTransitionCommit ||
            GetString(parserDesign, "real_artifact_review_authorization_transition_commit") == ProgramConstants.AcceptedReviewAuthorizationTransitionCommit ||
            GetString(repository, "real_artifact_review_authorization_transition_commit") == ProgramConstants.AcceptedReviewAuthorizationTransitionCommit;

        if (!TryLoadJsonDocument(compileEvidencePath, out JsonDocument? loadedCompileEvidence) || loadedCompileEvidence is null)
        {
            return Fail(manifestPath, "COMPILE_ONLY_EVIDENCE_MALFORMED");
        }

        using JsonDocument compileDocument = loadedCompileEvidence;
        JsonElement compileEvidence = compileDocument.RootElement;
        if (compileEvidence.ValueKind != JsonValueKind.Object)
        {
            return Fail(manifestPath, "COMPILE_ONLY_EVIDENCE_MALFORMED");
        }

        string artifactRelative = FindAcceptedPrimaryArtifactRelativePath(compileEvidence);
        string artifactSha256 = FindAcceptedPrimaryArtifactSha256(compileEvidence);
        long artifactSize = FindAcceptedPrimaryArtifactSize(compileEvidence);
        bool identityMatched =
            !string.IsNullOrWhiteSpace(artifactRelative) &&
            artifactRelative.Replace('\\', '/').StartsWith(ProgramConstants.RealArtifactRelativeRoot + "/", StringComparison.OrdinalIgnoreCase) &&
            string.Equals(Path.GetFileName(artifactRelative), ProgramConstants.RealArtifactFileName, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(artifactSha256, GetString(parserDesign, "referenced_primary_dll_sha256"), StringComparison.OrdinalIgnoreCase) &&
            string.Equals(artifactSha256, "77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862", StringComparison.OrdinalIgnoreCase) &&
            artifactSize == 11264;

        string status = "AUTHORIZED";
        if (!gateMatched)
        {
            status = "MANIFEST_GATE_OR_BLOCKER_MISMATCH";
        }
        else if (!acceptedParserMatched)
        {
            status = "PARSER_IMPLEMENTATION_NOT_ACCEPTED";
        }
        else if (!notPerformedMatched)
        {
            status = "REAL_ARTIFACT_REVIEW_ALREADY_PERFORMED_OR_STATUS_MISMATCH";
        }
        else if (!transitionMatched)
        {
            status = "TRANSITION_COMMIT_NOT_RECORDED";
        }
        else if (!identityMatched)
        {
            status = "COMPILE_ONLY_ARTIFACT_IDENTITY_MISMATCH";
        }

        return new RealArtifactAuthorizationContext
        {
            Authorized = status == "AUTHORIZED",
            Status = status,
            FailureReason = status == "AUTHORIZED" ? "" : status,
            ManifestPath = manifestPath,
            AcceptedArtifactRelativePath = artifactRelative,
            AcceptedArtifactPath = string.IsNullOrWhiteSpace(artifactRelative) ? "" : Path.GetFullPath(Path.Combine(repositoryRoot, artifactRelative.Replace('/', Path.DirectorySeparatorChar))),
            AcceptedArtifactSha256 = artifactSha256,
            AcceptedArtifactSize = artifactSize,
            IdentitySource = "docs/evidence/native-interop-compile-only-validation.json",
            GateMatched = gateMatched,
            AcceptedParserAuditCommitMatched = acceptedParserMatched,
            TransitionCommitMatched = transitionMatched,
            IdentityMatched = identityMatched
        };
    }

    private static RealArtifactAuthorizationContext Fail(string manifestPath, string reason) => new()
    {
        Authorized = false,
        Status = reason,
        FailureReason = reason,
        ManifestPath = manifestPath
    };

    private static bool TryLoadJsonDocument(string path, out JsonDocument? document)
    {
        try
        {
            document = JsonDocument.Parse(File.ReadAllText(path));
            return true;
        }
        catch (Exception ex) when (ex is JsonException or IOException or UnauthorizedAccessException)
        {
            document = null;
            return false;
        }
    }

    private static bool TryGetObject(JsonElement parent, string propertyName, out JsonElement child)
    {
        if (parent.ValueKind == JsonValueKind.Object &&
            parent.TryGetProperty(propertyName, out child) &&
            child.ValueKind == JsonValueKind.Object)
        {
            return true;
        }

        child = default;
        return false;
    }

    private static JsonElement GetObject(JsonElement parent, string propertyName) =>
        TryGetObject(parent, propertyName, out JsonElement child) ? child : default;

    private static string GetString(JsonElement parent, string propertyName) =>
        parent.ValueKind == JsonValueKind.Object &&
        parent.TryGetProperty(propertyName, out JsonElement value) &&
        value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? ""
            : "";

    private static string FindAcceptedPrimaryArtifactRelativePath(JsonElement compileEvidence)
    {
        foreach (JsonElement file in EnumerateProducedFiles(compileEvidence))
        {
            string relative = GetString(file, "relative_path").Replace('\\', '/');
            if (relative.Contains("/bin/Release/x64/net9.0-windows10.0.26100.0/", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Path.GetFileName(relative), ProgramConstants.RealArtifactFileName, StringComparison.OrdinalIgnoreCase))
            {
                return relative;
            }
        }

        return "";
    }

    private static string FindAcceptedPrimaryArtifactSha256(JsonElement compileEvidence)
    {
        foreach (JsonElement file in EnumerateProducedFiles(compileEvidence))
        {
            string relative = GetString(file, "relative_path").Replace('\\', '/');
            if (relative.Contains("/bin/Release/x64/net9.0-windows10.0.26100.0/", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Path.GetFileName(relative), ProgramConstants.RealArtifactFileName, StringComparison.OrdinalIgnoreCase))
            {
                return GetString(file, "sha256");
            }
        }

        return "";
    }

    private static long FindAcceptedPrimaryArtifactSize(JsonElement compileEvidence)
    {
        foreach (JsonElement file in EnumerateProducedFiles(compileEvidence))
        {
            string relative = GetString(file, "relative_path").Replace('\\', '/');
            if (relative.Contains("/bin/Release/x64/net9.0-windows10.0.26100.0/", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Path.GetFileName(relative), ProgramConstants.RealArtifactFileName, StringComparison.OrdinalIgnoreCase) &&
                file.TryGetProperty("byte_size", out JsonElement size) &&
                size.TryGetInt64(out long value))
            {
                return value;
            }
        }

        return 0;
    }

    private static IEnumerable<JsonElement> EnumerateProducedFiles(JsonElement compileEvidence)
    {
        JsonElement buildResult = GetObject(compileEvidence, "build_result");
        if (buildResult.ValueKind != JsonValueKind.Object ||
            !buildResult.TryGetProperty("produced_files", out JsonElement files) ||
            files.ValueKind != JsonValueKind.Array)
        {
            yield break;
        }

        foreach (JsonElement file in files.EnumerateArray())
        {
            yield return file;
        }
    }
}

internal static class ProgramConstants
{
    public const string RealArtifactAuthorizationGate = "BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION";
    public const string RuntimeBlocker = "BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED";
    public const string AcceptedParserImplementationStatus = "ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED";
    public const string AcceptedParserAuditCommit = "f0be4746ad4cc548334336c1e66f07007b71859f";
    public const string AcceptedReviewAuthorizationTransitionCommit = "baab23aece902cbb06e11a308d9092fdc0f9ce0d";
    public const string ReadinessManifestSchemaVersion = "chatpad-runtime-bringup-readiness-manifest-v4";
    public const string CanonicalReadinessManifestPath = "docs/evidence/runtime-bringup-readiness-manifest.json";
    public const string RealArtifactRelativeRoot = "artifacts/compile-only/native-interop";
    public const string RealArtifactFileName = "Chatpad.NativeInterop.CompileOnlyValidation.dll";
}

internal static class ProgramPaths
{
    private const string IndependentAuthorizationAuditPrefix =
        "independent-static-parser-real-artifact-authorization-plumbing-audit-";
    private const string IndependentAuthorizationRemediationPrefix =
        "independent-static-parser-real-artifact-authorization-plumbing-remediation-";
    private const string IndependentAuthorizationRemediationAuditPrefix =
        "independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-";

    public static bool IsAllowedPreflightManifestFixturePath(string repositoryRoot, string manifestPath) =>
        InvokeIsAllowedPreflightManifestFixturePath(repositoryRoot, manifestPath);

    public static bool IsApprovedParserRootSegment(string segment) =>
        segment.StartsWith("static-metadata-parser-", StringComparison.OrdinalIgnoreCase) ||
        segment.StartsWith("independent-static-metadata-parser-", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(segment, "static-parser-status-boundary-remediation", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(segment, "static-parser-real-artifact-authorization-plumbing", StringComparison.OrdinalIgnoreCase) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationAuditPrefix) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationRemediationPrefix) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationRemediationAuditPrefix);

    private static bool InvokeIsAllowedPreflightManifestFixturePath(string repositoryRoot, string manifestPath)
    {
        string logsRoot = Path.GetFullPath(Path.Combine(repositoryRoot, "artifacts", "logs"));
        string candidate = Path.GetFullPath(manifestPath);
        string relative = Path.GetRelativePath(logsRoot, candidate);
        string[] segments = relative.Split(
            new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar },
            StringSplitOptions.RemoveEmptyEntries);
        return segments.Length >= 2 &&
            segments.All(segment => segment is not "." and not "..") &&
            IsApprovedAuthorizationManifestRootSegment(segments[0]) &&
            string.Equals(Path.GetExtension(manifestPath), ".json", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsApprovedAuthorizationManifestRootSegment(string segment) =>
        string.Equals(segment, "static-parser-status-boundary-remediation", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(segment, "static-parser-real-artifact-authorization-plumbing", StringComparison.OrdinalIgnoreCase) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationAuditPrefix) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationRemediationPrefix) ||
        HasCanonicalHexSuffix(segment, IndependentAuthorizationRemediationAuditPrefix);

    private static bool HasCanonicalHexSuffix(string segment, string prefix)
    {
        if (!segment.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        string suffix = segment[prefix.Length..];
        return suffix.Length is >= 7 and <= 40 && suffix.All(Uri.IsHexDigit);
    }
}

internal sealed class ParserOptions
{
    public required string OriginalInputPath { get; init; }
    public required string InputPath { get; init; }
    public required string OriginalOutputPath { get; init; }
    public required string OutputPath { get; init; }
    public string OriginalExpectedPath { get; init; } = "";
    public string ExpectedPath { get; init; } = "";
    public string ParserSourceCommit { get; init; } = "UNKNOWN";
    public string ParserBuildIdentity { get; init; } = "UNKNOWN";
    public ParserReviewScope ReviewScope { get; init; } = ParserReviewScope.SyntheticFixtures;
    public bool PreflightOnly { get; init; }
    public string AuthorizationManifestPath { get; init; } = "";
    public List<string> SafetyPolicyOptions { get; init; } = [];

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
                case "--review-scope":
                case "--authorization-manifest":
                    if (i + 1 >= args.Length)
                    {
                        throw new ArgumentException("Missing value for " + arg);
                    }

                    values[arg] = args[++i];
                    break;
                case "--preflight-only":
                    flags.Add(arg);
                    break;
                case "--no-load":
                case "--no-reflection":
                case "--no-execute":
                case "--no-native-invoke":
                case "--no-device-query":
                case "--no-windows-mutation":
                case "--no-driver-action":
                case "--allow-load":
                case "--allow-reflection":
                case "--allow-execute":
                case "--allow-native-invoke":
                case "--allow-device-query":
                case "--allow-windows-mutation":
                case "--allow-driver-action":
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

        ParserReviewScope reviewScope = ParserReviewScope.Parse(
            values.TryGetValue("--review-scope", out string? scope) ? scope : "synthetic-fixtures");

        return new ParserOptions
        {
            OriginalInputPath = input,
            InputPath = Path.GetFullPath(input),
            OriginalOutputPath = output,
            OutputPath = Path.GetFullPath(output),
            OriginalExpectedPath = values.TryGetValue("--expected", out string? originalExpected) ? originalExpected : "",
            ExpectedPath = values.TryGetValue("--expected", out string? expected) ? Path.GetFullPath(expected) : "",
            ParserSourceCommit = values.TryGetValue("--parser-source-commit", out string? commit) ? commit : "UNKNOWN",
            ParserBuildIdentity = values.TryGetValue("--parser-build-identity", out string? identity) ? identity : "UNKNOWN",
            ReviewScope = reviewScope,
            PreflightOnly = flags.Contains("--preflight-only"),
            AuthorizationManifestPath = values.TryGetValue("--authorization-manifest", out string? manifest) ? Path.GetFullPath(manifest) : "",
            SafetyPolicyOptions = flags.Where(item => item != "--preflight-only").OrderBy(item => item, StringComparer.Ordinal).ToList()
        };
    }
}

internal sealed record ParserReviewScope(string Text)
{
    public static readonly ParserReviewScope SyntheticFixtures = new("synthetic-fixtures");
    public static readonly ParserReviewScope RealArtifactStaticMetadataReview = new("real-artifact-static-metadata-review");

    public static ParserReviewScope Parse(string value)
    {
        if (string.Equals(value, SyntheticFixtures.Text, StringComparison.Ordinal))
        {
            return SyntheticFixtures;
        }

        if (string.Equals(value, RealArtifactStaticMetadataReview.Text, StringComparison.Ordinal))
        {
            return RealArtifactStaticMetadataReview;
        }

        throw new ArgumentException("Unsupported review scope: " + value);
    }
}

internal sealed class ExpectedMetadata
{
    public string InputIdentitySource { get; private init; } = "SYNTHETIC_FIXTURE";
    public bool RequireNoEntryPoint { get; private init; } = true;
    public List<ExpectedDeclaration> ExpectedDeclarations { get; } = [];

    public static ExpectedMetadata Load(string path, Evidence evidence)
    {
        byte[] bytes = File.ReadAllBytes(path);
        evidence.ExpectedBytesRead = true;
        evidence.SafetyCounters.ExpectedBytesRead = 1;
        using JsonDocument document = JsonDocument.Parse(bytes);
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

internal sealed record PathScopeDecision(
    string Role,
    string OriginalPath,
    string NormalizedPath,
    string Decision,
    string Reason)
{
    public static PathScopeDecision Allowed(string role, string originalPath, string normalizedPath, string reason) =>
        new(role, originalPath, normalizedPath, "ALLOWED", reason);

    public static PathScopeDecision Rejected(string role, string originalPath, string normalizedPath, string reason) =>
        new(role, originalPath, normalizedPath, "REJECTED", reason);

    public static PathScopeDecision NotProvided(string role) =>
        new(role, "", "", "NOT_PROVIDED", "OPTION_NOT_PROVIDED");

    public static PathScopeDecision NotEvaluated(string role) =>
        new(role, "", "", "NOT_EVALUATED", "");
}

internal sealed class Evidence
{
    public string SchemaVersion { get; init; } = ProgramEvidence.SchemaVersion;
    public string GeneratedUtc { get; init; } = DateTimeOffset.UtcNow.ToString("o", CultureInfo.InvariantCulture);
    public string Result { get; set; } = "FAIL";
    public string ResultCode { get; set; } = "NOT_EVALUATED";
    public string EvidenceTransport { get; set; } = "OUTPUT_FILE";
    public string ParserToolName { get; init; } = ProgramEvidence.ToolName;
    public string ParserToolVersion { get; init; } = ProgramEvidence.ToolVersion;
    public string ParserSourceCommit { get; init; } = "";
    public string ParserBuildIdentity { get; init; } = "";
    public string ParserTargetFramework { get; init; } = "net9.0";
    public string SystemReflectionMetadataVersion { get; init; } = typeof(PEReader).Assembly.GetName().Version?.ToString() ?? "";
    public string CurrentGate { get; set; } = "";
    public string ReviewScope { get; set; } = "synthetic-fixtures";
    public bool PreflightOnly { get; set; }
    public string SafetyPolicyMode { get; init; } = "IMMUTABLE_STATIC_ONLY";
    public bool SafetyPolicyEnforced { get; init; } = true;
    public string AllowedInputScope { get; set; } = "";
    public string AllowedExpectedScope { get; set; } = "";
    public string AllowedOutputScope { get; set; } = "";
    public string RepositoryRoot { get; set; } = "";
    public string AuthorizationManifestPath { get; set; } = "";
    public string RealArtifactAuthorizationStatus { get; set; } = "NOT_REQUESTED";
    public string RealArtifactAuthorizationReason { get; set; } = "";
    public bool RealArtifactAuthorizationGateMatched { get; set; }
    public bool RealArtifactAcceptedParserAuditCommitMatched { get; set; }
    public bool RealArtifactTransitionCommitMatched { get; set; }
    public bool RealArtifactIdentityMatched { get; set; }
    public string RealArtifactExpectedRelativePath { get; set; } = "";
    public string RealArtifactExpectedSha256 { get; set; } = "";
    public long RealArtifactExpectedSize { get; set; }
    public string RealArtifactExpectedIdentitySource { get; set; } = "";
    public string InputPath { get; init; } = "";
    public string OriginalInputPath { get; set; } = "";
    public string InputNormalizedPath { get; set; } = "";
    public PathScopeDecision InputPathDecision { get; set; } = PathScopeDecision.NotEvaluated("input");
    public PathScopeDecision ExpectedPathDecision { get; set; } = PathScopeDecision.NotEvaluated("expected");
    public PathScopeDecision OutputPathDecision { get; set; } = PathScopeDecision.NotEvaluated("output");
    public string InputScopeDecision { get; set; } = "NOT_EVALUATED";
    public string InputScopeReason { get; set; } = "";
    public string InputClassification { get; set; } = "NOT_CLASSIFIED";
    public long InputSize { get; set; }
    public string InputSha256 { get; set; } = "";
    public string InputIdentitySource { get; set; } = "SYNTHETIC_FIXTURE";
    public bool MetadataParsed { get; set; }
    public bool ArtifactBytesRead { get; set; }
    public bool ArtifactHashComputed { get; set; }
    public bool ExpectedBytesRead { get; set; }
    public bool ExpectedHashComputed { get; set; }
    public bool OutputWriteAttempted { get; set; }
    public bool OutputWriteCompleted { get; set; }
    public bool PeParseAttempted { get; set; }
    public bool MetadataParseAttempted { get; set; }
    public string MetadataReviewStatus { get; init; } = "NOT_PERFORMED";
    public string RealArtifactOpenStatus { get; init; } = "NOT_PERFORMED";
    public string RealArtifactParseStatus { get; init; } = "NOT_PERFORMED";
    public string RealArtifactHashStatus { get; init; } = "NOT_PERFORMED";
    public string RealArtifactWriteStatus { get; init; } = "NOT_PERFORMED";
    public bool StaticOnly => SafetyPolicyEnforced &&
        NoLoadGuarantee &&
        NoRuntimeReflectionGuarantee &&
        NoExecutionGuarantee &&
        NoNativeInvocationGuarantee &&
        NoDeviceQueryGuarantee &&
        NoWindowsMutationGuarantee &&
        !DriverActionsOccurred;
    public bool NoLoadGuarantee => SafetyPolicyEnforced && SafetyCounters.AssemblyLoad == 0;
    public bool NoRuntimeReflectionGuarantee => SafetyPolicyEnforced && SafetyCounters.RuntimeReflection == 0;
    public bool NoExecutionGuarantee => SafetyPolicyEnforced && SafetyCounters.CompiledArtifactExecution == 0;
    public bool NoNativeInvocationGuarantee => SafetyPolicyEnforced &&
        SafetyCounters.NativeDllLoad == 0 &&
        SafetyCounters.EntryPointResolution == 0 &&
        SafetyCounters.NativeInvocation == 0 &&
        SafetyCounters.SetupApiNewdevInvocation == 0;
    public bool NoDeviceQueryGuarantee => SafetyPolicyEnforced &&
        SafetyCounters.DeviceQuery == 0 &&
        SafetyCounters.HardwareAccess == 0;
    public bool NoWindowsMutationGuarantee => SafetyPolicyEnforced && SafetyCounters.WindowsMutation == 0;
    public bool AssemblyLoadOccurred => SafetyCounters.AssemblyLoad != 0;
    public bool RuntimeReflectionOccurred => SafetyCounters.RuntimeReflection != 0;
    public bool CompiledArtifactExecutionOccurred => SafetyCounters.CompiledArtifactExecution != 0;
    public bool NativeDllLoadOccurred => SafetyCounters.NativeDllLoad != 0;
    public bool EntryPointResolutionOccurred => SafetyCounters.EntryPointResolution != 0;
    public bool NativeInvocationOccurred => SafetyCounters.NativeInvocation != 0;
    public bool SetupApiNewdevInvocationOccurred => SafetyCounters.SetupApiNewdevInvocation != 0;
    public bool DeviceQueryOccurred => SafetyCounters.DeviceQuery != 0;
    public bool HardwareAccessOccurred => SafetyCounters.HardwareAccess != 0;
    public bool WindowsMutationOccurred => SafetyCounters.WindowsMutation != 0;
    public bool DriverActionsOccurred => SafetyCounters.DriverBuild != 0 ||
        SafetyCounters.DriverLink != 0 ||
        SafetyCounters.DriverSign != 0 ||
        SafetyCounters.DriverCatGeneration != 0 ||
        SafetyCounters.DriverPackage != 0 ||
        SafetyCounters.DriverStage != 0 ||
        SafetyCounters.DriverInstall != 0 ||
        SafetyCounters.DriverLoad != 0 ||
        SafetyCounters.DriverUnload != 0 ||
        SafetyCounters.DriverBind != 0 ||
        SafetyCounters.DriverRestore != 0 ||
        SafetyCounters.DriverRestart != 0;
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
        InputPath = options.InputPath,
        OriginalInputPath = options.OriginalInputPath
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
    public int ExpectedBytesRead { get; set; }
    public int ExpectedHashComputed { get; set; }
    public int OutputWriteAttempted { get; set; }
    public int OutputWriteCompleted { get; set; }
    public int PeParseAttempted { get; set; }
    public int MetadataParseAttempted { get; set; }
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
