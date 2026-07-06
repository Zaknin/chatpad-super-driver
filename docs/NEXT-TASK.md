# Next Task

## Objective

Perform an independent strict read-only audit of the native SetupAPI/Newdev
adapter execution design gate. Determine whether the contract is complete,
fail-closed, internally consistent, and safe to advance to a separately
authorized non-live implementation task.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-design-gate`.
- Required starting commit: the design-gate commit that follows
  `cb80939a862d33efb1abf26a14d5c75d43a77b30`; verify the exact hash from Git.
- Previous gate: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Current gate: `BLOCKED_PENDING_NATIVE_ADAPTER_EXECUTION_DESIGN_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_DEFINED_PENDING_INDEPENDENT_AUDIT`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Static metadata lane: `ACCEPTED_CLOSED`.
- Static metadata acceptance commit:
  `cb80939a862d33efb1abf26a14d5c75d43a77b30`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, exact HEAD, upstream, `0/0` synchronization, and clean status.
3. Read the current-state, decision, readiness, native-adapter design, and
   latest worklog records.
4. Verify the canonical manifest under Windows PowerShell 5.1 and PowerShell 7.
5. Confirm that native declarations, parser source/tests, compile-only harness,
   production driver source, INF, projects/solutions, binaries, ignored review
   evidence, and `legacy/` did not change.

## Audit Scope

Audit:

- the definition of native adapter execution;
- the fail-closed design/implementation/live-run gate sequence;
- exact-instance, device, artifact/package, rollback, Windows-mutation, and
  evidence prerequisites;
- proposed SetupAPI/Newdev call scope and forbidden alternatives;
- safety-counter completeness and exact numeric enforcement;
- public API and PowerShell module-state trust boundaries;
- manifest generator/validator exact vocabulary;
- deterministic blocked behavior of existing `Apply`, `Restore`, and
  `Restart` operations; and
- documentation and continuation consistency.

## Safety Restrictions

This is read-only. Do not edit, regenerate, commit, or push. Do not implement
native execution, load a native DLL, resolve an entry point, invoke a P/Invoke,
query a device, access hardware, mutate Windows, or perform driver build,
link, sign, CAT generation, package, stage, install, load, unload, bind,
restore, restart, or reboot actions.

Do not run the static metadata parser or open, read, hash, parse, write,
overwrite, load, reflect over, or execute the real compile-only DLL.

## Acceptance Criteria

- The design remains non-executing and fail-closed by construction.
- Missing, invalid, synthetic, caller-created, or mismatched authority cannot
  reach native load, resolution, query, or mutation.
- The current gate is pending independent design audit.
- Runtime blocker remains
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness remains `BLOCKED`; native execution remains
  `NOT_IMPLEMENTED`.
- Manifest schema remains v4 with 39 unique path-bearing entries and zero
  `NO_PATH` entries.
- Dual-runtime validation, cross-runtime identity, repository safety,
  generated-file scans, documentation searches, prohibited-pattern review,
  and `git diff --check` pass.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
8. `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
