# Native SetupAPI/Newdev Adapter Design Gate

## Status

This branch contains a source-level, declaration-only SetupAPI/Newdev interop boundary and an isolated non-production compile-only validation harness. The accepted declarations compile cleanly in that harness, but the compiled output is not loaded, executed, reflected over, invoked, installed, bound, restored, restarted, used to query devices, used to mutate Windows, or used for driver behavior.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries, native operations, and Windows mutations performed: `0`.
- Source audit verdict: `AUDIT PASS` for audited commit
  `dbba70d74e99c211d47187697e19e528b381520a`.
- Compile-only validation: `PASS`; evidence
  `docs/evidence/native-interop-compile-only-validation.json`; validation ID
  `native-interop-compile-only-20260703T170511Z`.

Authoritative source files:

- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`
- `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`
- `tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj`
- `tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs`

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

The current declaration set intentionally excludes Configuration Manager APIs, DIFx APIs, DevCon, PnPUtil, WMI/CIM mutation, service mutation, runtime compilation, and native loading. The accepted source boundary has been compiled only in the isolated validation harness. It remains unloaded and uninvoked. Any future addition requires a separate authorized implementation task and independent source audit.

## Compile-Only Validation

`tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1` validates the
accepted source hashes, preprocesses the effective MSBuild graph, scans the
harness and preprocessed graph for execution/test/device/native patterns, runs
`dotnet msbuild` restore/build for the isolated library project, hashes the
temporary outputs under ignored `artifacts/compile-only/native-interop/`, and
writes tracked evidence.

The validation used target framework `net9.0-windows10.0.26100.0`, platform
`x64`, configuration `Release`, .NET SDK `9.0.315`, MSBuild
`17.14.43+2a0eb78b3`, and Roslyn `4.14.0-3.26064.1 (450493a9)`. Compiler exit
code, warning count, and error count were all `0`. The primary DLL output hash
was `1F5337976BDE45333CAF5E5D50E12A5A05F1A4B85E12E7B91A800B29F82CF0FA`.

The compile-only evidence records all prohibited action counters as false:
assembly loading, managed execution, native invocation, device query,
exact-instance access, Windows mutation, produced assembly execution, test host
execution, reflection inspection, and post-build execution.

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
- accepted source-audit gate, the historical compile-only-not-authorized gate,
  and zero live/native/device/Windows operation accounting.

G133-G152 add compile-only validation coverage for:

- harness references to the approved audited source and no copied declarations;
- no executable entry point, post-build hook, test project, runtime
  orchestration, shell/device tooling, or native execution pattern;
- valid tracked compile-only evidence, exact input hashes, output hashes,
  toolchain identity, and readiness transition;
- rejected missing/extra/duplicate inputs and rejected loading/execution claims;
- historical source-audit evidence remaining read-only; and
- current blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Next Boundary

The next task is an independent audit of the compile-only validation evidence or
a separately authorized source/design phase for native adapter execution. No
task may load compiled output, resolve entry points, invoke native APIs, query
devices, or mutate Windows unless that exact action is later authorized after
independent audit. The current blocker remains
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
