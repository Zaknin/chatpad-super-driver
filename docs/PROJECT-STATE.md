# Project State

*Last updated: 2026-07-03 (offline exact-instance framework finalization)*

## Current state

- **Branch:** `feature/runtime-bringup-exact-instance-binding-restoration`.
- **Starting audited commit:**
  `b9374d8a98392de67824aac4235021b5bd90d284`.
- **Implementation commit:**
  `0060cd91be7d460f1a4141f6bf893bd56b32bf35`, subject
  `Implement offline exact-instance binding framework`.
- **Corrective implementation commit:**
  `fdcd9448a3dc172213c07928af45d2e68fd0197a`, subject
  `Verify analyzer and updated script inventory`.
- **Expected finalization commit:** the commit containing this file, subject
  `docs: finalize exact-instance framework evidence`.
- **Accepted offline baseline:** commit
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256
  `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.
- **Frozen binaries:** Debug 68,096 bytes,
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`;
  Release 40,960 bytes,
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`.

## Exact-instance implementation

- Pure contracts validate complete instance IDs, canonical ordinal identity,
  paths, target/restoration driver identities, plans, snapshots, evidence,
  execution gates, and state transitions.
- Plan and snapshot hashes use a deterministic canonical encoder with identical
  results under Windows PowerShell and PowerShell 7.
- The fake adapter models same-hardware-ID devices, same-compatible-ID devices,
  same-container siblings, similar instance prefixes, absent/duplicate
  records, package absence/ambiguity, restart/reboot outcomes, postcondition
  mismatch, partial mutation, restoration failure, and adapter exceptions.
- The orchestrator verifies the same exact instance before and after every
  synthetic mutation. It has no hardware-ID, compatible-ID, class, package,
  first-match, or best-rank targeting fallback.
- The public command defaults to `Plan`. No live Windows adapter is present or
  invocable in this phase.
- T1-T25: `PASS`; 25 records; 99 assertions; 50 allowed transition edges
  validated; five prohibited transition probes rejected; static broad-action
  guard `PASS`.
- Synthetic accounting: 14 bind attempts, four restoration attempts, zero
  restart attempts, one rejected broad-operation attempt, one expected
  post-mutation adapter-exception uncertainty case, and zero unexpected harness
  exceptions.

## Readiness and evidence

- Framework status: `PASS`.
- Live installation readiness: `BLOCKED`.
- Blocker: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Authoritative ledger: 329 records and 1,823 assertions, increased from
  304/1,724 by exactly 25 records and 99 assertions in category
  `exact-instance-offline`.
- Record/category sums reconcile at 329/329 and 1,823/1,823. Unassigned,
  off-ledger, duplicate-counted, zero-assertion PASS, skipped-as-PASS, and
  category-reconciliation defects are zero.
- Runtime observer provenance, lifecycle, malformed-input totality,
  stop-linkage, committed sample, and prior readiness contracts remain `PASS`.
- PowerShell inventory: 43 `.ps1`, 6 `.psm1`, 49 total; AST errors `0`.
- PSScriptAnalyzer ran with zero errors; retained warnings are style findings
  and pre-existing repository conventions.
- Ignored exact-instance evidence:
  `artifacts/logs/exact-instance-binding-restoration-suite-post-implementation-fdcd944.json`,
  529,662 bytes,
  `3D81C8FA8612B36A1FC10B57851D32E5C053BBF78BB9BF8D526E54F774303ADA`,
  JSON valid, UTF-8 without BOM.
- Ignored full-readiness evidence:
  `artifacts/logs/runtime-bringup-exact-instance-suite-post-implementation-fdcd944.json`,
  867,941 bytes,
  `F21A0BAC76CD075A29A443549237039D2F926263FF01DDFC5DD091F9DE2FF6B7`,
  JSON valid, UTF-8 without BOM.

## Safety and blocker

- Live exact-instance binding operations: `0`.
- Live exact-instance restoration operations: `0`.
- Live restart operations: `0`.
- Broad successful install/rollback operations: `0`.
- Live observations: `0`.
- Windows mutations: `0`.
- No production source/header, INF, project, solution, protocol, transport,
  binary, package, credential, signing material, or `legacy/` path changed.
- No driver build, signing, CAT generation, package creation/staging,
  installation, binding, loading, restoration, restart, reboot, driver-store,
  registry, service, boot, security, trace, event-log, device, hardware,
  protocol, or input operation occurred.
- **Remaining blocker:** independent read-only audit has not been performed.
  A native Windows exact-instance adapter remains a separately authorized
  future implementation and audit boundary.
