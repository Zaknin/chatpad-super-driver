# Next Task

## Current State

- Current branch:
  `feature/offline-kmdf-production-orchestration-invocation`.
- Expected starting commit:
  the commit with subject
  `driver: invoke production request owner orchestration`.
- Starting checkpoint for that implementation:
  `4ba0de15420e0b66287a501918de694c8b6fd720`,
  `docs: close orchestration defensive taxonomy`.
- Checkpoint record:
  [Offline KMDF Production Orchestration Invocation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md).
- Evidence manifest:
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json).

Production `ChatpadEvtDeviceAdd` now invokes the dormant request-owner object
graph exactly once after ordinary owner initialization and explicit pre-object
validation, before lifecycle initialization. The call uses a stack-local
zero-initialized orchestration report, cross-checks function return against
`report.Result`, maps failures before lifecycle, validates structural ready
state, and then continues to the existing lifecycle path.

No driver load, signing, package creation, staging, installation, Windows
mutation, hardware query, target discovery, request formatting, request send,
completion, or cancellation occurred.

## Recommended Objective

Perform an independent offline implementation and evidence audit of the
production orchestration invocation checkpoint.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Confirm the starting commit is the expected
   `driver: invoke production request owner orchestration` commit.
3. Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
   `docs/NEXT-TASK.md`, and the latest `docs/WORKLOG.md` entry.
4. Inspect `src/driver/ChatpadFilter/device.c`,
   `tools/Test-ChatpadProductionOrchestrationInvocation.ps1`,
   `tools/Test-ChatpadProductionLinkage.ps1`,
   `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`,
   `tools/Test-ChatpadProductionOwnerInitialization.ps1`,
   `docs/OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md`, and
   `docs/evidence/production-orchestration-invocation-manifest.json`.
5. Compare the manifest to retained ignored logs under `artifacts/logs` when
   practical.

## Safety Restrictions

- Keep the audit read-only unless a concrete documentation or guard defect is
  found and explicitly needs correction.
- Do not sign, package, stage, install, load, mutate Windows, query hardware,
  or interact with a controller or Chatpad.
- Do not add target discovery, request formatting, request send, completion,
  cancellation, D0/removal owner observation, cleanup callbacks, or destroy
  callbacks.
- Do not modify files under `legacy/`.
- Keep any generated audit logs under ignored `artifacts/`.

## Acceptance Criteria

- `ChatpadEvtDeviceAdd` has exactly one production
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` call.
- The call is after successful ordinary owner initialization and explicit
  pre-object validation, and before `ChatpadFilterLifecycleInitialize`.
- The local report is initialized as `{ 0 }`, does not escape, and is not
  embedded in device context.
- The function return/report-result mismatch path returns
  `STATUS_INVALID_DEVICE_STATE` before lifecycle initialization.
- Every non-OK orchestration result returns before lifecycle initialization.
- Creation-stage failures preserve failing `FrameworkStatus`; all local
  validation/rollback/invariant failures map to `STATUS_INVALID_DEVICE_STATE`;
  null input/report categories map to `STATUS_INVALID_PARAMETER`.
- Structural-ready validation checks ready attempt, ready publication, graph
  completeness, non-null request, and authoritative `FULLY_READY` state.
- Production `device.c` still has no direct creation-helper, rollback,
  direct-WDF-object-management, target, request-operation, D0/removal observer,
  or handle/report logging surface.
- The updated semantic guards pass in SourceOnly and Full modes.
- The manifest evidence hashes match retained ignored logs.
- Debug and Release driver hashes, sizes, and `NotSigned` status match
  `docs/PROJECT-STATE.md` and the manifest.
- No prohibited runtime or deployment action occurred.

## Inspect First

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --untracked-files=all
git show --stat --oneline HEAD
Get-Content docs\OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md
Get-Content docs\evidence\production-orchestration-invocation-manifest.json
Get-Content src\driver\ChatpadFilter\device.c
Get-Content tools\Test-ChatpadProductionOrchestrationInvocation.ps1
```
