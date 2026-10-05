# Project State

Updated 2026-10-05 for the final offline C4L2 package handoff.

- Branch: `feature/chatpad-usermode-runner`; XUSB gate implementation commit `2c554fe118eec879fbe41ee925fbc188e36dc436`; latest package build commit `10e178cc035c09e260b8c5d20e88e86e81b027d7`.
- Live status: the user's earlier normal-user run proved WinUSB, Chatpad, HID input and changing Game Controller values. XInput returned no slot and `XInputSetState` returned 1167; rumble is not qualified. The service was last observed Running as LocalSystem. The user has not yet repaired from the XUSB-gated package.
- Source behavior: broker create now requires the exact present XUSB interface for the returned HIDMaestro controller token. If absent it returns `xusb_companion_unavailable` and performs owned-controller cleanup. This necessary device-side gate does not establish an interactive XInput slot or rumble.
- Verification: packaged managed self-test 168/168; focused native CTest `broker-client` and `runner-lifecycle` 2/2; setup checks repository 5/5, package identity 8/8, baseline 5/5, PnP restart 4/4, SCM argv 4/4; readiness archive/privacy 9/9; repository safety PASS. The exact package inventory audited 214/214 members with zero length or hash mismatches.
- Release: package build directory `artifacts/task-8lc4l2/build-xusb-interface-gate-10e178c`; prepared canonical target `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T025900Z`; deterministic archive SHA-256 `3A9CDDEF6803DF89AFD0CA910ECD26F7ECCC46FD6FBAE757CDDB430C21DA86ED`. Atomic publication follows the current continuity-only commit and refreshes readiness to that release identity.
- Safety: agent did not modify the live service, driver/PnP/registry/device state, trust, boot settings, or perform a reboot, elevated bridge run, or HIDMaestro global cleanup. `legacy/` is untouched.

## Next

Complete the prepared atomic publication, then the user manually runs the exact elevated `RepairBroker` command from the handoff. After repair, normal-user runtime must prove the exact XUSB gate, XInput slot, physical rumble, and remaining lifecycle cases.
