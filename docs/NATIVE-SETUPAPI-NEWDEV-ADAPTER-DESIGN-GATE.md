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
- Fail-closed scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Fail-closed scaffolding commit:
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.
- Scaffolding-audit remediation commit:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Fail-closed scaffolding audit acceptance:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Scaffolding-audit acceptance commit:
  `748ba24b3e795cd70b3325b6a54fb88569427ed6`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live implementation commit:
  `4522510a17354fe53d163546e16ff24af5fa0374`.
- Non-live implementation audit acceptance:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live planning audit-acceptance commit:
  `bb6cc27c2281e04dee2166c5a67e124092055f9f`.
- Execution-scope boundary status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Execution-scope boundary commit:
  `4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
- Execution-scope boundary audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-scope boundary audit target:
  `f0b10d862d23d0ede28b1139c2ccb726bfcddc48`.
- Execution-scope boundary lane closeout:
  `AUDIT_PASS_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted lane-closeout audit target:
  `d1372ba8f7812d24a09b87238793e78435ac4492`.
- Execution-scope boundary lane-closeout commit:
  `e68ed58e3c5a2560c331f4b69dfe021ae54531e1`.
- Closeout-identity audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_BOUNDARY_CLOSEOUT_IDENTITY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted closeout-identity audit target:
  `9c9af5cf0cfdffde67a0f2b4e41e8eceb42d673f`.
- Final lane closeout:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted final-closeout audit target:
  `f7f6041d6987ea8e3752546bd4c9116c88fbe56a`.
- Accepted execution scope-boundary final-closeout commit:
  `68099a441db5f8b517dbeb296ab234a9ee639bdb`.
- Execution-envelope verifier:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.
- Execution-envelope verifier audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit target:
  `4849d1959cab9c289952655eb73e3279117779d2`.
- Execution-envelope verifier audit-acceptance audit pass:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-acceptance audit target:
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Execution-envelope verifier audit pass recorded:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass target:
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Execution-envelope verifier audit-pass acceptance:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass record target:
  `b64a672984b6e7db16765f13de385b22f3491f11`.
- Execution-envelope verifier audit-pass acceptance audit pass:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass acceptance audit target:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Execution-envelope verifier audit-pass acceptance audit accepted:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass acceptance audit-pass target:
  `ba952444d9d3e306da8985e25b93b74aa5f6cff6`.
- Execution-envelope verifier lane closeout:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier lane-closeout audit target:
  `e271e5c8dd464ba0aeee82e4dc163b12ae28b8de`.
- Prior execution-envelope verifier audit-pass acceptance audit accepted target:
  `ba952444d9d3e306da8985e25b93b74aa5f6cff6`.
- Prior accepted execution-envelope verifier audit-pass acceptance audit target:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Prior execution-envelope verifier audit-pass record target:
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Prior execution-envelope verifier audit-pass transition target:
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Accepted non-live planning audit target:
  `5e7a6f39d0363121b8bd3f6e4b38ceb517889679`.
- Accepted scaffolding audit target:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
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
- Fail-closed scaffolding added at
  `7560fc242a39228d6a95f42ff908bb4be438d6ad` on branch
  `feature/native-adapter-fail-closed-scaffolding` adds inert operation
  request, evidence-state, authorization-state, and deterministic blocked
  execution-result records. It does not add native implementation, artifact
  I/O, live device lookup, Windows mutation, or driver action.
- The independent audit of that commit returned `AUDIT FAIL` only because
  current-state documentation omitted the exact scaffolding commit. The
  technical fail-closed and no-artifact-I/O checks passed.
- The separately authorized non-live implementation phase adds only inert
  operation plans, in-memory precondition evaluation, an always-deny
  authorization decision, and typed blocked results with zero counters. Target
  identity is not resolved and no execution or artifact-I/O boundary is crossed.

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

The fail-closed scaffolding records the requested operation, target identity,
evidence state, authorization state, planned call family, and zero action
counters for audit. Target identity fields are inert request data and do not
trigger enumeration, property reads, current-driver inspection, package
selection, or any live lookup. Unsupported operations return
`UNSUPPORTED_NATIVE_ADAPTER_OPERATION`. Missing or malformed tracked evidence,
missing authorization, stale authorization, design-gate-only authorization, and
future-live authorization all fail closed before any artifact, native, device,
Windows, or driver boundary.

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

The current fail-closed scaffolding intentionally rejects every authorization
shape, including future-live-looking records. It exposes authorization state
only as evidence that execution is not authorized under this branch.

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

