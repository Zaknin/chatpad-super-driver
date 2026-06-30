# Next Task

## Current state

- Current branch: `feature/offline-owner-init-doc-consistency`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: align owner initialization state`.
- Required parent: `a08ea1f5e4431893bc84e459957a3a63509d0c2f`.
- Starting correction branch:
  `feature/offline-owner-init-audit-corrections`.
- Completed correction branch:
  `feature/offline-owner-init-doc-consistency`.
- Checkpoint record:
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
- Audit-corrections record:
  [Offline KMDF Owner Initialization Audit Corrections](OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md).
- Evidence manifest:
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json).

## Recommended objective

Perform an independent read-only documentation-consistency audit of the
owner-initialization current-state corrections.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Inspect only tracked documentation and Git metadata.
3. Confirm the documentation-only commit changed only Markdown files.
4. Confirm `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md` and
   `docs/PORTING-PLAN.md` no longer present completed linkage, owner
   embedding, ordinary initialization, or explicit pre-object validation as
   future work.
5. Confirm current-state validation wording distinguishes initializer-internal
   validation from one additional explicit `EvtDeviceAdd` pre-object
   validation.

## Safety restrictions

- Keep the audit strictly read-only.
- Do not edit files, stage changes, commit, push, rebuild, or regenerate
  evidence.
- Do not modify source, headers, projects, solutions, scripts, tests,
  manifests, retained logs, or artifacts.
- Do not run builds, regression suites, compile checks, InfVerif, Inf2Cat, or
  evidence-generating wrappers.
- Do not invoke dormant orchestration, any request-owner helper, WDF object
  creation or deletion, target discovery, request formatting/submission/
  completion/cancellation, signing, staging, installation, loading, Windows
  mutation, hardware query, or controller/Chatpad interaction.

## Acceptance criteria

- The current production state is documented consistently:
  project reference present, authoritative header included, exactly one
  embedded owner, one ordinary initializer call, initializer-internal
  validation, one additional explicit pre-object validation, lifecycle
  initialization only after both steps succeed, and no request-owner WDF object
  graph or target/request activity.
- Historical design passages are clearly labeled as historical, completed, or
  superseded where they describe completed slices.
- Remaining future integration is limited to dormant orchestration, live WDF
  parentage/runtime creation proof, target discovery, request formatting,
  submission/completion/cancellation, D0/removal rundown, signing/deployment,
  and hardware observation.
- `docs/NEXT-TASK.md` authorizes only this read-only documentation audit and
  does not authorize dormant orchestration.
- No implementation, guard, manifest, evidence, binary, project, or script
  change is present.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
git show --stat --oneline HEAD
Get-Content docs\WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md
Get-Content docs\PORTING-PLAN.md
```
