# Next Task

## TASK 8L-C4L2 — Repair failed-create broker cleanup

- Branch: `feature/chatpad-usermode-runner`; start from latest pushed continuity HEAD; implementation baseline `a5a082f3081d08c16e6e728005c8f784ce1fd93`.
- Latest user run reached RUNNING, then broker create failed with `broker_pipe_closed:109`. The diagnostic log records `BackendException: Create first.` from cleanup. `CreateAsync` attempted `SubmitState(default)` after `Create()` failed; cleanup threw, then `StopAsync` repeated the invalid submission and terminated the service.
- Local fix tracks whether backend `Create()` returned successfully and submits neutral state only in that case. Callback clearing, disconnect, and dispose still run after failed creation; create errors remain surfaced. Focused regression passes.
- Diagnostic package `artifacts/task-8lc4l2/build-broker-service-failure-log` predates this correction and must not be installed again. Build and package verification are pending.
- Managed suite after correction: 156 pass, 1 pipe-squatter test fails because the running broker owns the fixed pipe. No service was stopped by this agent.

Do not mutate or restart the service automatically. Build, commit, and push the correction, then provide one elevated `RepairBroker` command and wait. After successful repair, launch from ordinary PowerShell. If another service error occurs, use the protected service log.

The exact package path and commands will be recorded after the build completes.

Acceptance: broker create succeeds and service remains running; verify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and graceful Ctrl+C cleanup. Reconnect, crash recovery, and rejected/disconnected client survival remain to qualify. Return full logs.

Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/BrokerSession.cs`, `tools/ChatpadVirtualXbox/BrokerSessionTests.cs`, and final package manifest/readiness.
