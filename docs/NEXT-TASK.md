# Next Task

## Objective

Perform an independent read-only re-audit of the remediated non-loading
compiled-artifact metadata-review design gate. Audit the design and enforcement
only; do not implement or perform metadata inspection.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-compiled-artifact-metadata-review-design-gate-remediation`.
- Starting commit: the final pushed remediation commit containing strict
  metadata-review Boolean validation, regenerated readiness manifest, and
  continuity updates.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged
  native declarations, compile-only harness, runtime adapter behavior,
  production driver source, INF, project/solution files, binaries, and
  `legacy/`.

## Current State

- Prior design-gate audit: `AUDIT FAIL` due PowerShell Boolean coercion of
  metadata-review prohibited-action fields.
- Remediation: all metadata-review safety fields must be explicit JSON
  Booleans; missing, null, numeric, string, empty-string, array, and object
  values fail closed with field-level defects.
- Manifest generation mode for this boundary:
  `NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT`.
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
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`

## Safety Restrictions

- Do not open, hash, or parse the compiled artifact during the design audit.
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

- Reproduce the original failed-audit condition against the pre-remediation
  validator behavior or supplied failing fixture, then prove the remediated
  validator rejects numeric `0`/`1` and all other non-Boolean JSON types.
- Confirm all metadata-review prohibited-action fields are strict JSON
  Booleans with field-level defects for missing, null, numeric, string,
  empty-string, array, and object values.
- Confirm top-level and metadata-gate `native_execution_status` remain
  `NOT_IMPLEMENTED` and fail closed for missing, null, empty, unknown, or
  implemented values.
- Confirm no-artifact-open design-gate audit mode reports artifact opening,
  compiled-output hash verification, and metadata parsing as not performed.
- Confirm the future review allowlist remains limited to inert PE/CLI byte
  parsing and no existing path is incorrectly presented as an approved safe
  parser.
- Confirm live readiness remains `BLOCKED`, the current gate remains
  `BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT`, and the
  runtime blocker remains unchanged.
- Return `AUDIT PASS` or `AUDIT FAIL` with exact evidence. Do not authorize or
  implement the metadata review during this audit.
