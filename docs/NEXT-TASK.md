# Next Task

Recommended objective: rerun the corrected TASK 8L-C4L1 setup from the user's elevated PowerShell and reconcile the result.

Current state: the false readiness classification was fixed and focused tests pass. Regenerate the package/readiness from this task's commit and verify all package hashes. The user's previous elevated Install copied runtime files to `Program Files\ChatpadBridge`, then halted before baseline capture or PnP binding. No live setup succeeded.

Required branch and starting point: `feature/chatpad-usermode-runner`, current pushed HEAD after the TASK 8L-C4L1 correction. Verify branch, commit and clean status first.

First inspect: `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, latest `docs/WORKLOG.md`; then `artifacts/task-8lc4/build-*/build-manifest.json` and `readiness-input.json`.

Preconditions: package manifest and readiness identify current branch/HEAD and the same package root; all listed SHA-256 values independently match. User runs exactly ` .\tools\ChatpadSetup.ps1 -Mode Install` from repository root in elevated PowerShell and returns complete output.

Safety: do not run Install from this non-elevated execution context. Do not bind, install/remove drivers, change security/trust, replug/reboot, or clean the partially copied Program Files directory. Stop on any identity/hash/preflight error and reconcile before another attempt. Do not modify `legacy/`.

Acceptance: confirm successful one-time setup and recovery baseline before proceeding to the separately specified live lifecycle criteria. Report unperformed behavior as UNTESTED; do not run the comprehensive suite during this focused packaging follow-up.

Inspect first: `tools/ChatpadSetup.ps1`, `tools/ChatpadC4Package.psm1`, `tools/New-ChatpadC4Readiness.ps1`, `tools/Test-ChatpadC4Setup.ps1`, and exact current package/readiness manifests.
