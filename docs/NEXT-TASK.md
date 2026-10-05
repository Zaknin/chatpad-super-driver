# TASK 8L-C4L2 — Repair broker and qualify authorized RDP access

## Current state

- Branch: `feature/chatpad-usermode-runner`; package source commit: `1044e226f9d5da86d347b91137b97e026c892f9a`; release identity is this docs-only continuity closeout commit.
- The user ran package `artifacts/task-8lc4l2/build-rumble-recovery-2258de1/package/ChatpadBridge.exe` as a normal user. Chatpad activation succeeded and clean-start zero-rumble recovery was correctly skipped. Broker create then failed with `broker_peer_unauthorized`.
- Read-only checks confirmed the installed broker authorization SID matches the current account. The bridge process was in active RDP session `rdp-tcp#1` ID 1; `query session` showed no signed-in user at the local console. The service was Running.
- The user explicitly requested RDP access. The broker now authorizes only the exact installed user SID from a non-anonymous local named-pipe client, regardless of whether that SID is in a console or RDP session. Different SIDs and remote pipe clients remain rejected.
- Broker authorization failed before HIDMaestro create, so this run says nothing about XUSB, XInput, or rumble. The watcher output included only its zero-interface idle baseline, not an observation during successful create.
- Focused managed offline self-test passes 168/168, including authorization acceptance for the same SID in an RDP session and rejection for wrong SID, invalid session, anonymous, and remote peers.
- The installed service still runs the prior helper payload. New package is built and hash-audited; focused release verification passed. Prepared canonical archive is `20261005T065100Z` with SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`. Publish it atomically, then ask the user to run the elevated RepairBroker command below. Current live verdict remains PARTIAL.

## Next action

After atomic publication, have the user run this exact command in elevated PowerShell to refresh the LocalSystem helper:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rdp-peer-authorization-1044e22\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After RepairBroker reports PASS, have the user retry in their ordinary RDP PowerShell and return the full output. Continue only after `broker_peer_unauthorized` is gone and broker creation reaches `state=RUNNING`. Then qualify exact XUSB interface/XInput slot and rumble. The read-only watcher may be run concurrently from a second normal-user PowerShell if interface-arrival timing still needs observation.

## Safety

- Preserve exact installed-SID and local named-pipe checks; do not permit arbitrary users or remote pipe clients.
- Do not run ChatpadBridge elevated. The user will perform the explicitly requested RepairBroker step manually; do not mutate service, PnP, registry, device, driver, trust, or boot state automatically.
- Preserve the exact XUSB interface gate and HIDMaestro backend.
- Keep the result PARTIAL until local-console broker, XInput, physical rumble, reconnect, and crash-recovery evidence is collected.

## Inspect first

`docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md` entries, `tools/ChatpadVirtualXbox/BrokerPeerAuthorization.cs`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and `tools/ChatpadBridge` broker connection code.
