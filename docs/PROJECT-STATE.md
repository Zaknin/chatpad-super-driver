# Project State

*Last updated: 2026-07-03 (native interop source boundary implemented; validation in progress before final commit)*

## Current State

- **Branch:** `feature/runtime-bringup-native-interop-source-boundary`.
- **Accepted starting commit:** `b7672d123200f13e95353d2505bb813843ac3f7c`.
- **Implementation commit:** pending; this document will be committed with the native interop source-boundary implementation and continuity updates.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Interop Source Boundary

- A declaration-only SetupAPI/Newdev source boundary exists under `tools/ExactInstance/NativeInterop/`.
- The declaration source is `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`.
- The source-boundary metadata and static validator are in `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`.
- The declaration inventory contains 13 P/Invoke signatures:
  `SetupDiCreateDeviceInfoList`, `SetupDiDestroyDeviceInfoList`, `SetupDiOpenDeviceInfoW`, `SetupDiGetDeviceInstanceIdW`, `SetupDiGetDevicePropertyW`, `SetupDiGetDeviceRegistryPropertyW`, `SetupDiBuildDriverInfoList`, `SetupDiDestroyDriverInfoList`, `SetupDiEnumDriverInfoW`, `SetupDiGetDriverInfoDetailW`, `SetupDiGetDriverInstallParamsW`, `SetupDiSetSelectedDriverW`, and `DiInstallDevice`.
- The declaration inventory includes six typed structure/ownership records:
  `ChatpadDeviceInfoSetHandleToken`, `SP_DEVINFO_DATA`,
  `SP_DEVINSTALL_PARAMS_W`, `SP_DRVINFO_DATA_W`,
  `SP_DRVINFO_DETAIL_DATA_W`, and `DEVPROPKEY`.
- Configuration Manager, DIFx, DevCon, PnPUtil, runtime compilation, native loading, and native invocation remain prohibited.
- Production adapter identity remains `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity remains `chatpad-fake-exact-instance-adapter-v1`.
- `Apply`, `Restore`, and `Restart` expose deterministic non-executing call plans but still return `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native source declarations are present, but `native_interop_implemented`, `native_compilation_permitted`, `native_loading_permitted`, `native_invocation_permitted`, `device_queries_available`, and `windows_mutation_available` remain `false`.

## Verified Results

- Exact-instance suite under Windows PowerShell 5.1: `PASS`; 171 tests, 709 assertions, zero failed tests.
- Parser inventory smoke check: `PASS`; 45 `.ps1`, eight `.psm1`, 53 total tracked PowerShell files, zero parse errors.
- Native source-boundary guard smoke check: `PASS`; 71 tracked source/build files scanned, one approved declaration match, zero forbidden matches.
- Full dual-runtime readiness, manifest generation/validation, PSScriptAnalyzer, repository safety, and final diff checks are still required before the final commit.

## Readiness And Safety

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- No driver build/link, signing, CAT generation, packaging, staging, installation, binding, loading, restoration, restart, reboot, driver-store mutation, device query, hardware access, registry, service, boot, security, trace, event-log, protocol, input, certificate, credential, production driver source/INF, frozen binary, or `legacy/` action is authorized by this source-boundary phase.

## Unresolved Blockers

- Native SetupAPI/Newdev execution remains unimplemented and explicitly blocked.
- The declaration-only source boundary requires an independent source audit before any future implementation or live authorization.
- Live readiness remains blocked until a later implementation, independent audit, and explicit live authorization complete.
