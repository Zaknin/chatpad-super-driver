# Project State

Updated 2026-10-05 after the read-only RDP controller probe timed out.

- Branch: `feature/chatpad-usermode-runner`; current documentation closeout follows pushed RDP diagnosis commit `abbd05232a50ffcd897bf3275daf7bfb16231bed`; setup-fix source/build commit: `b76336dd021cc561fa9cfe4f65b1dcc33c78da7b`; published package identity `20261005T070200Z` remains the runtime package in use.
- The 2026-10-05 06:40 UTC normal-user run of the rumble-recovery package confirmed clean-start recovery skip, then failed before HIDMaestro creation with `broker_peer_unauthorized`.
- Read-only identity check confirmed the installed broker authorization SID matches the current user's SID. `query user/session` showed the bridge running in active `rdp-tcp#1` session 1; the local `console` session had no logged-in user. This explained the authorization failure under the previous active-console-only policy.
- The broker authorization policy is changed to accept the exact installed SID from any non-anonymous local named-pipe session, including the user's RDP session. It continues to reject mismatched SIDs and remote pipe clients. Focused offline self-test passes 168/168 after the change.
- Rebuilt package from the exact source commit: build directory `artifacts/task-8lc4l2/build-rdp-peer-authorization-1044e22`, 214/214 package member lengths and SHA-256 match the build manifest. C4 setup/readiness checks PASS. Release verification PASS: managed 504/504, focused native CTest 3/3, setup identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4, readiness/privacy 9/9, safety PASS.
- Release `20261005T065100Z` was atomically published to `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T065100Z`; archive SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`. Independent readback verified all six payload sidecars, the receipt commit, and absence of `.part` files.
- Because authorization failed before the service created a virtual controller, this run provides no XUSB, XInput, or rumble evidence. The concurrent watcher output supplied only an idle baseline (`xusbInterfaceCount=0`); no in-run interface observation was returned.
- User attempted the elevated RepairBroker command from RDP; setup rejected it at line 66 because of a second active-local-console-only identity check. The service was not repaired; no lifecycle mutation occurred.
- The setup gate now permits an elevated setup process for the configured authorized SID from RDP and still rejects non-elevated, wrong-SID, and invalid-session identities. Focused regression passes.
- New package `artifacts/task-8lc4l2/build-rdp-setup-session-b76336d` passed release verification: managed 504/504, focused native CTest 3/3, setup/readiness/privacy/safety checks PASS; 214/214 package files match manifest hashes. Canonical release `20261005T070200Z` is prepared with deterministic archive SHA-256 `659604F490EB19ED2F5F606A7B32BAEB8BAE1888F5893B7288CB8300135F2CCB`.
- User manually ran elevated `RepairBroker` from RDP with package `build-rdp-setup-session-b76336d`; it passed, reporting the service Running as LocalSystem and 197 runtime members. This confirms the service helper was refreshed.
- The subsequent normal-user RDP run opened WinUSB but repeated `ACTIVATING_CHATPAD` -> `DEVICE_LOST` at roughly five-second intervals. It ended cleanly on Ctrl+C after four reconnect attempts. No `controller input polling started`, activation-stage, broker-create, or virtual-Xbox lines appeared.
- A second normal-user RDP run repeated the same pattern for six reconnect attempts and was stopped cleanly with Ctrl+C. The user is away from the physical controller and cannot press it remotely.
- The subsequent read-only `probe` reported `target_count=1`, `state=DEVICE_PRESENT`, and the expected live WinUSB topology, including IF0 endpoint IN81. Its one-second read returned `probe=FAILED controller_win32=1460` (`ERROR_TIMEOUT`); no controller input report arrived in that interval.
- Source inspection shows `ACTIVATING_CHATPAD` is logged before `RunSession` waits up to five seconds for the first controller report. The repeated five-second losses match that readiness wait timing out. Cause of the absent report is not established; this is not evidence of broker authorization, XUSB, XInput, or rumble failure.
- No service, PnP, driver, registry, trust, device, or boot mutation by the agent; `legacy/` untouched. Hardware XInput, rumble, reconnect, and crash recovery remain unqualified for the current broker architecture.

## Next

Live qualification is waiting for a controller input report. The remote user is away from the physical controller, and the probe confirms the device is present but IF0/IN81 returns `ERROR_TIMEOUT`. Do not repeat the looping `run` or probe while the physical controller cannot be awakened. When physical interaction is available, run the normal-user bridge once and verify it reaches `controller input polling started`, activation stages, and broker create:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-setup-session-b76336d\package\ChatpadBridge.exe" run
```

Do not repeat RepairBroker unless a new package is built. No virtual-controller or rumble acceptance may be claimed until the runner receives physical reports and broker/XInput evidence is captured.
