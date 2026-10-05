# Project State

Updated 2026-10-05 after building the RDP-capable RepairBroker setup package.

- Branch: `feature/chatpad-usermode-runner`; setup-fix source/build commit: `b76336dd021cc561fa9cfe4f65b1dcc33c78da7b`; release identity: this docs-only continuity closeout.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. This explained the authorization failure under the previous active-console-only policy.
- The broker authorization policy is changed to accept the exact installed SID from any non-anonymous local named-pipe session, including the user's RDP session. It continues to reject mismatched SIDs and remote pipe clients. Focused offline self-test passes 168/168 after the change.
- Rebuilt package from the exact source commit: build directory `artifacts/task-8lc4l2/build-rdp-peer-authorization-1044e22`, 214/214 package member lengths and SHA-256 match the build manifest. C4 setup/readiness checks PASS. Release verification PASS: managed 504/504, focused native CTest 3/3, setup identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4, readiness/privacy 9/9, safety PASS.
- Release `20261005T065100Z` was atomically published to `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T065100Z`; archive SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`. Independent readback verified all six payload sidecars, the receipt commit, and absence of `.part` files.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- User attempted the elevated RepairBroker command from RDP; setup rejected it at line 66 because of a second active-local-console-only identity check. The service was not repaired; no lifecycle mutation occurred.
- The setup gate now permits an elevated setup process for the configured authorized SID from RDP and still rejects non-elevated, wrong-SID, and invalid-session identities. Focused regression passes.
- New package `artifacts/task-8lc4l2/build-rdp-setup-session-b76336d` passed release verification: managed 504/504, focused native CTest 3/3, setup/readiness/privacy/safety checks PASS; 214/214 package files match manifest hashes. Canonical release `20261005T070200Z` is prepared with deterministic archive SHA-256 `659604F490EB19ED2F5F606A7B32BAEB8BAE1888F5893B7288CB8300135F2CCB`.
- Installed service still has the earlier helper. The new setup package must be published and the user's manual elevated RepairBroker must succeed before retrying normal-user RDP runtime.
- No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched. Hardware XInput, rumble, reconnect, and crash recovery are still not qualified for the current broker architecture.

## Next

Finish atomic publication of the prepared release, then have the user run this command in elevated PowerShell to repair the broker:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-setup-session-b76336d\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After RepairBroker reports PASS, the user can retry `ChatpadBridge.exe run` from their ordinary RDP PowerShell. Confirm broker create reaches `state=RUNNING`, then continue XUSB/XInput and rumble qualification.
