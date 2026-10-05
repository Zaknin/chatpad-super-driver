# TASK 8L-C4L2 — Remove the setup console-session gate

## Current state

- Branch: `feature/chatpad-usermode-runner`; starting HEAD: `53559b7e51f29ff2ba1c480abd26b948098dd0cd`.
- The user ran package `artifacts/task-8lc4l2/build-rumble-recovery-2258de1/package/ChatpadBridge.exe` as a normal user. Chatpad activation succeeded and clean-start zero-rumble recovery was correctly skipped. Broker create then failed with `broker_peer_unauthorized`.
- Read-only checks confirmed the installed broker authorization SID matches the current account. The bridge process was in active RDP session `rdp-tcp#1` ID 1; `query session` showed no signed-in user at the local console. The service was Running.
- The user explicitly requested RDP access. The broker now authorizes only the exact installed user SID from a non-anonymous local named-pipe client, regardless of whether that SID is in a console or RDP session. Different SIDs and remote pipe clients remain rejected.
- Broker authorization failed before HIDMaestro create, so this run says nothing about XUSB, XInput, or rumble. The watcher output included only its zero-interface idle baseline, not an observation during successful create.
- Focused managed offline self-test passes 168/168, including authorization acceptance for the same SID in an RDP session and rejection for wrong SID, invalid session, anonymous, and remote peers.
- The `20261005T065100Z` package was successfully published and sidecar-audited (archive SHA-256 `10050027E207E607E07CBE608BF1191D367A0441F2071FE18DCD20E92304FEB2`). User then attempted elevated RepairBroker over RDP. It failed at `ChatpadSetup.ps1:66` before service mutation because setup still required the active physical console session.
- TDD reproduction: the new RDP setup-identity regression failed against the old validator. After removing only the console/protocol/session-state requirements, `Test-ChatpadC4Setup.ps1` passes repository identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4, SCM argv 4/4, and broker setup/package regressions.
- Existing service still has the old helper because RepairBroker stopped at the identity gate. New package/readiness and canonical publication are required before another manual repair. Current live verdict remains PARTIAL.

## Next action

Rebuild/package/publish the setup identity fix and provide an exact elevated RepairBroker command. Preserve elevation, exact user SID, and valid token-session checks; do not relax runtime pipe authorization. Then have the user repair manually and rerun from normal-user RDP.

```powershell
<pending new package and readiness paths>
```

After RepairBroker reports PASS, have the user retry in their ordinary RDP PowerShell and return the full output. Continue only after `broker_peer_unauthorized` is gone and broker creation reaches `state=RUNNING`. Then qualify exact XUSB interface/XInput slot and rumble. The read-only watcher may be run concurrently from a second normal-user PowerShell if interface-arrival timing still needs observation.

## Safety

- Preserve exact installed-SID and local named-pipe checks; do not permit arbitrary users or remote pipe clients.
- Do not run ChatpadBridge elevated. The user will perform the explicitly requested RepairBroker step manually; do not mutate service, PnP, registry, device, driver, trust, or boot state automatically.
- Preserve the exact XUSB interface gate and HIDMaestro backend.
- Keep the result PARTIAL until local-console broker, XInput, physical rumble, reconnect, and crash-recovery evidence is collected.

## Inspect first

`docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md` entries, `tools/ChatpadVirtualXbox/BrokerPeerAuthorization.cs`, `tools/ChatpadVirtualXbox/WindowsClientIdentity.cs`, and `tools/ChatpadBridge` broker connection code.
