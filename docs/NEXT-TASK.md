# Next Task

## Objective

Perform an independent strict read-only audit of the non-live native adapter
operation-planning implementation.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-non-live-implementation-phase`.
- Required starting commit: the commit with subject
  `feat: add non-live native adapter operation planning`; obtain its exact full
  hash from Git, require parent
  `748ba24b3e795cd70b3325b6a54fb88569427ed6`, and require upstream
  synchronization `0/0`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Scaffolding audit acceptance:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify exact branch, HEAD, parent, upstream, remote equality, `0/0`, and a
   clean tree/index.
3. Verify the implementation commit changed only the authorized module, focused
   offline suite, manifest generator/validator, continuity documents, and
   regenerated readiness manifest.
4. Confirm parser, real artifacts, compile outputs, production driver source,
   INF/project/solution files, binaries, ignored evidence, and `legacy/` are
   unchanged.

## Audit Scope

- Trace the new operation-plan, precondition-evaluation, always-deny
  authorization-decision, and typed result-model call chain.
- Verify `Apply`, `Restore`, and `Restart` produce inert blocked plans and
  blocked results with all native-load, entry-point, SetupAPI/Newdev, device,
  hardware, Windows, driver, and artifact counters/flags zero.
- Verify future or caller-supplied authorization cannot authorize execution.
- Verify target identity remains inert request data and no lookup is performed.
- Verify no new path reaches the static parser, full compile-output validator,
  filesystem output enumeration, native loading, or executable APIs.
- Reproduce focused tests and no-artifact-I/O regression in Windows PowerShell
  5.1 and PowerShell 7, plus schema-v4 39-entry manifest validation.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any
native/device/Windows/driver action. Do not open, read, hash, parse, stat, scan,
write, load, reflect over, or execute the real DLL or compile outputs.

## Acceptance Criteria

- The implementation is data-only and non-live.
- All focused checks pass under both PowerShell runtimes.
- Manifest validation passes with 39 entries, duplicate IDs/paths `0`,
  `NO_PATH` `0`, zero defects, and cross-runtime identity.
- Current gate remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness remains `BLOCKED`; native execution remains
  `NOT_IMPLEMENTED`.
- No positive authorization or prohibited executable pattern is reachable.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
7. `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
