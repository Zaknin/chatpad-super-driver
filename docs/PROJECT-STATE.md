# Project State

Updated 2026-10-04 for TASK 8L-C4L1 restart guard follow-up.

- Branch: `feature/chatpad-usermode-runner`; implementation is based on `b537ef6a90aeedbea9e5492a6692afc8799aaba3`.
- Live function: the user's 13:44 run created the virtual Xbox, enabled Chatpad data, and ended cleanly (`keysReleased=true`, `virtualNeutral=true`, `virtualReleased=true`, `motorsStopped=true`, `clean_shutdown=true`). Controller, Chatpad keyboard, and rumble were previously confirmed.
- Latest restart: at 13:47 the runner safely refused before controller creation. The exact old Enum key `SWD\HIDMAESTRO\HM_622C184E37F6891E` remains with `ControllerIndex=0`, but PnPUtil found no device and `CM_Locate_DevNodeW` returned `CR_NO_SUCH_DEVNODE`.
- Fix prepared: the profile-sweep guard now checks devnode presence and only blocks a present `ROOT`/`SWD` device at index zero. Presence API errors fail closed. No registry deletion or PnP mutation is added. Focused HIDMaestro offline tests pass 113/113, including the exact stale-record regression and present-index-zero refusal.
- Package/commit: fresh package generation, full manifest/readiness verification, commit, and push are pending. Do not reuse the earlier `shutdown-correction` package.
- Safety: no driver operation, registry mutation, PnP mutation, reboot, trust/security change, input injection, rumble, or new virtual-controller creation was performed in this follow-up. The user must rerun a package tied to the new final commit; subsequent lifecycle qualification remains incomplete.
