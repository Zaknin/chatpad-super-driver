# Compiled-artifact metadata review design gate

## Status

- Compile-only evidence remediation: accepted by independent `AUDIT PASS`.
- Metadata-review design-gate remediation: accepted by independent `AUDIT PASS`
  at `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`.
- Static metadata-parser implementation design: accepted by independent
  `AUDIT PASS` at `468e8679388481e923a37a985055046f72480921`.
- Static metadata-parser implementation: accepted by independent `AUDIT PASS`
  at `f0be4746ad4cc548334336c1e66f07007b71859f`.
- Active gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Static metadata-parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT`.
- Parser execution against the real artifact: `NOT_PERFORMED`.
- Metadata review: not performed.
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

The repository now has an isolated .NET 9 parser implementation using
framework-provided `System.Reflection.Metadata`/`PEReader` APIs. It has been
validated with synthetic fixtures and accepted by independent implementation
audit as static-only. This transition adds only authorization plumbing for a
future real-artifact static metadata review. The plumbing is preflight-only,
requires the prior manifest authorization gate and the transition commit
`baab23aece902cbb06e11a308d9092fdc0f9ce0d`, and is pending independent audit
before any real-artifact review may be retried.
See `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`.

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
No real artifact opening, hash verification, parsing, loading, reflection,
execution, native invocation, device query, Windows mutation, or driver action
occurred. The implementation design is defined at
`docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md` and passed independent
read-only audit at `468e8679388481e923a37a985055046f72480921`. Parser
implementation now exists, but normal parser execution is still authorized
only for synthetic fixtures. The new real-artifact scope is preflight-only and
may only validate manifest-bound authorization and exact recorded artifact
identity without opening, reading, hashing, parsing, or writing the real
compile-only artifact. Real artifact use and metadata review remain
unauthorized until this plumbing passes independent audit and a separate
metadata-review task explicitly authorizes the next step. The first plumbing
audit failed at `cb34346d3a2268b92a295e9d135609c1e45e2c68`; the current
remediation adds canonical independent audit roots, structured malformed-
manifest denial, and deterministic 39-entry manifest regeneration and remains
pending fresh re-audit. Design acceptance and parser implementation do not
authorize native runtime execution.
