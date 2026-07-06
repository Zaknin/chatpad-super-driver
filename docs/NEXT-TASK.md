# Next Task

## Objective

Perform an independent strict read-only audit of the final documentation-only
execution scope-boundary lane closeout commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-scope-boundary`.
- Required starting commit: obtain the exact full hash from Git and require
  subject `docs: close native adapter execution boundary scope`.
- Required parent:
  `f7f6041d6987ea8e3752546bd4c9116c88fbe56a`.
- Required upstream:
  `origin/feature/native-adapter-execution-scope-boundary`.
- Required synchronization and tree: `0/0` and clean.
- Accepted final-closeout audit target:
  `f7f6041d6987ea8e3752546bd4c9116c88fbe56a`.
- Prior accepted closeout-identity target:
  `9c9af5cf0cfdffde67a0f2b4e41e8eceb42d673f`.
- Lane-closeout commit:
  `e68ed58e3c5a2560c331f4b69dfe021ae54531e1`.
- Boundary audit-acceptance commit:
  `d1372ba8f7812d24a09b87238793e78435ac4492`.
- Boundary continuity remediation commit:
  `f0b10d862d23d0ede28b1139c2ccb726bfcddc48`.
- Boundary implementation commit:
  `4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
- Final lane status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO`.
- Closeout status: `AUDIT_PASS_LANE_CLOSED_NO_NATIVE_IO`.
- Closeout-identity audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_BOUNDARY_CLOSEOUT_IDENTITY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Scaffolding-audit status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live audit status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Scope status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Scope-audit status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

The closeout commit must not be rejected for omitting its own hash. Its identity
did not exist when its content was created and must be established from Git.

## Preconditions

1. Follow `AGENTS.md` and verify exact branch, commit subject, parent, upstream,
   remote equality, `0/0`, and a clean tree/index.
2. Verify the commit changed only the authorized documentation, manifest,
   manifest generator, and manifest validator paths.
3. Confirm adapter modules, offline suite, parser, artifacts, compile outputs,
   driver source, INF/project files, binaries, ignored evidence, and `legacy/`
   are unchanged.

## Audit Scope

- Verify accepted target `f7f6041d6987ea8e3752546bd4c9116c88fbe56a`
  and final lane status
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO` are
  documented and validator-enforced.
- Verify every prior identity and status listed above remains exact.
- Verify the manifest remains schema v4 with 39 entries, duplicate IDs/paths
  `0/0`, `NO_PATH` `0`, and cross-runtime identity.
- Verify the repository still does not satisfy the execution envelope and all
  artifact/native/device/hardware/Windows/driver authorization remains false.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run behavior tests, the
static parser, the full compile-output validator, full exact/readiness suites,
or any artifact/native/device/hardware/Windows/driver path. Do not open, read,
hash, parse, stat, scan, write, load, reflect over, or execute the real DLL or
compile outputs.

## Acceptance Criteria

- Git identity, subject, parent, changed paths, and content establish the final
  closeout without requiring self-reference.
- All identities/statuses are present and validator-enforced.
- Gate/runtime blocker remain
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, live readiness remains
  `BLOCKED`, native execution remains `NOT_IMPLEMENTED`, and evidence mode
  remains `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Manifest validation passes under both PowerShell runtimes with zero defects
  and no cross-runtime differences.
- No positive authorization or prohibited executable pattern was added.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
8. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
