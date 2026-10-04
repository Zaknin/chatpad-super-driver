# Project State

Updated 2026-10-04 after normal-user broker handshake diagnosis.

- Branch: `feature/chatpad-usermode-runner`; peer-fault isolation fix `0f2540ee2ac89d0ad90875d36fb3883021eb5ff2` and package handoff `98e556e8a7013de7c4fcf3821eee02854f6862fc` are pushed.
- Live service: user manually repaired the installed broker from the peer-fault isolation package; setup reported PASS and service RUNNING as LocalSystem. Physical binding was unchanged.
- Latest live runtime: physical WinUSB opened and Chatpad activation stages 0–5 passed. Broker returned `broker_peer_identity_failed: Unable to impersonate using a named pipe until data has been read from that pipe.` The service stayed available; this is the concrete handshake-order defect.
- Fix in progress: broker now reads one bounded initial protocol frame (5-second deadline) before calling `RunAsClient`, then authorizes the SID/session before dispatching the buffered frame to the session. Regression coverage verifies read-before-impersonate ordering. The normal client sends `ping` first.
- Focused validation: managed self-test reported 149 passed, 1 environment-limited pipe-squatter failure because the live broker owns the fixed pipe. The added ordering regression passed. Earlier native `broker-client|runner-lifecycle` was 2/2; native client code did not change in this fix. Fresh package build and final hash verification are pending.
- Remaining acceptance: user-run elevated `RepairBroker` from the next package, then normal-user virtual XInput, buttons/sticks/triggers, Chatpad typing, rumble callback, graceful cleanup, reconnect, crash recovery, and broker survival after malformed/disconnected client input. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: this task performed no service lifecycle/configuration operation, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup. `legacy/` is untouched.
