# Next Task

## TASK 8L-C4L2 — Install corrected broker package and retry normal-user runtime

- Branch: `feature/chatpad-usermode-runner`; source fix `160d6054682d0fcadaa68c1e2b79c0d07b67a27b`; package build `a93a1070add5a539f889a2fceb8bd69c6e34fccc` is pushed and clean.
- Latest user run used `build-scope-conflict-id-b621b27`, passed WinUSB and Chatpad activation after reconnect, then stopped before virtual creation at `virtual_scope_conflict` for `SWD\HIDMAESTRO\HM_622C184E37F6891E`.
- Root defect identified in source: bit `0x2` was named `DN_PRESENT`, but Windows SDK `cfg.h` defines it as `DN_DRIVER_LOADED`. Source now queries device instance IDs using `CM_GETIDLIST_FILTER_PRESENT (0x100)` and exact case-insensitive matching. After the failed run, Get-PnpDevice/PnPUtil and direct CM queries reported that ID absent; it persists only as an Enum record with index zero.
- Current package: `artifacts/task-8lc4l2/build-present-device-list-a93a107/package`, with 214/214 exact manifest hashes. Runner SHA-256 `2D367359F7840245AD824F0FE7E09D215CF48C668B3351C56DCF2F3F1D1F655C`; broker SHA-256 `2EF94608449028140AD479BC3B473B28819AFD6BE068CA6E74004ED40D88B003`.
- Verification: managed 162/162; focused native CTest 2/2; C4 setup checks PASS; readiness privacy 9/9. Canonical release `20261004T200803Z` was atomically published and remote sidecars independently verified 6/6. Archive SHA-256 `760C1A11047A829F5D05308E724438B29901AC2FD4ABFA4FA295B2D5F8C8DDB9`.

### Required continuation

1. Ask the user to repair the broker in elevated PowerShell using `artifacts/task-8lc4l2/build-present-device-list-a93a107/package` and the matching `artifacts/task-8lc4l2/readiness-input.json`.
2. Have the user launch the same package in ordinary PowerShell and provide the complete run output.
3. If virtual creation succeeds, qualify XInput buttons/sticks/triggers, Chatpad, rumble callback to the physical controller, graceful Ctrl+C cleanup, reconnect, and crash recovery. If it fails, inspect the new precise failure read-only.

### Safety and acceptance

- Keep the index-zero guard fail-closed for IDs present in the explicit present-device list; stale registry Enum entries alone must not block. Do not weaken or bypass the guard.
- No device/registry deletion, service mutation by the agent, bridge elevation, driver binding, trust change, reboot, global HIDMaestro cleanup, or `legacy/` edits.
- Inspect first: `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, its new offline tests, recent C4L2 worklog entries, and the new build/package manifests.
