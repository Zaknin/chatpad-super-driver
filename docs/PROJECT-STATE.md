# Project State

*Last updated: 2026-07-03 (native interop source audit accepted; compile-only validation not authorized)*

## Current State

- **Branch:** `feature/runtime-bringup-native-interop-source-audit-acceptance`.
- **Accepted native source audit commit:** `dbba70d74e99c211d47187697e19e528b381520a`.
- **Native source implementation commits:** `2730d037bcbccf4de3dc51e4961922eff98fff7b` and `a05c7e3fffa2968777824a3a2efe4f286449bdc5`.
- **Documentation/status transition commit:** the commit containing this document, the regenerated readiness manifest, and continuity updates.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Interop Source Boundary

- The declaration-only SetupAPI/Newdev source boundary under `tools/ExactInstance/NativeInterop/` passed independent strict read-only source audit.
- Audit verdict: `AUDIT PASS`.
- Audited branch: `feature/runtime-bringup-native-interop-source-boundary`.
- Audited commit: `dbba70d74e99c211d47187697e19e528b381520a`.
- Audit artifacts: `artifacts/logs/independent-native-interop-source-audit-dbba70d/`.
- Artifact inventory: `artifact-inventory.json`; SHA-256 `198124D0949A9DD987CD154A09D0DC55DDFEB79C6A2E63839E8FB19BD2202967`.
- The audit was strict read-only: no compilation, loading, native invocation, device query, build, package, installation, binding, or Windows mutation occurred.
- Native source remains only in the approved source boundary and is not included in production build inputs.
- The source remains uncompiled, unloaded, and uninvoked.
- Structure layout, marshaling, size, `cbSize`, and compiler diagnostics remain unvalidated until a separately authorized compile-only phase.

## Readiness And Safety

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- Production adapter identity remains `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity remains `chatpad-fake-exact-instance-adapter-v1`.
- `Apply`, `Restore`, and `Restart` expose deterministic non-executing call plans but still return `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- `native_interop_implemented`, `native_compilation_permitted`, `native_loading_permitted`, `native_invocation_permitted`, `device_queries_available`, and `windows_mutation_available` remain `false`.
- No driver build/link, signing, CAT generation, packaging, staging, installation, binding, loading, restoration, restart, reboot, driver-store mutation, device query, hardware access, registry, service, boot, security, trace, event-log, protocol, input, certificate, credential, production driver source/INF, frozen binary, or `legacy/` action is authorized.

## Verified Results

- Exact-instance suite under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 171 tests, 718 assertions, zero failed tests in each runtime.
- Full readiness under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 475 fixtures, 2,442 assertions, exact-instance subtotal 171 tests and 718 assertions, live readiness `BLOCKED`, and Windows mutation count `0` in each runtime.
- Readiness manifest regenerated with 27 entries, framework status `PASS`, live installation readiness `BLOCKED`, current gate `BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED`, and implementation binding `a05c7e3fffa2968777824a3a2efe4f286449bdc5`.
- Manifest validation default path under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 27 entries and zero defects in each runtime.
- Manifest corruption regression under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 18 cases and zero failed cases in each runtime.
- Native source-boundary guard: `PASS`; approved declaration matches unchanged and forbidden matches remain zero.
- Repository safety: `PASS`.

## Unresolved Blockers

- Compile-only native interop validation has not been authorized or performed.
- Native SetupAPI/Newdev execution remains unimplemented and explicitly blocked.
- A compile-only validation phase must use an isolated non-production harness, produce temporary artifacts outside production build/package paths, avoid loading compiled output, avoid native invocation, and validate structure sizes, `cbSize`, marshaling metadata, and compiler diagnostics.
- Any compiled artifact requires a separate independent audit before loading or invocation.
- Live readiness remains blocked until later implementation, independent audit, and explicit live authorization complete.
