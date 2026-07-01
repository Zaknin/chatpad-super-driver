# Project State

*Last updated: 2026-07-01 (offline production orchestration invocation)*

## Current State

- **Branch:** `feature/offline-kmdf-production-orchestration-invocation`.
- **Starting checkpoint:** `4ba0de15420e0b66287a501918de694c8b6fd720`,
  `docs: close orchestration defensive taxonomy`.
- **Expected implementation commit:** the commit containing this state uses
  subject `driver: invoke production request owner orchestration`.
- **Checkpoint record:**
  [Offline KMDF Production Orchestration Invocation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md).
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
- Production orchestration guard: PASS SourceOnly and Full in Debug and
  Release. Full mode verifies manifest evidence hashes, driver identity,
  artifact containment, source constraints, context symbols, link inputs, and
  final-image forbidden-operation absence.

## Binary State

- Debug driver:
  `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys`, 32,256 bytes,
  SHA-256
  `826700E0556840D79D5A18A6C7CFA739FAF8ADEC6A9A3CF37F544187FBEAA821`,
  Authenticode `NotSigned`.
- Release driver:
  `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys`, 20,480 bytes,
  SHA-256
  `D0983260B9CAD00CD72EE3F2AE4697110AA5C13DF01F7BC2B39C0FEF891F4CB3`,
  Authenticode `NotSigned`.
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

- The new production orchestration invocation requires an independent offline
  implementation and evidence audit before any runtime, signing, packaging, or
  deployment gate.
- The driver has not been loaded; the new dormant WDF object-graph creation
  behavior is compile-validated only.
- Target discovery, request formatting, submission, completion, cancellation,
  D0/removal rundown, signing, package validation, installation, and hardware
  observation remain separate future gates.
- No usable production driver package exists.
