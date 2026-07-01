# Next Task

## Exact Current State

- Required branch:
  `feature/offline-runtime-instrumentation-implementation`.
- Required starting commit: the final implementation commit containing this
  file, with subject `driver: implement offline runtime instrumentation`.
- Required parent:
  `526f6bb055b485fdb459a9d303fc3f814da15e48`,
  `docs: remediate runtime instrumentation design audit`.
- Runtime instrumentation provider:
  `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Runtime instrumentation schema: `1`.
- Runtime instrumentation event catalogue: 73 accepted IDs and symbolic names.
- Implementation manifest:
  `docs/evidence/runtime-instrumentation-implementation-manifest.json`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.
- Hardware/device state: no hardware identity has been queried in this phase.

## Next Recommended Objective

Independently audit the offline runtime instrumentation implementation.

## Preconditions

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, recent `docs/WORKLOG.md`,
   `docs/OFFLINE-RUNTIME-INSTRUMENTATION-IMPLEMENTATION.md`,
   `docs/evidence/runtime-instrumentation-implementation-manifest.json`,
   `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`, and
   `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`.
3. Confirm changed-path scope against the implementation commit.
4. Re-run the runtime instrumentation guard and repository safety checks before
   relying on the manifest.

## Safety Restrictions

- Do not sign, package, create certificates/keys, stage, install, load, mutate
  Windows, query devices, use PnPUtil/DISM/DevCon/Device Manager, enable
  verifier, alter boot settings, access USB/HID/XUSB/controller/Chatpad, open a
  target, discover targets, or perform request formatting/submission/reuse/
  completion/cancellation.
- Do not start a trace session during this audit.
- Do not modify `legacy/`.

## Acceptance Criteria

- Provider GUID, schema version, WPP project settings, and WPP init/cleanup
  lifecycle are correct.
- All 73 accepted event IDs and symbolic names are present once in the tracked
  catalogue and inventory.
- Event sites cover driver entry, device add, owner initialization,
  orchestration, readiness, lifecycle, rollback, cleanup, prohibited counters,
  invariants, and terminal summaries.
- Attempt IDs, per-attempt sequence values, status classes, object snapshots,
  report summaries, and terminal events are bounded and deterministic.
- Static guards reject prohibited target discovery, target opening, request
  formatting, request reuse, request send, completion, cancellation, protocol
  traffic, keyboard injection, and hardware actions.
- Debug and Release driver/solution builds and existing offline regressions
  remain green.
- Continuation documents contain no unsupported runtime, signing, packaging,
  installation, or hardware claims.

## Inspect First

- `src/driver/ChatpadFilter/ChatpadRuntimeDiagnostics.h`
- `src/driver/ChatpadFilter/driver.c`
- `src/driver/ChatpadFilter/device.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
- `tools/Test-ChatpadRuntimeInstrumentation.ps1`
- `docs/OFFLINE-RUNTIME-INSTRUMENTATION-IMPLEMENTATION.md`
- `docs/evidence/runtime-instrumentation-implementation-manifest.json`
