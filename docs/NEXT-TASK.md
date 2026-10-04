# Next Task

## TASK 8L-C4L2 — Install handshake-order fix and continue normal-user qualification

- Branch: `feature/chatpad-usermode-runner`; implementation commit `f5d5885c73ec10d3d33ac30ad68eaf8ceb543290` with the final package handoff continuity commit.
- User previously repaired the peer-fault package. The subsequent normal-user run exposed that .NET requires the server to read pipe data before `RunAsClient`. Source now reads a bounded initial frame with a five-second deadline, authenticates the peer SID/active local console session, and only then dispatches the buffered first frame.
- Final package: `artifacts/task-8lc4l2/build-broker-read-before-impersonation-f5d5885/package`; all 214 package hashes/lengths match its build manifest. Focused native CTest passed 2/2. Managed self-test reported 149 passed and one pipe-squatter failure because the installed broker owns the fixed pipe.
- Preconditions: no other `ChatpadBridge.exe` process owns the device. Keep the bridge non-elevated. The service must be manually repaired because its executable changed. Do not install or repair it automatically.

Run this exact command from elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-read-before-impersonation-f5d5885\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After successful repair, retry from ordinary PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-read-before-impersonation-f5d5885\package\ChatpadBridge.exe" run
```

Acceptance: confirm the broker create succeeds and service remains running; verify virtual XInput, controller and Chatpad input, rumble callback, then graceful Ctrl+C cleanup. Reconnect, client crash recovery, and malformed/disconnected peer survival remain later live checks. Return complete logs.

Safety: no automatic service lifecycle operation, driver/PnP/registry/device change, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest TASK 8L-C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/BrokerPipeServer.cs`, and the final package manifest/readiness.
