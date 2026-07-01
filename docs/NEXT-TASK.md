# Next Task

## Exact Current State

- Required branch:
  `feature/documentation-offline-runtime-instrumentation-design-remediation`.
- Required starting commit: the remediation commit containing this file, with
  subject `docs: remediate runtime instrumentation design audit`.
- Required parent:
  `b26514f59e9d07fbee09e8bab5ea296d18c0dd85`,
  `docs: define offline runtime instrumentation design`.
- Accepted first-runtime recovery plan:
  `fbca8852e47300d4f483968b23e42ee82e88b972`.
- Original offline instrumentation design checkpoint:
  `b26514f59e9d07fbee09e8bab5ea296d18c0dd85`.
- Independent audit result for the original design checkpoint: `AUDIT FAIL`.
- Original blocking defects:
  incomplete per-event metadata and premature continuity advancement to
  implementation.
- Remediated design:
  `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`.
- Remediated design status: independent acceptance pending.
- Selected mechanism remains WPP software tracing as primary evidence, with
  existing `KdPrintEx` as fallback only.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.
- Hardware/device state: no hardware identity has been queried in this phase.

## Next Recommended Objective

Independently audit the remediated offline runtime instrumentation design.

## Preconditions

1. Verify exact branch, HEAD parent, subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, recent `docs/WORKLOG.md`,
   `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`, and
   `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`.
3. Confirm the remediation changed only authorized documentation paths.
4. Reconfirm that no instrumentation implementation authorization exists.

## Safety Restrictions

- Do not implement instrumentation during the audit.
- Do not sign, package, create certificates/keys, stage, install, load, mutate
  Windows, query devices, use PnPUtil/DISM/DevCon/Device Manager, enable
  verifier, alter boot settings, access USB/HID/XUSB/controller/Chatpad, open a
  target, discover targets, or perform request formatting/submission/
  completion/cancellation.
- Do not modify source, headers, projects, solution files, shared props, INF
  files, scripts, tests, guards, evidence manifests/contracts, generated
  evidence, signing/packaging paths, or `legacy/`.

## Acceptance Criteria

- All 73 event IDs and symbolic names are preserved.
- Every event has complete per-event metadata for expected IRQL, maximum
  frequency, first-load criterion, and failure or rollback action.
- WPP safety assumptions are technically reasonable and do not authorize unsafe
  emission points.
- Continuity documents accurately state that the original audit failed, the
  remediation is not independently accepted, implementation is not authorized,
  and the next task is independent read-only audit.
- Frozen source/header, project/solution/props/INF, script/test/guard,
  manifest/contract, signing/packaging, generated evidence, and `legacy/`
  surfaces remain unchanged.
- Signing, packaging, device discovery, staging, installation, loading,
  runtime, and hardware gates remain closed.

## Inspect First

- `docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`
- `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- `docs/PORTING-PLAN.md`
- `docs/WORKLOG.md`
