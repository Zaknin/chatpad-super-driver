# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-readiness-final-contract-remediation`.
- Required starting point for audit: the finalization commit containing this
  file, with subject `docs: finalize final-contract readiness evidence`.
- Required direct parent:
  `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6`.
- Required parent chain:
  `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`
  -> `66de13033e4ba5f67465829c25c0e6a158516044`
  -> `7689d2cca57c485d8c0569bdcbec58e400621b20`
  -> `bb4c06cc87150b944d04ae2135ea58b8218c5dc8`
  -> `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6`
  -> finalization commit.
- Current final-contract implementation:
  `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6`.
- Accepted offline baseline:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Runtime framework status: `PASS`.
- Authoritative live installation readiness: `BLOCKED`.
- Exact blocker: `BLOCKED_NOT_IMPLEMENTED`.
- Offline suite: 118 fixtures, 801 assertions, 15 public validators, 180
  malformed-input matrix cases, uncontrolled exceptions `0`,
  `PropertyNotFoundException` count `0`, StrictMode exception count `0`,
  invalid lifecycle acceptance count `0`, missing-start-timestamp acceptance
  count `0`.
- Committed sample evidence: structural validation `PASS`; semantic
  validation `PASS`.
- PowerShell inventory: 41 tracked `.ps1`, 2 tracked `.psm1`, 43 total; all
  43 parsed; AST parse errors `0`.
- Driver state remains unsigned, unpackaged, unstaged, uninstalled, unloaded,
  untraced, unqueried, and unexecuted.

## Next recommended objective

Perform an independent, read-only audit of both final-contract remediation
commits.

The audit must directly:

- rerun the executed-operation missing-start-timestamp probe;
- validate the committed sample structurally and semantically;
- independently enumerate and parse all 43 tracked PowerShell files;
- verify lifecycle symmetry for planned, blocked, skipped_authorization,
  executed, failed, rolled_back, and restored operations;
- verify malformed-input totality across all 15 public validators and 180
  malformed-input cases;
- verify no executable finalization changes;
- confirm live readiness remains `BLOCKED` with blocker
  `BLOCKED_NOT_IMPLEMENTED`.

## Preconditions

1. Verify exact branch, full HEAD, direct parent, subject, upstream equality,
   ahead/behind `0/0`, and clean index/worktree.
2. Supply the full finalization HEAD as
   `-CurrentReadinessFinalizationCommit` and
   `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6` as
   `-CurrentReadinessImplementationCommit` when running repository identity
   validation.
3. Rehash the accepted baseline manifest and both frozen SYS files.
4. Inspect `bb4c06cc87150b944d04ae2135ea58b8218c5dc8..HEAD` and verify there
   are exactly two final-contract remediation commits.
5. Inspect the second/finalization commit's name-only diff and fail the audit
   if it modifies `.ps1`, `.psm1`, executable schemas, test logic, validator
   logic, the manifest generator, the manifest validator, or the committed
   sample evidence used by tests.

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

- The exact executed-operation missing-start-timestamp probe rejects with
  `OPERATION_LIFECYCLE_INVALID`, stop condition
  `command-differs-from-approved-plan`, and reason
  `start-timestamp-missing`.
- The committed `docs/evidence/runtime-bringup-sample-evidence.json` passes
  structural Draft 2020-12 validation and semantic validation from its actual
  repository path.
- Independent Git-tracked PowerShell enumeration reports 41 `.ps1`, 2 `.psm1`,
  43 total; all 43 parse with zero AST errors and no exclusions.
- Lifecycle validation rejects malformed planned, blocked,
  skipped_authorization, executed, failed, rolled_back, and restored records
  with controlled results and valid stop-condition IDs.
- Malformed inputs across all public readiness validators produce controlled
  result records, never unhandled exceptions.
- The second/finalization commit changes only generated evidence and docs.
- Manifest records PSScriptAnalyzer as `SKIPPED_UNAVAILABLE` when unavailable.
- No prohibited operation or live Windows/device action occurred.
- Authoritative live-readiness remains `BLOCKED`; any unsupported PASS claim is
  an audit failure.

## Inspect first

- `docs/RUNTIME-BRINGUP-READINESS.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `docs/evidence/runtime-bringup-evidence-schema-v1.json`
- `docs/evidence/runtime-bringup-sample-evidence.json`
- `docs/evidence/runtime-bringup-stop-conditions.json`
- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `tools/Test-ChatpadRuntimeRepositoryIdentity.ps1`
