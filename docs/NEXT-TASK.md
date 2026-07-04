# Next Task

## Objective

Perform an independent read-only audit of the static PE/CLI metadata-parser
implementation design. Audit the technology choice, containment contract,
metadata allowlist, expected declaration contract, prohibited-pattern guard
requirements, evidence schema, determinism, and fail-closed behavior.

Do not implement, build, or run the parser. Do not perform metadata review.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-static-metadata-parser-implementation-design`.
- Starting commit: the final pushed design commit containing
  `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`, the
  design-audit gate, regenerated readiness manifest, and continuity updates.
- Transition base: `382aa85980408939a93043583b48e942ebfbf018`.
- Accepted metadata-review design audit:
  `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged
  native declarations, compile-only harness/runner, runtime adapter,
  production driver source, INF, project/solution files, binaries, frozen
  artifacts, and `legacy/`.

## Current State

- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_DESIGN_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution: `NOT_IMPLEMENTED`.
- Preferred technology:
  `System.Reflection.Metadata` with `PEReader`/`MetadataReader`.
- Parser implementation: `NOT_IMPLEMENTED`.
- Parser execution: `NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Artifact opening/parsing/hash verification: `NOT_PERFORMED`.

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

## Audit Questions

- Can the preferred API inspect only PE/CLI bytes without assembly loading,
  runtime reflection, execution, dependency resolution, or native invocation?
- Are file containment, reparse-point, evidence identity, byte-size, timeout,
  malformed-input, and single-output controls complete and fail closed?
- Is the metadata allowlist sufficient and no broader than required?
- Are exactly 13 expected P/Invoke rows and only `setupapi.dll`/`newdev.dll`
  specified from an immutable audited contract?
- Does the future evidence schema distinguish artifact read, hash, parse,
  assembly load, reflection, execution, native invocation, device query,
  Windows mutation, and driver actions with strict fields and counters?
- Would the required source/project guard reject every runtime, native,
  process, device, network, mutation, and production dependency path?
- Are dnlib, Mono.Cecil, ILDasm, ILSpy CLI, `dumpbin`, PowerShell-hosted code,
  and a custom parser rejected for defensible dependency and proof-surface
  reasons?

## Safety Restrictions

- Do not open, parse, or hash the compiled artifact.
- Do not implement, build, execute, or test a parser against the artifact.
- Do not load or reflect over compiled output; do not execute it.
- Do not use runtime assembly APIs, artifact-targeted `Add-Type`, `dotnet exec`,
  native DLL loading, entry-point resolution, or native invocation.
- Do not invoke SetupAPI/Newdev, query devices/hardware, or mutate Windows.
- Do not build, link, sign, generate CAT files, package, stage, install, load,
  unload, bind, restore, restart, enable, disable, or remove a driver/device.
- Do not modify production/native/compile-only/runtime implementation paths,
  binaries, frozen artifacts, or `legacy/`.

## Acceptance Criteria

- Return `AUDIT PASS` or `AUDIT FAIL` with exact findings and evidence.
- Confirm no parser implementation or executable exists.
- Confirm no artifact opening, parsing, hashing, or metadata review occurred.
- Confirm the design remains static-byte-only and separately gates
  implementation, execution, and first use.
- Confirm live readiness remains `BLOCKED`, native execution remains
  `NOT_IMPLEMENTED`, and the runtime blocker remains unchanged.
- Do not authorize parser implementation or metadata review during this audit.
