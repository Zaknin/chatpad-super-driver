# Next Task

## Objective

Perform an independent read-only audit of the static PE/CLI metadata parser
implementation.

Do not run the parser against the real compile-only native interop compiled
artifact. Do not open, parse, hash, load, reflect over, execute, or invoke the
real artifact. Do not perform metadata review.

## Required Starting Point

- Branch: `feature/runtime-bringup-static-metadata-parser-implementation`.
- Starting commit: the final pushed parser implementation commit containing
  `tools/StaticMetadataParser/`, `tools/Test-ChatpadStaticMetadataParser.ps1`,
  `docs/evidence/static-metadata-parser-evidence-schema-v1.md`, the regenerated
  readiness manifest, and continuity updates.
- Implementation base commit:
  `27d4640069808121ee74749940392d2df6c8e746`.
- Accepted static metadata-parser implementation design audit:
  `468e8679388481e923a37a985055046f72480921`.
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
- Metadata review: `NOT_PERFORMED`.
- Real artifact opening/parsing/hash verification: `NOT_PERFORMED` and
  unauthorized.
- Synthetic validation evidence:
  `artifacts/static-metadata-parser-implementation/static-metadata-parser-synthetic-validation.json`.

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
- Audit confirms the parser was validated only against synthetic fixtures.
- Audit confirms the parser was not run against the real compile-only artifact.
- Audit confirms real artifact opening/parsing/hash verification remains not
  performed.
- Audit confirms metadata review remains not performed.
- Audit confirms prohibited-action counters remain zero.
- Manifest and continuity docs keep live readiness `BLOCKED`, native execution
  `NOT_IMPLEMENTED`, runtime blocker
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, and current gate
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
