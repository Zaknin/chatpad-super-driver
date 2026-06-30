# Next Task

## Current state

- Current branch: `feature/offline-kmdf-creation-orchestration`.
- Expected checkpoint: pushed `driver: compose dormant object creation` commit
  created from `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`.
- The isolated context module compiles ordinary storage initialization,
  attribute preparation, four one-object creation helpers, rollback
  classification, partial-creation rollback, and dormant all-or-nothing
  creation orchestration.
- The orchestrator validates a clean `MODEL_READY` baseline, calls helpers in
  spinlock/request/outbound-memory/inbound-memory order, validates partial
  states, publishes `OWNER_READY` only after full pre-ready validation, and
  rolls back exactly once after object-published failure.
- No orchestration, creation, or rollback helper has executed. No production
  driver code references or links the isolated module.

## Recommended next objective

Perform an independent read-only audit of the completed dormant KMDF creation
orchestration checkpoint.

Do not implement production linkage in the audit task.

## Preconditions

1. Start from the exact pushed orchestration checkpoint with matching upstream
   and clean worktree/index.
2. Re-read `AGENTS.md`, current continuity docs, and
   `docs/OFFLINE-KMDF-CREATION-ORCHESTRATION.md`.
3. Verify that the final commit parent is
   `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`.
4. Verify `ChatpadFilter` still has no isolated context link, include, helper
   call, `/INCLUDE`, or new object-management import.

## Safety restrictions

- Read-only audit only: do not edit, rebuild, commit, push, package, sign,
  install, load, stage, query devices, or mutate Windows.
- Do not execute orchestration, creation, or rollback helpers.
- Do not run InfVerif or Inf2Cat.
- Keep any observation of existing artifacts non-mutating.

## Acceptance criteria

- Report exact branch, HEAD, parent, upstream, and clean status.
- Confirm changed files are limited to isolated context source/header,
  compile-check, semantic/test wrappers, and documentation.
- Confirm direct WDF counts remain `WdfSpinLockCreate=1`,
  `WdfRequestCreate=1`, `WdfMemoryCreatePreallocated=2`,
  `WdfObjectDelete=2`.
- Confirm orchestrator helper order, single centralized rollback call site,
  final-only `OWNER_READY`, ready/faulted/partial pre-helper rejection, and no
  retry loop.
- Confirm validation evidence and artifact containment from the checkpoint.
- Confirm no production linkage, target discovery, request operation, signing,
  staging, installation, loading, Windows mutation, or hardware access.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\OFFLINE-KMDF-CREATION-ORCHESTRATION.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'CreateDormantObjectGraph|CreateBookkeeping|CreateReusable|CreateOutbound|CreateInbound|RollbackPartialCreation|OWNER_READY'
Select-String -Path src\driver\ChatpadFilter\* -Pattern 'ChatpadKmdfRequestOwner|CreateDormantObjectGraph'
```
