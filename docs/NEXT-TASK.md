# Next Task

## Objective

TASK 8B-4 — validate manifest/docs update for rollback/no-op package evidence

## Evidence Reference

- **Evidence path:** `docs/evidence/exact-instance-binding-rollback-no-op-package.json`
- **Schema:** `chatpad-exact-instance-binding-rollback-no-op-package-v1`
- **Status:** `EXACT_INSTANCE_BINDING_ROLLBACK_NO_OP_PACKAGE_DEFINED_NO_ROLLBACK_IMPLEMENTED_NO_RESTORE_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
- **Readiness:** `READY_FOR_ROLLBACK_NO_OP_PACKAGE_EVIDENCE_AUDIT_ONLY`
- **Evidence hash (SHA-256):** `03AA4058D9CDB6DA00ED7EF4DC3FEFB01E314438CA07974E73659B8D8C4FDCD3`
- **Hash method:** `canonical_lf_text_sha256`
- **Source commit:** `ffad232eea24fb2dcda0ce09aa6809180cad880c`
- **Operator confirmation ID:** `operator-confirmation-c445630fbb303c7c`

## Safety Summary

- **Rollback implementation** — remains unauthorized
- **Rollback package implementation** — remains unauthorized
- **Restore** — remains unauthorized
- **Binding implementation/execution** — remains unauthorized
- **Native execution** — remains NOT_IMPLEMENTED
- **Live readiness** — BLOCKED
- **Blocker** — `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`

## Forbidden Actions (do not perform or authorize)

Do not perform or authorize: rollback implementation, rollback package implementation, restore, binding implementation, binding execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, compile-output access.

## Required Validation

1. The evidence file `docs/evidence/exact-instance-binding-rollback-no-op-package.json` is unchanged and has SHA-256 `03AA4058D9CDB6DA00ED7EF4DC3FEFB01E314438CA07974E73659B8D8C4FDCD3`.

2. The manifest section `exact_instance_binding_rollback_no_op_package` exists with exact schema, status, readiness classification, evidence hash, hash method, operator confirmation ID, accepted target instance ID, shared container ID, accepted target chain, source evidence chain, package decision fields, precondition fields, safety fields, and readiness fields.

3. The accepted target chain has exactly 3 elements: `USB\\VID_045E&PID_028E\\1C21F10`, `USB\\VID_045E&PID_028E&IG_00\\8&2AF61D70&1&00`, `HID\\VID_045E&PID_028E&IG_00\\9&2E72F677&0&0000`.

4. `docs/PROJECT-STATE.md` contains the rollback/no-op package evidence section with required values.

5. `docs/RUNTIME-BRINGUP-READINESS.md` contains the rollback/no-op package evidence readiness entry.

6. `docs/NEXT-TASK.md` references TASK 8B-4 only.

7. `docs/WORKLOG.md` contains dated entry for TASK 8B-1, TASK 8B-2, and TASK 8B-3.

8. `git status` shows exactly 5 modified files and 1 untracked evidence file.

9. `git diff --check` shows no errors (line-ending warnings acceptable).

## Final Action

After validation passes:
- Stage all 5 modified files.
- Commit with subject: `docs: update manifest and docs for rollback/no-op package evidence`
- Push to `origin/feature/native-adapter-execution-envelope-verifier`.

## Acceptance Criteria

- All validation checks pass.
- No evidence file modification.
- No live/device queries performed.
- No operator confirmation collected.
- No binding/native/mutation/driver/artifact actions authorized or performed.
- Manifest section has exact required fields with correct values.
- All docs contain required tokens and safety language.
- Clean commit pushed to remote.
