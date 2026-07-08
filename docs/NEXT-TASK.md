# Next Task

|## Objective

Re-audit the remediated operator confirmation collection design-gate (TASK 4C).

This next task is not operator confirmation collection, rollback implementation, restore execution, binding implementation, binding execution, dry-run execution, native execution, SetupAPI/Newdev invocation, Windows mutation, driver action, live observation, hardware access, identity capture, device query, live query, or artifact/compile-output access.

## Context: TASK 4B-REMEDIATION Complete

TASK 4B FAIL identified 5 gaps in the operator confirmation package specification (missing required fields, non-required fields not documented as such, status naming mismatch). TASK 4B-REMEDIATION addressed all gaps:
1. Added `generated_utc`, `operator_confirmation_id`, `confirmation_expiry_utc` to `required_fields`
2. Added target/parent/child prior-driver identity fields to future requirements
3. Added `upstream_evidence_requirements` documenting all 4 upstream evidence files
4. Replaced simplified status naming (CONFIRMED/REJECTED/NO_OP/PENDING_VERIFICATION/INSUFFICIENT_DATA/MANUALLY_REVOKED) with canonical `OPERATOR_CONFIRMATION_COLLECTION_*` vocabulary (6 canonical statuses)
5. Updated `future_package_audit_requirements` to reference remediated fields

Design-gate SHA-256 after remediation: `41d85e56a55a89e2c2f3fb2ab79ea6e77538691ef7882d4e431511125b195db1`.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required parent commit before this transition: `6af8b8ea82213235e53c8125c7b0da6f929cefef`.
- Required commit subject: `docs: add operator confirmation collection design gate evidence and manifest entry`.
- Required upstream: `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Operator confirmation collection design-gate evidence path: `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json`.
- Operator confirmation collection design-gate evidence schema: `chatpad-exact-instance-binding-operator-confirmation-collection-design-gate-v1`.
- Operator confirmation collection design-gate evidence status: `EXACT_INSTANCE_BINDING_OPERATOR_CONFIRMATION_COLLECTION_DESIGN_GATE_OPENED_NO_OPERATOR_CONFIRMATION_COLLECTED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.
- Operator confirmation collection design-gate readiness classification: `READY_TO_DEFINE_OPERATOR_CONFIRMATION_COLLECTION_CONTRACT_ONLY`.
- Manifest path: `docs/evidence/runtime-bringup-readiness-manifest.json`.
- Manifest schema: `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entries: `51`.
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
- Final readiness gate accepted: `EXACT_INSTANCE_BINDING_FINAL_IMPLEMENTATION_READINESS_GATE_OPENED_NO_OPERATOR_CONFIRMATION_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.
- Final readiness gate readiness classification: `READY_TO_PREPARE_BINDING_IMPLEMENTATION_AUTHORIZATION_TASK_ONLY`.
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

7. `operator_confirmation_package_purpose` describes the minimum operator confirmation collection package required before binding implementation authorization.

|8. `required_fields` contains exactly 3 fields (added by remediation):
   - `generated_utc`
   - `operator_confirmation_id`
   - `confirmation_expiry_utc`

9. `operator_confirmation_rejection_no_op_rules` contains exactly 6 rules:
   - CONFIRMED → authorization_task_proceeds_with_binding
   - REJECTED → binding_implementation_authorized=false, authorization_task_terminated
   - NO_OP → binding_implementation_authorized=false, authorization_task_terminated, no_action_taken
   - PENDING_VERIFICATION → authorization_task_blocked_until_verified
   - INSUFFICIENT_DATA → authorization_task_blocked_until_sufficient_data_provided
   - MANUALLY_REVOKED → authorization_task_terminated, all prior authorizations invalidated

10. `required_rollback_no_op_package_fields` contains exactly 12 fields as defined.

11. `future_prior_driver_provider_identity_requirements` contains exactly 8 requirements.

12. `future_package_evidence_requirements` contains exactly 8 requirements.

13. `future_package_audit_requirements` contains exactly 10 requirements.

