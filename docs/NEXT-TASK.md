# Next Task

## Objective

Perform an independent read-only audit of the non-executing production native
SetupAPI/Newdev adapter scaffold and composition-root wiring. Do not implement
or execute native adapter behavior.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-adapter-composition-root`.
- Starting commit: the finalization commit for this scaffold task, after
  implementation commit `9ea29a8a29379a55747c6cf53112379aeb03b9e0` and the
  regenerated readiness manifest are present.
- Before audit work, verify a clean tree, configured upstream, local/remote
  equality, and ancestry from
  `a23259a73dc27f332a98f292e90866b0db42a764`.

## Current State

- The accepted capability-boundary remediation at
  `a23259a73dc27f332a98f292e90866b0db42a764` superseded the stale
  `BLOCKED_PENDING_INDEPENDENT_REAUDIT` continuation text.
- The current phase adds a production adapter identity and deterministic
  composition-root selection, but only as a non-executing scaffold.
- Implementation commit:
  `9ea29a8a29379a55747c6cf53112379aeb03b9e0`.
- Production adapter identity:
  `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity:
  `chatpad-fake-exact-instance-adapter-v1`, selectable only with explicit
  synthetic mode.
- `Apply`, `Restore`, and `Restart` remain blocked with
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Full live readiness remains blocked as
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_AUDIT`.
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

- Read-only audit only.
- No native API implementation, declaration, P/Invoke, Add-Type, C# shim, DLL
  import, driver build/link, signing, CAT generation, packaging, staging,
  driver-store mutation, installation, binding, loading, restoration, restart,
  reboot, device query, hardware access, Windows mutation, production
  source/INF change, frozen-binary change, or `legacy/` change.
- Keep any audit outputs under ignored `artifacts/`.

## Acceptance Criteria

- Confirm production adapter metadata is stable, non-synthetic, fail-closed,
  non-executing, and blocked by
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Confirm composition-root selection is deterministic and uses explicit
  production or synthetic identity, with no implicit synthetic fallback.
- Confirm `Apply`, `Restore`, and `Restart` return deterministic blocked
  operation evidence and keep native operation, device query, and Windows
  mutation counters at zero.
- Confirm unknown adapter names, missing adapter selection, production selected
  as synthetic, synthetic selected without explicit synthetic mode, unsupported
  operations, caller objects, serialized objects, module-state extraction,
  splatted capability-like names, positional extras, and pipeline input fail
  closed or remain non-authorizing.
- Re-run the exact suite, full readiness suite, manifest validation/corruption
  regression, executable guard, AST parse inventory, PSScriptAnalyzer, and
  repository safety checks without live execution.
- Confirm exact-instance opening, driver-node identity, restoration identity,
  postcondition, restart/reboot, and evidence-origin contracts remain intact.
- Confirm all live/device/Windows mutation counters remain zero.
- Leave live readiness blocked as
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_AUDIT`.
- Do not recommend executable native adapter implementation until this
  independent scaffold audit passes.
