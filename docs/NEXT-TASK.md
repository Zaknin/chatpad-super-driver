# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-readiness-enforcement-remediation`.
- Required starting point for audit: the finalization commit containing this
  file, with subject `docs: finalize runtime bring-up enforcement evidence`.
- Required direct parent:
  `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`.
- Required parent chain:
  `b9990d287bee6916cc5bb4e6b7f194ee579c7fbb`
  -> `0d7f5677c214ebd2081ba40a169e0fc6d1efc0ea`
  -> `2bb08fee77125f6b5bed2774c085ce57fe192752`
  -> `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`
  -> finalization commit.
- Prior readiness implementation:
  `0d7f5677c214ebd2081ba40a169e0fc6d1efc0ea`.
- Prior readiness finalization:
  `2bb08fee77125f6b5bed2774c085ce57fe192752`.
- Current remediation implementation:
  `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`.
- Accepted offline baseline:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Runtime framework status: `PASS`.
- Authoritative live installation readiness: `BLOCKED`.
- Exact blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Offline suite: 31 fixtures, 158 assertions.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of both enforcement-remediation
commits. Rerun every direct unsupported-PASS probe, verify expected-failure
reasons rather than exception side effects, verify the finalization commit
changed no executable file, and confirm the authoritative live-readiness status
remains `BLOCKED`.

## Preconditions

1. Verify exact branch, full HEAD, direct parent, subject, upstream equality,
   ahead/behind `0/0`, and clean index/worktree.
2. Supply the full finalization HEAD as
   `-CurrentReadinessFinalizationCommit` and the full implementation commit
   `f0f9bf7e196a6f7cfe9b391cc4001b593016d310` as
   `-CurrentReadinessImplementationCommit` when running repository identity
   validation.
3. Rehash the accepted baseline manifest and both frozen SYS files.
4. Inspect `2bb08fee77125f6b5bed2774c085ce57fe192752..HEAD` and verify there
   are exactly two remediation commits.
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

- Repository identity independently proves the frozen baseline, prior
  implementation/finalization, current implementation/finalization, current
  HEAD, and branch.
- Harness fixtures fail for intended machine-readable reasons, never unrelated
  exceptions.
- Empty-operation and Boolean-only install plans remain blocked and never PASS.
- The official synthetic `Show-ChatpadInstallPlan.ps1` invocation returns
  `BLOCKED` / `BLOCKED_NOT_IMPLEMENTED` without throwing.
- Effective INF semantic fixtures reject token-only package evidence.
- All target, driver-state, rollback, signing, host, evidence-directory, WPP,
  event-log, reconciliation, Draft 2020-12 structural schema, semantic schema,
  stop-condition, and manifest truthfulness checks reproduce.
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
- `tools/Show-ChatpadInstallPlan.ps1`
- `tools/Show-ChatpadRollbackPlan.ps1`
- `tools/Test-ChatpadRuntimeObservation.ps1`
