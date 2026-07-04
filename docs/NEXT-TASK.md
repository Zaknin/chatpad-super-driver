# Next Task

## Objective

Perform a fresh independent read-only audit of the remediated static PE/CLI
metadata parser implementation.

Do not run the parser against the real compile-only native interop compiled
artifact. Do not open, parse, hash, load, reflect over, execute, or invoke the
real artifact. Do not perform metadata review.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-static-metadata-parser-implementation-remediation`.
- Starting commit: the pushed remediation commit containing parser
  fail-closed input-scope enforcement, immutable safety-policy enforcement,
  updated parser validation, regenerated readiness manifest, and continuity
  updates.
- Remediation base commit:
  `47b9ada4255b310db5234446404975165a971678`.
- Failed implementation audit finding:
  the parser at `47b9ada4255b310db5234446404975165a971678` could be pointed at
  real compile-only artifact paths under the current gate and parsed safety
  flags without enforcing them.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged
  native declarations, compile-only harness/runner, runtime adapter,
  production driver source, INF, production project/solution files outside the
  parser project, binaries, frozen artifacts, and `legacy/`.

## Current State

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser technology: `System.Reflection.Metadata` with
  `PEReader`/`MetadataReader`.
- Parser implementation: `IMPLEMENTED_PENDING_AUDIT`.
- Parser execution: `SYNTHETIC_FIXTURES_ONLY`.
- Parser real-artifact path gate: `IMPLEMENTED_PENDING_AUDIT`.
- Parser allowed input scope: `SYNTHETIC_FIXTURES_ONLY`.
- Parser safety policy: `IMMUTABLE_STATIC_ONLY`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact opening/parsing/hash verification: `NOT_PERFORMED` and
  unauthorized.
- Synthetic and pre-read validation evidence:
  `artifacts/logs/static-metadata-parser-implementation-remediation/static-metadata-parser-synthetic-validation.json`.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`
- `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
- `tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj`
- `tools/StaticMetadataParser/Program.cs`
- `tools/Test-ChatpadStaticMetadataParser.ps1`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Safety Restrictions

- Do not open, parse, or hash the real compile-only native interop compiled
  artifact.
- Do not run the parser against the real artifact.
- Do not perform metadata review.
- Do not load or reflect over compiled output; do not execute it.
- Do not use runtime assembly APIs, artifact-targeted `Add-Type`, `dotnet exec`,
  native DLL loading, entry-point resolution, or native invocation.
- Do not invoke SetupAPI/Newdev, query devices/hardware, or mutate Windows.
- Do not build, link, sign, generate CAT files, package, stage, install, load,
  unload, bind, restore, restart, enable, disable, or remove a driver/device.
- Do not modify production/native/runtime implementation paths, binaries,
  frozen artifacts, or `legacy/`.

## Acceptance Criteria

- Audit confirms the parser implementation is static-only and uses
  `System.Reflection.Metadata`, `PEReader`, and `MetadataReader`.
- Audit confirms the parser rejects real-artifact-like paths before file read,
  hash computation, PE parsing, or metadata parsing.
- Audit confirms current parser input is limited to parser-specific synthetic
  fixture roots under ignored `artifacts/logs/`.
- Audit confirms immutable safety policy is enforced and safety options are
  rejected before input read.
- Audit confirms the parser was validated only against synthetic fixtures and
  real-artifact-like path strings.
- Audit confirms the parser was not run against the real compile-only artifact.
- Audit confirms real artifact opening/parsing/hash verification remains not
  performed.
- Audit confirms metadata review remains not performed.
- Audit confirms prohibited-action counters remain zero.
- Manifest and continuity docs keep live readiness `BLOCKED`, native execution
  `NOT_IMPLEMENTED`, runtime blocker
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, and current gate
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
