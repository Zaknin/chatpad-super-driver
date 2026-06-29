# Project State

*Last updated: 2026-06-29T17:14+04:00*

## Current state

- **Branch:** `feature/activation-sequence-planner`, tracking
  `origin/feature/activation-sequence-planner`.
- **Starting checkpoint:** `095772352def48a6764edd11e795745096e165dc`.
- **Expected task commit:** `feat: add activation sequence planner` (this
  implementation and continuity commit).
- **Initialization/status audit:** complete. The authoritative analysis remains
  `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
- **`0x90` conclusion:** its only legacy occurrence is a tentative comment on
  an unused internal structure. It is not proven as payload or a USB setup
  field.
- **Initialization-related `0x00` conclusion:** the executable activation path
  confirms `0x00` as the second payload byte in `09 00`; the `00` beside `90`
  is not proven wire data.
- **Activation-request builder:** implemented as a transport-independent,
  caller-owned value-copy API in `ChatpadActivationRequests.h/.c`. It exposes
  exactly six confirmed request descriptors in the legacy executable order.
- **Activation-sequence planner:** implemented as a transport-independent,
  caller-owned value-copy API in `ChatpadActivationSequence.h/.c`. It exposes
  exactly six steps, one-to-one with the request builder indexes, and obtains
  each request from the builder rather than duplicating request tuples.
- **Activation sequence timing metadata:** every step has
  `DelayBeforeMilliseconds = 0` and `DelayAfterMilliseconds = 12`. The 12 ms
  value represents only the confirmed legacy executable path behavior that
  `SendControlRequest` slept after each call returned. The zero before-delay
  value means no confirmed pre-request delay metadata, not a proven no-delay
  device requirement.
- **Activation request facts:** `09 00` appears only as the confirmed outbound
  payload for request/step index 4. `90 00` is absent from every request
  descriptor, sequence step, fixture, payload, and test.
- **Sequence/response boundary:** the planner contains no response bytes,
  acknowledgement schema, readiness state, retry policy, timeout/deadline, I/O,
  USB/HID/IOCTL access, callback, hardware access, sleep, timer, allocation,
  or driver integration.
- **Portable parser:** unchanged Phase 1 five-byte raw keyboard parser.
- **Portable state machine:** unchanged caller-owned, allocation-free
  last-classification state and deterministic transition output.
- **Tests:** 443/443 pass directly and in integrated Debug/Release x64 builds.
  The total is 85 parser assertions, 89 state-machine assertions, 126
  activation-request assertions, and 143 activation-sequence assertions.
- **User-mode artifacts:**
  - Direct test executable:
    `artifacts/bin/x64/Debug/ChatpadProtocolParser/ChatpadProtocolParserTests.exe`
    SHA-256 `EEDB42AA640E3E8E1613DA08D9C6CA316A9989D815F364512B49F5E5A0051181`
  - Debug library:
    `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
    `10643A992FBD02F1AF309DEEEB602F0C9B37BA38B82DECBAA606C5198891EFBD`
  - Debug tests:
    `artifacts/bin/x64/Debug/ChatpadProtocolTests/ChatpadProtocolTests.exe`
    SHA-256 `DFE983B7D444B9950AE392B4860BD5EC8B85FE21EF8291111C5DAA68C0152E57`
  - Release library:
    `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
    `2AAFD4EDE9E52062BCCA117E75BC380A4313E77F6E0EEE8CFF398E0A9DD4F591`
  - Release tests:
    `artifacts/bin/x64/Release/ChatpadProtocolTests/ChatpadProtocolTests.exe`
    SHA-256 `20F5A79284378A267F778ED99742C78D420CE600E6C5E8CB62682CCE1E18FA4B`
- **WDK compatibility:** Debug and Release x64 static libraries compile the
  activation-sequence planner, activation-request builder, parser, and state
  machine with exit 0; only `.lib` outputs are produced.
  - Debug:
    `artifacts/bin/x64/Debug/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`
    SHA-256 `4B9E9EB3EE8262EA7AB750D0B88819A5713DA2132DD5BB8FA43E38D9CE51FCEB`
  - Release:
    `artifacts/bin/x64/Release/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`
    SHA-256 `9FF6E8086DA53EF25A180DF56D11D6CEF6AD44CDD48F61F72F0FF19B395D3853`
- **Driver regression:** Debug and Release exit 0, remain NotSigned, and run no
  signing operation.
  - Debug:
    `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys` SHA-256
    `5E66DFC2BF9E83CADF4F369E7588D8E9609AB2B0D42F793B3FB9C4E411C11E2B`
  - Release:
    `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` SHA-256
    `C7E745D94AFDFC6C058F00B56700C9401A8EAB96CB8F211B3E65AFAFBB15997D`
- **Driver isolation:** `ChatpadFilter.vcxproj` has no protocol project
  reference and no protocol source, including no activation-sequence or
  activation-request source. Diagnostic linker inputs contain driver objects
  and WDK/KMDF libraries only; neither `ChatpadProtocol.lib` nor
  `ChatpadProtocolKernelCompileCheck.lib` is linked into `ChatpadFilter`.
- **Toolchain:** Visual Studio 2022 17.14.35; MSVC 14.44.35207; SDK/WDK
  10.0.26100.0; latest installed KMDF 1.35; driver target/link version 1.15.
- **Unresolved blockers:** Response bytes, `f0` packet meaning, the three
  mystery setup requests, periodic request semantics, and objective ready
  conditions remain unresolved.
- **Safety:** PASS. `legacy/` unchanged, prohibited commit absent, generated
  files ignored beneath `artifacts/`, and no runtime, hardware, USB, HID,
  IOCTL, installation, signing, packaging, deployment, loading, capture,
  external-skill, or driver-runtime action occurred.
