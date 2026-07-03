# Next Task

## Objective

Perform an independent read-only audit of the offline exact-instance contract
remediation. Do not implement the native SetupAPI/Newdev adapter.

## Required starting point

- Branch: `feature/runtime-bringup-exact-instance-contract-remediation`
- Starting commit: the finalization commit whose parents include
  `a969745f589a55243ca9f9e964a45d7104f9a5e8` and
  `c3c0930db1326d56808879f12a9e8951f0051e80`, followed by
  `fd70e9779056b336b43d09be97e686fa61ed5514`
- Verify a clean tree, configured upstream, local/remote equality, exact
  ancestry from `9b380ef6e070311d682866a5f130b51a44f8485a`, and manifest validity.

## Audit focus

1. Reproduce T26/T27 restoration-identity tampering with all caller-accessible
   hashes recomputed; require zero restoration calls.
2. Reproduce coordinated synthetic-to-live evidence spoofing; require
   `UNTRUSTED_EVIDENCE_ORIGIN`.
3. Supply every prior public real-execution gate input; require
   `LIVE_ADAPTER_NOT_IMPLEMENTED`.
4. Independently verify the four-direction Windows PowerShell/PowerShell 7
   canonical plan and snapshot matrix.
5. Test duplicate names at root and nested depths, including equal, different,
   and case-variant names.
6. Delete required plan/snapshot/driver fields, recompute hashes, and require
   controlled schema failure.
7. Exercise the complete hidden-Unicode instance-ID matrix before adapter
   access.
8. Run complete PSScriptAnalyzer coverage over all 45 `.ps1` and six `.psm1`
   files; require zero errors and zero tool failures while reporting warnings
   and information findings.
9. Verify 343 records/1,879 assertions, exact-instance 39/155, unique IDs,
   zero off-ledger/duplicate-counted assertions, and zero live/Windows
   operations.

## Safety restrictions

- Read-only audit only.
- Create malformed data only in isolated temporary locations.
- No native adapter implementation, build, signing, CAT generation,
  packaging, staging, driver-store mutation, installation, binding, loading,
  restoration, restart, reboot, device query, hardware access, Windows
  mutation, production source/INF/frozen binary change, or `legacy/` change.

## Acceptance criteria

- Every audited fail-open path is controlled and fail-closed.
- Canonical hashes are identical across all four runtime directions.
- T1-T39 and full readiness remain PASS.
- Readiness remains blocked by both the pending audit gate and the separately
  unimplemented live adapter capability.
- Audit output makes no live-readiness or hardware-observation claim.

## Inspect first

- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- latest `docs/WORKLOG.md` entry
- `tools/ExactInstance/ChatpadExactInstance.Contracts.psm1`
- `tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1`
- `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
- `tools/Test-ChatpadExactInstanceCrossRuntime.ps1`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
