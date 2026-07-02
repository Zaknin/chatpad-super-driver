# Next Task

## Exact current state

- Required branch: `feature/runtime-bringup-readiness-remediation`.
- Required starting commit: the final commit containing this file, with subject
  `test: remediate controlled runtime bring-up readiness`.
- Required direct parent: `b9990d287bee6916cc5bb4e6b7f194ee579c7fbb`.
- Accepted offline baseline:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Runtime readiness status: `PASS WITH BLOCKER`; exact-instance binding and
  exact-instance restoration are intentionally not implemented.
- Offline suite: 177 fixtures, 203 assertions, 21 command-injection fixtures.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of the final remediation commit. Verify
dual repository identity, structured argument boundaries and injection
resistance, explicit exact-instance blocking, effective package semantics,
signing/host/evidence contracts, Draft 2020-12 schema enforcement,
stop-condition linkage, synthetic totals, manifest truthfulness, and complete
absence of prohibited operations.

## Preconditions

1. Verify the exact branch, full HEAD, direct parent, subject, upstream
   equality, ahead/behind `0/0`, and clean index/worktree.
2. Supply that full HEAD as `-ApprovedReadinessCommit` when running the
   repository identity validator; do not infer or abbreviate it.
3. Rehash the accepted baseline manifest and both frozen SYS files.
4. Inspect the complete `b9990d2..HEAD` diff and the readiness manifest without
   regenerating evidence.

## Safety restrictions

- Audit only. Do not edit files or regenerate evidence.
- Do not create/import/export certificates or keys; sign, package, stage,
  install, bind, load, remove, or roll back a driver.
- Do not mutate Windows, boot/security/service/registry/device state, start a
  trace, export/clear event logs, query/open a live device, send a request,
  access hardware, generate protocol traffic, inject input, or reboot.
- Do not modify `legacy/`.

## Acceptance criteria

- Repository identity independently proves the accepted baseline and exact
  approved readiness revision.
- Hostile values cannot add arguments or operations, and no rendered display
  text is executable evidence.
- Broad package staging and optional rescan remain separately classified and
  blocked; install/rollback cannot pass without an implemented exact-instance
  mechanism.
- All validator fixtures, schema/sample checks, stop-condition links, manifest
  counts/hashes/states/containment, and prohibited-action scans reproduce.
- Any unsupported PASS claim is reported as an audit failure.

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
