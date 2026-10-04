# Next Task

## TASK 8L-C4L1 — Resume Phase 3 after focused runner fix

Current state: setup binding remains WinUSB/problem 0 on `USB\VID_045E&PID_028E\1C21F10` (`oem104.inf`). The runner previously timed out its HIDMaestro create request at 1 second and then retried on a disconnected phantom devnode created during that run. The focused source fix uses a 30-second create deadline and stops the run on virtual-backend creation failure instead of classifying it as physical loss. Focused `helper` and `runner-lifecycle` tests pass. A read-only PnPUtil query now confirms the stale devnode `SWD\HIDMAESTRO\HM_622C184E37F6891E` is absent; physical WinUSB/problem0 remains confirmed.

Required branch: `feature/chatpad-usermode-runner`, synchronized with `origin/feature/chatpad-usermode-runner`. Confirm `git rev-parse HEAD` matches the repository identity in the regenerated package manifest and readiness.

Preconditions: the user confirms `pnputil /remove-device "SWD\HIDMAESTRO\HM_622C184E37F6891E"` completed and a read-only query shows that exact instance absent. Confirm the physical controller remains WinUSB/problem 0. Do not remove the `oem107.inf` driver package or touch the physical `oem104.inf` device.

Next action: from an elevated PowerShell session, launch the freshly built package runner (helper is beside it):

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4\build-task-8lc4l1-create-timeout-published\package\ChatpadBridge.exe" run
```

Keep the console open. Capture whether it reaches `RUNNING`, helper-create result, virtual XInput and controller forwarding, Chatpad packet/key output, rumble, and simultaneous use. If create fails, it should now stop with `VIRTUAL_BACKEND_FAILED` without a physical reconnect loop; capture the exact backend error and device state. Stop cleanly with Ctrl+C before lifecycle follow-up. Continue remaining C4L1 phases only after Phase 3 succeeds.

Safety: do not rerun Install while WinUSB is active; do not uninstall, restore Microsoft, reboot, or broadly remove virtual devices during this Phase 3 retry. Do not remove the HIDMaestro package. The exact stale devnode may be removed only as above. No live input/rumble acceptance is inferred from offline tests.

Inspect first: this file, `docs/PROJECT-STATE.md`, latest `docs/WORKLOG.md`, `tools/ChatpadWinUsbPoc/Runner.cpp`, `tools/ChatpadWinUsbPoc/VirtualHelper.cpp`, and `artifacts/task-8lc4/build-task-8lc4l1-create-timeout-published/build-manifest.json`.
