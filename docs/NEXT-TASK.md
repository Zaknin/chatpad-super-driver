# Next Task

## TASK 8L-C4L2 — Review the HIDMaestro broker specification

- Branch: `feature/chatpad-usermode-runner`.
- Starting HEAD for the design work: `52f5e4da57d5e031cc63ef4325d5f46803025412`. This spec checkpoint will be committed separately; implementation must start from the then-current branch HEAD after the user approves the written spec and reviews the implementation plan.
- Approved design: `docs/superpowers/specs/2026-10-04-hidmaestro-broker-design.md`.

The user approved the service-in-`ChatpadVirtualXbox.exe` approach conversationally. The immediate continuation point is review of the written spec. After written approval, create and self-review a task-level implementation plan, then ask the user to approve the plan and choose its execution method before touching implementation code.

Implementation acceptance remains: offline protocol/authentication/ownership/lifecycle tests pass; exact package/readiness identities and hashes pass; final package/evidence is atomically published under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\` with SHA-256 sidecars. Only then does the user perform the separate elevated service install/repair step. Follow with normal-user hardware qualification for WinUSB → bridge → broker → XInput, Chatpad, rumble callback, reconnect, graceful cleanup, client crash recovery, and service crash/restart. Do not mark live acceptance from offline results.

Safety restrictions: do not install, start, repair, stop, or uninstall the service before the user's explicit live setup step; do not change WinUSB binding, install/load/sign drivers, mutate PnP/registry/device state, change security/trust, or reboot; do not elevate `ChatpadBridge.exe`; do not call HIDMaestro's global `RemoveAllVirtualControllers`; do not modify `legacy/`; keep generated outputs under ignored `artifacts/`.

Inspect first: this spec, the pinned SDK manifest `tools/ChatpadVirtualXbox/upstream.json`, `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`, `tools/ChatpadWinUsbPoc/VirtualHelper.cpp`, `tools/ChatpadWinUsbPoc/Runner.cpp`, `tools/ChatpadSetup.ps1`, and the C4 package/build/publisher scripts.
