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
- Treat a device-specific lower filter on the physical
  `USB\VID_045E&PID_028E`/`XnaComposite` node beneath `xusb22` as a conditional
  architecture direction, not an implementation-ready capability.
- First define a kernel-safe transport-adapter interface and fully mocked,
  WDF-independent implementation.
- Keep physical transport, per-device WDF lifetime, scheduling, diagnostics,
  and keyboard presentation in separate layers with no portable-to-WDF
  dependency.
- Resolve the attachment, stack-preservation, transport-visibility,
  endpoint/input, lifecycle, recovery, and explicit-authorization gates before
  any USB request can be sent.
- Use the legacy source only as protocol and historical architecture evidence;
  do not reproduce hard-coded pipe ordinals, proxy controller reads, global
  device pointers, permissive sideband IOCTLs, or obsolete HID layering.
- Require explicit validation for every request and transfer length.

## Phase 4: Build, Sign, and Device Validation Gate

This phase is intentionally not part of the baseline task. It requires a separate approval gate before any driver build, signing, installation, Device Manager action, Secure Boot setting, Memory Integrity setting, BCD setting, driver store mutation, or live device validation.

It also requires a tested device-specific recovery procedure that restores the
Microsoft `xusb22` binding without changing class-wide filter state or
disabling Secure Boot or Memory Integrity.

## Non-Goals For This Baseline

- No claim that the legacy driver builds.
- No claim that the legacy driver works.
- No loading, installing, executing, or trusting any legacy `.sys`, `.exe`, `.dll`, coinstaller, or installer payload.
- No conversion of legacy driver code.
