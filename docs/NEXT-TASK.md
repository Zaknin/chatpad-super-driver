# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-readiness-validator-totality-remediation`.
- Required starting point for audit: the finalization commit containing this
  file, with subject `docs: finalize validator-totality readiness evidence`.
- Required direct parent:
  `7689d2cca57c485d8c0569bdcbec58e400621b20`.
- Required parent chain:
  `b9990d287bee6916cc5bb4e6b7f194ee579c7fbb`
  -> `0d7f5677c214ebd2081ba40a169e0fc6d1efc0ea`
  -> `2bb08fee77125f6b5bed2774c085ce57fe192752`
  -> `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`
  -> `66de13033e4ba5f67465829c25c0e6a158516044`
  -> `7689d2cca57c485d8c0569bdcbec58e400621b20`
  -> finalization commit.
- Current validator-totality implementation:
  `7689d2cca57c485d8c0569bdcbec58e400621b20`.
- Accepted offline baseline:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Runtime framework status: `PASS`.
- Authoritative live installation readiness: `BLOCKED`.
- Exact blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Offline suite: 75 fixtures, 467 assertions, 90 malformed-input matrix cases,
  uncontrolled exceptions `0`, `PropertyNotFoundException` count `0`,
  StrictMode exception count `0`, invalid transition acceptance count `0`.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of both validator-totality remediation
commits. Directly rerun missing-field target and rollback probes, test malformed
inputs against every public readiness validator, verify lifecycle and semantic
transition enforcement, verify no uncontrolled exception, verify no executable
finalization changes, and confirm live readiness remains `BLOCKED`.

## Preconditions

1. Verify exact branch, full HEAD, direct parent, subject, upstream equality,
   ahead/behind `0/0`, and clean index/worktree.
2. Supply the full finalization HEAD as
   `-CurrentReadinessFinalizationCommit` and the full implementation commit
   `7689d2cca57c485d8c0569bdcbec58e400621b20` as
   `-CurrentReadinessImplementationCommit` when running repository identity
   validation.
3. Rehash the accepted baseline manifest and both frozen SYS files.
4. Inspect `66de13033e4ba5f67465829c25c0e6a158516044..HEAD` and verify there
   are exactly two validator-totality remediation commits.
5. Inspect the second commit's name-only diff and fail the audit if it modifies
   `.ps1`, `.psm1`, executable schemas, test logic, validator logic, the
   manifest generator, or the manifest validator.

## Safety restrictions

- Audit only. Do not edit files or regenerate evidence.
- Do not create/import/export/delete certificates or keys; sign; generate CATs;
  package; stage; install; bind; load; remove; enable; disable; or roll back a
  driver.
- Do not mutate Windows, boot/security/service/registry/device state; start a
  trace; export or clear event logs; enumerate/open a live device; send a
  request; access hardware; generate protocol traffic; inject input; or reboot.
- Do not modify `legacy/`.

## Acceptance criteria

- Missing `candidate_set_id` and missing `rollback_operations` reject with
  controlled machine-readable results and expected stop-condition IDs.
- Malformed inputs across all public readiness validators produce controlled
  result records, never unhandled exceptions.
- Lifecycle validation rejects executed/failed without result/timestamps,
  malformed result objects, rolled-back without rollback evidence, and restored
  without final reconciliation.
- Semantic evidence validation rejects invalid rollback references, cross-host
  or cross-session rollback operations, unresolved dependencies, duplicates,
  synthetic artifacts in live sessions, and restored states with planned work.
- The second/finalization commit changes only generated evidence and docs.
- Manifest records PSScriptAnalyzer as `SKIPPED_UNAVAILABLE` when unavailable.
- No prohibited operation or live Windows/device action occurred.
- Authoritative live-readiness remains `BLOCKED`; any unsupported PASS claim is
  an audit failure.

## Inspect first

- `docs/RUNTIME-BRINGUP-READINESS.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `docs/evidence/runtime-bringup-evidence-schema-v1.json`
- `docs/evidence/runtime-bringup-stop-conditions.json`
- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeRepositoryIdentity.ps1`
- `tools/Test-ChatpadRuntimeTargetSelection.ps1`
- `tools/Test-ChatpadRollbackReadiness.ps1`
- `tools/Test-ChatpadRuntimeObservation.ps1`
