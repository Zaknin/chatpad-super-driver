# Next Task

|## Objective

Independent strict read-only audit of the corrected operator confirmation collection design-gate state.

This next task is **audit-only**. It does not collect operator confirmation. It does not implement rollback. It does not perform restore. It does not implement or execute binding. It does not perform new live observation. It does not run device query commands, hardware access commands, binding execution, dry-run execution, native adapter execution, SetupAPI/Newdev, verifier behavior tests, offline-suite behavior tests, the static parser, the full compile-output validator, generator, full exact/readiness suites, build, package, sign, install, load, bind, restore, restart, `pnputil`, `devcon`, driver/service mutation, or artifact/compile-output access.

## Context: TASK 4D-CORRECTIVE Complete

TASK 4D FAIL identified critical integrity failures in the operator confirmation collection design-gate evidence state:
1. Manifest SHA-256 did not match actual evidence file hash
2. Design-gate JSON missing `future_preconditions` (0 entries, expected many)
3. Design-gate JSON missing `operator_confirmation_collection_statuses` (0 entries, expected 6 canonical statuses)
4. Design-gate JSON missing `captured_prior_identities` (0 entries, expected target/parent/child)
5. Manifest incorrectly flagged `corrective_remediation`, `evidence_updated`, `real_artifact_static_metadata_review_completed` as active true safety flags
6. NEXT-TASK.md contained prohibited references

TASK 4D-CORRECTIVE repaired all failures by:
1. Adding 20 entries to `future_preconditions`
2. Adding 6 canonical `OPERATOR_CONFIRMATION_COLLECTION_*` status strings to `operator_confirmation_collection_statuses`
3. Populating `captured_prior_identities` with target, parent, and child identities
4. Recomputing and updating manifest SHA-256 to match corrected evidence file
5. Setting all safety/action flags to false/zero in manifest section
6. Rewriting NEXT-TASK.md to audit-only scope with explicit safety statements

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Binding implementation status: `NOT_IMPLEMENTED`.
- Binding implementation authorized: `false`.
- Binding implementation performed: `false`.
- Binding execution performed: `false`.
- Prior-driver/provider identity captured: `true`.
- Operator confirmation collected: `false`.
- Rollback implemented: `false`.
- Restore performed: `false`.
- Native library load count: `0`.
- Entry-point resolution count: `0`.
- SetupAPI/Newdev invocation count: `0`.
- Windows mutation count: `0`.
- Driver action count: `0`.
- Accepted target: `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`.
- Canonical chain:
  - `USB\VID_045E&PID_028E\1C21F10`
  - `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`
  - `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`
- Shared ContainerId: `{828F4587-006F-5AD1-B169-6AF57905DFDE}`.

## Required Audit Points

Verify the operator confirmation collection design-gate explicitly:

1. `schema` equals `chatpad-exact-instance-binding-operator-confirmation-collection-design-gate-v1`.

2. `status` equals `EXACT_INSTANCE_BINDING_OPERATOR_CONFIRMATION_COLLECTION_DESIGN_GATE_OPENED_NO_OPERATOR_CONFIRMATION_COLLECTED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.

3. `readiness_classification` equals `READY_TO_DEFINE_OPERATOR_CONFIRMATION_COLLECTION_CONTRACT_ONLY`.

4. `accepted_target_chain` includes:
   - `root_composite_xbox_controller_node` with InstanceId `USB\VID_045E&PID_028E\1C21F10`
   - `usb_hid_interface_child` with InstanceId `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`
   - `hid_game_controller_child` with InstanceId `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`

5. `shared_container_id` equals `{828F4587-006F-5AD1-B169-6AF57905DFDE}`.

6. `accepted_target_instance_id` equals `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`.

7. `future_preconditions` exists and contains at least 20 entries covering: final readiness gate accepted, operator/rollback package design gate accepted, prior identity capture result accepted, dry-run result accepted, target/parent/child matches, ContainerId matches, prior identity matches, live readiness remains BLOCKED, native execution remains NOT_IMPLEMENTED, execution authorized remains false, binding implementation status remains NOT_IMPLEMENTED, rollback remains false, restore remains false, SetupAPI/Newdev count remains 0, Windows mutation count remains 0, driver action count remains 0, artifact/compile-output access remains false.

8. `operator_confirmation_collection_statuses` exists and contains exactly 6 canonical status strings:
   - `OPERATOR_CONFIRMATION_COLLECTION_COMPLETED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
   - `OPERATOR_CONFIRMATION_COLLECTION_REJECTED_TARGET_MISMATCH_NO_MUTATION`
   - `OPERATOR_CONFIRMATION_COLLECTION_REJECTED_SOURCE_EVIDENCE_INVALID_NO_MUTATION`
   - `OPERATOR_CONFIRMATION_COLLECTION_REJECTED_EXPIRED_OR_MISSING_ACK_NO_MUTATION`
   - `OPERATOR_CONFIRMATION_COLLECTION_REJECTED_UNSAFE_STATE_NO_MUTATION`
   - `OPERATOR_CONFIRMATION_COLLECTION_BLOCKED_UNAUTHORIZED_ACTION_REQUIRED_NO_MUTATION`

