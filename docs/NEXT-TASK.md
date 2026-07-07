# Next Task

## Objective

Perform an independent strict read-only audit of the live read-only equipment
observation gate-opening commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit: derive the exact full hash from Git and require
  subject `docs: open live readonly observation gate`.
- Required parent:
  `a38264fa06db15a36ed46f0ac8daba9cdecf1ba9`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree: `0/0` and clean.
- Verifier lane closeout:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Live read-only equipment observation gate:
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_GATE_OPENED_NO_DEVICE_IO`.
- Manifest schema:
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Gate/runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Artifact opening: `false`.
- Artifact/compile-output I/O: `false`.
- Compile-output hash verification: `false`.
- Metadata parsing: `false`.
- Native library load count: `0`.
- Entry-point resolution count: `0`.
- SetupAPI/Newdev invocation count: `0`.
- Device query count: `0`.
- Hardware access count: `0`.
- Windows mutation count: `0`.
- Driver action count: `0`.

This gate-opening commit should not be rejected for omitting its own hash.
Establish its identity from Git.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, subject, parent, upstream, remote
   equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/DECISIONS.md`
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
3. Confirm verifier behavior modules, offline-suite behavior modules, static
   parser, real artifact, compile outputs, harness/evidence policy, driver,
   INF/project/solution, packaging, signing, staging, deployment, binaries, and
   `legacy/` are unchanged.

## Audit Scope

- Verify the commit records the new gate status exactly as
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_GATE_OPENED_NO_DEVICE_IO`.
- Verify the verifier lane remains closed with status
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Verify no new manifest schema is introduced and schema remains
  `chatpad-runtime-bringup-readiness-manifest-v4`.
- Verify the forbidden alternate vocabularies from the gate-opening request
  are absent from tracked repository content.
- Verify the gate/runtime blocker remains
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Verify execution authorization remains false, native execution remains
  `NOT_IMPLEMENTED`, and live readiness remains `BLOCKED`.
- Verify artifact opening, artifact/compile-output I/O, compile-output hash
  verification, and metadata parsing remain false.
- Verify native library load, entry-point resolution, SetupAPI/Newdev
  invocation, device query, hardware access, Windows mutation, and driver
  action counters remain zero.
- Verify `docs/NEXT-TASK.md` points to audit of this gate-opening commit, not
  actual live observation.
- Verify `docs/NEXT-TASK.md` does not authorize live preflight, device query,
  hardware access, Windows mutation, driver action, or actual live
  observation.

## Safety Restrictions

This audit is read-only. No live preflight is authorized by this commit. No
device query is authorized by this commit. No hardware access is authorized by
this commit. No Windows mutation is authorized by this commit. No driver action
is authorized by this commit. Actual live read-only observation must be
separately authorized after audit.

Do not edit, commit, or push during the audit. Do not run verifier behavior
tests, offline-suite behavior tests, the static parser, full compile-output
validator, full exact/readiness suites, or any artifact, native, device,
hardware, Windows, or driver path. Do not open, read, hash, parse, stat, scan,
write, load, reflect over, or execute the real DLL or compile outputs.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  gate-opening transition without self-reference.
- Manifest validation passes with schema
  `chatpad-runtime-bringup-readiness-manifest-v4`, 39 entries, duplicate
  IDs/paths `0/0`, and `NO_PATH` `0`.
- Documentation consistency, positive-authorization search, prohibited
  executable-pattern search for changed tools, changed-path safety, forbidden
  generated-file scan, spelling-variant scan, and `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/RUNTIME-BRINGUP-READINESS.md`
7. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
