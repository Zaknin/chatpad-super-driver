# Next Task

## TASK 8L-C4L2 — Install and qualify the broker locality fix

- Branch: `feature/chatpad-usermode-runner`; continue from current pushed continuity HEAD, whose parent is `186f3283cb024d831760da0c10faba667a85e543`. Implementation/package source fix is `3961374159a2b095cd0810a1e16c5bb5334bfd5d`.
- Latest user log used the previous `build-broker-read-before-impersonation-f5d5885` package. Its `broker_peer_unauthorized` result does not test the fix. Root cause from the preceding run: `GetNamedPipeClientComputerNameW` returned 229 (`ERROR_PIPE_LOCAL`) for the local pipe; prior code treated every false result as remote. The current source accepts precisely that local status, validates returned computer name on success, and rejects other query errors.
- Package: `artifacts/task-8lc4l2/build-broker-local-pipe-229-3961374/package`; all 214 hashes and lengths matched. C4 setup/readiness checks passed; native focused tests passed 2/2. Managed suite: 153 passed, 1 pipe-squatter failure because the installed broker holds the fixed pipe.
- User must manually repair the installed broker from the new package. Do not perform service lifecycle operations automatically. The runner command must also use the same new package, not `build-broker-read-before-impersonation-f5d5885`.

After successful repair, launch bridge only from ordinary non-elevated PowerShell.

Elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-local-pipe-229-3961374\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After successful repair, ordinary PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-broker-local-pipe-229-3961374\package\ChatpadBridge.exe" run
```

Acceptance: broker create succeeds and service remains running; verify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and graceful Ctrl+C cleanup. Reconnect, crash recovery, and rejected/disconnected client survival remain to qualify. Return full logs.

Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and final package manifest/readiness.
