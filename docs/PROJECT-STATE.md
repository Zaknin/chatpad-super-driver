# Project State

Updated 2026-10-05 after live hot-unplug/reconnect qualification.

- Branch: `feature/chatpad-usermode-runner`; runner source fix is pushed as `92a368830bb6ecfb0a990ba68051583b506d5dd0`; current HEAD is this pushed continuity update.
- Corrected package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`. Build manifest binds runner bytes to source commit `92a3688`; all 214 package members match declared sizes and SHA-256. Runner SHA-256 is `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`. Regenerate readiness after the current docs-only closeout to bind it to current HEAD.
- User-reported normal-user live run passed WinUSB open, Chatpad activation, broker virtual Xbox creation, Chatpad key-data, keyboard input, and XInput rumble. During unplug, Win32 433 produced deferred zero-rumble cleanup; keys were released and the virtual controller neutralized and released. The runner entered reconnect, waited while the target was absent, reopened WinUSB after replug, sent startup zero-rumble recovery successfully, and recreated the virtual Xbox. The user confirmed controller and Chatpad input worked after reconnect.
- User stopped the recovered run with Ctrl+C. Final cleanup was `keysReleased=true virtualNeutral=true virtualReleased=true motorsStopped=true`; `clean_shutdown=true reconnect_count=1`.
- Live reconnect and graceful cleanup are PASS. Client process crash/disconnect cleanup remains unqualified. The service install/repair was user-reported successful and the service payload has not changed in this task.
- Final C4L2 closeout and canonical artifact publication remain pending client-crash cleanup qualification. No service, PnP, driver, registry, trust, device, or boot mutation was performed by the agent; `legacy/` remains untouched.

## Next

Run a normal-user client-crash test with the corrected package. From a second ordinary PowerShell, force-stop only the `ChatpadBridge.exe` process whose executable path exactly matches this package. Confirm the broker removes the virtual XInput PnP node and the broker service remains Running. Then start the bridge again and verify the preserved unclean-session marker triggers zero-rumble recovery and a fresh virtual Xbox. Physical motor stopping after a hard bridge crash is an accepted limitation. Record the full evidence, then complete the remaining release verification/publication steps.
