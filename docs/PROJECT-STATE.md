# Project State

Updated 2026-10-05 after the first user-operated unplug/reconnect attempt with the C4L2 broker runtime.

- Branch: `feature/chatpad-usermode-runner`; source work starts at `c0c42ca1ca087423fd709d74d6c49a337b9f961d`. The current source fix and continuity updates are intended for one commit on this branch.
- The user reported a normal-user run with WinUSB open, Chatpad activation, HIDMaestro virtual Xbox creation, Chatpad input, and a successful XInput rumble pulse. The preceding run ended cleanly.
- On unplug during a subsequent run, WinUSB returned `ERROR_NO_SUCH_DEVICE` (Win32 433). Keyboard release and virtual neutralization/release succeeded, while the physical zero-rumble write could not reach the removed controller. The runner incorrectly classified this expected removal as fatal cleanup failure and exited without reconnecting.
- The source now classifies zero-rumble cleanup separately: confirmed device removal is recoverable only when key release, virtual neutralization, and virtual release all succeeded. It preserves pending zero-rumble recovery for the next opened session. Other rumble-write errors and any failed cleanup action remain fatal.
- Focused regression tests cover complete cleanup, unplug during motor stop, failed key/virtual cleanup, timeout, and partial write. The focused runner lifecycle CTest and native runner build passed; package regeneration from the committed fix remains pending.
- Live reconnect with the corrected package, startup zero-rumble recovery after replug, service crash recovery, and full C4L2 closeout remain unqualified. Existing user-reported broker installation/repair and initial normal-user XInput/Chatpad/rumble are distinct from those gates.
- No service, PnP, driver, registry, trust, device, or boot mutation was performed by the agent. The broker service payload was not changed; `legacy/` remains untouched.

## Next

Build the updated package from the pushed source commit in `artifacts/task-8lc4l2/build-rumble-removal-reconnect`, verify its package manifest/readiness hashes, and give the user the normal-user runner command. After the user has reconnected the controller, qualify unplug/replug: the corrected run should report deferred zero-rumble cleanup, enter reconnect, reopen WinUSB, complete `unclean-session zero-rumble recovery`, and create the virtual Xbox again. Stop with Ctrl+C after the second session is running and return its full output.
