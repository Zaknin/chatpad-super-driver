# Project State

Updated 2026-10-04 after local named-pipe classification diagnosis.

- Branch: `feature/chatpad-usermode-runner`; latest pushed implementation is `f5d5885c73ec10d3d33ac30ad68eaf8ceb543290` with docs handoff `3c75f42fa9f90086010eba632d9507bdb933b5ef`.
- Live service: user manually repaired the read-before-impersonate package; the service reported RUNNING as LocalSystem. The next normal-user run opened WinUSB and passed Chatpad stages 0–5, then failed closed with `broker_peer_unauthorized`.
- Root cause: `GetNamedPipeClientComputerNameW` returns `ERROR_PIPE_LOCAL` (229) for local pipes. `WindowsClientIdentity` incorrectly treated every false return as remote. Read-only host checks also confirmed authorized user SID and active local console session match. The broker must accept 229 as the local result, compare the name on API success, and fail closed on other errors.
- Fix in progress: `WindowsClientIdentity.ResolveLocality` handles exactly those three cases; regression tests cover local error 229, matching name, mismatched name, and unrelated API error. Read-before-impersonate and service fault isolation remain intact.
- Focused verification: managed self-test reported 153 passed and one environment-limited pipe-squatter failure because the live service owns the fixed pipe. New locality tests passed. Fresh package/build/readiness and complete member-hash verification are pending.
- Remaining acceptance: manual elevated `RepairBroker` from the next package, followed by normal-user create/XInput, controller and Chatpad input, rumble, graceful cleanup, reconnect, and crash recovery. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: no service lifecycle/configuration operation, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed for this fix. `legacy/` is untouched.
