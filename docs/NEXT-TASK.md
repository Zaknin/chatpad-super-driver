# TASK 8L-C4L2 — Live retry of startup-polling correction

## Current state

- Branch: `feature/chatpad-usermode-runner`; implementation/build commit `a6b304f1da41de83908f75aebfb32d9533ee728b`; release readiness identity `624d3b7e9385f4e24307f9e61840f84b0f3b1b4a`. This closeout changes documentation only.
- Published package path: `artifacts/task-8lc4l2/build-startup-input-poll-a6b304f/package`; runner SHA-256 `5E26662C53FD5899B1AFFFD7E09E1DDA6E3C869861567F91423B0BEF66985687`.
- Canonical immutable release: `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T035300Z`; archive SHA-256 `23BA57F588630F61D811F1A33F75A0FAA57BCAED35DFF73608CD4B66D17E0695`. Five payload sidecars, completion receipt hash, no `.part`, and release identity passed independent readback.
- Offline checks PASS: helper 504/504 across three runs; focused CTest 3/3; setup regressions and readiness pass; 214/214 package members verified.
- Source-order diagnosis is still a hypothesis until a normal-user hardware run confirms the startup rumble write now succeeds. User previously reported successful manual broker repair; do not request another elevated repair because service helper bytes are unchanged.

## Next steps

1. Ask the user to run from ordinary, non-elevated PowerShell:
   `& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-startup-input-poll-a6b304f\package\ChatpadBridge.exe" run`
2. Request the full output after Ctrl+C. Check for `controller input polling started before Chatpad activation`, absence of the startup zero-rumble timeout, and `virtual Xbox created and initial controller state submitted`.
3. If virtual creation succeeds, separately resume XInput slot, Chatpad, and physical rumble qualification.

## Safety and acceptance

- Do not perform service lifecycle changes, driver binding, PnP/registry mutation, trust changes, reboot, elevated bridge execution, or HIDMaestro global cleanup.
- Keep the initial zero-rumble command and exact XUSB interface gate strict. Do not claim XInput or rumble pass from HID/joy.cpl behavior.
- Inspect first: `Runner.cpp`, `ControllerInputPump.{h,cpp}`, `controller-input-pump-tests.cpp`, and the release manifest/receipts.
