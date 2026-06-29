# Worklog

*Entries are appended chronologically. Do not rewrite or delete valid historical entries.*

## 2026-06-29T11:25Z — Protocol integration verification (session 3)

- **Objective:** Verify applied script changes and run full builds (parser + protocol + driver)
- **Starting branch and commit:** `test/protocol-fixtures` / `664aa66bfb5bfca8c8319…`
- **Investigation:** Confirmed all changes applied to working tree (ChatpadWin11.sln, Directory.Build.props, Build-Driver.ps1, ChatpadFilter.vcxproj). Driver builds ChatpadProtocol as dependency, then builds ChatpadFilter separately with its own IntDir/OutDir.
- **Files modified:** 7 files modified, 3 files untracked (ChatpadProtocol.vcxproj, ChatpadProtocolTests.vcxproj, Test-ChatpadProtocol.ps1)
- **Commands and tests run:**
  - `pwsh -File tools/Test-ChatpadProtocolParser.ps1` — 85/85 passed
  - `pwsh -File tools/Test-ChatpadProtocol.ps1 -Configuration Debug` — 85/85 passed
  - `pwsh -File tools/Test-ChatpadProtocol.ps1 -Configuration Release` — 85/85 passed
  - `pwsh -File tools/Build-Driver.ps1 -Configuration Debug -Platform x64` — PASS, 0 warnings, 0 errors
  - `pwsh -File tools/Build-Driver.ps1 -Configuration Release -Platform x64` — PASS, 0 warnings, 0 errors
  - Confirmed ChatpadFilter linker dependencies: ntoskrnl, hal, wmilib, WdfLdr, WdfDriverEntry, BufferOverflowFastFailK (no ChatpadProtocol.lib linked)
  - Confirmed SpectreMitigation=Spectre inherited from Directory.Build.props
- **Generated artifacts:** All under `artifacts/` (ignored by Git)
- **Results:** All 4 build/test configurations pass. Parser 85/85 assertions in all configurations. Driver builds cleanly with Spectre mitigation. No SignTool execution. Repository safety passes.

## 2026-06-29T14:30Z — Continuity repair: close protocol integration checkpoint

- **Objective:** Repair stale continuity documents, restore removed durable decisions, correct project dependency representation, validate, commit, and push.
- **Starting branch and commit:** `test/protocol-fixtures` / `969990ca9e532643b750a3fc1820a4c31770fd44`
- **Investigation:** HEAD was at 969990c (not 664aa66 as PROJECT-STATE.md claimed). Prohibited commit 6502452 confirmed not an ancestor of HEAD. Pre-integration DECISIONS.md recovered from parent commit 664aa66. ChatpadProtocolTests.vcxproj used hardcoded AdditionalDependencies/AdditionalLibraryDirectories with a redundant SolutionDependencies section in the sln.
- **Files modified:**
  - `docs/PROJECT-STATE.md` — updated HEAD to full commit hash, removed "no new commit" language, added dependency relationship and implementation state sections.
  - `docs/NEXT-TASK.md` — replaced stale commit instruction with next bounded task (kernel-safe shared protocol interface boundary design), updated starting commit, safety restrictions, and acceptance criteria.
  - `docs/DECISIONS.md` — restored 4 historical durable decisions from commit 664aa66, appended 4 new integration decisions (protocol build integration, SignTool detection expansion, PowerShell 5.1 compatibility, native ProjectReference).
  - `tests/protocol/ChatpadProtocolTests.vcxproj` — replaced hardcoded AdditionalDependencies/AdditionalLibraryDirectories with native ProjectReference to ChatpadProtocol.vcxproj (GUID {A1B2C3D4-E5F6-4789-ABCD-EF0123456789}).
  - `ChatpadWin11.sln` — removed redundant SolutionDependencies section (ProjectReference handles build ordering).
- **Commands and tests run:**
  - `pwsh -File tools/Test-ChatpadProtocolParser.ps1` — 85/85 passed
  - `pwsh -File tools/Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64` — MSBuild exit 0, test exit 0, 85/85
  - `pwsh -File tools/Test-ChatpadProtocol.ps1 -Configuration Release -Platform x64` — MSBuild exit 0, test exit 0, 85/85
  - `pwsh -File tools/Build-Driver.ps1 -Configuration Debug -Platform x64` — exit 0, NotSigned, no SignTool
  - `pwsh -File tools/Build-Driver.ps1 -Configuration Release -Platform x64` — exit 0, NotSigned, no SignTool
  - `pwsh -File tools/Test-RepositorySafety.ps1` — PASS
  - `git diff --check` — clean
  - `git diff HEAD -- legacy/` — no changes
  - `git merge-base --is-ancestor 6502452 HEAD` — confirmed not ancestor
- **Validation results:** All builds pass, all safety checks pass, no generated output tracked, legacy/ untouched, parser not linked into driver.
- **Commit:** `docs: close protocol integration checkpoint`
- **Push:** `origin/test/protocol-fixtures`
- **Remaining risks or limitations:** None.

## 2026-06-29T16:01+04:00 — Kernel-safe shared protocol interface and WDK compile check

- **Objective:** Create a portable shared protocol type/interface boundary,
  prove the complete five-byte parser compiles under the x64 WDK toolchain in
  Debug and Release without linking it into `ChatpadFilter`, run all parser and
  driver regressions, update continuity, commit, and push.
- **Starting branch and commit:**
  `feature/kernel-safe-protocol-interface` /
  `c18b40b2c66ec9c529567ae2df3d01e3a233b6b8`; clean and aligned with
  `origin/feature/kernel-safe-protocol-interface`.
- **Continuity discrepancy:** At start, `PROJECT-STATE.md` and `NEXT-TASK.md`
  still named the prior `test/protocol-fixtures` checkpoint. Project state also
  listed only KMDF 1.15. Live detection found installed KMDF headers/libraries
  through 1.35, while driver diagnostic linker input confirms the existing
  `ChatpadFilter` target remains KMDF 1.15. The continuity files now state both
  facts explicitly.
- **Investigation:** The existing parser exposed types and the function in one
  header and included MSVC standard integer/size headers. A first strict WDK
  compile correctly failed because MSVC user-mode `stdint.h` collided with the
  WDK kernel CRT. Protocol-owned `ChatpadUInt8` and `ChatpadSize` aliases fixed
  the boundary without WDK types or warning suppression. A second WDK compile
  exposed `NULL` as an undeclared standard-header dependency; private parser
  pointer checks now use the C null pointer constant `0`, preserving behavior.
- **Files created:**
  - `src/protocol/ChatpadProtocol/ChatpadProtocolTypes.h`
  - `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.c`
  - `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.vcxproj`
  - `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`
  - `tools/Test-ChatpadProtocolKernelCompatibility.ps1`
- **Files modified:** `ChatpadWin11.sln`, `docs/BUILDING.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, `docs/PROJECT-STATE.md`,
  `docs/TOOLCHAIN.md`, `docs/WORKLOG.md`,
  `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.c`,
  `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.h`,
  `src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj`, and
  `src/protocol/ChatpadProtocol/README.md`.
- **Implementation:** Shared public types require no Windows or WDK API and use
  no packing, allocation, exceptions, STL, RTTI, templates, handles, transport
  state, retained pointers, or mutable globals. The compatibility project
  compiles the full parser and a consumer as C with `/W4 /WX`, produces only a
  static `.lib` under `artifacts/`, and has no entry point. The solution adds
  only Debug/Release x64 mappings and no project dependencies.
- **Toolchain detection:** exit 0; Visual Studio 2022 17.14.35; MSVC
  14.44.35207; SDK/WDK 10.0.26100.0; latest installed KMDF 1.35; x64 Spectre
  libraries 14.44.35207.
- **Commands and verified results:**
  - `tools/Get-DriverBuildEnvironment.ps1` — exit 0.
  - `tools/Test-RepositorySafety.ps1` — PASS before implementation and during
    every build/test wrapper.
  - `git diff --exit-code HEAD -- legacy/` — exit 0.
  - `git merge-base --is-ancestor 6502452 HEAD` — exit 1, confirmed not ancestor.
  - `tools/Test-ChatpadProtocolParser.ps1` — exit 0, 85/85.
  - `tools/Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64` —
    MSBuild exit 0, test exit 0, 85/85.
  - `tools/Test-ChatpadProtocol.ps1 -Configuration Release -Platform x64` —
    MSBuild exit 0, test exit 0, 85/85.
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Debug -Platform x64`
    — MSBuild exit 0; library
    `artifacts/bin/x64/Debug/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`;
    SHA-256 `804A41BFF6CC57F980A7E35950091E0599B821C370EAB152EBA0ECE452079FA5`.
  - Same Windows PowerShell 5.1 command with `Release` — MSBuild exit 0;
    library
    `artifacts/bin/x64/Release/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`;
    SHA-256 `848AE61D1B9F27F49E9F0AC51E94DF804AB0D5D059977A1DB7938AEC8B9DEE33`.
  - `tools/Build-Driver.ps1 -Configuration Debug -Platform x64` — exit 0,
    NotSigned, no SignTool; SHA-256
    `44bbeab24279397609d8f07fee63bb4ee0a71f4683c3980fb3738794c71ecdff`.
  - `tools/Build-Driver.ps1 -Configuration Release -Platform x64` — exit 0,
    NotSigned, no SignTool; SHA-256
    `96848ec8d743828b79a6c20c93c3f33fe7258ee78fda071a475bfcd4fc110552`.
- **Failed checks retained honestly:** Initial WDK builds failed first on the
  `stdint.h`/kernel-CRT warning collision and then on undeclared `NULL`; both
  boundary dependencies were removed before successful reruns. The first
  Windows PowerShell 5.1 run failed because `ConvertFrom-Json` returned a
  nested installation array; the script now flattens it and both 5.1 reruns
  pass. One ad hoc summary wrapper passed named arguments positionally and
  printed a stale zero after binding errors; those results were discarded and
  both integrated commands were rerun directly with exit 0 and 85/85.
- **Driver isolation proof:** `ChatpadFilter.vcxproj` has no `ProjectReference`,
  parser source, or compatibility source. `ChatpadWin11.sln` has no
  `ProjectDependencies` section. Debug/Release diagnostic linker commands use
  `driver.obj`, `device.obj`, kernel libraries, and KMDF 1.15 libraries only;
  neither `ChatpadProtocol.lib`, the compatibility `.lib`, nor the parser
  symbol is present.
- **Safety result:** No `.sys` was created by the compatibility project; no
  signing task ran; no output escaped `artifacts/`; no INF, CAT, certificate,
  package, service, installer, or deployment file was added. No USB, HID,
  IOCTL, device, PnP, power, callback, injection, transport, or hardware code
  was introduced. Nothing was installed, signed, packaged, deployed, loaded,
  or tested against hardware. `legacy/` and external skills were not modified.
- **Generated artifacts:** All build outputs and diagnostic logs are beneath
  ignored `artifacts/` and are not committed.
- **Commit and push:** Commit exactly
  `build: add kernel-safe protocol interface check`; push only
  `origin/feature/kernel-safe-protocol-interface`.
- **Remaining risks or limitations:** Compile compatibility only. The parser is
  not connected to runtime driver code; unresolved protocol fields remain raw.

## 2026-06-29T16:14+04:00 — Offline protocol state machine

- **Objective:** Add an evidence-constrained, transport-independent protocol
  state machine using synthetic offline classifications, preserve parser
  behavior, compile through user and WDK toolchains, prove driver isolation,
  update continuity, commit, and push.
- **Starting branch and commit:**
  `feature/offline-protocol-state-machine` /
  `804393c9c9e1c0b976c0ad73f6f1fcc5c57de5c2`; clean and aligned with origin.
- **Continuity discrepancy:** The parent continuity files correctly described
  the completed kernel-interface branch rather than this newly prepared branch.
  They were updated to the live branch and current objective before handoff.
- **Investigation:** `docs/CHATPAD-PROTOCOL.md` proves the existing five-byte
  keyboard packet and only the presence of `0x90, 0x00` in an internal legacy
  structure. It does not prove a complete initialization sequence, status
  codes, readiness, retry/timeout policy, or transport behavior. Therefore the
  state machine accepts neutral caller classifications and performs no raw
  initialization/status decoding.
- **Files created:**
  - `src/protocol/ChatpadProtocol/ChatpadProtocolStateMachine.h`
  - `src/protocol/ChatpadProtocol/ChatpadProtocolStateMachine.c`
  - `tests/protocol/ChatpadProtocolStateMachineTests.h`
  - `tests/protocol/ChatpadProtocolStateMachineTests.c`
  - `tests/protocol/fixtures/ChatpadProtocolStateMachineFixtures.h`
- **Implementation:** Caller-owned state records awaiting classification,
  accepted keyboard data, unsupported input, policy-rejected input, or
  unresolved control/status. Explicit events include reset. Transition output
  records previous/current state, applied event, and whether state changed.
  Null pointers, invalid states/events, and invalid parser enum values are
  rejected safely; non-null failed outputs are cleared deterministically.
  Parser argument/length failures remain unclassified and cause no transition.
