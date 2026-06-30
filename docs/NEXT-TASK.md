# Next Task

## Current state

- Current branch: `feature/offline-kmdf-orchestration-design-fix`.
- Required starting commit: the documentation-only commit with exact subject
  `docs: correct production orchestration failures`.
- Required parent:
  `eb0a9e90f7adc424ae7e5c471a0c8977a71b6efe`.
- Previous branch: `feature/offline-kmdf-production-orchestration-design`.
- Previous design commit:
  `eb0a9e90f7adc424ae7e5c471a0c8977a71b6efe`,
  `docs: design production owner orchestration`.
- Corrected design record:
  [Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
- Existing production integration design:
  [Windows 11 KMDF Production Integration Design](WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md).
- The first orchestration-invocation design failed independent audit because it
  overgeneralized early no-object failure semantics. The corrected design now
  distinguishes early argument/baseline rejection from post-baseline no-object
  stage failure, explicitly includes no sequence-advance eligibility, and maps
  partial-state validation failures through the existing failed stage result
  and report fields.

## Recommended objective

Perform an independent read-only documentation audit of the corrected
production orchestration-invocation design.

## Preconditions

1. Verify exact branch, HEAD, parent, subject, upstream, clean worktree, and
   clean index.
2. Inspect tracked documentation, tracked source, project metadata, and Git
   metadata only as needed to audit the corrected design.
3. Confirm the correction changed only approved Markdown files.
4. Confirm the main design contains exactly 28 numbered sections and leaves no
   fundamental orchestration-invocation failure-state decision unresolved.
5. Confirm production orchestration remains unimplemented and unauthorized.

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

- Null parent-device rejection is documented as an early argument rejection
  after baseline acceptance, before common failure handling, with no creation
  helper call, no object publication, no rollback, no fault transition, no
  lifecycle initialization, and `STATUS_INVALID_PARAMETER` mapping.
- Invalid baseline rejection is documented as an early baseline rejection
  before common failure handling, with no creation helper call, no object
  publication, no rollback, no automatic fault transition, no lifecycle
  initialization, and `STATUS_INVALID_DEVICE_STATE` mapping.
- Post-baseline no-object stage failure is documented separately as the
  spinlock-stage no-publication path that reaches common failure handling,
  performs no rollback, and uses the existing no-object fault helper when its
  invariant path succeeds.
- Partial-state validation failure is explicit and represented through the
  actual failed stage result plus `FailedStage` and `ValidationResult`, not a
  newly invented enum.
- The clean pre-object baseline explicitly includes
  `SequenceAdvanceEligible == 0u`.
- The insertion point remains immediately after explicit pre-object validation
  and before `ChatpadFilterLifecycleInitialize`.
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
