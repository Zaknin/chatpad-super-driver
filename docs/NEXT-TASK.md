# Next Task

## Objective

TASK 8A-4 — validate manifest/docs update and finalize rollback/no-op package contract definition gate evidence commit

This task must validate the evidence file, manifest section, docs updates, evidence hash, safety fields, and clean staged file set for the rollback/no-op package contract definition gate, then stage/commit/push after validation passes.

Do not modify the evidence file. Do not run live/device queries. Do not collect a new operator confirmation. Do not authorize rollback implementation, restore, binding implementation, binding execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access, or compile-output access.

## Required Validation

1. The evidence file `docs/evidence/exact-instance-binding-rollback-no-op-package-contract-definition-gate.json` is unchanged and has SHA-256 `AD4D6D1F949E66C8847610BFFDBA5628DD9BBBF57D5BD60ED7625F30A47C6714`.

2. The manifest section `exact_instance_binding_rollback_no_op_package_contract_definition_gate` exists with exact schema, status, readiness classification, evidence hash, hash method, operator confirmation ID, accepted target instance ID, shared container ID, accepted target chain, source evidence chain, safety state, and readiness decision.

3. The accepted target chain has exactly 3 elements: `USB\VID_045E&PID_028E\1C21F10`, `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`, `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`.

4. `docs/PROJECT-STATE.md` contains the rollback/no-op package contract definition gate section with required values.

5. `docs/RUNTIME-BRINGUP-READINESS.md` contains the rollback/no-op package contract definition gate readiness entry.

6. `docs/NEXT-TASK.md` references TASK 8A-4 only.

7. `docs/WORKLOG.md` contains dated entries for TASK 8A-1, TASK 8A-2R, and TASK 8A-3.

8. `git status` shows exactly 5 modified files and 1 untracked evidence file.

9. `git diff --check` shows no errors (line-ending warnings acceptable).

## Final Action

After validation passes:
- Stage all 5 modified files.
- Commit with subject: `docs: update manifest and docs for rollback/no-op package contract definition gate evidence`
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
