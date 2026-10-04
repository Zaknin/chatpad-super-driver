# Next Task

## TASK 8L-C4L2 — Review the HIDMaestro broker implementation plan

- Branch: `feature/chatpad-usermode-runner`.
- Starting HEAD for this planning turn: `0107be20255e2bd97cccefb11ffa63c84a4a6cbd`.
- Written spec approved by user: `docs/superpowers/specs/2026-10-04-hidmaestro-broker-design.md`.
- Plan awaiting user approval: `docs/superpowers/plans/2026-10-04-hidmaestro-broker.md`.

The plan applies the three approved clarifications: exact installed user SID plus active local console (never arbitrary/RDP) authorization; one-way sequenced state streaming with bounded latest-value queues and no per-frame response; and absolute protected-install-root executable/runtime/config paths with no IPC paths. If approved, execute natively in this checkout using `superpowers:executing-plans`; the current collaboration policy does not authorize subagent delegation.

Implementation acceptance remains: offline protocol/authentication/ownership/lifecycle tests pass; exact package/readiness identities and hashes pass; final package/evidence is atomically published under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\` with SHA-256 sidecars. Only then does the user perform the separate elevated service install/repair step. Follow with normal-user hardware qualification for WinUSB → bridge → broker → XInput, Chatpad, rumble callback, reconnect, graceful cleanup, client crash recovery, and service crash/restart. Do not mark live acceptance from offline results.

Safety restrictions: do not install, start, repair, stop, or uninstall the service before the user's explicit live setup step; do not change WinUSB binding, install/load/sign drivers, mutate PnP/registry/device state, change security/trust, or reboot; do not elevate `ChatpadBridge.exe`; do not call HIDMaestro's global `RemoveAllVirtualControllers`; do not modify `legacy/`; keep generated outputs under ignored `artifacts/`.

Inspect first: the approved spec, this plan, pinned SDK manifest `tools/ChatpadVirtualXbox/upstream.json`, `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`, `tools/ChatpadWinUsbPoc/VirtualHelper.cpp`, `tools/ChatpadWinUsbPoc/Runner.cpp`, `tools/ChatpadSetup.ps1`, and C4 package/build/publisher scripts.
