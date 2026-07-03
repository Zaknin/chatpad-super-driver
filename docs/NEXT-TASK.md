# Next Task

## Objective

Perform an independent read-only audit of the native SetupAPI/Newdev adapter design gate. Do not implement or execute native adapter behavior.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-adapter-design-gate`.
- Starting commit: the finalization commit containing this file.
- Before any audit work, verify a clean tree, configured upstream, local/remote equality, and ancestry from `5ef224e27b53f4c5a562be3556173bc7856f69d9`.

## Current State

- The native adapter work is design-and-gate only.
- The public mutation-capability factory remains blocked with `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Static guards currently report zero native SetupAPI/Newdev/native Windows mutation API declarations or invocations in tracked PowerShell files.
- Full readiness remains offline and blocked for live installation: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Audit evidence is ignored under `artifacts/logs/` and must not be committed.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md` entry.
- Inspect these files first:
  - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
  - `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
  - `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
  - `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
  - `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
  - `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
  - `docs/evidence/runtime-bringup-readiness-manifest.json`

## Safety Restrictions

- Read-only audit only.
- No native API implementation, declaration, P/Invoke, Add-Type, C# shim, DLL import, driver build/link, signing, CAT generation, packaging, staging, driver-store mutation, installation, binding, loading, restoration, restart, reboot, device query, hardware access, Windows mutation, production source/INF change, frozen-binary change, or `legacy/` change.
- Keep any audit outputs under ignored `artifacts/`.

## Acceptance Criteria

- Confirm the design gate preserves exact instance ID opening, adapter-returned canonical ID comparison, one retained device element, immutable driver-node identity, exact restoration, postcondition proof, and manual-recovery blockers.
- Confirm public callers cannot construct or spoof live mutation authorization.
- Confirm read-only design probes do not grant mutation authority.
- Confirm executable/static guards catch future native declarations or invocations before live adapter implementation.
- Re-run the exact suite, full readiness suite, cross-runtime matrix, manifest validation/corruption regression, executable guard, and repository safety checks without live execution.
- Leave live readiness blocked unless a separate later task explicitly authorizes implementation and audit.
