# Project State

*Last updated: 2026-06-30 (dormant partial-creation rollback checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-creation-rollback`.
- **Expected checkpoint commit:** `driver: define dormant creation rollback`,
  created from `142f8e11bebac78cf2e10367c96d3b409d9c8db7`.
- **Authoritative rollback checkpoint:**
  [Offline KMDF Partial-Creation Rollback](OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md).
- **Implementation:** The isolated static library compiles four independent
  creation helpers, a non-mutating rollback-state classifier, and one dormant
  reverse-order partial-creation rollback helper.
- **Rollback:** Valid pre-ready partial states delete the request hierarchy
  first and spinlock second. Memory children are deleted only through request
  parentage. Owner handles/bits clear immediately after deletion initiation;
  the result is `MODEL_READY | FAULTED`.
- **Idempotence:** Clean `MODEL_READY` and rolled-back
  `MODEL_READY | FAULTED` states initiate no deletion. Ready, draining, active,
  invalid-model, or handle/bit-inconsistent states are rejected unchanged.
- **Storage/model:** Fixed arrays and pure-model state are preserved. No
  context access occurs after request deletion begins.
- **Execution:** Static compile checks take helper addresses only. Exact call
  counts are one spinlock create, one request create, two preallocated-memory
  creates, and two object deletes; none executes.
- **Dormancy:** `ChatpadFilter`, active callbacks, live device context, INF,
  package/signing, installation, and runtime behavior remain unchanged and do
  not link the isolated module.
- **Verification:** Required Debug/Release builds, regressions, semantic guards,
  symbol/import inspection, repository safety, containment, and whitespace
  checks pass. Generated outputs remain ignored beneath `artifacts/`.

## Unresolved blockers

- No creation or rollback helper has executed; no live WDF graph exists.
- Full creation orchestration and final owner-ready publication are not
  implemented or authorized.
- Production linkage, normal teardown, active-operation rundown, target and
  request operations, sequencing, and D0 coordination remain separate gates.
- Signing, staging, installation, loading, USB/controller validation, and
  Chatpad input remain unproven and unauthorized.
- No usable production driver exists.
