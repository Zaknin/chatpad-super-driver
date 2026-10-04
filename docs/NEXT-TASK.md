# Next Task

## TASK 8L-C4L2 — Retry broker creation after read-only PnP scope check

- Branch: `feature/chatpad-usermode-runner`; source package implementation is commit `299569e484ee61d993b5879ded04535e2848bb1f`; continuity branch currently includes `76cc6b742b8bac0ca93652d96eff5dd610399868`.
- Current state: user manually repaired `ChatpadHidMaestroBroker` with `build-broker-create-failure-299569e` and confirmed it Running as LocalSystem. Normal-user runner opened WinUSB and passed Chatpad activation, then received `virtual_scope_conflict` before virtual controller creation. Installed runner and broker hashes equal the package. The service log is stale (19:17 UTC `Create first.`), not evidence about the 19:30 UTC run.
- Current read-only snapshot: one stale `SWD\HIDMAESTRO\HM_622C184E37F6891E` registry record has `ControllerIndex=0`, but `CM_Locate_DevNode` returns `CR_NO_SUCH_DEVNODE` and PnPUtil/Get-PnpDevice show no matching present node. The exact node present at the time of the broker failure is unknown because the error lacks its instance ID.

### Immediate user step

In ordinary, non-elevated PowerShell, retry the same package:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-create-failure-299569e\package\ChatpadBridge.exe" run
```

If it reaches `state=RUNNING`, test controller input and Chatpad, then test rumble once and stop with Ctrl+C. Send the complete output through `session ended` / `state=STOPPING`.

If the same `virtual_scope_conflict` appears, do not delete devices or registry keys. Capture read-only PnP state immediately and update the guard diagnostic to include the exact conflicting instance ID before another live retry.

### Preconditions and safety

- The existing elevated `RepairBroker` succeeded; no further service repair is needed for this retry.
- Do not run the bridge elevated. Do not stop/restart the service, remove devices, edit registry, invoke HIDMaestro global cleanup, change trust, or reboot.
- Preserve the guard's rule that a currently present ROOT/SWD index-zero device blocks creation.

### Acceptance

- Broker create succeeds and service remains Running.
- As a normal user, verify XInput slot, controller buttons/sticks/triggers, Chatpad, rumble callback to physical controller, and clean Ctrl+C virtual-device release.
- Continue with reconnect and crash-recovery qualification only after normal runtime succeeds.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `docs/PROJECT-STATE.md`, `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, and the package build manifest.
