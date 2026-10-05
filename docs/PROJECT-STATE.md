# Project State

Updated 2026-10-05 after normal-user crash-recovery qualification.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD for this closeout is `c8beb69fe88eced6a33b306b64e9c0483161974d`, pushed to origin. Runtime fix commit: `92a368830bb6ecfb0a990ba68051583b506d5dd0`.
- The corrected runtime package at `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package` contains 214 members matching its build manifest; runner SHA-256 is `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`. It is bound to source commit `92a3688`; final release packaging must be rebuilt from the closeout HEAD.
- Live normal-user runtime PASS: physical WinUSB and Chatpad activation/input; broker virtual Xbox; XInput slot and physical rumble; hot-unplug/replug, deferred zero-rumble and next-open recovery; virtual/keyboard/motor cleanup on graceful stop.
- Client crash cleanup PASS: the user force-stopped the exact package process; the virtual controller disappeared within three seconds and the service stayed Running/Automatic. The following normal-user launch logged `unclean_previous_session=true`, recovered zero rumble, recreated the virtual Xbox, accepted Chatpad input, and ended with all cleanup flags true and `clean_shutdown=true`.
- The release publisher had stale hard-coded `UNTESTED`/pending statuses. Its source now validates and archives a separate sanitized live qualification record. Focused publisher regressions pass 9/9 (five atomic-receipt checks and four live-manifest/result-summary checks). Final package regeneration, offline release verification, and canonical publication are pending.
- Scope limits: a hard ChatpadBridge crash cannot immediately stop physical rumble; next-launch zero-rumble recovery passed. A crash of the Windows broker service itself was not injected. No service install/repair, driver binding, PnP, registry, trust, boot, or device mutation was performed by the agent; `legacy/` is untouched.

## Next

Commit/push the publisher and continuity changes on this branch, build a fresh package from that exact HEAD, run `artifacts/task-8lc4l2/verify-offline-release.ps1`, then prepare and publish the canonical TASK-8L-C4L2 archive through `tools/Publish-ChatpadC4L2.ps1` and the existing atomic publisher. Keep the normal-user live qualification record and build outputs under ignored `artifacts/`; do not repeat live setup or mutate the service/device.
