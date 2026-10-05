# TASK 8L-C4L2 — Requalify reconnect after physical unplug

## Current state

- Branch: `feature/chatpad-usermode-runner`; source fix is based on `c0c42ca1ca087423fd709d74d6c49a337b9f961d` and is being committed with this continuity update.
- In the user’s normal-user run, WinUSB open, Chatpad activation, virtual Xbox creation, Chatpad input, and a separate XInput rumble pulse succeeded. During unplug, the final zero-rumble write returned Win32 433; keyboard and virtual-controller cleanup succeeded, but the runner treated the unavailable physical write as fatal and exited with `CLEANUP_FAILED`.
- The fix defers zero-rumble recovery when the device is confirmed removed, while still requiring key release and successful virtual neutralization/release. Timeouts, partial writes, and failed cleanup actions remain fatal.
- Focused `runner-lifecycle` regression and native `ChatpadWinUsbPoc` build passed. The updated package has not yet been generated. Existing installed broker payload is unchanged; do not run `RepairBroker` for this client-only fix.

## Next action

Build the package from the committed and pushed branch tip:

```powershell
& "C:\Dev\chatpad-super-driver\tools\Build-ChatpadBridge.ps1" -OutputDirectory "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect" -SkipNativeTests
```

Check `build-manifest.json`, generated `readiness-input.json`, and every package member’s SHA-256 against the manifest. Then provide the user the exact ordinary, non-elevated command:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe" run
```

The user should reconnect the controller before starting. After the log reaches virtual Xbox creation, have them unplug and replug once. Acceptance requires `zero-rumble cleanup deferred device_removed`, reconnect progress, successful WinUSB reopen, `unclean-session zero-rumble recovery succeeded`, and a second virtual Xbox creation. Ask for the complete output and then stop after the user ends the recovered run with Ctrl+C.

## Safety and acceptance

- Run the bridge only from ordinary, non-elevated PowerShell.
- Do not repeat service install/repair; service and broker code did not change.
- Do not change driver binding, PnP, registry, trust, boot, or device state beyond the user-directed physical unplug/replug test.
- Preserve the fatal path for timeouts, partial/failed writes, or keyboard/virtual cleanup failures.
- Report reconnect as live PASS only after the corrected package recovers and zero-rumble recovery succeeds after replug. Full C4L2 closeout and publication remain pending.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md`; check branch/HEAD/status, then inspect `Runner.cpp`, `RunnerLifecycle.cpp`, and the focused lifecycle test.
