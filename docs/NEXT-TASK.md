# Next Task

## Current state

- Current branch: `feature/offline-kmdf-memory-creation`.
- Expected checkpoint commit: the pushed
  `driver: define dormant memory creation` commit created from
  `9bd3a8e0ce6a94a5d6c7f6d45d2ca651d50ea497`.
- The isolated static-library module compiles independent dormant creation for
  a device-parented lock, targetless device-parented request, and
  request-parented outbound/inbound preallocated memory over exact two-byte
  owner arrays.
- Partial validation accepts model-only, lock, lock/request,
  outbound-memory, and both-memory states. `OWNER_READY` remains unset.
- No creation helper has executed. `ChatpadFilter` does not include, link,
  embed, retain, or invoke the isolated module.

## Recommended next objective

Design and implement only isolated rollback orchestration for partial creation
failure. It must unwind the request tree before the bookkeeping lock, clear
published handles/bits deterministically, preserve the original failure
status, and leave owner-ready unset.

This objective requires a new explicit task. This file does not authorize it.

## Preconditions

1. Start from the exact pushed `driver: define dormant memory creation` commit
   on `origin/feature/offline-kmdf-memory-creation`.
2. Require a clean worktree/index and matching local/upstream HEAD.
3. Re-read `AGENTS.md`, project continuity documents, the complete object
   creation/cleanup design, and
   `docs/OFFLINE-KMDF-PREALLOCATED-MEMORY-CREATION.md`.
4. Reconfirm installed KMDF 1.15 deletion and parent-child cleanup contracts
   before selecting exact rollback calls.

## Safety restrictions

- Do not execute creation or rollback helpers.
- Do not publish `OWNER_READY` or link the module into `ChatpadFilter`.
- Do not discover a target or format, reuse, send, complete, or cancel a
  request.
- Do not change active callbacks, device context, INF/package/signing/install
  paths, Windows state, or hardware state.
- Do not install, stage, sign, package, or load a driver.
- Keep generated outputs under ignored `artifacts/`; never modify `legacy/`.

## Acceptance criteria

- Rollback ordering and ownership follow the request-parent hierarchy.
- Each partial state has deterministic reverse-order cleanup and mask/handle
  invalidation.
- Original creation failure status is preserved separately from rollback
  diagnostics.
- Cleanup remains compile-only, unexecuted, unlinked, and semantically guarded.
- No target, request-operation, deployment, or hardware surface is introduced.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
Get-Content docs\OFFLINE-KMDF-PREALLOCATED-MEMORY-CREATION.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'CreateOutboundMemory|CreateInboundMemory|WdfMemoryCreatePreallocated|InitializationMask'
```
