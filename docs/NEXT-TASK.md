# Next Task

## TASK 8L-C4L1 — Retry Phase 4 after stale Enum guard correction

The restart at 2026-10-04 13:47 UTC failed before virtual-controller creation because a historical `SWD\HIDMAESTRO\HM_622C184E37F6891E` Enum key has `ControllerIndex=0` despite the devnode being absent (`CM_Locate_DevNodeW` returned `CR_NO_SUCH_DEVNODE`, and PnPUtil found no device). The guard now checks current devnode presence and still refuses a present ROOT/SWD controller at index zero. Presence-query errors fail closed. Focused HIDMaestro offline tests passed 113/113.

Build and independently verify a fresh package from the final pushed commit under a new ignored path in `artifacts/task-8lc4`. The previous `build-task-8lc4l1-shutdown-correction` package predates this fix and must not be used.

After package verification, the user runs this exact command from PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4\<verified-build-directory>\package\ChatpadBridge.exe" run
```

Capture the full startup and shutdown output. If it reaches RUNNING, verify ordinary controller/Chatpad behavior and then stop with Ctrl+C; confirm clean shutdown and no remaining XInput slot or present task-owned ROOT/SWD nodes. Do not delete the historical Enum key, weaken the present-device check, rerun setup/install, or reboot. Do not proceed to the later long-idle, crash, unplug/reconnect, or comprehensive phases until this restart is accepted.

Required starting state: final package manifest and readiness both identify the pushed `feature/chatpad-usermode-runner` commit and every packaged member hash matches. Physical `USB\VID_045E&PID_028E\1C21F10` must remain WinUSB/problem 0/no filters.

Inspect first: `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, `HidMaestroBackend.cs`, the current package manifest/readiness, then user runtime output.