- **Build integration:** Added the state-machine source/header to
  `ChatpadProtocol.vcxproj`; added focused tests and synthetic event fixtures to
  `ChatpadProtocolTests.vcxproj`; added state-machine source/header and a compile
  consumer to the isolated kernel compatibility project; extended the direct
  compiler script to compile/link both implementation and test sources.
- **Documentation modified:** `docs/CHATPAD-PROTOCOL.md`, `docs/BUILDING.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, `docs/PROJECT-STATE.md`,
  `docs/WORKLOG.md`, `src/protocol/ChatpadProtocol/README.md`,
  `tests/protocol/README.md`, `tests/protocol/fixtures/README.md`, and
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`.
- **Test count:** 174 assertions total: original parser 85 plus state machine 89.
- **Windows PowerShell 5.1 validation:**
  - `tools/Get-DriverBuildEnvironment.ps1` — exit 0.
  - `tools/Test-RepositorySafety.ps1` — PASS.
  - `git diff --exit-code HEAD -- legacy/` — exit 0.
  - `git merge-base --is-ancestor 6502452 HEAD` — exit 1, not ancestor.
  - `tools/Test-ChatpadProtocolParser.ps1` — compiler/link/test exits 0,
    174/174; executable SHA-256
    `C24E161B14FFF0B234DAED85C411D9915B1020B95FDA3B037D3DBD5E727125A4`.
  - `tools/Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64` —
    MSBuild/test exits 0, 174/174; library
    `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib`
    SHA-256 `79B4785BEF2B1A095B2CF4C6ED24872D7B2101E6B8C50F8F4078B84BAF22B5B8`;
    test executable SHA-256
    `361E57471EB1398AF58ECF17141DF383FF0278F2E080339CCF976651B016605F`.
  - Integrated Release — exits 0, 174/174; library
    `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib`
    SHA-256 `23CEB0A4D4B1E1765EFAAD53ED36F28F5846205E1C2560E8FE399726D2BDE1FA`;
    test executable SHA-256
    `F53CBA3A17AAAA58FA0FFCFE077D4A48211F9A5F7282B4E1D552964AB511EC86`.
  - Kernel Debug — MSBuild exit 0; state-machine source compiled; library
    `artifacts/bin/x64/Debug/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`;
    SHA-256 `AB85938F137AEF8E0C745B6EC65F9857F3CCC0697140867E1EE999FFFC21C284`.
  - Kernel Release — MSBuild exit 0; state-machine source compiled; library
    `artifacts/bin/x64/Release/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.lib`;
    SHA-256 `A2B9C6DF3FC4DC4D60F58D08C2DC9C59B36E010FBC0FF149890440E07CFF221B`.
  - Driver Debug — exit 0, NotSigned, no SignTool; path
    `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys`; SHA-256
    `75c56cbe820f38902e6fa3c0752efea162a5593ea0c6ccd05f5d39ac1c2a9998`.
  - Driver Release — exit 0, NotSigned, no SignTool; path
    `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys`; SHA-256
    `b317141364878e1c441639a56d35b97aa8fbb4f24847bd0dda0fa9e12f089f3e`.
- **Driver isolation proof:** `ChatpadFilter.vcxproj` has no project reference,
  parser/state-machine source, or protocol name. The solution has no dependency
  section. Debug/Release diagnostic linker commands contain only driver objects
  and kernel/KMDF libraries; no protocol or compatibility library is linked.
- **Safety:** Compatibility builds produced only `.lib` artifacts; no `.sys`,
  INF, CAT, certificate, package, service, installer, or deployment output.
  No hardware, USB, HID, IOCTL, callback, injection, semantic key mapping,
  installation, signing, packaging, deployment, loading, or external skill
  action occurred. `legacy/` remained unchanged.
- **Generated artifacts:** All binaries and logs remain beneath ignored
  `artifacts/` and are not committed.
- **Commit and push:** Commit exactly `feat: add offline protocol state machine`;
  push only `origin/feature/offline-protocol-state-machine`.
- **Remaining risks or limitations:** Raw initialization/status forms remain
  unresolved. The state machine is an offline classification layer only and is
  not connected to runtime driver code.

## 2026-06-29T16:36+04:00 — Chatpad initialization and status evidence audit

- **Objective:** Perform a read-only legacy-source audit of initialization,
  response, status, keepalive, timing, retry, IOCTL, and internal-state
  evidence; correct continuity; commit and push documentation only.
- **Starting branch and commit:** `analysis/init-status-evidence` /
  `55a1af2c1418a95fcda51038c1b299cb5a75b91f`; clean and aligned with
  `origin/analysis/init-status-evidence`. Prohibited commit `6502452` was not
  an ancestor.
- **Continuity discrepancy:** The inherited project-state and next-task files
  accurately described the parent state-machine checkpoint but named that
  parent branch rather than this prepared audit branch. They were updated to
  current repository truth before handoff.
- **Investigation:** Targeted searches and compact line ranges covered the sole
  `0x90` occurrence, all references to initialization structures and flags,
  user-mode request serialization, filter-side WDF control transfer creation,
  initialization triggers, completion paths, continuous reads, `f0` handling,
  and periodic requests. `CHATPAD_INIT_REQUEST` is declaration-only. The
  executable path sends payload `09 00`, not `90 00`.
- **Confirmed control path:** `main` -> `ChatpadControlMainLoop` -> one
  `InitChatpad` call -> internal Microsoft-init flag IOCTL -> three unexplained
  no-data control requests -> two-byte control-IN -> control-OUT with payload
  `09 00` -> second control-IN. The filter copies the eight setup bytes into a
  WDF setup packet and provides optional IOCTL bytes 9+ as the data stage.
- **Status and success boundary:** The filter marks Microsoft initialization
  complete on USB configuration selection. Two returned bytes are logged but
  never compared. `chatpadInitFinished` is never set true or read. Received
  `f0` packets are ignored with unknown meaning. Alternating `001f`/`001e`
  no-data requests are called keep-alives but have no response validation.
  Therefore no acknowledgement, response/status format, retry policy, or
  objective ready state is confirmed.
- **Files created:** `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, `docs/CHATPAD-PROTOCOL.md`,
  `docs/NEXT-TASK.md`, and append-only `docs/WORKLOG.md`.
- **Validation before editing:** `tools/Test-RepositorySafety.ps1` — PASS;
  `git diff --exit-code -- legacy` — exit 0; prohibited-ancestor check — exit
  1 as required.
- **Validation after editing:** repository safety, whitespace, legacy-diff,
  documentation-only scope, forbidden-file, staged-diff, and final-status
  checks are recorded by the final report for this task. No build was required
  or run.
- **Artifacts:** None generated.
- **Commit and push:** Commit exactly
  `docs: audit chatpad initialization status evidence`; push only
  `origin/analysis/init-status-evidence`.
- **Remaining risks or limitations:** Meanings of the mystery requests,
  control-IN responses, `f0` packets, `001f`/`001e` periodic requests, and an
  objective ready condition remain unresolved. The next safe boundary is a
  neutral offline representation and construction tests for confirmed setup
  tuples and payload only.
- **Safety:** `legacy/` remained untouched. No implementation, hardware,
  driver, build-project, external-skill, installation, signing, packaging,
  deployment, loading, capture, or runtime action occurred.

## 2026-06-29T16:56+04:00 — Declarative activation request builder

- **Objective:** Add a transport-independent declarative representation of the
  six activation control requests confirmed by the initialization/status audit,
  add offline construction tests, update build integration and continuity, then
  commit and push.
- **Starting branch and commit:** `feature/activation-request-builder` /
  `782e8e15037af1ec524b69ee38003977d3b99fa5`; clean and aligned with
  `origin/feature/activation-request-builder`. Prohibited commit `6502452` was
  not an ancestor.
- **Continuity discrepancy:** The inherited project-state and next-task files
  correctly described the parent audit checkpoint but named the parent audit
  branch. They were updated to this feature branch and current implementation.
- **Implementation:** Added `ChatpadActivationRequests.h/.c` with a private
  immutable six-entry descriptor table, request count API, build-by-index API,
  null-output rejection, invalid-index rejection with deterministic clearing,
  embedded payload bytes, expected inbound data length, and caller-owned value
  copies. The public model preserves raw setup fields and direction without
  transport, I/O, allocation, mutable globals, caller-pointer retention,
  retries, timeouts, acknowledgement semantics, ready states, or response
  decoding.
- **Confirmed six-request order:** index 0 `40 a9 a30c 4423 0000`, index 1
  `40 a9 2344 7f03 0000`, index 2 `40 a9 5839 6832 0000`, index 3
  `c0 a1 0000 e416 0002`, index 4 `40 a1 0000 e416 0002` with outbound
  payload `09 00`, and index 5 `c0 a1 0000 e416 0002`.
- **Evidence boundary:** `09 00` is the only outbound payload. `90 00` is
  absent from descriptors, fixtures, payloads, and tests. Device-to-host
  descriptors expose only expected inbound data length and contain no fabricated
  response bytes.
- **Tests:** Added evidence-derived activation fixtures and 126 focused
  assertions covering count, null output, invalid indexes, exact order,
  direction, setup fields, outbound payload length and bytes, `09 00`
  placement, `90 00` absence, no fabricated device-to-host outbound data,
  unused payload zeroing, deterministic failure clearing, repeatability,
  stateless sequential construction, value-copy isolation, sentinel guards, and
  absence of acknowledgement/ready/retry/timeout fields. Total assertions are
  now 300.
- **Build integration:** Added the source/header to `ChatpadProtocol.vcxproj`;
  added tests and fixtures to `ChatpadProtocolTests.vcxproj`; updated
  `Test-ChatpadProtocolParser.ps1` to compile/link the activation source and
  tests directly; added the source/header and compile consumer to the isolated
  WDK compatibility project. The direct script now uses a PowerShell 5.1-safe
  UTF-8 encoding constructor for touched log writes.
- **Kernel compatibility fix:** Unconditional MSVC `stdint.h` inclusion failed
  under the WDK kernel toolchain with CRT macro redefinition warnings promoted
  to errors. The activation public header uses standard `<stdint.h>` and
  `<stddef.h>` for normal C callers and a primitive `_MSC_VER` plus
  `_KERNEL_MODE` fallback for the isolated kernel compile path, without adding
  Windows or WDK headers to the portable API.
- **Files created:** `src/protocol/ChatpadProtocol/ChatpadActivationRequests.h`,
  `src/protocol/ChatpadProtocol/ChatpadActivationRequests.c`,
  `tests/protocol/ChatpadActivationRequestsTests.h`,
  `tests/protocol/ChatpadActivationRequestsTests.c`, and
  `tests/protocol/fixtures/ChatpadActivationRequestFixtures.h`.
- **Files modified:** `src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj`,
  `src/protocol/ChatpadProtocol/README.md`,
  `tests/protocol/ChatpadProtocolParserTests.c`,
  `tests/protocol/ChatpadProtocolTests.vcxproj`,
  `tests/protocol/README.md`, `tests/protocol/fixtures/README.md`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.c`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.vcxproj`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`,
  `tools/Test-ChatpadProtocolParser.ps1`, `docs/CHATPAD-PROTOCOL.md`,
  `docs/BUILDING.md`, `docs/DECISIONS.md`, `docs/PROJECT-STATE.md`,
  `docs/NEXT-TASK.md`, and append-only `docs/WORKLOG.md`.
- **Initial validation:** `tools/Get-DriverBuildEnvironment.ps1` — exit 0;
  `tools/Test-RepositorySafety.ps1` — PASS; `git diff --exit-code -- legacy`
  — exit 0; `git merge-base --is-ancestor 6502452 HEAD` — exit 1 as required.
- **Direct validation:** `tools/Test-ChatpadProtocolParser.ps1` — compiler
  exits 0, linker exit 0, test exit 0, 300/300 assertions. Test executable
  SHA-256 `F88F87BC842C72F45074F1A818F36A9C3738F60B448A0298C8D0F3FCFF9958BA`.
- **Integrated Debug:** `tools/Test-ChatpadProtocol.ps1 -Configuration Debug
  -Platform x64` — MSBuild exit 0, test exit 0, 300/300 assertions; library
  `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
  `4F337A31B8E3657865606423ECB2DE80510432EFA0BFFFDA2C70E6E5D8063989`; test
  executable `artifacts/bin/x64/Debug/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `A9869E027C9C1D14EB03C36CCA931207DC05F78558DD60E48D2BD5A26A5016AA`.
- **Integrated Release:** `tools/Test-ChatpadProtocol.ps1 -Configuration
  Release -Platform x64` — MSBuild exit 0, test exit 0, 300/300 assertions;
  library `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib`
  SHA-256 `3B82C72AD836A236B30F5067509748F0422E4657D0A931FD0177BB61A85821E4`;
  test executable
  `artifacts/bin/x64/Release/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `2A8000A9D1EA214AE27DB477A2914DD0E511D36A385B8A43493BFD3B81172505`.
- **Kernel compatibility Debug:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Debug -Platform x64` — MSBuild exit 0; activation source
  compiled under WDK; only `.lib` output; SHA-256
  `54ED65B1B7DDEE19218153D6B258CE12AA7CF8A9A76D378960FCB750AA76DB1B`.
