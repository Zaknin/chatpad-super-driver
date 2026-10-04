# Project State

Updated 2026-10-04 for TASK 8L-C4L1 stale Enum restart guard.

- Branch: `feature/chatpad-usermode-runner`; implementation commit: `b74e20bb87586b601493b0972127fa33796ae668`.
- Live function: the user's 13:44 run created the virtual Xbox, enabled Chatpad data, and ended cleanly (`keysReleased=true`, `virtualNeutral=true`, `virtualReleased=true`, `motorsStopped=true`, `clean_shutdown=true`). Controller, Chatpad keyboard, and rumble were previously confirmed.
- Latest restart: at 13:47 the runner safely refused before controller creation. The exact old Enum key `SWD\HIDMAESTRO\HM_622C184E37F6891E` remains with `ControllerIndex=0`, but PnPUtil found no device and `CM_Locate_DevNodeW` returned `CR_NO_SUCH_DEVNODE`.
- Fix: the profile-sweep guard checks devnode presence and only blocks a present `ROOT`/`SWD` device at index zero. Presence API errors fail closed. No registry deletion or PnP mutation is added. Focused HIDMaestro tests pass 113/113; C4 setup tests pass 21/21.
- Package: generated after the final continuity commit at `artifacts/task-8lc4/build-task-8lc4l1-stale-enum-published-final/package`; its build manifest and readiness record identify final HEAD. Independent member-hash verification is recorded in the ignored build output.
- Safety: no driver operation, registry/PnP mutation, reboot, trust/security change, input injection, rumble, or new virtual-controller creation was performed in this follow-up. The user must rerun a package tied to final HEAD; later lifecycle qualification remains incomplete.
