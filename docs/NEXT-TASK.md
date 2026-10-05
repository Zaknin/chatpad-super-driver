# TASK 8L-C4L2 — Final offline release verification and publication

## Current state

- Branch `feature/chatpad-usermode-runner`; publisher correction commit `fbf4375` is local, and this continuity update is expected to be the final source/package HEAD. Starting commit was `c8beb69fe88eced6a33b306b64e9c0483161974d`; publisher regressions pass 9/9.
- Normal-user end-to-end, XInput/physical rumble, Chatpad input, unplug/replug recovery, graceful cleanup, client-crash virtual cleanup, and next-launch recovery have been qualified from user-provided logs. See the latest WORKLOG entries and `artifacts/task-8lc4l2/live-qualification.json`.
- The current package predates publisher/continuity changes. Rebuild from the exact committed closeout HEAD before release Prepare; do not reuse the old package as the final artifact.

## Objective and acceptance

Build the final exact-HEAD package, regenerate readiness, run `artifacts/task-8lc4l2/verify-offline-release.ps1`, prepare a deterministic release archive, update continuity docs with the verification identity, then publish via `tools/Publish-ChatpadC4L2.ps1 -Mode Publish`.

Acceptance: clean/pushed branch identity; package/readiness/manifest hashes agree; offline verification summary passes (managed suite 3 runs, focused native CTest 3/3, setup/readiness/repository safety PASS); live record validates and is included in the archive; archive repeat hash is deterministic; atomic publisher source/part/final hash readbacks and SHA-256 completion sidecars pass under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\`.

## Safety

- No service install/repair, driver binding, PnP, registry, trust, boot, device mutation, or elevated bridge run.
- Keep generated builds, sanitized live record, verification output, and staging under ignored `artifacts/`.
- `legacy/` is immutable. Push only `feature/chatpad-usermode-runner`.

## Inspect and run first

Read `AGENTS.md`, project state, decisions, this file, and recent worklog; verify branch/status/HEAD and the live qualification input. Then build to a fresh ignored directory (for example `artifacts/task-8lc4l2/build-c4l2-final`), verify, prepare with a fresh UTC timestamp, make only allowed continuity-doc updates after Prepare, commit/push them, and Publish using the same timestamp.
