# Next Task

## Objective

Perform an independent strict read-only audit of the live read-only observation
capture commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit before the capture:
  `cd81f875dade6fd2a7ea3a7ca3ab65b28532f54b`.
- Required commit subject:
  `docs: capture live readonly equipment observation`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree before audit: `0/0` and clean.
- Observation evidence path:
  `docs/evidence/live-readonly-equipment-observation.json`.
- Observation evidence schema:
  `chatpad-live-readonly-equipment-observation-evidence-v1`.
- Observation status:
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
- Artifact opening/access: `false`.
- Artifact/compile-output I/O: `false`.
- Compile-output hash verification: `false`.
- Metadata parsing: `false`.
- Native library load count: `0`.
- Entry-point resolution count: `0`.
- SetupAPI/Newdev invocation count: `0`.
- Windows mutation count: `0`.
- Driver action count: `0`.
- Exact-instance binding implementation: not authorized and not implemented.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, commit subject, parent, upstream,
   remote equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `docs/evidence/live-readonly-equipment-observation.json`
3. Confirm verifier behavior modules, offline-suite behavior modules, static
   parser, real artifact, compile outputs, harness/evidence policy, driver,
   INF/project/solution, packaging, signing, staging, deployment, binaries,
   tools, and `legacy/` are unchanged.

## Audit Scope

- Verify target commit Git identity, subject, parent, changed paths, and
  pushed branch.
- Verify observation evidence JSON parses and records schema
  `chatpad-live-readonly-equipment-observation-evidence-v1`.
- Verify observation status is
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_CAPTURED_NO_MUTATION_NO_NATIVE_IO`.
- Verify source gate status is
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_GATE_OPENED_NO_DEVICE_IO`.
- Verify verifier lane remains closed with status
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Verify observed device candidates, including candidate counts and clear
  target candidate details.
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
- Verify exact-instance binding implementation is still not the next task.

## Safety Restrictions

This audit is strict read-only. Do not perform new live observation. Do not run
native adapter execution, SetupAPI/Newdev, verifier behavior tests,
offline-suite behavior tests, the static parser, the full compile-output
validator, full exact/readiness suites, build, package, sign, install, load,
bind, restore, restart, `pnputil`, `devcon`, driver/service mutation, or
artifact/compile-output access.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  observation capture transition without self-reference.
- Evidence JSON and manifest JSON parse successfully.
- Manifest validation passes with schema
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Observation evidence schema, status, source gate, verifier closeout,
  candidate inventory, and explicit safety counters match the capture record.
- Documentation consistency, positive-authorization search, prohibited
  executable-pattern search, changed-path safety, forbidden vocabulary scan,
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
8. `docs/evidence/live-readonly-equipment-observation.json`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
