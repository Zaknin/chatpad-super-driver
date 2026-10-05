# Project State

Updated 2026-10-05 after live rumble-recovery and XUSB companion checks.

- Branch: `feature/chatpad-usermode-runner`; current repository state follows release commit `97095be21c420f55a26a7319b8a42323fd6fb6d4` (release archive built from `2258de10c65052a12efff8acfa30f2773dc546ad`).
- Latest normal-user run of release `20261005T040900Z` confirmed `unclean_previous_session=false` and `startup zero-rumble recovery skipped previous_session_clean=true`. That corrects the repeated clean-start OUT timeout; this does not establish rumble output.
- Virtual Xbox creation then failed because the exact XUSB interface `SWD#HIDMAESTRO#HM_622C184E37F6891E#{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}` was absent. The broker correctly refused HID-only success and cleaned up.
- Read-only host evidence: SetupAPI logged the HIDMaestro ROOT node configured and started with `oem106.inf`/`mshidumdf` at 2026-10-05 04:13:35 UTC; broker cleanup deleted it at 04:13:52 UTC. Kernel-PnP logged repeated 3–5.2 second WUDFRd device-event queue delays and query-remove vetoes for the same SWD instance. These facts localize the failure to the UMDF/PnP/XUSB companion path; they do not yet prove whether the XUSB interface appears late or never appears.
- The XUSB exact-interface gate remains necessary because HID-class input alone did not yield an XInput slot in prior C4 checks. Do not weaken it or switch backend. The gate currently polls for 1 second after HIDMaestro returns; observe interface arrival timing before changing that bound or create RPC timeout.
- Offline release verification and publication remain PASS: managed 504/504, focused native CTest 3/3, setup/readiness/safety PASS, package inventory 214/214; archive SHA-256 `C03531153A5AF9E7407970DBBBA1AC88B9155C731294A1B42541BFF3C343CD07`.
- Service remains Running on read-only query. Failed-create cleanup removed the controller nodes; no matching present XUSB device remained after process exit. No service, PnP, driver, registry, trust, or device mutation by the agent; `legacy/` untouched.

## Next

Use the read-only interface monitor in `artifacts/task-8lc4l2/monitor-xusb-interface.ps1` during one normal-user bridge run. If the exact interface appears after the current one-second gate window, adjust only bounded wait/RPC timing and test offline first. If it never appears before cleanup, investigate the UMDF/HIDMaestro XUSB companion startup from the captured PnP evidence without reporting it as a rumble bug.
