# Next Task

## Objective

Perform a separately authorized non-loading compiled-artifact metadata review,
if the repository already supports static inspection without assembly loading,
reflection, or execution. If no such tooling exists, produce a design gate for
that review without implementing the inspector.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-interop-compile-only-audit-acceptance`.
- Starting commit: the final commit containing the audit-acceptance transition,
  regenerated readiness manifest, and continuity updates.
- Verify exact HEAD, configured upstream, `0/0` ahead/behind, clean status, and
  unchanged native declaration, compile harness, and adapter runtime behavior.

## Current State

- Independent compile-only evidence remediation re-audit: `AUDIT PASS`.
- Accepted audit commit: `3e922470f2e46d5eeb4b6fe7500c4f105c608b3b`.
- Audit inventory:
  `artifacts/logs/independent-compile-only-evidence-reaudit-3e92247/artifact-inventory.json`,
  size `49650` bytes, SHA-256
  `09E4CB50663849B7E2ADB6D91817A35E97DC12831CA5384128ABE2A72BFCFA5C`.
- Line-ending-stable tracked-text evidence is accepted.
- Old v1 compile outputs are superseded ignored derived artifacts and are not
  an active preservation criterion.
- Current schema v2 evidence is authoritative for current compile-output
  identity.
- Live readiness: `BLOCKED`.
- Current gate and remaining blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution status: `NOT_IMPLEMENTED`.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/evidence/native-interop-compile-only-validation.json`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- Existing repository tooling for static PE/metadata inspection

## Safety Restrictions

- Do not load, reflect over, execute, or invoke the compiled assembly.
- Do not load SetupAPI/Newdev, resolve entry points, invoke native APIs, query
  devices or bindings, or access hardware.
- Do not build or link the driver, sign, package, stage, install, load, unload,
  bind, restore, restart, enable, disable, or remove a driver or device.
- Do not mutate Windows, registry, services, certificates, keys, credentials,
  boot state, scheduled tasks, or system configuration.
- Keep generated outputs under ignored `artifacts/`; do not modify `legacy/`.

## Acceptance Criteria

- Establish whether an existing tool can inspect the compiled artifact as raw
  file bytes without assembly loading, reflection, or execution.
- If supported, define an exact allowlisted metadata scope and fail-closed
  evidence contract before running it.
- If unsupported, stop at a design gate and do not implement or execute a new
  inspector without separate authorization.
- Preserve live readiness `BLOCKED`, native execution `NOT_IMPLEMENTED`, and
  blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
