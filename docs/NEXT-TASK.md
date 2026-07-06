# Next Task

## Objective

Perform an independent strict read-only audit of the native-adapter execution
design-gate audit-acceptance transition. Verify the exact accepted vocabulary,
accepted audit facts, manifest consistency, and unchanged no-execution safety
boundary.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-design-gate`.
- Required starting commit: the commit with subject
  `docs: accept native adapter design gate audit`; verify its exact hash from
  Git and require upstream synchronization `0/0`.
- Accepted audit target: `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`.
- Failed audit target: `dddd4afab914c1929de5683d6822fde5cbf46c6a`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Static metadata lane: `ACCEPTED_CLOSED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify exact branch, HEAD, parent, upstream, `0/0`, and clean tree/index.
3. Verify the acceptance commit changed only authorized docs, manifest, and
   exact-vocabulary generator/validator/readiness files.
4. Confirm both native-adapter design-gate modules are unchanged from
   `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`.

## Audit Scope

- Verify the manifest records the exact accepted design status and complete
  audit facts for `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`.
- Verify generator and validator require exact values and reject arbitrary
  accepted statuses or incomplete audit records.
- Verify top-level and nested current gates consistently use
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Verify live readiness remains `BLOCKED`, native execution remains
  `NOT_IMPLEMENTED`, and all native/device/Windows/driver counters remain zero.
- Verify documentation contains no stale current pending-design-audit claim.

## Safety Restrictions

This is read-only. Do not run the static parser, full compile-output validator,
full exact/readiness suites, or any native/device/Windows/driver action. Do not
open, read, hash, parse, write, load, reflect over, execute, stat, or scan the
real DLL or compile outputs. Do not edit, commit, or push during the audit.

## Acceptance Criteria

- Exact accepted status and audit facts validate under Windows PowerShell 5.1
  and PowerShell 7 with zero defects.
- Manifest remains schema v4 with 39 entries, duplicate IDs/paths `0`, and
  `NO_PATH` `0`.
- No arbitrary-value acceptance or weakened validation exists.
- Native-adapter design-gate modules, parser, harness, driver, INF/projects,
  binaries, and `legacy/` are unchanged.
- Final Git status remains clean and synced `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
7. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
