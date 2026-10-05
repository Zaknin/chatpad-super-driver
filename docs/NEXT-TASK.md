# TASK 8L-C4L2 — Publish and manually repair XUSB-gated broker

## Current state

- Required branch: `feature/chatpad-usermode-runner`; starting HEAD: `bea72ab2d7adf31561a6deaa74868456b73a93b1`. This task's continuity update is documentation-only; publish must regenerate readiness for the resulting pushed HEAD.
- Source package: `artifacts/task-8lc4l2/build-xusb-interface-gate-bea72ab/package`, built from exact source commit `bea72ab`.
- Offline checks: helper 168/168; focused native CTest 2/2; setup regressions repository 5/5, package 8/8, baseline 5/5, PnP restart 4/4, SCM argv 4/4; readiness artifacts 9/9; repository safety PASS; package hashes 214/214.
- Prepared immutable destination: `20261005T030811Z`; archive SHA-256 `1166065DB57CDD92081C3BE982FD7C3BF4F1BF1B93FED5D6DFF4804710AF2661`. Final `Publish` and independent remote readback are the immediate remaining offline steps.
- Prior package timestamp `20261005T030543Z` is bound to the old HEAD; do not use it after this docs-only commit.
- Live evidence: physical WinUSB/Chatpad and HID inputs worked. XInput scan found no slot, `XInputSetState` returned 1167, and `C:\Program Files\ChatpadBridge\Temp\HIDMaestro` did not exist. Rumble remains unqualified.

## Immediate next steps

1. Push the documentation-only commit to `origin/feature/chatpad-usermode-runner`.
2. Run `tools/Publish-ChatpadC4L2.ps1 -Mode Publish -UtcTimestamp 20261005T030811Z -BuildDirectory artifacts/task-8lc4l2/build-xusb-interface-gate-bea72ab -VerificationSummaryPath artifacts/task-8lc4l2/build-xusb-interface-gate-bea72ab/release-verification.json`.
3. Independently check the canonical publication's payload hashes against `.sha256` sidecars, absence of `.part` files, completion receipt, and exact pushed release identity.
4. Give the user one elevated manual command:
   `& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-xusb-interface-gate-bea72ab\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"`
5. Stop and wait for the user's RepairBroker output. If PASS, next use normal-user PowerShell for runtime and XInput/rumble checks.

## Safety

- Do not perform service lifecycle changes, driver binding, PnP/registry mutation, trust changes, reboot, elevated bridge execution, or global HIDMaestro cleanup.
- Do not claim XInput or rumble pass from HID/joy.cpl behavior. `legacy/` remains immutable.
