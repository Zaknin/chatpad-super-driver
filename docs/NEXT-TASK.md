# Next Task

## Objective

Perform an independent strict read-only audit of the documentation-only
acceptance commit for non-live native adapter operation planning.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-non-live-implementation-phase`.
- Required starting commit: the commit with subject
  `docs: accept native adapter planning audit`; obtain its exact full hash from
  Git, require parent `5e7a6f39d0363121b8bd3f6e4b38ceb517889679`, and
  require upstream synchronization `0/0`.
- Accepted audit target:
  `5e7a6f39d0363121b8bd3f6e4b38ceb517889679`.
- Non-live implementation commit:
  `4522510a17354fe53d163546e16ff24af5fa0374`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live planning audit acceptance:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Scaffolding implementation commit:
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.
- Scaffolding-audit remediation commit:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Scaffolding-audit acceptance commit:
  `748ba24b3e795cd70b3325b6a54fb88569427ed6`.
- Scaffolding-audit status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify exact branch, HEAD, parent, upstream, remote equality, `0/0`, and a
   clean tree/index.
3. Verify the acceptance commit changed only authorized continuity documents,
   manifest, and manifest generator/validator.
4. Confirm adapter modules, offline suite, parser, artifacts, compile outputs,
   driver source, INF/project files, binaries, ignored evidence, and `legacy/`
   are unchanged.

## Audit Scope

- Verify the accepted target, implementation commit, audit status,
  scaffolding-audit identity/status, and prior scaffolding identities are
  present consistently and validator-enforced.
- Validate schema v4, 39 entries, duplicate IDs/paths `0`, `NO_PATH` `0`, and
  semantic cross-runtime identity under Windows PowerShell 5.1 and PowerShell
  7.
- Verify gate/runtime blocker remain
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, live readiness remains
  `BLOCKED`, native execution remains `NOT_IMPLEMENTED`, and evidence mode
  remains `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Verify operation plans/results remain blocked/non-executing and the
  acceptance authorizes no artifact, native, device, hardware, Windows, or
  driver action.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any
native/device/Windows/driver action. Do not open, read, hash, parse, stat, scan,
write, load, reflect over, or execute the real DLL or compile outputs.

## Acceptance Criteria

- Exact continuity identities and statuses are present and validator-enforced.
- Manifest validation passes under both runtimes with zero defects and
  cross-runtime identity.
- No positive authorization or prohibited executable pattern was added.
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