- **Kernel compatibility Release:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Release -Platform x64` — MSBuild exit 0; activation source
  compiled under WDK; only `.lib` output; SHA-256
  `925E08541617E52FEB70D9C974E49797C8FDC9E2A079D7A722345895A5245592`.
- **Driver Debug:** `tools/Build-Driver.ps1 -Configuration Debug -Platform x64`
  — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `9e01f44b37c45141a6cb1f67941edd1a08cf6a66d3d663a47131e35e081bedfd`.
- **Driver Release:** `tools/Build-Driver.ps1 -Configuration Release -Platform
  x64` — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `1f1a81fb5e4392ad640c97d1c6c5b11972e66b55b5773732e8a3d9c217ad7b9b`.
- **Driver isolation proof:** `ChatpadFilter.vcxproj` lists only `driver.c`,
  `device.c`, and `driver.h`, with no project reference or activation/protocol
  source. The solution has no dependency section. Debug and Release driver
  diagnostic linker inputs include only driver objects and WDK/KMDF libraries,
  not `ChatpadProtocol.lib` or `ChatpadProtocolKernelCompileCheck.lib`.
- **Generated artifacts:** Build outputs and logs remain under ignored
  `artifacts/`; none are staged or tracked.
- **Commit and push:** Commit exactly
  `feat: add declarative activation request builder`; push only
  `origin/feature/activation-request-builder`.
- **Remaining risks or limitations:** The three `40/a9` requests remain
  semantically unexplained; control-IN response bytes, `f0` packet meaning,
  `001f`/`001e` periodic request semantics, inter-request timing policy, and
  objective ready conditions remain unresolved.
- **Safety:** `legacy/` remained untouched. No request was sent. No hardware,
  USB, HID, IOCTL, installation, signing, packaging, deployment, loading,
  capture, external-skill, driver runtime, callback, service, INF, CAT,
  certificate, or installer action occurred.

## 2026-06-29T17:15+04:00 — Activation sequence planner

- **Objective:** Add a transport-independent activation-sequence planner that
  exposes the six confirmed activation requests in proven order and represents
  confirmed legacy timing only as declarative metadata. Complete validation,
  documentation, continuity, commit, and push on the requested branch.
- **Starting branch and commit:** `feature/activation-sequence-planner` /
  `095772352def48a6764edd11e795745096e165dc`; clean and aligned with
  `origin/feature/activation-sequence-planner`. Prohibited commit `6502452`
  was not an ancestor.
- **Continuity discrepancy:** The inherited project-state and next-task files
  correctly described the parent activation-request-builder checkpoint but
  named that parent branch. They were updated to the current feature branch
  and current implementation state.
- **Investigation:** Re-read `AGENTS.md`, continuity docs, the initialization
  evidence audit, protocol docs, build docs, request builder, request tests,
  fixtures, MSBuild projects, direct test runner, and kernel compile-check
  project. Section 9 of `docs/CHATPAD-INIT-STATUS-EVIDENCE.md` confirms only
  legacy executable-path post-`SendControlRequest` sleep behavior: 12 ms after
  each call returns, including after failure. No pre-request delay, device
  required inter-request minimum, timeout, retry, acknowledgement, response, or
  readiness condition is confirmed.
- **Implementation:** Added `ChatpadActivationSequence.h/.c` with
  `ChatpadGetActivationSequenceStepCount` and
  `ChatpadGetActivationSequenceStep`. The planner exposes six caller-owned
  value-copy steps. Each step contains `SequenceIndex`, matching
  `RequestIndex`, a request descriptor obtained from
  `ChatpadBuildActivationRequest`, `DelayBeforeMilliseconds`, and
  `DelayAfterMilliseconds`.
- **Timing metadata boundary:** all six steps report
  `DelayBeforeMilliseconds = 0` and `DelayAfterMilliseconds = 12`. The zero
  before-delay means no confirmed pre-request timing metadata, not a proven
  no-delay requirement. The 12 ms after-delay is metadata only for the observed
  legacy post-call sleep; the planner does not sleep, wait, enforce a deadline,
  retry, send, or interpret a response.
- **Exact six-step mapping:** step 0 -> request 0
  `40 a9 a30c 4423 0000`; step 1 -> request 1
  `40 a9 2344 7f03 0000`; step 2 -> request 2
  `40 a9 5839 6832 0000`; step 3 -> request 3
  `c0 a1 0000 e416 0002`; step 4 -> request 4
  `40 a1 0000 e416 0002` with outbound payload `09 00`; step 5 -> request 5
  `c0 a1 0000 e416 0002`.
- **Evidence boundary:** `09 00` remains the only outbound payload and only on
  request/step index 4. `90 00` is absent from descriptors, sequence steps,
  fixtures, payloads, and tests. Device-to-host steps contain expected inbound
  length only and no fabricated response bytes.
- **Tests:** Added `ChatpadActivationSequenceTests.c/.h` and
  `fixtures/ChatpadActivationSequenceFixtures.h`, adding 143 focused
  assertions. Coverage includes count six, null output, invalid index at
  count, invalid large index, every step builds, exact sequence indexes,
  request-builder index one-to-one mapping, setup fields matching builder,
  payload bytes matching builder, `09 00` only in the confirmed step,
  unsupported comment payload absence, exact timing metadata, zero timing where
  no pre-request timing is confirmed, no response/acknowledgement data,
  deterministic failure clearing, repeated construction, stateless sequential
  construction, mutation isolation, sentinel protection, planner/request
  builder count equality, and no readiness/retry/timeout claims.
- **Build integration:** Added source/header to `ChatpadProtocol.vcxproj`;
  added tests and timing fixture to `ChatpadProtocolTests.vcxproj`; updated
  `Test-ChatpadProtocolParser.ps1` to compile/link planner source and tests;
  added planner source/header and a compile consumer to the isolated WDK
  compatibility project.
- **Files created:** `src/protocol/ChatpadProtocol/ChatpadActivationSequence.h`,
  `src/protocol/ChatpadProtocol/ChatpadActivationSequence.c`,
  `tests/protocol/ChatpadActivationSequenceTests.h`,
  `tests/protocol/ChatpadActivationSequenceTests.c`, and
  `tests/protocol/fixtures/ChatpadActivationSequenceFixtures.h`.
- **Files modified:** `src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj`,
  `src/protocol/ChatpadProtocol/README.md`,
  `tests/protocol/ChatpadProtocolParserTests.c`,
  `tests/protocol/ChatpadProtocolTests.vcxproj`,
  `tests/protocol/README.md`, `tests/protocol/fixtures/README.md`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.c`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.vcxproj`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`,
  `tools/Test-ChatpadProtocolParser.ps1`, `docs/CHATPAD-PROTOCOL.md`,
  `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`, `docs/BUILDING.md`,
  `docs/DECISIONS.md`, `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, and
  append-only `docs/WORKLOG.md`.
- **Initial validation before editing:** `tools/Get-DriverBuildEnvironment.ps1`
  — exit 0; `tools/Test-RepositorySafety.ps1` — PASS;
  `git diff --exit-code -- legacy` — exit 0;
  `git merge-base --is-ancestor 6502452 HEAD` — exit 1 as required;
  `tools/Test-ChatpadProtocolParser.ps1` — compiler/link/test exits 0,
  300/300 assertions; test executable SHA-256
  `D9BBE4155637A2A5E3C114B73ADE09FC00FA33258388DFF6C0D9ADA5B98A94C2`.
- **Direct validation after implementation:** `tools/Test-ChatpadProtocolParser.ps1`
  — compiler/link/test exits 0, 443/443 assertions; test executable
  `artifacts/bin/x64/Debug/ChatpadProtocolParser/ChatpadProtocolParserTests.exe`
  SHA-256 `EEDB42AA640E3E8E1613DA08D9C6CA316A9989D815F364512B49F5E5A0051181`.
- **Integrated Debug:** `tools/Test-ChatpadProtocol.ps1 -Configuration Debug
  -Platform x64` — MSBuild exit 0, test exit 0, 443/443 assertions; library
  `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
  `10643A992FBD02F1AF309DEEEB602F0C9B37BA38B82DECBAA606C5198891EFBD`; test
  executable `artifacts/bin/x64/Debug/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `DFE983B7D444B9950AE392B4860BD5EC8B85FE21EF8291111C5DAA68C0152E57`.
- **Integrated Release:** `tools/Test-ChatpadProtocol.ps1 -Configuration
  Release -Platform x64` — MSBuild exit 0, test exit 0, 443/443 assertions;
  library `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib`
  SHA-256 `2AAFD4EDE9E52062BCCA117E75BC380A4313E77F6E0EEE8CFF398E0A9DD4F591`;
  test executable
  `artifacts/bin/x64/Release/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `20F5A79284378A267F778ED99742C78D420CE600E6C5E8CB62682CCE1E18FA4B`.
- **Kernel compatibility Debug:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Debug -Platform x64` — MSBuild exit 0; planner source
  compiled under WDK; only `.lib` output; SHA-256
  `4B9E9EB3EE8262EA7AB750D0B88819A5713DA2132DD5BB8FA43E38D9CE51FCEB`.
- **Kernel compatibility Release:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Release -Platform x64` — MSBuild exit 0; planner source
  compiled under WDK; only `.lib` output; SHA-256
  `9FF6E8086DA53EF25A180DF56D11D6CEF6AD44CDD48F61F72F0FF19B395D3853`.
- **Driver Debug:** `tools/Build-Driver.ps1 -Configuration Debug -Platform x64`
  — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `5E66DFC2BF9E83CADF4F369E7588D8E9609AB2B0D42F793B3FB9C4E411C11E2B`.
- **Driver Release:** `tools/Build-Driver.ps1 -Configuration Release -Platform
  x64` — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `C7E745D94AFDFC6C058F00B56700C9401A8EAB96CB8F211B3E65AFAFBB15997D`.
- **Driver isolation proof:** `ChatpadFilter.vcxproj` lists only driver source
  files and has no project reference or protocol source. Debug and Release
  diagnostic linker inputs include only driver objects and WDK/KMDF libraries,
  not `ChatpadProtocol.lib` or `ChatpadProtocolKernelCompileCheck.lib`. The
  driver did not compile planner or request-builder sources.
- **Generated artifacts:** Build outputs and logs remain under ignored
  `artifacts/`; none are staged or tracked.
- **Commit and push:** Commit exactly `feat: add activation sequence planner`;
  push only `origin/feature/activation-sequence-planner`.
- **Remaining risks or limitations:** The three `40/a9` requests remain
  semantically unexplained; control-IN response bytes, `f0` packet meaning,
  `001f`/`001e` periodic request semantics, and objective ready conditions
  remain unresolved.
- **Safety:** `legacy/` remained untouched. No request was sent. No sleep,
  timer, retry, response interpretation, acknowledgement handling, readiness
  transition, hardware, USB, HID, IOCTL, installation, signing, packaging,
  deployment, loading, capture, external-skill, driver runtime, callback,
  service, INF, CAT, certificate, or installer action occurred.

## 2026-06-29T18:12+04:00 — Mocked activation executor

- **Objective:** Add a portable, transport-independent activation execution
  contract and fully mocked activation executor that consumes the existing
  six-step activation sequence planner. Complete validation, documentation,
  continuity updates, commit, and push on the requested branch.
- **Starting branch and commit:** `feature/mocked-activation-executor` /
  `e1de1860e2f2ea21146e8de8aeec19892d2c9203`. The tree was clean before
  edits. Prohibited commit `6502452` was not an ancestor.
- **Continuity discrepancy:** Existing continuity docs described the parent
  activation-sequence-planner checkpoint. They were replaced or appended with
  the current executor implementation state and this task's next recommended
  read-only device inventory objective.
- **Investigation:** Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, recent `docs/WORKLOG.md`, the
  request builder, sequence planner, protocol tests, fixtures, MSBuild
  projects, direct test runner, kernel compatibility project, and build scripts.
- **Implementation:** Added `ChatpadActivationExecutor.h/.c` with
  `ChatpadExecuteActivationPlan`, `ChatpadActivationExecutionSink`, callback
  result enum, execution result enum, operation-kind enum, and
  `ChatpadActivationExecutionSummary`. The executor obtains each step through
  `ChatpadGetActivationSequenceStep`, emits request callbacks first, emits
  delay metadata callbacks only when `DelayAfterMilliseconds` is nonzero, and
  stops immediately on callback rejection or planner failure.
- **Contract boundary:** request callback emission means a planned request was
  handed to the caller, not transmitted. Delay metadata emission means metadata
  exists, not elapsed time. Callback acceptance/rejection is an API/callback
  outcome, not a USB, HID, IOCTL, driver, device, or hardware result. Callback
  request pointers are valid only during the callback. The executor retains no
  caller pointers and allocates no memory.
- **Summary boundary:** summaries contain only planned step count, emitted
  request count, emitted delay metadata count, last completed step index,
  rejected operation kind, and rejected step index. No response, acknowledgement,
  ready flag, transport status, elapsed time, timeout, retry count, pointer,
  allocation, hardware, or driver field was added.
