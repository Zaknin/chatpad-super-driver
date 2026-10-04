# Next Task

## TASK 8L-C4L2 — Capture broker service failure and continue qualification

- Branch: `feature/chatpad-usermode-runner`; diagnostics source commit `a5a082f3081d08c16e6eaececa2638c695154f5d`, plus the current package-handoff continuity commit.
- User repaired and ran `build-broker-local-pipe-229-3961374`. WinUSB and Chatpad activation passed, then broker create failed with `broker_pipe_closed:109`. SCM 7023 reports generic service exit code 1 and SCM 7031 scheduled recovery; the actual exception was lost because the service writes it only to `Console.Error`.
- Source adds a bounded, single-line service-failure log at `C:\Program Files\ChatpadBridge\ChatpadBrokerService.log`, under the protected install root.
- Package `artifacts/task-8lc4l2/build-broker-service-failure-log/package` is built from the diagnostics source commit. Independent manifest verification passed 214/214; runner SHA-256 `9709D08F35CC49457D967D9F09ECF6D2516C86D682BFCE51AD1590345D66209D`, broker SHA-256 `5C6C6BFBB34035B09C13589A35DE50FE4A214E9BA13D2B3AAB73057F7E486BAB`.
- Managed self-test: 155 pass, 1 pipe-squatter test fails because the running broker owns the fixed pipe. The broker service was not stopped.

Do not mutate or restart the service automatically. After committing/pushing the package handoff and regenerating readiness for final HEAD, provide one elevated `RepairBroker` command. After repair succeeds, launch bridge only from ordinary non-elevated PowerShell. If it fails, read `C:\Program Files\ChatpadBridge\ChatpadBrokerService.log` and use the recorded exception before changing runtime behavior.

Elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-service-failure-log\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After successful repair, ordinary PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-service-failure-log\package\ChatpadBridge.exe" run
```

The package path and commands will be recorded after the build completes.

Acceptance: broker create succeeds and service remains running; verify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and graceful Ctrl+C cleanup. Reconnect, crash recovery, and rejected/disconnected client survival remain to qualify. Return full logs.

Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/WindowsServiceHost.cs`, `tools/ChatpadVirtualXbox/BrokerServiceDiagnostics.cs`, and final package manifest/readiness.
