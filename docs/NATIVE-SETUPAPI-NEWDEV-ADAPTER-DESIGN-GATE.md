# Native SetupAPI/Newdev Adapter Design Gate

## Status

This branch contains a source-level, declaration-only SetupAPI/Newdev interop boundary and an isolated non-production compile-only validation harness. The accepted declarations compile cleanly in that harness, but the compiled output is not loaded, executed, reflected over, invoked, installed, bound, restored, restarted, used to query devices, used to mutate Windows, or used for driver behavior.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries, native operations, and Windows mutations performed: `0`.
- Source audit verdict: `AUDIT PASS` for audited commit
  `dbba70d74e99c211d47187697e19e528b381520a`.
- Remediated compile-only validation and independent re-audit: `AUDIT PASS` at
  `3e922470f2e46d5eeb4b6fe7500c4f105c608b3b`; evidence
  `docs/evidence/native-interop-compile-only-validation.json`; validation ID
  `native-interop-compile-only-20260703T194533Z`.

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

The first independent compile-only audit failed because evidence recorded
LF-normalized identities while validators compared raw CRLF working-tree
bytes. All canonical LF hashes matched, so the failure was an identity-policy
portability defect rather than a declaration, output, or safety defect.

`tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1` now validates the
accepted canonical source identities, preprocesses the effective MSBuild graph, scans the
harness and preprocessed graph for execution/test/device/native patterns, runs
`dotnet msbuild` restore/build for the isolated library project, hashes the
temporary outputs under ignored `artifacts/compile-only/native-interop/`, and
writes tracked evidence.

Schema `chatpad-native-interop-compile-only-validation-v2` declares
`canonical_lf_text` for tracked UTF-8 text inputs and records both canonical
and informational raw working-tree identities. Compile outputs use
`raw_file_bytes`. `-OutputRoot` with `-NoLoad -NoReflection -NoInvoke` redirects
compile output, logs, and evidence into one ignored audit root without deleting
the canonical output; roots outside ignored `artifacts/` fail closed.

The v1 compile-output hashes recorded by
`native-interop-compile-only-20260703T170511Z` are historical ignored derived
artifacts only. They are superseded by schema v2 evidence and are not required
for acceptance. The source-input line-ending defect is reproducible from the
old evidence without preserving old DLL/PDB/NuGet/cache output bytes. If a
future audit observes old/new output hash mismatches, it must verify that the
mismatch is this documented supersession and that current evidence binds the
current outputs.

The validation used target framework `net9.0-windows10.0.26100.0`, platform
`x64`, configuration `Release`, .NET SDK `9.0.315`, MSBuild
`17.14.43+2a0eb78b3`, and Roslyn `4.14.0-3.26064.1 (450493a9)`. Compiler exit
code, warning count, and error count were all `0`. Raw output hashes are
recorded per run and are not claimed to be stable across commits or output
roots.

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

G133-G152 add the original compile-only validation coverage. G153-G170 add:

- canonical-LF identity and informational raw working-tree identity;
- missing, unknown, raw-on-text, canonical-hash, canonical-size, and alias
  corruption rejection;
- raw-byte compile-output identity and prohibited-action rejection;
- explicit supersession of historical v1 compile-output identity;
- explicit audit-root and no-load/no-reflection/no-invoke parameters; and
- preservation of the historical pending re-audit transition in compile
  evidence while the active gate advances after audit acceptance.

## Next Boundary

The remediated compiled-artifact metadata-review design gate passed independent
audit at `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`. The static parser
implementation design passed independent audit at
`468e8679388481e923a37a985055046f72480921` but remains unimplemented and not
authorized for execution. No task may open, hash, or parse compiled output, load or
reflect over it, resolve entry points, invoke native APIs, query devices, or
mutate Windows unless that exact action is later authorized. The current gate
is `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUTHORIZATION`; the
capability blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`;
native execution remains `NOT_IMPLEMENTED`.
