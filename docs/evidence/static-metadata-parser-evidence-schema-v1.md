# Static Metadata Parser Evidence Schema v1

Schema identifier: `chatpad-static-metadata-parser-evidence-v1`.

This schema is emitted by `Chatpad.StaticMetadataParser`, the isolated .NET 9
static PE/CLI metadata parser under `tools/StaticMetadataParser/`. Evidence is
valid for the implementation task only when generated from synthetic fixture
inputs. It is not metadata review evidence for the real compile-only native
interop artifact.

Required evidence fields:

- `schemaVersion`, `generatedUtc`, `result`, `resultCode`, and
  `evidenceTransport`.
- `parserToolName`, `parserToolVersion`, `parserSourceCommit`,
  `parserBuildIdentity`, `parserTargetFramework`, and
  `systemReflectionMetadataVersion`.
- `currentGate`, `safetyPolicyMode`, `safetyPolicyEnforced`,
  `allowedInputScope`, `repositoryRoot`, `inputPath`, `inputNormalizedPath`,
  `inputPathDecision`, `expectedPathDecision`, `outputPathDecision`,
  `inputScopeDecision`, `inputScopeReason`, `inputClassification`,
  `inputSize`, `inputSha256`, and `inputIdentitySource`.
- `metadataParsed`, `artifactBytesRead`, `artifactHashComputed`,
  `expectedBytesRead`, `expectedHashComputed`, `outputWriteAttempted`,
  `outputWriteCompleted`, `peParseAttempted`, `metadataParseAttempted`, and
  `staticOnly`.
- `metadataReviewStatus`, `realArtifactOpenStatus`,
  `realArtifactParseStatus`, `realArtifactHashStatus`, and
  `realArtifactWriteStatus`.
- `noLoadGuarantee`, `noRuntimeReflectionGuarantee`, `noExecutionGuarantee`,
  `noNativeInvocationGuarantee`, `noDeviceQueryGuarantee`, and
  `noWindowsMutationGuarantee`.
- `assemblyLoadOccurred`, `runtimeReflectionOccurred`,
  `compiledArtifactExecutionOccurred`, `nativeDllLoadOccurred`,
  `entryPointResolutionOccurred`, `nativeInvocationOccurred`,
  `setupApiNewdevInvocationOccurred`, `deviceQueryOccurred`,
  `hardwareAccessOccurred`, `windowsMutationOccurred`, and
  `driverActionsOccurred`.
- `peCliSummary`, `assemblyIdentity`, `artifactTargetFramework`,
  `typeDefinitions`, `methodDefinitions`, and `pInvokeSummary`.
- `expectedDeclarationCount`, `actualDeclarationCount`, `expectedModules`,
  `actualModules`, `declarationChecks`, `diagnostics`, `defects`, and
  `safetyCounters`.

Parser file access is fail-closed. Under
`BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`, one central
preflight classifies every file-bearing option before caller-selected file I/O:

- `--input` and `--expected` are read paths limited to parser-specific
  synthetic `fixtures/` roots under ignored `artifacts/logs/`;
- `--output` is a write path limited to parser-specific ignored evidence
  roots under `artifacts/logs/`;
- output may not equal either read path, target an existing file, pass through
  a reparse point, use alternate-data-stream syntax, resolve outside the
  evidence root, or contain the protected compile-only DLL name;
- evidence output uses create-new semantics and never overwrites an existing
  file.

The second independent implementation audit failed because the prior
remediation gated only `--input`: `--expected` could reach `File.OpenRead`, and
`--output` could write outside parser evidence roots. The file-scope
remediation rejects those channels with
`PARSER_EXPECTED_PATH.NOT_AUTHORIZED` or
`PARSER_OUTPUT_PATH.NOT_AUTHORIZED` before input read, expectation read,
hashing, PE parsing, metadata parsing, or an unsafe output write. When output
itself is unsafe, no rejection evidence is written to that requested path.

The third independent implementation audit found that rejected `--input` and
`--expected` paths still caused the parser to write an authorized evidence
file. File preflight is now an all-or-nothing boundary: if any file-bearing
path decision is `REJECTED`, the parser exits with code `64`, writes no
`--output` file, and emits a structured console diagnostic with
`evidenceTransport = CONSOLE_PREFLIGHT_REJECTION`. That diagnostic records
zero input/expectation reads, hashes, PE/metadata parsing, and output-write
attempt/completion counters. The validation harness captures the command,
exit code, defect code, console diagnostic, and absence of the requested
output in its aggregate ignored test evidence. Successful synthetic fixture
runs continue to use `evidenceTransport = OUTPUT_FILE` and create-new output.

Safety policy is immutable static-only. Safety options are not user-controlled;
attempted safety options such as legacy `--no-load` or contradictory
`--allow-*` options are rejected before input read. Any nonzero
prohibited-action counter is a defect for audit acceptance.
Safety guarantee and occurrence booleans are computed from the enforced policy
and their corresponding counters; they are not independent constant claims.

For this implementation task, nonzero input/expectation read, input hash,
PE/metadata parse, and approved output-write counters are allowed only for
synthetic fixtures and parser evidence under ignored parser artifact roots.
Every rejected file-bearing path test keeps all read/hash/parse/write counters
at zero and creates no parser output file. Approved synthetic success cases
may write parser evidence only below approved parser-specific ignored roots.
Manifest evidence-path policy accepts both standard parser-remediation roots
and parser-specific independent-audit roots under `artifacts/logs/`, while
rejecting non-parser, compile-only, protected-name, metadata-review,
production, tracked, and legacy paths. The real compile-only native interop
artifact remains unopened, unparsed, unhashed, unwritten, and unreviewed.
