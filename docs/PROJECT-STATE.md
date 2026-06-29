# Project State

*Last updated: 2026-06-29T16:56+04:00*

## Current state

- **Branch:** `feature/activation-request-builder`, tracking
  `origin/feature/activation-request-builder`.
- **Starting checkpoint:** `782e8e15037af1ec524b69ee38003977d3b99fa5`.
- **Expected task commit:** `feat: add declarative activation request builder`
  (this implementation and continuity commit).
- **Initialization/status audit:** complete. The authoritative analysis is
  `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
- **`0x90` conclusion:** its only legacy occurrence is a tentative comment on
  an unused internal structure. It is not proven as payload or a USB setup
  field.
- **Initialization-related `0x00` conclusion:** the executable activation path
  confirms `0x00` as the second payload byte in `09 00`; other nearby zeros are
  setup fields, buffer defaults, internal state, or comments. The `00` beside
  `90` is not proven wire data.
- **Sequence/response boundary:** the legacy software call sequence is
  traceable, but no complete semantically confirmed initialization protocol,
  acknowledgement, status format, retry policy, or objective ready condition
  is known.
- **Activation-request builder:** implemented as a transport-independent,
  caller-owned value-copy API in `ChatpadActivationRequests.h/.c`. It exposes
  exactly six confirmed request descriptors in the legacy executable order and
  performs no I/O, allocation, transport access, mutable global state, retry,
  timeout, acknowledgement, ready-state, or response decoding.
- **Activation request facts:** `09 00` appears only as the confirmed outbound
  payload for request index 4. `90 00` is absent from every request descriptor,
  fixture, payload, and test.
- **Portable parser:** unchanged Phase 1 five-byte raw keyboard parser.
- **Portable state machine:** caller-owned, allocation-free last-classification
  state and deterministic transition output.
  - States: awaiting classification, accepted keyboard data, unsupported input,
    policy rejected, and unresolved control/status.
  - Events: accepted keyboard packet, unsupported packet, policy-rejected
    packet, unresolved control/status, and explicit reset.
  - Parser mapping: `OK`, unsupported type, and policy-rejected modifier map to
    events. Argument/length failures remain unclassified and do not transition.
- **Evidence boundary:** unresolved control/status is an abstract caller event,
  not a decoded wire packet. Raw initialization/status interpretation remains
  unresolved; semantic key mappings remain absent.
- **Tests:** 300/300 pass directly and in integrated Debug/Release x64 builds.
- **User-mode artifacts:**
  - Debug library: `4F337A31B8E3657865606423ECB2DE80510432EFA0BFFFDA2C70E6E5D8063989`
  - Debug tests: `A9869E027C9C1D14EB03C36CCA931207DC05F78558DD60E48D2BD5A26A5016AA`
  - Release library: `3B82C72AD836A236B30F5067509748F0422E4657D0A931FD0177BB61A85821E4`
  - Release tests: `2A8000A9D1EA214AE27DB477A2914DD0E511D36A385B8A43493BFD3B81172505`
- **WDK compatibility:** Debug and Release x64 static libraries compile the
  activation-request builder, parser, and state machine with exit 0; no `.sys`
  or signing/package output.
  - Debug: `54ED65B1B7DDEE19218153D6B258CE12AA7CF8A9A76D378960FCB750AA76DB1B`
  - Release: `925E08541617E52FEB70D9C974E49797C8FDC9E2A079D7A722345895A5245592`
- **Driver regression:** Debug and Release exit 0, remain NotSigned, and run no
  signing operation.
  - Debug: `9e01f44b37c45141a6cb1f67941edd1a08cf6a66d3d663a47131e35e081bedfd`
  - Release: `1f1a81fb5e4392ad640c97d1c6c5b11972e66b55b5773732e8a3d9c217ad7b9b`
- **Driver isolation:** `ChatpadFilter.vcxproj` has no protocol reference or
  protocol source, including no activation-request source. The solution has no
  dependency section. Diagnostic linker inputs contain neither
  `ChatpadProtocol.lib` nor the compatibility library.
- **Toolchain:** Visual Studio 2022 17.14.35; MSVC 14.44.35207; SDK/WDK
  10.0.26100.0; latest installed KMDF 1.35; driver target/link version 1.15.
- **Unresolved blockers:** Response bytes, `f0` packet meaning, the three
  mystery setup requests, inter-request timing policy, and periodic request
  semantics remain unresolved.
- **Safety:** PASS. `legacy/` unchanged, prohibited commit absent, generated
  files ignored beneath `artifacts/`, and no runtime, hardware, USB, HID,
  IOCTL, installation, signing, packaging, deployment, loading, capture, or
  external-skill action occurred.
