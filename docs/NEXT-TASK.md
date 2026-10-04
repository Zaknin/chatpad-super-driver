# Next Task

Recommended objective: rerun TASK 8L-C4L1 from the user's elevated PowerShell using the final hash-verified package.

Current state: package/readiness identity passed on the user's last run. Install next failed because `Save-ChatpadC3Baseline` accepted only `artifacts`, conflicting with C4's intentional durable path under `ProgramData\ChatpadBridge`. The guard now accepts only that exact persistent private root alongside artifacts; focused tests pass. A package is regenerated after the final continuity commit. Previous run copied runtime files and secured the ProgramData parent, but stopped before baseline creation or PnP binding.

Required branch and starting point: `feature/chatpad-usermode-runner`, pushed HEAD recorded in `artifacts/task-8lc4/build-task-8lc4l1-final/build-manifest.json`. Verify branch, commit, clean status and manifest/readiness hash agreement first.

First inspect: `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`; then `artifacts/task-8lc4/build-*/build-manifest.json` and `readiness-input.json`.

Preconditions: package manifest and readiness identify current branch/HEAD and the same package root; all listed SHA-256 values independently match. User runs exactly `.\tools\ChatpadSetup.ps1 -Mode Install` from repository root in elevated PowerShell and returns complete output.

Safety: do not run Install from this non-elevated execution context. Do not bind, install/remove drivers, change security/trust, replug/reboot, or clean the partially copied Program Files directory. Stop on any identity/hash/preflight error and reconcile before another attempt. Do not modify `legacy/`.

Acceptance: confirm the private recovery baseline is created and setup proceeds through exact PnP postconditions before proceeding to the separately specified live lifecycle criteria. Report unperformed behavior as UNTESTED; do not run the comprehensive suite during this focused setup follow-up.

Inspect first: `tools/ChatpadSetup.ps1`, `tools/ChatpadC4Package.psm1`, `tools/New-ChatpadC4Readiness.ps1`, `tools/Test-ChatpadC4Setup.ps1`, and exact current package/readiness manifests.
