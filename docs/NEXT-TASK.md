# Next Task

## Objective

Perform an independent strict read-only audit of the native adapter
design-gate artifact-I/O remediation. Prove that fail-closed operations and
their audit-safe probes cannot open, read, hash, parse, write, load, reflect
over, execute, stat, or scan the real compile-only DLL or related outputs.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-design-gate`.
- Required starting commit: the remediation commit with subject
  `fix: keep native adapter design gate from hashing artifacts`; verify its
  exact hash from Git and require upstream synchronization `0/0`.
- Failed audit target: `dddd4afab914c1929de5683d6822fde5cbf46c6a`.
- Current gate: `BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_DEFINED_PENDING_INDEPENDENT_AUDIT`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Design-gate evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Static metadata lane: `ACCEPTED_CLOSED`.

## Preconditions

1. Follow `AGENTS.md` and require the exact branch, clean status/index,
   expected HEAD, upstream, and `0/0` ahead/behind state.
2. Verify the remediation commit changed only authorized paths.
3. Read the current-state, decision, readiness, native-adapter design, and
   latest worklog records.
4. Do not run the static metadata parser, full compile-output validator, full
   exact-instance suite, or full readiness suite.

## Audit Scope

- Trace every call from `Invoke-ChatpadNativeAdapterOperation`, production
  adapter construction, source-boundary contract decoration, call-plan
  decoration, and fail-closed gate probes.
- Confirm those paths call only
  `Test-ChatpadNativeInteropCompileOnlyValidationEvidenceRecordOnly`.
- Confirm the record-only validator reads only the two fixed tracked JSON
  records and compares recorded identities without any output-path I/O.
- Confirm the full compile-output validator remains unreachable from the
  design-gate path and retains its separately authorized purpose.
- Run only the isolated no-artifact-I/O regression and static checks under
  Windows PowerShell 5.1 and PowerShell 7.
- Verify manifest schema v4, 39 entries, duplicate IDs/paths 0, `NO_PATH` 0,
  dual-runtime validation, cross-runtime identity, repository safety,
  forbidden generated files, documentation consistency, and clean diff.

## Safety Restrictions

This audit is read-only. Do not open, read, hash, parse, write, overwrite,
load, reflect over, execute, stat, or scan the real DLL or related compile
outputs. Do not load native libraries, resolve entry points, invoke
SetupAPI/Newdev, query devices, mutate Windows, or perform driver build, link,
sign, CAT generation, package, stage, install, load, unload, bind, restore,
restart, or reboot actions.

## Acceptance Criteria

- Static call-chain proof shows no path from fail-closed operations/probes to
  `Get-FileHash`, output-directory enumeration, or the full validator.
- Isolated regressions return `PASS` under both runtimes with Apply, Restore,
  and Restart blocked as
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` and all action counters
  zero.
- Evidence mode is exactly `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Current gate, runtime blocker, blocked live readiness, and unimplemented
  native execution are unchanged.
- The audit performs no prohibited artifact, native, device, Windows, or
  driver action.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
8. `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
