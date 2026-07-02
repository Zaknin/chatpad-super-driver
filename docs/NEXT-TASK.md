# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-manifest-validator-integral-count-remediation`.
- Required starting point: the evidence-finalization commit containing this
  file, subject `docs: finalize integral-count manifest evidence`.
- Required implementation commit:
  `72abd0695e34e27d075cb10fdf5b381418bcce1d`.
- Required ancestry:
  `88e3cbba3a64828322b7c703765e6b1e2369f698` ->
  `eef5b9c151c884eefaa0157e32446e481db73bb4` ->
  `f4e98e5719230bd40c7096d2a48efb788eeb5a7d` ->
  `b4cfe8473500073bebacc807230d4f1af2f5e09e` ->
  `72abd0695e34e27d075cb10fdf5b381418bcce1d` ->
  finalization commit containing this file.
- Framework status: `PASS`.
- Live installation readiness: `BLOCKED`.
- Blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Suite: 304 first-class fixture records and 1,724 assertions.
- Accounting: record/category counts `304/304`; record/category assertions
  `1,724/1,724`; unassigned, off-ledger, duplicate-counted, and reconciliation
  defects `0`.
- Integral-count regression: isolated corrupt manifests for F1-F5 and the
  malformed-count matrix fail or pass according to the documented exact integer
  contract. The self-consistent `assertion_count = 1.5` bypass fails with an
  explicit `INVALID_INTEGER_COUNT.FRACTIONAL` defect.
- Empty-subset regression: omitted harness and accounting records fail through
  controlled accounting defects; uncontrolled exception count `0`;
  `PropertyNotFoundException` `false`.
- Generator provenance: the manifest generator derives the checked-out local
  branch from Git and rejects detached HEAD.
- Runtime observers: missing-provenance PASS `0`; synthetic-source PASS `0`;
  unsupported runtime-observer PASS `0`; live observations `0`.
- Stop linkage: 20 conditions, 20 unique IDs, five runtime-observer links,
  and zero unlinked, unknown, malformed, or nested-array acceptance defects.
- PowerShell: 41 `.ps1`, 2 `.psm1`, 43 total; all parse with zero errors.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of the integral-count manifest
validator remediation, generator branch provenance correction, regenerated
manifest, and evidence-finalization commit.

The audit must directly:

- verify the exact branch, full HEAD, direct parent, upstream equality, and
  clean worktree;
- confirm implementation commit
  `72abd0695e34e27d075cb10fdf5b381418bcce1d` contains only the validator
  count-validation correction and generator dynamic-branch correction after
  starting commit `b4cfe8473500073bebacc807230d4f1af2f5e09e`;
- corrupt only isolated manifest copies, never tracked evidence;
- reproduce F1 through F5, including the self-consistent coerced-total bypass
  attempt for `assertion_count = 1.5`;
- run the malformed-count matrix for missing, null, string, numeric-looking
  string, Boolean, array, object, negative, fractional, and oversized values;
- remove all `harness-self-test` records, one `harness-self-test` record, and
  all `assertion-accounting-negative` records;
- verify all malformed and empty-subset cases fail through controlled defects,
  with zero uncontrolled exceptions and no `PropertyNotFoundException`;
- independently prove generator output uses the checked-out local branch, not
  an upstream branch, cached document branch, or hard-coded string;
- verify detached HEAD generation fails clearly and does not record a stale
  branch;
- independently sum every fixture record and category in the canonical suite;
- prove record and category sums equal 304 records and 1,724 assertions;
- preserve runtime-observer missing-provenance, synthetic-source, provenance,
  stop-linkage, lifecycle, and malformed-input contracts;
- confirm live readiness remains `BLOCKED`.

## Preconditions

1. Verify the exact branch, full HEAD, direct parent, upstream equality,
   ahead/behind `0/0`, and clean worktree.
2. Rehash the accepted baseline manifest, both frozen SYS files, the finalized
   readiness manifest, and all manifest entries.
3. Inspect the manifest validator and generator before executing only offline
   synthetic or isolated-corruption modes.

## Safety restrictions

- Audit only. Do not modify or regenerate repository evidence.
- Do not sign, package, stage, install, bind, load, remove, enable, disable,
  or roll back a driver.
- Do not mutate Windows, boot/security/service/registry/device state; start a
  trace; export event logs; query or open a live device; access hardware;
  generate protocol traffic; inject input; or reboot.
- Do not modify `legacy/`.

## Acceptance criteria

- Canonical manifest validation passes.
- F1-F4 and the malformed-count matrix fail with explicit invalid integer
  defects; F5 `1.0` behavior matches the documented integer-valued numeric
  rule.
- The self-consistent fractional bypass attempt does not pass.
- Corrupted-copy omitted-record cases produce controlled accounting failures.
- Uncontrolled exception and `PropertyNotFoundException` counts are zero.
- Generator branch identity follows the checked-out local branch and detached
  HEAD behavior is controlled.
- Record count equals category record sum.
- Record assertion sum equals category assertion sum and reported total.
- Accounting, observer provenance, manifest, lifecycle, totality, and
  stop-linkage results pass.
- Finalization executable changes and prohibited operations are zero.
- Live readiness remains `BLOCKED` with `BLOCKED_NOT_IMPLEMENTED`.

## Inspect first

- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `docs/RUNTIME-BRINGUP-READINESS.md`