- **Successful operation order:** request 0, delay 0 12 ms, request 1,
  delay 1 12 ms, request 2, delay 2 12 ms, request 3, delay 3 12 ms,
  request 4, delay 4 12 ms, request 5, delay 5 12 ms.
- **Tests:** Added `ChatpadActivationExecutorTests.c/.h` and
  `fixtures/ChatpadActivationExecutionFixtures.h`, adding 167 focused
  assertions. Coverage includes null sink, missing request callback, missing
  delay callback, null summary, successful execution, exact six request
  callbacks, exact six delay metadata callbacks, exact 12 total operations,
  alternating order, step indexes, planner/request-builder request matching,
  setup fields, payload bytes, `09 00` only at step 4, `90 00` absence,
  all delay values exactly 12 ms, no active wait/elapsed-time behavior,
  successful summary counts and last-completed step, request rejection at
  step 0/middle/step 5, delay rejection at step 0/middle/step 5, no callbacks
  after rejection, accepted-operation counts after rejection, rejected
  operation kind/step, no retry, repeated successful execution determinism,
  success after prior rejection, independent recorder contexts, mutation
  isolation, summary and recorder sentinels, fixed-capacity recorder
  exhaustion, planner/request counts exactly six, no retained caller pointer,
  no response/acknowledgement/ready/timeout/retry fields, and no
  hardware/transport semantics.
- **Build integration:** Added executor source/header to
  `ChatpadProtocol.vcxproj`; added tests and execution fixture to
  `ChatpadProtocolTests.vcxproj`; updated `Test-ChatpadProtocolParser.ps1` to
  compile/link executor source and tests; added executor source/header and a
  compile consumer to the isolated WDK compatibility project.
- **Files created:** `src/protocol/ChatpadProtocol/ChatpadActivationExecutor.h`,
  `src/protocol/ChatpadProtocol/ChatpadActivationExecutor.c`,
  `tests/protocol/ChatpadActivationExecutorTests.h`,
  `tests/protocol/ChatpadActivationExecutorTests.c`, and
  `tests/protocol/fixtures/ChatpadActivationExecutionFixtures.h`.
- **Files modified:** `src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj`,
  `src/protocol/ChatpadProtocol/README.md`,
  `tests/protocol/ChatpadProtocolParserTests.c`,
  `tests/protocol/ChatpadProtocolTests.vcxproj`,
  `tests/protocol/README.md`, `tests/protocol/fixtures/README.md`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.c`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.vcxproj`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`,
  `tools/Test-ChatpadProtocolParser.ps1`, `docs/CHATPAD-PROTOCOL.md`,
  `docs/BUILDING.md`, `docs/DECISIONS.md`, `docs/PROJECT-STATE.md`,
  `docs/NEXT-TASK.md`, and append-only `docs/WORKLOG.md`.
- **Initial validation before editing:** `tools/Get-DriverBuildEnvironment.ps1`
  — exit 0; `tools/Test-RepositorySafety.ps1` — PASS;
  `git diff --exit-code -- legacy` — exit 0;
  `git merge-base --is-ancestor 6502452 HEAD` — exit 1 as required;
  `tools/Test-ChatpadProtocolParser.ps1` — compiler/link/test exits 0,
  443/443 assertions.
- **Direct validation after implementation:** `tools/Test-ChatpadProtocolParser.ps1`
  — compiler/link/test exits 0, 610/610 assertions; test executable
  `artifacts/bin/x64/Debug/ChatpadProtocolParser/ChatpadProtocolParserTests.exe`
  SHA-256 `70742A4D425AEB88E8EB89AFF088D493D79DFD7B726DD0C74972BAAD2F69C516`;
  repository safety PASS.
- **Final direct validation after documentation:** `tools/Test-ChatpadProtocolParser.ps1`
  — compiler/link/test exits 0, 610/610 assertions; test executable
  `artifacts/bin/x64/Debug/ChatpadProtocolParser/ChatpadProtocolParserTests.exe`
  SHA-256 `D6E533D6A59BFE312E8EDF9B9A993D60E59CCA7B810710A62CB71A02AEF7A435`;
  repository safety PASS.
- **Integrated Debug:** `tools/Test-ChatpadProtocol.ps1 -Configuration Debug
  -Platform x64` — MSBuild exit 0, test exit 0, 610/610 assertions; library
  `artifacts/bin/x64/Debug/ChatpadProtocol/ChatpadProtocol.lib` SHA-256
  `68984F9F9C0ABC6107AD01E4387E7DAAA0E2418A089AB31F26FC743995502C64`; test
  executable `artifacts/bin/x64/Debug/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `2700503C6D96053E152C1EFA36FD4F16C3A8CBE80EEFBDD4BFFB1E1DB7605AF6`.
- **Integrated Release:** `tools/Test-ChatpadProtocol.ps1 -Configuration
  Release -Platform x64` — MSBuild exit 0, test exit 0, 610/610 assertions;
  library `artifacts/bin/x64/Release/ChatpadProtocol/ChatpadProtocol.lib`
  SHA-256 `15336EE73D68F9AE4CD40C245393B6CE7AECCBD2C7AC2193C044DCB53CA62F87`;
  test executable
  `artifacts/bin/x64/Release/ChatpadProtocolTests/ChatpadProtocolTests.exe`
  SHA-256 `1F1D704A478F6353C27B472083012C027A89C8A03B5F4881941BC9ADF4D49C42`.
- **Kernel compatibility Debug:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Debug -Platform x64` — environment detector exit 0, MSBuild
  exit 0; executor source compiled under WDK; only `.lib` output; SHA-256
  `D5A7D38056C9FEACCE884CA9368695A05B106EE0499113CE9230BD46C0D9820C`;
  signing scan PASS; prohibited output scan PASS; artifact containment PASS.
- **Kernel compatibility Release:** `tools/Test-ChatpadProtocolKernelCompatibility.ps1
  -Configuration Release -Platform x64` — environment detector exit 0,
  MSBuild exit 0; executor source compiled under WDK; only `.lib` output;
  SHA-256 `5353CE201671210CFBF0DA5E41CBF9C358D827E907BDDFFB86D57920AE789DA2`;
  signing scan PASS; prohibited output scan PASS; artifact containment PASS.
- **Driver Debug:** `tools/Build-Driver.ps1 -Configuration Debug -Platform x64`
  — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `7daea18602f33f7e00d8525ca12ea3d9541ed9648de2e97707dff3092a679c11`;
  repository safety PASS.
- **Driver Release:** `tools/Build-Driver.ps1 -Configuration Release -Platform
  x64` — exit 0, NotSigned, no SignTool; `ChatpadFilter.sys` SHA-256
  `8fb2e1a7832c07081960c551334f93dcd89a21e4a8ddcd0e093ce8d11d2cbb08`;
  repository safety PASS.
- **Driver isolation proof:** `ChatpadFilter.vcxproj` lists only driver source
  files and has no project reference or protocol source. Debug and Release
  diagnostic linker inputs include only driver objects and WDK/KMDF libraries,
  not `ChatpadProtocol.lib` or `ChatpadProtocolKernelCompileCheck.lib`. The
  driver did not compile executor, planner, or request-builder sources.
- **Generated artifacts:** Build outputs and logs remain under ignored
  `artifacts/`; none are staged or tracked.
- **Commit and push:** Commit exactly `feat: add mocked activation executor`;
  push only `origin/feature/mocked-activation-executor`.
- **Remaining risks or limitations:** The three `40/a9` requests remain
  semantically unexplained; control-IN response bytes, `f0` packet meaning,
  `001f`/`001e` periodic request semantics, objective ready conditions, and
  connected-device inventory remain unresolved.
- **Safety:** `legacy/` remained untouched. No request was sent. No sleep,
  timer, retry, response interpretation, acknowledgement handling, readiness
  transition, hardware, USB, HID, IOCTL, installation, signing, packaging,
  deployment, loading, capture, external-skill, driver runtime, service, INF,
  CAT, certificate, installer, or private-machine artifact action occurred.

## 2026-06-29T18:40+04:00 — Connected Xbox 360 controller and Chatpad inventory

- **Objective:** Perform and document a strictly read-only Windows device,
  interface, driver-binding, and topology inventory for the connected original
  Xbox 360 controller and attached original Chatpad; add a repeatable
  cross-version collector; validate, commit, and push the requested branch.
- **Starting branch and commit:** `analysis/connected-device-inventory` /
  `1159adc49e50d694186da67ce105fa07d81f7987`; tree clean; prohibited commit
  `6502452` not an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and `docs/NEXT-TASK.md`
  correctly described the parent activation-executor checkpoint but still
  named `feature/mocked-activation-executor`. They were updated for the
  dedicated inventory branch and the observed device state before being used
  as continuation truth.
- **Investigation:** Read all required repository, protocol, initialization,
  build, legacy-architecture, blocker, and protocol README documents. Verified
  the prior executor commit at HEAD, repository safety, legacy immutability,
  prohibited ancestry, and controller presence before editing.
- **Implementation:** Added `tools/Get-ConnectedChatpadInventory.ps1`. It finds
  the repository from its script path; uses only PnP, CIM, and read-only
  registry metadata; captures minimal baseline/final target snapshots; emits
  canonical JSON plus human-readable and focused JSON files beneath a unique
  ignored UTC directory; preserves Unicode as UTF-8; opens no device/interface
  handle; and fails on collection errors or target-state differences.
- **Observed controller:** exact instance ID retained in raw artifacts;
  redacted pattern `USB\VID_045E&PID_028E\<device instance>`; hardware IDs
  `USB\VID_045E&PID_028E&REV_0114` and
  `USB\VID_045E&PID_028E`; class `XnaComposite` /
  `{D61CA365-5AF4-4486-998B-9DB4734C6CA3}`; service `xusb22`; Microsoft
  `xusb22.inf` version `10.0.26100.8521`, date 2026-05-16, signer Microsoft
  Windows, matching ID `USB\VID_045E&PID_028E`, file `xusb22.sys`.
- **Topology and visibility:** controller has one `IG_01` USB HID child and one
  HID game-controller grandchild; all three share a container. A generic USB
  hub is the direct parent. No separately Chatpad-labeled PnP node or interface
  was observed. The related HID branch cannot be attributed to Chatpad from
  cached inventory alone.
- **Interfaces and filters:** controller registrations include
  `GUID_DEVINTERFACE_USB_DEVICE` and
  `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}`; the HID collection registers
  `GUID_DEVINTERFACE_HID`. No target device-level or XnaComposite/HIDClass
  class-level upper/lower filters were observed.
- **Transport boundary:** endpoint layout and activation transport target are
  unavailable from cached inventory. The physical USB/XnaComposite node is a
  plausible device-specific future filter attachment point only; no endpoint,
  request, or safe access mechanism is proven.
- **Files created:** `tools/Get-ConnectedChatpadInventory.ps1` and
  `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`,
  `docs/DECISIONS.md`, `docs/CHATPAD-PROTOCOL.md`, and append-only
  `docs/WORKLOG.md`.
- **Initial validation:** `tools/Test-RepositorySafety.ps1` PASS;
  `git diff --exit-code -- legacy` exit 0; prohibited-ancestor check exit 1 as
  required; read-only PnP presence query found the controller.
- **Read-only prototype results:** one early `Win32_PnPSignedDriver` WQL filter
  was rejected as an invalid query (exit 1), so the collector uses an
  in-memory exact DeviceID match. One broad per-node property prototype was
  terminated after repeated slow queries; the collector instead expands only
  the controller relationship graph. An intermediate dual-version validation
  exposed an empty-array enumeration bug and exited 1 in both shells; the
  ordinal array helper was corrected before the final runs. None of these
  diagnostics opened a device handle or changed device state.
- **Collector validation:** final PowerShell 7.6.3 run exit 0 at
  `artifacts/device-inventory/20260629T143606331Z/`; final Windows PowerShell
  5.1.26100.8655 run exit 0 at
  `artifacts/device-inventory/20260629T143618407Z/`. Both report unchanged
  baseline/final status, problem code, service, INF, and present state. Stable
  controller identity, binding, topology, HID, and interface-class fields match
  exactly across versions.
- **Generated artifacts:** each final directory contains `inventory.json`,
  `inventory.txt`, `candidate-devices.json`, `relationships.json`,
  `driver-bindings.json`, and `interfaces.json`; all remain ignored and
  untracked.
- **Final validation:** artifact fact assertions PASS; exact cross-version
  stable-field comparison PASS; PowerShell AST command/API safety scan PASS;
  tracked-file private-identifier scan PASS; artifact containment/tracking and
  changed-file scope checks PASS; `tools/Test-RepositorySafety.ps1` PASS;
  `git diff --check` exit 0; `git diff --exit-code -- legacy` exit 0; prohibited
  ancestry check exit 1 as required.
- **Builds:** not run because protocol, driver, runtime source, and project
  files are outside scope and unchanged.
- **Commit and push:** commit exactly
  `docs: inventory connected xbox chatpad device stack`; push only
  `origin/analysis/connected-device-inventory`.
- **Remaining limitation:** a separately authorized observation capable of
  proving USB interface/endpoint or supported interface semantics is still
  required before real transport implementation.
- **Safety:** no handle, USB request, HID operation, IOCTL, URB, activation,
  input read, output write, capture, trace, state-changing device command,
  driver install/bind/update/export/stage/sign/package/deploy/load, elevation,
  inventory/dependency network request, source/project edit, legacy edit, or
  external-skill modification occurred. The required Git push is the only
  authorized network action.

## 2026-06-29T18:55+04:00 — Windows 11 Chatpad transport architecture

- **Objective:** Produce the documentation-only Windows 11 attachment,
  activation transport, input acquisition, lifetime, and keyboard-output
  architecture; define hard stop gates; update continuity; validate, commit,
  and push the requested branch without runtime or hardware behavior.
- **Starting branch and commit:**
  `analysis/windows11-transport-architecture` /
  `6881fc492af50b7f28977d306fad369a2f6a309f`; clean tree; tracking the same
  branch on origin; prohibited commit `6502452` not an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` correctly described the completed inventory but still
  named `analysis/connected-device-inventory`. They were updated for the
  dedicated architecture branch before serving as final continuation truth.
