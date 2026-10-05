# TASK 8L-C4L2 — Verify recovery after client crash

## Current state

- Branch: `feature/chatpad-usermode-runner`; runner fix source commit `92a368830bb6ecfb0a990ba68051583b506d5dd0` is pushed. Current HEAD is this docs-only continuity closeout.
- Corrected package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`; build manifest has 214/214 verified members. Runner SHA-256: `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`.
- Live normal-user run passed WinUSB, Chatpad activation/input, broker virtual Xbox, XInput rumble, unplug/replug reconnect, deferred zero-rumble, post-replug rumble recovery, and graceful cleanup (`reconnect_count=1`).
- Client disconnect cleanup PASS: the user force-stopped the single exact-path runner process PID 27348. After three seconds, the target virtual Xbox was absent from the present PnP query and `ChatpadHidMaestroBroker` remained `Running / Automatic`.
- Next verify a new bridge process consumes the preserved unclean-session marker. The physical motor stop after a hard client crash is an accepted limitation.

## Next action

Run the corrected package again from ordinary, non-elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe" run
```

Acceptance requires `unclean_previous_session=true`, `unclean-session zero-rumble recovery succeeded`, a fresh virtual Xbox, Chatpad key-data/input, and clean Ctrl+C shutdown. Return the complete output. Then run final focused verification, refresh readiness for final HEAD, and prepare/publish the canonical TASK-8L-C4L2 release using the existing atomic publisher.

## Safety and acceptance

- Run ChatpadBridge only from a normal user process.
- Do not repeat service install/repair; installed service payload is unchanged.
- Do not change driver binding, PnP, registry, trust, boot, or device state. No further forced termination is needed for the client cleanup gate.
- Do not expect a hard bridge-process crash to stop physical rumble; verify broker cleanup of the virtual Xbox and marker-driven recovery on the subsequent launch.
- Report service lifecycle, IPC, XInput, Chatpad, rumble, reconnect, cleanup, and crash recovery independently. Keep overall status PARTIAL until the restart result and final artifact publication are verified.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md`; check branch/HEAD/status and confirm the package manifest/readiness identity.
