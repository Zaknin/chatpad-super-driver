# TASK 8L-C4L2 — Final exact-HEAD build and canonical publication

## Current state

- Branch `feature/chatpad-usermode-runner`, starting pushed HEAD `6ca32dfb2c64c205893026b5ae23dc6d71bb9e3c`. The archive-helper correction and continuity update in this commit are expected to be the new source HEAD; push it before rebuilding.
- Prior package and offline verification from `6ca32df` passed (214 members; managed 504/504; native 3/3; setup/readiness/safety PASS), but Prepare exposed an archive assembly-loading failure under Windows PowerShell 5.1. The fix now passes archive/privacy 11/11 in both Windows PowerShell 5.1 and PowerShell 7.
- The failed Prepare timestamp `20261005T145217Z` created only ignored local staging; nothing was written to the SMB destination. Use a new UTC timestamp and rebuild from the next clean pushed HEAD.
- Live runtime, XInput/physical rumble, Chatpad, reconnect, graceful cleanup, client-crash cleanup, and following-launch recovery are qualified; see the latest WORKLOG entry and `artifacts/task-8lc4l2/live-qualification.json`.

## Objective and acceptance

Commit/push the archive-helper correction, regression, and continuity docs. Build a fresh package from that exact HEAD; run `artifacts/task-8lc4l2/verify-offline-release.ps1`; prepare the deterministic archive with a fresh timestamp; record verification/hash/path in continuity docs; commit/push only those allowed docs; publish with the same timestamp.

Require clean and pushed repository identity; 214-member package hash/length agreement; managed 504/504, focused native CTest 3/3, setup/readiness/repository safety PASS; deterministic repeated archive hash; live evidence included; and atomic source/part/final SHA-256 readbacks plus sidecars at `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\`.

## Safety

- No service install/repair, driver binding, PnP, registry, trust, boot, device mutation, or elevated bridge execution.
- Keep generated artifacts and logs under ignored `artifacts/`; `legacy/` is immutable.
- Push only `feature/chatpad-usermode-runner`.

## Inspect first

Read `AGENTS.md`, project state, decisions, this file, and recent worklog. Verify the staged diff and branch; then commit/push the fix, rebuild into a fresh ignored directory, verify, Prepare with a fresh UTC timestamp, and Publish only after the continuity commit is pushed.
