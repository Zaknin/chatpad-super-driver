# Next Task

## Objective

Perform an independent strict read-only audit of the non-mutating
exact-instance binding dry-run design commit.

This next task is not dry-run implementation, dry-run execution, binding
implementation, binding execution, native execution, SetupAPI/Newdev
invocation, Windows mutation, driver action, or artifact/compile-output access.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit before the dry-run design:
  `7865356e640d08a052b9e32366f2755352a7d9c5`.
- Required commit subject:
  `docs: design exact instance binding dry run`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Dry-run design evidence path:
  `docs/evidence/exact-instance-binding-dry-run-design.json`.
- Dry-run design evidence schema:
  `chatpad-exact-instance-binding-dry-run-design-v1`.
- Dry-run design status:
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
- Manifest schema:
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Gate/runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Binding implementation status: `NOT_IMPLEMENTED`.
- Binding implementation authorized: `false`.
- Dry-run implementation status: `NOT_IMPLEMENTED`.
- Dry-run execution authorized: `false`.
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
   - `docs/DECISIONS.md`
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-dry-run-design.json`
3. Confirm no tool, source, INF, project, solution, parser, verifier,
   offline-suite, packaging, signing, staging, deployment, binary, artifact,
   frozen-output, or `legacy/` path changed.
4. Confirm `docs/evidence/exact-instance-binding-dry-run-result.json` was not
   created.

## Audit Scope

- Verify target commit Git identity.
- Verify dry-run design evidence file schema and status.
- Verify source design-gate evidence reference.
- Verify source analysis evidence reference.
- Verify source observation evidence reference.
- Verify accepted three-node target chain:
  `USB\VID_045E&PID_028E\1C21F10` ->
  `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00` ->
  `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`.
- Verify dry-run target InstanceId:
  `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`.
- Verify allowed match predicates.
- Verify rejection predicates.
- Verify dry-run decision model.
- Verify planned-action reporting requirements.
- Verify future dry-run evidence schema
  `chatpad-exact-instance-binding-dry-run-result-v1`.
- Verify future audit requirements.
- Verify no dry-run implementation.
- Verify no dry-run execution.
- Verify no binding implementation.
- Verify no binding execution.
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
device query commands, hardware access commands, native adapter execution,
SetupAPI/Newdev, verifier behavior tests, offline-suite behavior tests, the
static parser, the full compile-output validator, full exact/readiness suites,
build, package, sign, install, load, bind, restore, restart, `pnputil`,
`devcon`, driver/service mutation, or artifact/compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  dry-run design transition without self-reference.
- Dry-run design evidence JSON and manifest JSON parse successfully.
- Manifest validation passes with schema
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Dry-run design evidence schema, status, source evidence references, accepted
  target chain, dry-run target InstanceId, allowed match predicates, rejection
  predicates, dry-run decision model, planned-action reporting requirements,
  future dry-run evidence schema, future audit requirements, and explicit
  safety counters match the design record.
- Documentation consistency, positive-status search, prohibited executable
  pattern search, changed-path safety, forbidden vocabulary scan,
  spelling-variant scan, and `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
8. `docs/evidence/exact-instance-binding-dry-run-design.json`
9. `docs/evidence/exact-instance-binding-implementation-design-gate.json`
10. `docs/evidence/exact-instance-binding-analysis.json`
11. `docs/evidence/live-readonly-equipment-observation.json`
12. `docs/evidence/runtime-bringup-readiness-manifest.json`
