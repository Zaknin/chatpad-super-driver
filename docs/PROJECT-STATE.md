# Project State

Updated 2026-10-05 for the XUSB-gated C4L2 manual repair handoff.

- Branch: `feature/chatpad-usermode-runner`. Source package was built from pushed commit `bea72ab2d7adf31561a6deaa74868456b73a93b1`; this continuity update advances the release identity by documentation only. The publisher will regenerate readiness for the resulting HEAD before publication.
- Live status: the user's normal-user bridge previously produced working WinUSB, Chatpad, HID input and changing Game Controller values, but XInput enumeration returned no slot and `XInputSetState` returned 1167. The expected service temp log directory `C:\Program Files\ChatpadBridge\Temp\HIDMaestro` is absent. XInput/rumble remain unqualified. Service was last observed Running as LocalSystem; agent has not changed it.
- Source behavior: broker create requires the present XUSB interface for the exact HIDMaestro controller identity. Missing interface fails create as `xusb_companion_unavailable` and triggers owned-controller cleanup. The gate is not live XInput/rumble proof.
- Verification on the exact package source: managed helper self-test 168/168; focused native CTest 2/2; C4 setup regressions PASS (repository identity 5/5, package identity 8/8, baseline 5/5, PnP restart 4/4, SCM argv 4/4); readiness archive/privacy 9/9; repository safety PASS. Package audit: 214 expected/214 actual members, zero missing, extra, length, or SHA-256 mismatches.
- Prepared release: timestamp `20261005T030811Z`; archive SHA-256 `1166065DB57CDD92081C3BE982FD7C3BF4F1BF1B93FED5D6DFF4804710AF2661`; canonical target `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T030811Z`. This target is prepared but not yet published at the time of this continuity commit. An earlier immutable release at `20261005T030543Z` is bound to the previous HEAD and must not be used for RepairBroker.
- Safety: no service lifecycle/configuration action, driver binding, PnP/registry/device mutation, trust change, reboot, elevated bridge run, or HIDMaestro global cleanup by the agent. `legacy/` untouched.

## Next

Publish the prepared release from the new pushed HEAD, verify its remote SHA-256 sidecars and completion receipt, then hand the user the exact elevated `RepairBroker` command using the final readiness. After manual repair, normal-user runtime must prove XUSB/XInput presence, physical rumble, and remaining lifecycle cases.
