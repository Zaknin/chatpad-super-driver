# TASK 8G-2 — Independent read-only audit of remediated one-shot coordinator

## Current state

- **Required branch:** `feature/native-adapter-execution-coordinator`.
- **Required starting commit:** the TASK 8G-1R5 commit with subject `fix: eliminate coordinator provider injection surface`; verify its exact hash and parent with Git.
- **Required parent:** `3baca0fb97d80ec61bae9e07fd62d12cb21e733d`.
- **Evidence:** `docs/evidence/one-shot-native-execution-coordinator-task-8g-1.json`.
- **Manifest section:** `one_shot_native_execution_coordinator`.
- **Current blocker:** `BLOCKED_NATIVE_ADAPTER_EXECUTION_COORDINATOR_NOT_INDEPENDENTLY_AUDITED`.
- **Live readiness:** `BLOCKED`.

## Preconditions

- Verify branch, HEAD, parent, clean worktree/index, upstream `0/0`, and the matching remote branch before audit conclusions.
- Confirm TASK 8E and TASK 8F are independently closed and their evidence, source, and focused-test identities remain unchanged.
- Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest relevant `docs/WORKLOG.md` entries.

## Audit scope

- Read-only inspection only: do not edit, stage, commit, push, execute native APIs, query a live device, bind, mutate Windows, install, load, restart, rollback, restore, package, sign, build, or open compile outputs.
- Verify the obsolete managed signature `Register(object key, string fingerprint, object provider)` is absent.
- Verify exact public managed signatures: `CreateRecordingAuthorization(object key, string fingerprint)` and `TryConsume(object key, string fingerprint)`.
- Verify no managed method accepts a provider parameter, production-provider descriptor, provider replacement, authorization reset, or consumed-state reset.
- Verify the coordinator obtains the provider only from the private internally-created TASK 8F recording-provider map, never from invocation-time caller input.
- Verify exact request/evidence binding, `Interlocked.CompareExchange` one-shot consumption, direct managed-boundary arbitrary/production-provider rejection, replay/transfer/forgery rejection, and zero counters.
- Verify the bounded real two-runspace race ran 16 iterations with two contenders, one winner, one provider-plan entry, one replay rejection, and zero native invocations per iteration.
- Verify direct replay rejection after normal provider failure, a thrown recording-provider-path exception, and cleanup failure, while confirming the test-local wrapper restores the private recording-call seam.
- Run TASK 8E, TASK 8F, and TASK 8G focused tests under both runtimes, the canonical validator, and `-RunTask8GRegression` without live access.

## Acceptance criteria

- Report `PASS` only if evidence/source/test hashes, exact managed signature arrays, manifest section, validator, regression, and both-runtime results match exactly with zero defects.
- Confirm no live query, native invocation, SetupAPI/Newdev call, binding, mutation, rollback, restore, driver action, artifact access, compile-output access, binary emission, or production-provider construction occurred.
- Do not create an acceptance or lane-close commit in this audit; report findings and leave the repository immutable.
