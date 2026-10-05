# Project State

Updated 2026-10-05 after exact-HEAD package verification and deterministic Prepare.

- Branch: `feature/chatpad-usermode-runner`; pushed source/package commit `18e6572073aee0ac4231e89d9c509d6a420aa37b`. The package at `artifacts/task-8lc4l2/build-c4l2-final-v2/package` and readiness record both bind to this commit. It contains 214/214 members whose paths, lengths, and SHA-256 match `build-manifest.json`.
- Final offline verification PASS: managed tests 504/504 over three runs; focused native CTest 3/3; setup tests PASS (repository identity 5/5, package identity 8/8, baseline 5/5, PnP 4/4); readiness/archive tests 11/11; repository safety PASS. No live API was called by offline managed tests.
- Deterministic archive Prepare passed twice at timestamp `20261005T145921Z`. Canonical destination: `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261005T145921Z`. Prepared archive SHA-256: `ABA2E12546BD394C967E6D7C8C26339306FA927EA71D617725C8E2F223981A50`; local hash readback matches. Archive holds 217 files: 214 package members plus inventory, offline evidence, and live qualification record. SMB publication is pending.
- Live normal-user runtime, authorized-user broker connection, XInput/physical rumble, Chatpad input, hot-unplug/reconnect, graceful cleanup, client-crash virtual cleanup, and next-launch recovery PASS based on user-provided logs. The separate wrong-SID authorization cases passed offline; no unauthorized-account live attempt was made.
- Limits: a hard ChatpadBridge crash cannot immediately stop physical rumble; next-launch zero-rumble recovery passed. Broker service process crash recovery was not injected. No service install/repair, driver binding, PnP, registry, trust, boot, or device mutation was performed by the agent; `legacy/` is untouched.

## Next

Commit and push only the continuity-document update. Then run `tools/Publish-ChatpadC4L2.ps1 -Mode Publish` with timestamp `20261005T145921Z` and build directory `artifacts/task-8lc4l2/build-c4l2-final-v2`. Verify all final source/part/destination/sidecar receipts, then append the publication result, archive SHA-256, and canonical path to the final worklog/status commit.
