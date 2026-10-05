# TASK 8L-C4L2 — Continue live qualification from local console

## Current state

- Branch: `feature/chatpad-usermode-runner`; starting HEAD for this documentation update: `09acee749437256f5625a94b9cbea7bf97ed69f9`.
- The user ran package `artifacts/task-8lc4l2/build-rumble-recovery-2258de1/package/ChatpadBridge.exe` as a normal user. Chatpad activation succeeded and clean-start zero-rumble recovery was correctly skipped. Broker create then failed with `broker_peer_unauthorized`.
- Read-only checks confirmed the installed broker authorization SID matches the current account. The bridge process was in active RDP session `rdp-tcp#1` ID 1; `query session` showed no signed-in user at the local console. The service was Running.
- The approved broker policy restricts access to the specifically authorized user in the active local interactive console session and rejects RDP/remote sessions. This failure is expected in the observed RDP context. Do not change the authorization policy.
- Broker authorization failed before HIDMaestro create, so this run says nothing about XUSB, XInput, or rumble. The watcher output included only its zero-interface idle baseline, not an observation during successful create.
- Current live verdict remains PARTIAL. Physical XInput, rumble callback/output, reconnect, and crash recovery have not been qualified under the broker architecture.

## Next action

Ask the user to sign in locally at the physical machine and run the bridge from an ordinary PowerShell opened in that local console session (not an RDP terminal):

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-recovery-2258de1\package\ChatpadBridge.exe" run
```

Return the full output. Continue only after `broker_peer_unauthorized` is gone and broker creation reaches `state=RUNNING`. Then qualify exact XUSB interface/XInput slot and rumble. The read-only watcher may be run concurrently from a second normal-user PowerShell in the same local console session if interface-arrival timing still needs observation.

## Safety

- Do not weaken local-console/SID authorization or permit RDP clients.
- Do not run ChatpadBridge elevated; do not perform service repair, PnP/registry/device/driver/trust/boot mutation, or global HIDMaestro cleanup for this authorization result.
- Preserve the exact XUSB interface gate and HIDMaestro backend.
- Keep the result PARTIAL until local-console broker, XInput, physical rumble, reconnect, and crash-recovery evidence is collected.

## Inspect first

`docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md` entries, `tools/ChatpadVirtualXbox/BrokerPeerAuthorization.cs`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and `tools/ChatpadBridge` broker connection code.