- **Preconditions:** Read `AGENTS.md`, all required continuation, inventory,
  evidence, protocol, architecture, blocker, plan, source-inventory, build, and
  README documents. Inspected solution/build properties, every current
  `src/driver/ChatpadFilter/` file, the inventory collector's evidence
  boundary, relevant Git history, branch, HEAD, status, and complete initial
  diff.
- **Legacy attachment investigation:** Examined the filter `sources`, header,
  implementation, IOCTL contract, and XP/Vista/7 INF variants beneath
  `legacy/source_release_0_0_4a/`, including installer copies. The INFs target
  exact hardware ID `USB\VID_045E&PID_028E` and set device-key
  `LowerFilters=ChatpadFilter`; `EvtDeviceAdd` calls `WdfFdoInitSetFilter`;
  `EvtDevicePrepareHardware` creates `WDFUSBDEVICE`; and the internal-control
  queue intercepts `IOCTL_INTERNAL_USB_SUBMIT_URB` and
  `URB_FUNCTION_SELECT_CONFIGURATION`.
- **Legacy transport investigation:** Traced
  `WdfUsbTargetDeviceSendControlTransferSynchronously`, setup-packet copying,
  cached interface/pipe acquisition, the interface-0 pipe-0/1 and interface-2
  pipe-0 ordinal assumptions, proxy controller reads, two direct Chatpad read
  URBs, IOCTL read queues, `InitChatpad`, `ChatpadReadFunction`, and
  `HandleChatpadData`. The six-call order and five-byte packet boundary remain
  protocol evidence; current endpoint identity and access do not.
- **Legacy output/lifetime investigation:** Examined keyboard/mouse INFs,
  KMDF layers, WDM HID minidrivers, `HidRegisterMinidriver`, PnP ID spoofing,
  global device collections/pointers, D0 callbacks, surprise-removal behavior,
  reusable-request cleanup, cancellation handling, and user-mode worker
  lifetime. These support rejection of the obsolete multi-driver HID design
  and global/raw-pointer lifetime model.
- **Installed WDK evidence:** Read-only inspection found
  `C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared\vhf.h`,
  kernel `vhfkm.lib`, and user-mode VHF libraries. The header exposes VHF for
  Windows 10-and-later targets and declares `VhfCreate`, `VhfStart`,
  `VhfDelete`, and `VhfReadReportSubmit`. VHF is recorded as a candidate, not
  selected without isolated lifecycle/signing/HVCI validation.
- **Architecture decision:** The physical
  `USB\VID_045E&PID_028E`/`XnaComposite` devnode and a device-specific lower
  filter beneath `xusb22` are the conditional design direction. Candidate A is
  explicitly unresolved, not preferred, until default-control access and a
  safe incoming Chatpad path are both proven. Installation must never use an
  XNA/HID class-wide filter.
- **Candidate results:** A unresolved/selected direction; B unresolved and not
  selected; C rejected for transport; D rejected for blast radius; E rejected
  for the primary transport because rebinding threatens `xusb22`; F possible
  fallback for keyboard output only.
- **Layer/lifetime decision:** Portable descriptors/parser/executor stay free
  of WDF types. A Windows adapter will eventually translate requests and own
  five-byte input copies. A parented per-device context/generation blocks new
  work, cancels scheduler/reader/requests, drains completions, and releases
  transport resources before context deletion. Keyboard output is a separate
  downstream component.
- **Stop gates:** Exact attachment, unchanged `xusb22` behavior, default-control
  and incoming-transfer visibility, current endpoint/input evidence, fully
  mocked lifecycle safety, tested device-specific recovery, and later explicit
  authorization are all mandatory. Gate failure stops work and does not permit
  legacy-ordinal guesses or activation traffic.
- **Files created:**
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, append-only
  `docs/WORKLOG.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`,
  `docs/PORTING-PLAN.md`, and
  `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`.
- **Pre-edit validation:** `tools/Test-RepositorySafety.ps1` PASS;
  `git diff --exit-code -- legacy` exit 0; prohibited-ancestor check exit 1 as
  required; source and project trees clean.
- **Draft assertion correction:** An initial documentation assertion exited 1
  because the table labeled the final gate `7. Explicit authorization` rather
  than containing the literal text `Gate 7`. All seven table labels were made
  explicit; the repeated structure/concept assertion passed with 23/23 ordered
  sections. No runtime or repository-safety check failed.
- **Final validation:** Complete and staged diffs inspected; staged/worktree
  architecture blobs match; `tools/Test-RepositorySafety.ps1` PASS;
  `git diff --cached --check` exit 0; staged and unstaged legacy diffs exit 0;
  prohibited-ancestor check exit 1 as required; seven staged files are all
  documentation; private-identifier and forbidden-file-type scans PASS;
  source/project/legacy status clean; no unstaged or untracked files.
- **Builds:** Not run because this task prohibits implementation/project edits
  and the applicable proof is documentation/scope validation. The previous
  protocol and compile checkpoints remain unchanged.
- **Commit and push:** Commit exactly
  `docs: design windows 11 chatpad transport architecture`; push only
  `origin/analysis/windows11-transport-architecture`. The self-referential
  commit hash is reported after commit and push rather than embedded here.
- **Next task:** Define a kernel-safe transport-adapter interface and fully
  mocked, WDF-independent implementation with cancellation/device-generation
  tests and no WDF request or hardware behavior.
- **Safety:** No device/interface handle, additional live enumeration,
  SetupAPI/Configuration Manager runtime call, USB/HID/IOCTL/URB request,
  activation, report read/write, detach/reconnect/reset/restart, driver or
  service operation, INF/CAT/certificate/package change, signing, installation,
  deployment, loading, capture, elevation, source/project/legacy edit, or
  external-skill modification occurred. The required Git push is the only
  authorized network action.

## 2026-06-29T22:15+04:00 — Mocked transport adapter contract

- **Objective:** Add a kernel-safe, WDF-independent transport-adapter contract
  with a fully mocked deterministic implementation/test seam, validate it in
  user mode and WDK compile-only mode, document the state, commit, and push
  `feature/transport-adapter-contract`.
- **Starting branch and commit:** `feature/transport-adapter-contract` /
  `37326ec5cc9c3745ee692f9250904475de0af7dd`; clean tree; tracking
  `origin/feature/transport-adapter-contract`; prohibited commit `6502452`
  not an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` still described the completed
  `analysis/windows11-transport-architecture` branch. They were replaced for
  this branch before final handoff.
- **Preconditions and investigation:** Read `AGENTS.md`, continuation docs,
  current architecture, protocol documentation, build documentation, recent
  worklog entries, protocol production sources, protocol tests, kernel
  compile-check project, driver skeleton sources/projects, solution, and build
  scripts. Verified `legacy/` clean and prohibited ancestry absent before
  editing.
- **Files created:** `src/transport/ChatpadTransport/ChatpadTransportAdapter.h`,
  `src/transport/ChatpadTransport/ChatpadTransportAdapter.c`,
  `src/transport/ChatpadTransport/ChatpadTransport.vcxproj`,
  `src/transport/ChatpadTransport/README.md`,
  `tests/transport/ChatpadTransportTests.c`,
  `tests/transport/ChatpadTransportTests.vcxproj`,
  `tests/transport/fixtures/ChatpadTransportMock.h`,
  `tests/transport/README.md`, and `tools/Test-ChatpadTransport.ps1`.
- **Files modified:** `ChatpadWin11.sln`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.c`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/ChatpadProtocolKernelCompileCheck.vcxproj`,
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`,
  `docs/BUILDING.md`, `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`,
  `docs/DECISIONS.md`, and this worklog.
- **Implementation details:** `ChatpadTransport` is a native static library
  with caller-owned state, explicit device generation, neutral operation
  tokens, value-copied activation requests from existing protocol interfaces,
  delay metadata emission from the existing activation executor, cancellation
  state, stale-generation/stale-completion/duplicate/unknown completion
  classification, and no mutable global state. The mock sink is test-only and
  bounded.
- **Build integration:** Added `ChatpadTransport.vcxproj` and
  `ChatpadTransportTests.vcxproj` to `ChatpadWin11.sln` for Debug/Release x64,
  with outputs and intermediates under `artifacts/`. The transport test
  project references both `ChatpadTransport` and the existing `ChatpadProtocol`
  library. The existing WDK static-library compatibility project now compiles
  the transport public header and production source alongside protocol sources.
- **Pre-edit validation:** `tools/Get-DriverBuildEnvironment.ps1` exit 0;
  `tools/Test-RepositorySafety.ps1` PASS; `git diff --exit-code -- legacy`
  exit 0; `git merge-base --is-ancestor 6502452 HEAD` exit 1 as required;
  `tools/Test-ChatpadProtocolParser.ps1` PASS with `610/610`.
- **During-task corrections:** The first transport wrapper run failed because
  blank `OutDir`/`IntDir` MSBuild properties overrode project artifact paths;
  the wrapper was corrected to let projects own their paths and pass
  `RepoRoot`. The first C compile found an identifier collision between the
  invalid-generation constant and result enum; the result enum was renamed to
  `CHATPAD_TRANSPORT_INVALID_GENERATION_ID`. A test initially reused a cleared
  failed-submit output; the test was corrected to preserve the pending token
  before exercising cancellation completion.
- **Transport validation:** `tools/Test-ChatpadTransport.ps1 -Configuration
  Debug -Platform x64` PASS, `186/186`, `.lib` SHA-256
  `37B41BF22E0AAAE3F4852CBE08E8D6B83EE301F67ED2B228553F4C5FD9AA53CA`,
  executable SHA-256
  `CC7386AE7ADE04A1B0108ACF6E75485AE209D727EDE55740B1C536BAAFE5479B`.
  Release PASS, `186/186`, `.lib` SHA-256
  `EB3EB6BC6C7983B46864B09B4774A538039AC22B1F417CAF67B51C1CBE4199D0`,
  executable SHA-256
  `63E7AB822B05BA7AC0FFD7A110C812F74689CEF4F43694B0B0DBDD0430A96B14`.
- **Kernel compatibility validation:** Debug and Release
  `tools/Test-ChatpadProtocolKernelCompatibility.ps1` PASS with the transport
  source included. Debug compatibility library SHA-256
  `7B8171E2B947EE12D906D0DAFC0352B8D5F24A7B038B9C834CF5AE95D3E6F2A0`;
  Release SHA-256
  `7FCB8B6753EE2DBC36370E50F81DDAAA23EFD6A45F2B05B2A4E4E3D7DBCD5792`.
  Both reported no signing execution and no `.sys`, INF, CAT, certificate,
  package, installer, or deployment output.
- **Final validation:** `tools/Get-DriverBuildEnvironment.ps1` exit 0;
  `tools\Test-RepositorySafety.ps1` PASS before and during validation;
  `tools\Test-ChatpadProtocolParser.ps1` PASS, `610/610`, executable SHA-256
  `06FF5D359854FBE663D71E92E6F56513C97438E921BEF6260205F99226E365A1`;
  `tools\Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64` PASS,
  `610/610`, library SHA-256
  `5131DEEF21E5B254DA7800C5C8C7168604A69AA89238FBCE3C4F6E72319EBFFA`,
  executable SHA-256
  `251EB0C0A977E6A089212A16B07E625E39C8BC71E5B2196ABC6127EFD6CF341B`;
  Release PASS, `610/610`, library SHA-256
  `15AB8A9AD8ECEAF0DA590F2CCE13A62FF16B19B7A068BFFF32F1C86C84A7B783`,
  executable SHA-256
  `FEC058CF00DFF26D107F7FE534744EB1DF361418B49FA7943EC347CB290CE559`.
  `tools\Build-Driver.ps1 -Configuration Debug -Platform x64` PASS,
  `Authenticode.NotSigned`, no SignTool execution, driver SHA-256
  `0e03c2cce031a79724d4d1c66abe627b396c19ec8ca784b7ebad477186f0d835`;
  Release PASS, `Authenticode.NotSigned`, no SignTool execution, driver
  SHA-256 `2fb451e08e5be8bbfe403e495ffdf75b6672a6b3d74bc2e1f657bd5991bf9797`.
