# Next Task

## TASK 8L-C4L2 — Package corrected PnP presence guard and retry normal-user runtime

- Branch: `feature/chatpad-usermode-runner`; starting commit `160d6054682d0fcadaa68c1e2b79c0d07b67a27b` contains the explicit-present-list correction. Push state must be checked before package preparation.
- Latest user run used `build-scope-conflict-id-b621b27`, passed WinUSB and Chatpad activation after reconnect, then stopped before virtual creation at `virtual_scope_conflict` for `SWD\HIDMAESTRO\HM_622C184E37F6891E`.
- Root defect identified in source: bit `0x2` was named `DN_PRESENT`, but Windows SDK `cfg.h` defines it as `DN_DRIVER_LOADED`. Source now queries device instance IDs using `CM_GETIDLIST_FILTER_PRESENT (0x100)` and exact case-insensitive matching. After the failed run, Get-PnpDevice/PnPUtil and direct CM queries reported that ID absent; it persists only as an Enum record with index zero.
- Focused verification so far: pinned .NET 10 helper build succeeds with 0 warnings/errors; managed offline self-test 162/162; focused native CTest 2/2. The correction is committed but has not yet been packaged, published, or installed.
- Existing canonical release `20261004T194810Z` and its archive hash refer to the previous package only.

### Required continuation

1. Verify that exact commit is pushed and the worktree is clean.
2. Build a fresh package from that exact HEAD, run managed and focused setup/package/hash verification, and confirm all package members against the generated manifest.
3. Prepare and atomically publish a new PARTIAL C4L2 release with SHA-256 sidecars under the canonical task share.
4. Give the user the exact elevated `RepairBroker` command for that package. Do not perform service repair from the agent.
5. After the user's manual repair, have them launch the package in ordinary PowerShell and provide the full output. Only if virtual creation succeeds, continue XInput, Chatpad, rumble, graceful cleanup, reconnect, and crash-recovery qualification.

### Safety and acceptance

- Keep the index-zero guard fail-closed for IDs present in the explicit present-device list; stale registry Enum entries alone must not block.
- No device/registry deletion, service mutation by the agent, bridge elevation, driver binding, trust change, reboot, global HIDMaestro cleanup, or `legacy/` edits.
- Inspect first: `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, its new offline tests, recent C4L2 worklog entries, and the new build/package manifests.
