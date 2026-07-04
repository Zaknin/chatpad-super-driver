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
- `inputPath`, `inputClassification`, `inputSize`, `inputSha256`, and
  `inputIdentitySource`.
- `metadataParsed`, `artifactBytesRead`, `artifactHashComputed`, and
  `staticOnly`.
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

Parser output is fail-closed. Missing input, invalid PE bytes, missing CLI
metadata, executable entry points, unexpected P/Invoke declarations, malformed
expectation files, unsupported output paths, and unsafe options produce
`result: FAIL` with defect records. Any nonzero prohibited-action counter is a
defect for audit acceptance.

For this implementation task, nonzero `artifactBytesRead`,
`artifactHashComputed`, and `metadataParsed` counters are allowed only for
synthetic fixtures created under ignored parser artifact roots. The real
compile-only native interop artifact remains unopened, unparsed, unhashed, and
unreviewed.
