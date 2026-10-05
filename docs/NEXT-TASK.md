# TASK 8L-C4L2 — Trace missing XUSB companion during broker create

## Current state

- Branch: `feature/chatpad-usermode-runner`; source/package build commit `2258de10c65052a12efff8acfa30f2773dc546ad`; published release identity `97095be21c420f55a26a7319b8a42323fd6fb6d4`.
- New normal-user run confirmed the rumble recovery correction: `unclean_previous_session=false` and startup zero-rumble was skipped. It then failed broker creation because the exact XUSB interface was absent.
- SetupAPI shows the HIDMaestro ROOT node starts via `oem106.inf`/`mshidumdf`; broker cleanup deletes the node after the failed XUSB gate. Kernel-PnP logged repeated 3–5.2 second WUDFRd event-queue delays and query-remove vetoes for the SWD node. Exact cause is unresolved.
- The product gate in `HidMaestroBackend.Create` waits 1000 ms for the interface after HIDMaestro returns. Do not increase it blindly: native broker create timeout is 30000 ms and the SDK startup already takes most of that bound.
- Read-only watcher created at `artifacts/task-8lc4l2/monitor-xusb-interface.ps1`; a 5-second idle syntax/runtime check passed and observed zero present XUSB interfaces (expected while no controller is running).
- The user previously reported the broker service Running. No service repair is indicated by this log.

## Next steps

1. In a second ordinary PowerShell, start the read-only watcher for 60 seconds:

   `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\monitor-xusb-interface.ps1" -Seconds 60 -IntervalMs 250`

2. While it runs, start the published normal-user bridge in another PowerShell and return both outputs:

   `& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-recovery-2258de1\package\ChatpadBridge.exe" run`

3. If the exact SWD XUSB interface appears after the current one-second gate, make a minimal bounded wait/RPC timeout change with focused tests. If it never appears, investigate UMDF/PnP driver behavior; do not weaken the gate or switch backend.

## Safety

- The watcher only enumerates present device-interface paths. It does not create/remove devices or alter service, PnP, registry, driver, trust, or boot state.
- Do not run the bridge elevated or perform global HIDMaestro cleanup.
- Keep the result PARTIAL until exact XUSB/XInput and subsequent rumble behavior are live-verified.
