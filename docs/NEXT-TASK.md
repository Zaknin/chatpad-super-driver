# Next Task

## Objective

Perform a separately authorized compile-only native interop validation phase for the accepted declaration-only SetupAPI/Newdev source boundary.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-interop-source-audit-acceptance`.
- Starting commit: the final commit from the native interop source-audit acceptance transition.
- Accepted source audit commit: `dbba70d74e99c211d47187697e19e528b381520a`.
- Native source implementation binding in readiness evidence: `a05c7e3fffa2968777824a3a2efe4f286449bdc5`.
- Before work, verify a clean tree, configured upstream, local/remote equality, and exact current HEAD.

## Current State

- The declaration-only SetupAPI/Newdev source boundary passed independent audit with verdict `AUDIT PASS`.
- Current gate is `BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED`.
- Live readiness is `BLOCKED`.
- Downstream blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- The declaration source remains uncompiled, unloaded, and uninvoked.
- Native operation, live device query, Windows mutation, exact binding, restoration, restart, broad install, and rollback counters remain zero.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- `docs/WORKLOG.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`
- `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`
- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`

## Safety Restrictions

- Compile only in an isolated non-production audit harness.
- Do not load the compiled assembly.
- Do not invoke any native declaration.
- Do not query devices, driver bindings, or hardware.
- Do not mutate Windows, registry, services, certificates, keys, credentials, boot state, or scheduled tasks.
- Do not build, link, sign, package, stage, install, load, unload, bind, restore, restart, enable, disable, or remove a driver or device.
- Keep deterministic temporary compiler artifacts outside production build and package paths and under ignored `artifacts/`.
- Do not modify `legacy/`.

## Acceptance Criteria

- Verify native source hashes against the accepted audited source boundary before compiling.
- Compile only the declarations in an isolated audit harness.
- Validate structure sizes, `cbSize`, marshaling metadata, Unicode/last-error metadata, and compiler diagnostics.
- Produce deterministic temporary artifact inventory under ignored `artifacts/`.
- Confirm no assembly loading, native entry-point resolution, native invocation, device query, or Windows mutation occurred.
- Record that compiled artifacts require a separate independent audit before any loading or invocation.
