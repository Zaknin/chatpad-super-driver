# Project State

Updated 2026-10-05 after the startup rumble recovery correction.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD for this correction: `344644548bec4f8ba4361b9dbe6ee0bc42c1900a`.
- Live status: user ran release `20261005T035300Z`. Log confirmed controller input polling started, yet initial zero-rumble write timed out and the runner retried until Ctrl+C (`reconnect_count=8`). It also reported `unclean_previous_session=false`. Therefore the previous source-order/polling diagnosis was disproven as the cause of this write failure.
- Current diagnosis: the runner sent its crash-recovery zero-rumble command on every launch. The approved design only requires that command on the next launch after an unclean process exit. Clean shutdown already attempts and verifies motor neutralization.
- Correction: clean starts skip that redundant write. When the prior-session marker is present, the runner still performs strict zero-rumble recovery; if that one attempt fails, it stops and retains the marker instead of repeating the write through reconnects. Continuous IF0/81 polling remains in place for startup and state streaming.
- Focused checks so far: regression tests first failed to compile because the recovery decision helper was absent, as expected. After implementation, `ChatpadRunnerLifecycleTests` passed 17/17 and focused native CTest `controller-input-pump`, `broker-client`, `runner-lifecycle` passed 3/3. Fresh package, full focused package checks, publication, commit, and push remain pending.
- Service remains reported Running after the user's successful RepairBroker operation; this change affects only the bridge executable. No new elevated setup step is expected.
- Safety: no live service, PnP, binding, registry, trust, device, reboot, elevated bridge, or global HIDMaestro cleanup by the agent; `legacy/` untouched.

## Next

Finish focused offline checks, build and publish a fresh package from the exact pushed HEAD, then ask the user to launch its `ChatpadBridge.exe` as a normal user. Verify a clean start skips startup rumble recovery, creates the virtual controller, and remains running. Separately verify that an unclean-session marker still triggers one strict recovery attempt and does not enter an automatic retry loop if that write fails.
