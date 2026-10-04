# Next Task

## TASK 8L-C4L2 — Repair failed-create broker cleanup

- Branch: `feature/chatpad-usermode-runner`; fix commit `299569e484ee61d993b5879ded04535e2848bb1f`, plus the current package-handoff continuity commit.
- Latest user run reached RUNNING, then broker create failed with `broker_pipe_closed:109`. The diagnostic log records `BackendException: Create first.` from cleanup. `CreateAsync` attempted `SubmitState(default)` after `Create()` failed; cleanup threw, then `StopAsync` repeated the invalid submission and terminated the service.
- Local fix tracks whether backend `Create()` returned successfully and submits neutral state only in that case. Callback clearing, disconnect, and dispose still run after failed creation; create errors remain surfaced. Focused regression passes.
- Package `artifacts/task-8lc4l2/build-broker-create-failure-299569e/package` is built from the fix commit. Independent manifest readback passed 214/214. Runner SHA-256 `0041E6B4CD834FDB36721DE0E0B5961EE5CC509765F19C0FAF215871A87FDE7F`; broker SHA-256 `4EA7684E41EA6CAD32BFD8C80468E3E299EA5A925A6909F7C6C9C1FE396CFD3D`.
- Managed suite after correction: 156 pass, 1 pipe-squatter test fails because the running broker owns the fixed pipe. C4 setup/readiness passed; native tests were skipped because native sources were unchanged. No service was stopped by this agent.

Do not mutate or restart the service automatically. Build, commit, and push the correction, then provide one elevated `RepairBroker` command and wait. After successful repair, launch from ordinary PowerShell. If another service error occurs, use the protected service log.

After commit/push and readiness regeneration, run the following.

Elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-create-failure-299569e\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After successful repair, ordinary PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-create-failure-299569e\package\ChatpadBridge.exe" run
```

If broker create fails again, inspect `C:\Program Files\ChatpadBridge\ChatpadBrokerService.log` before further implementation changes.

Acceptance: broker create succeeds and service remains running; verify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and graceful Ctrl+C cleanup. Reconnect, crash recovery, and rejected/disconnected client survival remain to qualify. Return full logs.

Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/BrokerSession.cs`, `tools/ChatpadVirtualXbox/BrokerSessionTests.cs`, and final package manifest/readiness.
