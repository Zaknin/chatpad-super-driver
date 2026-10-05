# Project State

Updated 2026-10-05 after rebuilding the broker with authorized-user RDP support.

- Branch: `feature/chatpad-usermode-runner`; source/build commit: `1044e226f9d5da86d347b91137b97e026c892f9a`.
- Release identity: this pushed docs-only continuity closeout; the package and helper bytes remain built from the source/build commit above.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. This explained the authorization failure under the previous active-console-only policy.
- The broker authorization policy is changed to accept the exact installed SID from any non-anonymous local named-pipe session, including the user's RDP session. It continues to reject mismatched SIDs and remote pipe clients. Focused offline self-test passes 168/168 after the change.
- Rebuilt package from the exact source commit: build directory `artifacts/task-8lc4l2/build-rdp-peer-authorization-1044e22`, 214/214 package member lengths and SHA-256 match the build manifest. C4 setup/readiness checks PASS. Release verification PASS: managed 504/504, focused native CTest 3/3, setup identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4, readiness/privacy 9/9, safety PASS.
- Prepared release `20261005T065100Z` for `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T065100Z`; deterministic archive SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`. Atomic publication/readback remains the handoff step after this documentation commit.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- Installed broker still contains the previous build until the user runs an elevated RepairBroker command for the rebuilt package. No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched.
- Offline release verification/publication for release `20261005T040900Z` remain PASS as documented in prior worklog entries. Hardware XInput, rumble, reconnect, and crash recovery are still not qualified for the current broker architecture.

## Next

Finish atomic publication of the prepared archive, then have the user run this exact command in elevated PowerShell to update the protected service payload:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-peer-authorization-1044e22\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After RepairBroker reports PASS, the user can retry `ChatpadBridge.exe run` from their ordinary RDP PowerShell. Confirm broker create reaches `state=RUNNING`, then continue XUSB/XInput and rumble qualification.
