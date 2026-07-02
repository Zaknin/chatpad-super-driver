# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-observer-provenance-accounting-remediation`.
- Required starting point: the evidence-finalization commit containing this
  file, subject `docs: finalize observer provenance and accounting evidence`.
- Required direct parent:
  `ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10`.
- Required implementation chain:
  `b6b62a974bf7705e4cabc0bc98ffa44bf0718ddb` →
  `ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10`.
- Prior finalization:
  `9b5c8f3b4ac8c0dc0453da693266a82fea636ec0`.
- Framework status: `PASS`.
- Live installation readiness: `BLOCKED`.
- Blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Suite: 304 first-class fixture records and 1,724 assertions.
- Accounting: record/category counts `304/304`; record/category assertions
  `1,724/1,724`; unassigned, off-ledger, duplicate-counted, and reconciliation
  defects `0`.
- Runtime observers: missing-provenance PASS `0`; synthetic-source PASS `0`;
  unsupported runtime-observer PASS `0`; live observations `0`.
- Stop linkage: 20 conditions, 20 unique IDs, five runtime-observer links,
  and zero unlinked, unknown, malformed, or nested-array acceptance defects.
- PowerShell: 41 `.ps1`, 2 `.psm1`, 43 total; all parse with zero errors.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of both runtime-observer provenance and
assertion-accounting implementation commits and the evidence-finalization
commit.

The audit must directly:

- test all five runtime-observer IDs with `evidence_available=true` and missing
  provenance;
- test all five IDs with `source_classification=synthetic`;
- inspect session, host, producer, observer path, timestamps, freshness,
  artifact identity/path/size/SHA-256, collection result, evidence type, and
  condition-specific payload enforcement;
- confirm structural synthetic PASS is separate from runtime evaluation and
  cannot authorize continuation;
- confirm no live observation is claimed or performed;
- independently sum every fixture record assertion and every category;
- prove both record and category sums equal the reported totals;
- verify no assertion is off-ledger, unassigned, or duplicate-counted;
- preserve the flat stop-linkage and nested-array rejection contracts;
- verify the finalization commit changes no executable file;
- confirm live readiness remains `BLOCKED`.

## Preconditions

1. Verify the exact branch, full HEAD, direct parent, upstream equality,
   ahead/behind `0/0`, and clean worktree.
2. Supply the full finalization HEAD and final implementation commit
   `ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10` to repository identity
   validation; verify its direct parent is
   `b6b62a974bf7705e4cabc0bc98ffa44bf0718ddb`.
3. Rehash the accepted baseline manifest, both frozen SYS files, the finalized
   manifest, and all manifest entries.
4. Inspect complete call paths before executing only offline synthetic modes.

## Safety restrictions

- Audit only. Do not modify or regenerate repository evidence.
- Do not sign, package, stage, install, bind, load, remove, enable, disable,
  or roll back a driver.
- Do not mutate Windows, boot/security/service/registry/device state; start a
  trace; export event logs; query or open a live device; access hardware;
  generate protocol traffic; inject input; or reboot.
- Do not modify `legacy/`.

## Acceptance criteria

- All five missing-provenance probes produce zero PASS results.
- All five synthetic-source probes produce zero PASS results.
- Unsupported runtime-observer PASS and live-observation counts are zero.
- Record count equals category record sum.
- Record assertion sum equals category assertion sum and reported total.
- Accounting, observer provenance, manifest, lifecycle, totality, and
  stop-linkage results pass.
- Finalization executable changes and prohibited operations are zero.
- Live readiness remains `BLOCKED` with `BLOCKED_NOT_IMPLEMENTED`.

## Inspect first

- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeObservation.ps1`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `docs/RUNTIME-BRINGUP-READINESS.md`
