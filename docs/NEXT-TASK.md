# Next Task

## TASK 8L-C4L1 — Requalify Phase 3 shutdown after helper lifecycle fix

The shutdown correction and continuity updates are committed together on `feature/chatpad-usermode-runner`, following starting HEAD `4d7efc6b3154703ecc55ea54adc052a93680eb94`. The user's previous live session proved controller, Chatpad keyboard, and physical rumble function, but shutdown failed: after process exit, XInput slot 0 remained connected and the exact SWD and ROOT HIDMaestro nodes remained present. The source fix adds a bounded 30-second helper disconnect/exit deadline and makes cleanup failure visible.

First complete the source review, commit implementation and continuity updates together, push only `feature/chatpad-usermode-runner`, build a fresh C4 package from that pushed HEAD, and independently verify branch/commit/package identity plus every manifest/readiness hash. Use a fresh ignored output directory under `artifacts/task-8lc4`; the existing `build-task-8lc4l1-create-timeout-published` package predates this shutdown fix.

Before live retry, confirm the user removed only these two old owned instances and retained `oem107.inf`/`oem106.inf`:

```powershell
pnputil /remove-device "SWD\HIDMAESTRO\HM_622C184E37F6891E"
pnputil /remove-device "ROOT\VID_045E&PID_028E&IG_00\HM_622C184E37F6891E"
```

Then read-only verify both exact IDs are absent and physical `USB\VID_045E&PID_028E\1C21F10` remains WinUSB/problem 0. Do not remove driver packages or modify the physical node.

User runs the newly generated `package\ChatpadBridge.exe run` in the already used elevated PowerShell. Capture helper teardown log, `clean_shutdown`, process exit code, XInput slots 0-3, and PnP state for new virtual nodes. Acceptance requires slot 0 disconnected and no task-owned present nodes; if teardown reports forced termination or state is ambiguous, stop and inspect exact owned IDs before any cleanup. Do not add automatic/broad PnP mutation to the ordinary runtime.

Safety: no Install rerun while WinUSB is active; no package removal, restore, reboot, trust/security mutation, broad device removal, or automatic physical reconnect/retry on helper cleanup failure. Keep long-idle, crash, hot-unplug, and other lifecycle phases unqualified until directly exercised.

Inspect first: `AGENTS.md`, this file, `docs/PROJECT-STATE.md`, the latest `docs/WORKLOG.md`, `tools/ChatpadWinUsbPoc/VirtualHelper.cpp`, `VirtualHelper.h`, `Runner.cpp`, and the new package manifest/readiness.
