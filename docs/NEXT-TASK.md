# TASK 8L-C5 — exact package repair and live qualification

- Required branch: `feature/chatpad-usermode-runner`.
- Starting point: the C5 implementation/continuity commit created from `64b867ef640c5ae57dce2bf8f9772a562556a788`; resolve the exact current HEAD with `git rev-parse HEAD`, then push that branch and build from the resulting clean HEAD.
- Preconditions: native, setup, and broker offline tests have passed for the implementation; rerun the complete build after commit and verify manifest branch/commit plus every package SHA-256. The current desktop shell is non-elevated.
- First live step: provide the user one elevated `ChatpadSetup.ps1 -Mode RepairBroker` command using the exact committed package and readiness file. Wait for its full output. Then perform read-only service/PnP/process checks and one strict probe; start no runner unless a valid 20-byte `00 14` controller report is observed.
- Normal-user qualification: enable HKCU autostart from the authorized user, launch `ChatpadBridge.exe start`, verify no console/UAC and exactly one launcher/runner, test controls/Chatpad/XInput/rumble, and verify graceful `stop` cleanup. Confirm launch with the controller absent and reconnection before S3 qualification.
- S3 acceptance: use the existing elevated trace helper for one cycle at a time. After each wake, verify changing valid controller reports, Chatpad typing, XInput, rumble, zero-rumble, and virtual cleanup. Do not start a later cycle until the previous recovery passed. C5 requires at least three successful cycles; retain PARTIAL if any cycle fails.
- Safety: exact Xbox target only; preserve WinUSB binding and USB power settings; no `RemoveAllVirtualControllers`; do not manually delete `session.active.json`; no edits under `legacy/`.
- Inspect first: `artifacts/task-8lc5/<exact-build>/build-manifest.json`, its `package/ChatpadSetup.ps1`, `tools/ChatpadWinUsbPoc/Runner.cpp`, `tools/ChatpadVirtualXbox/WindowsServiceHost.cs`, and current host/service status.
