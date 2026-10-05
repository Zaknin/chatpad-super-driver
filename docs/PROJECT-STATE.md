# Project State

Updated 2026-10-05 after publishing the C4L2 startup-polling correction.

- Branch: `feature/chatpad-usermode-runner`. Implementation/package build commit: `a6b304f1da41de83908f75aebfb32d9533ee728b`. Published release identity commit: `624d3b7e9385f4e24307f9e61840f84b0f3b1b4a`. This final documentation-only closeout advances repository HEAD; no packaged source files changed afterward.
- Live status: the user previously repaired the broker successfully; service was reported Running as LocalSystem. A subsequent normal-user run failed the initial zero-rumble write with Win32 1460 (once 121) before virtual create. XInput/rumble remain unqualified for the failing run.
- Diagnosis/fix: runner previously stopped IF0/81 reads after its first readiness report until after Chatpad activation, initial rumble, and potentially slow broker create. `ControllerInputPump` now owns continuous controller reads from before activation, caches state during startup, and streams latest state after create. Required zero-rumble write and exact XUSB gate remain unchanged. This is a leading source-based cause, not yet hardware-confirmed.
- Offline verification PASS: helper self-test 504/504 across three runs; focused native CTest 3/3; setup checks PASS (5/5 repository identity, 8/8 package identity, 5/5 baseline, 4/4 PnP restart, 4/4 SCM argv); readiness 9/9; publication receipts 5/5; repository safety PASS. Package: 214 members, all lengths and SHA-256 match manifest/readiness.
- Published release: `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T035300Z`; archive SHA-256 `23BA57F588630F61D811F1A33F75A0FAA57BCAED35DFF73608CD4B66D17E0695`. Independent readback verified five payload sidecars and receipt sidecar; zero `.part` files. The release manifest/readiness binds to release identity commit `624d3b7`; this final documentation-only commit does not change package inputs. The user does not need another elevated setup action for this normal-user executable update.
- Safety: agent performed no service, PnP, driver binding, registry, trust, device, reboot, elevated bridge, or global HIDMaestro cleanup action; `legacy/` untouched.

## Next

Have the user launch the newly published package's `ChatpadBridge.exe run` in ordinary, non-elevated PowerShell and return the complete log. Confirm startup polling begins before activation, the initial zero-rumble write succeeds, and the XUSB-gated virtual controller is created. Then resume separate XInput and physical rumble qualification.
