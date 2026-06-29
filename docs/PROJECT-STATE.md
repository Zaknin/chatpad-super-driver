# Project State

*Last updated: 2026-06-29T16:14+04:00*

## Current state

- **Branch:** `feature/offline-protocol-state-machine`, tracking
  `origin/feature/offline-protocol-state-machine`.
- **Checkpoint:** task commit named `feat: add offline protocol state machine`,
  based on `804393c9c9e1c0b976c0ad73f6f1fcc5c57de5c2`.
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
- **Tests:** 174/174 pass directly and in integrated Debug/Release x64 builds
  under Windows PowerShell 5.1.
- **User-mode artifacts:**
  - Debug library: `79B4785BEF2B1A095B2CF4C6ED24872D7B2101E6B8C50F8F4078B84BAF22B5B8`
  - Debug tests: `361E57471EB1398AF58ECF17141DF383FF0278F2E080339CCF976651B016605F`
  - Release library: `23CEB0A4D4B1E1765EFAAD53ED36F28F5846205E1C2560E8FE399726D2BDE1FA`
  - Release tests: `F53CBA3A17AAAA58FA0FFCFE077D4A48211F9A5F7282B4E1D552964AB511EC86`
- **WDK compatibility:** Debug and Release x64 static libraries compile the
  parser and state machine with exit 0; no `.sys` or signing/package output.
  - Debug: `AB85938F137AEF8E0C745B6EC65F9857F3CCC0697140867E1EE999FFFC21C284`
  - Release: `A2B9C6DF3FC4DC4D60F58D08C2DC9C59B36E010FBC0FF149890440E07CFF221B`
- **Driver regression:** Debug and Release exit 0, remain NotSigned, and run no
  signing operation.
- **Driver isolation:** `ChatpadFilter.vcxproj` has no protocol reference or
  protocol source. The solution has no dependency section. Diagnostic linker
  inputs contain neither `ChatpadProtocol.lib` nor the compatibility library.
- **Toolchain:** Visual Studio 2022 17.14.35; MSVC 14.44.35207; SDK/WDK
  10.0.26100.0; latest installed KMDF 1.35; driver target/link version 1.15.
- **Unresolved blockers:** None.
- **Safety:** PASS. `legacy/` unchanged, prohibited commit absent, generated
  files ignored beneath `artifacts/`, and no runtime/hardware behavior added.
