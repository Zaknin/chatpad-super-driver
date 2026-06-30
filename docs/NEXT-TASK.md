# Next Task

## Current state

- Current branch: `feature/offline-kmdf-production-orchestration-design`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: design production owner orchestration`.
- Required parent: `8b91eaf939252e038bd0970db261cc14b1089613`.
- Previous branch: `feature/offline-owner-init-doc-consistency`.
- Current implementation checkpoint:
  `8b91eaf939252e038bd0970db261cc14b1089613`,
  `docs: align owner initialization state`.
- New design record:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- Existing production integration design:
  [Windows 11 KMDF Production Integration Design](WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md).

## Recommended objective

Perform an independent read-only documentation audit of the production
orchestration-invocation design.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Inspect tracked documentation, tracked source, project metadata, and Git
   metadata only as needed to audit the design.
3. Confirm the design task changed only Markdown files.
4. Confirm `docs/PROJECT-STATE.md` records the current implementation
   checkpoint subject as `docs: align owner initialization state` and commit
   `8b91eaf939252e038bd0970db261cc14b1089613`.
5. Confirm the new design contains exactly 28 numbered sections and leaves no
   fundamental orchestration-invocation decision unresolved.

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

- The design starts from the current production state: project reference,
  authoritative header include, exactly one embedded owner, one ordinary
  initializer call, initializer-internal validation, one additional explicit
  pre-object validation, lifecycle initialization only after both steps
  succeed, and no current request-owner WDF object graph or target/request
  activity.
- The selected future insertion point is immediately after explicit
  pre-object validation and before `ChatpadFilterLifecycleInitialize`.
- Result/status mapping, no-object failure, partial rollback, final-ready
  validation failure, rollback failure, and later `EvtDeviceAdd` failure
  cleanup are fully specified.
- Parentage, callback visibility, concurrency assumptions, IRQL assumptions,
  future implementation scope, semantic-guard expectations, validation plan,
  evidence contract, and future gates are documented consistently.
- The design does not authorize source implementation, driver loading,
  signing, staging, installation, target discovery, request execution, Windows
  mutation, hardware query, or controller/Chatpad interaction.
- No implementation, project, script, manifest, evidence, artifact, binary, or
  non-Markdown change is present.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git log -1 --format="%H%n%P%n%s"
git status --short --branch --untracked-files=all
git show --stat --oneline HEAD
Get-Content docs\WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md
Get-Content docs\PROJECT-STATE.md
Get-Content docs\WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md
```
