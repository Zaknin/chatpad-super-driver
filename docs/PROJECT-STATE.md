# Project State

Updated 2026-10-05 after relaxing broker session authorization for the authorized RDP user.

- Branch: `feature/chatpad-usermode-runner`; source HEAD before this change: `667a4eb9976d8f78b91b3d54e1ea675d1aace4d1`.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. This explained the authorization failure under the previous active-console-only policy.
- The broker authorization policy is now changed to accept the exact installed SID from any non-anonymous local named-pipe session, including the user's RDP session. It continues to reject mismatched SIDs and remote pipe clients. Focused offline self-test passes 168/168 after the change.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- Installed broker still contains the previous build until the user runs an elevated RepairBroker command for the rebuilt package. No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched.
- Offline release verification/publication for release `20261005T040900Z` remain PASS as documented in prior worklog entries. Hardware XInput, rumble, reconnect, and crash recovery are still not qualified for the current broker architecture.

## Next

Rebuild and publish the current source package, then have the user run the exact elevated `ChatpadSetup.ps1 -Mode RepairBroker` command once to update the protected service payload. After repair, the user can run `ChatpadBridge.exe run` from their ordinary RDP PowerShell; confirm broker create reaches `state=RUNNING`, then continue XUSB/XInput and rumble qualification.