## Future Execution Authorization Envelope

Status: `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
The exact scope-boundary commit is
`4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
This record-only boundary is opened from accepted non-live planning
audit-acceptance commit `bb6cc27c2281e04dee2166c5a67e124092055f9f`.
The current repository does not satisfy the envelope, and this task grants no
execution or artifact-access authority.

A future implementation or execution authorization is valid only when one
immutable envelope contains every field below and an independent audit accepts
the complete envelope. Partial records, defaults, wildcards, caller-created
objects, branch identity, elevation, prior audit results, or operator intent do
not satisfy any field.

1. **Authorization statement:** one exact statement names exactly one operation
   class: `NATIVE_ADAPTER_APPLY`, `NATIVE_ADAPTER_RESTORE`, or
   `NATIVE_ADAPTER_RESTART`. It also binds the implementation commit, host,
   session, expiry, evidence root, and envelope hash. An umbrella or multi-
   operation statement is invalid.
2. **Real artifact identity:** one approved canonical absolute path, positive
   byte size, and 64-character uppercase SHA-256 must be recorded together with
   artifact-origin evidence. These values are absent in the current boundary;
   the real DLL and compile outputs remain inaccessible.
3. **Native entry-point allowlist:** an exact ordered, library-qualified list
   with no wildcard must be present. It must be a subset of the reviewed
   declaration ceiling and must bind each entry point to the selected operation.
4. **SetupAPI/Newdev function allowlist:** an exact ordered subset of
   `SetupDiCreateDeviceInfoList`, `SetupDiDestroyDeviceInfoList`,
   `SetupDiOpenDeviceInfoW`, `SetupDiGetDeviceInstanceIdW`,
   `SetupDiGetDevicePropertyW`, `SetupDiGetDeviceRegistryPropertyW`,
   `SetupDiBuildDriverInfoList`, `SetupDiDestroyDriverInfoList`,
   `SetupDiEnumDriverInfoW`, `SetupDiGetDriverInfoDetailW`,
   `SetupDiGetDriverInstallParamsW`, `SetupDiSetSelectedDriverW`, and
   `DiInstallDevice` must be present. This declaration ceiling is not a current
   invocation allowlist. Any other function requires a separately authorized
   declaration/design change and audit.
5. **Device binding:** one complete canonical Plug and Play instance ID,
   approved snapshot identity, target and prior driver-node identities, and an
   ordinal reopen comparison immediately before the operation are required.
   Enumeration, hardware-ID-wide selection, ambiguity, or identity drift fails
   closed.
6. **Dry-run evidence:** independently audited no-mutation evidence must bind
   the envelope, planned ordered calls, preconditions, expected postconditions,
   cleanup, and zero artifact/native/device/Windows/driver action counters.
7. **Rollback/restore plan:** the exact prior driver identity, ordered rollback
   calls, cleanup obligations, verification steps, stop conditions, and manual-
   recovery procedure for uncertain state must be independently accepted.
8. **Windows mutation classification:** every proposed call must have an exact
   mutation class, precondition, postcondition, failure state, cleanup duty,
   and integer attempt/success/failure counter. Unclassified mutation is
   forbidden.
9. **Operator confirmation:** an explicit single-operation confirmation must
   bind the envelope hash, exact instance, artifact identity, host/session,
   operation class, and expiry. Generic consent or interactive presence is not
   authority.
10. **Independent audits:** an audit is required before any implementation is
    accepted and another audit is required after implementation but before any
    execution authorization can be considered. Implementation audit success is
    not execution authorization.

The current repository has no approved real-artifact identity in this
envelope, no native-entry-point or SetupAPI/Newdev invocation allowlist, no
device-bound operator confirmation, and no accepted implementation. Therefore
the envelope is unsatisfied. Artifact access, native loading, entry-point
resolution, SetupAPI/Newdev invocation, device query, hardware access, Windows
mutation, and driver actions remain forbidden.

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

Focused fail-closed scaffolding coverage adds 16 checks under both Windows
PowerShell 5.1 and PowerShell 7 for blocked `Apply`, `Restore`, and `Restart`;
unsupported operation rejection; missing and malformed evidence rejection;
missing, malformed, stale, design-gate, and future-live authorization
rejection; inert target identity handling; and zero native/device/Windows/
driver/artifact counters. The no-artifact-I/O regression traces 11 functions
and requires zero forbidden commands.

