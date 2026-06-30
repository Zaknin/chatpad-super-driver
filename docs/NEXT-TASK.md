# Next Task

## Current state

- Current branch: `feature/offline-kmdf-owner-embedding-init`.
- Required starting commit: the pushed commit with exact subject
  `driver: initialize production request owner`.
- Required parent:
  `41172d7f2877509a16f3b58abf0f81d231cbabaf`.
- Checkpoint record:
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
- Evidence manifest:
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json).

## Recommended objective

Perform an independent read-only audit of production device-context owner
embedding and ordinary initialization evidence.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Read the repository protocol and current continuity documents.
3. Parse the manifest and verify every retained path and SHA-256.
4. Inspect the complete containing commit diff.
5. Revalidate existing driver hashes, signatures, symbols, and imports without
   rebuilding.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not build, edit, regenerate evidence, or invoke an implementation helper.
- Do not invoke dormant orchestration or any creation/rollback helper.
- Do not create/delete a WDF object or perform a target/request operation.
- Do not modify D0, cleanup, removal, INF, signing, package, deployment, or
  recovery behavior.
- Do not sign, stage, install, load, mutate Windows, enumerate hardware, or
  interact with a controller or Chatpad.

## Acceptance criteria

- Exactly one authoritative owner is embedded directly in the device context.
- Exactly one ordinary initializer and one immediate pre-object validator call
  occur after scalar setup and before lifecycle initialization.
- Status mappings match the production-integration design.
- The portable model source is linked once; isolated context source is not
  compiled into `ChatpadFilter`.
- Debug and Release evidence paths/hashes match.
- Creation, rollback, orchestration, object-management imports, and
  target/request behavior are absent.
- The audit reports PASS or FAIL without changing repository or machine state.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
Get-Content docs\evidence\production-owner-initialization-manifest.json
Get-Content docs\OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md
git show --stat --oneline HEAD
```
