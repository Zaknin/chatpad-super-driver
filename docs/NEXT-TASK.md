# Next Task

## Current state

- Current branch:
  `feature/offline-kmdf-orchestration-report-contract-fix`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: bind orchestration report contract`.
- Required parent:
  `ad04ebc17a4ca75d033a08514f692b037a5e6dc8`,
  `docs: complete orchestration report design`.
- Corrected design:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- The third independent design audit found three remaining documentation-only
  defects: exact report fields `Result` and `ReadyPublicationAttempted` were
  not explicitly bound, post-orchestration lifecycle behavior was ambiguous,
  and the evidence contract omitted explicit highest/final-mask checks.
- The report-contract correction explicitly binds all 19 source report fields,
  distinguishes function return from report `Result`, makes mismatch a hard
  local failure, defines deterministic lifecycle subcases 22A and 22B, and
  names both mask fields in future evidence requirements.
- Earlier early-rejection, report-mask, rollback, status-mapping, insertion,
  report-lifetime, LTCG, and WDF-parentage corrections remain unchanged.
- Dormant request-owner source is unchanged. Production orchestration remains
  unimplemented and unauthorized.

## Recommended objective

Perform an independent read-only audit of the corrected production
orchestration report contract.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Confirm the correction commit contains only approved Markdown files.
3. Inspect the authoritative 19-field report structure and every relevant
   assignment in the existing dormant source.
4. Inspect current `device.c` lifecycle initialization and device-created
   transition ordering.
5. Confirm the main design retains exactly 28 sequential numbered sections and
   22 top-level taxonomy categories with subcases 22A and 22B.
6. Confirm no production implementation or runtime action occurred.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not edit, generate evidence, build, test, execute helpers, stage, commit,
  or push.
- Do not invoke initialization, validation, orchestration, creation, or
  rollback helpers.
- Do not create/delete WDF objects, sign, package, install, load, mutate
  Windows, query hardware, or interact with a controller or Chatpad.

## Acceptance criteria

- All 19 exact source report fields are explicitly bound for every taxonomy
  category without blank cells or inference.
- Function return and report `Result` are distinct and equal on every path with
  valid report storage; null-report behavior and mismatch failure policy are
  exact.
- `ReadyPublicationAttempted` is explicit for every category and remains
  distinct from `ReadyPublished`, final-mask `OWNER_READY`,
  `ObjectGraphComplete`, and successful `Result`.
- Category 22 contains deterministic subcases 22A and 22B matching current
  `device.c`; no conditional lifecycle wording remains.
- Future evidence explicitly checks `HighestPartialInitializationMask`
  progression/rollback stability and `FinalInitializationMask` final-state
  behavior with exact command, result, and SHA-256 binding.
- Early rejection, post-baseline no-object faulting, status behavior, rollback
  ownership, insertion point, one-call rule, lifecycle failure reachability,
  report lifetime, LTCG limits, and separate implementation/runtime gates
  remain correct.
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
Get-Content src\driver\ChatpadFilter\device.c
```