- **Final safety and isolation checks:** Final
  `tools\Test-RepositorySafety.ps1` PASS; `git diff --check` exit 0;
  `git diff --exit-code -- legacy` exit 0; prohibited-ancestor check exit 1
  as required. `ChatpadFilter.vcxproj` has no `ProjectReference`,
  `ChatpadProtocol`, or `ChatpadTransport` entries and lists only `driver.c`
  and `device.c` as compile sources. `ChatpadWin11.sln` has no
  `ProjectDependencies` section for `ChatpadFilter`. The latest Debug and
  Release diagnostic driver-build logs contain no protocol or transport linker
  inputs in the `ChatpadFilter` build section.
- **Generated artifact locations:** `artifacts\bin\x64\Debug\ChatpadTransport\`,
  `artifacts\bin\x64\Release\ChatpadTransport\`,
  `artifacts\bin\x64\Debug\ChatpadTransportTests\`,
  `artifacts\bin\x64\Release\ChatpadTransportTests\`,
  `artifacts\bin\x64\<Configuration>\ChatpadProtocolKernelCompileCheck\`, and
  timestamped logs under `artifacts\logs\`.
- **Commit and push:** Commit exactly
  `feat: add mocked transport adapter contract`; push only
  `origin/feature/transport-adapter-contract`. The self-referential commit
  hash is reported after commit and push rather than embedded here.
- **Next task:** Non-installable KMDF lower-filter lifecycle scaffold with
  context/generation/lifecycle bookkeeping, cancel/rundown, and logging stubs
  only; no INF, USB/hardware behavior, install, package, sign, deploy, or load.
- **Safety:** No `legacy/` edits; no WDF/WDM/USB/HID/SetupAPI/Configuration
  Manager/WinUSB/IOCTL/URB/device-handle/endpoint/pipe/ETW/capture/sleep/
  timer/thread/retry/readiness/response/driver-callback/INF/CAT/sign/package/
  install/load/deploy behavior; no protocol/transport source linked or
  compiled into `ChatpadFilter`.

## 2026-06-29T23:05+04:00 — KMDF lifecycle scaffold

- **Objective:** Add a non-installable KMDF filter lifecycle scaffold with
  per-device context, neutral prepare/D0/release bookkeeping, nonzero D0
  generation epochs, operation admission/rundown state, stale-generation
  protection, deterministic diagnostic logging, offline lifecycle-core tests,
  validation wrapper, documentation, commit, and push.
- **Starting branch and commit:** `feature/kmdf-lifecycle-scaffold` /
  `29c3fc1a55ded35c8e33f6ceb88e2a434334ef9a`; clean tree; tracking
  `origin/feature/kmdf-lifecycle-scaffold`; prohibited commit `6502452` not an
  ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` correctly described the completed transport branch rather
  than this prepared lifecycle branch. They were updated for the live branch,
  starting commit, implemented scaffold, validation state, and next
  continuation point.
- **Preconditions and investigation:** Read `AGENTS.md`, continuation docs,
  current architecture/inventory/porting/build documents, latest relevant
  worklog entries, driver skeleton source/project/README, transport source and
  test README, kernel compatibility README, solution/build properties, and
  build/test/safety scripts. Verified branch, HEAD, clean status, recent
  history, and prohibited ancestry before editing.
- **Files created:** `src/driver/ChatpadFilter/ChatpadFilterLifecycle.h`,
  `src/driver/ChatpadFilter/ChatpadFilterLifecycle.c`,
  `tests/driver/ChatpadFilterLifecycleTests/ChatpadFilterLifecycleTests.c`,
  `tests/driver/ChatpadFilterLifecycleTests/ChatpadFilterLifecycleTests.vcxproj`,
  `tests/driver/ChatpadFilterLifecycleTests/README.md`, and
  `tools/Test-ChatpadFilterLifecycle.ps1`.
- **Files modified:** `ChatpadWin11.sln`, `docs/BUILDING.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, `docs/PROJECT-STATE.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`, this worklog,
  `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`,
  `src/driver/ChatpadFilter/README.md`,
  `src/driver/ChatpadFilter/device.c`, and
  `src/driver/ChatpadFilter/driver.h`.
- **Implementation details:** `ChatpadFilterLifecycle` is a portable C,
  caller-owned core with neutral phases: unset, created, prepared, D0 active,
  rundown requested, D0 stopped, and released. Generation zero is invalid;
  first D0 entry returns generation `1`; later D0 entries after completed D0
  exit increment generation; exhaustion returns a deterministic failure. D0
  entry opens admission. D0 exit closes admission, starts rundown, and
  completes only when outstanding count is zero. Stale-generation acquire,
  release, rundown, and completion attempts reject without mutating current
  state. The core has no allocation, I/O, global mutable state, retained caller
  pointer, WDF/WDM/Windows/USB/HID/IOCTL/request/queue/timer/work-item/protocol
  or transport dependency and is externally serialized by its caller.
- **KMDF scaffold details:** `EvtDeviceAdd` validates normal KMDF arguments,
  calls `WdfFdoInitSetFilter(DeviceInit)`, configures only PnP/power lifecycle
  callbacks, creates a per-device context, initializes lifecycle state, and
  marks the device-created phase. The context contains only signature/version,
  a diagnostic sequence counter, and lifecycle core state. Prepare/release
  callbacks mark the conceptual resource epoch without inspecting or using
  resource lists. D0 callbacks delegate generation/admission/rundown
  transitions to the core. `EvtDeviceD0Exit` does not wait; incomplete rundown
  returns a busy status.
- **Status mapping:** invalid lifecycle transitions map to
  `STATUS_INVALID_DEVICE_STATE`; null output/state, invalid generation, and
  stale generation map to `STATUS_INVALID_PARAMETER`; generation or outstanding
  overflow maps to `STATUS_INTEGER_OVERFLOW`; admission closed or incomplete
  rundown maps to `STATUS_DEVICE_BUSY`.
- **Diagnostic logging:** the KMDF layer logs deterministic neutral values only:
  sequence, callback name, phase, current generation, next generation,
  outstanding count, admission flag, and lifecycle result. No WPP, manifest,
  ETW, registry, file, network, allocation, machine identifier, raw pointer,
  or device identifier logging was added.
- **Filter capability caveat:** The scaffold documents that
  `WdfFdoInitSetFilter(DeviceInit)` makes the binary filter-capable only. With
  no INF, service binding, package, signing, installation, or load path, this
  task does not prove the `.sys` is attached, positioned beneath `xusb22`, or
  targeted at `USB\VID_045E&PID_028E`; those remain future installation
  responsibilities.
- **Pre-edit validation:** `tools/Get-DriverBuildEnvironment.ps1` exit 0;
  `tools/Test-RepositorySafety.ps1` PASS; `git diff --exit-code -- legacy`
  exit 0; prohibited-ancestor check exit 1; `tools/Test-ChatpadProtocolParser.ps1`
  PASS with `610/610`; transport Debug and Release wrappers PASS with
  `186/186`.
- **During-task corrections:** The first lifecycle wrapper invocation failed
  before execution because a PowerShell error string used `$file:` interpolation;
  it was corrected to `${file}:`. The first lifecycle compile found a C
  preprocessor collision between the invalid-generation constant and a result
  enum member; the result enum was renamed. The first Release driver build
  found `KdPrintEx` arguments compiled out as unreferenced under `/WX`; the
  diagnostic parameters are now explicitly marked referenced.
- **Lifecycle validation:** Debug Windows PowerShell 5.1
  `tools/Test-ChatpadFilterLifecycle.ps1 -Configuration Debug -Platform x64`
  PASS; source/project guard PASS; MSBuild exit 0; test exit 0; `109/109`;
  executable
  `artifacts\bin\x64\Debug\ChatpadFilterLifecycleTests\ChatpadFilterLifecycleTests.exe`;
  SHA-256 `0D3802BBF3B0171E1223F8E066FBA4CA8D486F47CF48AD989E42706815155757`.
  Release Windows PowerShell 5.1 PASS; source/project guard PASS; MSBuild exit 0; test exit 0;
  `109/109`; executable
  `artifacts\bin\x64\Release\ChatpadFilterLifecycleTests\ChatpadFilterLifecycleTests.exe`;
  SHA-256 `8EFEF8CA2ABC2CF8330C120B439A86639034C461EEC2286F0851417C23331F04`.
- **Driver validation:** Debug `tools/Build-Driver.ps1 -Configuration Debug
  -Platform x64` PASS; `ChatpadFilterLifecycle.c` compiled into
  `ChatpadFilter`; no SignTool or active signing task; output
  `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`;
  `Authenticode.NotSigned`; SHA-256
  `b7c19f4f54a91c0e172bb44a629c4ffb22359de59cb415021ffa2793c1feabff`.
  Release PASS; no SignTool or active signing task; output
  `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`;
  `Authenticode.NotSigned`; SHA-256
  `5c27c85b1918009331f02a18f7558fb81fe47cf280a431fddde9a38f34a252e0`.
- **Protocol regression validation:** `tools/Test-ChatpadProtocolParser.ps1`
  PASS, `610/610`, executable SHA-256
  `746AFF764A136C8025FED5E6A5520B718B21B532A27387841ECAC8E80482735C`.
  Integrated Debug PASS, `610/610`, library SHA-256
  `2945B9D411FDD21C86E9492AF75F5698D90C06EA8292CC5184F481971E907DC5`,
  executable SHA-256
  `21ED38B5C7C80670E63F7BAB279CE939166BD247E086AFF84ED008608F456A3A`.
  Integrated Release PASS, `610/610`, library SHA-256
  `200A770BE3A89E85530ECF2D510006AE972088B25632601C4AEE28D5FA962CCC`,
  executable SHA-256
  `4AD4F6F82D24564BA7A9BFA8535A652B489ADEBFB766026B0ACB5171ED4F878A`.
- **Transport regression validation:** Debug PASS, `186/186`, library
  `artifacts\bin\x64\Debug\ChatpadTransport\ChatpadTransport.lib`,
  SHA-256 `502C9CD293D098AAE5A6953E592FEC0E81B3D7E504E84732CCD6749EF9697D7B`,
  test executable
  `artifacts\bin\x64\Debug\ChatpadTransportTests\ChatpadTransportTests.exe`,
  SHA-256 `69195506272DD3FE272AFA2B2E2404872B7518BC4A73C1DCF676C94AA7667C5D`.
  Release PASS, `186/186`, library
  `artifacts\bin\x64\Release\ChatpadTransport\ChatpadTransport.lib`,
  SHA-256 `5DA8FD2A2F65142E900258E56CF98DC855DDD2C0B3E3DF6BB9CA5FF4354A8DFE`,
  test executable
  `artifacts\bin\x64\Release\ChatpadTransportTests\ChatpadTransportTests.exe`,
  SHA-256 `27C028A66E018897C26180DC8FD608A695AB3B2F796F3C644B110C597CAF6261`.
- **Kernel compatibility validation:** Debug
  `tools/Test-ChatpadProtocolKernelCompatibility.ps1` PASS; `.lib` only;
  no signing execution; no `.sys`, INF, CAT, certificate, package, installer,
  or deployment output; library
  `artifacts\bin\x64\Debug\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib`;
  SHA-256 `B8515FE511F085BFAEE305B0D26D247ED7F4D25D67D0DEB693FA4474EFDA1ECF`.
  Release PASS with the same `.lib`-only/prohibited-output guarantees; library
  `artifacts\bin\x64\Release\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib`;
  SHA-256 `6E2672FB9A141CD39AFCE3D78355970E9D633BC0C5169E764CC5A5EC19D1FA23`.
- **Final safety and isolation checks:** Final `tools/Test-RepositorySafety.ps1`
  PASS; `git diff --check` exit 0; `git diff --exit-code -- legacy` exit 0;
  prohibited-ancestor check exit 1. `ChatpadFilter.vcxproj` has no
  `ProjectReference`, no `ChatpadProtocol`, and no `ChatpadTransport` text;
  its compile items are only `ChatpadFilterLifecycle.c`, `driver.c`, and
  `device.c`. Source/project guard found no prohibited runtime surfaces:
  `WdfUsbTargetDevice`, `WDFUSB`, `URB`, `IOCTL_INTERNAL_USB`,
  `WdfIoQueueCreate`, `WdfDeviceCreateDeviceInterface`, `WdfTimerCreate`,
  `WdfWorkItemCreate`, `CreateFile`, or `DeviceIoControl`.
- **Generated artifacts:** All build outputs and logs remain under ignored
  `artifacts\`; none are staged or committed.
- **Commit and push:** Commit exactly `feat: add kmdf lifecycle scaffold`;
  push only `origin/feature/kmdf-lifecycle-scaffold`. The self-referential
  commit hash is reported after commit and push rather than embedded here.
- **Remaining risks or limitations:** Compile-only scaffold. No installation
  target, lower-filter stack position, USB transport path, default-control
  access, endpoint/input path, response semantics, readiness, retry, activation
  traffic, input reader, keyboard presentation, or hardware behavior is proven
  or implemented.
- **Safety:** No `legacy/` edits; no INF/CAT/certificate/package/service/
  installer/signing/deployment/load behavior; no device/interface open; no
  USB/HID/WinUSB/SetupAPI/Configuration Manager/IOCTL/URB/endpoint/pipe
  behavior; no queue/request interception/forwarding/submission/formatting; no
  activation/input/key-mapping behavior; no timer/work item/thread/continuous
  reader/polling loop; no protocol or transport source linked into
  `ChatpadFilter`; no driver installation, signing, packaging, deployment,
  loading, or hardware testing occurred.

## 2026-06-30T00:00+04:00 — KMDF transport bridge design

- **Objective:** Design, document, review, commit, and push the future KMDF
  transport bridge between `ChatpadActivationExecutor`,
  `ChatpadTransportAdapter`, a per-device KMDF transport owner, and later WDF
  USB request translation/submission, without implementing runtime transport
  behavior.
- **Starting branch and commit:** `analysis/kmdf-transport-bridge-design` /
  `e3729efbcdd2891bfcb3a427b82e4be7c99d8d16`; clean tree; tracking
  `origin/analysis/kmdf-transport-bridge-design`; prohibited commit `6502452`
  not an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` still described the completed
  `feature/kmdf-lifecycle-scaffold` continuation point even though the live
  branch was `analysis/kmdf-transport-bridge-design` at the required starting
  commit. They were updated to the live branch, bridge-design result, current
  gates, and next translation task before finalizing. `docs/CHATPAD-PROTOCOL.md`
  also retained an older evidence-table row treating `0x90, 0x00` as
  medium-confidence initialization evidence; it was corrected to the focused
  audit's current conclusion that the value is only a comment-only claim on
  unused declarations and that executable activation uses confirmed payload
  `09 00`.
