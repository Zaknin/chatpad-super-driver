# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-kmdf-request-owner-context`.
- Required starting commit for the next task:
  the pushed `driver: define compile-only request contexts` commit on
  `origin/feature/offline-kmdf-request-owner-context`.
- The repository contains:
  - a pure request-owner state model;
  - compile-only KMDF request-owner context declarations;
  - a dedicated WDK compile-check target and wrapper;
  - no production-driver linkage to the new context module.

## Recommended next objective

Design the dormant WDF object-creation and cleanup checkpoint for the
activation request owner.

The next task should define the exact future creation/cleanup sequence for the
device-parented `WDFREQUEST`, request-parented outbound/inbound `WDFMEMORY`
objects, and device-owned `WDFSPINLOCK`, including partial-failure unwind and
D0/removal cleanup ordering. It should be documentation-first unless a later
task explicitly authorizes a dormant implementation.

## Preconditions

1. Start from `origin/feature/offline-kmdf-request-owner-context` at the exact
   pushed `driver: define compile-only request contexts` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify `tools\Test-ChatpadKmdfRequestOwnerContext.ps1 -Configuration Debug -Platform x64`
   and `tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Debug -Platform x64`
   still pass before relying on the context/model.

## Safety restrictions

- Do not create `WDFREQUEST`, `WDFMEMORY`, `WDFIOTARGET`, queues, timers, work
  items, USB targets, or locks unless a later task explicitly authorizes that
  implementation.
- Do not format, send, cancel, complete, wait for, reuse, or delete a live
  request.
- Do not add completion, cancel, PnP, power, queue, or timer callbacks.
- Do not call new code from `DriverEntry`, `EvtDeviceAdd`, D0-entry, D0-exit,
  cleanup, self-managed I/O, queue, or any runtime path unless the next task
  explicitly opens that scope.
- Do not change INF, catalog/package/signing scripts, staging/install paths,
  registry/service state, Driver Store state, or hardware/device state.
- Keep generated outputs under ignored `artifacts/`.
- Do not modify `legacy/`.

## Acceptance criteria

- The creation/cleanup plan identifies every future parent, attribute, context,
  ownership flag, partial-failure state, cleanup step, and stop condition.
- It preserves the pure model as the single ownership-state authority.
- It preserves the compile-only context module as absent from `ChatpadFilter`
  runtime behavior unless a later task explicitly authorizes dormant linkage.
- It does not authorize request formatting, submission, completion,
  cancellation, target discovery, installation, loading, signing, or hardware
  access.
- Continuation docs and worklog precisely state the remaining boundary.

## Files and commands to inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git log -5 --oneline --decorate
Get-Content docs\OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md
.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Debug -Platform x64
```
