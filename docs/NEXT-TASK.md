# Next Task

## Current state

- Current branch:
  `feature/offline-kmdf-orchestration-report-design-fix`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: complete orchestration report design`.
- Required parent:
  `8ec45055b3608ae917fa05e762ce37f73424ab63`,
  `docs: correct production orchestration failures`.
- Corrected design:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- The first independent audit found overgeneralized early-rejection semantics;
  commit `8ec45055b3608ae917fa05e762ce37f73424ab63` corrected them.
- The second independent audit found incomplete report/status taxonomy and
  ambiguous caller report initialization wording. This correction preserves
  the early-rejection fix and adds deterministic `{ 0 }` local report
  initialization, synchronous report lifetime, a 22-category report/mask/
  rollback/status taxonomy, and explicit LTCG limitations.
- Dormant request-owner implementation is unchanged. Production orchestration
  remains unimplemented and unauthorized.

## Recommended objective

Perform an independent read-only audit of the corrected report-aware
production orchestration-invocation design.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Confirm the correction commit contains only approved Markdown files.
3. Inspect the authoritative orchestration report definition and every report
   assignment in the existing dormant source.
4. Confirm the main design retains exactly 28 sequential numbered sections.
5. Confirm no production orchestration implementation or runtime action
   occurred.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not edit, generate evidence, build, test, execute helpers, stage, commit,
  or push.
- Do not invoke orchestration, creation, validation, or rollback helpers.
- Do not create/delete WDF objects, sign, package, install, load, mutate
  Windows, query hardware, or interact with a controller or Chatpad.

## Acceptance criteria

- Section 6 contains exactly one
  `ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };`,
  one orchestration call, result/report checks, and lifecycle only after
  success.
- Report storage is local, handle-free, synchronous, non-escaping, and read
  only after return; internal orchestrator clearing is documented.
- All 22 supported categories explicitly cover baseline/object/common-path
  state, result, stages, helper/validator/framework status, highest/final
  masks, ready flags, rollback result/effects, final owner state, production
  status, lifecycle, and final `EvtDeviceAdd` outcome.
- `HighestPartialInitializationMask` and `FinalInitializationMask` semantics
  match source assignments.
- Rollback failure preserves original failure fields and maps to
  `STATUS_INVALID_DEVICE_STATE`.
- Early null-parent/invalid-baseline semantics remain correct and distinct from
  post-baseline no-object fault marking.
- LTCG limitations are explicit without requiring LTCG to be disabled.
- Production orchestration remains unimplemented and unauthorized.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --untracked-files=all
git show --stat --oneline HEAD
Get-Content docs\WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md
Get-Content src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.h
Get-Content src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.c
```
