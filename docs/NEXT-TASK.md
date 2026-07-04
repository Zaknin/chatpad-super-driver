# Next Task

## Objective

Perform a narrowly authorized static PE/CLI metadata-parser implementation
task. Create the parser source, project, schema, synthetic fixtures, and
prohibited-pattern guard needed to implement the accepted design.

Do not run the parser against the compiled artifact unless the next task
explicitly authorizes that exact action. Do not perform metadata review.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-static-metadata-parser-design-audit-acceptance`.
- Starting commit: the final pushed design-audit acceptance commit containing
  the gate transition to
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION`, the
  regenerated readiness manifest, and continuity updates.
- Accepted static metadata-parser implementation design audit:
  `468e8679388481e923a37a985055046f72480921`.
- Accepted audit inventory:
  `artifacts/logs/independent-static-metadata-parser-design-audit-468e867/artifact-inventory.json`,
  size `54161` bytes, SHA-256
  `D43213A552CF61E793BABD2792D6B3329706EF9F2DB3DC46D401B66307725B6F`.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged
  native declarations, compile-only harness/runner, runtime adapter,
  production driver source, INF, project/solution files outside the parser
  project, binaries, frozen artifacts, and `legacy/`.

## Current State

- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution: `NOT_IMPLEMENTED`.
- Preferred technology:
  `System.Reflection.Metadata` with `PEReader`/`MetadataReader`.
- Parser implementation: `NOT_IMPLEMENTED`.
- Parser execution: `NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Artifact opening/parsing/hash verification: `NOT_PERFORMED` and
  unauthorized.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`
- `docs/COMPILED-ARTIFACT-METADATA-REVIEW-DESIGN-GATE.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Implementation Boundaries

- Implement only the accepted static parser surface, outside production
  driver and native/runtime project graphs.
- Use .NET 9 with framework-provided `System.Reflection.Metadata`,
  `PEReader`, and `MetadataReader`.
- Add a fail-closed source/project prohibited-pattern guard before first use.
- Use only synthetic fixtures unless artifact reading is explicitly authorized
  by the next task.
- Keep evidence deterministic and include parser identity, source commit,
  input identity source, byte-read/hash/parse distinctions, no-load/
  no-reflection/no-execution/no-native/no-device/no-mutation flags, PE/CLI
  summary, P/Invoke summary, declaration checks, diagnostics, defects, and
  safety counters.

## Safety Restrictions

- Do not open, parse, or hash the compiled artifact unless the next task
  explicitly authorizes that exact implementation-time action.
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

- Parser implementation source/project/schema/guard exist only in the
  authorized static parser scope.
- Parser source passes parse/build/static guard checks authorized by the next
  task without touching the compiled artifact unless explicitly allowed.
- No metadata review, artifact loading/reflection/execution, native invocation,
  device query, Windows mutation, or driver action occurs.
- Manifest and continuity docs keep live readiness `BLOCKED`, native execution
  `NOT_IMPLEMENTED`, and runtime blocker
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Any implemented parser requires independent implementation audit before
  first use against the compiled artifact.
