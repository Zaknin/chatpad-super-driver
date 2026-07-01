# Next Task

## Current state

- Current branch:
  `feature/offline-kmdf-orchestration-defensive-taxonomy-fix`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: close orchestration defensive taxonomy`.
- Required parent:
  `8b06ff5c2a7679b3057992ac99302fa550ddf098`,
  `docs: finalize orchestration taxonomy contract`.
- Finalized design:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- The fifth independent audit found four documentation-only defects: invalid
  `OWNER_READY`-bearing masks were normalized to canonical `READY`; rollback
  rejection/effects were not closed; R1-R20 profiles required cross-table
  inference; and section 23 did not explicitly require R1-R20 evidence.
- The defensive-taxonomy correction preserves actual incoming masks, separates
  ordinary sequential production from a finite offline fault-injection model,
  classifies every rollback enum through 12 closed effect labels, expands every
  R1-R20 record, and requires one-to-one evidence for the exact range R1-R20.
- Dormant source remains unchanged. Production orchestration is unimplemented
  and unauthorized. No production WDF graph was created and no driver loading
  occurred.

## Recommended objective

Perform an independent read-only audit of the finalized defensive taxonomy and
report-contract design.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Confirm only approved Markdown files changed.
3. Reinspect all report, baseline, ready, rollback, effect, mask, and stage
   assignments in dormant source.
4. Confirm 28 sequential sections, 22 top-level categories, deterministic 22A
   and 22B, and exactly 20 ordinary origins R1-R20.
5. Confirm all 16 rollback result enums and all seven effect members are bound.
6. Confirm no production implementation or runtime action occurred.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not edit, generate evidence, build, test, execute helpers, stage, commit,
  or push.
- Do not invoke initialization, validation, orchestration, creation, rollback,
  or any WDF object action.
- Do not sign, package, install, load, mutate Windows, query hardware, or
  interact with a controller or Chatpad.

## Acceptance criteria

- Valid already-ready input uses exact `READY`; invalid `OWNER_READY`-bearing
  input retains its actual incoming mask in all three report-mask fields.
- Ordinary R1-R20 production rollback permits only `R(OK)` and S1-S4 under the
  documented no-observer assumptions.
- The finite offline injection model is closed; every rollback result enum is
  classified; `ALREADY_CLEAN` uses A0/AF with populated masks and
  `AlreadyClean=TRUE`; invalid-mask and owner-ready rejection begin no deletion.
- The closed effect set is exactly `{ N0, J0, A0, AF, S1, S2, S3, S4, F1, F2,
  F3, F4 }`, with all seven values and final state explicit.
- Every R1-R20 record independently binds original report fields, exact entry
  state, ready values, ordinary and finite injected outcomes, final result,
  final mask/state, status, lifecycle, and `EvtDeviceAdd` outcome.
- Section 23 requires one-to-one R1-R20 evidence including command,
  configuration, result, assertion count when applicable, relative path, and
  SHA-256.
- Insertion point, one-call/report lifetime, mismatch handling, no-object
  faulting, status mapping, WDF parentage, category 22, guard limitations, and
  separate implementation/runtime gates remain correct.
- Production implementation remains unauthorized.

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
Get-Content src\driver\ChatpadFilter\device.c
```
