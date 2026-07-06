# Next Task

## Objective

Perform an independent strict read-only audit of the native adapter execution
scope-boundary identity remediation commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-scope-boundary`.
- Required starting commit: the commit with subject
  `docs: record native adapter execution boundary identity`; obtain its exact
  full hash from Git, require parent
  `4cdde55e392e78db8a7a38858fb2f436557fbe2e`, and require upstream
  synchronization `0/0`.
- Execution scope-boundary commit:
  `4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
- Accepted non-live planning audit commit:
  `bb6cc27c2281e04dee2166c5a67e124092055f9f`.
- Non-live implementation commit:
  `4522510a17354fe53d163546e16ff24af5fa0374`.
- Non-live planning continuity remediation:
  `5e7a6f39d0363121b8bd3f6e4b38ceb517889679`.
- Scaffolding audit acceptance:
  `748ba24b3e795cd70b3325b6a54fb88569427ed6`.
- Scaffolding implementation:
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.
- Previous scaffolding remediation/audit:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Execution-scope boundary status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Execution design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Scaffolding-audit status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live planning audit status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Installation readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

## Preconditions

1. Follow `AGENTS.md` and verify exact branch, HEAD, parent, upstream, remote
   equality, `0/0`, and a clean tree/index.
2. Verify the remediation changed only the authorized documentation, manifest,
   manifest generator, and manifest validator paths.
3. Confirm adapter modules, offline suite, parser, artifacts, compile outputs,
   driver source, INF/project files, binaries, ignored evidence, and `legacy/`
   are unchanged.

## Audit Scope

- Verify the manifest records and the generator/validator enforce exact
  scope-boundary commit `4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
- Verify the boundary status and all prior implementation/audit identities and
  statuses remain exact and consistent.
- Verify the current repository still does not satisfy the execution envelope
  and every artifact/native/device/hardware/Windows/driver authorization is
  false.
- Validate schema v4, 39 entries, duplicate IDs/paths `0`, `NO_PATH` `0`, and
  cross-runtime manifest identity under Windows PowerShell 5.1 and PowerShell
  7.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any artifact,
native, device, hardware, Windows, or driver path. Do not open, read, hash,
parse, stat, scan, write, load, reflect over, or execute the real DLL or compile
outputs.

## Acceptance Criteria

- Scope-boundary commit, boundary status, accepted base, and all prior
  identities/statuses are present and validator-enforced.
- Gate/runtime blocker remain
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, installation readiness
  remains `BLOCKED`, native execution remains `NOT_IMPLEMENTED`, and evidence
  mode remains `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Manifest validation passes under both runtimes with zero defects and no
  cross-runtime differences.
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
