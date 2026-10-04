# Project State

Updated 2026-10-04, TASK 8L-C4: **implementation/package PASS; live acceptance PARTIAL**.

- Branch: `feature/chatpad-usermode-runner`, created from C3 commit `c5975efefd160ad45ca41e939e24c3b9fdd922c6`. The C4 closeout commit is expected to be this branch's new HEAD; its final SHA and remote synchronization are recorded by Git and the canonical result manifest.
- Release runner/package builds with MSVC and pinned HIDMaestro runtime; 8/8 native CTest targets pass. Comprehensive repository regression passes 2064/2064, with zero failures; four setup identity/elevation assertions pass.
- The user-mode runner implements discovery/wait, open, activation, controller/Chatpad workers, virtual state/rumble, cleanup, reconnect backoff, bounded logging, single-instance protection, and unclean-session keyboard-release recovery. Normal runtime contains no PnP mutation.
- Setup keeps the recovery baseline durably under `ProgramData\ChatpadBridge`, with an Administrators/SYSTEM-only ACL, so recovery does not depend on the source checkout remaining present.
- Read-only readiness preflight PASS: current target remains Microsoft `xusb22`, problem 0, no device/class filters or extension. `status`, `diagnostics`, and `probe` correctly report no WinUSB interface. HIDMaestro backend status reports runtime ready without creating a device/context.
- Current shell is not elevated. Setup `Install` stopped at its elevation check before mutation. Therefore WinUSB normal-user access and all live runner functions remain UNTESTED: install/bind, input, virtual XInput, keyboard, rumble, start-unplugged, reconnect and held-device cleanup.
- Controlled idle process-kill/relaunch PASS for marker detection and mapped-key release recovery path, with virtual controller disabled. Runner waiting-state CPU/working-set sample is recorded; it is not a hardware performance qualification.
- Safety: no driver bind/install/uninstall, PnP mutation, security/trust change, replug, reboot, hardware I/O, user keypress, rumble, or virtual controller creation during C4. The stale-key test invoked mapped key-up recovery with no held keys. Generated evidence is ignored under `artifacts/task-8lc4`.
- Canonical TASK-8L-C4 publication is PARTIAL and must contain sanitized build/package, diagnostics, test and lifecycle evidence with independent source/.part/final hash readback and sidecars last. See the final result manifest/receipt.

Next: perform the explicitly authorized live C4 setup and lifecycle qualification from an elevated session, then verify whether ordinary-user runtime works. See `NEXT-TASK.md`. Do not start automatically.
