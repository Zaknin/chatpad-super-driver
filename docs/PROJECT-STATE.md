# Project State

*Last updated: 2026-06-30 (dormant creation orchestration checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-creation-orchestration`.
- **Expected checkpoint commit:** `driver: compose dormant object creation`,
  created from `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`.
- **Authoritative orchestration checkpoint:**
  [Offline KMDF Creation Orchestration](OFFLINE-KMDF-CREATION-ORCHESTRATION.md).
- **Implementation:** The isolated static library compiles four independent
  creation helpers, a non-mutating rollback-state classifier, one dormant
  reverse-order partial-creation rollback helper, and one dormant
  all-or-nothing orchestration helper.
- **Orchestration:** A clean `MODEL_READY` owner is validated, then helpers are
  composed in order: spinlock, targetless request, outbound preallocated
  memory, inbound preallocated memory. `OWNER_READY` is published only after
  the complete pre-ready graph validates, and final ready validation must pass.
- **Rollback/idempotence:** Any partial object publication on orchestration
  failure uses the existing rollback helper exactly once. Valid ready,
  faulted, or partial owners are classified before helper invocation; partial
  state is not resumed.
- **Storage/model:** Fixed arrays and pure-model state are preserved. No
  context access occurs after request deletion begins.
- **Execution:** Static compile checks take helper addresses only. Exact direct
  WDF call counts remain one spinlock create, one request create, two
  preallocated-memory creates, and two object deletes; none executes.
- **Dormancy:** `ChatpadFilter`, active callbacks, live device context, INF,
  package/signing, installation, and runtime behavior remain unchanged and do
  not link the isolated module.
- **Verification:** Required Debug/Release builds, regressions, semantic guards,
  symbol/import inspection, repository safety, containment, and whitespace
  checks pass. Generated outputs remain ignored beneath `artifacts/`.

## Unresolved blockers

- No orchestration, creation, or rollback helper has executed; no live WDF graph
  exists.
- Production linkage, normal teardown, active-operation rundown, target and
  request operations, sequencing, and D0 coordination remain separate gates.
- Signing, staging, installation, loading, USB/controller validation, and
  Chatpad input remain unproven and unauthorized.
- No usable production driver exists.
