# Project State

Updated 2026-10-04 for TASK 8L-C4L1 helper shutdown pipe race.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD `2f185d095cf2e900c6d5a0e0d385118c020b6b2e`.
- Live function: user's 14:01 run passed the stale Enum guard, opened WinUSB, created the virtual Xbox, enabled Chatpad data, and emitted keyboard input (`hid=32`). Session duration 50.878s.
- Shutdown result: helper teardown reported `helper_output_closed:109`, so runner correctly recorded `virtualReleased=false`, `clean_shutdown=false`, and stopped without reopening the physical controller. Read-only follow-up found no Chatpad processes, XInput slots 0–3 returned 1167, and no present task-owned ROOT/SWD nodes; the virtual controller was released despite the diagnostic failure.
- Root cause: after helper replies successfully to `quit`, it exits and closes stdout. The parent reader can observe `ERROR_BROKEN_PIPE` before `DisposeProcess()` sets its stop flag and incorrectly records a cleanup fault.
- Fix prepared: mark expected helper exit when sending `quit`; suppress pipe-end/read errors only during that expected quit path. A missing quit response still times out and fails. The regression failed before the fix and passed after it.
- Focused validation: native `helper` and `runner-lifecycle` passed 2/2; helper then passed three consecutive repeats. No broad native suite was run.
- Package: regenerate after the final implementation/continuity commit at `artifacts/task-8lc4/build-task-8lc4l1-expected-quit-final`; independently verify exact HEAD identity and all manifest/readiness hashes.
- Safety: no driver or PnP/registry operation, reboot, trust/security change, input injection, rumble, or virtual-device creation was performed in this agent session. The user's run was the live creation. Clean user shutdown is not yet accepted pending a fresh-package retry.
