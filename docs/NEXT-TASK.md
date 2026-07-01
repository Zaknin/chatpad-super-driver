# Next Task

## Exact Current State

- Branch:
  `feature/offline-kmdf-production-orchestration-input-identity-remediation`.
- Required starting commit: the commit containing this file, with subject
  `test: complete production orchestration input identity evidence` and parent
  `d22867f86917a6c81574b5f82d19aacd9984b213`. Obtain its hash from Git.
- Frozen production implementation:
  `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Prior finalization checkpoint:
  `d22867f86917a6c81574b5f82d19aacd9984b213`,
  `test: finalize production orchestration evidence`.
- Finalization/remediation record:
  [Offline KMDF Production Orchestration Evidence Finalization](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-FINALIZATION.md).
- Manifest:
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json),
  schema `1.3.0`, 62 mandatory IDs and 62 unique entries.
- Complete A/B input identity:
  Debug A/B each contain 116 inputs; Release A/B each contain 118 inputs.
  Both configurations report zero missing, extra, hash mismatch, unresolved,
  duplicate, configuration mismatch, and toolchain mismatch counts.
- Canonical Debug set B:
  32,256 bytes,
  `F05357700DCC71125CFA2583867B422E2E8E5A8E26FD3FA0AFCE5370AF5F8D7B`.
- Canonical Release set B:
  20,480 bytes,
  `5313E60CB503EBB4FA129D21CB26E1832E32FDE7E1F923D5C8E802D1D74D3905`.

Production source is unchanged. The driver has never been loaded. Runtime WDF
creation, target discovery, request operations, signing, installation, and
hardware behavior remain unobserved.

## Recommended Objective

Perform an independent read-only audit of the frozen implementation, the
input-identity remediation checkpoint, the schema-`1.3.0` manifest, all 62
ignored evidence files, retained A/B input inventories, retained A/B binaries
and inspection outputs, the containing commit, and final upstream state.

## Preconditions

1. Verify branch, HEAD, parent, exact subject, upstream, local/upstream
   equality, and clean worktree/index.
2. Require the containing commit parent to equal
   `d22867f86917a6c81574b5f82d19aacd9984b213`.
3. Re-read the repository protocol and latest worklog entry.
4. Independently verify that all production source/project/INF blobs equal
   implementation commit `efb7295`.
5. Rehash every manifest evidence path, all four retained A/B SYS files, and
   all four retained input-inventory JSON files.

## Safety Restrictions

- Read-only audit only.
- Do not regenerate evidence.
- Do not run builds, tests, guards, helpers, orchestration, or WDF actions.
- Do not sign, package, create certificates/keys, stage outside Git, install,
  load, mutate Windows, query devices, or access USB, XUSB, a controller, or a
  Chatpad.
- Do not modify `legacy/`.

## Acceptance Criteria

- Remediation commit parent, subject, branch, upstream, and clean state match.
- Production source and projects exactly match frozen implementation
  `efb7295`.
- Manifest schema is `1.3.0`.
- Guard mandatory set, top-level declaration, and entry IDs are each exactly
  62, with zero missing, unexpected, or duplicate IDs/paths.
- Every entry has exactly one literal `command` or ordered `commands` value,
  complete metadata, an ignored existing path, and a matching SHA-256.
- KMDF semantic evidence reports 62/62, zero warnings/errors, and zero
  build/guard exits in Debug and Release.
- Repository-safety evidence contains every required counter and all are zero.
- Debug and Release A/B input inventories derive from compiler/linker tracking
  logs plus explicit solution/project/props and toolchain identity, not the
  rejected eight-file subset.
- Debug and Release A/B input comparisons have equal path sets, equal content
  hashes, equal build-configuration digests, equal toolchain identity digests,
  zero unresolved inputs, and zero duplicate normalized paths.
- Debug and Release A/B pairs have equal sizes, PE structure, normalized
  PE/section hashes, executable-section raw hashes, imports, WDF references,
  normalized disassembly/symbol hashes, retention boundaries, target/request
  absence, and Authenticode state.
- A/B equivalence manifest `metric_value` strings exactly match the retained
  equivalence logs' `ManifestMetricValue` lines.
- Normalization excludes only COFF timestamp, PE checksum, debug-directory
  timestamp, and CodeView GUID.
- Historical hashes are treated as observations only; no retroactive
  equivalence claim remains.
- Full-log and staged/candidate self-reference limits are stated honestly.
- No production source, generated artifact, runtime, deployment, or hardware
  action is in the remediation commit.

## Inspect First

```powershell
git branch --show-current
git log -1 --format="%H%n%P%n%s"
git status --short --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-FINALIZATION.md
Get-Content docs\evidence\production-orchestration-invocation-manifest.json
Get-Content tools\Test-ChatpadProductionOrchestrationInvocation.ps1
Get-Content artifacts\logs\production-orchestration-ab-rebuild\ab-input-comparison-debug.log
Get-Content artifacts\logs\production-orchestration-ab-rebuild\ab-input-comparison-release.log
```
