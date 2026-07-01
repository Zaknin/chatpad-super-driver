# Next Task

## Current State

- Branch:
  `feature/offline-kmdf-production-orchestration-evidence-remediation`.
- Frozen implementation:
  `efb729502a0527ac70e2d20fa31a323c3beb2920`,
  `driver: invoke production request owner orchestration`.
- Implementation parent:
  `4ba0de15420e0b66287a501918de694c8b6fd720`.
- Remediation commit: the commit containing this file, with subject
  `test: remediate production orchestration evidence`.
- Implementation checkpoint:
  [Offline KMDF Production Orchestration Invocation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md).
- Remediation checkpoint:
  [Offline KMDF Production Orchestration Evidence Remediation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-REMEDIATION.md).
- Evidence manifest:
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json).

Production source is unchanged from the source-audited implementation commit.
The separate remediation binds Git's authoritative 14-path implementation
scope, all 18 status results, a closed 42-ID evidence set, exact per-entry
metadata, KMDF semantic output, repository safety, Git diff state, and explicit
containing-commit/self-reference limitations.

The driver has never been loaded. No runtime WDF graph, target discovery,
request operation, signing, staging, installation, Windows mutation, device
query, or hardware behavior has been observed.

## Recommended Objective

Perform an independent read-only audit of the frozen production implementation
together with the remediated guard, manifest, ignored evidence, containing
commit, and upstream state.

## Preconditions

1. Verify branch, HEAD, parent, exact subject, upstream, local/upstream
   equality, and clean worktree/index.
2. Require the remediation commit parent to equal
   `efb729502a0527ac70e2d20fa31a323c3beb2920`.
3. Re-read the repository protocol and latest worklog entry.
4. Independently derive the implementation commit's changed paths; Git must
   return 14, despite the superseded 15-path assumption in the remediation
   request.
5. Inspect the committed manifest and rehash every referenced ignored log.

## Safety Restrictions

- Read-only audit only.
- Do not regenerate evidence.
- Do not run builds, tests, guards, helpers, orchestration, or WDF actions.
- Do not sign, package, stage, install, load, mutate Windows, query devices, or
  interact with USB, XUSB, a controller, or a Chatpad.
- Do not modify `legacy/`.

## Acceptance Criteria

- Production source blobs exactly match implementation commit `efb7295`.
- Implementation parent-to-current scope is exactly the authoritative 14 paths.
- Guard reports 18 expected and 18 mapped results with zero discrepancies.
- Manifest schema is `1.1.0` with all 42 mandatory unique IDs.
- Every entry has exact command, configuration, count applicability, state
  binding, path, SHA-256, result, UTC time, and notes.
- Missing metadata, paths, mandatory IDs, and hash mismatches are all zero.
- KMDF context evidence contains the actual semantic PASS output.
- Repository safety, immutable commit scope, whitespace, unstaged, staged, and
  candidate-containment evidence are present and accurate.
- Debug and Release binaries match the remediated manifest.
- Full guard and staged evidence self-reference limits are stated honestly.
- No production source or prohibited artifact is in the remediation commit.
- No runtime or deployment action occurred.

## Inspect First

```powershell
git branch --show-current
git log -1 --format="%H%n%P%n%s"
git status --short --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-REMEDIATION.md
Get-Content docs\evidence\production-orchestration-invocation-manifest.json
Get-Content tools\Test-ChatpadProductionOrchestrationInvocation.ps1
```