Focused non-live planning coverage adds 16 checks under both runtimes for three
blocked plans, always-deny authorization, invalid evidence/operation rejection,
inert target identity, and typed zero-counter results. The expanded
no-artifact-I/O regression traces 15 functions and requires zero forbidden
commands.

## Record-only execution-envelope verifier

`Test-ChatpadNativeAdapterExecutionAuthorizationEnvelope` validates only inert
declared values. The exact schema binds one Apply, Restore, or Restart
operation; a future authorization statement; declared artifact path, size, and
SHA-256; native and SetupAPI/Newdev name allowlists; device and driver
identifiers; tracked dry-run evidence identifiers and `docs/evidence/` paths;
rollback/restore declarations; Windows-mutation classification; operator
confirmation; pre- and post-implementation audit requirements; and the current
denial `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

The verifier uses exact property whitelists and rejects unknown fields,
wildcards, invalid numeric types, missing records, malformed nested records,
expired records, future/live authorization vocabulary, and any current
execution-authorized claim. A structurally complete envelope is still blocked.
Every result sets execution authorization false, native execution
`NOT_IMPLEMENTED`, live readiness `BLOCKED`, artifact and compile-output I/O
false, and all native/device/hardware/Windows/driver counters to zero.

The verifier is not connected to production operation dispatch. It does not
inspect the filesystem, real DLL, compile outputs, registry, services,
certificates, devices, hardware, drivers, or Windows state. Its implementation
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.

Independent strict read-only audit accepted verifier implementation commit
`4849d1959cab9c289952655eb73e3279117779d2`, parent
`68099a441db5f8b517dbeb296ab234a9ee639bdb`, with status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
The acceptance is record-only and does not authorize artifact access, native
loading, entry-point resolution, SetupAPI/Newdev invocation, device query,
hardware access, Windows mutation, driver action, or execution.

Independent strict read-only audit accepted verifier audit-acceptance commit
`b6bdd01588e9d72113dd9b09fcfa9baf2026424d` with transition status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
The prior verifier implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. This record does not contain the
new transition commit's own identity; the next audit must derive it from Git.
It grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

Independent strict read-only audit accepted verifier audit-pass transition
commit `f235879fe6d74dcc02dfe2e56297ef14e5a48800` with transition status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
The prior audit-pass transition target remains
`b6bdd01588e9d72113dd9b09fcfa9baf2026424d`, and the prior verifier
implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. This record does not contain the
new transition commit's own identity; the next audit must derive it from Git.
It grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

Independent strict read-only audit accepted verifier audit-pass-recording
commit `b64a672984b6e7db16765f13de385b22f3491f11` with transition status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
The prior audit-pass record target remains
`f235879fe6d74dcc02dfe2e56297ef14e5a48800`, the prior audit-pass transition
target remains `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`, and the prior
verifier implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. This record does not contain the
new transition commit's own identity; the next audit must derive it from Git.
It grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

Independent strict read-only audit accepted verifier audit-pass-acceptance
commit `75a083a684c79b729de04c770371fb6190c9c9e7` with transition status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
The accepted audit-pass record target remains
`b64a672984b6e7db16765f13de385b22f3491f11`, the prior audit-pass record target
remains `f235879fe6d74dcc02dfe2e56297ef14e5a48800`, the prior audit-pass
transition target remains `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`, and the
prior verifier implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. This record does not contain the
new transition commit's own identity; the next audit must derive it from Git.
It grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

Independent strict read-only audit accepted verifier audit-pass-acceptance
audit-pass transition commit `ba952444d9d3e306da8985e25b93b74aa5f6cff6` with
transition status
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_ACCEPTED_NO_NATIVE_IO`.
The prior accepted audit target remains
`75a083a684c79b729de04c770371fb6190c9c9e7`, the accepted audit-pass record
target remains `b64a672984b6e7db16765f13de385b22f3491f11`, the prior
audit-pass record target remains `f235879fe6d74dcc02dfe2e56297ef14e5a48800`,
the prior audit-pass transition target remains
`b6bdd01588e9d72113dd9b09fcfa9baf2026424d`, and the prior verifier
implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. This record does not contain the
new transition commit's own identity; the next audit must derive it from Git.
It grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

