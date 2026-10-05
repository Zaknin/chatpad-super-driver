# TASK 8L-C4L2 — Requalify reconnect after physical unplug

## Current state

- Branch: `feature/chatpad-usermode-runner`; current HEAD is this pushed continuity closeout commit. Runner fix is in source commit `92a368830bb6ecfb0a990ba68051583b506d5dd0`.
- User-reported normal-user run previously reached Chatpad `RUNNING`, created the virtual Xbox, accepted Chatpad input, and produced a successful XInput rumble pulse. During unplug, final zero-rumble write returned Win32 433; keys and virtual state were cleaned, but the runner incorrectly stopped with `CLEANUP_FAILED` instead of reconnecting.
- The fix defers zero-rumble recovery when device removal is confirmed and all other cleanup succeeds. It preserves the pending recovery marker and retries after the next physical open. Timeout, partial write, and key/virtual cleanup failures remain fatal.
- Focused `runner-lifecycle` CTest passed 1/1 (24 checks); native Release runner build passed. Package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`; build manifest source commit is `92a368830bb6ecfb0a990ba68051583b506d5dd0`, and 214/214 member sizes and SHA-256 values match. Readiness was refreshed for current HEAD after continuity-only changes. Runner SHA-256: `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`.
- No broker/service implementation changed; do not repeat `RepairBroker`.

## Next action

Reconnect the controller before starting, then run this from ordinary, non-elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe" run
```

After virtual Xbox creation, unplug and replug once. Acceptance requires `zero-rumble cleanup deferred device_removed`, reconnect progress, successful WinUSB reopen, `unclean-session zero-rumble recovery succeeded`, and a second virtual Xbox creation. Stop with Ctrl+C after the recovered session is running and return the complete output.

## Safety and remaining acceptance

- Run the bridge only non-elevated.
- No service install/repair, driver binding, PnP, registry, trust, boot, or device mutation by the agent; only the user-operated unplug/replug qualification is expected.
- Report reconnect as live PASS only after the recovery sequence above. Service crash recovery, final TASK 8L-C4L2 verdict, and canonical publication remain pending.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md`; confirm branch/HEAD/status and package manifest before the next live step.
