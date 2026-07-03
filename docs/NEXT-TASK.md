# Next Task

## Exact current state

- Required branch:
  `feature/runtime-bringup-exact-instance-binding-restoration`.
- Required implementation commit:
  `0060cd91be7d460f1a4141f6bf893bd56b32bf35`.
- Required corrective implementation commit:
  `fdcd9448a3dc172213c07928af45d2e68fd0197a`.
- Required starting point: the evidence-finalization commit containing this
  file, subject `docs: finalize exact-instance framework evidence`.
- Required ancestry:
  `b9374d8a98392de67824aac4235021b5bd90d284` ->
  `0060cd91be7d460f1a4141f6bf893bd56b32bf35` ->
  `fdcd9448a3dc172213c07928af45d2e68fd0197a` ->
  finalization commit.
- Exact-instance suite: `PASS`, 25 records, 99 assertions.
- Readiness suite: framework `PASS`, 329 records, 1,823 assertions.
- Live installation readiness: `BLOCKED`.
- Blocker: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Live binding, restoration, restart, observation, broad-success, and Windows
  mutation counters are all zero.

## Next recommended objective

Perform an independent, read-only audit of the offline exact-instance binding
and restoration implementation, schemas, generated manifest, evidence, and
finalization commit.

The audit must directly:

- verify exact branch, HEAD, direct parent, ancestry, clean worktree, upstream,
  ahead/behind `0/0`, and live remote equality;
- confirm the implementation commit contains only the declared executable and
  schema paths and the finalization commit contains no executable changes;
- independently inspect the exact-instance normalization, path, plan, snapshot,
  evidence, authorization, adapter, and state-machine contracts;
- rerun T1-T25 under Windows PowerShell and PowerShell 7;
- independently prove same-hardware-ID and same-container sibling isolation
  from call traces and before/after bytes;
- verify partial/wildcard rejection, drift, target/restoration absence and
  ambiguity, postcondition failure, exact restoration, replay, expiry, hash and
  operation-ID mismatch, restart/reboot behavior, broad-operation rejection,
  evidence spoof rejection, and adapter-exception uncertainty;
- enumerate all 50 allowed transition edges and verify prohibited transitions
  remain rejected;
- inspect the production static broad-operation guard and confirm negative-test
  references cannot become execution paths;
- verify deterministic plan/snapshot hashes across runtimes and repeated runs;
- independently reconcile 329 records and 1,823 assertions, including the
  exact 25/99 category increment;
- validate every manifest entry, JSON file, UTF-8 BOM state, ignored evidence
  identity, and zero live/Windows-mutation counters;
- confirm live readiness remains blocked and no independent-audit pass is
  claimed by the implementation branch.

## Preconditions

1. Rehash the accepted baseline manifest, frozen Debug/Release SYS files,
   exact-instance evidence, full-readiness evidence, and readiness manifest.
2. Inspect the implementation and finalization diffs before executing tests.
3. Execute only pure, synthetic, or isolated-copy validation.
4. Preserve the tracked readiness manifest; corrupt only isolated copies.

## Safety restrictions

- Audit only. Do not implement the native Windows adapter.
- Do not build, sign, package, stage, install, bind, load, restore, restart, or
  reboot a driver or device.
- Do not query a live device or mutate the driver store, registry, services,
  boot/security state, tracing, event logs, hardware, protocols, or input.
- Do not modify production source, INF, project/solution, frozen binaries, or
  `legacy/`.

## Acceptance criteria

- T1-T25 and both PowerShell runtimes pass.
- Critical call traces identify only the authorized synthetic instance.
- All schema, state, replay, evidence-provenance, static broad-action,
  accounting, manifest, AST, and repository-safety checks pass.
- Finalization executable change count is zero.
- Live readiness remains `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Every live and Windows-mutation counter remains zero.

## Inspect first

- `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
- `tools/ExactInstance/ChatpadExactInstance.Contracts.psm1`
- `tools/ExactInstance/ChatpadExactInstance.FakeAdapter.psm1`
- `tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1`
- `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
- `tools/Invoke-ChatpadExactInstanceBindingRestoration.ps1`
- `tools/Test-ChatpadExactInstanceBindingRestoration.ps1`
- `docs/evidence/exact-instance-operation-plan-schema-v1.json`
- `docs/evidence/exact-instance-operation-evidence-schema-v1.json`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