- **Preconditions and investigation:** Read `AGENTS.md`, continuation docs,
  latest relevant worklog entries, Windows 11 transport architecture,
  connected-device inventory, initialization/status evidence, protocol,
  porting, blocker, and building docs; inspected every file under
  `src/driver/ChatpadFilter/`, `src/transport/ChatpadTransport/`, and
  `src/protocol/ChatpadProtocol/`; inspected relevant transport and lifecycle
  tests, `ChatpadWin11.sln`, `Directory.Build.props`, `tools/Build-Driver.ps1`,
  `tools/Test-ChatpadTransport.ps1`, and
  `tools/Test-ChatpadFilterLifecycle.ps1`.
- **Pre-edit validation:** `tools/Test-RepositorySafety.ps1` PASS;
  `git diff --exit-code -- legacy` exit 0; prohibited-ancestor check
  `git merge-base --is-ancestor 6502452 HEAD` exit 1; `git status --short
  --branch` clean; `git diff` empty.
- **Files created:** `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`.
- **Files modified:** `docs/DECISIONS.md`, `docs/NEXT-TASK.md`,
  `docs/CHATPAD-PROTOCOL.md`, `docs/PORTING-PLAN.md`, `docs/PROJECT-STATE.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`, this worklog,
  `src/driver/ChatpadFilter/README.md`, and
  `src/transport/ChatpadTransport/README.md`.
- **Design details:** The bridge design selects one future per-device KMDF
  transport owner under `WDFDEVICE` for bounded activation bridge state,
  request-owner records, future target references, future delay scheduler
  state, diagnostics, and separate continuous-input state. Future WDF requests
  are tied to exactly one nonzero lifecycle D0 generation through a
  request-owner record containing the portable
  `ChatpadTransportOperationToken`; raw request pointers are not generation or
  operation tokens.
- **Synchronization details:** The recommended first implementation strategy is
  a per-device `WDFSPINLOCK` for short lifecycle/bridge/request-table,
  completion-once, cancellation, generation, scheduler-state, and diagnostics
  transitions. KMDF automatic synchronization, `WDFWAITLOCK`, and passive
  serialized work are documented as narrower or fallback options; unsupported
  lock-free use is rejected.
- **Lifecycle and completion details:** D0 entry starts one lifecycle
  generation and initializes the bounded activation adapter for that
  generation. D0 exit closes admission before cancellation and before delay
  scheduling. Future completions must compare stored generation/token, reject
  stale and duplicate completions, and release lifecycle outstanding counts
  exactly once. Successful lower-stack completion is explicitly not Chatpad
  readiness.
- **Delay and input details:** The six 12 ms values remain delay metadata owned
  by a future per-device scheduler only after prior request completion policy
  permits progression. Blocking sleep is rejected. Continuous input is
  separated from the activation adapter's 64-operation tracking model and
  remains blocked on endpoint/input evidence.
- **Stop gates:** The design defines gates for synchronization, request
  ownership, pure translation, compile-only WDK formatting, lifecycle race
  tests, installation recovery, stack visibility, and explicit authorization.
  Passing documentation or compile gates does not authorize USB traffic.
- **Next task:** Pure, WDF-independent Windows control-setup translation for
  the six neutral activation descriptors, with offline tests and kernel compile
  validation only; no WDF target/request/formatter/submission or hardware
  behavior.
- **Validation planned after documentation:** rerun repository safety, run
  `git diff --check`, confirm `legacy/` unchanged, confirm only documentation
  and README continuity files changed, inspect complete and staged diffs, then
  commit exactly `docs: design kmdf transport adapter bridge` and push only
  `origin/analysis/kmdf-transport-bridge-design`.
- **Remaining risks or limitations:** No default-control access, input
  endpoint, transfer ownership, response semantics, acknowledgement, readiness,
  retry, timeout, lower-filter installation, keyboard presentation, or live
  hardware behavior is proven or implemented.
- **Safety:** No `legacy/` edits; no source, project, solution, INF, CAT,
  certificate, package, service, installer, signing, deployment, load,
  device/interface open, USB/HID/IOCTL/URB, endpoint/pipe, WDF target, WDF
  request, queue, timer, work item, continuous reader, thread, ETW, capture,
  elevation, hardware enumeration, or external-skill action occurred.

## 2026-06-30T00:35+04:00 — Pure control-setup translation

- **Objective:** Implement a pure, WDF-independent translator from a
  caller-provided `ChatpadActivationRequest` to explicit setup bytes and
  caller-owned data-stage metadata; validate in user mode and through the WDK
  kernel toolchain; document, commit, and push the result.
- **Starting branch and commit:** `feature/control-setup-translation` /
  `55e84722a73ce1d65fde2af829986e9ee5d66995`; clean tree tracking
  `origin/feature/control-setup-translation`; prohibited commit `6502452` not
  an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` described the completed bridge-design branch because the
  requested feature branch had just been prepared at that design commit. Live
  Git matched the exact task preflight, so continuity was updated to the live
  branch and implementation and the discrepancy was not treated as code state.
- **Investigation:** Read the required protocol, evidence, architecture,
  bridge-design, building, porting, project, source, test, project-file, and
  wrapper surfaces. Verified all protocol and transport source files, relevant
  tests, solution mappings, build properties, driver project isolation, and
  existing kernel compile-check behavior before editing.
- **Files created:** `src/transport/ChatpadControlSetup/ChatpadControlSetup.h`,
  `.c`, `.vcxproj`, and `README.md`;
  `tests/transport/ChatpadControlSetupTests/ChatpadControlSetupTests.c`,
  `.vcxproj`, `README.md`, and
  `fixtures/ChatpadControlSetupFixtures.h`; and
  `tools/Test-ChatpadControlSetup.ps1`.
- **Files modified:** `ChatpadWin11.sln`, `docs/BUILDING.md`,
  `docs/CHATPAD-PROTOCOL.md`, `docs/DECISIONS.md`, `docs/NEXT-TASK.md`,
  `docs/PROJECT-STATE.md`, both Windows 11 architecture/design documents,
  this worklog, `src/transport/ChatpadTransport/README.md`, and the kernel
  compile-check source, project, and README.
- **Implementation:** `ChatpadTranslateActivationRequest` validates nulls,
  direction enum, `bmRequestType` direction bit, outbound/inbound length
  consistency, and fixed payload capacity. It clears the full non-null output
  bytewise before validation, explicitly encodes eight setup bytes
  little-endian, copies outbound payload by value, and records expected inbound
  length without allocating a response buffer. It has no mutable global state,
  packing, structure overlay, retained pointer, allocation, or I/O.
- **Confirmed translations:** exact setup arrays are
  `40 a9 0c a3 23 44 00 00`, `40 a9 44 23 03 7f 00 00`,
  `40 a9 39 58 32 68 00 00`, `c0 a1 00 00 16 e4 02 00`,
  `40 a1 00 00 16 e4 02 00`, and `c0 a1 00 00 16 e4 02 00`.
  Request 4 carries copied outbound `09 00`; requests 3 and 5 expect two
  inbound bytes; confirmed fixtures contain no outbound `90 00`.
- **Pre-edit baseline:** environment detector exit 0; repository safety PASS;
  `legacy/` unchanged; prohibited-ancestor check exit 1; direct protocol
  `610/610`; transport Debug/Release `186/186`; lifecycle Debug/Release
  `109/109`.
- **During-task corrections:** The first wrapper guard selected XML build
  settings as source items and failed before compilation; its XPath was narrowed
  to item nodes. The first native run compiled successfully but exposed
  nondeterministic structure padding during whole-value comparisons; the
  translator now clears the complete output bytewise. The wrapper's summary
  regex was also made CRLF-aware for Windows PowerShell 5.1.
- **Control-setup validation:** Windows PowerShell 5.1 Debug and Release source/
  project guards PASS; MSBuild exit 0; tests `141/141`; artifact containment
  PASS. Debug library SHA-256
  `F82965C44A179DD7EE5369469524604145C27368ED069BA0223D43E1AC2B0EB4`;
  Debug executable SHA-256
  `8059411DFE493510AEA33AF822465D3797DD0E53B16F59082C35BE2EA407384E`;
  Release library SHA-256
  `6C24F82BC5C27BB849CBA02FEB59CB13865F4AB30217AA712260DCB8FEC7C5BD`;
  Release executable SHA-256
  `F862F8FFAFA5822C7471FF6E1A1283FA7A5046F5F7BC9EF631313B365D14F347`.
- **Regression validation:** Integrated protocol Debug/Release `610/610`;
  transport Debug/Release `186/186`; lifecycle Debug/Release `109/109`.
- **Kernel compatibility:** Debug and Release WDK builds compile the translator
  source/header and emit only
  `artifacts\bin\x64\<Configuration>\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib`.
  Debug SHA-256
  `DD6BA30F03611E6617036C7F64D21373695B74E766776C3834768E0D940E52C2`;
  Release SHA-256
  `F08148853D9DAF8AC37332112B11D486B5A278633A1241A373A41076E2621F41`.
  No signing execution or `.sys`, INF, CAT, certificate, package, installer, or
  deployment output occurred in these checks.
- **Driver validation and isolation:** Debug driver
  `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`, SHA-256
  `fd3776f3687e9a3d1e75306ec09ca0c9c22bbcf0353bc3270248f7ff90bf115f`;
  Release driver `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  SHA-256
  `c041ba7c5b8f146589afb0e0db44848434d47406ea40d047a7fdd309f0ca0f18`.
  Both build exit 0, remain `Authenticode.NotSigned`, and show no SignTool
  operation. `ChatpadFilter.vcxproj` has no project reference and compiles only
  `ChatpadFilterLifecycle.c`, `driver.c`, and `device.c`; the solution has no
  driver dependency section; Debug/Release driver log sections contain no
  protocol, transport, or control-setup linker input.
- **Commit and push:** Commit exactly `feat: add pure control setup translation`
  and push only `origin/feature/control-setup-translation`. The self-referential
  commit hash is reported after commit/push rather than embedded here.
- **Next task:** Isolated compile-only WDK formatting from the pure value into
  an inspectable `WDF_USB_CONTROL_SETUP_PACKET`, with no target, request,
  memory object, formatting/submission, driver dependency, install, or hardware
  behavior.
- **Safety:** No `legacy/` edit; no Windows/WDF/WDM/USB/HID/IOCTL/URB runtime
  API; no request/target/queue/interface/timer/work-item/thread/handle; no
  device enumeration or access; no disconnect/reconnect/reset; no transfer,
  response decode, acknowledgement, retry, timeout, readiness, endpoint, pipe,
  capture, elevation, INF/CAT/certificate/package/service/installer, signing,
  installation, deployment, loading, external-skill edit, or hardware action.

## 2026-06-30T00:58+04:00 - Compile-only WDF control-setup formatter

- **Objective:** Implement, validate, document, commit, and push an isolated
  WDK formatter from `ChatpadControlSetupTranslation` to a caller-owned
  `WDF_USB_CONTROL_SETUP_PACKET`, without creating a WDF object or connecting
  the formatter to `ChatpadFilter`.
