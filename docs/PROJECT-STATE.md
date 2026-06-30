# Project State

*Last updated: 2026-06-30 (dormant preallocated-memory creation checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-memory-creation`.
- **Expected checkpoint commit:** this documentation is part of
  `driver: define dormant memory creation`, created from
  `9bd3a8e0ce6a94a5d6c7f6d45d2ca651d50ea497`.
- **Authoritative memory checkpoint:**
  [Offline KMDF Preallocated-Memory Creation](OFFLINE-KMDF-PREALLOCATED-MEMORY-CREATION.md).
- **Implementation:** `ChatpadKmdfRequestOwnerContext` remains an isolated WDK
  static library. It defines ordinary owner storage, typed request context,
  exact attribute helpers, and four independent dormant one-object creation
  helpers for the device-parented spinlock, targetless device-parented request,
  and request-parented outbound/inbound preallocated memory.
- **Memory parentage:** both `WDFMEMORY` descriptors are parented to the exact
  reusable owner request and describe the distinct fixed two-byte owner arrays.
  The arrays remain ordinary device-owner storage and are not owned by WDF.
- **Handle authority:** owner fields are authoritative for outbound/inbound
  memory handles. The request context has no duplicate mutable handles and
  remains in its inactive baseline.
- **State:** partial validation distinguishes model-only, lock-created,
  lock/request-created, outbound-memory-created, and both-memory-created
  states. The pure model remains unavailable/non-admitting and `OWNER_READY`
  remains unset.
- **Execution:** the compile-check takes helper addresses only. Exactly one
  `WdfSpinLockCreate`, one targetless `WdfRequestCreate`, and two
  `WdfMemoryCreatePreallocated` calls compile; none executes.
- **Dormancy:** `ChatpadFilter` does not include, compile, link, retain, embed,
  or invoke the context module. Its active callbacks, device context, runtime
  behavior, INF, package/signing, and install/recovery paths are unchanged.
- **Verification:** x64 Debug/Release compile checks, full solutions, driver
  builds, all required regression wrappers, semantic guards, symbol/import
  inspection, repository safety, containment, and whitespace checks pass.
- **Containment:** all generated outputs/logs remain ignored beneath
  `artifacts/`; no generated artifact is tracked.

## Unresolved blockers

- Creation helpers have never executed; no live WDF object graph exists.
- Reverse-order rollback/deletion orchestration is not implemented or
  authorized.
- Owner-ready publication and production linkage are not implemented.
- Target discovery, formatting, reuse, submission, completion, cancellation,
  sequencing, and D0 rundown remain separate design/implementation gates.
- USB visibility, controller preservation, activation effectiveness, Chatpad
  input, signing, staging, installation, loading, and hardware validation are
  unproven and unauthorized.
- No usable production driver exists.