14. Source evidence chain entries (5 sources) all present with correct file paths, schemas, and statuses:
    - `docs/evidence/exact-instance-binding-final-implementation-readiness-gate.json` — `EXACT_INSTANCE_BINDING_FINAL_IMPLEMENTATION_READINESS_GATE_OPENED_NO_OPERATOR_CONFIRMATION_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
    - `docs/evidence/exact-instance-binding-operator-rollback-package-design-gate.json` — `EXACT_INSTANCE_BINDING_OPERATOR_ROLLBACK_PACKAGE_DESIGN_GATE_OPENED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
    - `docs/evidence/exact-instance-binding-prior-driver-provider-identity-capture-result.json` — `PRIOR_DRIVER_PROVIDER_IDENTITY_CAPTURED_NO_MUTATION_NO_NATIVE_IO`
    - `docs/evidence/exact-instance-binding-dry-run-result.json` — `DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`
    - `docs/evidence/runtime-bringup-readiness-manifest.json` — `RUNTIME_BRINGUP_READINESS_MANIFEST_V4`

15. `binding_implementation_status` equals `NOT_AUTHORIZED`.

16. `binding_implementation_authorized` is `false`.

17. `binding_execution_performed` is `false`.

18. `native_execution` is `false`.

19. `execution_authorized` is `false`.

20. `live_readiness` is `false`.

21. `blocker` equals `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

22. Safety fields: all `false`/`0` (mutation, windows_mutation, driver_action, native_io, setupapi_newdev, device_state_changed, driver_state_changed, registry_changed, driver_installed, driver_uninstalled, driver_started, driver_stopped, device_restarted, device_state_changes=0, driver_state_changes=0, device_restarts=0, driver_installs=0, driver_uninstalls=0, driver_start_stops=0).

23. Manifest section `exact_instance_binding_operator_confirmation_collection_design_gate` present with:
    - `schema` matches evidence file schema
    - `status` matches evidence file status
    - `readiness_classification` matches evidence file readiness
    - `evidence_path` equals `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json`
    - `evidence_sha256` equals canonical LF text hash of evidence file
    - `blocker` equals `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`
    - `execution_authorized` is `false`
    - `live_readiness` is `BLOCKED`
    - `native_execution_status` is `NOT_IMPLEMENTED`

24. Prohibited statements all present and explicit:
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
- Verify source evidence chain references (final readiness gate, rollback package design gate, prior identity capture result, dry-run result, manifest).
- Verify accepted target chain and shared ContainerId.
- Verify captured target identity.
- Verify captured parent/child identity.
- Verify unavailable/skipped property summary.
|  - Verify future operator confirmation package fields (3 required_fields, 6 rejection/no-op rules with canonical OPERATOR_CONFIRMATION_COLLECTION_* vocabulary, 12 rollback no-op fields, 8 prior driver provider requirements, 8 package evidence requirements, 13 package audit requirements, 4 upstream evidence requirements).
- Verify operator confirmation package preconditions.
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

This audit is strict read-only. Do not collect operator confirmation. Do not implement rollback. Do not perform restore. Do not implement or execute binding. Do not perform new live observation. Do not run device query commands, hardware access commands, binding execution, dry-run execution, native adapter execution, SetupAPI/Newdev, verifier behavior tests, offline-suite behavior tests, the static parser, the full compile-output validator, generator, full exact/readiness suites, build, package, sign, install, load, bind, restore, restart, `pnputil`, `devcon`, driver/service mutation, or artifact/compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact documentation/manifest-only operator confirmation collection design-gate transition without self-reference.
- Operator confirmation collection design-gate evidence JSON and manifest JSON parse successfully.
- Design-gate evidence schema/status/readiness classification, all audit points above pass exactly.
- Manifest schema remains `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entry count remains `51`.
- Manifest hash for `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json` matches the evidence file canonical LF text hash.
- Documentation consistency, changed-path safety, forbidden vocabulary scan, added-line prohibited-action review, no-tool-file-change review, and `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/evidence/exact-instance-binding-operator-confirmation-collection-design-gate.json`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
