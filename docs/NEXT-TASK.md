# Next Task

## TASK 8L-C4L2 — User-run broker install, then live qualification

- Branch: `feature/chatpad-usermode-runner`.
- Starting point: final continuity commit for this offline release; exact release identity commit is recorded in the published `readiness-identity.json` and `result-manifest.json`. Package build commit: `76b89ae5e0a9a4ede9c26a78ec956989e309c3df`.
- Offline release: self-contained package at `artifacts/task-8lc4l2/build-c4l2-release-final/package`; canonical publication root `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261004T171319Z\`; archive SHA-256 `28178FA276BCF32624B94843477657FFB1E23E2BD09B35F74222F3FBD9D74AFB`.
- Preconditions: stop any running `ChatpadBridge.exe`; open elevated PowerShell as the same authorized Windows account from the active local console session (not RDP). The command installs only `ChatpadHidMaestroBroker`; it does not change the physical WinUSB binding. Do not start `ChatpadBridge.exe` elevated.

Run this exact command and return its complete output:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode InstallBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-c4l2-release-final\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

If setup does not return `Result: PASS`, stop and provide the full error output. After PASS, continue with the normal-user bridge session and qualify service identity/pipe authentication, physical WinUSB → bridge → broker → XInput state, Chatpad typing, rumble callback to the physical controller, reconnect, graceful cleanup, client crash/next-launch recovery, and service crash/restart. Record each result separately; offline tests do not count as live acceptance. The accepted limitation remains that the broker cannot stop physical rumble immediately after a hard bridge-process crash.

Safety: do not rerun install/repair/uninstall automatically, do not mutate driver/PnP/registry/device binding or security/trust, do not reboot, do not run the bridge elevated, and do not use HIDMaestro's global controller cleanup. Ask the user before any additional privileged lifecycle action if the exact `InstallBroker` step fails or produces ambiguous service state.

Inspect first: `docs/PROJECT-STATE.md`, the published readiness identity and result manifest, `artifacts/task-8lc4l2/build-c4l2-release-final/release-verification.json`, `tools/ChatpadSetup.ps1`, `tools/ChatpadVirtualXbox/BrokerPipeServer.cs`, and `tools/ChatpadWinUsbPoc/VirtualBrokerController.cpp`.
