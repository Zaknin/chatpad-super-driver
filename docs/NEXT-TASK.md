# Next Task

## Exact Current State

- Branch:
  `feature/offline-kmdf-production-orchestration-evidence-finalization`.
- Required starting commit: the commit containing this file, with subject
  `test: finalize production orchestration evidence` and parent
  `33f726f68f563ec7e7e0dc1fc778a17bf85ebee9`. Obtain its hash from Git.
- Frozen production implementation:
  `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Finalization checkpoint:
  [Offline KMDF Production Orchestration Evidence Finalization](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-FINALIZATION.md).
- Manifest:
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json),
  schema `1.2.0`, 56 mandatory IDs and 56 unique entries.
- Canonical Debug set B:
  32,256 bytes,
  `5BF55C56138ABB180ACC3DB77D3CB03A8FC82DD7706926C06F342C096F76F0AA`.
- Canonical Release set B:
  20,480 bytes,
  `F7D8182D32FAFC86A3D42A414365170C8EA46404E7545351AA43AEB2EF2AEDBB`.

Production source is unchanged. The driver has never been loaded. Runtime WDF
creation, target discovery, request operations, signing, installation, and
hardware behavior remain unobserved.

## Recommended Objective

Perform an independent read-only audit of the frozen implementation, the
second evidence-finalization checkpoint, the schema-`1.2.0` manifest, all 56
ignored evidence files, retained A/B binaries and inspection outputs, the
containing commit, and final upstream state.

## Preconditions

1. Verify branch, HEAD, parent, exact subject, upstream, local/upstream
   equality, and clean worktree/index.
2. Require the containing commit parent to equal
   `33f726f68f563ec7e7e0dc1fc778a17bf85ebee9`.
3. Re-read the repository protocol and latest worklog entry.
4. Independently verify that `device.c` and all production source/project
   blobs equal implementation commit `efb7295`.
5. Rehash every manifest evidence path and all four retained A/B SYS files.

## Safety Restrictions

- Read-only audit only.
- Do not regenerate evidence.
- Do not run builds, tests, guards, helpers, orchestration, or WDF actions.
- Do not sign, package, create certificates/keys, stage outside Git, install,
  load, mutate Windows, query devices, or access USB, XUSB, a controller, or a
  Chatpad.
- Do not modify `legacy/`.

## Acceptance Criteria

- Finalization commit parent, subject, branch, upstream, and clean state match.
- Production source and projects exactly match frozen implementation
  `efb7295`.
- Manifest schema is `1.2.0`.
- Guard mandatory set, top-level declaration, and entry IDs are each exactly
  56, with zero missing, unexpected, or duplicate IDs/paths.
- Every entry has exactly one literal `command` or ordered `commands` value,
  complete metadata, an ignored existing path, and a matching SHA-256.
- KMDF semantic evidence reports 62/62, zero warnings/errors, and zero
  build/guard exits in Debug and Release.
- Repository-safety evidence contains every required counter and all are zero.
- Debug and Release A/B pairs have equal source/project/toolchain inputs,
  sizes, PE structure, normalized PE/section hashes, executable-section raw
  hashes, imports, WDF references, normalized disassembly/symbol hashes,
  retention boundaries, target/request absence, and Authenticode state.
- Normalization excludes only COFF timestamp, PE checksum, debug-directory
  timestamp, and CodeView GUID.
- Historical hashes are treated as observations only; no retroactive
  equivalence claim remains.
- Full-log and staged/candidate self-reference limits are stated honestly.
- No production source, generated artifact, runtime, deployment, or hardware
  action is in the finalization commit.

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
```
