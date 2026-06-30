# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-kmdf-owner-storage-init`.
- Required starting commit for the next task:
  the pushed `driver: initialize dormant request owner` commit on
  `origin/feature/offline-kmdf-owner-storage-init`.
- The repository contains:
  - a pure request-owner state model;
  - compile-only KMDF request-owner context declarations;
  - an ordinary storage initialization and pre-object validation helper for
    the future activation owner;
  - an authoritative design for future dormant KMDF object creation and
    cleanup;
  - no production-driver linkage to the context module;
  - no live `WDFSPINLOCK`, `WDFREQUEST`, `WDFMEMORY`, target, request
    formatting, request submission, completion registration, cancellation, or
    hardware access.

## Recommended next objective

Implement only compile-only attribute/parentage preparation helpers for the
future dormant object-creation slice, without creating any WDF object.

The next helper may prepare caller-owned `WDF_OBJECT_ATTRIBUTES` values for:

- device-parented bookkeeping spinlock;
- device-parented reusable activation request with typed request context;
- request-parented outbound memory;
- request-parented inbound memory.

It must not call `WdfSpinLockCreate`, `WdfRequestCreate`,
`WdfMemoryCreatePreallocated`, or any other object-creation API.

## Preconditions

1. Start from
   `origin/feature/offline-kmdf-owner-storage-init` at the exact pushed
   `driver: initialize dormant request owner` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
   - `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify the current branch, HEAD, upstream, and clean status before editing.

## Safety restrictions

- Do not create `WDFDEVICE`, `WDFREQUEST`, `WDFMEMORY`, `WDFIOTARGET`, queues,
  timers, work items, USB targets, events, threads, or locks.
- Do not call `WdfDeviceCreate`, `WdfRequestCreate`, `WdfMemoryCreate`,
  `WdfMemoryCreatePreallocated`, `WdfObjectAllocateContext`, `WdfObjectDelete`,
  `WdfObjectReference`, `WdfObjectDereference`, `WdfSpinLockCreate`,
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

- Attribute helpers initialize caller-owned attributes only.
- Device-parent and request-parent intent is represented only in attributes and
  compile checks; no object is created.
- Existing storage initialization remains model-ready only and owner-ready is
  still not published.
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
Get-Content docs\OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'ChatpadKmdfRequestOwnerInitializeStorage|ChatpadKmdfRequestOwnerValidatePreObjectState|WDF_OBJECT_ATTRIBUTES|ParentObject'
```
