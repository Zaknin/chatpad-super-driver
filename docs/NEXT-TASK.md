# Next Task

## TASK 8L-C4L1 — Requalify clean Phase 4 shutdown after expected-quit pipe fix

The user's 2026-10-04 14:01Z run proved restart, WinUSB, virtual Xbox, and Chatpad keyboard input work. It ended with `helper_output_closed:109`, `virtualReleased=false`, and `clean_shutdown=false`. Read-only post-run checks found no Chatpad process, all XInput slots disconnected (1167), and no present task-owned ROOT/SWD nodes. The native regression failed before the change when the mock helper closed stdout immediately after replying to `quit`; it passes after the fix. Expected EOF is ignored only once `quit` is sent; a missing response still times out as an error.

Build the package from the final pushed `feature/chatpad-usermode-runner` HEAD at `artifacts/task-8lc4/build-task-8lc4l1-expected-quit-final`. Verify the build manifest/readiness identity and every packaged member hash before use.

User reruns from PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4\build-task-8lc4l1-expected-quit-final\package\ChatpadBridge.exe" run
```

Confirm controller and Chatpad keyboard input, then stop with Ctrl+C. Acceptance requires `keysReleased=true`, `virtualNeutral=true`, `virtualReleased=true`, `motorsStopped=true`, and `clean_shutdown=true`; read-only follow-up must show all XInput slots disconnected and no present task-owned ROOT/SWD nodes. If cleanup fails, return the full output and do not retry or mutate PnP/registry state.

Do not rerun setup/install, reboot, delete the historical Enum key, or start long-idle/crash/unplug/reconnect phases until clean shutdown is accepted.

Inspect first: `tools/ChatpadWinUsbPoc/VirtualHelper.cpp`, `helper-tests.cpp`, package manifest, and readiness file.
