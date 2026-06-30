# Next Task

## Current state

- Current branch: `feature/offline-owner-init-audit-corrections`.
- Required starting commit: the pushed commit with exact subject
  `test: tighten owner initialization audit`.
- Required parent: `a25d5637487ec6e4e7583a64dcec6c5192e06092`.
- Checkpoint record:
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
- Correction record:
  [Offline KMDF Owner Initialization Audit Corrections](OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md).
- Evidence manifest:
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json).

## Recommended objective

Perform an independent read-only audit of the corrected production
request-owner initialization documentation, semantic guard, and evidence
manifest.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Read the repository protocol and current continuity documents.
3. Parse the corrected manifest and verify every retained path and SHA-256.
4. Inspect the complete correction commit diff.
5. Revalidate existing driver hashes, signatures, symbols, imports, object
   references, library members, linker tlogs, and guard output without
   rebuilding.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not edit files, stage changes, commit, push, rebuild, or regenerate
  evidence.
- Do not run regression suites or driver build wrappers.
- Do not invoke any driver helper through a loaded driver.
- Do not invoke dormant orchestration or any creation/rollback helper.
- Do not create/delete a WDF object or perform a target/request operation.
- Do not modify D0, cleanup, removal, INF, signing, package, deployment, or
  recovery behavior.
- Do not sign, stage, install, load, mutate Windows, enumerate hardware, or
  interact with a controller or Chatpad.

## Acceptance criteria

- Documentation no longer states that project linkage is the current
  production boundary after the owner-embedding checkpoint.
- The initializer-internal validation and the one explicit `EvtDeviceAdd`
  pre-object boundary validation are described as distinct checks.
- Debug and Release guard output distinguishes direct evidence from inferred
  evidence and states proof limitations.
- Existing artifacts are inspected read-only; Debug direct references and
  Release `/GL` source/input evidence are interpreted correctly.
- The manifest records exact commands, working directories, paths, SHA-256
  values, and results for corrected evidence entries.
- Every manifest path exists and every SHA-256 matches.
- No production source/header, project/solution, implementation script, binary,
  or generated artifact is changed by the audit.
- The audit reports PASS or FAIL without changing repository or machine state.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
Get-Content docs\evidence\production-owner-initialization-manifest.json
Get-Content docs\OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md
Get-Content docs\OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md
git show --stat --oneline HEAD
```
