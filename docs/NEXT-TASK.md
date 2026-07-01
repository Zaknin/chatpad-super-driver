# Next Task

## Exact Current State

- Required branch: `feature/documentation-first-runtime-observation-recovery-plan`.
- Required starting commit: the commit containing this file, with subject
  `docs: define first runtime observation and recovery gate` and parent
  `4c84891ca24ef969664f53fd5e9ec2a697f2edb9`.
- Accepted baseline: `4c84891ca24ef969664f53fd5e9ec2a697f2edb9`,
  `AUDIT PASS WITH LIMITATIONS`.
- Frozen implementation: `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Runtime planning document:
  `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.
- Hardware/device state: no hardware identity has been queried in this phase.
- Observability verdict: current build is not sufficiently observable for first
  controlled load.

## Next Recommended Objective

Perform **Option A - Offline runtime instrumentation design**.

Design diagnostic-only runtime instrumentation that can later prove
`EvtDeviceAdd` reachability, orchestration outcome, structural-ready
reachability, lifecycle reachability, cleanup after failure, target/request
absence, and no unintended device-stack effect. This must remain an offline
source/design phase until separately authorized.

## Preconditions

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, recent `docs/WORKLOG.md`, and
   `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`.
3. Reconfirm that no runtime authorization exists.
4. Reconfirm that source, project, solution, props, INF, signing, packaging,
   and hardware gates are closed unless the next task explicitly authorizes a
   narrower source-only instrumentation change.

## Safety Restrictions

- Do not sign, package, create certificates/keys, stage, install, load, mutate
  Windows, query devices, use PnPUtil/DISM/DevCon/Device Manager, enable
  verifier, alter boot settings, access USB/HID/XUSB/controller/Chatpad, open a
  target, discover targets, or perform request formatting/submission/
  completion/cancellation.
- Do not modify `legacy/`.
- Do not treat instrumentation design as runtime approval.

## Acceptance Criteria

- Instrumentation remains diagnostic-only and does not introduce target
  discovery, request formatting, send, completion, or cancellation.
- Event IDs and fields are deterministic, bounded, secret-free, and sufficient
  for the runtime evidence manifest described in the first-runtime plan.
- Debug and Release behavior are explicitly defined.
- Offline tests/guards and provenance requirements are specified before any
  future load.
- Continuation docs are updated with the exact next gate and no unsupported
  runtime claims.

## Inspect First

- `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`
- `src/driver/ChatpadFilter/device.c`
- `src/driver/ChatpadFilter/driver.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
- `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`
