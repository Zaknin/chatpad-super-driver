# Next Task

## Objective

TASK 7C-2 — validate manifest/docs update and finalize rollback/no-op preparation gate evidence commit

This task must validate the manifest section, docs updates, evidence hash, safety fields, and clean staged file set for the rollback/no-op package preparation gate, then stage/commit/push after validation passes.

Do not modify the evidence file. Do not run live/device queries. Do not collect a new operator confirmation. Do not authorize rollback implementation, restore, binding implementation, binding execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, or compile-output access.

## Required Validation

1. The evidence file `docs/evidence/exact-instance-binding-rollback-no-op-package-preparation-gate.json` is unchanged and has SHA-256 `31C0FE15B864DC7121CFDE05A3032D913152FBC976E03ACCE59753719CCF388D`.

2. The manifest section `exact_instance_binding_rollback_no_op_package_preparation_gate` exists with exact schema, status, readiness classification, evidence hash, hash method, operator confirmation ID, accepted target instance ID, shared container ID, accepted target chain, source evidence chain, safety state, and readiness decision.

3. The accepted target chain has exactly 3 elements: `USB\VID_045E&PID_028E\1C21F10`, `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`, `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`.

4. `docs/PROJECT-STATE.md` contains the rollback/no-op package preparation gate section with required values.

5. `docs/RUNTIME-BRINGUP-READINESS.md` contains the rollback/no-op package preparation gate readiness entry.

6. `docs/WORKLOG.md` contains dated entries for TASK 7B, TASK 7C-0, and TASK 7C-1.

7. `git status` shows exactly 5 modified files and 1 untracked evidence file.

8. `git diff --check` shows no errors (line-ending warnings acceptable).

## Final Action

After validation passes:
- Stage all 5 modified files.
- Commit with subject: `docs: update manifest and docs for rollback/no-op package preparation gate evidence`
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
