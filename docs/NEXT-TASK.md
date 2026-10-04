# Next Task

## TASK 8L-C4L2 — Rebuild after local-pipe locality fix and continue qualification

- Branch: `feature/chatpad-usermode-runner`; start from the latest pushed implementation/continuity commits in `docs/WORKLOG.md`.
- The user manually repaired the read-before-impersonate package. The subsequent normal-user run opened WinUSB, passed Chatpad activation stages 0–5, then returned `broker_peer_unauthorized`.
- Root cause: on this Windows build, `GetNamedPipeClientComputerNameW` returned Win32 229, `ERROR_PIPE_LOCAL`, for this local pipe. The code treated all API failures as remote. The fix accepts only 229 as a local pipe, compares the returned name when the API succeeds, and rejects all other query failures.
- New managed locality regressions pass for local 229, matching/mismatched names, and fail-closed unrelated errors. Managed self-test totals: 153 pass, 1 pipe-squatter failure because the installed broker owns the fixed pipe. Final package/readiness/hash checks are pending.
- No automatic broker service lifecycle action. After rebuilding, user must manually run elevated `RepairBroker`, then retry the runner from ordinary PowerShell.
- Acceptance: broker create, XInput state, controller and Chatpad input, rumble callback, graceful cleanup, reconnect, crash recovery, and service survival after invalid/disconnected clients.

After final package build, provide the exact commands:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\<FINAL_BUILD_DIRECTORY>\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\<FINAL_BUILD_DIRECTORY>\package\ChatpadBridge.exe" run
```

Keep ChatpadBridge non-elevated. No driver/PnP/registry/device changes, trust/security changes, reboot, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 worklog entries, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, `tools/ChatpadVirtualXbox/OfflineTests.cs`, final package manifest/readiness.
