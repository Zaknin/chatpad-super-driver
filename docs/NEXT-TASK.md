# Next Task

Recommended objective: complete the reboot-aware WinUSB setup and then continue live runner qualification.

Current state: user's last Install passed package checks, saved the private baseline, then selected WinUSB with `NeedReboot=true`. Old code treated that as failure and immediately requested Microsoft restoration, also with `NeedReboot=true`. Read-only Status now shows Microsoft xusb22, problem0, no filters. Reboot-aware code now reports `PENDING_REBOOT`, persists the baseline/install record and avoids rollback when Bind succeeds with a restart requirement. The final package must match pushed HEAD.

Required branch and starting point: `feature/chatpad-usermode-runner`, pushed HEAD recorded in `artifacts/task-8lc4/build-task-8lc4l1-final-3673014/build-manifest.json`. Verify branch, commit, clean status and manifest/readiness hash agreement first.

First inspect: `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`; then `artifacts/task-8lc4/build-task-8lc4l1-final-3673014/build-manifest.json` and `artifacts/task-8lc4/readiness-input.json`.

Preconditions: user manually restarts Windows to settle the previous Microsoft restore request, then runs `.\tools\ChatpadSetup.ps1 -Mode Status` in elevated PowerShell and confirms xusb22/problem0/no filters. Verify final package/readiness identity. User then runs `.\tools\ChatpadSetup.ps1 -Mode Install` elevated and returns complete output. If it reports `PENDING_REBOOT`, user restarts manually and returns a fresh Status result.

Safety: do not run Install or reboot from this non-elevated execution context. Do not clean the partially copied Program Files directory or secured ProgramData baseline. Do not change security/trust or modify `legacy/`. Stop on any identity/hash/preflight error and reconcile before another attempt.

Acceptance: confirm the recovery baseline is recorded and setup either verifies WinUSB immediately or cleanly reports pending restart. After any required manual restart, verify WinUSB/problem0/no filters with Status before runner testing. Report unperformed behavior as UNTESTED; do not run the comprehensive suite during this focused setup follow-up.

Inspect first: `tools/ChatpadSetup.ps1`, `tools/ChatpadC4Package.psm1`, `tools/New-ChatpadC4Readiness.ps1`, `tools/Test-ChatpadC4Setup.ps1`, and exact current package/readiness manifests.
