# Project State

*Last updated: 2026-07-02 (runtime-observer provenance and assertion-accounting remediation)*

## Current state

- **Branch:** `feature/runtime-bringup-observer-provenance-accounting-remediation`.
- **Starting commit:** `9b5c8f3b4ac8c0dc0453da693266a82fea636ec0`.
- **Primary implementation commit:**
  `b6b62a974bf7705e4cabc0bc98ffa44bf0718ddb`, subject
  `Harden runtime observer provenance and accounting`.
- **Corrective implementation commit:**
  `ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10`, subject
  `Write readiness manifest without UTF-8 BOM`.
- **Expected evidence-finalization commit:** the commit containing this file,
  subject `docs: finalize observer provenance and accounting evidence`.
- **Accepted offline baseline:**
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256
  `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.
- **Frozen binaries:** Debug 68,096 bytes,
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`;
  Release 40,960 bytes,
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`.
- **Offline suite:** framework `PASS`; live readiness `BLOCKED`; blocker
  `BLOCKED_NOT_IMPLEMENTED`; 304 first-class fixture records; 1,724
  assertions.
- **Accounting:** record count `304`; category record sum `304`; record
  assertion sum `1,724`; category assertion sum `1,724`; unassigned,
  off-ledger, duplicate-counted, and category-reconciliation defects all `0`.
- **Runtime observers:** five structural synthetic records pass the isolated
  shape contract; 140 runtime-evaluation negative fixtures pass; five
  missing-provenance and five synthetic-source probes produce zero runtime
  PASS results; live observations performed `0`.
- **Stop linkage:** 20 conditions; 20 unique IDs; five runtime-observer links;
  unlinked, unknown, malformed, and nested-array acceptance counts all `0`.
- **PowerShell inventory:** 41 `.ps1`, 2 `.psm1`, 43 total; AST errors `0`.
- **PSScriptAnalyzer:** `SKIPPED_UNAVAILABLE`.

## Implementation truth

- `Test-ChatpadRuntimeObservationRecordShape` validates closed source/mode
  enums, stable observation/condition/session/host identities, approved
  producer and observer path, timestamp order/freshness, artifact metadata,
  condition-specific evidence types and payloads, and cross-record linkage.
- `Test-ChatpadRuntimeObservationContract` separately controls runtime
  evaluation. Missing evidence remains `BLOCKED`; malformed provenance fails;
  synthetic, sample, planned, and unknown sources remain `BLOCKED`; only a
  live record with a matching existing artifact size and SHA-256 can reach an
  evaluated runtime result.
- No fixture is represented as live. Structurally valid synthetic records do
  not authorize continuation.
- The six former off-ledger harness assertions are ordinary one-assertion
  fixture records in the `harness-self-test` category.
- The suite and manifest validator independently enumerate records,
  assertions, and categories. The historical 140 fixture records / 915
  fixture assertions plus six separate harness assertions / 921 reported
  assertions discrepancy is retained only as history and a negative fixture.
- Lifecycle, committed sample, malformed-input, target, rollback, package,
  signing, host, evidence, install-blocker, WPP, event-log, reconciliation,
  stop-linkage, and prior direct-probe contracts remain passing.

## Safety and blocker

- Executable exact-instance binding operations: `0`.
- Executable exact-instance restoration operations: `0`.
- Broad approved install operations: `0`.
- Broad approved rollback operations: `0`.
- No production source/header, INF, project, solution, protocol, transport,
  binary, package, credential, signing material, or `legacy/` path changed.
- No signing, CAT generation, package creation, staging, installation,
  binding, loading, rollback, Windows mutation, tracing, event-log export,
  live device query, hardware access, protocol traffic, input injection, or
  reboot occurred.
- **Blocker:** exact-instance binding and restoration are not implemented.
  The next task is an independent read-only audit of both implementation
  commits and the evidence-finalization commit.
