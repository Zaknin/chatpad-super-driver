# Project State

Updated 2026-10-05 after the published RDP broker package was blocked by a separate setup-session check.

- Branch: `feature/chatpad-usermode-runner`; published broker RDP source/build commit: `1044e226f9d5da86d347b91137b97e026c892f9a`; release identity commit: `53559b7e51f29ff2ba1c480abd26b948098dd0cd`.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. This explained the authorization failure under the previous active-console-only policy.
- The broker authorization policy is changed to accept the exact installed SID from any non-anonymous local named-pipe session, including the user's RDP session. It continues to reject mismatched SIDs and remote pipe clients. Focused offline self-test passes 168/168 after the change.
- Rebuilt package from the exact source commit: build directory `artifacts/task-8lc4l2/build-rdp-peer-authorization-1044e22`, 214/214 package member lengths and SHA-256 match the build manifest. C4 setup/readiness checks PASS. Release verification PASS: managed 504/504, focused native CTest 3/3, setup identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4, readiness/privacy 9/9, safety PASS.
- Release `20261005T065100Z` was atomically published to `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T065100Z`; archive SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`. Independent readback verified all six payload sidecars, the receipt commit, and absence of `.part` files.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- User attempted the elevated RepairBroker command from RDP; setup rejected it at line 66 because of a second active-local-console-only identity check. The service was not repaired; no lifecycle mutation occurred. That setup gate is now being revised to accept elevated use by the authorized identity from RDP while preserving the SID/elevation/session checks.
- The published package's broker helper already has the RDP IPC policy, but the installed service remains unchanged until a new package with the updated setup identity check is built and the user retries RepairBroker.
- No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched. Hardware XInput, rumble, reconnect, and crash recovery are still not qualified for the current broker architecture.

## Next

Commit, rebuild and publish the setup identity fix. Then provide the user the exact elevated RepairBroker command for that new package. Do not run setup lifecycle actions automatically.

```powershell
<pending new package and readiness paths>
```

After RepairBroker reports PASS, the user can retry `ChatpadBridge.exe run` from their ordinary RDP PowerShell. Confirm broker create reaches `state=RUNNING`, then continue XUSB/XInput and rumble qualification.
