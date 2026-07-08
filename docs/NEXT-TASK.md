# Next Task

## Objective

TASK 6F-RERUN — independent read-only audit of committed operator confirmation collection result after stale-doc remediation.

This task is audit-only. It must validate the committed operator confirmation
collection result state after TASK 6F-REMEDIATION repaired stale continuation
docs. Do not modify files, stage, commit, push, collect a new operator
confirmation, ask the operator to confirm, authorize binding implementation,
implement binding, execute binding, implement rollback, perform restore, run a
live or device query, perform identity capture, run native execution, invoke
SetupAPI/Newdev, mutate Windows, perform driver action, access artifacts, or
access compile outputs.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`
- Required branch: `feature/native-adapter-execution-envelope-verifier`
- Required starting commit: the TASK 6F-REMEDIATION commit created after
  `c423ced463f3bdf4cb2a295f19e687278db798e3`.
- TASK 6E result commit:
  `c423ced463f3bdf4cb2a295f19e687278db798e3`
  (`docs: record operator confirmation collection result`).
- TASK 6E parent:
  `15925bb74f7eb5ea90f1c414b5e3ba59e0a86d99`.
- TASK 6E was committed and pushed to
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Final TASK 6E git status was clean and upstream ahead/behind was `0/0`.
- TASK 6F failed only because stale continuation docs still described TASK 6E
  as pending and uncommitted.
- TASK 6F-REMEDIATION repaired `docs/PROJECT-STATE.md` and this file only for
  stale continuation state, and appended the remediation to `docs/WORKLOG.md`.
- No evidence JSON or manifest files were changed by TASK 6F-REMEDIATION.
- Live readiness remains `BLOCKED`.
- Native execution remains `NOT_IMPLEMENTED`.
- Execution authorized remains `false`.
- Binding implementation status remains `NOT_IMPLEMENTED`.
- Binding implementation authorized remains `false`.
- binding implementation/execution remains unauthorized.
- Project blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Rollback/no-op package is still required before mutation-capable work.

## Operator Confirmation Collection Result

- **Result evidence file:** `docs/evidence/exact-instance-binding-operator-confirmation-collection-result.json`
- **Result manifest section:** `exact_instance_binding_operator_confirmation_collection_result`
- **Result schema:** `chatpad-exact-instance-binding-operator-confirmation-collection-result-v1`
- **Result status:** `OPERATOR_CONFIRMATION_COLLECTION_COMPLETED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
- **Result canonical LF text SHA-256:** `A15D6C85F92246CBF345096E5E2547D52562763953FC2C31F6556307E5335169`
- **Operator confirmation ID:** `operator-confirmation-c445630fbb303c7c`
- **Operator:** `operator_handle=zaknin`, `operator_label=zak`
- **Confirmation window:** `2026-07-08T00:00:00Z` to `2026-07-18T00:00:00Z`
- **Accepted target chain:**
  - `USB\VID_045E&PID_028E\1C21F10`
  - `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`
  - `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`

## TASK 6F-RERUN Audit Scope

Validate all of the following read-only:

1. Current commit identity: branch, HEAD, parent, subject, and changed files.
2. Remote sync: upstream ahead/behind is `0/0`.
3. Git status is clean.
4. Committed result evidence exists, parses with Python `pathlib` using
   `encoding="utf-8-sig"`, and matches the schema, status, hash, operator
   confirmation ID, derivation, operator, confirmation window, accepted target
   chain, and safety fields.
5. Manifest parses with Python `pathlib` using `encoding="utf-8-sig"` and
   contains `exact_instance_binding_operator_confirmation_collection_result`
   with the committed result evidence path, schema, status, uppercase evidence
   hash, `hash_method=canonical_lf_text_sha256`, operator confirmation ID,
   blocker, live readiness, native execution status, execution authorization,
   binding implementation status, binding authorization, source template/design
   hashes, and flat safety fields.
6. Documentation in `docs/PROJECT-STATE.md`,
   `docs/RUNTIME-BRINGUP-READINESS.md`, `docs/NEXT-TASK.md`, and
   `docs/WORKLOG.md` contains the required result values and safety language.
7. Docs no longer describe TASK 6E as the pending next task or as an
   unstaged/uncommitted transition.
8. No binding/native/mutation/driver/artifact actions were authorized or
   performed.

## Safety Restrictions

TASK 6F-RERUN does not authorize binding implementation, binding execution,
native execution, SetupAPI/Newdev invocation, Windows mutation, driver action,
rollback implementation, restore, live query, device query, identity capture,
operator confirmation collection, artifact/compile-output access, generator
execution, verifier/offline behavior tests, static metadata parser execution,
or full compile-output validator execution.

No binding/native/mutation/driver/artifact actions are authorized or performed.

## Acceptance Criteria

- Git identity, changed files, clean status, and upstream sync validate.
- Result evidence, manifest section, docs, hashes, safety fields, and source
  references all validate exactly.
- `docs/PROJECT-STATE.md` and this file no longer contain stale TASK 6E
  pending/uncommitted continuation state.
- Forbidden claim scan passes:
  - no binding authorized
  - no binding implemented
  - no binding executed
  - no rollback implemented
  - no restore performed
  - no live readiness unblocked
  - no native execution implemented
  - no SetupAPI/Newdev invoked
  - no Windows mutated
  - no driver action performed
  - no artifact access performed
  - no unresolved project blockers are none
- Final report must include branch, commit hash, validation results,
  unresolved blockers, final git status, upstream sync, and confirmation that
  no prohibited binding/native/mutation/driver/artifact actions occurred.
