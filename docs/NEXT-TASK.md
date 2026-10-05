# TASK 8L-C4L2 — Qualify clean-start rumble recovery correction

## Current state

- Branch: `feature/chatpad-usermode-runner`; source/package build commit `2258de10c65052a12efff8acfa30f2773dc546ad`; published release identity commit `97095be21c420f55a26a7319b8a42323fd6fb6d4`.
- The prior user run showed controller polling before activation but still timed out the startup zero-rumble write (Win32 1460) while `unclean_previous_session=false`, then reconnected eight times. Polling was not the cause.
- The source skips startup zero-rumble after clean previous exit; an unclean previous session still gets one recovery attempt, with no automatic retry on failure. The new bytes await user live test.
- Offline qualification passed: managed 504/504, native CTest 3/3, setup checks (identity 5, package 8, baseline 5, PnP 4), readiness/privacy 9/9, publication receipts 5/5, repository safety PASS; package 214/214 exact members.
- Published canonical release: `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T040900Z`; archive SHA-256 `C03531153A5AF9E7407970DBBBA1AC88B9155C731294A1B42541BFF3C343CD07`. Independent remote readback passed all six sidecars, receipt identity/hash, and no `.part` files.
- User previously reported broker RepairBroker PASS. No elevated repair is needed for this bridge-only change.

## Next steps

1. Ask the user to run `C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-recovery-2258de1\package\ChatpadBridge.exe` from ordinary PowerShell, then return the complete output after Ctrl+C.
2. Confirm clean startup skips the recovery write and whether broker create/Chatpad runtime succeeds. Do not claim XInput or physical rumble PASS unless the user demonstrates it.
3. Later, separately qualify unclean-session recovery and the single-attempt failure behavior.

## Safety

- Do not change service lifecycle, driver binding, PnP/registry, trust, reboot, run an elevated bridge, or perform global HIDMaestro cleanup.
- Preserve the unclean-session marker when its one recovery attempt fails; do not retry automatically.
- Inspect first: `tools/ChatpadWinUsbPoc/Runner.cpp`, lifecycle tests, published readiness identity, and the user's new runtime output.
