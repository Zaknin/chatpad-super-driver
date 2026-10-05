# TASK 8L-C4L2 — Require the XUSB companion before reporting virtual creation

## Current state

- Branch: `feature/chatpad-usermode-runner`; XUSB success-gate source commit `2c554fe118eec879fbe41ee925fbc188e36dc436` is pushed. The required package base is the exact HEAD after this continuity update is committed; resolve it with `git rev-parse HEAD`.
- User live evidence: physical WinUSB and Chatpad work; HID/Game Controller values change. XInput enumeration found no slot and `XInputSetState` returned 1167. The service temp log directory `C:\Program Files\ChatpadBridge\Temp\HIDMaestro` was absent when checked elevated.
- Pinned HIDMaestro source treats XUSB interface and XInput slot timeouts as nonfatal. The broker now has an exact-identity XUSB-interface gate after `CreateController`; absence fails creation instead of reporting a usable virtual Xbox.
- Focused source verification: managed self-test 168/168; native `broker-client` and `runner-lifecycle` CTest 2/2. Source changes are committed and pushed; package/readiness are not yet built or published.

## Required continuation

1. Review the diff and `git diff --check`; commit source and continuity updates, then push only `feature/chatpad-usermode-runner`.
2. Build a fresh C4L2 package/readiness from the exact pushed HEAD; audit all package SHA-256 members and rerun focused checks.
3. Atomically publish under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\` and verify sidecars/readback.
4. Give the user one exact elevated `RepairBroker` command and stop for their manual output.
5. If repair passes, run as a normal user. Require the broker's exact XUSB interface gate to pass, then verify one XInput slot, buttons/sticks/triggers, Chatpad input, rumble, graceful cleanup, reconnect, and crash recovery.

## Safety

- Do not run the bridge elevated or change the live service/PnP/registry/device state from the agent. The user performs the elevated repair manually.
- No driver binding, trust/security change, reboot, broad cleanup, or edits under `legacy/`.
- Do not claim rumble or XInput acceptance from `joy.cpl`/HID values; require a connected XInput slot and physical motor response.

## Inspect first

- `tools/ChatpadVirtualXbox/XusbInterfaceQualification.cs`
- `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`
- `tools/ChatpadVirtualXbox/OfflineTests.cs`
- latest TASK 8L-C4L2 entries in `docs/WORKLOG.md`
