# Porting Plan

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
- If separately authorized, design the next slice as dormant WDF object
  creation and cleanup sequencing for the request, two memory objects, and
  spinlock. Do not add runtime request formatting, submission, completion,
  cancellation, target discovery, installation, or hardware access in that
  slice unless explicitly authorized.
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

Before any deployment stage, the project also requires a tested
device-specific recovery procedure that restores the Microsoft `xusb22`
binding without changing class-wide filter state or disabling Secure Boot or
Memory Integrity.

## Non-Goals For This Baseline

- No claim that the legacy driver builds.
- No claim that the legacy driver works.
- No loading, installing, executing, or trusting any legacy `.sys`, `.exe`, `.dll`, coinstaller, or installer payload.
- No conversion of legacy driver code.
