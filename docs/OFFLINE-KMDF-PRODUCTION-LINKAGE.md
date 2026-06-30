# Offline KMDF Production Linkage Checkpoint

This checkpoint records the project-linkage-only production integration of the
dormant KMDF activation request-owner static library into `ChatpadFilter`.

## Scope

The checkpoint proves only that `ChatpadFilter` has a native build dependency
on the existing `ChatpadKmdfRequestOwnerContext` static-library project and
that an otherwise unused request-owner static library can be present in the
link inputs without changing the final driver image behavior.

It does not prove header compatibility in production source, owner embedding,
ordinary owner initialization, dormant orchestration invocation, WDF object
creation or deletion, target discovery, request formatting, request reuse,
request submission, completion, cancellation, D0 or removal rundown, signing,
packaging, staging, installation, loading, hardware visibility, Chatpad input,
or a usable driver.

## Starting and branch state

- Starting branch: `feature/offline-kmdf-production-integration-design`.
- Starting commit: `033bd4fb4deff662ee9e3c2144d10decd27c8a03`.
- Starting parent: `39b2356c9193ea33d10d5c689e565a88a2e586c3`.
- Starting subject: `docs: define kmdf production integration`.
- New branch: `feature/offline-kmdf-production-linkage`.

## Project-reference implementation

`src/driver/ChatpadFilter/ChatpadFilter.vcxproj` now contains exactly one
request-owner context dependency:

```xml
<ProjectReference Include="..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj">
  <Project>{421C7E3A-5B02-4D07-A37D-4B45D3755694}</Project>
  <GlobalPropertiesToRemove>OutDir;IntDir</GlobalPropertiesToRemove>
  <AdditionalProperties>OutDir=$(RepoRoot)\artifacts\bin\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\;IntDir=$(RepoRoot)\artifacts\obj\$(Platform)\$(Configuration)\ChatpadKmdfRequestOwnerContext\</AdditionalProperties>
</ProjectReference>
```

No solution-file change was required. The static-library project was already
present in `ChatpadWin11.sln` for Debug and Release x64, and the native
project reference provides the build-order and linker-input evidence.

The `GlobalPropertiesToRemove` and `AdditionalProperties` metadata are both
intentional. Normal MSBuild project-reference evaluation respects
`GlobalPropertiesToRemove`, while the WDK driver-packaging reference pass uses
the referenced item's `AdditionalProperties`. Without the explicit dependency
output directories, the WDK pass rebuilt the context library under the
`ChatpadFilter` output/intermediate roots and emitted `MSB8028`; that evidence
was rejected.

## Production boundary

No production `.c` or `.h` source was changed. `ChatpadFilter` still does not
include `ChatpadKmdfRequestOwnerContext.h`, does not embed
`ChatpadKmdfActivationRequestOwner`, does not initialize owner storage, does
not call the dormant orchestration helper, and does not create, delete, format,
send, complete, cancel, or reuse any request-owner WDF object.

No `/INCLUDE` or `/WHOLEARCHIVE` directive was added for request-owner symbols.
The only retained forced symbol remains the pre-existing
`/INCLUDE:ChatpadPrepareActivationStep`.

## Link-input evidence

Final full-solution linker tlogs show the generated context-library artifact
as a link input:

- Debug:
  `artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`.
- Release:
  `artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`.

`ChatpadKmdfRequestOwnerContext.lib` appears twice in each
`link.command.1.tlog` because the tlog records both the source dependency line
and the link command input. The tlogs contain zero request-owner
`/INCLUDE`, `/WHOLEARCHIVE`, or `/FORCE` matches.

## Binary evidence

Post-full-solution `tools\Test-ChatpadProductionLinkage.ps1` passed in Debug
and Release. It inspects project XML, active production source text, the final
driver imports, and the final driver symbol table.

Final driver images:

- Debug:
  `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`, 15,872 bytes,
  SHA-256
  `198DD46B310A041EC40C6A4B5CE97A3B851DDD95CD300D167B929103580929D2`,
  Authenticode `NotSigned`.
- Release:
  `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`, 12,288 bytes,
  SHA-256
  `040ACC31C1464320037D957777A1C092FD2030D4F2EAE0D10397016CF00F3445`,
  Authenticode `NotSigned`.

Final context libraries from full-solution validation:

- Debug:
  `artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256
  `8FCE8EB6F648ED555C22143642B4E035957E524F84422990BBC6CED053BEA72E`.
- Release:
  `artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256
  `CC4730A4A402079A7EA3557DEADC1E69F626F5C5892AD3FC7031308EEA234DAE`.

The final driver contains no retained `ChatpadKmdfRequestOwner`,
`ChatpadKmdfActivationRequest`, or `CreateDormantObjectGraph` symbol strings
and imports none of `WdfSpinLockCreate`, `WdfRequestCreate`,
`WdfMemoryCreatePreallocated`, or `WdfObjectDelete`.

## Validation results

Final validation passed:

- Repository safety before implementation and after driver builds.
- `tools\Test-ChatpadKmdfRequestOwnerContext.ps1`: Debug and Release PASS.
- `tools\Build-Driver.ps1`: Debug and Release PASS.
- `tools\Test-ChatpadProductionLinkage.ps1`: Debug and Release PASS after the
  full-solution builds.
- Full solution: Debug and Release PASS, `0 Warning(s)`, `0 Error(s)`.
- Request-owner model: Debug and Release `5002/5002`.
- Protocol: Debug and Release `610/610`.
- Transport: Debug and Release `186/186`.
- Filter lifecycle: Debug and Release `109/109`.
- Control setup: Debug and Release `141/141`.
- Protocol kernel compatibility: Debug and Release PASS.
- WDF control setup: Debug and Release PASS.

Evidence manifest:
`docs/evidence/production-linkage-manifest.json`.

The manifest's retained-evidence fields were completed by the
[Offline Production Linkage Evidence Correction](OFFLINE-PRODUCTION-LINKAGE-EVIDENCE-CORRECTION.md).
That correction adds exact command names and hash-bound paths without changing
the linkage implementation or rerunning builds and regression suites.

## Known limitations

The semantic guard uses targeted XML, text, import, and symbol checks. It
cannot prove all C macro expansion paths or all linker extraction internals by
itself. The checkpoint relies on the paired MSBuild logs, linker tlogs,
`dumpbin` import/symbol inspection, regression suite, and complete diff review
for the proof boundary.

The next safe task is an independent read-only audit of the corrected evidence
manifest before any owner embedding or ordinary initialization.
