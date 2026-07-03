# Native SetupAPI/Newdev Adapter Design Gate

## Status

This branch contains a source-level, declaration-only SetupAPI/Newdev interop boundary. It does not compile, load, invoke, install, bind, restore, restart, query devices, mutate Windows, or execute driver behavior.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries, native operations, and Windows mutations performed: `0`.
- Source audit verdict: `AUDIT PASS` for audited commit
  `dbba70d74e99c211d47187697e19e528b381520a`.

Authoritative source files:

- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`
- `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`

## Declaration Boundary

The allowlisted declaration file contains 13 `DllImport` signatures for `setupapi.dll` and `newdev.dll` only:

- `SetupDiCreateDeviceInfoList`
- `SetupDiDestroyDeviceInfoList`
- `SetupDiOpenDeviceInfoW`
- `SetupDiGetDeviceInstanceIdW`
- `SetupDiGetDevicePropertyW`
- `SetupDiGetDeviceRegistryPropertyW`
- `SetupDiBuildDriverInfoList`
- `SetupDiDestroyDriverInfoList`
- `SetupDiEnumDriverInfoW`
- `SetupDiGetDriverInfoDetailW`
- `SetupDiGetDriverInstallParamsW`
- `SetupDiSetSelectedDriverW`
- `DiInstallDevice`

The current declaration set intentionally excludes Configuration Manager APIs, DIFx APIs, DevCon, PnPUtil, WMI/CIM mutation, service mutation, runtime compilation, and native loading. The accepted source boundary remains uncompiled, unloaded, and uninvoked. Any future addition requires a separate authorized implementation task and independent source audit.

## Structure And Ownership Boundary

The declaration inventory records typed ownership for:

- `ChatpadDeviceInfoSetHandleToken`
- `SP_DEVINFO_DATA`
- `SP_DEVINSTALL_PARAMS_W`
- `SP_DRVINFO_DATA_W`
- `SP_DRVINFO_DETAIL_DATA_W`
- `DEVPROPKEY`

The current source does not implement a `SafeHandle` release path because that would add an executable native call path. Cleanup obligations are represented in metadata and call plans only: future code must destroy the driver list and device-information set exactly once, preserve Win32 last-error before cleanup can overwrite it, and report cleanup uncertainty.

## Capability Boundary

Public strings, public mode fields, synthetic flags, elevation state, mutation switches, caller-created objects, serialized records, fake adapters, and fake wrappers are not authority. PowerShell module state is introspectable by callers in the same process and is not a security boundary.

The production adapter identity remains `chatpad-windows-exact-instance-adapter-v1`. The synthetic identity remains `chatpad-fake-exact-instance-adapter-v1` and requires explicit synthetic selection. Production is never selected implicitly.

`Apply`, `Restore`, and `Restart` return `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`. They expose deterministic planned call sequences for audit, but the plan fields explicitly state native invocation, compilation, and loading are unavailable.

## Planned Operation Sequences

`Apply` and `Restore` share the same planned native sequence:

1. `SetupDiCreateDeviceInfoList`
2. `SetupDiOpenDeviceInfoW`
3. `SetupDiGetDeviceInstanceIdW`
4. `SetupDiGetDevicePropertyW`
5. `SetupDiGetDeviceRegistryPropertyW`
6. `SetupDiBuildDriverInfoList`
7. `SetupDiEnumDriverInfoW`
8. `SetupDiGetDriverInfoDetailW`
9. `SetupDiGetDriverInstallParamsW`
10. `SetupDiSetSelectedDriverW`
11. `DiInstallDevice`
12. `SetupDiDestroyDriverInfoList`
13. `SetupDiDestroyDeviceInfoList`

`Restart` remains a future separate exact-device restart sequence and has no current restart API declaration.

## Error Taxonomy

The source-boundary metadata maps 25 controlled errors, including exact-instance absence, canonical mismatch, identity drift, access/elevation/platform blockers, property and driver-list failures, target/prior driver absence or ambiguity, selected-driver association failure, bind failures before and after possible mutation, post-bind and post-restore verification failure, restore failure, restart/reboot required, cleanup failure, unexpected native exception, and uncertain device state.

Every mapped error is retry-prohibited. Errors that may occur after mutation are marked as possible-mutation/manual-recovery cases where applicable.

## Static Guards

`Test-ChatpadNativeExecutableGuard` now distinguishes:

- approved declaration-only source matches in the allowlisted C# file; and
- forbidden declarations, runtime compilation, native loading, native invocation, driver tools, PnP cmdlets, service mutation, and build references elsewhere.

The guard passes only when the approved declaration file is isolated and forbidden matches are zero.

## Offline Gate Coverage

G1-G77 preserve the prior exact-instance and non-executing native adapter scaffold coverage.

G78-G132 add source-boundary coverage for:

- declaration inventory and DLL allowlist;
- absence of Configuration Manager, DIFx, broad install tools, runtime compiler paths, and build references;
- Unicode and `SetLastError` declaration choices;
- typed structures, constants, handle ownership token, cleanup obligations, and call-plan ordering;
- fail-closed public operation behavior with source declarations present;
- module/caller integrity and regenerated contract metadata;
- complete error mapping; and
- accepted source-audit gate, compile-only validation not authorized, and zero live/native/device/Windows operation accounting.

## Next Boundary

The next task is a separately authorized compile-only validation phase in an isolated non-production harness. That phase may validate structure layout, size, `cbSize`, marshaling metadata, and compiler diagnostics, but it must not load compiled output, resolve entry points, invoke native APIs, query devices, or mutate Windows. A compiled artifact requires a separate independent audit before loading or invocation.
