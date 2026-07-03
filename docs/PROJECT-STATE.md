# Project State

*Last updated: 2026-07-03 (native interop compile-only validation accepted; native adapter execution not implemented)*

## Current State

- **Branch:** `feature/runtime-bringup-native-interop-compile-only-validation`.
- **Starting branch:** `feature/runtime-bringup-native-interop-source-audit-acceptance`.
- **Starting commit:** `a5a1ddfe055481eec4ea4da57b664c0bd3189d22`.
- **Compile-only validation evidence:** `docs/evidence/native-interop-compile-only-validation.json`, schema `chatpad-native-interop-compile-only-validation-v1`, validation ID `native-interop-compile-only-20260703T170511Z`.
- **Readiness manifest:** `docs/evidence/runtime-bringup-readiness-manifest.json`, regenerated with 32 entries.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Interop Compile-Only Boundary

- The accepted declaration-only SetupAPI/Newdev source boundary under `tools/ExactInstance/NativeInterop/` was compiled only by an isolated non-production harness under `tools/ExactInstance/CompileOnlyValidation/`.
- The harness links the audited declaration source by reference; it does not copy the declaration source and does not participate in production driver builds.
- Target framework/platform/configuration: `net9.0-windows10.0.26100.0`, `x64`, `Release`.
- Toolchain: .NET SDK `9.0.315`, MSBuild `17.14.43+2a0eb78b3`, Roslyn `4.14.0-3.26064.1 (450493a9)`.
- Build result: `PASS`; compiler exit code `0`; warnings `0`; errors `0`; produced file count `18`.
- Primary compile output hash: `artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll` SHA-256 `1F5337976BDE45333CAF5E5D50E12A5A05F1A4B85E12E7B91A800B29F82CF0FA`.
- Audited source hashes matched before and after compilation:
  - `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs` SHA-256 `127EA58993862CCE865E3D73B0F1A99513932ABDF1BEA615812966EB5C14BEAA`.
  - `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1` SHA-256 `3E7E3119A467330A413280658503B294C0FFB38271A9CA847056BAF6B2E778D3`.
- No compiled output was loaded, executed, reflected over, tested, or invoked.

## Readiness And Safety

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- Production adapter identity remains `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity remains `chatpad-fake-exact-instance-adapter-v1`.
- `Apply`, `Restore`, and `Restart` expose deterministic non-executing call plans and still return `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Compile-only validation is authorized and performed; native source compilation evidence is available.
- Native loading, entry-point resolution, native invocation, device queries, exact-instance access, Windows mutation, driver build/link, signing, CAT generation, packaging, staging, installation, binding, restoration, restart, reboot, hardware access, registry/service/boot mutation, production driver source/INF changes, frozen binary changes, and `legacy/` changes remain unauthorized and were not performed.

## Verified Results

- Compile-only native interop validation: `PASS`; warning count `0`; error count `0`; produced file count `18`.
- Exact-instance suite under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 191 tests, 793 assertions, zero failed tests in each runtime.
- Full readiness under Windows PowerShell 5.1 and PowerShell 7: `PASS`; 495 fixtures, 2,517 assertions, exact-instance subtotal 191 tests and 793 assertions, live readiness `BLOCKED`, current gate `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, and Windows mutation count `0` in each runtime.
- Readiness manifest generation: `PASS`; 32 entries, framework status `PASS`, live installation readiness `BLOCKED`.
- Manifest default validation and corruption regression passed under Windows PowerShell 5.1 and PowerShell 7 after final staging/regeneration with the new compile-only validation script included in tracked PowerShell inventory.
- Native source-boundary guard: `PASS`; approved declaration matches unchanged and forbidden matches remain zero.
- Repository safety: `PASS`.

## Unresolved Blockers

- Native SetupAPI/Newdev adapter execution remains unimplemented and explicitly blocked.
- The compile-only artifacts require a separate independent audit before any loading, reflection inspection, entry-point resolution, native invocation, device query, or live adapter implementation can rely on them.
- Live readiness remains blocked until later implementation, independent audit, and explicit live authorization complete.