Independent strict read-only audit accepted verifier audit-pass-acceptance
audit-acceptance transition commit
`e271e5c8dd464ba0aeee82e4dc163b12ae28b8de`. The verifier lane is closed with
status `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
The accepted audit-pass acceptance audit-pass target remains
`ba952444d9d3e306da8985e25b93b74aa5f6cff6`, the prior accepted audit target
remains `75a083a684c79b729de04c770371fb6190c9c9e7`, the accepted audit-pass
record target remains `b64a672984b6e7db16765f13de385b22f3491f11`, the prior
audit-pass record target remains `f235879fe6d74dcc02dfe2e56297ef14e5a48800`,
the prior audit-pass transition target remains
`b6bdd01588e9d72113dd9b09fcfa9baf2026424d`, and the prior verifier
implementation audit target remains
`4849d1959cab9c289952655eb73e3279117779d2`. No work remains in this verifier
lane except independent strict read-only audit of this closeout transition. It
grants no artifact access, native loading, entry-point resolution,
SetupAPI/Newdev invocation, device query, hardware access, Windows mutation,
driver action, or execution.

## Next Boundary

The remediated compiled-artifact metadata-review design gate passed independent
audit at `49b41dad087a3d7e6f4db7f52cd51a0c17eed222`. The static parser
implementation design passed independent audit at
`468e8679388481e923a37a985055046f72480921`, and the remediated implementation
passed independent audit at `f0be4746ad4cc548334336c1e66f07007b71859f`.
The native-adapter execution design gate and no-artifact-I/O remediation passed
independent audit at `d71c6a46b0066eb8bc48e8de14795c223cdaa00c` and are
accepted and closed. Fail-closed scaffolding is now implemented as
`NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO` at
`7560fc242a39228d6a95f42ff908bb4be438d6ad`, but no task may open, hash, or
parse compiled output, load or reflect over it, resolve entry points, invoke
SetupAPI/Newdev or other native APIs, query devices, mutate Windows, or perform
driver build/sign/package/install/load/bind/restore/restart unless that exact
action is later authorized. The current gate is
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`; the capability blocker has
the same value; live readiness remains `BLOCKED`; native execution remains
`NOT_IMPLEMENTED`. `Apply`, `Restore`, and `Restart` remain blocked, and the
no-artifact-I/O regression passed. Independent strict read-only audit target
`af41a8eaeea96dcbcad75fb2e261c4352b2a468e` received `AUDIT PASS`; acceptance
status is
`NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
Acceptance does not authorize native execution, artifact I/O, device query,
Windows mutation, or driver action. The separately authorized non-live phase
implements inert planning with status
`NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO` at
`4522510a17354fe53d163546e16ff24af5fa0374`. Its first independent audit found
the technical implementation safe but failed continuity identity recording.
Independent strict read-only audit of the resulting documentation/evidence
remediation at `5e7a6f39d0363121b8bd3f6e4b38ceb517889679` returned
`AUDIT PASS`; acceptance status is
`NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`. Independent strict
read-only audit of closeout-identity audit-acceptance commit
`f7f6041d6987ea8e3752546bd4c9116c88fbe56a` returned `AUDIT PASS`. The
execution scope-boundary lane is finally closed with status
`NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO`. The next
separately authorized lane starts from accepted final-closeout commit
`68099a441db5f8b517dbeb296ab234a9ee639bdb` and implements only the record-only
execution-envelope verifier. Independent strict read-only audit of that
verifier implementation commit
`4849d1959cab9c289952655eb73e3279117779d2` returned `AUDIT PASS`; acceptance
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
Independent strict read-only audit of the audit-acceptance commit
`b6bdd01588e9d72113dd9b09fcfa9baf2026424d` returned `AUDIT PASS`; transition
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
Independent strict read-only audit of the audit-pass transition commit
`f235879fe6d74dcc02dfe2e56297ef14e5a48800` returned `AUDIT PASS`; transition
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
Independent strict read-only audit of the audit-pass-recording commit
`b64a672984b6e7db16765f13de385b22f3491f11` returned `AUDIT PASS`; transition
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
Independent strict read-only audit of the audit-pass-acceptance commit
`75a083a684c79b729de04c770371fb6190c9c9e7` returned `AUDIT PASS`; transition
status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
Independent strict read-only audit of the audit-pass-acceptance audit-pass
transition commit `ba952444d9d3e306da8985e25b93b74aa5f6cff6` returned
`AUDIT PASS`; transition status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_ACCEPTED_NO_NATIVE_IO`.
Independent strict read-only audit of that audit-acceptance transition commit
`e271e5c8dd464ba0aeee82e4dc163b12ae28b8de` returned `AUDIT PASS`; verifier
lane status is
`NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`. The next
step is an independent strict read-only audit of this closeout transition
commit, deriving its identity from Git rather than requiring the commit to
contain its own hash. No artifact, native, device, hardware, Windows, driver,
or execution authority is granted.
