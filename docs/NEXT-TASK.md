# Next Task

## Current state

- Current branch:
  `feature/offline-kmdf-orchestration-taxonomy-contract-fix`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: finalize orchestration taxonomy contract`.
- Required parent:
  `6f9f2750347ee6ecd50470261a6af0a859b53357`,
  `docs: bind orchestration report contract`.
- Finalized design:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- The fourth independent audit found three documentation-only defects:
  helper/validator/rollback-effect values remained implicit, section 28 did
  not explicitly bind all 19 exact fields, and the semantic guard did not
  enforce source-level `ReadyPublicationAttempted` behavior.
- The taxonomy-contract correction replaces placeholders with closed exact
  value sets and origin/effect profiles, defines a closed `{ FAULT }`
  post-effect state, adds a ready-field truth table, binds all 19 fields in
  section 28, and requires semantic proof of ready-attempt values and rollback
  persistence.
- Earlier report initialization, return/result consistency, mask semantics,
  deterministic lifecycle subcases 22A/22B, evidence requirements, early
  rejection, status mapping, WDF parentage, and LTCG limits remain unchanged.
- Dormant source is unchanged. Production orchestration remains unimplemented
  and unauthorized.

## Recommended objective

Perform an independent read-only audit of the finalized production
orchestration taxonomy and report contract.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Confirm only approved Markdown files changed.
3. Inspect all report, creation, validation, rollback, effect, mask, and stage
   definitions and assignments in the dormant source.
4. Confirm 28 sequential sections, 22 top-level categories, and deterministic
   subcases 22A and 22B.
5. Confirm all 19 exact fields occur in both taxonomy and section 28.
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

- Every taxonomy category and subcase resolves all 19 report fields through
  exact symbols, closed sets, and `E0`-`E4` effect profiles with no placeholder
  or cross-row inference.
- Framework and validation subcases use source-supported creation/validation
  enums and exact framework-status behavior.
- Category 19 is bounded as a defensive classifier rejection with `E0`;
  category 20 uses `R(POST_ROLLBACK_INVARIANT_FAILED)`, `E1`-`E4`, and the
  single final state `{ FAULT }`.
- The ready-field truth table matches source, including final-ready failure,
  rollback profile `R20`, success, and later lifecycle failure.
- Section 28 names and binds all 19 fields by meaning, production use, and
  guard/evidence requirement.
- Semantic guards enforce exact `ReadyPublicationAttempted` values, distinction
  from other ready indicators, and persistence through rollback.
- Insertion point, one-call/no-retry rule, early rejection, no-object faulting,
  status mapping, lifecycle reachability, report lifetime, WDF parentage, and
  separate implementation/runtime gates remain correct.
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
