# Next Task

## TASK 8L-C4L2 — Rebuild after pipe read-before-impersonate fix and resume live qualification

- Branch: `feature/chatpad-usermode-runner`; start from the latest pushed source/docs commit recorded in `docs/WORKLOG.md`.
- User manually ran elevated `RepairBroker` for the peer-fault isolation package; it returned PASS and service RUNNING as LocalSystem. Physical binding was unchanged.
- The next normal-user run opened physical WinUSB and passed Chatpad activation stages 0–5. Broker returned `broker_peer_identity_failed: Unable to impersonate using a named pipe until data has been read from that pipe.` Service fault isolation worked; the remaining bug is operation ordering.
- Source change in progress: read a bounded initial frame with a five-second timeout, then call `RunAsClient` and validate the authorized SID/active local console session, then hand the buffered frame to the broker session. The client sends `ping` first. New regression checks that peer capture cannot occur before initial frame receipt.
- Focused managed suite: 149 passed; the single pipe-squatter test is blocked by the already-running installed service owning the fixed pipe. Native `broker-client|runner-lifecycle` previously passed 2/2 and native sources are unchanged. Final package/readiness/hash checks are pending.
- Do not install or repair the service automatically. After source commit and package verification, user must run the exact elevated `RepairBroker` command supplied in the handoff, then retry `ChatpadBridge.exe run` from ordinary PowerShell.
- Acceptance after repair: prove normal-user broker create and XInput, controller and Chatpad input, rumble callback, graceful cleanup, reconnect, crash recovery, and that malformed or disconnected clients do not terminate the broker. Preserve all existing identity and IPC bounds.
- Safety: no driver/PnP/registry/device changes, trust/security changes, reboot, elevated bridge run, or HIDMaestro global cleanup. Hard-client-crash physical rumble remains outside broker cleanup scope.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/BrokerPipeServer.cs`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and `tools/ChatpadVirtualXbox/OfflineTests.cs`.
