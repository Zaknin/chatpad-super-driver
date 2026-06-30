# Next Task

## Current state

- Current branch: `feature/offline-production-linkage-evidence-fix`.
- Starting linkage commit:
  `90ca13f8babfc0c8fd1d14c998c1719e4788a5f6`.
- The evidence-only correction is documented in
  [Offline Production Linkage Evidence Correction](OFFLINE-PRODUCTION-LINKAGE-EVIDENCE-CORRECTION.md).
- The corrected tracked manifest is
  [production-linkage-manifest.json](evidence/production-linkage-manifest.json).
- All historical retained log paths resolve and match their recorded hashes.
- No linkage implementation, source, project, solution, script, test, or
  generated binary changed. No build or regression suite was rerun.

## Recommended next objective

Perform an independent read-only audit of the corrected evidence manifest,
followed only after PASS by the separately gated owner-embedding and
ordinary-initialization design slice selected in the production-integration
plan.

## Required branch and starting commit

Start from the pushed
`feature/offline-production-linkage-evidence-fix` checkpoint. Verify its exact
HEAD, parent, subject, upstream, and clean worktree/index. The required parent
is `90ca13f8babfc0c8fd1d14c998c1719e4788a5f6` and the required subject is
`docs: complete production linkage evidence`.

## Preconditions

1. Re-read the repository protocol and current continuity documents.
2. Parse the corrected manifest and enumerate all `evidence_entries`.
3. Verify each retained path exists and each SHA-256 matches.
4. Verify the containing commit changed only the authorized JSON and Markdown.
5. Revalidate artifact size/hash/signature without rebuilding.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not regenerate historical build or regression evidence.
- Do not modify source, headers, projects, solutions, scripts, tests, INF,
  signing, packaging, deployment, or recovery files.
- Do not embed or initialize the owner unless a later task separately
  authorizes that design slice after audit PASS.
- Do not invoke helpers, create/delete WDF objects, build, install, load,
  mutate Windows, query hardware, or interact with the controller/Chatpad.

## Acceptance criteria

- Every manifest evidence entry has an exact command, configuration or explicit
  `N/A`, path, SHA-256, result, and applicable counts.
- Every retained path and hash matches.
- The five evidence-correction transcripts are deterministic and hash-bound.
- Artifact sizes, hashes, and Authenticode states match the manifest.
- The correction commit contains only authorized JSON and Markdown.
- The audit states PASS or FAIL before any owner-embedding work is considered.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
Get-Content docs\evidence\production-linkage-manifest.json
Get-Content docs\OFFLINE-PRODUCTION-LINKAGE-EVIDENCE-CORRECTION.md
git diff 90ca13f8babfc0c8fd1d14c998c1719e4788a5f6..HEAD --name-status
```
