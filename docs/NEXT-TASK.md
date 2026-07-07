# Next Task

## Objective

Perform an independent strict read-only audit of the exact-instance binding
implementation authorization design-gate commit.

This next task is not binding implementation, binding execution, dry-run
execution, native execution, SetupAPI/Newdev invocation, Windows mutation,
driver action, live observation, hardware access, or artifact/compile-output
access.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit before this authorization design-gate transition:
  `3ffe4d5e7cc33ec454b0f145353a86c8cd07f7b6`.
- Required commit subject:
  `docs: open binding implementation authorization gate`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Authorization design-gate evidence path:
  `docs/evidence/exact-instance-binding-implementation-authorization-design-gate.json`.
- Authorization design-gate evidence schema:
  `chatpad-exact-instance-binding-implementation-authorization-design-gate-v1`.
- Authorization design-gate status:
  `EXACT_INSTANCE_BINDING_IMPLEMENTATION_AUTHORIZATION_DESIGN_GATE_OPENED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`.
- Source dry-run result evidence path:
  `docs/evidence/exact-instance-binding-dry-run-result.json`.
- Source dry-run result status:
  `DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`.
- Source execution-gate evidence path:
  `docs/evidence/exact-instance-binding-dry-run-execution-gate.json`.
- Source execution-gate status:
  `EXACT_INSTANCE_BINDING_DRY_RUN_EXECUTION_GATE_OPENED_NO_EXECUTION_NO_MUTATION_NO_NATIVE_IO`.
- Source dry-run design evidence path:
  `docs/evidence/exact-instance-binding-dry-run-design.json`.
- Source dry-run design status:
  `EXACT_INSTANCE_BINDING_DRY_RUN_DESIGN_COMPLETED_NO_EXECUTION_NO_MUTATION_NO_NATIVE_IO`.
- Source design-gate evidence path:
  `docs/evidence/exact-instance-binding-implementation-design-gate.json`.
- Source design-gate status:
  `EXACT_INSTANCE_BINDING_IMPLEMENTATION_DESIGN_GATE_OPENED_NO_NATIVE_IO_NO_MUTATION`.
- Source analysis evidence path:
  `docs/evidence/exact-instance-binding-analysis.json`.
- Source analysis status:
  `EXACT_INSTANCE_BINDING_ANALYSIS_COMPLETED_FROM_ACCEPTED_OBSERVATION_NO_NATIVE_IO_NO_MUTATION`.
- Source observation evidence path:
  `docs/evidence/live-readonly-equipment-observation.json`.
- Source observation status:
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_CAPTURED_NO_MUTATION_NO_NATIVE_IO`.
- Source gate status:
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_GATE_OPENED_NO_DEVICE_IO`.
- Verifier lane closeout:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted three-node target chain:
  `USB\VID_045E&PID_028E\1C21F10` ->
  `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00` ->
  `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`.
- Shared ContainerId: `{828F4587-006F-5AD1-B169-6AF57905DFDE}`.
- Target InstanceId:
  `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`.
- Accepted dry-run result:
  `DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`.
- Manifest schema:
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Manifest entries: `46`.
- Blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Binding implementation status: `NOT_IMPLEMENTED`.
- Binding implementation authorized: `false`.
- Binding implementation performed: `false`.
- Binding execution performed: `false`.
- Dry-run performed in this task: `false`.
- New live observation performed: `false`.
- Device query performed: `false`.
- Hardware access performed: `false`.
- Artifact opening/access: `false`.
- Artifact/compile-output I/O: `false`.
- Compile-output hash verification: `false`.
- Metadata parsing: `false`.
- Native library load count: `0`.
- Entry-point resolution count: `0`.
- SetupAPI/Newdev invocation count: `0`.
- Windows mutation count: `0`.
- Driver action count: `0`.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, target commit identity, parent,
   upstream, remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/DECISIONS.md`, if changed for the durable decision record
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-implementation-authorization-design-gate.json`
3. Confirm no tool, source, INF, project, solution, parser, verifier,
   offline-suite, packaging, signing, staging, deployment, binary, artifact,
   frozen-output, or `legacy/` path changed.

## Audit Scope

- Verify target commit Git identity.
- Verify authorization design-gate evidence file schema and status.
- Verify source dry-run result evidence reference.
- Verify source execution-gate evidence reference.
- Verify source dry-run design evidence reference.
- Verify source design-gate evidence reference.
- Verify source analysis evidence reference.
- Verify source observation evidence reference.
- Verify accepted dry-run result.
- Verify accepted three-node target chain.
- Verify target InstanceId.
- Verify future authorization purpose.
- Verify future implementation target.
- Verify required source evidence chain.
- Verify future authorization preconditions.
- Verify rejection/no-op conditions.
- Verify operator confirmation package requirements.
- Verify rollback/no-op plan requirements.
- Verify future authorization evidence requirements.
- Verify future audit requirements.
- Verify no binding implementation.
- Verify no binding execution.
- Verify no dry-run performed in this task.
- Verify no new live observation.
- Verify no device query.
- Verify no hardware access.
- Verify no native execution.
- Verify no SetupAPI/Newdev invocation.
- Verify no native library load.
- Verify no entry-point resolution.
- Verify no Windows mutation.
- Verify no driver action.
- Verify no artifact/compile-output access.
- Verify live readiness remains `BLOCKED`.
- Verify native execution remains `NOT_IMPLEMENTED`.
- Verify execution authorized remains `false`.

## Safety Restrictions

This audit is strict read-only. Do not perform new live observation. Do not run
device query commands, hardware access commands, binding execution, dry-run
execution, native adapter execution, SetupAPI/Newdev, verifier behavior tests,
offline-suite behavior tests, the static parser, the full compile-output
validator, generator, full exact/readiness suites, build, package, sign,
install, load, bind, restore, restart, `pnputil`, `devcon`, driver/service
mutation, or artifact/compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the
  exact authorization design-gate transition without self-reference.
- Authorization design-gate evidence JSON and manifest JSON parse successfully.
- Manifest validation passes with schema
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Authorization design-gate evidence schema/status, source evidence
  references, accepted dry-run result, accepted target chain, target
  InstanceId, future authorization purpose, future implementation target,
  required source evidence chain, future authorization preconditions,
  rejection/no-op conditions, operator confirmation package requirements,
  rollback/no-op plan requirements, future authorization evidence
  requirements, future audit requirements, explicit safety statements, and
  safety counters match the evidence record.
- Documentation consistency, prohibited executable pattern search,
  changed-path safety, forbidden vocabulary scan, spelling-variant scan, and
  `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
8. `docs/evidence/exact-instance-binding-implementation-authorization-design-gate.json`
9. `docs/evidence/exact-instance-binding-dry-run-result.json`
10. `docs/evidence/exact-instance-binding-dry-run-execution-gate.json`
11. `docs/evidence/exact-instance-binding-dry-run-design.json`
12. `docs/evidence/exact-instance-binding-implementation-design-gate.json`
13. `docs/evidence/exact-instance-binding-analysis.json`
14. `docs/evidence/live-readonly-equipment-observation.json`
15. `docs/evidence/runtime-bringup-readiness-manifest.json`
