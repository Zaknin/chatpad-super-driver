# Next Task

## Exact Current State

- Branch: `feature/offline-kmdf-production-orchestration-tlog-provenance-remediation`.
- Required starting commit: the commit containing this file, with subject `test: bind production orchestration tlog provenance` and parent `b2a9b5cee457f69126c6f6c80615738e4ae59f31`. Obtain its hash from Git.
- Frozen production implementation: `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Prior remediation checkpoint: `b2a9b5cee457f69126c6f6c80615738e4ae59f31`, `test: complete production orchestration input identity evidence`.
- Current checkpoint record: [Offline KMDF Production Orchestration Tlog Provenance Remediation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-TLOG-PROVENANCE-REMEDIATION.md).
- Manifest: [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json), schema `1.4.0`, 77 mandatory IDs and 77 unique entries.
- Frozen input set: [production-orchestration-frozen-build-input-set.json](evidence/production-orchestration-frozen-build-input-set.json), 26 tracked paths.
- Tracked producer: [New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1](../tools/New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1), SHA-256 `9A52D03C2C3DAF98E475761DC2CC1B30169D73C5A04A0BA233DEE050DC67FD95`, Git blob `ebbcb5357b4fc55807f55d58d4afa4006cdb8cf4`.
- New ignored evidence root: `artifacts/logs/production-orchestration-ab-tlog-provenance/`.
- Raw tlog evidence: Debug A/B and Release A/B each retain 22 raw tlogs, with zero stale/hash/tracked-retained defects.
- Producer closure evidence: each set has 9 linked object producers, 2 linked libraries, and zero missing object producers.

Production source is unchanged. The driver has never been loaded. Runtime WDF creation, target discovery, request operations, signing, installation, and hardware behavior remain unobserved.

## Recommended Objective

Perform an independent read-only audit of the schema-`1.4.0` tlog-provenance remediation checkpoint, including containing commit identity, tracked producer/source binding, frozen input-set contract, ignored retained raw tlogs, producer-closure inventories, final manifest hashes, and upstream state.

## Preconditions

1. Verify branch, HEAD, parent, exact subject, upstream, local/upstream equality, and clean worktree/index.
2. Require the containing commit parent to equal `b2a9b5cee457f69126c6f6c80615738e4ae59f31`.
3. Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, and the latest `docs/WORKLOG.md` entry.
4. Independently verify that no production source/project/solution/INF/legacy file changed in this checkpoint.
5. Rehash every manifest evidence path, the tracked producer, the tracked frozen input set, all four retained A/B SYS files, all four raw tlog inventories, and all four producer-closure files.

## Safety Restrictions

- Read-only audit only.
- Do not regenerate evidence.
- Do not run builds, tests, guards, helpers, orchestration, or WDF actions.
- Do not sign, package, create certificates/keys, stage outside Git, install, load, mutate Windows, query devices, or access USB, XUSB, a controller, or a Chatpad.
- Do not modify `legacy/`.

## Acceptance Criteria

- Remediation commit parent, subject, branch, upstream, and clean state match.
- Production source and projects exactly match frozen implementation `efb7295`; only guard/producer/docs/evidence contracts changed.
- Manifest schema is `1.4.0`.
- Guard mandatory set, top-level declaration, and entry IDs are each exactly 77, with zero missing, unexpected, or duplicate IDs/paths.
- The frozen input set has exactly 26 tracked entries, unique paths, matching implementation blob IDs, matching SHA-256 values, and exactly one prototype-INF packaging-only boundary entry.
- The tracked producer hash and Git blob match the manifest top-level producer binding.
- Each retained raw tlog inventory has `pre_build_tlog_count=0`, positive post-build count, zero stale tlogs, zero hash mismatches, zero ignored/tracked defects, required CL/LIB/LINK families, and required project coverage.
- Each producer-closure record has positive linked object count, positive consuming link tlog count, zero missing object producers, zero stale/orphan intermediates, and complete command/read/write/consumer tlog references for every linked object.
- Debug and Release A/B input inventories and comparisons remain equal by path set, content hash, build-configuration digest, and toolchain identity digest.
- Debug and Release A/B pairs remain equivalent by size, normalized PE, executable sections, imports, WDF references, normalized disassembly/symbol hashes, retention boundaries, target/request absence, and Authenticode state.
- Historical A/B evidence without retained raw tlogs is treated as historical only.
- No production source, generated artifact, runtime, deployment, or hardware action is in the remediation commit.

## Inspect First

```powershell
git branch --show-current
git log -1 --format="%H%n%P%n%s"
git status --short --untracked-files=all
git diff --exit-code
git diff --cached --exit-code
Get-Content docs\OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-TLOG-PROVENANCE-REMEDIATION.md
Get-Content docs\evidence\production-orchestration-invocation-manifest.json
Get-Content docs\evidence\production-orchestration-frozen-build-input-set.json
Get-Content tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1
Get-Content tools\Test-ChatpadProductionOrchestrationInvocation.ps1
Get-Content artifacts\logs\production-orchestration-ab-tlog-provenance\tlog-comparison-summary.log
```
