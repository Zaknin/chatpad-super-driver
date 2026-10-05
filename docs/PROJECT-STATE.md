# Project State

Updated 2026-10-05 after building the corrected normal-user runner package.

- Branch: `feature/chatpad-usermode-runner`; source commit `92a368830bb6ecfb0a990ba68051583b506d5dd0` is pushed to `origin`.
- The user reported a normal-user run with WinUSB open, Chatpad activation, HIDMaestro virtual Xbox creation, Chatpad input, and a successful XInput rumble pulse. The preceding run ended cleanly.
- On unplug during a subsequent run, WinUSB returned `ERROR_NO_SUCH_DEVICE` (Win32 433). Keyboard release and virtual neutralization/release succeeded, while the physical zero-rumble write could not reach the removed controller. The runner incorrectly classified this expected removal as fatal cleanup failure and exited without reconnecting.
- The source now classifies zero-rumble cleanup separately: confirmed device removal is recoverable only when key release, virtual neutralization, and virtual release all succeeded. It preserves pending zero-rumble recovery for the next opened session. Other rumble-write errors and any failed cleanup action remain fatal.
- Focused regression tests cover complete cleanup, unplug during motor stop, failed key/virtual cleanup, timeout, and partial write. The focused runner lifecycle CTest passed 1/1 (24 checks, 0 failures), and the native runner Release build passed.
- Corrected package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`; source and readiness identity match branch/commit `feature/chatpad-usermode-runner` / `92a368830bb6ecfb0a990ba68051583b506d5dd0`. Independent inventory verified 214/214 member lengths and SHA-256 values against `build-manifest.json`. `ChatpadBridge.exe` SHA-256: `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`.
- Live reconnect with the corrected package, startup zero-rumble recovery after replug, service crash recovery, and full C4L2 closeout remain unqualified. Existing user-reported broker installation/repair and initial normal-user XInput/Chatpad/rumble are distinct from those gates.
- No service, PnP, driver, registry, trust, device, or boot mutation was performed by the agent. The broker service payload was not changed; `legacy/` remains untouched.

## Next

Give the user the corrected package command in `artifacts/task-8lc4l2/build-rumble-removal-reconnect`. After the user reconnects the controller, qualify unplug/replug: the corrected run should report deferred zero-rumble cleanup, enter reconnect, reopen WinUSB, complete `unclean-session zero-rumble recovery`, and create the virtual Xbox again. Stop with Ctrl+C after the second session is running and return its full output. Canonical C4L2 publication and final verdict remain pending until live qualification is complete.
