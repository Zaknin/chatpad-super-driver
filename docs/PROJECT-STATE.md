# Project State

Updated 2026-10-05 after the normal-user broker authorization check.

- Branch: `feature/chatpad-usermode-runner`; current HEAD before this continuity update: `09acee749437256f5625a94b9cbea7bf97ed69f9`.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. The approved broker policy accepts the configured user only from the active local console session and intentionally rejects RDP/remote clients. This explains the authorization failure; do not loosen that policy.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- Broker service is Running. Startup zero-rumble recovery was skipped because the previous bridge session was clean. No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched.
- Offline release verification/publication for release `20261005T040900Z` remain PASS as documented in prior worklog entries. Hardware XInput, rumble, reconnect, and crash recovery are still not qualified for the current broker architecture.

## Next

From a PowerShell opened after signing in locally at the physical machine's console (not through RDP), run the existing normal-user bridge package at `C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-recovery-2258de1\package\ChatpadBridge.exe`. Confirm broker create succeeds and the run reaches `state=RUNNING`. Then continue XUSB/XInput and rumble qualification. Do not change the RDP rejection policy or infer XUSB failure from the RDP-denied run.
