# TASK 8L-C4L2 — Publish and retry clean-start recovery correction

## Current state

- Branch: `feature/chatpad-usermode-runner`; source and package build commit: `2258de10c65052a12efff8acfa30f2773dc546ad`.
- The user-tested prior release polled IF0 before activation but still timed out the startup zero-rumble transfer (Win32 1460) with `unclean_previous_session=false`, then reconnected eight times. The polling-gap hypothesis was disproven.
- The source now skips startup zero-rumble on a clean prior exit. For an unclean prior session it tries recovery once; on failure it stops and preserves the marker rather than retrying. The user has not yet run these changed bytes.
- Focused offline verification passed: managed 504/504, native CTest 3/3, setup checks repository identity 5, package identity 8, baseline 5, PnP 4, readiness/privacy 9/9, publication receipt 5/5, safety PASS. Package has 214 exact manifest-matched members.
- Prepared timestamp: `20261005T040900Z`; archive SHA-256: `C03531153A5AF9E7407970DBBBA1AC88B9155C731294A1B42541BFF3C343CD07`. Publish and independent remote readback remain.
- User previously reported RepairBroker PASS. The changed executable is the bridge only, so do not request another elevated repair.

## Next steps

1. Commit/push the continuity-only release-identity update to `feature/chatpad-usermode-runner`.
2. Publish the prepared `20261005T040900Z` release with `tools/Publish-ChatpadC4L2.ps1 -Mode Publish`; verify all remote sidecars, receipt hash, release identity, and absence of `.part` files.
3. Give the user the exact ordinary PowerShell command for the published package and request the complete output after Ctrl+C.
4. Verify whether clean startup skips recovery, virtual controller creation succeeds, and the runner remains active. Unclean-session single-attempt recovery remains a separate qualification.

## Safety and acceptance

- Do not change service lifecycle, driver binding, PnP/registry, trust, reboot, run an elevated bridge, or perform global HIDMaestro cleanup.
- Do not automatically retry a failed unclean-session rumble recovery; preserve the marker.
- Do not claim live XInput or physical rumble PASS until separately observed.
- Inspect first: `tools/ChatpadWinUsbPoc/Runner.cpp`, `RunnerLifecycle.{h,cpp}`, lifecycle tests, and the prepared release record.
