# Next Task

## Objective

Perform an independent read-only audit of the non-loading compiled-artifact
metadata-review design gate. Audit the design and enforcement only; do not
implement or perform metadata inspection.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-compiled-artifact-metadata-review-design-gate`.
- Starting commit: the final pushed commit containing the design gate,
  regenerated readiness manifest, and continuity updates.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged
  native declarations, compile-only harness, runtime adapter behavior,
  production driver source, INF, project/solution files, binaries, and
  `legacy/`.

## Current State

- Compile-only evidence remediation re-audit: `AUDIT PASS`.
- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution: `NOT_IMPLEMENTED`.
- Metadata review: `DESIGN_GATED_NOT_IMPLEMENTED`.
- No approved repository-native static managed metadata parser exists.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/COMPILED-ARTIFACT-METADATA-REVIEW-DESIGN-GATE.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- Gate producers and manifest validator changed by the design-gate commit

## Safety Restrictions

- Do not open or parse the compiled artifact during the design audit.
- Do not load, reflect over, execute, or invoke the compiled assembly.
- Do not use `Assembly.Load*`, `ReflectionOnlyLoad`, artifact-targeted
  `Add-Type`, `dotnet exec`, native DLL loading, or entry-point resolution.
- Do not invoke SetupAPI/Newdev or any native API.
- Do not query devices, bindings, or hardware; do not mutate Windows.
- Do not build, link, sign, generate CAT files, package, stage, install, load,
  unload, bind, restore, restart, enable, disable, or remove a driver/device.
- Do not modify production driver source, INF, project/solution files,
  signing/package/deployment paths, binaries, frozen artifacts, or `legacy/`.

## Acceptance Criteria

- Classify every tooling finding and confirm no existing path is incorrectly
  presented as an approved safe parser.
- Confirm the future review allowlist is limited to inert PE/CLI byte parsing.
- Confirm all loading, reflection, execution, native, device, Windows, and
  driver actions are explicitly prohibited and recorded false.
- Confirm the manifest and validators fail closed on gate/status drift.
- Confirm live readiness remains `BLOCKED`, native execution remains
  `NOT_IMPLEMENTED`, and the runtime blocker remains unchanged.
- Return `AUDIT PASS` or `AUDIT FAIL` with exact evidence. Do not authorize or
  implement the metadata review during this audit.
