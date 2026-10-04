# Next Task

## TASK 8L-C4L2 — Retry normal-user broker connection and live qualification

- Branch: `feature/chatpad-usermode-runner`; start from the pushed SCM identity-check fix commit recorded in the latest `docs/WORKLOG.md` entry.
- Current state: user-installed `ChatpadHidMaestroBroker` is `RUNNING` as `LocalSystem`, configured as `"C:\Program Files\ChatpadBridge\ChatpadVirtualXbox.exe" service`. The normal-user bridge opened physical WinUSB and activated Chatpad, then failed closed because `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` returned access denied for the LocalSystem service process.
- Fix: the client now verifies the pipe-server PID against `QueryServiceStatusEx` for the fixed service name, and validates the configured LocalSystem account and exact protected Program Files image plus `service` argument through `QueryServiceConfigW`. It does not open the service process or trust pipe events until those checks pass. It still rejects a stopped service, a mismatched PID, account, executable, or argument.
- Read-only validation on this machine confirmed the standard interactive token can query the service DACL/config/status (`sc.exe sdshow` and `sc.exe qc`) and that the service is running. Focused native tests passed `broker-client` and `runner-lifecycle` 2/2, with 20 broker-client assertions. The replacement package/readiness must be generated after the fix commit and its code bytes verified against the build manifest.
- Preconditions: ensure no other `ChatpadBridge.exe` run owns the physical device; start the bridge from ordinary, non-elevated PowerShell. Do not reinstall/reconfigure the broker unless the client reports SCM access denied; do not run the bridge elevated.

After the new package path is recorded in the latest worklog, run:

```powershell
& "<new-build-directory>\package\ChatpadBridge.exe" run
```

If it reaches `state=RUNNING` and creates the virtual Xbox, verify XInput/controller input, Chatpad typing, and rumble callback. Then stop with Ctrl+C and report the full output. Continue with reconnect, graceful cleanup, client crash/next-launch recovery, and service crash/restart only after the basic normal-user path passes.

Safety: no service lifecycle changes, driver/PnP/registry/device binding changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. After a hard bridge crash, physical rumble is outside the broker's cleanup capability; the documented next-launch recovery is a separate qualification.

Inspect first: latest `docs/WORKLOG.md` C4L2 continuation, `tools/ChatpadWinUsbPoc/VirtualBrokerController.cpp`, focused test results under ignored `artifacts/task-8lc4l2/`, and the latest package `build-manifest.json`.
