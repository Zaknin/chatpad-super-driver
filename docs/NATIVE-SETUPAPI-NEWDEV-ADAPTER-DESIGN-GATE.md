# Native SetupAPI/Newdev Adapter Design Gate

## Status

This branch contains a source-level, declaration-only SetupAPI/Newdev interop boundary and an isolated non-production compile-only validation harness. The accepted declarations compile cleanly in that harness, but the compiled output is not loaded, executed, reflected over, invoked, installed, bound, restored, restarted, used to query devices, used to mutate Windows, or used for driver behavior.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution status: `NOT_IMPLEMENTED`.
- Execution design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Static metadata lane: `ACCEPTED_CLOSED` at
  `cb80939a862d33efb1abf26a14d5c75d43a77b30`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries, native operations, and Windows mutations performed: `0`.
- Source audit verdict: `AUDIT PASS` for audited commit
  `dbba70d74e99c211d47187697e19e528b381520a`.
- Remediated compile-only validation and independent re-audit: `AUDIT PASS` at
  `3e922470f2e46d5eeb4b6fe7500c4f105c608b3b`; evidence
  `docs/evidence/native-interop-compile-only-validation.json`; validation ID
  `native-interop-compile-only-20260703T194533Z`.
- Independent audit of design-gate commit
  `dddd4afab914c1929de5683d6822fde5cbf46c6a`: `AUDIT FAIL`. The fail-closed
  operation path called the full compile-output evidence validator, which
  opened and hashed the real DLL.
- Independent audit of remediation commit
  `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`: `AUDIT PASS`. The audit traced
  17 transitive functions, found the record-only validator reachable, and
  found the full compile-output validator, `Get-FileHash`, output enumeration,
  and native/file loading members unreachable. Design-gate operations use
  tracked evidence records only in mode
  `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.

Authoritative source files:

- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`
- `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`
- `tools/ExactInstance/CompileOnlyValidation/Chatpad.NativeInterop.CompileOnlyValidation.csproj`
- `tools/ExactInstance/CompileOnlyValidation/CompileOnlyContracts.cs`

## Native Adapter Execution Definition

Native adapter execution means that repository code crosses from deterministic
planning or declaration inspection into any runtime use of SetupAPI or Newdev.
The boundary includes loading a native library, resolving an entry point,
creating or opening a device-information set, querying a device, enumerating or
selecting driver nodes, invoking `DiInstallDevice`, releasing native handles,
or performing any related Windows, device, package, restart, or recovery
action.

