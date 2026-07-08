# Next Task

## Objective

TASK 6E — final validation, stage, commit, and push operator confirmation
collection result docs/manifest/evidence.

TASK 6E must validate the result evidence, manifest section, documentation,
hashes, safety fields, and git diff, then stage, commit, and push only if the
repository state is clean and all checks pass.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`
- Required branch: `feature/native-adapter-execution-envelope-verifier`
- Required starting commit: `15925bb74f7eb5ea90f1c414b5e3ba59e0a86d99`
- Expected working tree before TASK 6E:
  - `M docs/NEXT-TASK.md`
  - `M docs/PROJECT-STATE.md`
  - `M docs/RUNTIME-BRINGUP-READINESS.md`
  - `M docs/WORKLOG.md`
  - `M docs/evidence/runtime-bringup-readiness-manifest.json`
  - `?? docs/evidence/exact-instance-binding-operator-confirmation-collection-result.json`
- Expected staged changes before TASK 6E: none.
- Live readiness remains `BLOCKED`.
- Native execution remains `NOT_IMPLEMENTED`.
- Execution authorized remains `false`.
- Binding implementation status remains `NOT_IMPLEMENTED`.
- Binding implementation authorized remains `false`.
- binding implementation/execution remains unauthorized.
- Project blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

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

## TASK 6E Validation Scope

Validate all of the following before staging:

1. Result evidence file exists and parses with Python `pathlib` using
   `encoding="utf-8-sig"`.
2. Result evidence schema, status, operator confirmation ID, operator handle,
   operator label, confirmation window, accepted target chain, and safety fields
   match the values above.
3. Manifest parses with Python `pathlib` using `encoding="utf-8-sig"`.
4. Manifest contains
   `exact_instance_binding_operator_confirmation_collection_result`.
5. Manifest section records the result evidence path, schema, status,
   uppercase evidence hash, `hash_method=canonical_lf_text_sha256`,
   operator confirmation ID, blocker, live readiness, native execution status,
   execution authorization, binding implementation status, binding
   authorization, and flat safety fields.
6. Result evidence hash matches
   `A15D6C85F92246CBF345096E5E2547D52562763953FC2C31F6556307E5335169`.
7. Documentation in `docs/PROJECT-STATE.md`,
   `docs/RUNTIME-BRINGUP-READINESS.md`, `docs/NEXT-TASK.md`, and
   `docs/WORKLOG.md` contains the required result values and safety language.
8. `git diff --check` passes.
9. Changed paths are exactly the expected six paths listed above.
10. No staged changes exist until TASK 6E intentionally stages the final set.

## Safety Restrictions

TASK 6E does not authorize binding implementation, binding execution,
native execution, SetupAPI/Newdev invocation, Windows mutation, driver action,
rollback implementation, restore, live query, device query, identity capture,
operator confirmation collection, artifact/compile-output access, generator
execution, verifier/offline behavior tests, static metadata parser execution,
or full compile-output validator execution.

No binding/native/mutation/driver/artifact actions are authorized.

## Acceptance Criteria

- Result evidence, manifest section, docs, hashes, safety fields, and git diff
  all validate exactly.
- The final staged set contains only:
  - `docs/NEXT-TASK.md`
  - `docs/PROJECT-STATE.md`
  - `docs/RUNTIME-BRINGUP-READINESS.md`
  - `docs/WORKLOG.md`
  - `docs/evidence/runtime-bringup-readiness-manifest.json`
  - `docs/evidence/exact-instance-binding-operator-confirmation-collection-result.json`
- Commit all six paths together only after validation passes.
- Push only `feature/native-adapter-execution-envelope-verifier`.
- Final report must include branch, commit hash, pushed remote branch,
  validation results, unresolved blockers, final git status, and confirmation
  that no prohibited binding/native/mutation/driver/artifact actions occurred.
