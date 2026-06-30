# Project State

*Last updated: 2026-06-30 (production integration design checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-production-integration-design`.
- **Expected checkpoint commit:** `docs: define kmdf production integration`,
  created from `39b2356c9193ea33d10d5c689e565a88a2e586c3`.
- **Authoritative production integration design:**
  [Windows 11 KMDF Production Integration Design](WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md).
- **Implementation:** No production integration has begun. The isolated
  dormant request-owner implementation is complete and audited through
  documentation here, but remains unlinked from `ChatpadFilter`.
- **Selected integration strategy:** Use the existing
  `ChatpadKmdfRequestOwnerContext` static-library project as the production
  dependency, add the owner to the `WDFDEVICE` context only in a later slice,
  initialize ordinary owner storage after current context scalar setup, and
  invoke dormant orchestration at that same `EvtDeviceAdd` point only in a
  later separately authorized slice.
- **Execution:** No helper has executed. No lock, request, memory object, or
  rollback deletion has been created or deleted at runtime.
- **Evidence contract:** Future implementation checkpoints should retain
  ignored logs under `artifacts\logs` and bind them to commits through tracked
  JSON manifests under `docs/evidence/`.
- **Safety:** Target discovery, request formatting/submission, completion,
  cancellation, D0 rundown, INF/package/signing, staging, installation,
  loading, Windows mutation, device enumeration, and controller/Chatpad
  interaction remain unauthorized.

## Unresolved blockers

- Production project linkage has not begun.
- Device-context owner embedding has not begun.
- Ordinary owner initialization is not connected to production code.
- Dormant orchestration is not connected to production code.
- Normal teardown, active-operation rundown, target and request operations,
  sequencing, D0 coordination, signing, staging, installation, loading,
  USB/controller validation, and Chatpad input remain separate gates.
- No usable production driver exists.
