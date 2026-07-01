# Project State

*Last updated: 2026-07-01 (production orchestration input-identity remediation)*

## Current State

- **Branch:**
  `feature/offline-kmdf-production-orchestration-input-identity-remediation`.
- **Starting commit:**
  `d22867f86917a6c81574b5f82d19aacd9984b213`,
  `test: finalize production orchestration evidence`.
- **Frozen implementation commit:**
  `efb729502a0527ac70e2d20fa31a323c3beb2920`,
  `driver: invoke production request owner orchestration`.
- **Expected containing commit:** subject
  `test: complete production orchestration input identity evidence`; obtain
  its hash from Git after commit.
- **Finalization record:**
  [Offline KMDF Production Orchestration Evidence Finalization](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-FINALIZATION.md).
- **Manifest:**
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json),
  schema `1.3.0`.

## Implementation State

- `ChatpadEvtDeviceAdd` creates the `WDFDEVICE`, initializes ordinary owner
  storage, validates the pre-object baseline, and invokes
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` exactly once before
  lifecycle initialization.
- The synchronous report is stack-local. Production cross-checks function and
  report results, maps all 18 outcomes, and requires structural ready state
  before continuing.
- Production source/header, isolated request-owner source/header, model,
  protocol, transport, lifecycle, D0/removal, projects, solution, and INF are
  unchanged from implementation commit `efb7295`.
- The second evidence audit found five evidence-fidelity defects, not a
  production-source defect. The finalization adds a top-level mandatory set,
  exact ordered commands, explicit semantic/safety counters, and a retained
  A/B rebuild.

## Build and Validation State

- Toolchain: Visual Studio Community 2022 17.14.35, MSVC 14.44.35207,
  SDK/WDK 10.0.26100.0, KMDF 1.15,
  `WindowsKernelModeDriver10.0`, `SignMode=Off`.
- Complete-input-identity A/B wrapper builds: PASS for Debug A/B and Release
  A/B. Debug inventories contain 116 inputs; Release inventories contain 118.
  Both configurations report zero missing, extra, hash-mismatched,
  unresolved, duplicate, configuration-mismatched, or toolchain-mismatched
  inputs.
- Production orchestration SourceOnly and Full guards: PASS in Debug and
  Release.
- Mandatory evidence: 62 guard IDs, 62 manifest-declared IDs, and 62 entries;
  zero missing, unexpected, duplicate, metadata, path, or non-self hash
  defects.
- KMDF request-owner semantic/build guard: PASS 62/62 in Debug and Release,
  with zero warnings/errors and zero build/guard exit codes.
- Repository safety: PASS with all deployment, signing, packaging,
  certificate/key, Windows mutation, device query, hardware, tracked artifact,
  and evidence-containment counters zero.
- Retained baseline results remain request-owner model 5002/5002, protocol
  610/610, transport 186/186, lifecycle 109/109, and control setup 141/141 in
  Debug and Release.
- Retained Community full-solution builds remain PASS in Debug and Release.
  The Build Tools instance remains blocked by three `MSB8020` errors because it
  lacks `WindowsKernelModeDriver10.0`.

## Binary State

- A/B Debug raw hashes differ but normalize to
  `18656A2A1EC059E1D84F353B386400D7B79E3C4C37B6407364609DEB09433E50`;
  executable-section bytes and retained behavior evidence are equal.
- A/B Release raw hashes differ but normalize to
  `F87A4B3FB662D245856104AFB53027502B54AAE2018A596491521160A98B9A6C`;
  executable-section bytes and retained behavior evidence are equal.
- Final canonical Debug set B: 32,256 bytes,
  `F05357700DCC71125CFA2583867B422E2E8E5A8E26FD3FA0AFCE5370AF5F8D7B`,
  x64 Native, `NotSigned`.
- Final canonical Release set B: 20,480 bytes,
  `5313E60CB503EBB4FA129D21CB26E1832E32FDE7E1F923D5C8E802D1D74D3905`,
  x64 Native, `NotSigned`.
- Earlier binary hashes are historical observations only. The earlier files
  are unavailable, so exact equivalence cannot be retroactively proven.

## Safety State

- No signing, package/catalog creation, certificate/key creation, staging,
  installation, driver loading, Windows mutation, device query, hardware
  access, USB/XUSB/controller action, or Chatpad interaction occurred.
- No target discovery, request formatting/submission/completion/cancellation,
  D0/removal owner observer, cleanup callback, or destroy callback was added.
- Generated binaries, PDBs, dumps, and logs remain ignored under
  `artifacts/`.
- `legacy/` remains immutable.

## Unresolved Blockers

- Another independent read-only audit must verify the input-identity
  remediation commit, upstream state, all 62 manifest paths/hashes, Full-log
  self-reference limits, retained input inventories, and retained A/B
  normalization.
- The driver has never been loaded; dormant WDF graph creation is
  compile/link/offline validated only.
- Target discovery, request operations, runtime rundown, signing, package
  validation, installation, and hardware observation remain separate future
  gates.
- No usable production driver package exists.
