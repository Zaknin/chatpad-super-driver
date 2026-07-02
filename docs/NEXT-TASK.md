# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-stop-linkage-final-remediation`.
- Required starting point: the evidence-finalization commit containing this
  file, subject `docs: finalize stop-linkage readiness evidence`.
- Required direct parent:
  `a810d8ba3438a08cfa4742e53be61f64be5aa58e`.
- Required prior finalization:
  `30da5003aba75ef0f079c9a8c2c90df3768601d5`.
- Framework status: `PASS`.
- Live installation readiness: `BLOCKED`.
- Blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Suite: 140 fixtures, 921 assertions, 15 validators, 180 malformed-input
  cases, and zero uncontrolled, PropertyNotFound, StrictMode, lifecycle,
  missing-start, linkage, or nested-array acceptance defects.
- Stop linkage: 20 conditions, 20 unique IDs, five runtime-observer links,
  unlinked `0`, unknown IDs `0`, malformed linkage `0`.
- PowerShell: 41 `.ps1`, 2 `.psm1`, 43 total; all parse with zero errors.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of the stop-linkage implementation and
evidence-finalization commits.

The audit must directly:

- inspect the runtime type and nesting shape of every linkage value;
- verify canonical flat repository-relative path arrays;
- rerun the exact double-wrapped and three-level nested-array rejection probes;
- verify all five runtime-observer IDs link only to
  `tools/Test-ChatpadRuntimeObservation.ps1`;
- verify missing, scalar, empty, null, non-string, traversal, wildcard,
  nonexistent, duplicate, unknown, and misclassified linkage rejection;
- confirm the finalization commit changed no executable logic;
- verify current-state and next-task documentation;
- confirm framework `PASS`, live readiness `BLOCKED`, and blocker
  `BLOCKED_NOT_IMPLEMENTED`.

## Preconditions

1. Verify exact branch, full HEAD, direct parent, subject, upstream equality,
   ahead/behind `0/0`, and clean worktree.
2. Supply the full finalization HEAD and implementation commit
   `a810d8ba3438a08cfa4742e53be61f64be5aa58e` to repository identity
   validation.
3. Rehash the accepted baseline manifest and both frozen SYS files.
4. Verify the finalization diff changes no `.ps1`, `.psm1`, executable
   schema, canonical policy data, tests, validators, generators, or manifest
   validator.

## Safety restrictions

- Audit only. Do not modify or regenerate repository evidence.
- Do not sign, package, stage, install, bind, load, remove, enable, disable,
  or roll back a driver.
- Do not mutate Windows, boot/security/service/registry/device state; start a
  trace; export event logs; query or open a live device; access hardware;
  generate protocol traffic; inject input; or reboot.
- Do not modify `legacy/`.

## Acceptance criteria

- Canonical register result is `PASS` / `STOP_LINKAGE_VALID`.
- Stop-condition count and unique count are both 20.
- Runtime-observer linkage count is five; unlinked, unknown, and malformed
  counts are zero.
- Nested-array acceptance and malformed-linkage exception counts are zero.
- All five runtime-only observations remain blocked without runtime evidence.
- Full suite and manifest validation pass with exact derived totals.
- No executable finalization changes or prohibited operations occurred.
- Live readiness remains `BLOCKED`.

## Inspect first

- `docs/evidence/runtime-bringup-stop-conditions.json`
- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeObservation.ps1`
- `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `docs/RUNTIME-BRINGUP-READINESS.md`
