# Next Task

## Objective

Design and implement only the next separately authorized native adapter execution boundary after compile-only validation, or perform an independent audit of the compile-only validation evidence before any execution work begins.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-interop-compile-only-validation`.
- Starting commit: the final commit titled `Validate native interop compilation without execution`.
- Required first check: verify the branch, exact HEAD, upstream, ahead/behind state, and clean worktree before relying on these docs.

## Current State

- The declaration-only SetupAPI/Newdev source boundary passed independent source audit.
- The accepted declarations were compiled by an isolated non-production harness.
- Compile-only validation evidence is tracked at `docs/evidence/native-interop-compile-only-validation.json`.
- Readiness remains `BLOCKED`.
- Current gate and capability blocker are both `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native loading, entry-point resolution, reflection inspection, native invocation, device query, exact-instance access, Windows mutation, driver build/link, signing, packaging, staging, installation, binding, restoration, restart, reboot, production driver source/INF changes, frozen binary changes, and `legacy/` changes remain unauthorized.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- `docs/WORKLOG.md`
- `docs/evidence/native-interop-compile-only-validation.json`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1`
- `tools/ExactInstance/CompileOnlyValidation/`
- `tools/ExactInstance/NativeInterop/`
- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Safety Restrictions

- Do not load or execute the compile-only output unless a later task explicitly authorizes that exact action after independent audit.
- Do not invoke any SetupAPI/Newdev declaration.
- Do not query devices, driver bindings, hardware, driver store state, services, registry, boot state, event logs, or certificates unless the next task explicitly authorizes that exact inspection.
- Do not mutate Windows, registry, services, certificates, keys, credentials, boot state, scheduled tasks, devices, drivers, driver packages, or driver-store state.
- Do not build, link, sign, package, stage, install, load, unload, bind, restore, restart, enable, disable, or remove a driver or device.
- Keep generated outputs under ignored `artifacts/`.
- Do not modify `legacy/`.

## Acceptance Criteria

- If the next task is an audit, independently verify the compile-only evidence, harness isolation, source hashes, output inventory, and prohibited-action counters without loading or invoking native code.
- If the next task is implementation design, keep it source/design-only unless execution is explicitly authorized.
- If execution is explicitly authorized in a later task, require a new gate, new evidence contract, and independent audit boundary before any live operation can be considered.
- Preserve `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` until executable native adapter behavior is implemented, audited, and separately authorized.
