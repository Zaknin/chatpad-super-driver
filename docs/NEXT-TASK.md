# TASK 8L-C4L2 — Qualify RDP runtime after broker repair

## Current state

- Branch: `feature/chatpad-usermode-runner`; begin from the current pushed branch HEAD (confirm with `git rev-parse HEAD`); runtime package source commit `b76336dd021cc561fa9cfe4f65b1dcc33c78da7b`.
- User manually ran elevated `RepairBroker` from RDP using `artifacts/task-8lc4l2/build-rdp-setup-session-b76336d/package`; it passed and reported the service Running as LocalSystem with 197 runtime members.
- First subsequent normal-user RDP run opened WinUSB, then cycled through `ACTIVATING_CHATPAD` and `DEVICE_LOST` every five seconds; user stopped it with Ctrl+C after four reconnects.
- The run emitted no `controller input polling started`, activation-stage, broker-create, or virtual-Xbox messages. Source inspection shows the runner logs `ACTIVATING_CHATPAD` before waiting up to five seconds for the first controller report. This points to the physical controller readiness wait, but the reason no first report arrived is unknown.
- Broker creation, XUSB interface, XInput, rumble, reconnect recovery, and crash recovery are not established by this run. Verdict remains PARTIAL.
- The current build package remains runnable, but a future setup/repair must use readiness regenerated for the then-current HEAD.

## Next action

Run one normal-user RDP attempt and press A or the Xbox button promptly after launch:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-setup-session-b76336d\package\ChatpadBridge.exe" run
```

If `controller input polling started` appears, continue until the broker result is known, then stop cleanly and return the full output. If the five-second retry cycle continues, stop with Ctrl+C and return the complete output and `%LOCALAPPDATA%\ChatpadBridge\logs\bridge.log`. Also return read-only physical controller presence/power evidence. Do not repeat RepairBroker without a new exact-HEAD package.

## Safety and acceptance

- Do not run ChatpadBridge elevated.
- Keep broker authorization restricted to the configured SID and local named-pipe clients; do not weaken identity checks further.
- No automatic service, PnP, registry, device, driver, trust, boot, or HIDMaestro global cleanup.
- `legacy/` remains immutable.
- Continue to XUSB/XInput and rumble checks only after the runner reaches broker create. Report live statuses separately; do not infer rumble from controller enumeration or button input.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`, then inspect `tools/ChatpadWinUsbPoc/Runner.cpp` around `WaitController`, `RunSession`, and reconnect handling.
