# Next Task

## Objective

Perform an independent strict read-only audit of the record-only native-adapter
execution-envelope verifier audit-pass-acceptance audit-pass transition commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-envelope-verifier`.
- Required starting commit: derive the exact full hash from Git and require
  subject `docs: record native adapter verifier audit pass acceptance`.
- Required parent:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Required upstream:
  `origin/feature/native-adapter-execution-envelope-verifier`.
- Required synchronization and tree: `0/0` and clean.
- Accepted verifier audit-pass acceptance audit target:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Verifier audit-pass acceptance audit status:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Accepted verifier audit-pass record target:
  `b64a672984b6e7db16765f13de385b22f3491f11`.
- Verifier audit-pass acceptance status:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
- Prior verifier audit-pass record target:
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Verifier audit-pass recorded status:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
- Prior verifier audit-pass transition target:
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Prior verifier audit-acceptance audit pass:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Record-only verifier implementation commit and accepted audit target:
  `4849d1959cab9c289952655eb73e3279117779d2`.
- Verifier implementation status:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.
- Verifier audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
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
- Execution authorized: `false`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

This transition commit should not be rejected for omitting its own hash.
Establish its identity from Git.

## Preconditions

1. Follow `AGENTS.md`; verify exact branch, subject, parent, upstream, remote
   equality, `0/0`, and clean tree/index.
2. Verify changed paths are limited to:
   - `docs/DECISIONS.md`
   - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
   - `docs/NEXT-TASK.md`
   - `docs/PROJECT-STATE.md`
   - `docs/RUNTIME-BRINGUP-READINESS.md`
   - `docs/WORKLOG.md`
   - `docs/evidence/runtime-bringup-readiness-manifest.json`
   - `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
   - `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
3. Confirm verifier behavior modules, offline-suite behavior modules, static
   parser, real artifact, compile outputs, harness/evidence policy, driver,
   INF/project/solution, packaging, signing, staging, deployment, binaries, and
   `legacy/` are unchanged.

## Audit Scope

- Verify this commit records accepted audit-pass acceptance audit target
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Verify accepted audit-pass record target remains recorded as
  `b64a672984b6e7db16765f13de385b22f3491f11`.
- Verify prior audit-pass record target remains recorded as
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Verify prior audit-pass transition target remains recorded as
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Verify prior verifier implementation audit target remains recorded as
  `4849d1959cab9c289952655eb73e3279117779d2`.
- Verify audit-pass acceptance audit status is exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Verify audit-pass acceptance status is exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
- Verify audit-pass recorded status is exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
- Verify audit-acceptance audit-pass status is exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Verify audit acceptance status is exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Verify verifier implementation status remains exactly
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.
- Verify the gate/runtime blocker remains
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Verify execution authorization remains false, native execution remains
  `NOT_IMPLEMENTED`, and live readiness remains `BLOCKED`.
- Verify artifact/compile-output I/O fields remain false and all native,
  device, hardware, Windows, and driver counters remain zero.
- Validate manifest schema v4, 39 entries, duplicate IDs/paths `0/0`, `NO_PATH`
  `0`, and cross-runtime identity if the generator/validator changed.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any artifact,
native, device, hardware, Windows, or driver path. Do not open, read, hash,
parse, stat, scan, write, load, reflect over, or execute the real DLL or compile
outputs.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the exact
  audit-pass-acceptance audit-pass transition without self-reference.
- Accepted audit-pass acceptance audit target, audit-pass acceptance audit
  status, accepted audit-pass record target, prior audit-pass record target,
  prior audit-pass transition target, prior verifier implementation audit
  target, audit-pass acceptance status, audit-pass recorded status, audit-pass
  status, and audit-acceptance status are recorded in continuity docs,
  generated manifest, generator, and validator.
- Manifest validation passes under Windows PowerShell 5.1 and PowerShell 7 with
  zero defects.
- Documentation consistency, positive-authorization search, prohibited
  executable-pattern search, repository safety, forbidden generated-file scan,
  spelling-variant scan, and `git diff --check` pass.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
7. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
