# Project State

*Last updated: 2026-07-03 (manifest count validation and branch provenance remediation)*

## Current state

- **Branch:**
  `feature/runtime-bringup-manifest-validator-integral-count-remediation`.
- **Starting commit:** `b4cfe8473500073bebacc807230d4f1af2f5e09e`.
- **Corrective implementation commit:**
  `72abd0695e34e27d075cb10fdf5b381418bcce1d`, subject
  `Fix manifest count validation and branch provenance`.
- **Expected evidence-finalization commit:** the commit containing this file,
  subject `docs: finalize integral-count manifest evidence`.
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
- **Manifest-validator regression:** isolated corrupted-copy cases for all
  omitted harness records, one omitted harness record, all omitted
  `assertion-accounting-negative` records, fractional counts, oversized
  counts, and malformed count types fail through controlled validation or
  accounting defects. The self-consistent `assertion_count = 1.5` bypass is
  closed. Uncontrolled exception count `0`; `PropertyNotFoundException`
  detected `false`.
- **Ignored evidence artifact:**
  `artifacts/logs/runtime-bringup-manifest-validator-integral-count-evidence-post-implementation-72abd06.json`,
  50,298 bytes,
  `8E9514481A3D4CA0A4E2848B05E9B68184D5A19FC000B202C5BF12F0BE25343E`,
  JSON valid, UTF-8 without BOM.
- **Runtime observers:** five missing-provenance and five synthetic-source
  probes produce zero runtime PASS results; unsupported runtime-observer PASS
  count `0`; live observations performed `0`.
- **Stop linkage:** 20 conditions; 20 unique IDs; five runtime-observer links;
  unlinked, unknown, malformed, and nested-array acceptance counts all `0`.
- **PowerShell inventory:** 41 `.ps1`, 2 `.psm1`, 43 total; AST errors `0`.
- **PSScriptAnalyzer:** `SKIPPED_UNAVAILABLE`.

## Implementation truth

- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1` keeps StrictMode
  enabled and validates every count-like manifest and suite field before any
  integer conversion or aggregate arithmetic.
- The exact integer contract accepts only JSON numeric scalars in signed
  64-bit range with no nonzero fractional component. Numeric-looking strings,
  Boolean values, nulls, arrays, objects, missing properties, negative counts,
  fractional values such as `1.5` or `0.1`, and oversized values are controlled
  defects. Integer-valued numeric representations such as `1.0` are accepted
  deliberately and documented in the defect reason text.
- The new corruption regression mode copies manifest inputs into a temporary
  isolated Git repository under the user temp directory, mutates only that
  copy, runs the validator as a child process, and removes the temporary root.
- The canonical readiness manifest remains generated evidence. It is not
  manually edited or self-hashed. Its generator derives the checked-out local
  branch with Git symbolic-ref and rejects detached HEAD instead of recording a
  hard-coded branch.
- Runtime-observer provenance, assertion-accounting, lifecycle, committed
  sample, malformed-input, target, rollback, package, signing, host, evidence,
  install-blocker, WPP, event-log, reconciliation, stop-linkage, and prior
  direct-probe contracts remain passing.

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
  The next task is an independent read-only audit of this integral-count
  manifest-validator remediation, dynamic branch provenance, and the
  evidence-finalization commit.