The current PowerShell adapter remains non-executing. Its `Apply`, `Restore`,
and `Restart` operations return
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`; no public or exported
function accepts caller-supplied authority that can change that result. This
design gate does not implement native execution and does not authorize a live
run.

The failed audit found that the blocked operation result still reached
`Test-ChatpadNativeInteropCompileOnlyValidationEvidence`, whose compile-output
identity checks call `Get-FileHash` on produced files, including the real DLL.
The remediated operation path instead calls the explicit record-only validator.
It reads only the tracked compile-only evidence JSON and tracked readiness
manifest, compares their recorded path, size, SHA-256, status, and safety
claims, and never stats, scans, opens, reads, hashes, parses, writes, loads,
reflects over, or executes any recorded compile output. The full compile-output
validator remains available only for separately authorized artifact-validation
contexts and is unreachable from fail-closed design-gate operations and probes.

## Fail-Closed Authorization State Model

The execution state model is:

1. `BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT`: the design and
   manifest contract existed but had not yet received independent acceptance.
2. `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`: the fail-closed,
   no-artifact-I/O design gate is accepted, but no native implementation is
   available. This is the current state.
3. Design-audit acceptance authorizes only a separate non-live implementation
   task. It does not authorize execution.
4. A future implementation-audit gate may accept non-live implementation
   evidence only. It must not authorize execution.
5. A future live-execution authorization must name the exact implementation,
   device instance, artifact/package, operation, host/session, rollback plan,
   evidence root, and permitted Windows mutations.

Missing, expired, malformed, mismatched, replayed, caller-created, synthetic,
or partially validated authorization fails closed before native library load,
entry-point resolution, device query, or mutation. Elevation, branch name,
command-line intent, public strings, Boolean switches, object possession,
module state, and prior audit success are never execution authority.

## Prerequisites Before Native Execution

Every item below requires separate evidence and acceptance:

1. An independently audited implementation with no caller-controlled
   authorization surface.
2. Exact-instance binding using one complete canonical Plug and Play instance
   ID, reopened and compared ordinally before every operation.
3. An approved device snapshot proving class, container, parent, location,
   hardware/compatible IDs, status/problem code, current driver, and immutable
   driver-node identity.
4. An approved artifact and package identity: canonical paths, byte sizes,
   SHA-256 values, INF/catalog/signature identity, architecture, model/install
   section, provider, service, and exact target/prior driver-node identities.
5. An independently audited rollback/recovery plan that restores the exact
   prior driver, treats uncertain post-mutation state as manual recovery, and
   never substitutes a first, best, newest, or merely compatible driver.
6. Explicit Windows-mutation authorization scoped to one operation, instance,
   host/session, and evidence root.
7. Separate package, signing, catalog, staging, installation, restart, or
   reboot authorization whenever the approved operation needs it.
8. A live-evidence contract that binds inputs, ordered native calls, Win32
   results, cleanup, postconditions, counters, and terminal state.

Any unmet prerequisite returns a blocked result with every native/device/
Windows/driver action counter unchanged.

## Future Call Scope

The proposed exact-instance Apply/Restore implementation may eventually use
only the reviewed call family:

- opening and canonical identity/property capture through
  `SetupDiCreateDeviceInfoList`, `SetupDiOpenDeviceInfoW`,
  `SetupDiGetDeviceInstanceIdW`, `SetupDiGetDevicePropertyW`, and
  `SetupDiGetDeviceRegistryPropertyW`;
- exact compatible-driver list construction and inspection through
  `SetupDiBuildDriverInfoList`, `SetupDiEnumDriverInfoW`,
  `SetupDiGetDriverInfoDetailW`, and
  `SetupDiGetDriverInstallParamsW`;
- exact selected-node association through `SetupDiSetSelectedDriverW`;
- exact-device installation through `DiInstallDevice`; and
- deterministic cleanup through `SetupDiDestroyDriverInfoList` and
  `SetupDiDestroyDeviceInfoList`.

This is design scope, not invocation authorization. Any missing declaration,
including future device-install-parameter APIs needed to constrain an INF
search, requires its own source change, compile-only validation, and
independent audit before implementation acceptance.

Restart remains a separate future exact-device operation with no current API
declaration or execution path.

## Calls And Actions Still Forbidden

Until future explicit authorization, the following remain forbidden:

- loading `setupapi.dll`, `newdev.dll`, or another native library;
- resolving or invoking any native entry point or P/Invoke declaration;
- device enumeration, device query, handle creation, or property retrieval;
- `DiInstallDriver`, `UpdateDriverForPlugAndPlayDevices`, Configuration
  Manager mutation, DIFx, PnPUtil, DevCon, WMI/CIM mutation, registry/service
  mutation, broad rescans, or class/hardware-ID-wide selection;
- USB, HID, IOCTL, PnP, power, restart, reboot, or hardware operations; and
- driver build, link, sign, CAT generation, package, stage, install, load,
  unload, bind, restore, or restart.

## Future Safety Counters

Future attempt evidence must record exact integer counters for authorization
rejections, native library load attempts/successes, entry-point resolution
attempts/successes, SetupAPI/Newdev calls by entry point, device queries,
selected-driver mutations, install calls, cleanup attempts/failures,
postcondition queries/failures, rollback attempts/results, restart/reboot
requirements, Windows mutations, driver actions, uncertain-state events, and
unexpected exceptions. A design, implementation, or live audit must reject
missing, non-integer, negative, inconsistent, or unaccounted counters.

The current design-gate manifest records zero native library loads, entry-point
resolutions, SetupAPI/Newdev invocations, device queries, Windows mutations,
driver actions, authorization attempts, and uncertain-state events.

During design-gate audits and fail-closed probes, the real compile-only DLL
must not be opened, read, hashed, parsed, written, loaded, reflected over, or
executed. Those probes may read tracked JSON evidence records only. They must
not scan the compile-output directory or verify a recorded output identity
against the live output file.

## Required Independent Audits

Independent design audit must verify the complete contract, exact status
vocabulary, fail-closed prerequisites, call allowlist, forbidden operations,
counter requirements, documentation consistency, manifest validation, and
absence of an executable path.

Any later implementation requires a separate independent source and
adversarial audit covering malformed/missing authorization, identity drift,
duplicate/ambiguous driver nodes, cleanup failure, post-mutation uncertainty,
replay, public API shape, module-state introspection, and proof that no live
operation can occur before a distinct exact live-run authorization.

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
`468e8679388481e923a37a985055046f72480921`, and the remediated implementation
passed independent audit at `f0be4746ad4cc548334336c1e66f07007b71859f`.
The native-adapter execution design gate and no-artifact-I/O remediation passed
independent audit at `d71c6a46b0066eb8bc48e8de14795c223cdaa00c` and are
accepted and closed. No task may open, hash, or parse compiled output, load or reflect over it,
resolve entry points, invoke native APIs, query devices, or mutate Windows
unless that exact action is later authorized. The current gate is
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`; the capability blocker has
the same value; live readiness remains `BLOCKED`; native execution remains
`NOT_IMPLEMENTED`. The next implementation/scaffolding step requires separate
authorization and independent audit and must remain non-live and fail-closed.
