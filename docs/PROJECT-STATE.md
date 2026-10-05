# Project State

Updated 2026-10-05 after release-archive compatibility fix.

- Branch: `feature/chatpad-usermode-runner`; starting pushed HEAD is `6ca32dfb2c64c205893026b5ae23dc6d71bb9e3c`; runtime fix `92a3688` and release metadata fix `fbf4375` are pushed. The current archive-helper correction and continuity update are expected to become the new HEAD, then must be pushed before rebuilding.
- The fresh package at `artifacts/task-8lc4l2/build-c4l2-final/package` was built from `6ca32df` and has 214/214 member hashes/lengths matching its manifest. Offline release verification passed: managed 504/504, focused native CTest 3/3, setup/readiness/repository safety PASS. This package must be rebuilt after the current archive-helper source correction.
- Canonical Prepare at `20261005T145217Z` failed before publication because Windows PowerShell 5.1 had not loaded `System.IO.Compression.ZipArchive`. No SMB files were published. The deterministic archive helper now loads its assembly when needed; the regression passes archive/privacy 11/11 in Windows PowerShell 5.1 and PowerShell 7. The abandoned local staging tree remains ignored under `artifacts/`; use a fresh publication timestamp.
- Live normal-user runtime PASS: WinUSB and Chatpad activation/input; broker virtual Xbox; XInput slot and physical rumble; hot-unplug/replug and zero-rumble recovery; graceful cleanup. Client hard-crash cleanup PASS; the next launch recovered the pending zero-rumble state and shut down cleanly.
- Publisher/live-qualification regressions pass 9/9. Broker installation/repair and authorized normal-user runtime are qualified. Exact-SID/wrong-SID named-pipe policy cases are covered offline; no separate unauthorized-account live attempt was run. The broker service process itself was not crash-injected.
- Limits: a hard ChatpadBridge crash cannot stop physical rumble immediately; next-launch zero-rumble recovery passed. No service install/repair, driver binding, PnP, registry, trust, boot, or device mutation was performed by the agent; `legacy/` is untouched.

## Next

Commit and push the archive-helper/test/continuity update on `feature/chatpad-usermode-runner`. Then rebuild from that exact pushed HEAD, rerun `artifacts/task-8lc4l2/verify-offline-release.ps1`, and prepare/publish with a fresh UTC timestamp using the existing atomic publisher. Do not reuse package/build or timestamp `20261005T145217Z`; do not repeat live setup or mutate the service/device.
