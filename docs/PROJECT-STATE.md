# Project State

Updated 2026-10-04, TASK 8L-C4: **implementation/package PASS; live acceptance PARTIAL**.

- Branch: `feature/chatpad-usermode-runner`, created from C3 commit `c5975efefd160ad45ca41e939e24c3b9fdd922c6`. Implementation commit `1ce2dd65672eefb447ebe4051b7225d3d41ab4e7` is pushed; the current documentation-closeout commit is this file's HEAD and must remain synchronized with `origin/feature/chatpad-usermode-runner`.
- Release runner/package builds with MSVC and pinned HIDMaestro runtime; 8/8 native CTest targets pass. Comprehensive repository regression passes 2064/2064, with zero failures; four setup identity/elevation assertions pass.
- The user-mode runner implements discovery/wait, open, activation, controller/Chatpad workers, virtual state/rumble, cleanup, reconnect backoff, bounded logging, single-instance protection, and unclean-session keyboard-release recovery. Normal runtime contains no PnP mutation.
- Setup keeps the recovery baseline durably under `ProgramData\ChatpadBridge`, with an Administrators/SYSTEM-only ACL, so recovery does not depend on the source checkout remaining present.
- Read-only readiness preflight PASS: current target remains Microsoft `xusb22`, problem 0, no device/class filters or extension. `status`, `diagnostics`, and `probe` correctly report no WinUSB interface. HIDMaestro backend status reports runtime ready without creating a device/context.
- Current shell is not elevated. Setup `Install` stopped at its elevation check before mutation. Therefore WinUSB normal-user access and all live runner functions remain UNTESTED: install/bind, input, virtual XInput, keyboard, rumble, start-unplugged, reconnect and held-device cleanup.
- Controlled idle process-kill/relaunch PASS for marker detection and mapped-key release recovery path, with virtual controller disabled. Runner waiting-state CPU/working-set sample is recorded; it is not a hardware performance qualification.
- Safety: no driver bind/install/uninstall, PnP mutation, security/trust change, replug, reboot, hardware I/O, user keypress, rumble, or virtual controller creation during C4. The stale-key test invoked mapped key-up recovery with no held keys. Generated evidence is ignored under `artifacts/task-8lc4`.
- Canonical PARTIAL publication for implementation commit `1ce2dd65672eefb447ebe4051b7225d3d41ab4e7` exists at `TASK-8L-C4/20261004T103800Z`, archive SHA-256 `375AA2BE1883B63851DFAE5627FFC1CC7A4148837737A079D3B84CA76E8DD174`. Ten payload sidecars passed independent hash readback; sensitive-string scan of the published manifest found none. A package/readiness set for the documentation-closeout HEAD is the final publication step.

Next: perform the explicitly authorized live C4 setup and lifecycle qualification from an elevated session, then verify whether ordinary-user runtime works. See `NEXT-TASK.md`. Do not start automatically.
