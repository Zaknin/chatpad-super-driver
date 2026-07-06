# Next Task

## Objective

Perform an independent strict read-only audit of the documentation-only
acceptance transition for fail-closed native adapter scaffolding audit target
`af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-fail-closed-scaffolding`.
- Required starting commit: the commit with subject
  `docs: accept native adapter scaffolding audit`; obtain its exact full hash
  from Git, require its parent to be
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`, and require upstream
  synchronization `0/0`.
- Accepted scaffolding audit target:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Fail-closed scaffolding implementation commit:
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.
- Audit acceptance status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding implementation status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify exact branch, HEAD, parent, upstream, remote equality, `0/0`, and
   clean tree/index.
3. Verify the acceptance commit changed only the six authorized continuity
   documents and regenerated readiness manifest.
4. Confirm tooling, fail-closed scaffolding modules, parser source/tests,
   ignored evidence, real artifacts, compile outputs, production driver source,
   INF/project/solution files, packaging paths, and `legacy/` are unchanged.

## Audit Scope

- Verify accepted target
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e` and implementation commit
  `7560fc242a39228d6a95f42ff908bb4be438d6ad` are recorded consistently.
- Verify audit status is exactly
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Verify acceptance did not alter the current gate, runtime blocker, design
  status, implementation status, evidence mode, live readiness, or native
  execution status.
- Verify SetupAPI/Newdev invocation, native loading, entry-point resolution,
  device query, Windows mutation, driver action, and real DLL/compile-output
  access remain unauthorized.
- Verify manifest generation and validation remain schema v4, 39 entries,
  duplicate IDs/paths `0`, `NO_PATH` `0`, and record implementation commit
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any
native/device/Windows/driver action. Do not open, read, hash, parse, stat, scan,
write, load, reflect over, or execute the real DLL or compile outputs.

## Acceptance Criteria

- The transition is documentation/evidence only and records the exact audit
  target, implementation commit, and acceptance status.
- Manifest validation passes under Windows PowerShell 5.1 and PowerShell 7 with
  semantic cross-runtime identity and zero defects.
- Current gate and runtime blocker remain
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness remains `BLOCKED`; native execution remains
  `NOT_IMPLEMENTED`.
- No positive execution authorization or prohibited executable pattern was
  added.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `docs/RUNTIME-BRINGUP-READINESS.md`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
