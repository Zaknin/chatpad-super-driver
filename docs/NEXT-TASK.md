# TASK 8L-C4L2 — Qualify RDP runtime after broker repair

## Current state

- Branch: `feature/chatpad-usermode-runner`; begin from the current pushed branch HEAD (confirm with `git rev-parse HEAD`); runtime package source commit `b76336dd021cc561fa9cfe4f65b1dcc33c78da7b`.
- User manually ran elevated `RepairBroker` from RDP using `artifacts/task-8lc4l2/build-rdp-setup-session-b76336d/package`; it passed and reported the service Running as LocalSystem with 197 runtime members.
- Two subsequent normal-user RDP runs opened WinUSB, then cycled through `ACTIVATING_CHATPAD` and `DEVICE_LOST` every five seconds; the user stopped them cleanly after four and six reconnects. The user is away from the physical controller and cannot press it remotely.
- The read-only `probe` found one present target and the expected topology, but its IF0/IN81 read failed with Win32 1460 (`ERROR_TIMEOUT`) after one second. No controller report arrived.
- The run emitted no `controller input polling started`, activation-stage, broker-create, or virtual-Xbox messages. Source inspection shows the runner logs `ACTIVATING_CHATPAD` before waiting up to five seconds for the first controller report. This points to the physical controller readiness wait, but the reason no first report arrived is unknown.
- Broker creation, XUSB interface, XInput, rumble, reconnect recovery, and crash recovery are not established by this run. Verdict remains PARTIAL.
- The current build package remains runnable, but a future setup/repair must use readiness regenerated for the then-current HEAD.

## Next action

Resume live qualification when physical controller input is available. Run the normal-user bridge once:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-setup-session-b76336d\package\ChatpadBridge.exe" run
```

Do not retry while the controller cannot be awakened. Acceptance still requires successful broker create, exact XUSB interface and XInput proof, Chatpad input, rumble callback, reconnect cleanup, and crash recovery. Do not repeat RepairBroker without a new exact-HEAD package.

## Safety and acceptance

- Do not run ChatpadBridge elevated.
- Keep broker authorization restricted to the configured SID and local named-pipe clients; do not weaken identity checks further.
- No automatic service, PnP, registry, device, driver, trust, boot, or HIDMaestro global cleanup.
- `legacy/` remains immutable.
- Continue to XUSB/XInput and rumble checks only after the runner reaches broker create. Report live statuses separately; do not infer rumble from controller enumeration or button input.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`, then inspect `tools/ChatpadWinUsbPoc/Runner.cpp` around `WaitController`, `RunSession`, and reconnect handling.
