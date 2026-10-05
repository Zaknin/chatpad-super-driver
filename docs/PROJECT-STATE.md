# Project State

Updated 2026-10-05 after live hot-unplug/reconnect qualification.

- Branch: `feature/chatpad-usermode-runner`; runner source fix is pushed as `92a368830bb6ecfb0a990ba68051583b506d5dd0`; current HEAD is this pushed continuity update.
- Corrected package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`. Build manifest binds runner bytes to source commit `92a3688`; all 214 package members match declared sizes and SHA-256. Runner SHA-256 is `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`. Regenerate readiness after the current docs-only closeout to bind it to current HEAD.
- User-reported normal-user live run passed WinUSB open, Chatpad activation, broker virtual Xbox creation, Chatpad key-data, keyboard input, and XInput rumble. During unplug, Win32 433 produced deferred zero-rumble cleanup; keys were released and the virtual controller neutralized and released. The runner entered reconnect, waited while the target was absent, reopened WinUSB after replug, sent startup zero-rumble recovery successfully, and recreated the virtual Xbox. The user confirmed controller and Chatpad input worked after reconnect.
- User stopped the recovered run with Ctrl+C. Final cleanup was `keysReleased=true virtualNeutral=true virtualReleased=true motorsStopped=true`; `clean_shutdown=true reconnect_count=1`.
- Live reconnect and graceful cleanup are PASS. Client process crash/disconnect cleanup is also PASS: the user force-stopped only package PID 27348, the target virtual Xbox was absent from `Get-PnpDevice -PresentOnly` after three seconds, and `ChatpadHidMaestroBroker` remained `Running / Automatic`.
- The remaining live check is a fresh client start after the crash: verify `unclean_previous_session=true`, startup zero-rumble recovery, and new virtual Xbox creation. Final C4L2 closeout and canonical artifact publication remain pending this check. No service, PnP, driver, registry, trust, device, or boot mutation was performed by the agent; `legacy/` remains untouched.

## Next

Restart the corrected package as a normal user and return the output through clean Ctrl+C shutdown:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe" run
```

The prior user-operated crash test stopped exact package PID 27348. The virtual Xbox was absent from the present PnP list three seconds later and the broker service remained `Running / Automatic`. This restart should report `unclean_previous_session=true`, successful zero-rumble recovery, and a fresh virtual Xbox. Physical motor stopping after a hard bridge crash is an accepted limitation. After this output, complete the remaining release verification/publication steps.
