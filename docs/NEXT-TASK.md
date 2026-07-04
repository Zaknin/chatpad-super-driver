# Next Task

## Objective

Design and authorize, but do not yet use, a safe static PE/CLI metadata parser
for the compiled-artifact metadata review. Keep the task non-runtime and
separate parser implementation authorization from any later metadata-review
execution.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-metadata-review-design-audit-acceptance`.
- Starting commit: the final pushed acceptance commit containing the
  implementation-authorization gate, accepted audit facts, regenerated
  readiness manifest, and continuity updates.
- Verify exact HEAD, configured upstream, `0/0` ahead/behind, clean status,
  and unchanged native declarations, compile-only harness/runner, runtime
  adapter behavior, production driver source, INF, project/solution files,
  binaries, frozen artifacts, and `legacy/`.

## Current State

- Metadata-review design-gate remediation audit: `AUDIT PASS` at
  `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`.
- Accepted audit inventory:
  `artifacts/logs/independent-metadata-review-design-gate-remediation-audit-49b41da/artifact-inventory.json`,
  `22305` bytes, SHA-256
  `2EED833A5CF5948126A766FFAAA87FD267E548DD32B2237E1DA5644BF7355A3B`.
- Manifest schema: `chatpad-runtime-bringup-readiness-manifest-v4`.
- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_IMPLEMENTATION_AUTHORIZATION`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution: `NOT_IMPLEMENTED`.
- Metadata status: `DESIGN_GATED_NOT_IMPLEMENTED`.
- Metadata parser: not implemented and not authorized.
- Metadata review: not performed.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/COMPILED-ARTIFACT-METADATA-REVIEW-DESIGN-GATE.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Safety Restrictions

- Do not open, parse, or hash the compiled artifact unless the future task
  explicitly authorizes those exact implementation-time actions.
- Do not perform metadata review in the parser implementation-design task.
- Do not load or reflect over the compiled artifact; do not execute it.
- Do not use runtime assembly APIs, artifact-targeted `Add-Type`, `dotnet exec`,
  native DLL loading, entry-point resolution, or native invocation.
- Do not invoke SetupAPI/Newdev, query devices or hardware, or mutate Windows.
- Do not build, link, sign, generate CAT files, package, stage, install, load,
  unload, bind, restore, restart, enable, disable, or remove a driver/device.
- Do not modify production driver source, INF, project/solution files,
  signing/package/deployment paths, binaries, frozen artifacts, or `legacy/`.

## Acceptance Criteria

- Define an inert byte-oriented PE/CLI parsing implementation boundary with no
  runtime assembly loading, reflection, execution, or native invocation.
- Define exact input containment and identity checks, metadata allowlists,
  parser identity/version binding, malformed-input handling, evidence fields,
  and zero-action counters.
- Keep parser implementation and metadata-review execution separately gated.
- Require independent audit of any implemented parser before first use.
- Preserve live readiness `BLOCKED`, native execution `NOT_IMPLEMENTED`, and
  runtime blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Do not perform native loading, device installation/binding, hardware testing,
  or live runtime validation.
