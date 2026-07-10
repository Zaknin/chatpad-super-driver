# TASK 8G-2 — Independent read-only audit of the atomic one-shot production execution coordinator

## Current state

- **Required branch:** `feature/native-adapter-execution-coordinator`.
- **Starting commit:** the TASK 8G-1R4A2B commit with subject `fix: enforce atomic coordinator evidence contract`; verify its exact hash and parent with Git.
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
- Verify the four public exports are unchanged; coordinator/backend export nothing; the private reference-identity record cannot select a production provider.
- Verify exact request/evidence binding, `Interlocked.CompareExchange` one-shot consumption, real two-runspace race, replay/transfer/forgery rejection, and zero counters.
- Verify direct replay rejection after normal provider failure, a thrown recording-provider-path exception, and cleanup failure, while confirming the test-local wrapper restores the private recording-call seam.
- Run TASK 8E, TASK 8F, and TASK 8G focused tests under both runtimes, the canonical validator, and `-RunTask8GRegression` without live access.

## Acceptance criteria

- Report `PASS` only if evidence/source/test hashes, manifest section, validator, regression, and both-runtime results match exactly with zero defects.
- Confirm no live query, native invocation, SetupAPI/Newdev call, binding, mutation, rollback, restore, driver action, artifact access, or compile-output access occurred.
- Do not create an acceptance or lane-close commit in this audit; report findings and leave the repository immutable.
