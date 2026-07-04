# Compiled-artifact metadata review design gate

## Status

- Compile-only evidence remediation: accepted by independent `AUDIT PASS`.
- Metadata-review design-gate remediation: accepted by independent `AUDIT PASS`
  at `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`.
- Active gate:
  `BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_IMPLEMENTATION_AUTHORIZATION`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Metadata-review implementation: not authorized and not implemented.
- Accepted remediation: strict JSON Boolean safety validation covers 63
  metadata-review fields and rejects numeric `0`/`1` and other non-Boolean
  types under both supported PowerShell runtimes.

The compiled managed artifact exists only as ignored compile-only output. This
phase defines a future static review contract; it does not open, parse, load,
reflect over, execute, or invoke the artifact.

## Existing tooling classification

| Finding | Classification | Decision |
| --- | --- | --- |
| `System.Reflection.Metadata`, `PEReader`, `MetadataReader` | Not present | No safe repository-native managed metadata parser exists. |
| ILDasm, ILSpy/`ilspycmd`, dnlib, Mono.Cecil | Not present | No approved external static managed metadata path exists. |
| `dumpbin` scripts and documentation | Irrelevant | Existing uses inspect production native driver/object evidence, not managed CLI metadata. |
| `Add-Type` in exact-instance contracts | Unsafe for this purpose | It must never receive or compile the artifact; it is unrelated runtime support. |
| `Assembly.Load*`, reflection, `dotnet exec`, native loaders, entry-point resolution | Unsafe | Prohibited. No approved artifact-review implementation uses them. |
| Existing source and compile-only pattern checks | Test/guard only | They enforce absence of prohibited paths; they do not inspect metadata. |
| Existing design and evidence text | Documentation only | It does not authorize review execution. |

No existing tool qualifies as a safe static file-parsing candidate for the
compiled managed artifact. The project therefore stops at this design gate.

## Future review contract

A separately authorized implementation may read the artifact as bytes and use
a parser that treats PE and CLI metadata as inert file data. It must bind the
input to the current schema v2 compile-only evidence primary DLL SHA-256 and
require the input path to remain under an ignored compile-only or audit root.
It may report only:

- PE header basic identity, module kind, and platform architecture;
- managed metadata table presence;
- assembly identity and target-framework metadata;
- entry-point absence;
- P/Invoke declaration count and DllImport target names as metadata strings;
- expected declaration type and method names;
- absence of post-build or run hooks in the compile-only project;
- absence of native invocation in validation scripts.

The implementation must fail closed on an unknown parser, hash mismatch,
non-ignored path, malformed PE/CLI metadata, executable entry point, unexpected
DLL target, unexpected declaration inventory, or any request outside this
allowlist. Evidence must record parser identity, input path/hash, checks,
defects, and zero prohibited-action counters.

## Manifest safety contract

All metadata-review safety fields in
`compiled_artifact_metadata_review_design_gate` are type-sensitive JSON
Booleans. The validator must reject missing, null, numeric, string,
empty-string, array, and object values before any Boolean coercion. Field-level
defects must identify the exact manifest path, expected type, actual type, and
actual value category.

The manifest must also record `native_execution_status: NOT_IMPLEMENTED` at the
top level and in the metadata-review design-gate section. Missing, null, empty,
unknown, or implemented native-execution status values fail closed. In
`NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT` mode, validation must report artifact
opening, compiled-output hash verification, and metadata parsing as not
performed.

## Absolute prohibitions

The future review must not use `Assembly.Load`, `Assembly.LoadFrom`,
`Assembly.LoadFile`, `ReflectionOnlyLoad`, runtime reflection over the compiled
artifact, `Add-Type` on the artifact, `dotnet exec`, direct execution, native
DLL loading, native entry-point resolution, or native invocation. It must not
load SetupAPI/Newdev, query devices, access hardware, mutate Windows, or
build, link, sign, generate CAT files, package, stage, install, load, unload,
bind, restore, restart, enable, disable, or remove a driver or device.

## Authorization boundary

The independent read-only remediation audit passed at
`49b41dad087a3d7e6f4db7f52cd51a0c17eed222`. Its accepted inventory is
`artifacts/logs/independent-metadata-review-design-gate-remediation-audit-49b41da/artifact-inventory.json`,
size `22305` bytes, SHA-256
`2EED833A5CF5948126A766FFAAA87FD267E548DD32B2237E1DA5644BF7355A3B`.
No artifact opening, hash verification, parsing, loading, reflection,
execution, native invocation, device query, Windows mutation, or driver action
occurred. Parser implementation still requires separate authorization and
another independent audit before first use. Design acceptance does not
authorize metadata review or native runtime execution.
