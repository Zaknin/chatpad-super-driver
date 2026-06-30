# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-kmdf-object-attributes`.
- Required starting commit for the next task:
  the pushed `driver: prepare dormant object attributes` commit on
  `origin/feature/offline-kmdf-object-attributes`.
- The repository contains:
  - a pure request-owner state model;
  - compile-only KMDF request-owner context declarations;
  - an ordinary storage initialization and pre-object validation helper for
    the future activation owner;
  - four exact compile-only parentage-aware object-attribute helpers;
  - an authoritative design for future dormant KMDF object creation and
    cleanup;
  - no production-driver linkage to the context module;
  - no live `WDFSPINLOCK`, `WDFREQUEST`, `WDFMEMORY`, target, request
    formatting, request submission, completion registration, cancellation, or
    hardware access.

## Recommended next objective

Implement only isolated dormant bookkeeping-spinlock and targetless reusable
activation-request creation in the compile-only context module.

The slice may call `WdfSpinLockCreate` and `WdfRequestCreate` using the exact
attribute helpers already implemented. The request must be created with no
initial I/O target, and its typed context must be initialized to the dormant
baseline. It must stop before outbound/inbound `WDFMEMORY` creation, rollback,
production-driver linkage, or owner-ready publication.

## Preconditions

1. Start from
   `origin/feature/offline-kmdf-object-attributes` at the exact pushed
   `driver: prepare dormant object attributes` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`;
   - `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
   - `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify the current branch, HEAD, upstream, and clean status before editing.

## Safety restrictions

- Do not create `WDFDEVICE`, `WDFMEMORY`, `WDFIOTARGET`, queues, timers, work
  items, USB targets, events, threads, or any lock other than the single
  dormant bookkeeping `WDFSPINLOCK`.
- Do not call `WdfDeviceCreate`, `WdfMemoryCreate`,
  `WdfMemoryCreatePreallocated`, `WdfObjectAllocateContext`, `WdfObjectDelete`,
  `WdfObjectReference`, `WdfObjectDereference`,
  `WdfWaitLockCreate`, `WdfUsbTargetDeviceCreate`,
  `WdfUsbTargetDeviceCreateWithParameters`,
  `WdfUsbTargetDeviceFormatRequestForControlTransfer`,
  `WdfIoTargetFormatRequestForInternalIoctlOthers`, `WdfRequestReuse`,
  `WdfRequestSetCompletionRoutine`, `WdfRequestSend`,
  `WdfRequestCancelSentRequest`, `WdfIoTargetStart`, `WdfIoTargetStop`, or
  `IoCallDriver`.
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

- Exactly one device-parented bookkeeping spinlock and one device-parented
  reusable request may be created by the isolated helper.
- The reusable request is created with no initial I/O target and receives the
  typed dormant request-context baseline.
- No outbound or inbound memory object is created.
- Existing storage initialization remains model-ready only and owner-ready is
  still not published.
- Semantic guards allow only the two selected creation calls and prove no
  other WDF object creation, target discovery, request
  formatting, request submission, completion registration, cancellation,
  installation, loading, signing, or hardware access exists.
- Continuation docs and worklog precisely state the remaining boundary.

## Files and commands to inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git log -5 --oneline --decorate
Get-Content docs\OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md
Get-Content docs\OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'PrepareBookkeepingLockAttributes|PrepareActivationRequestAttributes|WdfSpinLockCreate|WdfRequestCreate|ChatpadKmdfGetActivationRequestContext'
```
