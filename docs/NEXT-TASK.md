# TASK 8L-C4L2 — Package and qualify authorized RDP access

## Current state

- Branch: `feature/chatpad-usermode-runner`; source change based on `667a4eb9976d8f78b91b3d54e1ea675d1aace4d1`.
- The user ran package `artifacts/task-8lc4l2/build-rumble-recovery-2258de1/package/ChatpadBridge.exe` as a normal user. Chatpad activation succeeded and clean-start zero-rumble recovery was correctly skipped. Broker create then failed with `broker_peer_unauthorized`.
- Read-only checks confirmed the installed broker authorization SID matches the current account. The bridge process was in active RDP session `rdp-tcp#1` ID 1; `query session` showed no signed-in user at the local console. The service was Running.
- The user explicitly requested RDP access. The broker now authorizes only the exact installed user SID from a non-anonymous local named-pipe client, regardless of whether that SID is in a console or RDP session. Different SIDs and remote pipe clients remain rejected.
- Broker authorization failed before HIDMaestro create, so this run says nothing about XUSB, XInput, or rumble. The watcher output included only its zero-interface idle baseline, not an observation during successful create.
- Focused managed offline self-test passes 168/168, including authorization acceptance for the same SID in an RDP session and rejection for wrong SID, invalid session, anonymous, and remote peers.
- The installed service still runs the prior helper payload. Rebuild and package from the committed source, verify hashes, publish, then ask the user to run RepairBroker before retrying runtime. Current live verdict remains PARTIAL.

## Next action

Finish package build and canonical publication from the current commit, then provide one elevated repair command to refresh the LocalSystem helper. After the user reports `RepairBroker` PASS, retry in their ordinary RDP PowerShell:

```powershell
& "<new build package>\ChatpadBridge.exe" run
```

Return the full output. Continue only after `broker_peer_unauthorized` is gone and broker creation reaches `state=RUNNING`. Then qualify exact XUSB interface/XInput slot and rumble. The read-only watcher may be run concurrently from a second normal-user PowerShell if interface-arrival timing still needs observation.

## Safety

- Preserve exact installed-SID and local named-pipe checks; do not permit arbitrary users or remote pipe clients.
- Do not run ChatpadBridge elevated. The user will perform the explicitly requested RepairBroker step manually; do not mutate service, PnP, registry, device, driver, trust, or boot state automatically.
- Preserve the exact XUSB interface gate and HIDMaestro backend.
- Keep the result PARTIAL until local-console broker, XInput, physical rumble, reconnect, and crash-recovery evidence is collected.

## Inspect first

`docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md` entries, `tools/ChatpadVirtualXbox/BrokerPeerAuthorization.cs`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and `tools/ChatpadBridge` broker connection code.
