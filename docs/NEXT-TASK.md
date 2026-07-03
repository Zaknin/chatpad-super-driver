# Next Task

## Objective

Perform an independent read-only re-audit of the remediated non-executing
production native SetupAPI/Newdev adapter scaffold and composition-root wiring.
Do not implement or execute native adapter behavior.

## Required Starting Point

- Branch:
  `feature/runtime-bringup-native-adapter-scaffold-integrity-remediation`.
- Starting commit: the finalization commit for this remediation task, after
  implementation commit `60da3ee244eaa5c28cb5022748a41ca95e6474cc` and the
  regenerated readiness manifest are present.
- Before audit work, verify a clean tree, configured upstream, local/remote
  equality, and ancestry from
  `b7f5f700c68af3846850b7ba69a34f7c8dd66614`.

## Current State

- The initial scaffold audit found fail-open integrity gaps in implicit
  production selection, script-scope mutable scaffold constants, extensible
  caller object handling, and manifest corruption regression forwarding.
- Implementation commit
  `60da3ee244eaa5c28cb5022748a41ca95e6474cc` remediates those gaps and moves
  live readiness to
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.
- Production adapter identity:
  `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity:
  `chatpad-fake-exact-instance-adapter-v1`, selectable only with explicit
  synthetic mode.
- Public native adapter operations require explicit primitive string adapter
  and operation inputs. Caller objects, missing selections, non-string inputs,
  module-state edits, and synthetic fallback attempts fail closed.
- `Apply`, `Restore`, and `Restart` remain blocked with
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
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
- No native API implementation, declaration, P/Invoke, Add-Type native shim,
  DLL import, driver build/link, signing, CAT generation, packaging, staging,
  driver-store mutation, installation, binding, loading, restoration, restart,
  reboot, device query, hardware access, Windows mutation, production
  source/INF change, frozen-binary change, or `legacy/` change.
- Keep any audit outputs under ignored `artifacts/`.

## Acceptance Criteria

- Confirm production adapter metadata is stable, non-synthetic, fail-closed,
  non-executing, and blocked by
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Confirm public native adapter operations require explicit primitive string
  adapter selection and operation selection, with no implicit production
  default and no implicit synthetic fallback.
- Confirm mutable module state, caller objects with spoofed methods, wrapper
  objects, serialized objects, `PSCustomObject`, `PSTypeNames`, `Add-Member`,
  positional extras, splatted capability-like names, and pipeline input do not
  authorize execution or change the blocked gate.
- Confirm `Apply`, `Restore`, and `Restart` return deterministic blocked
  operation evidence and keep native operation, device query, and Windows
  mutation counters at zero.
- Confirm manifest validation and corruption regression forward custom
  `-ManifestPath` values to child runtime processes.
- Re-run the exact suite, full readiness suite, manifest validation/corruption
  regression, executable guard, AST parse inventory, PSScriptAnalyzer, and
  repository safety checks without live execution.
- Confirm exact-instance opening, driver-node identity, restoration identity,
  postcondition, restart/reboot, and evidence-origin contracts remain intact.
- Confirm all live/device/Windows mutation counters remain zero.
- Leave live readiness blocked as
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.
- Do not recommend executable native adapter implementation until this
  independent scaffold re-audit passes.
