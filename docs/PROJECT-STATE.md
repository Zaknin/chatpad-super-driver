# Project State

Updated 2026-10-04 for TASK 8L-C4L2 normal-user broker identity verification.

- Branch: `feature/chatpad-usermode-runner`; implementation is prepared for a continuity commit and push to `origin/feature/chatpad-usermode-runner`.
- User-run elevated setup succeeded: `ChatpadHidMaestroBroker` is `RUNNING` as `LocalSystem`, configured with `"C:\Program Files\ChatpadBridge\ChatpadVirtualXbox.exe" service`, and authorized SID `S-1-5-21-561199664-4233008424-1776012680-1000`. Physical binding was unchanged.
- The user's ordinary-user bridge opened the physical controller and activated Chatpad, then failed closed at `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` with Win32 5. The client now checks the pipe server PID against the named running SCM service and validates its LocalSystem account and exact protected executable command line using SCM query APIs; it never opens the LocalSystem process. The pipe identity gate remains before IPC event readers start.
- Focused native verification: build of `ChatpadWinUsbPoc` and `ChatpadBrokerClientTests` succeeded; `broker-client|runner-lifecycle` passed 2/2, and `ChatpadBrokerClientTests.exe` reported 20 checks, 0 failures. Read-only queries under the ordinary interactive token successfully read service status/config and service DACL. Live rerun with the new client package is still required.
- A fresh self-contained package and readiness identity must be generated after commit. The previous package in `artifacts/task-8lc4l2/build-installbroker-argv-2315358` contains the client identity bug and must not be used.
- Remaining live qualification: normal-user broker connection and virtual XInput, Chatpad input, rumble callback, reconnect, graceful cleanup, client crash/next-launch recovery, and service crash/restart. The accepted hard-client-crash physical-rumble limitation remains.
- Safety: this task performed no service install/configuration/start/stop, driver/PnP/registry/device mutation, trust/security change, reboot, or elevated bridge run. `legacy/` is untouched.
