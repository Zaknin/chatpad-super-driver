# Next Task

## Current state

- Current branch after this checkpoint:
  `feature/offline-kmdf-lock-request-creation`.
- Required starting commit for the next task:
  the pushed `driver: define dormant lock request creation` commit on
  `origin/feature/offline-kmdf-lock-request-creation`.
- The repository contains:
  - a pure request-owner state model;
  - compile-only KMDF request-owner context declarations;
  - an ordinary storage initialization and pre-object validation helper for
    the future activation owner;
  - four exact compile-only parentage-aware object-attribute helpers;
  - independent compile-only dormant spinlock/request creation helpers;
  - deterministic typed request-context initialization and partial-state
    validation;
  - an authoritative design for future dormant KMDF object creation and
    cleanup;
  - no production-driver linkage to the context module;
  - no executed or live `WDFSPINLOCK`, `WDFREQUEST`, `WDFMEMORY`, target, request
    formatting, request submission, completion registration, cancellation, or
    hardware access.

## Recommended next objective

Implement only isolated request-parented outbound and inbound preallocated
memory creation in the compile-only context module.

The slice may compile exactly two `WdfMemoryCreatePreallocated` calls using the
existing request-parented attributes and fixed two-byte owner arrays. It must
not execute creation, implement rollback/deletion, link into `ChatpadFilter`,
publish owner-ready, discover a target, or perform any request operation.

## Preconditions

1. Start from
   `origin/feature/offline-kmdf-lock-request-creation` at the exact pushed
   `driver: define dormant lock request creation` commit.
2. Confirm the worktree and index are clean.
3. Read, in order:
   - `AGENTS.md`;
   - `docs/PROJECT-STATE.md`;
   - `docs/DECISIONS.md`;
   - this file;
   - the latest `docs/WORKLOG.md` entry;
   - `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`;
   - `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`;
   - `docs/OFFLINE-KMDF-LOCK-REQUEST-CREATION.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
   - `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
   - `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
   - `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
4. Verify the current branch, HEAD, upstream, and clean status before editing.

## Safety restrictions

- Do not create `WDFDEVICE`, `WDFIOTARGET`, queues, timers, work items, USB
  targets, events, threads, locks, or requests.
- Do not call `WdfDeviceCreate`, `WdfMemoryCreate`,
  `WdfObjectAllocateContext`, `WdfObjectDelete`,
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

- Exactly one outbound and one inbound request-parented preallocated-memory
  creation call may be compiled against the two fixed owner arrays.
- Creation helpers remain unexecuted; no memory object is actually created.
- Existing lock/request partial-state validation remains required.
- Existing storage initialization remains model-ready only and owner-ready is
  still not published.
- Semantic guards preserve the existing single lock/request creation calls,
  allow exactly two selected preallocated-memory creation calls, and prove no
  other WDF object creation, deletion, rollback, target discovery, request
  formatting, submission, completion registration, cancellation, installation,
  loading, signing, or hardware access exists.
- Continuation docs and worklog precisely state the remaining boundary.

## Files and commands to inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git log -5 --oneline --decorate
Get-Content docs\OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md
Get-Content docs\OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md
Get-Content docs\OFFLINE-KMDF-LOCK-REQUEST-CREATION.md
Get-Content docs\WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md
Select-String -Path src\driver\ChatpadKmdfRequestOwnerContext\* -Pattern 'PrepareOutboundMemoryAttributes|PrepareInboundMemoryAttributes|WdfMemoryCreatePreallocated|LOCK_REQUEST_CREATED'
```
