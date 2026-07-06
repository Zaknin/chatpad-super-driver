# Next Task

## Objective

Perform an independent strict read-only audit of the fail-closed native adapter
execution scaffolding. Verify that the added request, evidence, authorization,
and deterministic execution-result paths preserve the accepted no-artifact-I/O
design gate and keep native execution unimplemented.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-fail-closed-scaffolding`.
- Required starting commit: the commit with subject
  `feat: add fail-closed native adapter scaffolding`; verify its exact hash
  from Git and require upstream synchronization `0/0`.
- Branch was created from:
  `788ce8adfd0500741783ee1e359d5f805db710dd`.
- Accepted design-gate audit target:
  `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Fail-closed scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Static metadata lane: `ACCEPTED_CLOSED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify exact branch, HEAD, parent, upstream, `0/0`, and clean tree/index.
3. Verify the implementation commit changed only authorized PowerShell
   scaffolding, focused offline tests, readiness manifest generator/validator,
   regenerated readiness manifest, and continuity docs.
4. Confirm `legacy/`, production driver source, INF/project/solution files,
   native declarations, parser implementation, and compile-only harness source
   are unchanged.

## Audit Scope

- Trace `Invoke-ChatpadNativeAdapterOperation` through the new fail-closed
  scaffolding and prove it cannot reach the full compile-output validator,
  `Get-FileHash`, compile-output enumeration, file/native loading,
  entry-point resolution, device query, Windows mutation, or driver action.
- Verify `Apply`, `Restore`, and `Restart` return
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` under both Windows
  PowerShell 5.1 and PowerShell 7.
- Verify unsupported operations return `UNSUPPORTED_NATIVE_ADAPTER_OPERATION`.
- Verify missing or malformed tracked evidence fails closed.
- Verify missing, malformed, stale, design-gate, and future-live authorization
  states fail closed and do not grant execution authority.
- Verify target identity fields are inert request data and do not trigger live
  lookup or device enumeration.
- Verify manifest generation and validation require
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.

## Safety Restrictions

This is read-only. Do not edit, commit, or push during the audit. Do not run
the static parser, full compile-output validator, full exact/readiness suites,
or any native/device/Windows/driver action. Do not open, read, hash, parse,
write, load, reflect over, execute, stat, or scan the real DLL or compile
outputs.

## Acceptance Criteria

- Focused fail-closed scaffolding checks pass under Windows PowerShell 5.1 and
  PowerShell 7 with 16/16 checks and all native/device/Windows/driver/artifact
  counters zero.
- No-artifact-I/O regression passes under both runtimes with 11/11 traced
  functions and zero forbidden commands.
- Manifest remains schema v4 with 39 entries, duplicate IDs/paths `0`,
  `NO_PATH` `0`, live readiness `BLOCKED`, native execution
  `NOT_IMPLEMENTED`, and fail-closed scaffolding status exactly
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- No arbitrary authorization status, caller-controlled token, Boolean switch,
  object possession, module state, elevation state, or prior audit success can
  authorize execution.
- Final Git status remains clean and synced `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
7. `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
8. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
10. `docs/evidence/runtime-bringup-readiness-manifest.json`
