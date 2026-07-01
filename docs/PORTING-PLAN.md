# Porting Plan

## Current runtime-observation planning gate (2026-07-01)

The offline production-orchestration evidence is accepted at commit
`4c84891ca24ef969664f53fd5e9ec2a697f2edb9` after `AUDIT PASS WITH
LIMITATIONS`. The evidence manifest is schema `1.6.0` with 102 mandatory
entries. The 26-path production runtime/link contract is separate from the
32-path A/B wrapper-build contract. Four isolated clean builds retain exact raw
TLOG roots, objects, libraries, PDBs, parser output, and same-set closure.

The current phase is first-runtime observation and recovery planning. The plan
is in `docs/WINDOWS11-FIRST-RUNTIME-OBSERVATION-AND-RECOVERY-PLAN.md` and
selects offline runtime instrumentation design as the next gate because the
current build is not sufficiently observable for first controlled load. Runtime
observation, target discovery, request execution, signing, packaging,
installation, loading, device query, and hardware testing remain prohibited
future gates.

Current phase: **Offline runtime instrumentation design - independent
acceptance pending**.

The original offline runtime instrumentation design was committed at
`b26514f59e9d07fbee09e8bab5ea296d18c0dd85`. Its independent audit returned
`AUDIT FAIL` for documentation-only defects: incomplete per-event metadata and
premature continuity advancement to implementation. The remediated design is in
`docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`. It preserves WPP
software tracing as the primary first-load diagnostic mechanism, keeps existing
`KdPrintEx` statements as fallback only, preserves the 73-event catalogue, and
requires Release-capable diagnostic evidence before any runtime gate can open.
The next task is independent read-only audit of the remediated design. Source
implementation is not authorized; signing, packaging, staging, installation,
loading, device query, and hardware testing remain closed.

This plan starts from the preserved source-only baseline. It intentionally does not load, install, execute, or test any legacy binary.

## Phase 0: Preserve and Audit

- Keep the historical snapshot under `legacy/source_release_0_0_4a/`.
- Keep forbidden binaries, generated archives, and extracted audit inputs ignored.
- Use `docs/SOURCE-INVENTORY.md`, `docs/LEGACY-ARCHITECTURE.md`, and `docs/WIN11-BLOCKERS.md` as the source-review baseline.

Exit criteria:

- Forbidden-binary staged scan is clean.
- The legacy snapshot file count remains 68.
- No legacy driver source has been converted or modified.

## Phase 1: Protocol Fixtures

- Extract packet examples from preserved source comments and user-mode parsing paths.
- Create protocol fixture files under `tests/fixtures/`.
- Implement user-mode parser tests that validate packet length, endpoint identity, filter mode, and malformed input behavior.

Source references:

- Filter IOCTL definitions: `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h:21-90`
- Fixed endpoint buffer lengths: `legacy/source_release_0_0_4a/filter/chatpad_filter.h:66-76`
- Controls and chatpad request state: `legacy/source_release_0_0_4a/filter/chatpad_filter.h:147-174`

## Phase 2: Modern User-Mode Prototype

- Build a user-mode parser and state machine in `src/` with no dependency on legacy binaries.
- Model controls filtering, chatpad packet decoding, and virtual keyboard/mouse output intent.
- Use tests to lock behavior before any kernel implementation exists.

## Phase 3: Windows 11 Driver Design

- Use `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md` as the authoritative
  attachment and lifetime design.
- Use `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md` as the authoritative
  bridge design between the portable activation executor, the neutral transport
  adapter, and a future per-device KMDF request owner.
- Use `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md` as the
  authoritative design for the first future asynchronous activation request,
  its reusable per-device slot, request-parented two-byte outbound/inbound
  memory, exact-once lifecycle ownership, and send/completion/cancellation
  races.
- Treat a device-specific lower filter on the physical
  `USB\VID_045E&PID_028E`/`XnaComposite` node beneath `xusb22` as a conditional
  architecture direction, not an implementation-ready capability.
- First define a kernel-safe transport-adapter interface and fully mocked,
  WDF-independent implementation.
- Next define pure, WDF-independent control-setup translation for the six
  confirmed activation descriptors before any WDF request formatting or
  submission code exists.
- Convert that pure value to the installed
  `WDF_USB_CONTROL_SETUP_PACKET` only in an isolated compile-only static
  library. This checkpoint is complete.
- Compile the authoritative activation sequence, pure translator, and WDF
  formatter into one dormant `ChatpadFilter` preparation module. This offline
  integration checkpoint is complete: all six steps produce caller-owned data,
  and no runtime callback invokes the API.
