# Next Task

## TASK 8L-C4L2 — Retry user-run broker install with corrected SCM argv

- Branch: `feature/chatpad-usermode-runner`.
- Source fix commit: `2315358c06243629892e33cfe2b294483a5b7a3a`; the final documentation-only commit follows. Readiness must identify that final current HEAD and the fresh package below.
- The previous elevated attempt failed before service creation with `sc.exe create` exit 1639. Read-only verification found no `ChatpadHidMaestroBroker` SCM/CIM/registry registration. Existing copied runtime/config bytes may remain under Program Files and are handled by the normal package hash verification/copy path.
- Retry package: `artifacts/task-8lc4l2/build-installbroker-argv-2315358/package`. The previous canonical archive at `20261004T171319Z` contains the old setup argv bug and must not be used.
- Preconditions: stop any running `ChatpadBridge.exe`; use elevated PowerShell as the authorized account from the active local console session (not RDP). Do not run the bridge elevated.

Run this exact command after final readiness regeneration, then return its complete output:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode InstallBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-installbroker-argv-2315358\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

If setup fails or does not return `Result: PASS`, stop and provide the full output; do not retry, repair, uninstall, or clean up service files automatically. After PASS, continue normal-user qualification for pipe/server identity, WinUSB → bridge → broker → XInput, Chatpad typing, physical rumble callback, reconnect, graceful cleanup, client crash/next-launch recovery and service crash/restart.

Safety: do not mutate driver/PnP/registry/device binding or trust/security, reboot, or run `ChatpadBridge.exe` elevated. Do not call HIDMaestro's global controller cleanup. The already confirmed absent service registration does not prove copied Program Files files are absent; the setup command verifies and replaces exact packaged members.

Inspect first: `docs/PROJECT-STATE.md`, current `artifacts/task-8lc4l2/readiness-input.json`, `tools/ChatpadSetup.ps1`, `tools/ChatpadC4Package.psm1`, and the `build-manifest.json` in the retry build directory.
