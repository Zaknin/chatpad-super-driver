# Next Task

## TASK 8L-C4L2 — Rebuild readiness for final HEAD, then retry normal-user runtime

- Branch: `feature/chatpad-usermode-runner`; source fix `160d6054682d0fcadaa68c1e2b79c0d07b67a27b`; previous pushed HEAD was `5e4d101a7c2b289c4ed8cc53294eca7c3c97bbf9`. This continuity update must be committed and pushed before building.
- Latest user run used `build-scope-conflict-id-b621b27`, passed WinUSB and Chatpad activation after reconnect, then stopped before virtual creation at `virtual_scope_conflict` for `SWD\HIDMAESTRO\HM_622C184E37F6891E`.
- Root defect identified in source: bit `0x2` was named `DN_PRESENT`, but Windows SDK `cfg.h` defines it as `DN_DRIVER_LOADED`. Source now queries device instance IDs using `CM_GETIDLIST_FILTER_PRESENT (0x100)` and exact case-insensitive matching. After the failed run, Get-PnpDevice/PnPUtil and direct CM queries reported that ID absent; it persists only as an Enum record with index zero.
- The user's elevated RepairBroker command failed before any SCM query/change because readiness commit `a93a1070add5a539f889a2fceb8bd69c6e34fccc` did not equal checkout HEAD `5e4d101a7c2b289c4ed8cc53294eca7c3c97bbf9`. The setup guard is correct; do not bypass it.
- Previous package directory `artifacts/task-8lc4l2/build-present-device-list-a93a107/package` is stale for setup on the newer HEAD, although its package hashes and previous publication are internally valid.

### Required continuation

1. Commit and push this continuity correction.
2. Build a fresh package into `artifacts/task-8lc4l2/build-readiness-current-head` so its readiness branch/commit equals the exact pushed HEAD; run focused tests and verify all package members.
3. Prepare and publish the fresh package atomically under the canonical C4L2 share.
4. Give the user the exact elevated RepairBroker command. After PASS, have them run that package in ordinary PowerShell and provide complete output.
5. If virtual creation succeeds, qualify XInput buttons/sticks/triggers, Chatpad, rumble callback, graceful Ctrl+C cleanup, reconnect, and crash recovery. If it fails, inspect the new precise failure read-only.

### Safety and acceptance

- Keep the index-zero guard fail-closed for IDs present in the explicit present-device list; stale registry Enum entries alone must not block. Do not weaken or bypass the guard.
- No device/registry deletion, service mutation by the agent, bridge elevation, driver binding, trust change, reboot, global HIDMaestro cleanup, or `legacy/` edits.
- Inspect first: `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, its new offline tests, recent C4L2 worklog entries, and the new build/package manifests.