- Complete the request-owner and transfer-buffer lifetime design before adding
  WDF object definitions or runtime code. This documentation checkpoint is
  complete and selects one reusable device-parented activation request plus
  separate request-parented two-byte outbound and inbound memory objects.
- The pure, WDF-independent request-owner state model checkpoint is complete
  under `src/transport/ChatpadRequestOwnerModel/` with exhaustive offline
  race/accounting tests. It emits effects only and creates no WDF objects or
  production-driver behavior.
- The compile-only KMDF request-owner context-definition checkpoint is complete
  under `src/driver/ChatpadKmdfRequestOwnerContext/`. It defines the future
  owner and request-context layouts, exact two-byte transfer storage, WDF
  handle fields, context declaration, and attribute compile checks without
  object creation, formatting, submission, callbacks, or runtime behavior.
- The design-only dormant KMDF object-creation and cleanup checkpoint is
  complete in
  `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`. It selects future
  creation immediately after successful `WdfDeviceCreate` in `EvtDeviceAdd`,
  with a device-parented spinlock, device-parented reusable request,
  request-parented outbound/inbound preallocated memory, explicit
  initialization-failure rollback, no cleanup/destroy callbacks, and no target
  at request creation.
- The isolated ordinary KMDF request-owner storage initialization checkpoint is complete
  in `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`. It initializes only
  ordinary owner storage, embeds the pure model baseline, clears fixed
  two-byte transfer/completion storage, leaves future WDF handles null, and
  sets only `MODEL_READY`; it creates no WDF object. At that historical
  isolated checkpoint, the helper remained absent from `ChatpadFilter`.
- The compile-only KMDF object-attribute preparation checkpoint is complete in
  `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`. Four exact helpers encode
  device parentage for the lock/request, request parentage for both memory
  descriptors, typed context only for the request, inherited execution level,
  no automatic synchronization, and no cleanup/destroy callback.
- The compile-only dormant lock/request creation checkpoint is complete in
  `docs/OFFLINE-KMDF-LOCK-REQUEST-CREATION.md`. The isolated module contains
  exactly one spinlock create call and one targetless request create call,
  deterministic typed-context initialization, and partial-state validation.
  Static-library validation never invokes either helper.
- The compile-only dormant creation orchestration checkpoint is complete in
  `docs/OFFLINE-KMDF-CREATION-ORCHESTRATION.md`. It composes the existing
  lock, request, outbound-memory, inbound-memory, validation, and rollback
  helpers into one all-or-nothing helper and publishes structural
  `OWNER_READY` only after complete validation. The orchestration helper
  remains uncalled by production `ChatpadFilter` and unexecuted.
- The documentation-only production-integration design checkpoint is complete
  in `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`. It selects native
  static-library project linkage as the first production slice, one embedded
  owner in the device context, ordinary storage initialization after current
  context scalar setup, dormant orchestration at the same `EvtDeviceAdd` point
  before lifecycle initialization, framework cleanup for later post-ready
  `EvtDeviceAdd` failure, JSON evidence manifests, and independently gated
  implementation slices.
- The project-linkage-only dormant production checkpoint is complete in
  `docs/OFFLINE-KMDF-PRODUCTION-LINKAGE.md`, with tracked evidence in
  `docs/evidence/production-linkage-manifest.json`. At that historical
  checkpoint, `ChatpadFilter` gained one native static-library project
  reference to `ChatpadKmdfRequestOwnerContext`; no production source/header
  integration, owner embedding, helper invocation, WDF object creation, or
  runtime behavior change occurred.
- The production owner embedding and ordinary-initialization checkpoint is
  complete in `docs/OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md`, with
  tracked evidence in
  `docs/evidence/production-owner-initialization-manifest.json`. Current
  production `driver.h` includes the authoritative request-owner context
  header, the per-device context embeds exactly one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`, and
  `EvtDeviceAdd` calls the ordinary initializer exactly once. The initializer
  validates the newly initialized storage internally, after which
  `EvtDeviceAdd` performs one additional explicit pre-object
  integration-boundary validation before lifecycle initialization.
- The offline production orchestration-invocation checkpoint is complete in
  `docs/OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION.md`, with tracked
  evidence in
  `docs/evidence/production-orchestration-invocation-manifest.json`. Current
  production `EvtDeviceAdd` now invokes
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` exactly once after
  explicit pre-object validation and before lifecycle initialization, using a
  stack-local report, return/report cross-checking, status mapping, and
  structural-ready validation. This was compile/link/offline validation only;
  no driver was loaded and no runtime WDF graph was observed.