9. `captured_prior_identities` exists with `target`, `parent`, and `child` populated:
   - Target: provider Microsoft, version 10.0.26100.8521, service HidUsb, class HIDClass, driver key {745a17a0-74d3-11d0-b6fe-00a0c90f57da}\0086, INF input.inf
   - Parent: provider Microsoft, version 10.0.26100.8521, service xusb22, class XnaComposite, driver key {d61ca365-5af4-4486-998b-9db4734c6ca3}\0000, INF xusb22.inf
   - Child: provider Microsoft, version 10.0.26100.8521, service unavailable, class HIDClass, driver key {745a17a0-74d3-11d0-b6fe-00a0c90f57da}\0088, INF input.inf

10. `future_operator_confirmation_package_fields` contains at least 43 fields, each with `name`, `required`, `purpose` keys.

11. `remediation_added_required_fields` contains 3 items: `generated_utc`, `operator_confirmation_id`, `confirmation_expiry_utc`.

12. Safety fields: all `false`/`0` (mutation, windows_mutation, driver_action, native_io, setupapi_newdev, device_state_changed, driver_state_changed, registry_changed, driver_installed, driver_uninstalled, driver_started, driver_stopped, device_restarted, device_state_changes=0, driver_state_changes=0, device_restarts=0, driver_installs=0, driver_uninstalls=0, driver_start_stops=0).

13. Manifest section `exact_instance_binding_operator_confirmation_collection_design_gate` present with:
    - `schema` matches evidence file schema
    - `status` matches evidence file status
    - `readiness_classification` matches evidence file readiness
    - `evidence_path` equals `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json`
    - `evidence_sha256` equals canonical LF text hash of evidence file
    - `blocker` equals `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`
    - `execution_authorized` is `false`
    - `live_readiness` is `BLOCKED`
    - `native_execution_status` is `NOT_IMPLEMENTED`
    - No active true safety/action flags: `corrective_remediation`, `evidence_updated`, `real_artifact_static_metadata_review_completed` must be false or absent

14. Prohibited statements all present and explicit:
    - `current_task_does_not_collect_operator_confirmation_statement`
    - `current_task_does_not_implement_rollback_statement`
    - `current_task_does_not_perform_restore_statement`
    - `current_task_does_not_authorize_binding_implementation_statement`
    - `current_task_does_not_implement_binding_statement`
    - `current_task_does_not_execute_binding_statement`
    - `current_task_does_not_authorize_native_execution_statement`
    - `current_task_does_not_authorize_setupapi_newdev_statement`
    - `current_task_does_not_authorize_windows_mutation_statement`
    - `current_task_does_not_authorize_driver_action_statement`

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, audit target commit identity, subject, parent, upstream, remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json`
3. Confirm no tool, source, INF, project, solution, parser, verifier, offline-suite, packaging, signing, staging, deployment, binary, artifact, frozen-output, generated-output, or `legacy/` path changed.

## Audit Scope

- Verify target commit Git identity, subject, parent, changed paths, and push state.
- Verify operator confirmation collection design-gate evidence JSON and manifest JSON parse successfully.
- Verify manifest evidence hash for the operator confirmation collection design-gate evidence file matches the canonical LF text hash.
- Verify operator confirmation collection design-gate evidence schema/status/readiness classification.
- Verify `future_preconditions` contains at least 20 entries as specified.
- Verify `operator_confirmation_collection_statuses` contains exactly 6 canonical status strings.
- Verify `captured_prior_identities` contains target, parent, and child with all required fields.
- Verify `future_operator_confirmation_package_fields` contains at least 43 fields.
- Verify no operator confirmation collected.
- Verify no rollback implemented.
- Verify no restore performed.
- Verify no binding implementation authorized/performed.
- Verify no binding execution.
- Verify no live query in this task.
- Verify no device query in this task.
- Verify no identity capture in this task.
- Verify no native execution.
- Verify no SetupAPI/Newdev invocation.
- Verify no Windows mutation.
- Verify no driver action.
- Verify no artifact/compile-output access.
- Verify live readiness remains `BLOCKED`.
- Verify native execution remains `NOT_IMPLEMENTED`.
- Verify execution authorized remains `false`.
- Verify blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Safety Restrictions

This audit is strict read-only. It does not execute binding. It does not run native adapter execution. It does not run SetupAPI/Newdev. It does not perform windows mutation. It does not perform driver action. It does not perform artifact/compile-output access. It does not implement rollback. It does not perform restore. It does not collect operator confirmation. It does not authorize binding implementation. It does not authorize native execution. It does not authorize windows mutation. It does not authorize driver action. Live readiness remains `BLOCKED`. Native execution remains `NOT_IMPLEMENTED`. Execution authorized remains `false`. Blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact documentation/manifest-only operator confirmation collection design-gate state without self-reference.
- Operator confirmation collection design-gate evidence JSON and manifest JSON parse successfully.
- Design-gate evidence schema/status/readiness classification, all audit points above pass exactly.
- Manifest schema remains `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest hash for `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json` matches the evidence file canonical LF text hash.
- Documentation consistency, changed-path safety, forbidden vocabulary scan, added-line prohibited-action review, no-tool-file-change review, and `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.
