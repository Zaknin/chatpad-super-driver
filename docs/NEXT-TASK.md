# Next Task

## TASK 8L-C4L2 — Capture broker service failure and continue qualification

- Branch: `feature/chatpad-usermode-runner`, starting HEAD `2daa6a4e3a23ba3e250600705f9a08323f84b4b0`; locality-fix implementation is `3961374159a2b095cd0810a1e16c5bb5334bfd5d`.
- User repaired and ran `build-broker-local-pipe-229-3961374`. WinUSB and Chatpad activation passed, then broker create failed with `broker_pipe_closed:109`. SCM 7023 reports generic service exit code 1 and SCM 7031 scheduled recovery; the actual exception was lost because the service writes it only to `Console.Error`.
- Source adds a bounded, single-line service-failure log at `C:\Program Files\ChatpadBridge\ChatpadBrokerService.log`, under the protected install root. The next package build and package hash verification are pending.
- Managed self-test: 155 pass, 1 pipe-squatter test fails because the running broker owns the fixed pipe. The broker service was not stopped.

Do not mutate or restart the service automatically. After building, committing, and pushing the logging package, provide one elevated `RepairBroker` command. After repair succeeds, launch bridge only from ordinary non-elevated PowerShell and preserve the service log if the pipe closes again.

The package path and commands will be recorded after the build completes.

Acceptance: broker create succeeds and service remains running; verify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and graceful Ctrl+C cleanup. Reconnect, crash recovery, and rejected/disconnected client survival remain to qualify. Return full logs.

Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/WindowsServiceHost.cs`, `tools/ChatpadVirtualXbox/BrokerServiceDiagnostics.cs`, and final package manifest/readiness.
