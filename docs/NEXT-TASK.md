# Next Task

## Objective

Perform an independent strict read-only audit of the final binding implementation
readiness-gate commit.

This next task is not operator confirmation collection, rollback
implementation, restore execution, binding implementation, binding execution,
dry-run execution, native execution, SetupAPI/Newdev invocation, Windows
mutation, driver action, live observation, hardware access, or artifact/
compile-output access.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required parent commit before this transition:
  `8d9cf5a8c6e9daed670e0b48d3c39e25b8de8b48`.
- Required commit subject:
  `docs: add final implementation readiness gate evidence for exact-instance-binding`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Final readiness gate evidence path:
  `docs/evidence/exact-instance-binding-final-implementation-readiness-gate.json`.
- Final readiness gate evidence schema:
  `chatpad-exact-instance-binding-final-implementation-readiness-gate-v1`.
- Final readiness gate evidence status:
  `EXACT_INSTANCE_BINDING_FINAL_IMPLEMENTATION_READINESS_GATE_OPENED_NO_OPERATOR_CONFIRMATION_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.
- Readiness classification:
  `READY_TO_PREPARE_BINDING_IMPLEMENTATION_AUTHORIZATION_TASK_ONLY`.
- Manifest path:
  `docs/evidence/runtime-bringup-readiness-manifest.json`.
- Manifest schema:
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entries: `50`.
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

## Required Audit Points

Verify the final readiness gate explicitly:

1. `accepted_target_chain` includes:
   - `root_composite_xbox_controller_node` with InstanceId
     `USB\VID_045E&PID_028E\1C21F10`
   - `usb_hid_interface_child` with InstanceId
     `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`
   - `hid_game_controller_child` with InstanceId
     `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`

2. `shared_container_id` equals `{828F4587-006F-5AD1-B169-6AF57905DFDE}`.

3. `accepted_dry_run_summary` includes:
   - `partial_vid_pid_candidate_count = 3`
   - `usb_interface_partial_candidate_count = 1`
   - `read_only_current_state_query_count = 4`
   - `allowed_predicates_passed = 16/16`

4. `target_identity_captured` includes:
   - `name = USB Input Device`
   - `class = HIDClass`
   - `service = HidUsb`

5. `parent_identity_captured` includes:
   - `name = Xbox 360 Controller for Windows`
   - `class = XnaComposite`
   - `service = xusb22`

6. `child_identity_captured` includes:
   - `name = HID-compliant game controller`
   - `class = HIDClass`

7. `unavailable_skipped_properties` recorded for all three nodes.

8. `final_readiness_checks` all `PASS` (30 checks total).

9. `remaining_blocker_count = 12`.

10. `future_required_task_sequence` has 6 steps:
    - Step 1: `INDEPENDENT_AUDIT_OF_FINAL_READINESS_GATE` (current task)
    - Step 2: `BINDING_IMPLEMENTATION_AUTHORIZATION_DESIGN`
    - Step 3: `COLLECT_OPERATOR_CONFIRMATION`
    - Step 4: `IMPLEMENT_ROLLBACK_NO_OP_PACKAGE`
    - Step 5: `BINDING_IMPLEMENTATION_EXECUTION`
    - Step 6: `INDEPENDENT_AUDIT_OF_BINDING_EXECUTION`

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, audit target commit identity,
   subject, parent, upstream, remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-final-implementation-readiness-gate.json`
3. Confirm no tool, source, INF, project, solution, parser, verifier,
   offline-suite, packaging, signing, staging, deployment, binary, artifact,
   frozen-output, generated-output, or `legacy/` path changed.

## Audit Scope

- Verify target commit Git identity, subject, parent, changed paths, and push
  state.
- Verify final readiness-gate evidence JSON and manifest JSON parse successfully.
- Verify manifest evidence hash for the final readiness-gate evidence file matches
  the canonical LF text hash.
- Verify final readiness-gate evidence schema/status.
- Verify readiness classification.
- Verify accepted dry-run summary fields listed above.
- Verify accepted three-node target chain and shared ContainerId.
- Verify target InstanceId and captured target identity fields.
- Verify captured parent and child identity fields.
- Verify unavailable/skipped property reasons.
- Verify final readiness checks all pass.
- Verify remaining blockers count and future task sequence.
- Verify live readiness remains `BLOCKED`.
- Verify native execution remains `NOT_IMPLEMENTED`.
- Verify execution authorized remains `false`.

## Safety Restrictions

This audit is strict read-only. Do not collect operator confirmation. Do not
implement rollback. Do not perform restore. Do not implement or execute
binding. Do not perform new live observation. Do not run device query commands,
hardware access commands, binding execution, dry-run execution, native adapter
execution, SetupAPI/Newdev, verifier behavior tests, offline-suite behavior
tests, the static parser, the full compile-output validator, generator, full
exact/readiness suites, build, package, sign, install, load, bind, restore,
restart, `pnputil`, `devcon`, driver/service mutation, or artifact/
compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  documentation/manifest-only readiness-gate transition without self-reference.
- Final readiness-gate evidence JSON and manifest JSON parse successfully.
- Readiness-gate evidence schema/status, readiness classification, and all
  audit points above pass exactly.
- Manifest schema remains `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entry count remains `50`.
- Manifest hash for
  `docs/evidence/exact-instance-binding-final-implementation-readiness-gate.json`
  matches the evidence file.
- Documentation consistency, changed-path safety, forbidden vocabulary scan,
  added-line prohibited-action review, no-tool-file-change review, and
  `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/evidence/exact-instance-binding-final-implementation-readiness-gate.json`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
