# Project State

Updated 2026-10-10 during TASK 8L-C5 wired-controller status-packet handling.

- Branch: `feature/chatpad-usermode-runner`. Verified base HEAD before this change: `abb4e06348d04f2d77b2b9b568d9418042af9bb6`, clean and pushed. The previous state documents incorrectly named `cd6a21c` as current HEAD; `abb4e063` had already committed and pushed the probe diagnostics.
- Expected HEAD after this closeout: the TASK 8L-C5 status-packet implementation commit containing this state and worklog update; resolve its exact hash with `git rev-parse HEAD`.
- C4L2 remains complete and published. Earlier C4L2 package identity, hashes, and live service qualification remain recorded in `docs/WORKLOG.md`.
- Strict controller-state parsing remains unchanged: exactly 20 bytes, header `00 14`, plus the existing reserved-button validation. Readiness and the runtime input pump now classify only the four exact known wired status packets (`01 03 02`, `02 03 00`, `03 03 03`, `08 03 00`) as non-controller status. Readiness uses one absolute five-second deadline; all other malformed reports are rejected.
- Focused Release verification: `ChatpadBridgeTests` 544/544, controller-input-pump 10/10, focused CTest 2/2. The full C5 runner and diagnostic executable built successfully under ignored `artifacts/task-8lc5/status-packet-fix/`.
- Live pre-sleep qualification on a non-admin token: read-only probe skipped `08 03 00` then accepted a valid 20-byte `00 14` report. User confirmed controller buttons/stick and Chatpad input; a guarded XInput slot-0 rumble pulse was physically felt.
- During the attempted sleep/reconnect qualification, the runner later lost WinUSB with `1460`, cleaned keyboard/virtual state, deferred zero-rumble recovery, and made 15 reopen/activation attempts before being stopped cleanly. The post-run read-only probe timed out after 5 seconds with nine read timeouts and last Win32 `1460`; no controller report arrived. A rumble-recovery marker remains. This does not establish the missing UMDF verifier violation as the cause.
- C5 remains incomplete. Awaiting a physical USB power-cycle and another read-only probe before any additional runtime. No physical binding, PnP, service, registry, trust, boot, or power-setting changes were made in this task; no `RemoveAllVirtualControllers`; `legacy/` untouched.
