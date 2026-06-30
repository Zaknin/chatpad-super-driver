# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-kmdf-request-object-lifecycle-design`.
- Required starting commit for the next task:
  the pushed `docs: define kmdf object lifecycle` commit on
  `origin/feature/offline-kmdf-request-object-lifecycle-design`.
- The repository contains:
  - a pure request-owner state model;
  - compile-only KMDF request-owner context declarations;
  - an authoritative design for future dormant KMDF object creation and
    cleanup;
  - no production-driver linkage to the context module;
  - no live `WDFSPINLOCK`, `WDFREQUEST`, `WDFMEMORY`, target, request
    formatting, request submission, completion registration, cancellation, or
    hardware access.

## Recommended next objective

Implement only the first future slice: a pure helper for owner-structure
initialization and validation, with no WDF object-creation call.

The helper may prepare ordinary C storage and validate the intended invariants
described in
[Windows 11 KMDF Request Object Creation and Cleanup Design](WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md),
but it must not create a WDF request, memory object, lock, target, queue,
timer, work item, device, USB object, or callback.

## Preconditions

1. Start from
   `origin/feature/offline-kmdf-request-object-lifecycle-design` at the exact
   pushed `docs: define kmdf object lifecycle` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
   - `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify the current branch, HEAD, upstream, and clean status before editing.

## Safety restrictions

- Do not create `WDFREQUEST`, `WDFMEMORY`, `WDFIOTARGET`, queues, timers, work
  items, USB targets, devices, events, threads, or locks.
- Do not call `WdfRequestCreate`, `WdfMemoryCreate`,
  `WdfMemoryCreatePreallocated`, `WdfObjectAllocateContext`,
  `WdfSpinLockCreate`, `WdfWaitLockCreate`, `WdfObjectDelete`,
  `WdfObjectReference`, `WdfObjectDereference`, `WdfRequestReuse`,
  `WdfRequestSetCompletionRoutine`, `WdfRequestSend`,
  `WdfRequestCancelSentRequest`, `WdfUsbTargetDeviceCreate`,
  `WdfUsbTargetDeviceFormatRequestForControlTransfer`, or
  `WdfIoTargetFormatRequestForInternalIoctlOthers`.
- Do not format, send, cancel, complete, wait for, reuse, or delete a live
  request.
- Do not add cleanup, destroy, completion, cancellation, PnP, power, queue,
  timer, or runtime callbacks.
- Do not call new code from `DriverEntry`, `EvtDeviceAdd`, D0-entry, D0-exit,
  cleanup, self-managed I/O, queue, or any runtime path unless a later task
  explicitly authorizes that dormant linkage.
- Do not change INF, catalog/package/signing scripts, staging/install paths,
  registry/service state, Driver Store state, or hardware/device state.
- Keep generated outputs under ignored `artifacts/`.
- Do not modify `legacy/`.

## Acceptance criteria

- The helper initializes ordinary owner fields only and leaves all WDF handle
  fields null.
- The pure request-owner model remains the only transition/accounting
  authority.
- The helper validates the exact two-byte outbound and inbound capacities.
- The helper does not publish owner-ready state as though framework objects
  exist.
- Semantic guards prove no WDF object creation, target discovery, request
  formatting, request submission, completion registration, cancellation,
  installation, loading, signing, or hardware access exists.
- Continuation docs and worklog precisely state the remaining boundary.

## Files and commands to inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git log -5 --oneline --decorate
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Get-Content docs\OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'WDFREQUEST|WDFMEMORY|WDFSPINLOCK|InitializationMask'
```
