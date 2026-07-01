# Next Task

## Exact Current State

- Required branch:
  `feature/documentation-offline-runtime-instrumentation-design`.
- Required starting commit: the commit containing this file, with subject
  `docs: define offline runtime instrumentation design` and parent
  `fbca8852e47300d4f483968b23e42ee82e88b972`.
- First-runtime recovery plan accepted at
  `fbca8852e47300d4f483968b23e42ee82e88b972`.
- Frozen accepted baseline: `4c84891ca24ef969664f53fd5e9ec2a697f2edb9`,
  `AUDIT PASS WITH LIMITATIONS`.
- Frozen implementation: `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Instrumentation design:
  `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`.
- Design verdict: `INSTRUMENTATION DESIGN READY FOR OFFLINE IMPLEMENTATION`.
- Selected mechanism: WPP software tracing as primary evidence, existing
  `KdPrintEx` as fallback only.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.
- Hardware/device state: no hardware identity has been queried in this phase.

## Next Recommended Objective

Implement the accepted diagnostic instrumentation offline, with no signing,
installation, loading, device query, target discovery, request execution, or
hardware interaction.

## Preconditions

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, recent `docs/WORKLOG.md`,
   `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`, and
   `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`.
3. Reconfirm that no runtime authorization exists.
4. Treat source/project/test/build changes as permitted only if the next task
   explicitly authorizes offline diagnostic implementation. Signing, packaging,
   staging, installation, loading, live device query, and hardware gates remain
   closed.

## Safety Restrictions

- Do not sign, package, create certificates/keys, stage, install, load, mutate
  Windows, query devices, use PnPUtil/DISM/DevCon/Device Manager, enable
  verifier, alter boot settings, access USB/HID/XUSB/controller/Chatpad, open a
  target, discover targets, or perform request formatting/submission/
  completion/cancellation.
- Do not modify `legacy/`.
- Do not treat instrumentation implementation as runtime approval.

## Acceptance Criteria

- Diagnostic events and IDs match the accepted design.
- Instrumentation remains diagnostic-only and does not introduce target
  discovery, request formatting, send, completion, or cancellation.
- Debug and Release diagnostic behavior is explicitly tested or guarded.
- Prohibited-operation counters initialize to zero and produce final snapshots.
- Object-presence snapshots and orchestration-report summaries avoid handles,
  pointers, buffers, USB payloads, and Chatpad payloads.
- Static guards prove no duplicate IDs, no prohibited data fields, no new
  target/request operation paths, and no status-path changes.
- Existing offline regressions applicable to the implementation pass.
- Continuation docs are updated with exact evidence and no unsupported runtime
  claims.

## Inspect First

- `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`
- `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`
- `src/driver/ChatpadFilter/driver.c`
- `src/driver/ChatpadFilter/device.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`
