# Project State

Updated 2026-10-05 for the C4L2 startup-polling correction.

- Branch: `feature/chatpad-usermode-runner`; implementation and exact package build commit: `a6b304f1da41de83908f75aebfb32d9533ee728b`. A documentation-only release-preparation commit will follow; publisher will bind final readiness to its pushed HEAD.
- Live status: user previously repaired the broker successfully; service was reported Running as LocalSystem. A subsequent normal-user run failed the initial zero-rumble write with Win32 1460 (once 121) before virtual create. XInput/rumble remain unqualified for that run.
- Diagnosis/fix: the runner had stopped IF0/81 reads after its first readiness report until after Chatpad activation, initial rumble, and potentially slow broker create. The `ControllerInputPump` now owns continuous controller reads from before activation, caches state during startup, and streams latest state after create. The required zero-rumble and exact XUSB gate are unchanged. This is a leading source-based cause, not yet hardware-confirmed.
- Offline verification: helper self-test 504/504 over three runs; focused native CTest 3/3 (`controller-input-pump`, `broker-client`, `runner-lifecycle`); setup tests PASS (repository 5/5, package identity 8/8, baseline 5/5, PnP restart 4/4, SCM argv 4/4); readiness archive/privacy 9/9; publication receipt tests 5/5; repository safety PASS. Package manifest lists 214/214 expected members and matches the generated readiness.
- Prepared release: `20261005T035300Z`; archive SHA-256 `23BA57F588630F61D811F1A33F75A0FAA57BCAED35DFF73608CD4B66D17E0695`; canonical path `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T035300Z`. It is prepared but not yet published. Previous immutable release `20261005T030811Z` was published and its package was used for the user's successful RepairBroker step.
- Safety: no service, PnP, driver binding, registry, trust, device, reboot, elevated bridge, or global HIDMaestro cleanup operation by the agent; `legacy/` untouched.

## Next

Push the documentation-only preparation update and publish `20261005T035300Z`; verify canonical payload SHA-256 sidecars, no partial files, completion receipt, and exact release identity. Then ask the user to run the new packaged `ChatpadBridge.exe` in ordinary PowerShell. No elevated service repair is needed because this release only changes the normal-user bridge and the service helper payload is unchanged.
