# Static Metadata Parser Evidence Schema v1

Schema identifier: `chatpad-static-metadata-parser-evidence-v1`.

This schema is emitted by `Chatpad.StaticMetadataParser`, the isolated .NET 9
static PE/CLI metadata parser under `tools/StaticMetadataParser/`. Evidence is
valid for the implementation task only when generated from synthetic fixture
inputs. It is not metadata review evidence for the real compile-only native
interop artifact.

Required evidence fields:

- `schemaVersion`, `generatedUtc`, `result`, and `resultCode`.
- `parserToolName`, `parserToolVersion`, `parserSourceCommit`,
  `parserBuildIdentity`, `parserTargetFramework`, and
  `systemReflectionMetadataVersion`.
- `currentGate`, `safetyPolicyMode`, `safetyPolicyEnforced`,
  `allowedInputScope`, `repositoryRoot`, `inputPath`, `inputNormalizedPath`,
  `inputScopeDecision`, `inputScopeReason`, `inputClassification`,
  `inputSize`, `inputSha256`, and `inputIdentitySource`.
- `metadataParsed`, `artifactBytesRead`, `artifactHashComputed`, and
  `staticOnly`.
- `metadataReviewStatus`, `realArtifactOpenStatus`,
  `realArtifactParseStatus`, and `realArtifactHashStatus`.
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

Parser output is fail-closed. Under
`BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`, input is limited
to parser-specific synthetic fixture roots under ignored `artifacts/logs/`
paths. Real-artifact-like paths, the real compile-only output DLL name,
paths under `artifacts/compile-only/native-interop`, relative traversal into a
blocked root, paths outside the synthetic fixture scope, reparse points,
missing input, invalid PE bytes, missing CLI metadata, executable entry
points, unexpected P/Invoke declarations, malformed expectation files,
unsupported output paths, and unsupported safety options produce `result: FAIL`
with defect records. Real-artifact-like and safety-policy rejections occur
before file read, hash computation, PE parsing, or metadata parsing.

Safety policy is immutable static-only. Safety options are not user-controlled;
attempted safety options such as legacy `--no-load` or contradictory
`--allow-*` options are rejected before input read. Any nonzero
prohibited-action counter is a defect for audit acceptance.
Safety guarantee and occurrence booleans are computed from the enforced policy
and their corresponding counters; they are not independent constant claims.

For this implementation task, nonzero `artifactBytesRead`,
`artifactHashComputed`, and `metadataParsed` counters are allowed only for
synthetic fixtures created under ignored parser artifact roots. The real
compile-only native interop artifact remains unopened, unparsed, unhashed, and
unreviewed.
