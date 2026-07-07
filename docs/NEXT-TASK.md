# Next Task

## Objective

Perform an independent strict read-only audit of the exact-instance binding
implementation design-gate commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit before the design gate:
  `3d26a70aeaa1467aabc6d47a996a9b4596bd8b6d`.
- Required commit subject:
  `docs: open exact instance binding design gate`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Design-gate evidence path:
  `docs/evidence/exact-instance-binding-implementation-design-gate.json`.
- Design-gate evidence schema:
  `chatpad-exact-instance-binding-implementation-design-gate-v1`.
- Design-gate status:
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
- Binding implementation authorized: `false`.
- Binding implementation status: `NOT_IMPLEMENTED`.
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

1. Follow `AGENTS.md`; verify exact branch, commit subject, parent, upstream,
   remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/DECISIONS.md`
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/exact-instance-binding-implementation-design-gate.json`
3. Confirm verifier behavior modules, offline-suite behavior modules, static
   parser, real artifact, compile outputs, harness/evidence policy, driver,
   INF/project/solution, packaging, signing, staging, deployment, binaries,
   tools, and `legacy/` are unchanged.

## Audit Scope

- Verify target commit Git identity, subject, parent, changed paths, and
  pushed branch.
- Verify design-gate evidence file schema and status.
- Verify source analysis evidence reference and source analysis status.
- Verify source observation evidence reference and source observation status.
- Verify source gate status and verifier lane closeout.
- Verify the accepted three-node target chain:
  `USB\VID_045E&PID_028E\1C21F10` ->
  `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00` ->
  `HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`.
- Verify the recommended future implementation target candidate is the USB HID
  interface child `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`.
- Verify allowed match predicates.
- Verify rejection predicates.
- Verify non-mutation dry-run requirements.
- Verify operator confirmation requirements.
- Verify rollback/no-op requirements.
- Verify evidence requirements.
- Verify audit requirements.
- Verify no binding implementation occurred.
- Verify no new live observation occurred.
- Verify no device query occurred.
- Verify no hardware access occurred.
- Verify no native execution occurred or was authorized.
- Verify no SetupAPI/Newdev invocation occurred or was authorized.
- Verify no native library load occurred.
- Verify no entry-point resolution occurred.
- Verify no Windows mutation occurred.
- Verify no driver action occurred.
- Verify no artifact/compile-output access occurred.
- Verify live readiness remains `BLOCKED`.
- Verify native execution remains `NOT_IMPLEMENTED`.
- Verify execution authorized remains `false`.
- Verify binding implementation remains unauthorized and not implemented.

## Safety Restrictions

This audit is strict read-only. Do not perform new live observation. Do not run
device query commands, hardware access commands, native adapter execution,
SetupAPI/Newdev, verifier behavior tests, offline-suite behavior tests, the
static parser, the full compile-output validator, full exact/readiness suites,
build, package, sign, install, load, bind, restore, restart, `pnputil`,
`devcon`, driver/service mutation, or artifact/compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  design-gate transition without self-reference.
- Design-gate evidence JSON and manifest JSON parse successfully.
- Manifest validation passes with schema
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Design-gate evidence schema, status, source evidence references, accepted
  target chain, recommended future implementation target candidate, allowed
  match predicates, rejection predicates, future dry-run requirements,
  operator confirmation requirements, rollback/no-op requirements, evidence
  requirements, audit requirements, and explicit safety counters match the
  design-gate record.
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
8. `docs/evidence/exact-instance-binding-implementation-design-gate.json`
9. `docs/evidence/exact-instance-binding-analysis.json`
10. `docs/evidence/live-readonly-equipment-observation.json`
11. `docs/evidence/runtime-bringup-readiness-manifest.json`
