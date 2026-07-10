# TASK 8F-2 — Independent read-only audit of the gated production native-adapter backend source

## Current state

- **Required branch:** `feature/native-adapter-production-backend-source`.
- **Starting commit:** the TASK 8F-1 commit with subject `feat: implement gated production native adapter backend`; verify its exact hash and parent with Git.
- **Evidence:** `docs/evidence/native-adapter-production-backend-source-task-8f-1.json`.
- **Manifest section:** `gated_production_native_adapter_backend`.
- **Current blocker:** `BLOCKED_NATIVE_ADAPTER_PRODUCTION_BACKEND_NOT_INDEPENDENTLY_AUDITED`.
- **Live readiness:** `BLOCKED`.

## Preconditions

- Verify branch, HEAD, parent, clean worktree/index, upstream `0/0`, and the matching remote branch before audit conclusions.
- Confirm TASK 8E is independently closed and its evidence, source, and focused-test identities remain unchanged.
- Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest relevant `docs/WORKLOG.md` entries.

## Audit scope

- Read-only inspection only: do not edit, stage, commit, push, execute native APIs, query a live device, bind, mutate Windows, install, load, restart, rollback, restore, package, sign, build, or open compile outputs.
- Verify the four public exports are unchanged; the production backend module exports nothing; no default provider, SessionState object, or public capability can enable it.
- Verify exact ordered targets, ContainerId, confirmation ID, 13 allowed declarations, recording-shim ordering/arguments, failure-stop behavior, cleanup order, and zero counters.
- Run the TASK 8E and TASK 8F focused tests under PowerShell 7 and Windows PowerShell, the canonical readiness validator, and `-RunTask8FRegression` without live access.

## Acceptance criteria

- Report `PASS` only if evidence/source/test hashes, manifest section, validator, regression, and both-runtime results match exactly with zero defects.
- Confirm no live query, native invocation, SetupAPI/Newdev call, binding, mutation, rollback, restore, driver action, artifact access, or compile-output access occurred.
- Do not create an acceptance or lane-close commit in this audit; report findings and leave the repository immutable.
