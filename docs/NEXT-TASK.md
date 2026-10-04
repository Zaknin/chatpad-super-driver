# Next Task

## TASK 8L-C4L2 — Repair broker package and continue normal-user live qualification

- Branch: `feature/chatpad-usermode-runner`; implementation commit `0f2540ee2ac89d0ad90875d36fb3883021eb5ff2` plus the pushed package-handoff continuity update.
- Current service: user-installed `ChatpadHidMaestroBroker` is read-only confirmed RUNNING as LocalSystem, with binary command line `"C:\Program Files\ChatpadBridge\ChatpadVirtualXbox.exe" service`. This task has not changed it.
- Current runtime evidence: package `build-broker-scm-identity-f273416` opened physical WinUSB and passed Chatpad activation stages 0–5, then broker creation failed with `broker_control_write_failed:232`. Windows logged service exit code 1 and SCM restart on a pipe connection. The specific identity API failure is not yet known.
- Source correction: `BrokerPipeServer` catches peer identity exceptions and pipe fault-write failures per connection, emits bounded v1 faults, and continues accepting clients. Session errors are cleaned up and reported to the connected client. Focused native CTest passed 2/2. Managed self-test reported 148 pass and one environment-limited pipe-squatter failure because the installed service owns the fixed pipe. Final package `artifacts/task-8lc4l2/build-broker-peer-fault-isolation-0f2540e/package` has all 214 member lengths/hashes matched, and readiness names implementation commit `0f2540ee2ac89d0ad90875d36fb3883021eb5ff2`.
- Preconditions: no other bridge process owns the physical device. Keep ChatpadBridge in ordinary, non-elevated PowerShell. The service's executable changed, so user must manually run elevated `RepairBroker` using the final package/readiness below before retrying the runner.

Elevated setup command after final package regeneration:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-peer-fault-isolation-0f2540e\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After successful repair, run the final package from ordinary PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-peer-fault-isolation-0f2540e\package\ChatpadBridge.exe" run
```

Acceptance: broker stays running through peer identity errors and serves the normal-user lease; verify virtual XInput/button/stick/trigger state, Chatpad typing, rumble callback to the physical controller, graceful Ctrl+C neutralization/release, then separately qualify reconnect and crash recovery. Return full logs. Do not run bridge elevated.

Safety: no automatic service install/repair/start/stop/uninstall, driver/PnP/registry/device changes, trust/security changes, reboot, or HIDMaestro global cleanup. After hard client crash, physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entry in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/BrokerPipeServer.cs`, `tools/ChatpadVirtualXbox/OfflineTests.cs`, and the final package manifest/readiness.
