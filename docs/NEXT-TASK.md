# Next Task

## Objective

Perform an independent strict read-only audit of the record-only native-adapter
execution authorization-envelope verifier implementation commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit: obtain the exact full hash from Git and require
  subject `feat: add native adapter execution envelope verifier`.
- Required parent:
  `68099a441db5f8b517dbeb296ab234a9ee639bdb`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree: `0/0` and clean.
- Accepted execution scope-boundary final-closeout commit:
  `68099a441db5f8b517dbeb296ab234a9ee639bdb`.
- Verifier status:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.
- Final boundary lane:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO`.
- Boundary closeout-identity audit:
  `NATIVE_ADAPTER_EXECUTION_BOUNDARY_CLOSEOUT_IDENTITY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Closeout: `AUDIT_PASS_LANE_CLOSED_NO_NATIVE_IO`.
- Gate/runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Scaffolding audit:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live implementation:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live audit:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Scope:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Scope audit:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

The verifier implementation commit must not be rejected for omitting its own
hash. Establish its identity from Git.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, subject, parent, upstream, remote
   equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to the existing non-live adapter module,
   focused safe offline tests, continuity documents, manifest, generator, and
   validator.
3. Confirm static parser, compile-output harness/evidence policy, real artifact,
   driver source, INF/project files, packaging, binaries, and `legacy/` are
   unchanged.

## Audit Scope

- Trace `Test-ChatpadNativeAdapterExecutionAuthorizationEnvelope` and every
  helper transitively.
- Verify exact-property whitelists and strict declared-value validation for
  operation, future authorization, artifact identity, allowlists, device
  binding, dry-run evidence, rollback, mutation classification, operator
  confirmation, audits, and current denial.
- Verify missing, malformed, stale, future/live, injected-authority, wildcard,
  wrong numeric type, and complete envelopes all remain blocked.
- Verify the verifier is not connected to production operation dispatch.
- Verify no verifier path reaches artifact/compile-output I/O, parser, native
  loading, entry-point resolution, SetupAPI/Newdev, device/hardware query,
  registry/service/certificate access, Windows mutation, or driver action.
- Validate manifest schema v4, 39 entries, duplicate IDs/paths `0/0`, `NO_PATH`
  `0`, and cross-runtime identity.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any artifact,
native, device, hardware, Windows, or driver path. Do not open, read, hash,
parse, stat, scan, write, load, reflect over, or execute the real DLL or compile
outputs.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  implementation without self-reference.
- Focused verifier tests pass under Windows PowerShell 5.1 and PowerShell 7.
- No-artifact-I/O call-chain regression passes under both runtimes with 23/23
  functions and zero forbidden commands/members.
- Every result has execution authorization false, native execution
  `NOT_IMPLEMENTED`, live readiness `BLOCKED`, exact blocker, false artifact
  I/O, and zero native/device/hardware/Windows/driver counters.
- Manifest validation passes under both runtimes with zero defects.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
7. `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
8. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
10. `docs/evidence/runtime-bringup-readiness-manifest.json`
