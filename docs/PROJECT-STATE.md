# Project State

*Last updated: 2026-07-01 (production orchestration evidence remediation)*

## Current State

- **Branch:**
  `feature/offline-kmdf-production-orchestration-evidence-remediation`.
- **Frozen implementation commit:**
  `efb729502a0527ac70e2d20fa31a323c3beb2920`,
  `driver: invoke production request owner orchestration`.
- **Starting checkpoint:** `4ba0de15420e0b66287a501918de694c8b6fd720`,
  `docs: close orchestration defensive taxonomy`.
- **Expected implementation commit:** the commit containing this state uses
  subject `driver: invoke production request owner orchestration`.
- **Checkpoint record:**
  [Offline KMDF Production Orchestration Invocation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md).
- **Evidence-remediation record:**
  [Offline KMDF Production Orchestration Evidence Remediation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-REMEDIATION.md).
- **Evidence manifest:**
  [production-orchestration-invocation-manifest.json](evidence/production-orchestration-invocation-manifest.json).
- **Historical owner-initialization checkpoint:**
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).

## Implementation State

- `ChatpadEvtDeviceAdd` still creates the `WDFDEVICE`, initializes scalar
  context fields, initializes ordinary owner storage, and performs explicit
  pre-object validation before any lifecycle initialization.
- After that validation succeeds, `ChatpadEvtDeviceAdd` now declares a local
  zero-initialized `ChatpadKmdfRequestOwnerOrchestrationReport`, invokes
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` exactly once, cross-checks
  the function return against `report.Result`, maps failures, validates
  structural ready state, and only then continues to lifecycle initialization.
- The report is stack-local, synchronous, not embedded in the device context,
  and does not escape `EvtDeviceAdd`.
- `device.c` does not directly call individual creation helpers, rollback,
  attribute-preparation helpers, direct WDF object-management APIs, target
  discovery, request formatting, send, completion, cancellation, D0 owner
  observation, cleanup owner observation, or removal owner observation.
- The isolated KMDF request-owner context remains the owner of helper creation,
  ready publication, and pre-ready rollback.
- Independent source inspection passed. The first evidence audit failed on
  guard/manifest completeness. The separate remediation changes no production
  source and binds the immutable 14-path implementation scope and complete
  18-result mapping.

## Build and Validation State

- Toolchain verified: Visual Studio Community 2022 17.14.35, MSVC 14.44.35207,
  SDK/WDK 10.0.26100.0, KMDF 1.15, `WindowsKernelModeDriver10.0`,
  `SignMode=Off`.
- Debug driver wrapper build: PASS.
- Release driver wrapper build: PASS.
- Full solution through Visual Studio Community: PASS for Debug and Release.
- Full solution through the Build Tools MSBuild instance remains blocked by
  missing `WindowsKernelModeDriver10.0` platform toolset in that VS instance;
  this is a local Build Tools integration limitation, not a source failure.
- Request-owner model tests: PASS 5002/5002 assertions in Debug and Release.
- Protocol tests: PASS 610/610 assertions in Debug and Release.
- Transport tests: PASS 186/186 assertions in Debug and Release.
- Lifecycle tests: PASS 109/109 assertions in Debug and Release.
- Control-setup tests: PASS 141/141 assertions in Debug and Release.
- KMDF request-owner context, protocol kernel compatibility, and WDF
  control-setup compile checks: PASS in Debug and Release.
- Production linkage guard: PASS in Debug and Release.
- Production owner-initialization guard: PASS SourceOnly in Debug and Release.
  Its old Full-mode manifest is a historic prior checkpoint with intentionally
  superseded driver hashes.
- Production orchestration guard: PASS SourceOnly in Debug and Release with
  `18/18` mapped results and zero missing, duplicate, or unexpected cases.
  Full Debug/Release validation uses the schema-`1.1.0` closed mandatory
  evidence set and explicitly skips only its own changing transcript hash.
- The remediated manifest requires 42 unique evidence IDs, exact commands,
  configurations, count/metric applicability, per-entry state binding,
  repository/Git evidence, and containing-commit limitations.

## Binary State

- Debug driver:
  `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys`, 32,256 bytes,
  SHA-256
  `DD33388A3905A4C5AFCFD3FF4E3443308CC9A280BCDD094FB7ACED7478880F83`,
  Authenticode `NotSigned`.
- Release driver:
  `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys`, 20,480 bytes,
  SHA-256
  `72B30B0523B07F91A21FE8711ED846F4B355652F0E2B0FEA691F894A4304CAC5`,
  Authenticode `NotSigned`.
- Source was unchanged; the source-identical rebuild retained both sizes but
  changed hashes because the current PE build is not reproducible byte-for-byte.
- Debug object inspection exposes dormant orchestration, rollback, and WDF
  object-management evidence. Release LTCG strips ordinary named references;
  Release proof is based on audited source, link inputs, visible context
  symbols, no forced retention, and final-image absence of target/request
  operation evidence.

## Safety State

- No signing, package creation, catalog creation, staging, installation,
  driver loading, Windows mutation, hardware query, controller interaction, or
  Chatpad interaction was performed.
- No INF, deployment, recovery, target discovery, request formatting, request
  send, completion, cancellation, D0/removal owner-observer, cleanup callback,
  or destroy callback was added.
- Generated outputs and logs remain under ignored `artifacts/`.
- `legacy/` remains immutable.

## Unresolved Blockers

- The production implementation plus remediated guard/evidence checkpoint
  requires another independent read-only audit before any runtime, signing,
  packaging, or deployment gate.
- The driver has not been loaded; the new dormant WDF object-graph creation
  behavior is compile-validated only.
- Target discovery, request formatting, submission, completion, cancellation,
  D0/removal rundown, signing, package validation, installation, and hardware
  observation remain separate future gates.
- No usable production driver package exists.
