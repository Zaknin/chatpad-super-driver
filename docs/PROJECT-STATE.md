# Project State

*Last updated: 2026-07-02 (stop-linkage final remediation)*

## Current state

- **Branch:** `feature/runtime-bringup-stop-linkage-final-remediation`.
- **Starting commit:** `30da5003aba75ef0f079c9a8c2c90df3768601d5`.
- **Direct parent at start:**
  `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6`.
- **Implementation commit:**
  `a810d8ba3438a08cfa4742e53be61f64be5aa58e`, subject
  `Harden stop-condition linkage contracts`.
- **Expected evidence-finalization commit:** the commit containing this file,
  subject `docs: finalize stop-linkage readiness evidence`.
- **Accepted offline baseline:**
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256
  `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.
- **Frozen binaries:** Debug 68,096 bytes,
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`;
  Release 40,960 bytes,
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`.
- **Offline suite:** framework `PASS`; live readiness `BLOCKED`; blocker
  `BLOCKED_NOT_IMPLEMENTED`; 140 fixtures; 921 assertions; 15 public
  validators; 180 malformed-input cases; all exception, unsupported
  transition, and missing-start acceptance counts zero.
- **Stop linkage:** 20 conditions; 20 unique IDs; five runtime-observer links;
  unlinked `0`; unknown IDs `0`; malformed linkage values `0`; nested-array
  acceptances `0`; malformed-linkage exceptions `0`.
- **PowerShell inventory:** 41 `.ps1`, 2 `.psm1`, 43 total; all 43 parse; AST
  errors `0`.
- **PSScriptAnalyzer:** `SKIPPED_UNAVAILABLE`.

## Implementation truth

- Linkage values are validated from their direct property value as
  one-dimensional arrays. The validator never silently flattens nested input.
- Every linkage path must be a nonempty normalized repository-relative `.ps1`
  path, without traversal or wildcards, contained in the repository, present
  on disk, and unique after case-insensitive normalization.
- The five runtime-only stop conditions link exactly to
  `tools/Test-ChatpadRuntimeObservation.ps1` and remain blocked when runtime
  evidence is unavailable.
- Lifecycle, committed sample, collection-shape, malformed-input, package,
  target, rollback, signing, host, evidence, WPP, event-log, reconciliation,
  runtime-observer, and install-blocker contracts remain passing.
- Executable exact-instance binding operations, executable restoration
  operations, broad approved install operations, and broad approved rollback
  operations remain zero.

## Safety and blocker

- No production source/header, INF, project, solution, protocol, transport,
  binary, package, credential, signing material, or `legacy/` path changed.
- No signing, CAT generation, package creation, staging, installation,
  binding, loading, rollback, Windows mutation, tracing, event-log export,
  live device query, hardware access, protocol traffic, input injection, or
  reboot occurred.
- **Blocker:** exact-instance binding and restoration are not implemented.
  The next task is an independent read-only audit of both stop-linkage
  remediation commits.
