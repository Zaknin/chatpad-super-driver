# Next Task

## Objective

Prepare the next separately authorized native SetupAPI/Newdev adapter
implementation task boundary. Do not implement, declare, load, invoke, install,
bind, restore, restart, or otherwise execute native adapter behavior unless the
user explicitly authorizes that exact implementation scope.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-native-adapter-scaffold-integrity-remediation`.
- Starting commit: the re-audit finalization commit containing this file, the
  regenerated readiness manifest, and the worklog entry for the independent
  scaffold integrity re-audit.
- Required ancestry:
  `b7f5f700c68af3846850b7ba69a34f7c8dd66614`.
- Before any next-task work, verify a clean tree, configured upstream,
  local/remote equality, and the exact current HEAD.

## Current State

- Implementation commit
  `60da3ee244eaa5c28cb5022748a41ca95e6474cc` remediated the scaffold
  integrity gaps found in the initial audit.
- Remediation finalization commit
  `77a3c3c4e29ddb2cfb0f7281b0db40b9f0622ab6` contains the regenerated
  readiness manifest and continuity updates for that remediation.
- Independent read-only re-audit passed on 2026-07-03.
- Production adapter identity:
  `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity:
  `chatpad-fake-exact-instance-adapter-v1`, selectable only with explicit
  synthetic mode.
- Public native adapter operations require explicit primitive string adapter
  and operation inputs. Caller objects, missing selections, non-string inputs,
  module-state edits, synthetic fallback attempts, positional extras, splatted
  capability-like names, and pipeline input fail closed.
- `Apply`, `Restore`, and `Restart` remain blocked with
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- The executable gate string still reports
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`; do not treat
  the passed re-audit as live execution authorization.
- No native interop declaration, SetupAPI/Newdev invocation, live device query,
  Windows mutation, packaging, signing, install, bind, restore, restart, or
  reboot path exists in this scaffold.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file,
  and the latest `docs/WORKLOG.md` entry.
- Inspect these files first:
  - `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
  - `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
  - `tools/ExactInstance/ChatpadExactInstance.Contracts.psm1`
  - `tools/Invoke-ChatpadExactInstanceBindingRestoration.ps1`
  - `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
  - `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
  - `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
  - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
  - `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
  - `docs/evidence/runtime-bringup-readiness-manifest.json`

## Safety Restrictions

- No live execution without a later explicit user authorization for that exact
  action.
- No driver build/link, signing, CAT generation, packaging, staging,
  driver-store mutation, installation, binding, loading, restoration, restart,
  reboot, device query, hardware access, Windows mutation, production
  source/INF change, frozen-binary change, or `legacy/` change unless a later
  task explicitly authorizes that exact scope.
- Keep generated outputs and diagnostic logs under ignored `artifacts/`.

## Acceptance Criteria

- State the requested mode clearly: design-only, implementation-only without
  execution, audit, or live execution.
- Revalidate the current gate and safety state before changing source.
- Preserve explicit primitive adapter and operation selection, no implicit
  production default, no implicit synthetic fallback, and no caller-supplied
  capability-like authorization.
- Keep all native operation, device-query, and Windows-mutation counters at
  zero unless a later explicitly authorized live task changes that boundary.
- If implementation is authorized, add focused regressions for every new native
  adapter surface before claiming it is safe.
- Do not claim live readiness until a separate implementation, independent
  audit, and explicit live authorization all complete.
