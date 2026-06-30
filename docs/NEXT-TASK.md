# Next Task

## Current state

- Current branch: `feature/offline-kmdf-creation-rollback`.
- Expected checkpoint: pushed `driver: define dormant creation rollback`
  commit created from `142f8e11bebac78cf2e10367c96d3b409d9c8db7`.
- Independent compile-only helpers exist for lock, request, outbound memory,
  inbound memory, rollback-state classification, and reverse-order rollback.
- Rollback is request hierarchy first, spinlock second, with exact
  `MODEL_READY | FAULTED` post-state and idempotent clean behavior.
- No helper has executed and no production driver code references the module.

## Recommended next objective

Implement only full dormant creation orchestration that calls the existing
one-object helpers in order, invokes rollback on partial failure, validates the
complete dormant object graph, and finally publishes non-runtime
`OWNER_READY`.

This requires a new explicit task and remains unauthorized here.

## Preconditions

1. Start from the exact pushed rollback checkpoint with matching upstream and
   clean worktree/index.
2. Re-read all continuity documents, the creation/cleanup design, and the
   rollback checkpoint.
3. Preserve exact framework failure status separately from rollback effects.
4. Reconfirm no orchestrator can execute or link into `ChatpadFilter`.

## Safety restrictions

- Keep orchestration compile-only and uninvoked.
- Do not add production linkage, callbacks, target discovery, request
  formatting/reuse/send/completion/cancellation, or normal teardown.
- Do not install, stage, sign, package, load, mutate Windows, or access devices.
- Keep outputs under ignored `artifacts/`; never modify `legacy/`.

## Acceptance criteria

- Creation order is lock, request, outbound memory, inbound memory.
- Every partial failure invokes the existing rollback helper exactly once.
- Original failure status and rollback effects remain independently visible.
- `OWNER_READY` publishes only after complete invariant validation.
- Compile-check and guards prove no helper execution or production linkage.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
Get-Content docs\OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'CreateBookkeeping|CreateReusable|CreateOutbound|CreateInbound|RollbackPartialCreation'
```