- The separate production orchestration evidence-remediation checkpoint
  preserves that source unchanged while binding the immutable implementation
  scope, all 18 result mappings, mandatory evidence metadata/IDs, KMDF semantic
  guard output, repository safety, staged/unstaged state, and containing-commit
  limitations. It is evidence progress only, not runtime progress.
- The second production orchestration evidence-finalization checkpoint
  preserves production source again, upgrades the manifest to schema `1.2.0`
  with 56 top-level mandatory IDs, records exact ordered retention commands and
  explicit semantic/safety counters, and replaces an unprovable historical
  binary comparison with a retained source-identical A/B rebuild. It remains
  evidence-only; runtime, target/request, signing, installation, and hardware
  gates are closed.
- The owner-initialization audit-corrections checkpoint is complete in
  `docs/OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md`. It corrected
  documentation, guard wording, and retained evidence without changing
  production implementation. This documentation-consistency correction cleans
  up stale current-state wording left in the production integration design and
  porting roadmap.
- Before any INF or runtime bridge work, design and review a reversible,
  device-specific lower-filter installation and recovery procedure for
  `USB\VID_045E&PID_028E`.
- Use `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md` as the authoritative
  design for a future exact-ID extension INF, declarative lower-filter
  placement, package identity, staged authorization, and rollback. Treat its
  documentation checkpoint as incomplete until independently reviewed against
  an actual signed package and demonstrated on a noncritical system.
- Keep the validated extension INF prototype isolated under
  `prototypes/inf/ChatpadFilterExtension/`. Static `InfVerif` success completes
  the source-syntax checkpoint. The ignored offline package-layout and Inf2Cat
  catalog-closure checkpoint is complete and recorded in
  `docs/OFFLINE-INF2CAT-PACKAGE-VALIDATION.md`; signing, staging, installation,
  effective runtime placement, and device behavior remain separate gates.
- Keep physical transport, per-device WDF lifetime, scheduling, diagnostics,
  and keyboard presentation in separate layers with no portable-to-WDF
  dependency.
- Keep activation request ownership separate from future continuous input;
  neither request handles nor transfer buffers may be shared.
- Resolve the attachment, stack-preservation, transport-visibility,
  endpoint/input, lifecycle, recovery, and explicit-authorization gates before
  any USB request can be sent.
- Use the legacy source only as protocol and historical architecture evidence;
  do not reproduce hard-coded pipe ordinals, proxy controller reads, global
  device pointers, permissive sideband IOCTLs, or obsolete HID layering.
- Require explicit validation for every request and transfer length.

## Phase 4: Independent Package, Trust, Deployment, and Runtime Gates

Phase 4 is outside the baseline task and is divided into independent bounded
stages:

1. build and package preparation;
2. signing and trust preparation;
3. package staging only;
4. post-staging package-identity capture and exact package/target matching;
5. attachment, restart, or driver loading;
6. passive post-load stack and preservation observation;
7. active USB or Chatpad interaction;
8. production and release qualification.

Only unsigned offline package/catalog closure is complete. Signing, staging,
Windows acceptance, effective lower-filter placement, `xusb22` preservation,
controller behavior, and Chatpad behavior remain incomplete and unauthorized.
Completion or authorization of one stage does not authorize the next stage.
Each stage requires its own reviewed evidence, explicit authorization, stop
conditions, and recovery boundary.

The offline request-owner preparation path now includes device-parented
lock/request creation, request-parented outbound/inbound preallocated-memory
creation, request-first/spinlock-second rollback, all-or-nothing
structural-ready orchestration, production project linkage, owner embedding,
ordinary initializer integration, explicit pre-object validation, and the first
production call into the dormant orchestrator. The production context embeds
one authoritative owner and now calls ordinary initialization, explicit
pre-object validation, dormant orchestration, and structural-ready validation
before lifecycle initialization. The portable model source is linked as a WDK
object; the isolated KMDF context source still comes only from its
static-library project. This offline checkpoint does not authorize driver
loading, target discovery, request formatting/submission/completion/
cancellation, D0/removal rundown, signing, staging, installation, Windows
mutation, or hardware validation.

Before any deployment stage, the project also requires a tested
device-specific recovery procedure that restores the Microsoft `xusb22`
binding without changing class-wide filter state or disabling Secure Boot or
Memory Integrity.

## Non-Goals For This Baseline

- No claim that the legacy driver builds.
- No claim that the legacy driver works.
- No loading, installing, executing, or trusting any legacy `.sys`, `.exe`, `.dll`, coinstaller, or installer payload.
- No conversion of legacy driver code.