- **Starting branch and commit:** `feature/wdf-control-setup-formatter` /
  `9542fdd63493a455f6de4720542a48ca22f6fa96`; clean tree tracking
  `origin/feature/wdf-control-setup-formatter`; prohibited commit `6502452` not
  an ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` still described the completed pure-translation branch
  because this formatter branch had just been prepared at that commit. Live
  Git matched every hard precondition, so the documents were corrected to the
  live formatter task before finalization.
- **Investigation:** Read the required continuation, protocol, evidence,
  architecture, bridge-design, building, porting, source, test, project, and
  wrapper surfaces. Inspected the installed KMDF 1.15 header at the stable WDK
  relative path `Windows Kits/10/Include/wdf/kmdf/1.15/wdfusb.h` and the WDK
  KMDF USB project template. Relevant symbols were
  `WDF_USB_CONTROL_SETUP_PACKET`, `WDF_USB_CONTROL_SETUP_PACKET_INIT`,
  `WDF_USB_CONTROL_SETUP_PACKET_INIT_CLASS`, and
  `WDF_USB_CONTROL_SETUP_PACKET_INIT_VENDOR`; the template's declaration
  include order is `wdf.h`, `usb.h`, `usbdlib.h`, then `wdfusb.h`.
- **Files created:** `src/transport/ChatpadWdfControlSetup/` formatter header,
  source, static-library project, and README;
  `tests/kernel/ChatpadWdfControlSetupCompileCheck/` source, static-library
  project, and README; and `tools/Test-ChatpadWdfControlSetup.ps1`.
- **Files modified:** `ChatpadWin11.sln`, `docs/BUILDING.md`,
  `docs/CHATPAD-PROTOCOL.md`, `docs/DECISIONS.md`, `docs/NEXT-TASK.md`,
  `docs/PORTING-PLAN.md`, `docs/PROJECT-STATE.md`, both Windows 11 architecture
  documents, this worklog, `src/transport/ChatpadControlSetup/README.md`, and
  `tests/kernel/ChatpadProtocolKernelCompileCheck/README.md`.
- **Implementation:** `ChatpadFormatWdfControlSetupPacket` clears its non-null
  output, validates data direction and setup-bit agreement, enforces outbound/
  inbound/no-data length consistency and outbound capacity, then copies all
  eight authoritative setup bytes through the public `Generic.Bytes` member.
  The class/vendor initializers were not used because they normalize fields and
  leave `wLength` for later request formatting. No activation tuple is
  duplicated; payload ownership remains outside the WDF setup value.
- **Compile-check design:** The formatter project compiles only the formatter
  source and has no project references. The compile-check project references
  only the formatter with `LinkLibraryDependencies=false`; its source passes
  all six builder translations through the pure translator and formatter and
  includes public eight-byte representation assertions. Both outputs are
  static libraries with no entry point.
- **Pre-edit baseline:** environment detector exit 0; repository safety PASS;
  `legacy/` unchanged; prohibited-ancestor check exit 1; direct protocol
  `610/610`; transport Debug/Release `186/186`; lifecycle Debug/Release
  `109/109`; pure control setup Debug/Release `141/141`.
- **During-task corrections:** The first wrapper invocation failed at parse
  time because Windows PowerShell parsed `$file:` as a scoped variable; the
  variable was delimited. The next guard attempt failed before toolchain
  detection because compact MSBuild XML did not expose `ConfigurationType`
  through a property path; the guard now uses a namespace-aware XPath. The
  first compiler attempt then showed that this installed `wdfusb.h` requires
  USB/USBD declarations; the installed KMDF USB template confirmed the
  supported include order, which was added without introducing runtime calls.
- **Formatter validation:** Debug and Release source/project guards PASS;
  MSBuild exit 0; no active signing; no `.sys`, INF, CAT, certificate, package,
  installer, or deployment output; all output beneath `artifacts/`. Debug
  formatter library SHA-256
  `3C0FD775FA83FDDDEC1B1624284CE6C823A482C9FD2845CAE9476B5C767D8CAA`;
  Debug compile-check SHA-256
  `2D7F894568D9DB4C23EE0017C5DE6C800D9977E13469AEA882A1BD4B440CD317`;
  Release formatter SHA-256
  `51BDB4301D32B4A70104E7EDE4617FA3E2EA3BE1CCCB73D319964012E307145B`;
  Release compile-check SHA-256
  `5CFF4E956C57A748669A2DB71D95B53750B3D26F2CA7670EDF369EE82F51F3ED`.
- **Regression validation:** protocol Debug/Release `610/610`; transport
  Debug/Release `186/186`; lifecycle Debug/Release `109/109`; pure control
  setup Debug/Release `141/141`.
- **Existing kernel compatibility:** Debug and Release WDK builds PASS with
  `.lib` only, no signing, prohibited output, or escaped artifacts. Debug
  SHA-256 `9B6E42E4AE20EFD1A03832890BE7A1A71E08BB923EB9A827F34239B78BAD9F99`;
  Release SHA-256
  `482B478E2DD1C1DD81D58B554693BE1D675D34C1A87D819D6BF24D7C3E674B92`.
- **Driver validation and isolation:** Debug driver SHA-256
  `DC48F9F470BA6B25B218EE8CD6AA0A300D35FB92DB0F1A0BDD82852F73613593`;
  Release driver SHA-256
  `563610892A7E5067130FBDAF133C8DA876BAA1D6AE4B1903BDC894CC295E9E75`.
  Both build exit 0, remain `Authenticode.NotSigned`, and show no SignTool
  operation. The driver project has no project reference and compiles only
  `ChatpadFilterLifecycle.c`, `driver.c`, and `device.c`; the solution has no
  project-dependency section. Both diagnostic linker commands contain only
  those object files and WDK system libraries, with no formatter,
  control-setup, protocol, or transport input.
- **Commit and push:** Commit exactly
  `build: add compile-only wdf control setup formatter` and push only
  `origin/feature/wdf-control-setup-formatter`. The self-referential commit
  hash is reported after commit/push rather than embedded here.
- **Next task:** Design only a reversible device-specific lower-filter
  installation and recovery specification for `USB\VID_045E&PID_028E`; do not
  create an INF, sign, install, load, query, or touch the device.
- **Safety:** No `legacy/` edit; no WDF device, target, request, memory, queue,
  interface, timer, work item, callback, request formatting/submission,
  completion, transfer, USB/HID/IOCTL/URB operation, device enumeration or
  access, disconnect/reconnect/reset, response fabrication, capture, elevation,
  INF/CAT/certificate/package/service/installer, signing, installation,
  deployment, loading, external-skill modification, or hardware action.

## 2026-06-30T01:21+04:00 - Device-specific filter installation and recovery design

- **Objective:** Design, validate, document, commit, and push a reversible,
  device-specific lower-filter installation and recovery specification for
  `USB\VID_045E&PID_028E`, without creating an INF/package or changing the
  machine, Driver Store, registry, boot policy, security state, or device.
- **Starting branch and commit:**
  `analysis/device-specific-install-recovery-design` /
  `93cc84d94ca3a262ac1c024abd7b1affcd08a349`; clean tree tracking
  `origin/analysis/device-specific-install-recovery-design`; local HEAD,
  `origin/feature/wdf-control-setup-formatter`, and the current remote branch
  matched exactly; prohibited commit `6502452` was not an ancestor.
- **Continuity discrepancies:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` still described the completed formatter branch because
  this design branch had been prepared at that commit. They were updated to
  the live branch and design result. `docs/NEXT-TASK.md` also named nonexistent
  `docs/WINDOWS11-CONNECTED-DEVICE-INVENTORY.md`; the tracked source of truth is
  `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`, and the continuation pointer
  was corrected.
- **Investigation:** Read the required protocol and continuation documents,
  current architecture/bridge/inventory/build/porting surfaces, driver project,
  formatter README, build wrapper, and recent worklog. Verified the current
  project, solution, and diagnostic linker isolation. Consulted current primary
  Microsoft documentation for extension INFs, declarative `AddFilter` filter
  placement, PnPUtil staging/removal/export, Safe Mode/Windows RE, offline DISM
  driver removal, test signing, Secure Boot, and HVCI.
- **Pre-edit safety:** repository safety PASS; `legacy/` diff exit 0; prohibited
  ancestor exit 1; no tracked or untracked source change; no device inventory
  or system query was performed.
- **Previous-result verification:** Debug and Release
  `Test-ChatpadWdfControlSetup.ps1` passed source/project, formatter,
  compile-check, signing, prohibited-output, and containment guards. Current
  formatter hashes are
  `D7D9357B1C3E969875E51BBE7C71F367D30A7B7E72BE438D8DD2B8848DB8FE8B`
  and `8337944B935E4323AEE8DA746BCB4E7348188C0C86448C81688B1DF23B4B0469`;
  compile-check hashes are
  `B4FED2BEB03DA531A307EA2B0DA2DD56450D424935A55B466C0F4A1ED22F8B1E`
  and `D15E531F2725D081233C553A3CDB39288FE36ACBE65F1D3E6BA0BBD5B9BC7CAB`.
- **Driver verification:** Debug and Release builds exited 0, remained
  `Authenticode.NotSigned`, ran no signing task, and passed repository safety.
  Current driver hashes are
  `c3a9c65869bedfd0bd5f2231d22181100a9b1d63177c5a7c410c6be8d40f70a0`
  and `7a6f9fd5c8fbe2699d101dc7765203a113ef7a4e8b82c2c7130035ddc6c6dd50`.
  Debug/Release diagnostic linker inputs contain only
  `ChatpadFilterLifecycle.obj`, `driver.obj`, `device.obj`, and WDK system
  libraries; no formatter, control-setup, protocol, or transport library is
  linked into the driver.
- **Files created:**
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`.
- **Files modified:** `docs/DECISIONS.md`, `docs/NEXT-TASK.md`,
  `docs/PORTING-PLAN.md`, `docs/PROJECT-STATE.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`,
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`, and this worklog.
- **Package design:** A future package is an extension INF matching only
  `USB\VID_045E&PID_028E`, using a stable `ExtensionId` and declarative
  `DDInstall.Filters`/`AddFilter` with `FilterPosition=Lower`. It preserves
  `xusb22.inf`/`xusb22`, defines a non-associated demand/PnP filter service,
  and prohibits direct filter-value writes, class filters, base binding
  replacement, co-installers, custom actions, and executable installers.
- **Recovery design:** The specification defines an immutable package identity
  ledger, second-input/BitLocker/WinRE/media prerequisites, read-only PnP and
  security baselines, third-party Driver Store export, forensic registry
  exports, staging without `/install`, separately authorized attachment,
  exact-`oem#.inf` PnPUtil rollback, Safe Mode command-line recovery,
  last-resort offline DISM removal, post-recovery checks, and hard aborts.
  Registry exports are evidence, not automatic restore scripts.
- **Security decision:** Secure Boot, Memory Integrity/HVCI, VBS, and signature
  enforcement remain enabled. `TESTSIGNING`, one-boot signature bypass,
  unsigned installation, `/ForceUnsigned`, unreviewed trust changes, and
  security weakening are rejected as installation or recovery strategies.
- **Authorization gates:** Package creation, signing, staging, attachment/load,
  observation, and bounded device interaction are separate gates. Passing the
  documentation design authorizes none of them. Gate F remains operationally
  incomplete until the plan is reviewed against an actual signed package and
  demonstrated on a noncritical test system; Gate G transport visibility is
  still open.
- **Validation correction:** The first ad hoc acceptance assertion searched for
  literal `Gate I6` and returned false because the matrix row is labeled `I6`.
  The corrected assertion matched the actual heading/table structure and all
  ten design acceptance checks passed. This was a check-pattern error, not a
  document-content failure. A later compact final-check expression also let
  PowerShell combine comma-separated `-match` operands into one invalid regex;
  it emitted an error and an unusable `0/0` summary. The final run uses named
  independent checks and requires every result to be true.
- **Documentation validation:** `git diff --check` exit 0; repository safety
  PASS; `legacy/` diff exit 0; design assertions for exact target, extension
  INF, `AddFilter`, lower position, PnPUtil rollback, Safe Mode, offline DISM,
  Secure Boot, HVCI, and separate gates PASS. Complete staged diff and final
  status are inspected before commit.
- **Commit and push:** Commit exactly
  `docs: design device filter install recovery` and push only
  `origin/analysis/device-specific-install-recovery-design`. The final commit
  hash is reported after commit/push rather than embedded here.
- **Next task:** With new explicit authorization, create and statically validate
  an offline-only extension-INF package scaffold implementing this design;
  stop before signing, staging, installation, loading, elevation, or device
  interaction.
- **Remaining risks:** No actual package has been reviewed or demonstrated;
  effective filter ordering, Windows 11 default-control access, Chatpad input,
  response semantics, readiness, transport runtime, and hardware behavior
  remain unproven.
- **Safety:** No `legacy/` edit; no INF, CAT, certificate, package project,
  service, installer, signing, trust-store, Secure Boot, HVCI, VBS, BCD,
  Driver Store, registry, Device Manager, PnPUtil/DISM mutation, installation,
  deployment, load, elevation, device enumeration/query/open/restart, USB/HID/
  IOCTL/URB request, transfer, capture, disconnect/reconnect, or hardware action
  occurred. Only ignored compile outputs/logs and tracked documentation changed.
