# TASK 8L-C4L2 — Manual XUSB-gated broker repair and XInput qualification

## Current state

- Source: `feature/chatpad-usermode-runner`; implementation commit `2c554fe118eec879fbe41ee925fbc188e36dc436`; package build commit `10e178cc035c09e260b8c5d20e88e86e81b027d7`.
- The package for build HEAD `10e178c` was published at `20261005T025900Z`, but HEAD later advanced. Do not use it for setup; its readiness identity is stale for current HEAD. A new package and readiness at a new timestamp are required.
- The XUSB gate checks the present `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}` interface list and exact HIDMaestro controller token. Missing interface now fails create instead of reporting a usable virtual Xbox.
- Offline results on build HEAD `10e178c`: managed 168/168; focused native CTest 2/2; C4 setup regressions PASS; readiness archive/privacy 9/9; repository safety PASS; package hashes 214/214. Archive SHA-256 for the prior timestamp was `3A9CDDEF6803DF89AFD0CA910ECD26F7ECCC46FD6FBAE757CDDB430C21DA86ED`.
- User's prior XInput scan returned no slots and `XInputSetState` returned 1167. Do not claim rumble or XInput pass from HID/joy.cpl behavior.

## Immediate handoff

1. Build a fresh C4L2 package from the exact current pushed HEAD, rerun focused package checks, and publish with a new UTC timestamp. Do not reuse `20261005T025900Z`; its immutable destination already exists and refuses overwrite.
2. After publication succeeds, give the user one exact elevated `RepairBroker` command using the new package and the commit-bound `artifacts/task-8lc4l2/readiness-input.json`. Stop and wait for the user's output.
3. After RepairBroker passes, have the user run `ChatpadBridge.exe run` from ordinary PowerShell. If create fails, collect its new exact `xusb_companion_unavailable` or probe error. If it passes, test XInput slot visibility, buttons/sticks/triggers, Chatpad input, and brief rumble, then continue reconnect, graceful cleanup, and crash recovery qualification.

## Safety

- Agent must not perform service lifecycle changes, driver binding, PnP/registry mutation, trust change, reboot, elevated bridge execution, or broad HIDMaestro cleanup. User performs only the separate manual elevated repair.
- Do not edit `legacy/` or report rumble pass without physical vibration evidence.
