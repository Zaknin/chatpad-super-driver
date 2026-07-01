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

## 2026-06-30T01:46+04:00 - Offline extension-INF prototype

- **Objective:** Create, statically validate, document, commit, and push one
  isolated source-controlled extension-INF prototype for a future
  device-specific Chatpad lower filter targeting only
  `USB\VID_045E&PID_028E`, without staging, packaging, signing, installation,
  load, device access, or system mutation.
- **Starting branch and commit:**
  `feature/offline-extension-inf-prototype` /
  `08ad46584b62ae159971529a3a965d6ed6086146`; clean tree tracking the same
  branch on origin; exact required HEAD; prohibited commit `6502452` not an
  ancestor.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md` and
  `docs/NEXT-TASK.md` correctly described the completed recovery-design branch
  and its recommendation, but did not yet describe the prepared prototype
  branch. They were replaced with the live branch and validated result after
  the implementation outcome was known.
- **Required investigation:** Read all mandated continuation, architecture,
  recovery, inventory, blocker, plan, building, driver README, safety, and
  legacy-INF surfaces. All 18 legacy INFs form nine duplicated XP/Vista/7
  variants. The old filter INFs prove the exact hardware ID and non-associated
  service intent but use rejected `ClassInstall32`, direct `LowerFilters`,
  co-installer, DIRID 12, IA64/x86, and KMDF 1.9 patterns.
- **Installed evidence:** WDK/SDK 10.0.26100.0 and x64 KMDF toolchain readiness
  passed. Inspected x64 `InfVerif.exe`
  `C:\Program Files (x86)\Windows Kits\10\Tools\10.0.26100.0\x64\infverif.exe`,
  file version `10.0.26100.6584`; `/?` help advertised `/k`, `/v`, `/info`,
  `/l`, `/osver`, and rule-version modes. Inspected inbox
  `C:\Windows\INF\hidgamepad.inf` for Extension class, stable `ExtensionId`,
  DIRID 13, exact model association, service, and `AddFilter`; inbox
  `mshidkmdf.inf` for position-based lower filtering; and the installed KMDF
  templates for AMD64/OS decoration, service, DIRID 13, and KMDF declarations.
- **Pre-edit gates:** environment detector exit 0; repository safety PASS;
  `legacy/` diff exit 0; prohibited-ancestor exit 1; no controller/device query
  or action.
- **Files created:**
  `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf`,
  its `README.md`, and `tools/Test-ChatpadFilterInfPrototype.ps1`.
- **Files modified:** `tools/Test-RepositorySafety.ps1`, `docs/BUILDING.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, `docs/PORTING-PLAN.md`,
  `docs/PROJECT-STATE.md`, `docs/WIN11-BLOCKERS.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`,
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`,
  `src/driver/ChatpadFilter/README.md`, and this worklog.
- **Prototype identity:** Extension class GUID
  `{E2F84CE7-8EFA-411C-AA69-97454CA4CB57}`, project ExtensionId
  `{69E7CCD7-7011-4059-95D4-618974E126DD}`, AMD64 Windows 11 minimum build
  22000, exact hardware ID `USB\VID_045E&PID_028E`, and INF SHA-256
  `7E752EDAFDB252AF746C2AE6A9EFB3032A077A23FEB39C064D0E2C30700D11CE`.
- **Filter/service model:** `DDInstall.Filters` uses
  `AddFilter=ChatpadFilter` with `FilterPosition=Lower` and no invented named
  level. `AddService` is non-associated; service `ChatpadFilter` is kernel,
  demand start, normal error control, uses `%13%\ChatpadFilter.sys`, and
  declares KMDF 1.15. The INF never names or replaces `xusb22`.
- **Catalog finding:** The first direct `InfVerif /k` run returned error 1233
  and exit 1627 because declarative validation requires `CatalogFile`.
  Declaring future identity `ChatpadFilterExtension.cat` resolved the error
  without creating a CAT. No catalog, signature, or package output exists.
- **Wrapper corrections:** Initial PowerShell 5.1 runs exposed a UTF-8
  em-dash literal mismatch, one string-to-Boolean parameter conversion, scalar
  string indexing, strict-mode null `.Count`, and strict-mode null
  `.FullName` access. Each was corrected and rerun. The initial combined
  `/k /info /l` invocation preserved exit 1627 but information output hid the
  text of error 1233; the final wrapper therefore runs primary `/k /v`
  validation separately from `/k /info` and `/k /l`, records every exit, and
  preserves the first nonzero result.
- **Final InfVerif validation:** Windows PowerShell 5.1 wrapper exit 0.
  Primary `/k /v` prints `INF is VALID`; `/k /info` exit 0 reports device
  `Chatpad Filter Extension Prototype`, exact hardware ID, AMD64, minimum OS
  `10.0.22000`, and `ChatpadFilter` lower filter; annotated `/k /l` exit 0.
  Information mode reports `Service: none` because the filter service is
  intentionally non-associated; syntax-aware semantic guards separately prove
  the exact `AddService` and KMDF sections. No warnings or errors remain.
- **Semantic guards:** PASS for exact sole hardware ID, no instance/revision
  suffix, Extension class/ID, Windows 11 AMD64 decoration, declarative lower
  filter, non-associated service, demand start, DIRID 13, KMDF 1.15, no named
  level, no direct filter registry mutation, no class targeting, no
  `DefaultInstall`, `ClassInstall32`, co-installer, executable/command,
  absolute/network path, unrelated service, `xusb22` replacement, project/build
  reference, package binary, certificate, or CAT file.
- **Validation artifacts:** final evidence under
  `artifacts/inf-validation/20260629T214908Z/`: `infverif-help.txt`,
  `infverif-output.txt`, `infverif-info.txt`, `infverif-annotated.txt`,
  `semantic-guards.txt`, and annotated HTML. All are ignored.
- **Repository-safety change:** Modern INF discovery now permits exactly
  `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf`, requires
  the adjacent exact warning, rejects prohibited companion files, and rejects
  build/package/install references outside the validator and safety script.
  Windows PowerShell 5.1 and PowerShell 7 safety runs both PASS.
- **Driver regression:** Debug x64 and Release x64 builds exit 0. Debug driver
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  SHA-256
  `f3b7123c783776b2f49296b03b5b54e66d65f14a4e71cce884a8a705d8d4c45b`,
  `Authenticode.NotSigned`; Release driver
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  SHA-256
  `00a9e8689114886c04b6c45e86603be1257b42e6215b76ce41d3a721f28c5f6a`,
  `Authenticode.NotSigned`.
- **Build isolation:** Both logs have zero prototype-path hits. Inf2Cat and
  DrvCat are skipped; no SignTool operation; no INF or CAT under `artifacts/`;
  linker inputs remain `ChatpadFilterLifecycle.obj`, `driver.obj`,
  `device.obj`, and WDK system libraries. `ChatpadFilter.vcxproj` has no diff.
- **Final validation:** `git diff --check` exit 0; `legacy/` diff exit 0;
  prohibited-ancestor exit 1; wrapper has zero state-changing/network-tool
  tokens; no CAT, certificate, package, installer, registry export, or
  machine-specific identifier exists in the tracked diff. Complete and staged
  diffs are inspected before commit.
- **Commit and push:** Commit exactly
  `build: add offline extension inf prototype` and push only
  `origin/feature/offline-extension-inf-prototype`. The final commit hash is
  reported after commit/push rather than embedded here.
- **Next task:** With new explicit authorization, create only a disposable
  package layout beneath ignored `artifacts/` and run installed Inf2Cat to
  generate an unsigned/untrusted catalog for static package validation; stop
  before signing, staging, installation, loading, elevation, network, or
  device access.
- **Remaining blockers:** Static validation does not prove effective placement
  beneath `xusb22`, ordinary controller preservation, signed-package
  acceptance, recovery, default-control access, Chatpad input, or transport
  behavior. Gate F remains operationally unresolved.
- **Safety:** No `legacy/` edit; no CAT, certificate, key, package, installer,
  service, registry or Driver Store mutation, staging, installation, binding,
  device restart, signing, loading, hardware action, USB/HID/IOCTL/URB request,
  elevation, network request, or external-skill modification occurred. The
  only new INF is the authorized isolated source prototype.

## 2026-06-30T07:28+04:00 - Offline Inf2Cat validation documentation checkpoint

- **Objective:** Create and publish a documentation-only checkpoint for the
  completed unsigned offline Inf2Cat package validation and its independent
  read-only evidence audit.
- **Starting branch and commit:**
  `feature/offline-inf2cat-package-validation` /
  `9de526a55d5b60a28229cedc3a2e4e9926db6473`; clean tracked tree and index;
  no configured upstream; `origin` present.
- **Continuity discrepancy:** `docs/PROJECT-STATE.md`,
  `docs/NEXT-TASK.md`, `docs/PORTING-PLAN.md`, `docs/WIN11-BLOCKERS.md`, and
  the checkpoint section in
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md` still described offline
  catalog closure as pending. They were updated to the retained result without
  rewriting historical task records.
- **Evidence verification:** Current INF SHA-256
  `7E752EDAFDB252AF746C2AE6A9EFB3032A077A23FEB39C064D0E2C30700D11CE`;
  current unsigned Release SYS SHA-256
  `00A9E8689114886C04B6C45E86603BE1257B42E6215B76CE41D3A721F28C5F6A`;
  current unsigned 1,262-byte CAT SHA-256
  `84CF148F8E04F41F3691B99B058BCDDE810B9EC99EB8DA4EF38DA53E11712B87`.
  Installed Inf2Cat file/product versions `1.0.0519.24` /
  `1.0.0519.24+3dc05997` and SHA-256
  `B594728D38B271979367ABC8060A971B8E42422738009BE126710B1F5DD0FCBC`
  match retained evidence.
- **Retained result:** Inf2Cat used
  `10_CO_X64,10_NI_X64,10_GE_X64`, exited `0`, and reported no warnings or
  errors. `10_25H2_X64` was not advertised or passed. The catalog contains the
  INF and SYS members, SHA-256 member digests, x64 Windows 11 21H2/22H2/24H2
  attributes, exact hardware ID `usb\vid_045e&pid_028e`, and no signer,
  certificate, CRL, or recipient.
- **Files created:** `docs/OFFLINE-INF2CAT-PACKAGE-VALIDATION.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`,
  `docs/PORTING-PLAN.md`, `docs/WIN11-BLOCKERS.md`,
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`, and this worklog.
- **Documentation boundaries:** The report distinguishes InfVerif static INF
  validity from Inf2Cat offline package/catalog closure and distinguishes both
  from signing trust, staging, installation, effective lower-filter placement,
  controller preservation, and Chatpad/runtime behavior.
- **Validation:** Introduced relative links resolve to the intended tracked
  report; required semantic statements PASS; repository safety PASS with exit
  `0`; `git diff --check` exit `0`. No repository documentation-link checker
  exists, so local relative-link resolution was used without installing a
  dependency.
- **Validation corrections:** The first link check rejected the new report
  because it required the pre-stage file to already be tracked; the corrected
  check accepts that one intended new Markdown path. A semantic assertion then
  failed to span a Markdown line break even though the lower-filter disclaimer
  was present; the corrected assertion matched the explicit text. These were
  check-pattern failures, not documentation-content failures.
- **Commit and push:** Commit exactly
  `docs: record offline inf2cat validation` and push only
  `origin/feature/offline-inf2cat-package-validation` with upstream setup. The
  final commit hash is reported after commit and push rather than embedded
  here.
- **Remaining blockers:** The package and CAT remain unsigned and untrusted.
  Signing trust, staging, Windows acceptance, attachment beneath `xusb22`,
  controller preservation, transport visibility, Chatpad activation/input,
  keyboard output, and runtime lifecycle remain unproven and unauthorized.
- **Safety:** No Inf2Cat, InfVerif, build, protocol/driver test, signing,
  certificate, staging, installation, Driver Store, service, registry, device,
  controller, hardware, or operating-system action occurred. Retained evidence
  stayed ignored and unmodified; only tracked Markdown documentation changed.

## 2026-06-30T07:48+04:00 - Package-checkpoint documentation corrections

- **Objective:** Correct the independent review findings in the offline
  Inf2Cat documentation, add a durable sanitized review record, validate the
  documentation-only scope, commit, and push the current feature branch.
- **Starting branch and commit:**
  `feature/offline-inf2cat-package-validation` /
  `946f6feeb920e096663f757725ddb51ddd18a84d`; upstream
  `origin/feature/offline-inf2cat-package-validation` at the same commit;
  tracked tree and index clean.
- **Reviewed result:** The independent verdict is **REVIEW PASS WITH
  FINDINGS**. Package identities, catalog structure, documentation facts,
  links, ignored-output containment, and Git synchronization passed. The
  findings concerned recovery sequencing and continuity, not the unsigned
  offline package result.
- **Recovery corrections:** Source-package identity now precedes staging;
  Windows-assigned `oem#.inf` capture and exact source correlation follow only
  a separately authorized staging-only operation. Target matching,
  attachment/restart/load, passive observation, and active USB/Chatpad
  interaction are separate gates, and authorization never carries forward.
  The validated `ChatpadFilterExtension.cat` declaration is recorded as an
  unsigned and untrusted completed offline package-closure result.
- **Roadmap and continuity corrections:** Phase 4 is split into independent
  package, trust, staging, identity/matching, load, observation, hardware, and
  release stages. `PROJECT-STATE.md` records `946f6fe...` as the reviewed
  baseline without a self-referential correction hash. `NEXT-TASK.md` records
  machine-local evidence behavior and separates future signing/recovery design
  from continued offline KMDF work; neither path is authorized.
- **Historical evidence correction:** The final
  `20260629T214908Z` InfVerif `/k /l` invocation exited `0`. Its retained
  `infverif-annotated.txt` contains only encoding/newline bytes and therefore
  no substantive text output; the final timestamped `annotated/` directory
  contains no generated HTML file. The earlier prototype worklog statement
  that final evidence contained annotated HTML was inaccurate. INF validation
  remains PASS. No historical artifact was invented or reconstructed to fill
  the gap.
- **File created:** `docs/OFFLINE-INF2CAT-CHECKPOINT-REVIEW.md`.
- **Files modified:** `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`,
  `docs/PORTING-PLAN.md`, `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`,
  `docs/OFFLINE-INF2CAT-PACKAGE-VALIDATION.md`, and this worklog.
- **Validation:** Complete diff reviewed; `git diff --check` exit `0`;
  changed-document contradiction searches found no active conflicting claim;
  all modified repository-relative Markdown links resolved with exact tracked
  path case (the new review file was the single intended pre-stage path);
  all 16 final semantic requirements passed after whitespace-normalized
  checking;
  repository safety exit `0`, `REPOSITORY SAFETY: PASS`.
- **Validation correction:** The first changed-path policy expression retained
  the tracked and untracked path lists as two nested arrays, so it printed the
  seven correct paths but falsely reported one unexpected value and exited
  `1`. The corrected flat, unique path-list check passed with seven changed
  files, zero unexpected paths, and zero non-Markdown paths. This was a
  check-expression error, not a repository-scope failure.
- **Semantic-check correction:** A later semantic pass initially reported four
  false failures because those regular expressions did not span Markdown line
  breaks. Normalizing whitespace before matching produced 16/16 PASS,
  including signing/staging authorization, Windows-acceptance, and runtime
  `xusb22` proof boundaries. This was also a check-pattern error, not a
  documentation-content failure.
- **Commit and push:** Commit exactly
  `docs: tighten recovery authorization gates` and push normally only to
  `origin/feature/offline-inf2cat-package-validation`. The final commit hash is
  reported after commit and push rather than embedded here.
- **Remaining blockers:** Signing and trust, staging, Windows acceptance,
  published-package identity, target matching, effective lower-filter
  placement, `xusb22` preservation, controller and Chatpad behavior, and a
  usable production driver remain unproven and unauthorized.
- **Safety:** No Inf2Cat, InfVerif, build, protocol/driver test, signing,
  certificate, package regeneration, staging, installation, Driver Store,
  service, registry, driver load, operating-system mutation, device query,
  controller/Chatpad interaction, elevation, or network action before the
  final authorized Git push occurred. No other network action is authorized.
  Retained evidence stayed ignored and unmodified; only authorized tracked
  Markdown changed.

## 2026-06-30T08:09+04:00 - Offline driver activation-plan integration

- **Objective:** Compile the authoritative six-step activation model, pure
  control-setup translation, and WDF setup formatter into one dormant
  production-driver preparation layer without creating requests, changing
  runtime callbacks, loading the driver, or accessing hardware.
- **Starting branch and commit:**
  `feature/offline-inf2cat-package-validation` /
  `fad671d5d1ede2eda6f0a5defb0b0495c80cc39e`; upstream synchronized; tracked
  tree and index clean. Created
  `feature/offline-driver-activation-plan-integration` only after the exact
  preflight passed.
- **Architecture investigation:** The authoritative graph was
  `ChatpadActivationSequence` -> `ChatpadActivationRequests` ->
  `ChatpadControlSetup` -> `ChatpadWdfControlSetupFormatter`. Portable
  libraries use v143, while existing kernel checks already compile the same
  sources with the WDK. The narrow integration therefore compiles the exact
  authoritative `.c` files directly into `ChatpadFilter`; no constant,
  payload, table, or implementation was copied.
- **Production implementation:** Added
  `ChatpadActivationPreparation.h/.c` with
  `ChatpadPrepareActivationStep`. Output contains only the caller-owned WDF
  setup value, direction/length/payload metadata, sequence/request identity,
  and delay metadata. Typed results distinguish null output, invalid index,
  model, translation, formatter, capacity, and consistency failures. Every
  non-null failure output is fully cleared.
- **Dormancy and linkage:** The project has no new project reference and does
  not link user-mode libraries or `ChatpadTransport`. It compiles the exact
  authoritative sources under KMDF 1.15 and uses
  `/INCLUDE:ChatpadPrepareActivationStep` to retain the API. `driver.c`,
  `device.c`, and `driver.h` have no diff and no call to the API.
- **Compile validation:** The existing WDF compile check now compiles the
  production module and exact shared sources. Its compile-only paths cover all
  six steps, authoritative metadata comparison, deterministic repetition,
  null output, boundary and large indexes, and successful output followed by
  clearing failure. All authoritative steps are valid, so translator/formatter
  failure cannot be induced without fabricating an invalid model; typed
  fail-closed mappings remain in production, but no constant was modified and
  no fake WDF runtime or target was introduced.
- **Six-step result:** Exact setup fixtures remain
  `40 a9 0c a3 23 44 00 00`,
  `40 a9 44 23 03 7f 00 00`,
  `40 a9 39 58 32 68 00 00`,
  `c0 a1 00 00 16 e4 02 00`,
  `40 a1 00 00 16 e4 02 00`, and
  `c0 a1 00 00 16 e4 02 00`. Model-supplied `09 00` remains the only confirmed
  outbound payload; `90 00` remains absent. Before/after delay metadata remains
  `0/12 ms` for every step and is never executed.
- **Validation results:** Full solution Debug/Release exit `0`; canonical
  driver Debug/Release exit `0`; protocol `610/610` each; transport `186/186`
  each; lifecycle `109/109` each; pure control setup `141/141` each; direct
  protocol regression `610/610`; kernel compatibility Debug/Release PASS; WDF
  formatter/integration Debug/Release PASS; repository safety before and after
  PASS.
- **Validation failures and corrections:** The first full-solution build
  succeeded but emitted driver outputs and intermediates into ignored
  repository/source `x64` paths. An initial project-property fix corrected
  output location but was evaluated too early for the intermediates; the
  containment rerun therefore failed again. Moving both properties to
  post-import configuration groups fixed evaluation. The verified generated
  directories were removed, solution Debug/Release reran successfully with
  all outputs beneath `artifacts/`, and protocol containment reran PASS. These
  were output-containment failures, not compiler or assertion failures.
- **Driver artifacts:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `83C7D82BD77FA6F05690F0F4F610CF246042160D9E4A10D9032C44221B0A4AD6`,
  `Authenticode.NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `22D7A1DF6F051DBFB1AB835A08354391CDEDA7BC88F27BC6EB7CAACBD4A90139`,
  `Authenticode.NotSigned`.
- **Files created:** production preparation header/source and
  `docs/OFFLINE-DRIVER-ACTIVATION-PLAN-INTEGRATION.md`.
- **Files modified:** driver project/README; WDF compile-check source, project,
  and README; build/lifecycle/WDF wrappers; directly contradictory build,
  architecture, bridge, roadmap, decision, current-state, next-task, and
  worklog documentation.
- **Commit and push:** Commit exactly
  `driver: integrate offline activation plan` and push with upstream only to
  `origin/feature/offline-driver-activation-plan-integration`. The final commit
  hash is reported after commit and push rather than embedded here.
- **Remaining blockers:** No request/target/memory owner, live formatting,
  submission, completion, cancellation, executable timing, default-control
  visibility, activation proof, input path, installation, signing, loading, or
  hardware behavior exists. No usable driver exists.
- **Safety:** No WDF object was created and no request was formatted against a
  target or submitted. No signing, certificate, package, staging,
  installation, Driver Store, registry, service, driver load, Windows
  mutation, PnP/device query, USB/controller/Chatpad interaction, elevation, or
  network action before the final authorized Git push occurred. Generated
  outputs and logs remained ignored.

## 2026-06-30T09:07+04:00 - KMDF request-owner and buffer-lifetime design

- **Objective:** Define the authoritative ownership, stable transfer-memory,
  state, send/completion/cancellation race, lifecycle, cleanup, and sequencing
  rules for the first future asynchronous activation control request without
  adding production or runtime behavior.
- **Starting branch and commit:**
  `feature/offline-driver-activation-plan-integration` /
  `b814822a540f84b93b1a02809fd1bdb0a61ac02d`; upstream
  `origin/feature/offline-driver-activation-plan-integration` at the same
  commit; tracked tree and index clean. Created
  `feature/offline-kmdf-request-owner-design` only after the exact branch,
  HEAD, upstream, local/remote equality, and clean-diff gate passed.
- **Investigation:** Inspected the complete `ChatpadFilter` project inputs,
  dormant activation preparation, authoritative six-step request/sequence
  model, pure setup/WDF formatter, transport adapter, lifecycle scaffold,
  device context and PnP/power callbacks, stale/duplicate/cancel/generation/
  outstanding test models, bridge and transport architecture, and installed
  KMDF 1.15 `wdfrequest.h`, `wdfmemory.h`, `wdfusb.h`, and `wdfobject.h`.
  The asynchronous USB formatter accepts `WDFMEMORY`; the inspected
  `WDF_MEMORY_DESCRIPTOR` forms belong to the synchronous control-transfer
  boundary and were not selected.
- **Binding design:** Selected one reusable, device-parented activation
  `WDFREQUEST` with typed context and separate request-parented two-byte
  outbound/inbound `WDFMEMORY` children. Outbound capacity is the existing
  maximum payload constant; inbound capacity is the exact maximum expected by
  the six authoritative steps and requires a future semantic guard. The
  state machine publishes send/cancel call pins before outside-lock framework
  calls, handles completion before call return, gives completion terminal
  ownership after successful send, and maps one lifecycle acquire to one
  release obligation.
- **Files created:**
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`.
- **Files modified:** `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`,
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`, `docs/DECISIONS.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/PORTING-PLAN.md`, and
  this worklog. No other file was changed.
- **Documentation validation:** All 19 required sections are present. Semantic
  guards for ownership hierarchy, selected request/buffer strategies, state
  transition table, send-return race, cancellation, generation integration,
  failure/recovery matrix, implementation decomposition, continuous-input
  separation, stack-lifetime prohibition, and design-only boundary passed.
  Every new or modified relative Markdown link resolved to the exact intended
  tracked path (with the one intended new document admitted before staging).
  Contradiction searches found no active implementation claim; matches were
  limited to negative or explicitly future conceptual state descriptions.
  `git diff --check` exited `0`.
- **Repository safety:** `tools\Test-RepositorySafety.ps1` exited `0` with
  `REPOSITORY SAFETY: PASS`. It created no evidence file. No build, protocol,
  transport, lifecycle, setup, kernel compile, InfVerif, Inf2Cat, driver, or
  hardware test was run, as required by the documentation-only scope.
- **Artifacts:** None generated. Existing ignored artifacts were not modified
  or staged.
- **Commit and push:** Commit exactly
  `docs: define kmdf request ownership` and push only
  `origin/feature/offline-kmdf-request-owner-design` with upstream setup. The
  final commit hash is reported after commit and push rather than embedded in
  this entry.
- **Next recommended slice:** A separately authorized pure, WDF-independent
  request-owner state model and exhaustive offline race/accounting tests. No
  WDF type/object or production driver integration belongs in that slice.
- **Remaining blockers:** No request-owner model code, request context, WDF
  object, target, transfer memory, formatting, submission, completion,
  cancellation, executable delay, D0-exit deferral mechanism, default-control
  visibility, activation proof, continuous input, signing, loading,
  installation, or hardware behavior exists or is authorized.
- **Safety:** No source/header/project/solution/INF/script/test file was
  modified. No WDF object/callback was created; no request was reused,
  formatted, sent, or cancelled. No build, signing, certificate, packaging,
  staging, installation, Driver Store, registry, service, driver load,
  operating-system mutation, PnP/device query, USB/controller/Chatpad access,
  elevation, or network action before the final authorized Git push occurred.

## 2026-06-30T10:05+04:00 - Offline request-owner state model

- **Objective:** Implement the pure, WDF-independent request-owner state model
  for the future activation request slot, with exhaustive offline race and
  exact-once lifecycle-accounting tests. Do not create WDF objects, change
  runtime callbacks, submit/cancel/complete requests, package, sign, install,
  access devices, or begin any Inf2Cat task.
- **Starting branch and commit:**
  `feature/offline-kmdf-request-owner-design` /
  `8444c0199144a6ccb24e8463a1778befe05736ec`; parent
  `b814822a540f84b93b1a02809fd1bdb0a61ac02d`; upstream
  `origin/feature/offline-kmdf-request-owner-design` at the same commit;
  status clean. Created `feature/offline-request-owner-state-model` only after
  the branch, HEAD, parent, upstream, remote equality, and clean-diff gates
  passed.
- **Investigation:** Re-read the required repository instructions and current
  docs, then inspected the request-owner design, existing lifecycle core,
  transport adapter token shape, driver preparation seam, tests, projects,
  solution, and wrappers. The new model deliberately consumes the transport
  token value shape but does not call lifecycle, transport, WDF, WDM, USB, HID,
  PnP, SetupAPI, or driver APIs.
- **Implementation:** Added `ChatpadRequestOwnerModel`, a caller-owned pure C
  state machine with 14 states and 19 events. The dispatcher clears caller
  effects before validation, rejects invalid transitions without state/effect
  mutation, classifies faulting transitions, binds one lifecycle generation and
  one `ChatpadTransportOperationToken`, and emits effects for admission,
  release, preparation, formatting, send/cancel call boundaries, terminal
  retirement, sequence advance/abort, reuse, stale completion, and diagnostic
  fault recording.
- **Race/accounting details:** The model publishes send-call and cancel-call
  pins before future outside-model framework calls; completion can retire an
  accepted send before send return and then waits for call-return pins before
  reuse. False send return retires through the initiator and aborts the
  sequence. Completion owns terminal retirement after accepted send.
  Cancellation alone never releases lifecycle admission. Duplicate completion,
  duplicate cancellation, stale completion, generation mismatch, operation
  mismatch, preparation failure, formatting failure, draining, and faulted
  ownership are explicitly modeled. One acquired lifecycle obligation can emit
  exactly one release effect.
- **Tests:** Added `ChatpadRequestOwnerModelTests`, which enumerates every
  event symbol, classifies every 14-state by 19-event combination, verifies
  rejected-transition atomicity and effect clearing, covers 30 targeted
  scenarios, and performs bounded deterministic exploration to depth 10. The
  dual send/cancel-pin completion race is test-injected by constructing an
  otherwise valid awaiting-call-return snapshot with both call pins set; no
  WDF or framework call is made.
- **Wrapper:** Added `tools\Test-ChatpadRequestOwnerModel.ps1`. Its semantic
  guard rejects WDF/WDM/kernel/USB/HID/PnP/SetupAPI symbols and headers,
  dynamic allocation, handle/thread/sleep/event/device I/O surfaces,
  file-scope mutable state, missing dispatcher effect clearing, missing
  rejected-transition tests, unconfirmed `90 00` payload text, missing state or
  event coverage, project references in the model project, and any
  `ChatpadFilter` reference to `ChatpadRequestOwner`.
- **Files created:**
  `docs/OFFLINE-REQUEST-OWNER-STATE-MODEL.md`;
  `src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.h`;
  `src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.c`;
  `src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.vcxproj`;
  `src/transport/ChatpadRequestOwnerModel/README.md`;
  `tests/transport/ChatpadRequestOwnerModelTests/ChatpadRequestOwnerModelTests.c`;
  `tests/transport/ChatpadRequestOwnerModelTests/ChatpadRequestOwnerModelTests.vcxproj`;
  `tests/transport/ChatpadRequestOwnerModelTests/README.md`;
  `tools/Test-ChatpadRequestOwnerModel.ps1`.
- **Files modified:** `ChatpadWin11.sln`; `docs/BUILDING.md`;
  `docs/DECISIONS.md`; `docs/NEXT-TASK.md`; `docs/PORTING-PLAN.md`;
  `docs/PROJECT-STATE.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`; `src/README.md`;
  `tests/README.md`; this worklog.
- **Request-owner validation:** `.\tools\Test-ChatpadRequestOwnerModel.ps1
  -Configuration Debug -Platform x64` and Release both exited `0`.
  Semantic guard PASS; environment detector exit `0`; MSBuild exit `0`; test
  executable exit `0`; transition states `14`; event classes `19`;
  combinations `266`; accepted `41`; idempotent `12`; rejected `206`;
  faulting `7`; scenarios `30`; exploration depth `10`; attempts `1273`;
  unique snapshots `74`; assertions `5002/5002`; failures `0`; output
  containment PASS. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-build-Debug-20260630T055851Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-test-Debug-20260630T055851Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-build-Release-20260630T055852Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-test-Release-20260630T055852Z.log`.
- **Request-owner wrapper artifacts:** Debug wrapper output
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.lib`
  SHA-256 `1D436BCC95F1761AD3C000FC0B59396251312CD4D70B548CB39D98A564F7CC22`
  and
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadRequestOwnerModelTests\ChatpadRequestOwnerModelTests.exe`
  SHA-256 `4BDA955E0188330180DDFE42E6B3EC4C1FFB38C6AA3ECE800FAF3B303C9FCA2E`.
  Release wrapper output
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadRequestOwnerModel\ChatpadRequestOwnerModel.lib`
  SHA-256 `ECA12E77BFF970883C247A136AE049F0994EF0F76AD266EC6C6C6895F3A1221F`
  and
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadRequestOwnerModelTests\ChatpadRequestOwnerModelTests.exe`
  SHA-256 `7A791080B2F06DA5746022C6D14F8227716D1007BCD76B6D5AB156684CC485B7`.
  Later full-solution clean builds regenerated these ignored artifacts; the
  wrapper logs remain the evidence for the wrapper-run hashes.
- **Regression validation:** `.\tools\Test-ChatpadProtocol.ps1
  -Configuration Debug -Platform x64` and Release both exited `0` with
  `610/610` assertions and failure `0`; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-integrated-build-Debug-20260630T055904Z.log`,
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-integrated-test-Debug-20260630T055904Z.log`,
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-integrated-build-Release-20260630T055906Z.log`,
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-integrated-test-Release-20260630T055906Z.log`.
  `.\tools\Test-ChatpadTransport.ps1` Debug/Release exited `0` with
  `186/186`; logs `chatpad-transport-*-20260630T055908Z.log` and
  `chatpad-transport-*-20260630T055909Z.log`. `.\tools\Test-ChatpadFilterLifecycle.ps1`
  Debug/Release exited `0` with `109/109`; logs
  `chatpad-filter-lifecycle-*-20260630T055910Z.log` and
  `chatpad-filter-lifecycle-*-20260630T055911Z.log`.
  `.\tools\Test-ChatpadControlSetup.ps1` Debug/Release exited `0` with
  `141/141`; logs `chatpad-control-setup-*-20260630T055912Z.log` and
  `chatpad-control-setup-*-20260630T055913Z.log`.
- **Kernel/driver validation:** `.\tools\Test-ChatpadProtocolKernelCompatibility.ps1`
  Debug/Release exited `0`; MSBuild exit `0`; signing execution scan PASS;
  prohibited output scan PASS; artifact containment PASS; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-kernel-compatibility-Debug-20260630T055933Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-kernel-compatibility-Release-20260630T055934Z.log`.
  `.\tools\Test-ChatpadWdfControlSetup.ps1` Debug/Release exited `0`; source,
  formatter, compile-check, integration, dormancy, and authoritative API guards
  PASS; MSBuild exit `0`; signing execution scan PASS; prohibited output scan
  PASS; artifact containment PASS; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-wdf-control-setup-Debug-20260630T055935Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-wdf-control-setup-Release-20260630T055937Z.log`.
  `.\tools\Build-Driver.ps1` Debug/Release exited `0`; signing execution scan
  PASS; repository safety PASS inside the wrapper; Inf2Cat and DrvCat were
  skipped because there were no INF/catalog inputs; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-debug-x64-20260630T055938Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-release-x64-20260630T055940Z.log`.
- **Driver artifacts after final full-solution build:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `4392A1084D0E2B7263CA399A9B5038FF22F4F98C9F4EEF8E6F996E5561E78F59`,
  `Authenticode.NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `64A8363655B520B57F8C23F684717285B3E00D05864E7EBF4B15423440AB929F`,
  `Authenticode.NotSigned`.
- **Full solution validation:** The first full-solution attempt used generic
  BuildTools MSBuild and failed with `MSB8020` because that installation lacked
  `WindowsKernelModeDriver10.0`; this was a tool-selection failure. The
  corrected WDK-capable Community MSBuild path was
  `C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe`.
  Fresh final Debug and Release full-solution builds exited `0` with
  `Build succeeded`, `0 Warning(s)`, and `0 Error(s)`. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-request-owner-final-Debug-20260630T055957Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-request-owner-final-Release-20260630T055959Z.log`.
- **Direct and safety validation:** `.\tools\Test-ChatpadProtocolParser.ps1`
  exited `0` with `610/610` assertions and failure `0`; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-parser-build-20260630T060000Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-parser-test-20260630T060000Z.log`.
  `.\tools\Test-RepositorySafety.ps1` exited `0` with `REPOSITORY SAFETY:
  PASS`. `git diff --check` exited `0`.
- **Commit and push:** Commit exactly `model: add request owner state machine`
  and push only `origin/feature/offline-request-owner-state-model` with
  upstream setup. The final commit hash is reported after commit and push
  rather than embedded here.
- **Remaining blockers:** No KMDF request context definition, WDF object,
  transfer memory, target, live formatting, send, completion callback,
  cancellation callback, executable timing, D0-exit rundown mechanism,
  default-control visibility, activation proof, continuous input, signing,
  loading, installation, or hardware behavior exists or is authorized. No
  usable production driver exists.
- **Safety:** No WDF/WDM/USB/HID/PnP runtime dependency was added to the pure
  model. No DriverEntry, KMDF callback, request formatting/submission,
  completion/cancellation callback, device/system action, INF/CAT/catalog,
  certificate, package, signing, staging, installation, Driver Store, registry,
  service, driver load, PnP/device query, USB/controller/Chatpad access,
  elevation, or network operation before the final authorized Git push
  occurred. Generated outputs and logs remained ignored beneath `artifacts/`.

## 2026-06-30 - Compile-only KMDF request-owner context definitions

- **Task title and objective:** Implement the compile-only KMDF request-owner
  context-definition checkpoint. Define WDK/KMDF-visible owner and request
  context storage for the future activation reusable request without linking it
  into `ChatpadFilter` runtime behavior.
- **Starting branch and commit:** Started from
  `feature/offline-request-owner-state-model` at
  `7f5ff4264d3171a1067a3eb0090f48b9979fe609`, parent
  `8444c0199144a6ccb24e8463a1778befe05736ec`, subject
  `model: add request owner state machine`. The local branch, remote
  `origin/feature/offline-request-owner-state-model`, and upstream all matched
  `7f5ff4264d3171a1067a3eb0090f48b9979fe609`; `git diff --exit-code` and
  `git diff --cached --exit-code` both exited `0`.
- **Working branch:** Created
  `feature/offline-kmdf-request-owner-context` from the verified starting
  commit.
- **Investigation summary:** Reviewed the request-owner buffer-lifetime design,
  pure request-owner state model, activation preparation/builders, existing
  transport token type, WDF control-setup formatter pattern, WDK KMDF 1.15
  context/object-attribute declarations, and current `ChatpadFilter` project
  boundaries. No unresolved placement ambiguity remained for this checkpoint:
  the future device-owned owner embeds the pure model, the future reusable
  request receives a typed request context, and transfer bytes stay in fixed
  owner storage.
- **Files created:**
  `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj`;
  `src/driver/ChatpadKmdfRequestOwnerContext/README.md`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.c`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.vcxproj`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/README.md`;
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`.
- **Files modified:** `ChatpadWin11.sln`; `docs/BUILDING.md`;
  `docs/DECISIONS.md`; `docs/NEXT-TASK.md`; `docs/PORTING-PLAN.md`;
  `docs/PROJECT-STATE.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`; `src/README.md`;
  `src/transport/ChatpadRequestOwnerModel/ChatpadRequestOwnerModel.h`;
  `tests/README.md`; this worklog.
- **Implementation details:** Added isolated static-library project
  `ChatpadKmdfRequestOwnerContext` and compile-check project
  `ChatpadKmdfRequestOwnerContextCompileCheck`. The owner type stores
  signature/version, initialization mask, embedded
  `ChatpadActivationRequestOwner`, future `WDFREQUEST`, outbound/inbound
  `WDFMEMORY`, future `WDFSPINLOCK`, exact two-byte outbound and inbound
  transfer arrays, and a bounded completion snapshot. The request context is
  declared with `WDF_DECLARE_CONTEXT_TYPE_WITH_NAME` and stores owner pointer,
  immutable `ChatpadTransportOperationToken`, lifecycle generation, activation
  step, direction, transfer lengths, active transfer memory, copied
  `WDF_USB_CONTROL_SETUP_PACKET`, and completion snapshot. The only functions
  initialize ordinary `WDF_OBJECT_ATTRIBUTES` structures. No WDF object
  creation, request formatting, send, cancel, completion, callback, runtime
  linkage, or driver behavior was added.
- **Pure-model portability correction:** Added a narrow kernel-mode MSVC
  fallback for `UINT32_MAX` in `ChatpadRequestOwnerModel.h`, because compiling
  `ChatpadRequestOwnerModel.c` through the WDK compile-check path exposed that
  the kernel include chain did not provide `UINT32_MAX`.
- **Intermediate failures corrected:** The first context Debug wrapper failed
  because `wdfusb.h` was included before required USB/USBD prerequisites; the
  context header now includes `usb.h` and `usbdlib.h` before `wdfusb.h`. The
  next Debug wrapper failed on missing `UINT32_MAX`; the WDK fallback above
  fixed it. A later wrapper review found the active-driver source scan used a
  brittle PowerShell `-Include` form; it was tightened to enumerate files and
  filter `.c`/`.h` extensions explicitly before final validation.
- **New semantic guard:** `tools\Test-ChatpadKmdfRequestOwnerContext.ps1`
  verifies no prohibited WDF/WDM runtime creation/format/send/cancel/completion
  calls, no allocation/device-query/wait/IOCTL/HID/USB runtime surfaces, no
  `90 00` payload, no global mutable owner, no flexible arrays, authoritative
  pure-model and token reuse, exact two-byte capacity invariants, no activation
  sequence/setup duplication, typed request context/object-attribute usage,
  no `ChatpadFilter` include/reference/link/retention, and artifact containment.
  Final Debug and Release semantic guards printed PASS.
- **Context validation:** `.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1
  -Configuration Debug -Platform x64` exited `0`; semantic guard PASS;
  environment detector exit `0`; MSBuild exit `0`; signing execution scan PASS;
  prohibited output scan PASS; artifact containment PASS. Log:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T062311Z.log`.
  Wrapper-run context library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256 `439159749F5E04B48A187CF916EA962BD83BFE3F831E6D675DEA08C1F9902E32`.
  Wrapper-run compile-check library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContextCompileCheck\ChatpadKmdfRequestOwnerContextCompileCheck.lib`,
  SHA-256 `22062A0FD3E2F1BE75A4324FCC4E528F43341C15A1281111B20C333B884BFBCA`.
- **Context validation, Release:** `.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1
  -Configuration Release -Platform x64` exited `0`; semantic guard PASS;
  environment detector exit `0`; MSBuild exit `0`; signing execution scan PASS;
  prohibited output scan PASS; artifact containment PASS. Log:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T062312Z.log`.
  Wrapper-run context library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256 `A7B81AE8FDD3127A99915A29496698E948C0BDD562BC5829A79989E23FCB6888`.
  Wrapper-run compile-check library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContextCompileCheck\ChatpadKmdfRequestOwnerContextCompileCheck.lib`,
  SHA-256 `8AFBD956CE1FA67AEC1BFC9920F798705BDF428AA055942CDAB3FCC7882E1361`.
- **Request-owner model regression:** `.\tools\Test-ChatpadRequestOwnerModel.ps1`
  Debug and Release both exited `0`. Semantic guard PASS; environment detector
  exit `0`; MSBuild exit `0`; test executable exit `0`; transition states
  `14`; event classes `19`; combinations `266`; accepted `41`; idempotent
  `12`; rejected `206`; faulting `7`; scenarios `30`; exploration depth `10`;
  attempts `1273`; unique snapshots `74`; assertions `5002/5002`; failures
  `0`; output containment PASS. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-build-Debug-20260630T062313Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-test-Debug-20260630T062313Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-build-Release-20260630T062314Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-request-owner-model-test-Release-20260630T062314Z.log`.
- **Existing offline regression validation:** `.\tools\Test-ChatpadProtocol.ps1`
  Debug/Release exited `0` with `610/610` assertions and failure `0`; logs
  `chatpad-protocol-integrated-*-20260630T062316Z.log` and
  `chatpad-protocol-integrated-*-20260630T062317Z.log`.
  `.\tools\Test-ChatpadTransport.ps1` Debug/Release exited `0` with
  `186/186`; logs `chatpad-transport-*-20260630T062319Z.log` and
  `chatpad-transport-*-20260630T062320Z.log`.
  `.\tools\Test-ChatpadFilterLifecycle.ps1` Debug/Release exited `0` with
  `109/109`; logs `chatpad-filter-lifecycle-*-20260630T062321Z.log` and
  `chatpad-filter-lifecycle-*-20260630T062322Z.log`.
  `.\tools\Test-ChatpadControlSetup.ps1` Debug/Release exited `0` with
  `141/141`; logs `chatpad-control-setup-*-20260630T062323Z.log` and
  `chatpad-control-setup-*-20260630T062324Z.log`.
- **Kernel/driver validation:** `.\tools\Test-ChatpadProtocolKernelCompatibility.ps1`
  Debug/Release exited `0`; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-kernel-compatibility-Debug-20260630T062325Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-kernel-compatibility-Release-20260630T062326Z.log`.
  `.\tools\Test-ChatpadWdfControlSetup.ps1` Debug/Release exited `0`; source,
  formatter, compile-check, integration, dormancy, and authoritative API guards
  PASS; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-wdf-control-setup-Debug-20260630T062327Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-wdf-control-setup-Release-20260630T062328Z.log`.
  `.\tools\Build-Driver.ps1` Debug/Release exited `0`; signing execution scan
  PASS; repository safety PASS inside the wrapper; Inf2Cat and DrvCat were
  skipped because there were no INF/catalog inputs; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-debug-x64-20260630T062329Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-release-x64-20260630T062331Z.log`.
- **Full solution validation:** WDK-capable MSBuild
  `C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe`
  built `ChatpadWin11.sln` Debug and Release with `/m /restore`. Both exited
  `0` and logs contain `Build succeeded.`, `0 Warning(s)`, and `0 Error(s)`.
  Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-request-owner-context-final-Debug-20260630T062333Z.log`;
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-request-owner-context-final-Release-20260630T062335Z.log`.
- **Direct parser validation:** `.\tools\Test-ChatpadProtocolParser.ps1`
  exited `0` with `610/610` assertions and failure `0`; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-parser-build-20260630T062359Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-protocol-parser-test-20260630T062359Z.log`.
- **Driver artifacts after final full-solution build:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `973D8DE52B72C56E238CEB3A4A32485AD0747A4E35585B1315F1904DAFD491EA`,
  `Authenticode.NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `BEA5CECD1F6B601AEA2E89A535E3A54234B3295372523D60EF8FE031DCD378F6`,
  `Authenticode.NotSigned`.
- **Final rebuilt context artifacts after full-solution build:** Debug context
  library SHA-256
  `BB8331A553232BEA7445334E3800462A56077D09561009C9BAC1D6D8FA66E696`;
  Debug compile-check library SHA-256
  `F5088A5CEE37B6BDFFF86F4CC36EB34BED3B75F4A8C0D69B8DAA00135AD88BAD`;
  Release context library SHA-256
  `2B0435F7FEF43DC441E50C30F567D6E8AEC4D3AC1193836E2E8CED2D45DD4ADB`;
  Release compile-check library SHA-256
  `3726748DBE9E8842EBD20A2C0E9BFF611160D6F76A7CF315AFA0EA4F55BAD5DB`.
- **Runtime-linkage proof:** A source/project scan of
  `src\driver\ChatpadFilter\*.c`, `src\driver\ChatpadFilter\*.h`, and
  `src\driver\ChatpadFilter\ChatpadFilter.vcxproj` for
  `ChatpadKmdfRequestOwnerContext`,
  `ChatpadKmdfActivationRequestOwner`,
  `ChatpadKmdfGetActivationRequestContext`, and `ChatpadKmdf` returned count
  `0`. `ChatpadWin11.sln` includes only the isolated context library project
  and the compile-check project.
- **Direct safety validation:** `.\tools\Test-RepositorySafety.ps1` exited `0`
  with `REPOSITORY SAFETY: PASS`. `git diff --check` exited `0`.
- **Commit and push:** Commit exactly
  `driver: define compile-only request contexts` and push only
  `origin/feature/offline-kmdf-request-owner-context` with upstream setup.
  The final commit hash is reported after commit and push rather than embedded
  here.
- **Remaining blockers:** WDF request creation, memory creation, lock creation,
  target discovery, request formatting, request reuse/send/cancel/completion,
  completion/cancellation callbacks, D0-exit rundown, cleanup integration,
  executable timing, default-control visibility, lower-filter placement proof,
  controller preservation, activation effectiveness, continuous input, signing,
  trust, staging, installation, loading, and hardware behavior remain
  unimplemented and unauthorized. No usable production driver exists.
- **Safety:** No DriverEntry/runtime callback change, no ChatpadFilter runtime
  linkage, no WDF object creation, no request formatting/submission, no request
  reuse/cancel/completion, no timer/queue/work-item/device/USB object creation,
  no InfVerif, no Inf2Cat execution, no CAT/catalog creation, no certificate,
  no package, no signing, no staging, no install, no Driver Store/registry/
  service mutation, no driver load, no PnP/device/USB/controller/Chatpad query
  or access, no elevation, and no network operation before the final authorized
  Git push occurred. Generated outputs and logs remained ignored beneath
  `artifacts/`.

## 2026-06-30 - Design-only dormant KMDF object creation and cleanup

- **Task title and objective:** Create the design-only dormant KMDF
  object-creation and cleanup checkpoint for the activation request owner.
  Define future parentage, creation order, rollback, cleanup, callback, IRQL,
  scenario, and stop-condition rules without source implementation.
- **Starting branch and commit:** Verified
  `feature/offline-kmdf-request-owner-context` at
  `1be4637aa91fa675bc9b45caddd41e40279c1252`, parent
  `7f5ff4264d3171a1067a3eb0090f48b9979fe609`, subject
  `driver: define compile-only request contexts`. Upstream was
  `origin/feature/offline-kmdf-request-owner-context` at the same commit.
  `git status --short --untracked-files=all` was empty;
  `git diff --exit-code` and `git diff --cached --exit-code` both exited `0`.
- **Working branch:** Created
  `feature/offline-kmdf-request-object-lifecycle-design` from the verified
  starting commit.
- **Investigation summary:** Inspected the compile-only context module, pure
  request-owner model, current `ChatpadFilter` device context and callbacks,
  current project dormancy/linkage boundaries, request-owner buffer-lifetime
  design, activation-preparation structures, and installed KMDF 1.15 headers.
  The current driver context contains only signature, version, diagnostic
  sequence, and lifecycle state; it contains no activation request owner. The
  current callbacks are `EvtDeviceAdd`, prepare-hardware, release-hardware,
  D0-entry, and D0-exit. No activation cleanup, destroy, completion,
  cancellation, target, queue, timer, work item, request, memory, or spinlock
  code exists.
- **Installed WDK evidence:** KMDF 1.15 headers show `WdfDeviceCreate` is
  annotated for `PASSIVE_LEVEL`; `WdfRequestCreate`,
  `WdfMemoryCreatePreallocated`, `WdfSpinLockCreate`, `WdfObjectDelete`, and
  `WdfRequestReuse` are annotated for maximum `DISPATCH_LEVEL`;
  `WDF_OBJECT_ATTRIBUTES` contains cleanup callback, destroy callback,
  execution level, synchronization scope, optional `ParentObject`, and context
  type fields; cleanup and destroy callbacks are annotated for maximum
  `DISPATCH_LEVEL`; `WdfRequestCreate` accepts an optional `WDFIOTARGET`.
- **Files created:** `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`.
- **Files modified:** `docs/DECISIONS.md`; `docs/NEXT-TASK.md`;
  `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
  `docs/PORTING-PLAN.md`; `docs/PROJECT-STATE.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`; this worklog.
- **Design details:** Selected future dormant creation immediately after
  successful `WdfDeviceCreate` in `EvtDeviceAdd`. The exact future graph is
  ordinary owner storage in the future device context, device-parented
  `WDFSPINLOCK`, device-parented reusable `WDFREQUEST`, typed request context,
  and request-parented outbound/inbound preallocated `WDFMEMORY` descriptors
  over fixed two-byte owner arrays. The request is created without an initial
  target; target discovery and formatting remain separate future gates.
- **Rollback and cleanup decisions:** Initialization failure uses explicit
  reverse-order rollback: delete the request first so request-parented memory
  children are removed through parentage, then delete the spinlock, clear
  ordinary handle fields, keep owner-ready unset, and fail `EvtDeviceAdd`.
  Normal teardown relies on framework parent hierarchy deletion only after a
  separately designed operation rundown/cancellation path has proven no active
  operation or callback can use the owner. No cleanup or destroy callback is
  selected for the dormant lock, request, or memory objects.
- **Documentation validation:** `git diff --check` exited `0`. The new design
  document contains all 22 required numbered sections and the required object
  graph, selected creation location, exact creation order, parentage table,
  initialization-state model, partial-failure matrix, rollback decision,
  cleanup callback decision, IRQL analysis, success invariants, scenario
  matrix, implementation decomposition, binding decisions, and stop
  conditions.
- **Link validation:** The first ad hoc Markdown link-validation command failed
  because it normalized backslashes incorrectly and treated the new untracked
  Markdown file as unavailable before staging. The corrected validation included
  intended new Markdown files, resolved every relative Markdown link from its
  containing file, and passed for 9 changed Markdown files.
- **Contradiction scan:** Searches for `request created`, `memory created`,
  `lock created`, `request submitted`, `completion active`, `target acquired`,
  `controller verified`, and `installation authorized` found only contextual
  future/failure-scenario or negated invariant text, not current-state claims.
- **Repository safety:** `.\tools\Test-RepositorySafety.ps1` exited `0` with
  `REPOSITORY SAFETY: PASS`.
- **Scope validation:** Changed files were Markdown only. No source, header,
  project, solution, script, test, INF, SYS, CAT, certificate, key, package,
  binary, generated log, or `artifacts/` file was staged or modified. No build,
  source test, driver test, InfVerif, Inf2Cat, hardware query, device query,
  signing, staging, installation, driver load, registry/service/Driver Store
  mutation, or operating-system mutation was performed.
- **Commit and push:** Commit exactly
  `docs: define kmdf object lifecycle` and push only
  `origin/feature/offline-kmdf-request-object-lifecycle-design` with upstream
  setup. The final commit hash is reported after commit and push rather than
  embedded here.
- **Remaining blockers:** No WDF activation-owner object currently exists.
  Future owner-structure helper, dormant WDF object creation, rollback helper,
  target discovery, request formatting, submission, completion, cancellation,
  D0 rundown, signing, staging, installation, loading, and hardware validation
  all remain separate authorization gates.

## 2026-06-30 11:34 +04:00 - KMDF owner storage initialization checkpoint

- **Task title and objective:** Implement the ordinary KMDF request-owner
  storage initialization and pre-object validation helper without WDF object
  creation, production-driver linkage, host fake-WDF execution, installation,
  signing, packaging, InfVerif, Inf2Cat, or hardware/system action.
- **Starting branch and commit:** Verified
  `feature/offline-kmdf-request-object-lifecycle-design` at
  `91f645b983140b38c2985c67ea51020934bee515`, parent
  `1be4637aa91fa675bc9b45caddd41e40279c1252`, upstream
  `origin/feature/offline-kmdf-request-object-lifecycle-design` at the same
  commit, with clean worktree/index.
- **Working branch:** Created
  `feature/offline-kmdf-owner-storage-init` from the verified starting commit.
- **Investigation summary:** Re-read the repository protocol documents and
  inspected the context module, pure request-owner model, compile-check target,
  semantic wrapper, and active `ChatpadFilter` project/source boundaries. The
  exact production helper can be compiled under WDK, but host execution without
  a fake WDF layer is not a safe validation target because the owner type
  contains opaque WDF handle types. Validation therefore uses WDK compile-checks
  plus semantic guards.
- **Files created:**
  `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`.
- **Files modified:** `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.c`;
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`;
  `src/driver/ChatpadKmdfRequestOwnerContext/README.md`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/README.md`;
  `docs/PROJECT-STATE.md`; `docs/NEXT-TASK.md`; `docs/DECISIONS.md`;
  `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/PORTING-PLAN.md`; this worklog.
- **Implementation details:** Added
  `ChatpadKmdfRequestOwnerStorageResult`,
  `ChatpadKmdfRequestOwnerStorageValidationFlag`, and
  `ChatpadKmdfRequestOwnerStorageValidation`. Added
  `ChatpadKmdfRequestOwnerInitializeStorage` to clear ordinary owner storage,
  set context signature/version, leave `Request`, `OutboundMemory`,
  `InboundMemory`, and `BookkeepingLock` null, clear fixed transfer storage
  and completion snapshot storage, initialize the embedded pure
  `ChatpadActivationRequestOwner` model, and publish only
  `CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`.
  Added `ChatpadKmdfRequestOwnerValidatePreObjectState` to clear validation
  output and validate signature/version, model-ready-only mask, no
  owner-ready bit, null framework handles, zero transfer storage, zero
  completion snapshot, pure-model invariant success, no active
  operation/lifecycle, and unavailable baseline snapshot using authoritative
  invalid generation, operation-sequence, and step constants.
- **Semantic guard details:** Extended
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1` to forbid
  `WdfDeviceCreate`, WDF object creation/deletion/reference calls, request
  reuse/format/send/cancel/completion registration, target start/stop,
  `IoCallDriver`, dynamic allocation, wait/delay, install/device-query, USB,
  HID, IOCTL, and unconfirmed payload surfaces in the context code. The guard
  also proves the helper APIs exist, reuse the pure model initializer,
  invariant validator, and snapshot, expose typed error results, explicitly
  null all future WDF handles, explicitly clear transfer/completion storage,
  never assign `OWNER_READY`, and only assign initialization-mask states
  `NONE`, `MODEL_READY`, and `FAULTED`.
- **Important failed attempts:** The first Debug context compile-check failed
  with MSBuild exit code `1` because a runtime `if` compared compile-time
  `sizeof` constants and triggered `warning C4127` under `/WX`; log:
  `artifacts/logs/chatpad-kmdf-request-owner-context-Debug-20260630T072801Z.log`.
  The fix removed the constant conditional and relies on existing `C_ASSERT`
  capacity proofs. A parallel `Build-Driver.ps1` Debug/Release run caused the
  Debug process to fail before build because both processes attempted to write
  `artifacts/environment/driver-build-environment.txt`; Release completed, and
  Debug was rerun by itself successfully.
- **Validation commands and results:**
  - `.\tools\Test-RepositorySafety.ps1` exited `0` before implementation and
    after final changes with `REPOSITORY SAFETY: PASS`.
  - `.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1 -Configuration Debug -Platform x64`
    exited `0`; semantic guard PASS; log
    `artifacts/logs/chatpad-kmdf-request-owner-context-Debug-20260630T072816Z.log`.
  - `.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1 -Configuration Release -Platform x64`
    exited `0`; semantic guard PASS; log
    `artifacts/logs/chatpad-kmdf-request-owner-context-Release-20260630T072816Z.log`.
  - `.\tools\Test-ChatpadRequestOwnerModel.ps1` Debug and Release exited `0`;
    each reported `5002` assertions passed and `0` failed.
  - `.\tools\Test-ChatpadProtocol.ps1` Debug and Release exited `0`.
  - `.\tools\Test-ChatpadTransport.ps1` Debug and Release exited `0`.
  - `.\tools\Test-ChatpadControlSetup.ps1` Debug and Release exited `0`; each
    reported `141` assertions passed and `0` failed.
  - `.\tools\Test-ChatpadFilterLifecycle.ps1` Debug and Release exited `0`;
    each reported `109` assertions passed and `0` failed.
  - `.\tools\Test-ChatpadProtocolKernelCompatibility.ps1` Debug and Release
    exited `0` with signing/prohibited-output/artifact-containment PASS.
  - `.\tools\Test-ChatpadWdfControlSetup.ps1` Debug and Release exited `0`
    with signing/prohibited-output/artifact-containment PASS.
  - `.\tools\Build-Driver.ps1 -Configuration Release -Platform x64` exited
    `0`; log `artifacts/logs/build-release-x64-20260630T073348Z.log`;
    driver SHA-256
    `e3b830f05563925bac38201ace79f1b4955b792abdf5588ed09c7a15e0a52a66`;
    Authenticode `NotSigned`.
  - `.\tools\Build-Driver.ps1 -Configuration Debug -Platform x64` exited `0`;
    log `artifacts/logs/build-debug-x64-20260630T073356Z.log`; driver
    SHA-256 `473fe1b1b46166cb902250d4ee7a739cafcdde1c9ded28323c0f59d34b887a48`;
    Authenticode `NotSigned`.
  - Full solution `ChatpadWin11.sln` Debug and Release MSBuild invocations
    exited `0`; logs
    `artifacts/logs/full-solution-debug-x64-20260630T073416Z.log` and
    `artifacts/logs/full-solution-release-x64-20260630T073417Z.log`.
  - `git diff --check` exited `0`.
- **Generated artifact locations:** Build outputs and logs were generated only
  beneath ignored `artifacts/`, including `artifacts/bin/x64/...`,
  `artifacts/obj/x64/...`, `artifacts/logs/...`, and
  `artifacts/environment/driver-build-environment.txt`.
- **Scope validation:** `ChatpadFilter` runtime source, project linkage,
  `DriverEntry`, active KMDF callbacks, live device context, INF/CAT/signing
  scripts, package/install/recovery paths, and `legacy/` were not modified.
  No WDF object was created; no request was formatted, sent, cancelled, reused,
  completed, or deleted; no target was discovered; no InfVerif or Inf2Cat was
  run; no catalog, certificate, package, installer, installation, registry,
  service, Driver Store, device, USB, or hardware action occurred.
- **Commit and push:** Commit exactly
  `driver: initialize dormant request owner` and push only
  `origin/feature/offline-kmdf-owner-storage-init`. The final commit hash is
  reported after commit and push rather than embedded here.
- **Remaining blockers:** WDF spinlock/request/memory creation, object
  parentage helpers, rollback helpers, production-driver linkage, target
  discovery, request formatting, submission, completion, cancellation, D0
  rundown, signing, staging, installation, loading, and hardware validation
  remain separate authorization gates.

## 2026-06-30 12:35 +04:00 - KMDF object-attribute preparation checkpoint

- **Task title and objective:** Implement only compile-only
  `WDF_OBJECT_ATTRIBUTES` preparation for the future dormant activation-owner
  bookkeeping lock, reusable request, outbound memory, and inbound memory,
  without creating a WDF object or changing production-driver behavior.
- **Starting branch and commit:** Verified
  `feature/offline-kmdf-owner-storage-init` at
  `eee073e093ca10545ff6638044763653d5148487`, parent
  `91f645b983140b38c2985c67ea51020934bee515`, with
  `origin/feature/offline-kmdf-owner-storage-init` at the same commit and a
  clean worktree/index.
- **Previous checkpoint verification:** Before editing,
  `.\tools\Test-RepositorySafety.ps1` passed and
  `.\tools\Test-ChatpadKmdfRequestOwnerContext.ps1 -Configuration Debug
  -Platform x64` passed its semantic guard and WDK compile-check.
- **Working branch:** Created `feature/offline-kmdf-object-attributes` from the
  verified starting commit.
- **Investigation summary:** Re-read the repository protocol and continuation
  documents, inspected the ordinary storage helper, existing generic attribute
  initializers, compile-check source, semantic wrapper, dormant object graph,
  and installed KMDF 1.15 `WDF_OBJECT_ATTRIBUTES` definition. The old generic
  initializers attached request context or initialized plain attributes but
  did not encode or validate the selected parent object.
- **Files created:** `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`.
- **Files modified:** `docs/DECISIONS.md`; `docs/NEXT-TASK.md`;
  `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`;
  `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
  `docs/PORTING-PLAN.md`; `docs/PROJECT-STATE.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`;
  `src/driver/ChatpadKmdfRequestOwnerContext/README.md`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.c`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/README.md`;
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`; this worklog.
- **Implementation details:** Replaced the two generic attribute initializers
  with four exact typed APIs:
  `ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes`,
  `ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes`,
  `ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes`, and
  `ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes`. Added
  `ChatpadKmdfRequestOwnerAttributeResult` for null output, null device parent,
  and null request parent failures. Lock/request attributes set
  `ParentObject` to the caller's `WDFDEVICE`; both memory APIs use one internal
  plain-memory builder that sets `ParentObject` to the caller's `WDFREQUEST`.
  Only request attributes use
  `WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE` with
  `ChatpadKmdfActivationRequestContext`. All helpers leave execution level
  inherited, explicitly set `WdfSynchronizationScopeNone`, and register no
  cleanup or destroy callback.
- **Semantic guard details:** The context wrapper now requires all four public
  APIs and typed failures, exactly two device-parent assignments, exactly one
  shared request-parent assignment, exactly three explicit no-automatic-
  synchronization assignments, typed request context only through the request
  initializer, no execution-level override, no cleanup/destroy callback
  assignment, and compile-check invocation of every exact helper. Existing
  object-creation, formatting, submission, cancellation, target, installation,
  and runtime-linkage prohibitions remain active.
- **Important failed validation harness attempts:** The first combined
  regression harness invocation failed before running a test because an
  argument array was passed positionally and supplied `-Configuration` as the
  configuration value. The same checks were rerun with explicit named
  parameters and passed. A later combined audit used the reserved PowerShell
  variable `$Error` for an MSBuild-summary match, so that portion emitted
  `Cannot overwrite variable Error`; the summary check was rerun with
  `$errorSummary` and proved both logs had zero warnings and zero errors.
- **Context validation:** Final Debug and Release
  `Test-ChatpadKmdfRequestOwnerContext.ps1` runs exited `0`; semantic,
  signing-execution, prohibited-output, artifact-containment, and compile
  guards passed. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T083441Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T083443Z.log`.
  Final Debug context/compile-check library SHA-256 values were
  `6F15AF77AC79C553E5FF7647C4B532D281551E5C551A237C3471A4D2A9E6DE8B`
  and
  `8F352D2AD9D2AED185C4D3A1949A1426EDB9EC59AE4AC1F7707132E4431B18D6`;
  Release values were
  `E99958BB49DD4BF8B1D02E2BBF5973C1D3AA7AB7F493BBFB5845D194567E98B9`
  and
  `011AAD7089063AA9124295CE7DC458DA52827A7D777EBAC8C680EA9E24ACDC94`.
- **Offline regression validation:** Debug and Release runs all exited `0`:
  request-owner model `5002/5002`; integrated protocol `610/610`; transport
  `186/186`; control setup `141/141`; filter lifecycle `109/109`; protocol
  kernel compatibility; and WDF control-setup compile-check. Their build/test
  logs are under
  `C:\Dev\chatpad-super-driver\artifacts\logs\` with timestamps
  `20260630T083351Z` through `20260630T083407Z`.
- **Driver and solution validation:** Sequential Debug and Release
  `Build-Driver.ps1` runs exited `0`; logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-debug-x64-20260630T083413Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-release-x64-20260630T083416Z.log`.
  Direct full-solution Debug and Release builds exited `0` with zero warnings
  and zero errors; logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-object-attributes-Debug-20260630T083429Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-object-attributes-Release-20260630T083431Z.log`.
  Final full-solution driver artifacts were Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `3251631E3DEB5A6A944B99686E79067F416D3C2E14C6708E6CF97072AFCD2267`,
  `Authenticode.NotSigned`; and Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `74A88F7DEAEE609A9B0824576F27A5403DE59100B6F2325340F9E266C8CC2F8F`,
  `Authenticode.NotSigned`.
- **Final static validation:** Changed-Markdown link validation passed for 14
  files; `.\tools\Test-RepositorySafety.ps1` exited `0` with
  `REPOSITORY SAFETY: PASS`; the prohibited WDF/WDM call scan returned no
  matches; and `git diff --check` exited `0`.
- **Generated artifact locations:** All generated libraries, executables,
  driver binaries, environment reports, and logs remained ignored beneath
  `C:\Dev\chatpad-super-driver\artifacts\`.
- **Scope and safety:** `ChatpadFilter`, `DriverEntry`, active callbacks, the
  live device context, INF/CAT/package/signing/install paths, and `legacy/`
  were not modified. No WDF object was created, referenced, deleted, formatted,
  sent, reused, cancelled, or completed. No target was discovered. No InfVerif
  or Inf2Cat executable was invoked; MSBuild reported its Inf2Cat and DrvCat
  tasks skipped because no INF/catalog inputs existed. No catalog,
  certificate, signature, package, staging, installation, registry, service,
  Driver Store, device, USB, controller, hardware, elevation, or network
  action occurred before the final authorized push.
- **Commit and push:** Commit exactly
  `driver: prepare dormant object attributes` and push only
  `origin/feature/offline-kmdf-object-attributes`. The final commit hash is
  reported after commit and push rather than embedded here.
- **Remaining blockers:** Dormant spinlock/request/memory creation, typed
  request-context runtime initialization, partial-failure rollback,
  production-driver linkage, target discovery, formatting, submission,
  completion, cancellation, D0 rundown, signing, staging, installation,
  loading, and hardware validation remain separate authorization gates.

## 2026-06-30 13:19 +04:00 - Dormant KMDF lock/request creation checkpoint

- **Task title and objective:** Implement isolated, dormant KMDF creation
  helpers for one future device-parented bookkeeping spinlock and one future
  device-parented reusable targetless activation request. Compile the exact
  WDF calls and deterministic typed request-context initialization without
  executing either helper, creating any object, adding memory/rollback, or
  changing `ChatpadFilter`.
- **Starting-state verification:** Confirmed
  `feature/offline-kmdf-object-attributes` at
  `8b5a5b8b376568c063d521e76693a4067cc579a2`, parent
  `eee073e093ca10545ff6638044763653d5148487`, subject
  `driver: prepare dormant object attributes`, upstream
  `origin/feature/offline-kmdf-object-attributes` at the same commit, and clean
  tracked worktree/index. `git diff --exit-code` and
  `git diff --cached --exit-code` both exited `0`.
- **Working branch:** Created
  `feature/offline-kmdf-lock-request-creation` from the exact verified start.
- **Documentation filename clarification:** The task text referenced
  `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTES-PREPARATION.md`, which does not exist.
  The repository's existing authoritative file, linked consistently by all
  continuation documents, is
  `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`; that singular filename
  was inspected and updated without introducing a duplicate alias.
- **Architecture and WDK investigation:** Inspected the object-lifecycle,
  buffer-lifetime, context, storage, and attribute checkpoints; initialization
  masks; pure-model invalid identity values; current compile-check projects;
  `ChatpadFilter` source/project inputs; and installed KMDF 1.15 headers.
  `WdfSpinLockCreate` and `WdfRequestCreate` are both annotated for maximum
  `DISPATCH_LEVEL`. The installed `WdfRequestCreate` declaration marks its
  `WDFIOTARGET` argument `_In_opt_`, confirming `WDF_NO_HANDLE` is valid for
  targetless creation. Both isolated projects are static libraries, so
  compiling the calls does not link or execute a driver.
- **Files created:** `docs/OFFLINE-KMDF-LOCK-REQUEST-CREATION.md`.
- **Files modified:** `docs/DECISIONS.md`; `docs/NEXT-TASK.md`;
  `docs/OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md`;
  `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`;
  `docs/OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md`;
  `docs/PORTING-PLAN.md`; `docs/PROJECT-STATE.md`;
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`;
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`;
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`;
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`;
  `src/driver/ChatpadKmdfRequestOwnerContext/README.md`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.c`;
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/README.md`;
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`; this worklog.
- **Creation APIs:** Added
  `ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock` and
  `ChatpadKmdfRequestOwnerCreateReusableRequest`, both returning
  `ChatpadKmdfRequestOwnerCreationResult` and separately preserving exact WDF
  `NTSTATUS`. A non-null framework-status output is initialized to the stable
  local sentinel `STATUS_INVALID_DEVICE_STATE` before validation.
- **Spinlock helper behavior:** Validates owner identity, known mask, exact
  ordinary pre-object baseline, null handles, zero fixed storage, and
  unavailable/non-admitting pure model. It rejects repeated lock creation or a
  pre-existing request before the WDF call, reuses the device-parented
  attributes helper, calls `WdfSpinLockCreate` once, publishes the handle
  before OR-ing only `LOCK_CREATED`, and validates the lock-created state.
- **Request helper behavior:** Requires the valid lock-created partial state,
  rejects missing/repeated request state before the WDF call, reuses the typed
  device-parented request attributes, and calls
  `WdfRequestCreate(&attributes, WDF_NO_HANDLE, &request)` exactly once. After
  hypothetical success it retrieves the typed context, clears it, assigns the
  owner and authoritative invalid identities/inactive defaults, publishes the
  handle before OR-ing only `REQUEST_CREATED`, and validates the
  lock/request-created state.
- **Partial-state validation:** Added
  `ChatpadKmdfRequestOwnerValidateCreationState` for exact pre-object,
  lock-created, and lock/request-created states. It verifies pure-model
  invariants/snapshot, no operation/lifecycle obligation, zero owner transfer
  and completion storage, absent memory state, absent ready/fault/draining
  state, exact handles, and exact dormant request context. Fully ready is
  explicitly invalid and unreachable.
- **Failure/repeated-call boundary:** WDF failure leaves local handles
  unpublished and created bits absent while preserving the exact framework
  failure status. The helpers do not call one another, retry, delete,
  dereference, roll back, create memory, publish owner-ready, discover a
  target, or operate a request. A hypothetical post-creation invariant failure
  retains the handle/bit for a future separately authorized orchestrator to
  roll back.
- **Compile-check and semantic guards:** The compile-check takes typed
  addresses of both creation APIs and the partial validator but never calls
  them. The PowerShell 5.1-compatible guard requires exactly
  `WdfSpinLockCreate=1` and `WdfRequestCreate=1`, no other direct `Wdf*` call,
  exact helper independence/parentage, `WDF_NO_HANDLE`, generated typed-context
  access, deterministic inactive context fields, complete typed result/state
  surfaces, only lock/request bit publication, and no memory/deletion/
  request-execution/runtime-driver linkage. Exact project counts remain one
  production context C source and three compile-check C inputs; creation-helper
  invocation count is zero.
- **Defensive postcondition correction:** Complete-diff review found that a
  hypothetical WDF success paired with a null returned handle could otherwise
  reach the context accessor or publish a created bit. Explicit non-null
  handle postconditions were added before any accessor, handle publication, or
  bit publication. The affected Debug/Release context and full-solution builds
  were rerun successfully.
- **Inspection command failures:** An initial bare `dumpbin` command failed
  because `dumpbin.exe` was not on `PATH`; the exact VS 2022 x64 path was
  located and symbol inspection then succeeded. A separate read attempted the
  nonexistent `src/transport/ChatpadTransport/ChatpadTransport.h`; `rg` located
  the authoritative constants in `ChatpadTransportAdapter.h`. A final audit
  invocation supplied a nonexistent `-SkipBuild` parameter to
  `Test-ChatpadKmdfRequestOwnerContext.ps1`; PowerShell rejected the parameter
  before the script ran, after which the supported Debug and Release
  invocations both passed. None of these failed inspection or invocation
  attempts changed tracked repository or system state.
- **Final context validation:** Debug and Release
  `Test-ChatpadKmdfRequestOwnerContext.ps1` runs exited `0`. Each semantic
  guard reported the exact authorized call counts `1` and `1`; signing,
  prohibited-output, artifact-containment, and compile checks passed. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T092442Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T092443Z.log`.
  Debug context/compile-check SHA-256:
  `1A5883D30FCDF93D41182A5B09A13B2EA73A1E56024DDC1C86D216BC6D40AB92`
  and
  `C0C6D9F3745BB5FF58B3B36D77FBA27C022FA9089B8035BCF6DE2DCB79FA4FA2`.
  Release values:
  `12697F6C4D0D1610664357234DFA3DD34E803A46E1B7809C1561B24FB92833B5`
  and
  `CD19C22DD462A80A84FEB1FC96B4E349E00C86717EEC06F070BCE9E602B22E65`.
- **Regression validation:** Serial Debug and Release runs all exited `0`:
  request-owner model `5002/5002`; integrated protocol `610/610`; transport
  `186/186`; lifecycle `109/109`; control setup `141/141`; protocol kernel
  compatibility; and WDF control setup. Logs are beneath
  `C:\Dev\chatpad-super-driver\artifacts\logs\` with timestamps
  `20260630T091529Z` through `20260630T091545Z`.
- **Driver and full-solution validation:** Sequential Debug/Release
  `Build-Driver.ps1` runs exited `0`; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-debug-x64-20260630T091551Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\build-release-x64-20260630T091554Z.log`.
  Full-solution Debug/Release builds exited `0` with zero warnings and zero
  errors; logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-lock-request-creation-final-Debug-20260630T092141Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-lock-request-creation-final-Release-20260630T092142Z.log`.
- **Driver artifacts:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `54D039D1A99872BF3C0466B192A57A6738917080326D3001A19A934B4C937870`,
  `Authenticode.NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `4E33D23642B3CE26179C96305B1AEF291F64A1BB0BA74526FFCC455E5E95B852`,
  `Authenticode.NotSigned`. Import inspection found zero
  `WdfSpinLockCreate`, `WdfRequestCreate`, or isolated-helper matches in both
  driver images.
- **Symbol inspection:** The isolated Debug library contained public helper
  and validator symbols plus `WdfSpinLockCreate`, `WdfRequestCreate`, and the
  typed-context worker. Release optimization retained the public helper and
  validator symbols while inlining the framework wrappers. This is consistent
  with compile-only static libraries and does not execute a creation call.
- **Generated artifact containment:** All build outputs, logs, libraries,
  executables, driver images, and environment reports remained ignored beneath
  `C:\Dev\chatpad-super-driver\artifacts\`.
- **Safety:** Creation calls were compiled but never executed; no WDF object
  was created during this checkpoint. No `ChatpadFilter` source/project/device
  context or active callback was changed. No memory creation, deletion,
  rollback, target discovery, request formatting/reuse/send/completion/
  cancellation, InfVerif, Inf2Cat executable invocation, CAT, certificate,
  signing, packaging, staging, installation, driver load, Driver Store,
  registry, service, device enumeration, controller/Chatpad interaction,
  elevation, Windows mutation, or network operation occurred before the final
  authorized push.
- **Commit and push:** Commit exactly
  `driver: define dormant lock request creation` and push only
  `origin/feature/offline-kmdf-lock-request-creation`. The final commit hash is
  reported after commit and push rather than embedded here.
- **Remaining blockers:** Actual creation execution, request-parented
  outbound/inbound memory creation, rollback/deletion orchestration,
  production linkage, target discovery, request execution/completion/
  cancellation, D0 rundown, signing, installation, loading, and hardware
  validation remain separately gated.

## 2026-06-30 13:47 +04:00 - Dormant KMDF preallocated-memory creation checkpoint

- **Objective:** Compile two isolated, independent request-parented
  preallocated-memory creation helpers over the activation owner's exact
  outbound/inbound two-byte arrays without executing a framework call,
  implementing rollback, publishing owner-ready, or changing `ChatpadFilter`.
- **Starting gate:** Verified branch
  `feature/offline-kmdf-lock-request-creation`, HEAD
  `9bd3a8e0ce6a94a5d6c7f6d45d2ca651d50ea497`, parent
  `8b5a5b8b376568c063d521e76693a4067cc579a2`, matching upstream
  `origin/feature/offline-kmdf-lock-request-creation`, and clean worktree/index.
  Created `feature/offline-kmdf-memory-creation` only after every gate passed.
- **Architecture/WDK inspection:** Confirmed KMDF 1.15 declares
  `WdfMemoryCreatePreallocated` with optional attributes, caller-owned nonzero
  buffer/size, `WDFMEMORY` output, and maximum `DISPATCH_LEVEL`. Existing
  request-parented attribute helpers and device-owner arrays satisfy the
  contract. Both context projects remain static libraries and `ChatpadFilter`
  has no context-module link/reference.
- **Implementation:** Added
  `ChatpadKmdfRequestOwnerCreateOutboundMemory` and
  `ChatpadKmdfRequestOwnerCreateInboundMemory`. Each validates the exact
  predecessor state, retrieves the existing inactive request context, prepares
  attributes with `owner->Request`, calls
  `WdfMemoryCreatePreallocated` once over its exact array and `sizeof` value,
  publishes the handle, ORs only its own created bit, and validates the new
  partial state. Outbound must precede inbound.
- **Authority and failure behavior:** Owner memory fields remain authoritative;
  no duplicate context handles were added. Local rejection sets
  `STATUS_INVALID_DEVICE_STATE`; framework failures preserve exact `NTSTATUS`
  and publish no new handle/bit. Inbound failure preserves outbound state.
  Neither helper changes array/model/context contents, calls another creation
  helper, retries, deletes, dereferences, rolls back, or sets owner-ready.
- **Validation model:** `ChatpadKmdfRequestOwnerValidateCreationState` now
  accepts exact model-only, lock, lock/request, outbound-memory, and
  both-memory states while requiring inactive context, zero dormant storage,
  non-admitting pure model, and no lifecycle obligation. Fully ready remains
  invalid.
- **Compile-check/guard:** Compile-check takes typed addresses of both new
  helpers without invocation. The semantic guard passes with exact counts
  `WdfSpinLockCreate=1`, `WdfRequestCreate=1`, and
  `WdfMemoryCreatePreallocated=2`, exact request parentage/array sizes, helper
  independence, and no deletion, rollback, request execution, or driver
  linkage.
- **Failed proving command:** The first Debug compile at
  `20260630T094052Z` failed with warning-as-error `C4127` because direct
  fixed-capacity comparisons were constant expressions. The checks were moved
  into a parameterized ordinary capacity validator, preserving typed capacity
  rejection. The same Debug command and Release command then passed.
- **Final context evidence:** Debug log
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T094922Z.log`;
  Release log
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T094924Z.log`.
  Final full-solution context/compile-check library hashes were Debug
  `F8496928976EDCFB0D1E7E3363BCEA60332337B766E0392BE128F55ECBB267C0` /
  `CBD2256E7C2F4194CD1ED7172F42D48C7798F1674DFADCD21D2A941DFDD78F53`
  and Release
  `3D2BB19C0A3D832BE2A602D53D6CD5EFFF7A3D908857E8959649EFC86C7E83B6` /
  `9C11FA5E3F3B00E106681C49B30FA0E1DE46F9DF7AED2C4C686FE24C6B911319`.
- **Regression results:** Serial Debug/Release wrappers all exited `0`:
  request-owner `5002/5002`, protocol `610/610`, transport `186/186`,
  lifecycle `109/109`, control setup `141/141`, protocol kernel compatibility,
  WDF control setup, and `Build-Driver.ps1`. Logs span
  `20260630T094201Z` through `20260630T094220Z` beneath `artifacts\logs`.
- **Full solution:** Debug/Release exited `0` with zero warnings/errors. Logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-preallocated-memory-final-Debug-20260630T094933Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-preallocated-memory-final-Release-20260630T094935Z.log`.
- **Driver evidence:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `AC5EB131736F97DE573F297EB450C9D449665E13A6BF3A622401FD433C521DF3`,
  `NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `871B616DD761B7C678391249A54DC908A153651B91A9011ABA47E70D37B45613`,
  `NotSigned`. Import inspection found zero memory-creation/helper matches.
- **Safety/containment:** Memory-creation calls were compiled but never
  executed; no WDF memory object was created. No rollback, target, request
  operation, production linkage, InfVerif/Inf2Cat executable invocation,
  signing, package/driver staging, installation, loading, registry/service/
  Driver Store mutation, device enumeration, controller/Chatpad interaction,
  elevation, or network operation occurred. MSBuild only reported Inf2Cat and
  DrvCat skipped because no inputs existed. Generated outputs remain ignored
  beneath `artifacts\`.
- **Commit/push:** Commit exactly `driver: define dormant memory creation` and
  push only `origin/feature/offline-kmdf-memory-creation`; final hash is
  reported after commit rather than embedded here.
- **Next gate:** Independently authorized reverse-order rollback orchestration
  for partial creation failure. It is not implemented or authorized here.

## 2026-06-30 14:04 +04:00 - Dormant KMDF partial-creation rollback checkpoint

- **Objective/start:** Implement compile-only reverse-order rollback for valid
  pre-ready request-owner creation states. Verified exact start branch
  `feature/offline-kmdf-memory-creation`, HEAD
  `142f8e11bebac78cf2e10367c96d3b409d9c8db7`, parent
  `9bd3a8e0ce6a94a5d6c7f6d45d2ca651d50ea497`, matching upstream and clean
  worktree/index; then created `feature/offline-kmdf-creation-rollback`.
- **Investigation:** Inspected the complete object graph/rollback design, all
  four creation helpers, mask/handle states, pure-model baseline and active
  markers, request context, compile target, driver dormancy, and installed
  KMDF 1.15 `WdfObjectDelete`. The API returns `VOID`, accepts `WDFOBJECT`, and
  is valid through `DISPATCH_LEVEL`; no contract conflict exists.
- **Implementation:** Added typed rollback state/result/effects surfaces,
  non-mutating `ChatpadKmdfRequestOwnerClassifyRollbackState`, and
  `ChatpadKmdfRequestOwnerRollbackPartialCreation`. Classification rejects
  ready/draining/active/invalid/inconsistent states without dereferencing WDF
  handles. Effects clear before validation and contain no handle.
- **Deletion/publication order:** Snapshot request/spinlock; initiate request
  deletion once; clear request and memory handles/bits; initiate spinlock
  deletion once; clear lock handle/bit; publish exact `MODEL_READY | FAULTED`.
  Memory children are owned by request deletion and are never individually
  deleted. No request/context access occurs after deletion begins.
- **Post-state/idempotence:** Arrays, completion storage, and pure model remain
  unchanged in the unavailable/non-admitting baseline. Clean `MODEL_READY` and
  rolled-back `MODEL_READY | FAULTED` return `ALREADY_CLEAN` without a WDF
  call. Inconsistent states receive no best-effort deletion.
- **Compile-check/guard:** Address-only compile checks cover classifier and
  rollback APIs. Final semantic counts are `WdfSpinLockCreate=1`,
  `WdfRequestCreate=1`, `WdfMemoryCreatePreallocated=2`, and
  `WdfObjectDelete=2`; guards enforce request-before-spinlock deletion, no
  individual memory delete, deterministic clearing, no creation call from
  rollback, and no driver linkage.
- **Failed guard run:** The first Debug wrapper stopped before compilation
  because the prior global bit-publication allowlist rejected rollback's
  authorized `FAULTED` bit. The allowlist was narrowed to include only that
  existing diagnostic bit in addition to creation bits; the repeated Debug and
  Release runs passed.
- **Context/full solution evidence:** Context logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T100041Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T100050Z.log`.
  Full solution logs
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-creation-rollback-Debug-20260630T100146Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-creation-rollback-Release-20260630T100150Z.log`
  contain zero warnings/errors. Final context/compile-check hashes are Debug
  `F4471A0130677D9537F2CA21AC7D16BC2A8ADA3C6C22B91DDD7D9DDC9E90D55E` /
  `0A3756E170C8959D38ABC38E7AE88C3CB13C215DE2214D7F35A1079057027CB8`
  and Release
  `3ACBAAF95B32A33B4E853696216D2CC1B9A947D4A55799B5D2CD31DC435918BF` /
  `E6AAFA8714A58E729A664CDC95C054A747B0E403917DA3B5729EBAEC60A2DC46`.
- **Regressions:** Serial Debug/Release request-owner `5002/5002`, protocol
  `610/610`, transport `186/186`, lifecycle `109/109`, control setup
  `141/141`, kernel compatibility, WDF control setup, and driver builds all
  passed. Logs span `20260630T100115Z` through `20260630T100134Z`.
- **Driver evidence:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `88C7C43120D5C36BDE379CC1B463A9BDDEFD46A5BC1992456B6F9CF7CAC2452A`,
  `NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `A75A7CEAB6536E422019B4020B3CF5D47419FECC429321B25445F98F4C45650A`,
  `NotSigned`. Both contain zero rollback/`WdfObjectDelete` import matches.
- **Safety:** Rollback deletion calls were compiled but never executed; no WDF
  object was deleted. No creation helper, production linkage, normal teardown,
  target/request operation, InfVerif/Inf2Cat executable, signing, package/driver
  staging, installation, loading, Windows/device/controller action, elevation,
  or network operation occurred. Generated outputs remain ignored beneath
  `artifacts/`.
- **Commit/push:** Commit exactly `driver: define dormant creation rollback`
  and push only `origin/feature/offline-kmdf-creation-rollback`; final hash is
  reported after commit.
- **Next gate:** Full dormant creation orchestration with rollback and final
  non-runtime `OWNER_READY` publication; not authorized here.

## 2026-06-30 16:09 +04:00 - Dormant KMDF creation orchestration checkpoint

- **Objective/start:** Implement the isolated, dormant all-or-nothing KMDF
  activation request-owner object-graph orchestration helper. Verified exact
  start branch `feature/offline-kmdf-creation-rollback`, HEAD
  `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`, parent
  `142f8e11bebac78cf2e10367c96d3b409d9c8db7`, subject
  `driver: define dormant creation rollback`, matching upstream
  `origin/feature/offline-kmdf-creation-rollback`, clean worktree/index, and
  no tracked/cached diff. Created
  `feature/offline-kmdf-creation-orchestration` only after the gate passed.
- **Investigation:** Inspected the request-owner context APIs, ordinary storage
  initialization, pre-object validation, all four one-object creation helpers,
  creation-state validation, rollback classification/effects, `OWNER_READY` and
  `FAULTED` masks, pure request-owner model invariants, compile-check target,
  semantic guard, and `ChatpadFilter` dormancy. The proposed call graph is
  orchestration -> baseline validation -> spinlock -> request -> outbound
  memory -> inbound memory -> pre-ready validation -> `OWNER_READY` publication
  -> final ready validation, with centralized rollback on failure.
- **Implementation:** Added
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`, orchestration stage/result
  enums, and deterministic report structure. The helper clears the report,
  rejects invalid, ready, faulted, or partial baselines before helper calls,
  calls existing helpers exactly in spinlock/request/outbound-memory/
  inbound-memory order, validates each partial state, publishes only
  `OWNER_READY` after complete pre-ready validation, validates the final
  ready-but-non-admitting state, and returns complete stage/result evidence.
- **Failure behavior:** Object-published failures clear `OWNER_READY`, call
  `ChatpadKmdfRequestOwnerRollbackPartialCreation` exactly once, preserve the
  original creation/validation result and framework `NTSTATUS`, record rollback
  result/effects, and require the final state to classify as rolled-back
  `MODEL_READY | FAULTED`. No-object failure uses a narrow ordinary-state
  helper to mark `MODEL_READY | FAULTED` without invoking rollback. Rollback
  failure returns a dedicated rollback-failure result without direct
  best-effort deletion.
- **Ready-state validation:** Extended creation-state validation so fully ready
  requires exact `MODEL_READY | LOCK_CREATED | REQUEST_CREATED |
  OUTBOUND_MEMORY_CREATED | INBOUND_MEMORY_CREATED | OWNER_READY`, no
  `FAULTED`, all four handles, inactive typed request context, exact two-byte
  fixed storage, and the pure model in its non-admitting baseline. `OWNER_READY`
  remains structural only and does not admit activation.
- **Compile-check/guard:** The compile-check takes the orchestration function
  address and validates enum/report shapes without invocation. The semantic
  guard now enforces exact direct WDF counts, no direct WDF call from the
  orchestrator, one source call to each creation helper, helper order,
  centralized rollback call count, no retry loop, ready/faulted/partial
  rejection before helper calls, final ready validation, `OWNER_READY` single
  assignment, and no `ChatpadFilter` linkage. Final semantic output:
  `Semantic guard: PASS (authorized direct calls: WdfSpinLockCreate=1, WdfRequestCreate=1, WdfMemoryCreatePreallocated=2, WdfObjectDelete=2; orchestrator helper calls=4, centralized rollback calls=1; all-or-nothing ready publication, no execution/runtime-driver linkage).`
- **Validation-wrapper correction:** The first attempted Debug
  `tools\Test-ChatpadRequestOwnerModel.ps1` run failed before compilation
  because PowerShell rejected C-style unsigned integer literals such as `14u`.
  `tools\Test-ChatpadRequestOwnerModel.ps1` was corrected narrowly to use
  ordinary PowerShell integer literals in wrapper comparisons. The same Debug
  model wrapper then passed.
- **Context validation:** Debug and Release
  `tools\Test-ChatpadKmdfRequestOwnerContext.ps1` exited `0`; logs:
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T115118Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T115206Z.log`.
- **Regression validation:** Serial Debug/Release wrappers all exited `0`:
  request-owner model `5002/5002`; protocol `610/610`; transport `186/186`;
  lifecycle `109/109`; control setup `141/141`; protocol kernel
  compatibility; WDF control setup; and `Build-Driver.ps1`. Logs span
  `20260630T120035Z` through `20260630T120118Z` beneath
  `C:\Dev\chatpad-super-driver\artifacts\logs\`.
- **Full solution:** Debug and Release full-solution builds exited `0` with
  zero warning/error text in
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-orchestration-Debug-20260630T120133Z.log`
  and
  `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-orchestration-Release-20260630T120133Z.log`.
- **Library evidence:** Final full-solution context/compile-check library
  hashes are Debug
  `60AE6D7EC60B336E50D75AB9F3D75CE004886F68A86D811BE8C91759F8D4490B` /
  `0078CC1AADA7BE980B1E1B122DBF017F7958C46A475F4496FA8E0ADDED003795`
  and Release
  `ACF9F72EBFDB90C313B3A364AA8FA746781B80C1C275E664B14E3347F40A0621` /
  `9746F112ED68C83FA2780D0B4516033E635A19E40515AFA3ED970E4EC86C3714`.
- **Driver evidence:** Debug
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`,
  15,872 bytes, SHA-256
  `2D42065CAF76B003FAB6C59A69775FD089F2390C7E0BBB26EB61A97B227EF0A3`,
  `NotSigned`; Release
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`,
  12,288 bytes, SHA-256
  `CB677048F1F601C4A150E1EE3749CA802DE2D5D81AAED0894EAB38EEFE00F478`,
  `NotSigned`. `dumpbin /imports` found zero orchestration/helper or WDF
  object-management imports in both driver images.
- **Files changed:** Source/header
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
  and `.h`; compile-check
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/ChatpadKmdfRequestOwnerContextCompileCheck.c`;
  semantic/model wrappers; context and compile-check READMEs; and directly
  relevant documentation including
  `docs/OFFLINE-KMDF-CREATION-ORCHESTRATION.md`.
- **Safety:** The orchestration and its creation/rollback calls were compiled
  but never executed; no WDF object was created or deleted during this
  checkpoint. No `ChatpadFilter` source/project/device context or active
  callback changed. No production linkage, target discovery, request
  formatting/reuse/send/completion/cancellation, D0 rundown, InfVerif, Inf2Cat
  executable invocation, CAT, certificate, signing, packaging, staging,
  installation, driver load, Driver Store mutation, registry/service mutation,
  device enumeration, controller/Chatpad interaction, elevation, or network
  operation occurred before the final authorized push.
- **Commit/push:** Commit exactly `driver: compose dormant object creation` and
  push only `origin/feature/offline-kmdf-creation-orchestration`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of this orchestration checkpoint.
  Production linkage, `EvtDeviceAdd` integration, target discovery, request
  formatting, request submission, signing, installation, loading, and hardware
  testing remain unauthorized.

## 2026-06-30 18:43:04 +04:00 - Documentation-only KMDF production integration design checkpoint

- **Task title/objective:** Create the documentation-only production-integration
  design for the dormant KMDF activation request-owner graph. The objective was
  to select the future production linkage, header boundary, device-context owner
  placement, ordinary initialization location, dormant orchestration call
  sequence, cleanup semantics, concurrency/IRQL boundary, evidence contract, and
  next implementation slices without changing driver behavior.
- **Starting branch/commit:** Began on
  `feature/offline-kmdf-creation-orchestration` at
  `39b2356c9193ea33d10d5c689e565a88a2e586c3`, parent
  `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`, subject
  `driver: compose dormant object creation`; upstream was
  `origin/feature/offline-kmdf-creation-orchestration` at the same commit, with
  clean worktree, clean index, and no unstaged or staged diff. Created and
  worked on `feature/offline-kmdf-production-integration-design`.
- **Investigation summary:** Re-read `AGENTS.md`, current project state,
  durable decisions, next task, and the latest worklog. Verified that
  `ChatpadEvtDeviceAdd` currently prints diagnostics, marks the FDO as a filter,
  assigns PnP/power callbacks, creates the WDF device, initializes only
  ordinary context fields and lifecycle state, and returns the lifecycle result.
  Verified that the PnP/power callbacks only retrieve the existing device
  context and update lifecycle state. Confirmed `ChatpadFilter.vcxproj` still
  has no production reference to `ChatpadKmdfRequestOwnerContext`, while the
  dormant static-library project and compile-check projects exist separately.
  Inspected installed KMDF headers for the relevant IRQL contracts and
  `WDF_OBJECT_ATTRIBUTES` parent/context semantics.
- **Files created:** `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`,
  `docs/NEXT-TASK.md`, `docs/WORKLOG.md`, `docs/PORTING-PLAN.md`,
  `docs/OFFLINE-KMDF-CREATION-ORCHESTRATION.md`,
  `docs/OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md`,
  `docs/WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md`,
  `docs/WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md`,
  `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`, and
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`.
- **Implementation details:** Added a 28-section production-integration design.
  The selected path is static-library project linkage first, then a later
  `driver.h` include and embedded per-device
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`, then ordinary
  storage initialization immediately after existing device-context scalar
  initialization and before lifecycle initialization, then dormant orchestration
  immediately after ordinary owner validation and before lifecycle
  initialization. The design preserves exact WDF failure status where available,
  maps local invariant failures to `STATUS_INVALID_DEVICE_STATE`, keeps
  rollback limited to pre-ready partial publication, relies on framework
  device-parent cleanup for later failed `EvtDeviceAdd` returns after structural
  readiness, and requires a future proof checkpoint before implementing that
  behavior. It records that sequential publication is sufficient only while no
  observer exists, and that D0/target/operation/completion/cancel/cleanup
  observers require stronger synchronization in later slices.
- **Commands and validation run:** Preflight commands were
  `git branch --show-current`, `git rev-parse HEAD`,
  `git log -1 --format="%H%n%P%n%s"`, `git status --short --untracked-files=all`,
  `git diff --exit-code`, `git diff --cached --exit-code`,
  `git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'`, and
  `git rev-parse '@{upstream}'`; all matched the required start state. Ran
  read-only source/project/header inspection with PowerShell `Get-Content`,
  `Select-String`, and Git diff commands. Ran `git diff --stat`,
  `git diff --name-only`, section-count validation for the new design, and
  `git diff --check`. Inspected `tools\Test-RepositorySafety.ps1` before
  execution, then ran `.\tools\Test-RepositorySafety.ps1`.
- **Validation results:** `git diff --check` exited `0`.
  `.\tools\Test-RepositorySafety.ps1` exited `0` with `REPOSITORY SAFETY: PASS`.
  The new production-integration design contains exactly 28 numbered sections.
  Markdown link validation initially failed before inspecting files because the
  inline PowerShell validation command used `$file:` inside an interpolated
  string; the command was corrected to `${file}:...` and rerun. Corrected
  Markdown link validation exited `0` with `MARKDOWN LINKS: PASS` across 11
  changed Markdown files. No builds, compile tests, driver tests, InfVerif,
  Inf2Cat, signing, packaging, staging, installation, driver loading, or
  hardware validation were run.
- **Generated artifacts:** None.
- **Commit/push:** Commit exactly `docs: define kmdf production integration`
  and push only `origin/feature/offline-kmdf-production-integration-design`;
  final hash is reported after commit.
- **Safety:** Changed only tracked or new Markdown documentation. Did not modify
  source, headers, project files, solution files, scripts, tests, INF files, or
  files under `legacy/`. Did not execute or invoke the dormant creation helper,
  did not create or delete any WDF object, did not install, load, sign, package,
  stage, or deploy a driver, did not mutate Windows/device/hardware state, and
  did not use network access before the final authorized Git push.
- **Remaining risks/limitations:** This is design-only. Production linkage,
  owner embedding, ordinary owner initialization, dormant orchestration
  invocation, target discovery, request formatting, request submission,
  completion, cancellation, D0/removal rundown, signing, packaging,
  installation, loading, and hardware validation remain future gated tasks.
- **Next gate:** Project-linkage-only dormancy: add only the production project
  dependency needed for `ChatpadFilter` to link the existing dormant
  `ChatpadKmdfRequestOwnerContext` static library, with no include use, no
  device-context field, no helper invocation, no source behavior change, and a
  fresh audit before any behavior-changing slice.

## 2026-06-30 19:05 +04:00 - Project-linkage-only KMDF production integration checkpoint

- **Task title/objective:** Implement only the production project linkage that
  makes `ChatpadFilter` depend on and link the existing dormant
  `ChatpadKmdfRequestOwnerContext` static-library project. Preserve dormancy:
  no production source/header integration, no owner embedding, no helper
  invocation, no WDF object creation/deletion, no target/request operation, and
  no driver install/load/hardware action.
- **Starting branch/commit:** Began on
  `feature/offline-kmdf-production-integration-design` at
  `033bd4fb4deff662ee9e3c2144d10decd27c8a03`, parent
  `39b2356c9193ea33d10d5c689e565a88a2e586c3`, subject
  `docs: define kmdf production integration`, with upstream
  `origin/feature/offline-kmdf-production-integration-design` at the same
  commit, clean worktree, clean index, no unstaged or staged diff, and matching
  design/continuity docs. Created
  `feature/offline-kmdf-production-linkage` only after the gate passed.
- **Investigation summary:** Inspected `ChatpadFilter.vcxproj`,
  `ChatpadKmdfRequestOwnerContext.vcxproj`, `ChatpadWin11.sln`, recent
  decisions, the production integration design, current `ChatpadFilter`
  source/header files, WDK project-reference behavior, linker tlogs, build
  wrapper behavior, and existing semantic guards. Verified the context project
  is a WDK `StaticLibrary`, already present in the solution for Debug/Release
  x64, and that production `.c`/`.h` files contained no request-owner include,
  owner field, initializer/orchestration call, target discovery, request
  operation, or WDF object create/delete code.
- **Implementation details:** Added exactly one native `ProjectReference` from
  `src/driver/ChatpadFilter/ChatpadFilter.vcxproj` to
  `..\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj`
  with GUID `{421C7E3A-5B02-4D07-A37D-4B45D3755694}`. Added
  `GlobalPropertiesToRemove=OutDir;IntDir` and explicit
  `AdditionalProperties` for the context project's artifact `OutDir`/`IntDir`
  so both normal MSBuild and WDK driver-packaging reference passes keep the
  context library under `ChatpadKmdfRequestOwnerContext` artifact roots. No
  solution-file change was required.
- **Guard updates:** Updated
  `tools\Test-ChatpadKmdfRequestOwnerContext.ps1` to require the exact
  project-linkage-only reference while still rejecting production source/header
  integration and forced request-owner retention. Added
  `tools\Test-ChatpadProductionLinkage.ps1` to verify exact project XML,
  absence of manual `.lib`/`/WHOLEARCHIVE`/request-owner `/INCLUDE`, absence of
  request-owner API use in production `.c`/`.h`, absence of prohibited changed
  files, expected build-log link evidence, and final `dumpbin` import/symbol
  absence. Updated lifecycle and WDF-control guards to allow only the exact
  newly authorized project reference.
- **Rejected evidence/discrepancies:** The first context semantic guard failed
  before build because the script accessed absent optional XML metadata under
  strict mode; the guard was fixed. The first driver build with a raw
  `ProjectReference` succeeded but was rejected because WDK propagated the
  driver `OutDir`/`IntDir` into the context project and emitted `MSB8028`.
  Adding only `GlobalPropertiesToRemove` fixed the normal build pass but not
  the WDK packaging pass, so that evidence was also rejected. The first
  production-linkage guard run against build logs rejected generated MSBuild
  artifact paths as if they were hardcoded developer paths; the guard was
  narrowed to reject hardcoded project paths and prohibited retention while
  requiring the expected generated context-library artifact path. The first
  full regression run reached the lifecycle suite and exposed an older guard
  that still prohibited all `ChatpadFilter` project references; lifecycle and
  WDF-control guards were updated to allow only the exact linkage reference.
- **Validation commands/results:** Pre-change and post-build
  `tools\Test-RepositorySafety.ps1` passed. Final
  `tools\Test-ChatpadKmdfRequestOwnerContext.ps1` passed in Debug and Release.
  Final `tools\Build-Driver.ps1` passed in Debug and Release. Post-full
  solution `tools\Test-ChatpadProductionLinkage.ps1` passed in Debug and
  Release. Full-solution Debug and Release builds passed with `0 Warning(s)`
  and `0 Error(s)` in
  `artifacts\logs\full-solution-production-linkage-Debug-final-20260630T185423Z.log`
  and
  `artifacts\logs\full-solution-production-linkage-Release-final-20260630T185423Z.log`.
- **Regression results:** Serial final wrappers all exited `0`: request-owner
  model Debug/Release `5002/5002`; protocol Debug/Release `610/610`;
  transport Debug/Release `186/186`; filter lifecycle Debug/Release
  `109/109`; control setup Debug/Release `141/141`; protocol kernel
  compatibility Debug/Release PASS; WDF control setup Debug/Release PASS.
- **Link/binary evidence:** Final linker tlogs show
  `ChatpadKmdfRequestOwnerContext.lib` in both Debug and Release link inputs,
  with zero request-owner `/INCLUDE`, `/WHOLEARCHIVE`, or `/FORCE` matches.
  The only `/INCLUDE` remains the pre-existing
  `ChatpadPrepareActivationStep`. Final `dumpbin` import/symbol checks found
  no retained request-owner symbols and no imports of `WdfSpinLockCreate`,
  `WdfRequestCreate`, `WdfMemoryCreatePreallocated`, or `WdfObjectDelete`.
- **Artifact hashes:** Final full-solution context libraries: Debug
  `artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  109,382 bytes, SHA-256
  `8FCE8EB6F648ED555C22143642B4E035957E524F84422990BBC6CED053BEA72E`;
  Release
  `artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  93,790 bytes, SHA-256
  `CC4730A4A402079A7EA3557DEADC1E69F626F5C5892AD3FC7031308EEA234DAE`.
  Final driver images: Debug
  `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`, 15,872 bytes,
  SHA-256
  `198DD46B310A041EC40C6A4B5CE97A3B851DDD95CD300D167B929103580929D2`,
  `NotSigned`; Release
  `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`, 12,288 bytes,
  SHA-256
  `040ACC31C1464320037D957777A1C092FD2030D4F2EAE0D10397016CF00F3445`,
  `NotSigned`.
- **Files created:** `docs/OFFLINE-KMDF-PRODUCTION-LINKAGE.md`,
  `docs/evidence/production-linkage-manifest.json`, and
  `tools\Test-ChatpadProductionLinkage.ps1`.
- **Files modified:** `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`,
  `tools\Test-ChatpadKmdfRequestOwnerContext.ps1`,
  `tools\Test-ChatpadFilterLifecycle.ps1`,
  `tools\Test-ChatpadWdfControlSetup.ps1`, `docs/PROJECT-STATE.md`,
  `docs/DECISIONS.md`, `docs/NEXT-TASK.md`, `docs/PORTING-PLAN.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/OFFLINE-KMDF-CREATION-ORCHESTRATION.md`, and `docs/WORKLOG.md`.
- **Evidence manifest:** Tracked manifest
  `docs/evidence/production-linkage-manifest.json` records the checkpoint name,
  starting commit, implementation branch, exact project-reference metadata,
  toolchain identity, command/log hashes, final artifact paths/sizes/hashes,
  final import/symbol results, rejected evidence, repository safety, Markdown
  link status, and prohibited actions not performed. The manifest intentionally
  omits the final commit hash; the commit binds the manifest.
- **Safety:** No production `.c` or `.h` file changed. No owner field was
  embedded; no request-owner header was included; no owner initializer,
  orchestration helper, creation helper, rollback helper, target discovery,
  request formatting/reuse/submission/completion/cancellation, D0/removal path,
  signing, packaging, staging, installation, driver load, Windows/device
  mutation, device enumeration, controller/Chatpad interaction, elevation, or
  network operation occurred before the final authorized push.
- **Commit/push:** Commit exactly `build: link dormant request owner library`
  and push only `origin/feature/offline-kmdf-production-linkage`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of this project-linkage
  checkpoint. Owner embedding, ordinary owner initialization, dormant
  orchestration invocation, WDF object creation, target/request operations,
  signing, installation, loading, and hardware testing remain unauthorized.

## 2026-06-30 - Production-linkage evidence-retention correction

- **Task title/objective:** Complete the retained-evidence record for the
  audited project-linkage-only KMDF production checkpoint without changing the
  linkage implementation or rerunning builds/regression suites.
- **Starting branch/commit:** Began on
  `feature/offline-kmdf-production-linkage` at
  `90ca13f8babfc0c8fd1d14c998c1719e4788a5f6`, parent
  `033bd4fb4deff662ee9e3c2144d10decd27c8a03`, subject
  `build: link dormant request owner library`, with synchronized upstream and
  clean worktree/index. Created
  `feature/offline-production-linkage-evidence-fix`.
- **Investigation:** Confirmed all 22 historical context/build/full-solution,
  semantic, and regression retained logs exist and match the hashes already in
  the manifest. Revalidated existing Debug/Release driver and context-library
  artifacts by size and SHA-256 without rebuilding.
- **Files created:** `docs/OFFLINE-PRODUCTION-LINKAGE-EVIDENCE-CORRECTION.md`.
- **Files modified:** `docs/evidence/production-linkage-manifest.json`,
  `docs/OFFLINE-KMDF-PRODUCTION-LINKAGE.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, and `docs/WORKLOG.md`.
- **Manifest correction:** Added a backward-compatible structured evidence
  array with exact wrapper/command, configuration, path, SHA-256, observed
  result, and applicable assertion or warning/error counts. Added hash-bound
  entries for repository safety, Markdown links, final JSON parsing, and
  unstaged/staged diff checks.
- **Validation:** All 22 historical retained logs matched. Repository safety,
  six-file Markdown-link validation, final JSON parsing, `git diff --check`,
  and `git diff --cached --check` passed. The final manifest contains 27
  evidence entries, and every path/hash pair matched after staging.
- **Artifacts:** Newly generated deterministic transcripts remain ignored
  under `artifacts/logs`; no artifact is staged or committed.
- **Safety:** No build, compiler, regression wrapper, source/header,
  project/solution, script/test, INF/signing/package/deployment/recovery,
  helper, WDF object, target/request, installation/loading, Windows mutation,
  hardware query, or controller/Chatpad action occurred.
- **Remaining limitations:** The semantic wrapper remains targeted and
  regex/text based, and historical evidence does not prove runtime execution.
- **Commit/push:** Commit exactly
  `docs: complete production linkage evidence` and push only
  `origin/feature/offline-production-linkage-evidence-fix`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of the corrected evidence
  manifest. Only after PASS may the separately gated owner-embedding and
  ordinary-initialization design slice be considered.

## 2026-06-30 - Production owner embedding and ordinary initialization

- **Task title/objective:** Embed exactly one authoritative KMDF request owner
  in each production device context, initialize ordinary storage once, and
  immediately validate the clean pre-object baseline before lifecycle
  initialization. Keep dormant orchestration and every WDF object/target/
  request operation absent.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-production-linkage-evidence-fix` at
  `41172d7f2877509a16f3b58abf0f81d231cbabaf`, parent
  `90ca13f8babfc0c8fd1d14c998c1719e4788a5f6`, subject
  `docs: complete production linkage evidence`, then created
  `feature/offline-kmdf-owner-embedding-init`.
- **Preflight:** Debug and Release context libraries each contained only
  `ChatpadKmdfRequestOwnerContext.obj`. Initializer, pre-object validator,
  creation helpers, rollback, orchestration, and WDF thunks occupy separate
  `/Gy` COMDATs. Driver links use `/OPT:REF`, `/OPT:ICF`, and
  `/INCREMENTAL:NO`, with no request-owner `/INCLUDE` or `/WHOLEARCHIVE`.
  Referencing only the two WDF-free functions was therefore safe in both
  configurations.
- **Implementation:** `driver.h` includes the authoritative context header and
  embeds exactly
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`.
  `ChatpadEvtDeviceAdd` calls
  `ChatpadKmdfRequestOwnerInitializeStorage`, maps its typed result, calls
  `ChatpadKmdfRequestOwnerValidatePreObjectState`, and proceeds to
  `ChatpadFilterLifecycleInitialize` only after both succeed. The exact
  insertion is after `context->DiagnosticSequence = 0u;`.
- **Project integration:** Kept the existing context-library project
  reference unchanged. Added only the required context/model/transport include
  roots and compiled the portable `ChatpadRequestOwnerModel.c` directly as a
  WDK object. The user-mode model library was rejected because it carries
  `MSVCRT`/`MSVCRTD` default-library metadata.
- **Status mapping:** `OK` maps to `STATUS_SUCCESS`; impossible null owner or
  validation inputs map to `STATUS_INVALID_PARAMETER`; repeated initialization
  and invariant failures map to `STATUS_INVALID_DEVICE_STATE`; every
  pre-object validation failure returns `STATUS_INVALID_DEVICE_STATE`.
- **Guard changes:** Added
  `tools/Test-ChatpadProductionOwnerInitialization.ps1`; updated production
  linkage, context, model, lifecycle, and WDF formatter guards to permit only
  the exact embedded-owner/portable-model integration while retaining
  creation/orchestration/target/request prohibitions.
- **Validation:** Repository safety passed before changes. Debug and Release
  context checks, driver builds, owner-initialization guards, linkage guards,
  and Visual Studio Community full-solution builds passed. Successful solution
  logs contain zero warning/error diagnostics. An earlier solution attempt
  selected Build Tools MSBuild without WDK integration and failed with
  `MSB8020`; that log is retained as rejected evidence.
- **Regressions:** Debug and Release request-owner model `5002/5002`, protocol
  `610/610`, transport `186/186`, lifecycle `109/109`, control setup
  `141/141`; protocol kernel compatibility and WDF control setup PASS in both.
- **Binary evidence:** Debug driver is 20,992 bytes, SHA-256
  `FB9E9DD550BEF64B99BFAA74810A953A5B0DC12BB455869D7787FB657B565B8F`;
  Release is 14,336 bytes, SHA-256
  `9EA24A8B6BEB2796B9A1FF55A04486C8E3EB59B94A191AEA6F50B322531CBCE3`.
  Both are `NotSigned`; no creation/rollback/orchestration symbols and no
  forbidden WDF object-management or target/request imports are exposed.
- **Evidence:** Full ignored logs are under `artifacts/logs`; the tracked
  manifest is
  `docs/evidence/production-owner-initialization-manifest.json`.
- **Files changed:** Production `driver.h`, `device.c`, and
  `ChatpadFilter.vcxproj`; six semantic/build guards; directly relevant
  README/build/continuity documents; new checkpoint document and evidence
  manifest. No isolated context/model semantics, `legacy/`, INF, signing,
  package, deployment, recovery, D0, cleanup, removal, or hardware file
  changed.
- **Safety:** No orchestration, WDF object creation/deletion, rollback, target
  discovery, request operation, signing, packaging, staging, installation,
  loading, Windows mutation, device enumeration, elevation, or controller/
  Chatpad interaction occurred. Network access is reserved for the final
  authorized Git push.
- **Commit/push:** Commit exactly
  `driver: initialize production request owner` and push only
  `origin/feature/offline-kmdf-owner-embedding-init`; final hash is reported
  after commit.
- **Next gate:** Independent read-only audit of this production owner
  embedding and ordinary-initialization checkpoint. Dormant orchestration
  invocation remains unauthorized.

## 2026-06-30 - Owner initialization audit corrections

- **Task title/objective:** Complete the narrow documentation, semantic-guard,
  and evidence-retention correction for the audited production request-owner
  initialization checkpoint without changing production implementation.
- **Starting branch/commit:** Began from clean synchronized
  `feature/offline-kmdf-owner-embedding-init` at
  `a25d5637487ec6e4e7583a64dcec6c5192e06092`, parent
  `41172d7f2877509a16f3b58abf0f81d231cbabaf`, subject
  `driver: initialize production request owner`; created
  `feature/offline-owner-init-audit-corrections`.
- **Investigation:** Verified the existing Debug and Release driver binaries,
  request-owner context libraries, device/model objects, linker tlogs, manifest
  path/hash pairs, and clean branch/upstream baseline before editing. Found
  stale documentation that still treated linkage-only as the current boundary
  and over-compressed the distinction between initializer-internal validation
  and the explicit production boundary validation.
- **Files created:** `docs/OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md`.
- **Files modified:** `tools/Test-ChatpadProductionOwnerInitialization.ps1`,
  `docs/evidence/production-owner-initialization-manifest.json`,
  `docs/OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md`,
  `docs/OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md`,
  `docs/OFFLINE-KMDF-PRODUCTION-LINKAGE.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`,
  `docs/PORTING-PLAN.md`, and `docs/WORKLOG.md`.
- **Guard correction:** The production owner-initialization guard now supports
  `SourceOnly` and `Full` inspection modes, validates exact project/source
  semantics, rejects forbidden owner/WDF/target/request behavior, checks
  manifest evidence paths for ignored artifact containment, inspects retained
  Debug/Release objects, libraries, linker tlogs, PE sections, symbols, and
  signature/hash state, and reports direct observations separately from
  inferred evidence and proof limits.
- **Documentation correction:** Current docs now state that owner embedding and
  ordinary initialization supersede the linkage-only boundary; the initializer
  internal baseline validation and the one explicit `EvtDeviceAdd` pre-object
  boundary validation are recorded as distinct checks; KMDF function-table
  dispatch is documented as a limit of ordinary import inspection.
- **Validation:** Corrected non-building validation passed after the manifest
  update: Debug and Release guard `Full` mode, binary/member inspection through
  the corrected guard, Markdown links, JSON parsing, repository safety, and
  unstaged/staged diff checks. The manifest retains exact commands, working
  directories, paths, hashes, configurations, modes, and results for the
  corrected entries. Final evidence path/hash verification is rerun before
  commit.
- **Artifacts:** New ignored correction transcripts are retained under
  `artifacts/logs` and hash-bound in
  `docs/evidence/production-owner-initialization-manifest.json`.
- **Safety:** No production `.c/.h`, project/solution file, owner model,
  request-owner implementation, build/regression wrapper, `legacy/` file, INF,
  signing, package, deployment, recovery, D0, cleanup, removal, Windows state,
  device state, or hardware state was changed. No build, regression suite,
  driver loading, helper invocation through a driver, WDF object creation,
  target/request operation, device query, or hardware interaction occurred.
- **Remaining limitations:** This correction still proves only the offline
  retained evidence and semantic guard boundary. It does not prove runtime
  execution, orchestration, WDF object creation, request execution, deployment,
  or hardware behavior.
- **Commit/push:** Commit exactly
  `test: tighten owner initialization audit` and push only
  `origin/feature/offline-owner-init-audit-corrections`; final hash is reported
  after commit.
- **Next gate:** Independent read-only audit of this correction checkpoint.

## 2026-06-30 23:11 +04:00 - Owner initialization documentation consistency correction

- **Task title/objective:** Perform a narrow documentation-only consistency
  correction for the completed production request-owner initialization phase,
  ensuring current-state wording no longer presents completed linkage,
  owner-embedding, ordinary-initialization, or explicit pre-object validation
  as future work.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-owner-init-audit-corrections` at
  `a08ea1f5e4431893bc84e459957a3a63509d0c2f`, parent
  `a25d5637487ec6e4e7583a64dcec6c5192e06092`, subject
  `test: tighten owner initialization audit`, then created
  `feature/offline-owner-init-doc-consistency`.
- **Investigation:** Confirmed the primary stale wording was in
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md` and
  `docs/PORTING-PLAN.md`, where historical design slices still used future
  language for project linkage, owner embedding, and ordinary initialization.
  Confirmed continuity handoff files still pointed at the already completed
  owner-initialization audit rather than the requested documentation
  consistency audit.
- **Files modified:** `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PORTING-PLAN.md`, `docs/NEXT-TASK.md`, `docs/PROJECT-STATE.md`, and
  `docs/WORKLOG.md`.
- **Documentation correction:** Relabeled the original production-integration
  design baseline as historical pre-integration state, marked project linkage,
  owner embedding, ordinary initialization, explicit pre-object validation,
  audits, and evidence corrections as completed, and kept dormant
  orchestration, WDF object graph creation, target discovery, request
  operations, D0/removal rundown, signing, staging, installation, loading, and
  hardware validation as future unauthorized work.
- **Validation-count wording:** Current-state wording distinguishes initializer
  internal validation from one additional explicit `EvtDeviceAdd` pre-object
  integration-boundary validation. The correction does not describe the state
  as one total validation, two validator calls, duplicate validation, or an
  initializer invoked twice.
- **Continuity:** Replaced `docs/NEXT-TASK.md` with the exact next gate:
  independent read-only documentation-consistency audit of the
  owner-initialization current-state corrections. Updated
  `docs/PROJECT-STATE.md` only to remove direct stale branch/next-gate
  contradictions.
- **Validation:** Complete diff review performed. `git diff --check` passed
  with only Git line-ending warnings. Modified relative Markdown-link
  validation passed for five modified Markdown files. Stale-current-state
  searches in the two primary documents found no remaining unqualified claims
  that project linkage, owner embedding, ordinary initialization, or explicit
  pre-object validation are future work. Non-building repository safety passed.
  Changed-path checks confirmed only Markdown files changed and no source,
  project, script, manifest, evidence, artifact, or generated path changed.
- **Safety:** No source, header, project, solution, script, test, manifest,
  evidence, artifact, binary, INF, package, signing, recovery, deployment, D0,
  removal, USB, or hardware file was intentionally changed. No build,
  regression suite, compile check, driver load, helper invocation, WDF object
  creation/deletion, target/request operation, signing, staging, installation,
  Windows mutation, hardware query, controller/Chatpad interaction, merge, or
  force-push is authorized.
- **Commit/push:** Commit exactly
  `docs: align owner initialization state` and push only
  `origin/feature/offline-owner-init-doc-consistency`; final hash is reported
  after commit.
- **Next gate:** Independent read-only documentation-consistency audit of the
  owner-initialization current-state corrections. Dormant orchestration remains
  unauthorized.

## 2026-06-30 23:36 +04:00 - Production orchestration invocation design

- **Task title/objective:** Create the documentation-only design for invoking
  the existing dormant KMDF request-owner object-graph orchestrator from the
  production `ChatpadFilter` `EvtDeviceAdd` path. Correct the stale
  `docs/PROJECT-STATE.md` current checkpoint subject and keep the task
  Markdown-only.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-owner-init-doc-consistency` at
  `8b91eaf939252e038bd0970db261cc14b1089613`, parent
  `a08ea1f5e4431893bc84e459957a3a63509d0c2f`, subject
  `docs: align owner initialization state`, then created
  `feature/offline-kmdf-production-orchestration-design`.
- **Investigation:** Inspected the repository protocol, project state,
  decisions, next task, recent worklog, current `driver.h`, current
  `device.c`, current `ChatpadFilter.vcxproj`, the request-owner context
  header and implementation, existing production integration design,
  orchestration, rollback, owner-initialization, context-definition,
  object-lifecycle, buffer-lifetime, and transport-bridge documents. Inspected
  installed KMDF 1.15 headers under
  `C:\Program Files (x86)\Windows Kits\10\Include\wdf\kmdf\1.15` for the
  relevant IRQL and object-attribute contracts.
- **Files created:**
  `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`.
- **Files modified:** `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`,
  `docs/DECISIONS.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`, and
  `docs/WORKLOG.md`.
- **Design details:** Selected the future insertion point immediately after
  the explicit production
  `ChatpadKmdfRequestOwnerValidatePreObjectState` check and before
  `ChatpadFilterLifecycleInitialize`. The design defines one future
  orchestrator call, caller-owned report storage, complete result-to-status
  mapping, no-object failure behavior, partial-object rollback behavior,
  final-ready validation failure behavior, rollback-failure behavior, later
  `EvtDeviceAdd` failure cleanup by WDF parent hierarchy, exact WDF parentage,
  callback visibility, concurrency assumptions, IRQL assumptions, future
  implementation scope, semantic-guard expectations, validation plan,
  evidence contract, independent audit gate, runtime observation gate, and
  normal removal boundary.
- **Metadata correction:** `docs/PROJECT-STATE.md` now records current
  implementation checkpoint commit
  `8b91eaf939252e038bd0970db261cc14b1089613` with subject
  `docs: align owner initialization state`. The earlier
  `test: tighten owner initialization audit` subject remains only historical
  in existing worklog and decision context.
- **Safety:** The task is documentation-only. It does not implement or invoke
  dormant orchestration, create or delete WDF objects, execute rollback,
  publish `OWNER_READY` at runtime, discover targets, format/reuse/submit/
  complete/cancel requests, change D0/removal behavior, build, run
  regressions, sign, package, stage, install, load, mutate Windows state,
  query hardware, or interact with a controller or Chatpad.
- **Validation:** Starting-state verification passed. Source count checks
  confirmed one production header include, one embedded owner, one ordinary
  initializer call, one explicit pre-object validator call, zero production
  orchestrator references, zero production rollback references, zero
  production `OWNER_READY` references, and one context project reference. The
  new design contains exactly 28 numbered sections. Modified/new Markdown-link
  validation passed. Repository safety passed through the documented
  non-building `tools\Test-RepositorySafety.ps1` path. `git diff --check`
  reported only Git line-ending conversion warnings from `core.autocrlf=true`.
  Line-ending inspection found LF-only working-tree content for the six
  changed Markdown files and no lone carriage returns. Changed-path checks
  found only Markdown files.
- **Commit/push:** Commit exactly `docs: design production owner orchestration`
  and push only
  `origin/feature/offline-kmdf-production-orchestration-design`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of the production
  orchestration-invocation design. Source implementation, driver loading,
  signing, installation, target discovery, request execution, and hardware
  observation remain unauthorized.

## 2026-06-30 23:55 +04:00 - Production orchestration invocation design correction

- **Task title/objective:** Correct the documentation-only production KMDF
  request-owner orchestration-invocation design so it exactly matches the
  existing dormant orchestrator's early-rejection, post-baseline no-object
  stage failure, and partial-state validation behavior.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-kmdf-production-orchestration-design` at
  `eb0a9e90f7adc424ae7e5c471a0c8977a71b6efe`, parent
  `8b91eaf939252e038bd0970db261cc14b1089613`, subject
  `docs: design production owner orchestration`, then created
  `feature/offline-kmdf-orchestration-design-fix`.
- **Failed-audit finding:** The first orchestration-invocation design
  incorrectly treated no-object/pre-publication failures as one category that
  reaches the common failure path and transitions the owner to
  `MODEL_READY | FAULTED`.
- **Source behavior:** Current
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
  returns invalid-baseline and null-parent results before common
  `OrchestrationFailure` handling. Those paths call no creation helper,
  publish no object, call no rollback helper, and perform no automatic fault
  transition. Only a post-baseline staged creation failure before object
  publication reaches common failure handling and uses the existing no-object
  fault helper.
- **Files modified:** `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`, and
  `docs/WORKLOG.md`.
- **Documentation correction:** The corrected design now distinguishes null
  production input, null parent-device rejection, invalid baseline,
  already-ready, already-faulted, pre-existing partial state, post-baseline
  spinlock no-publication failure, request/outbound/inbound failures,
  partial-state validation failures, pre-ready validation failure, final-ready
  validation failure, rollback failure, and later `EvtDeviceAdd` failure after
  successful structural readiness. The clean baseline explicitly includes
  `SequenceAdvanceEligible == 0u`.
- **Partial-state validation mapping:** The design records that these failures
  use the actual stage failure result plus `FailedStage` and
  `ValidationResult`, not a dedicated orchestration enum. In the current
  source, staged partial-state validation runs after the relevant helper has
  returned OK and published the stage object, so rollback is selected for those
  validation failures. The post-baseline no-object fault helper owns the
  separate spinlock-stage no-publication failure path.
- **Validation to retain:** Complete diff review; changed-path containment;
  28-section check; searches for overgeneralized no-object wording; relative
  Markdown-link validation; repository safety through the non-building
  documented path; line-ending inspection; unstaged/staged diff checks; and
  staged diff review.
- **Safety:** Documentation-only. No source/header, project/solution, script,
  test, manifest, evidence, artifact, binary, INF, signing, package,
  deployment, recovery, D0, removal, USB, or hardware file is changed. No
  build, regression, compile check, semantic guard that generates evidence,
  helper invocation, WDF object creation/deletion, rollback execution, driver
  loading, target/request operation, Windows mutation, hardware query,
  controller/Chatpad interaction, merge, or force-push is authorized.
- **Commit/push:** Commit exactly
  `docs: correct production orchestration failures` and push only
  `origin/feature/offline-kmdf-orchestration-design-fix`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of the corrected production
  orchestration-invocation design. Production orchestration remains
  unimplemented and unauthorized.

## 2026-07-01 00:53 +04:00 - Report-aware orchestration design correction

- **Task title/objective:** Correct the documentation-only production KMDF
  orchestration-invocation design so caller-owned report handling and the
  complete per-category report/status taxonomy match the existing dormant
  orchestrator.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-kmdf-orchestration-design-fix` at
  `8ec45055b3608ae917fa05e762ce37f73424ab63`, parent
  `eb0a9e90f7adc424ae7e5c471a0c8977a71b6efe`, subject
  `docs: correct production orchestration failures`, then created
  `feature/offline-kmdf-orchestration-report-design-fix`.
- **Investigation:** Re-read the repository protocol and continuity files,
  inspected the complete authoritative orchestration report definition and
  every report assignment/reset in
  `ChatpadKmdfRequestOwnerContext.c`, and built an uncommitted internal matrix
  covering early returns, each creation/validation stage, ready publication,
  no-object faulting, rollback success/failure, and success.
- **Audit findings corrected:** The second independent audit found that the
  report/status taxonomy omitted mandatory report and mask behavior, the
  future C fragment described an uninitialized declaration as initialized, and
  LTCG limitations were not explicit. The earlier correction of null-parent,
  invalid-baseline, and post-baseline no-object semantics remains unchanged.
- **Design correction:** Section 6 now binds exactly one local
  `ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };`,
  documents the orchestrator's own `RtlZeroMemory`, synchronous non-escaping
  report lifetime, one call, deterministic status mapping, and lifecycle only
  after success. Section 10 now contains 22 explicit categories with stages,
  helper/validator/framework results, highest/final masks, ready flags,
  rollback result/effects, final owner state, production status, lifecycle,
  and final `EvtDeviceAdd` outcome.
- **Mask and rollback semantics:** Documented that early rejection retains the
  incoming non-null-owner mask; after a clean accepted baseline,
  `HighestPartialInitializationMask` records the pre-ready published prefix,
  excludes tentative `OWNER_READY` and later `FAULTED`, and is unchanged by
  rollback. `FinalInitializationMask` records the actual non-null-owner return
  state and can contain `FAULTED` or `OWNER_READY`. Rollback failure preserves
  the original stage/helper/validator/framework evidence and records exact
  rollback effects.
- **LTCG correction:** Future retention proof now combines source, object,
  COMDAT/function-level-linking, linker/LTCG, WDF function-table, and final
  image evidence without requiring LTCG to be disabled or treating one named
  PE symbol as decisive.
- **Files modified:**
  `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`, and
  `docs/WORKLOG.md`.
- **Validation:** The main design contains exactly 28 sequential numbered
  sections and exactly 22 required taxonomy rows. Markdown table pipe counts
  are consistent. The zero-initialized report declaration occurs exactly once;
  highest/final masks and LTCG are explicit. Relative Markdown-link validation
  passed for 11 links with zero broken/untracked/case-mismatched targets.
  `tools\Test-RepositorySafety.ps1` passed in its non-building, non-mutating
  mode. `git diff --check` passed with only `core.autocrlf` conversion notices.
  All six working-tree files are LF-only and no generated/tracked output
  appeared. Two initial combined inline validation commands did not execute
  because of PowerShell parser errors; they changed nothing, and the checks
  were split into smaller commands that completed successfully.
- **Safety:** Documentation-only. No source/header, project/solution,
  script/test, manifest/evidence, artifact/binary, INF, signing, package,
  deployment, recovery, D0/removal, USB, or hardware file changed. No build,
  regression, compile check, helper, orchestration, rollback, WDF object
  action, driver load, Windows mutation, hardware query, or controller/Chatpad
  interaction occurred.
- **Commit/push:** Commit exactly
  `docs: complete orchestration report design` without amend and push only
  `origin/feature/offline-kmdf-orchestration-report-design-fix`; final hash is
  reported after commit.
- **Next gate:** Independent read-only audit of the corrected report-aware
  production orchestration-invocation design. Source implementation and every
  runtime action remain unauthorized.

## 2026-07-01 07:12 +04:00 - Orchestration report-contract correction

- **Task title/objective:** Correct the three remaining documentation-only
  defects found by the third independent production orchestration-invocation
  design audit: explicit report-field binding, deterministic later lifecycle
  failures, and explicit highest/final-mask evidence requirements.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-kmdf-orchestration-report-design-fix` at
  `ad04ebc17a4ca75d033a08514f692b037a5e6dc8`, parent
  `8ec45055b3608ae917fa05e762ce37f73424ab63`, subject
  `docs: complete orchestration report design`, then created
  `feature/offline-kmdf-orchestration-report-contract-fix`.
- **Investigation:** Re-read the repository protocol and continuity files,
  verified all 19 authoritative report fields and every relevant `Result`/
  ready-publication assignment, and inspected current `device.c` plus
  lifecycle implementation/status mapping. The source confirms that valid
  report paths finalize report `Result` to the function return, only the
  publish-ready stage sets `ReadyPublicationAttempted`, and current
  post-orchestration failures are limited to lifecycle initialization or the
  following device-created transition.
- **Files modified:**
  `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`, and
  `docs/WORKLOG.md`.
- **Report contract:** The 22-category taxonomy now binds function return and
  exact report `Result` separately, lists all 19 exact source fields, and
  assigns every field through explicitly ordered grouped columns with no blank
  cells. It binds exact `ReadyPublicationAttempted` independently from
  `ReadyPublished`, final-mask `OWNER_READY`, `ObjectGraphComplete`, and
  success. A function-return/report mismatch is a hard
  `STATUS_INVALID_DEVICE_STATE` failure that preserves diagnostics, invokes no
  caller-owned rollback, and cannot reach lifecycle initialization.
- **Lifecycle contract:** Category 22 remains one top-level category with
  deterministic subcases 22A and 22B. Subcase 22A records initializer
  `NULL_STATE` mapping to `STATUS_INVALID_PARAMETER` without calling the
  device-created transition. Subcase 22B records successful initialization
  followed by `NOT_MARKED` or `INVALID_PHASE`, both mapped to
  `STATUS_INVALID_DEVICE_STATE`. Neither subcase calls pre-ready rollback or
  manually clears the owner; failed-device WDF hierarchy destruction remains
  authoritative.
- **Evidence contract:** Future evidence now explicitly checks
  `HighestPartialInitializationMask` progression and rollback stability,
  `FinalInitializationMask` on all required early/failure/success paths, exact
  final owner-state correspondence, `OWNER_READY`/`FAULTED` presence, and exact
  command/result/SHA-256 binding. No evidence manifest was created or changed.
- **Validation:** Structural inspection passed with 28 sequential numbered
  sections, 22 taxonomy categories, one 22A and one 22B subdivision, all 19
  source fields explicitly present, consistent 10-cell taxonomy rows, and zero
  blank cells. Ambiguity searches found no `returned result`, unlabeled ready
  flags, `may have run`, `possibly initialized`, `TBD`, `later decide`, or
  unresolved `either/or` wording. Eleven relative Markdown links passed
  existence/tracking/case/anchor checks. `git diff --check` passed with only
  expected `core.autocrlf=true` conversion warnings. All six working-tree
  Markdown files are LF-only with no CRLF or lone-CR content; numstat shows
  targeted edits rather than whole-file conversion. The documented
  non-building `tools\Test-RepositorySafety.ps1` check passed.
- **Failed command:** An initial read used the nonexistent path
  `src\driver\ChatpadFilterLifecycle\ChatpadFilterLifecycle.c` and failed
  without changing state. Read-only discovery located the authoritative file
  at `src\driver\ChatpadFilter\ChatpadFilterLifecycle.c`, which was then
  inspected successfully.
- **Safety:** Documentation-only. No source/header, project/solution,
  script/test, manifest/evidence, artifact/binary, INF, signing, package,
  deployment, recovery, D0/removal, USB, or hardware file changed. No build,
  test, compile, helper, initialization, validation, orchestration, rollback,
  WDF object action, driver load, Windows mutation, hardware query, or
  controller/Chatpad interaction occurred.
- **Commit/push:** Commit exactly
  `docs: bind orchestration report contract` without amend and push only
  `origin/feature/offline-kmdf-orchestration-report-contract-fix`; final hash
  is reported after commit.
- **Next gate:** Independent read-only audit of the corrected report contract.
  Production orchestration implementation and every runtime action remain
  unauthorized.

## 2026-07-01 07:49 +04:00 - Orchestration taxonomy-contract finalization

- **Task title/objective:** Correct the final three documentation-only defects
  found by the fourth independent orchestration report-contract audit:
  inferred taxonomy/effect values, incomplete section-28 exact-field binding,
  and insufficient `ReadyPublicationAttempted` semantic guarding.
- **Starting branch/commit:** Verified clean synchronized
  `feature/offline-kmdf-orchestration-report-contract-fix` at
  `6f9f2750347ee6ecd50470261a6af0a859b53357`, parent
  `ad04ebc17a4ca75d033a08514f692b037a5e6dc8`, subject
  `docs: bind orchestration report contract`, then created
  `feature/offline-kmdf-orchestration-taxonomy-contract-fix`.
- **Investigation:** Re-read the repository protocol and continuity files;
  inspected the complete report, orchestration, stage, storage, creation,
  validation, rollback, effects, and initialization-mask definitions; and
  traced every helper, validator, failure label, rollback assignment, and
  return. Source proves five exact effect profiles (`E0`-`E4`), 20 closed
  rollback-origin profiles, and one post-effect final state (`FAULT`).
- **Files modified:**
  `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`,
  `docs/WINDOWS11-KMDF-PRODUCTION-INTEGRATION-DESIGN.md`,
  `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/DECISIONS.md`, and
  `docs/WORKLOG.md`.
- **Taxonomy correction:** Replaced inferred helper/validator/effect wording
  with exact enum notation, closed validator sets, exact WDF-status pairings,
  and exact rollback-effect profiles. Categories 9-18 now describe successful
  recovery only; categories 19 and 20 use a closed 20-profile origin matrix.
  Category 19 is explicitly defensive and pre-deletion with `E0`; category 20
  records `POST_ROLLBACK_INVARIANT_FAILED`, `E1`-`E4`, and exact final
  `MODEL_READY | FAULTED` state.
- **Effects and ready contract:** Documented all seven
  `RollbackEffects` members and exact `E0`-`E4` values, nominal `P1`-`P4`
  handle states, closed rejection results, and the single post-effect final
  state. Added a ready-field truth table covering early rejection, all stage
  failures, final-ready recovery, rollback failures, success, and later
  `EvtDeviceAdd` failure.
- **Section 28 and guards:** Added a 19-row exact-field table binding every
  report field by meaning, authoritative assignment source, production use,
  and guard/evidence requirement. The semantic guard now proves
  `ReadyPublicationAttempted=FALSE` before `PUBLISH_READY`, `TRUE` for
  final-ready failure/profile `R20`/success, persistence through rollback, and
  independence from `ReadyPublished`, `ObjectGraphComplete`, and final-mask
  `OWNER_READY`.
- **Validation:** Structural checks passed with 28 sequential sections, 22
  top-level categories, one 22A and one 22B subdivision, 10 populated cells in
  every category row, all 19 exact field names in section 28, five effect
  profiles, 20 origin profiles, one ready-field truth table, and zero banned
  placeholder phrases. Eleven relative Markdown links passed
  existence/tracking/case/anchor checks. `git diff --check` passed with only
  expected `core.autocrlf=true` conversion notices. The documented non-building
  `tools\Test-RepositorySafety.ps1` check passed. Two later ad hoc checker
  attempts failed because the first regex spanned adjacent Markdown tables and
  the second expected `Scenario` instead of the actual `Path` ready-table
  header; the corrected blank-line-bounded and exact-header parser passed with
  the expected 22 rows, 10 populated cells per row, and one ready truth table.
- **Safety:** Documentation-only. No source/header, project/solution,
  script/test, manifest/evidence, artifact/binary, INF, signing, package,
  deployment, recovery, D0/removal, USB, or hardware file changed. No build,
  regression, test, compile, helper, initialization, validation,
  orchestration, rollback, WDF object action, driver load, Windows mutation,
  hardware query, or controller/Chatpad interaction occurred.
- **Commit/push:** Commit exactly
  `docs: finalize orchestration taxonomy contract` without amend and push only
  `origin/feature/offline-kmdf-orchestration-taxonomy-contract-fix`; final hash
  is reported after commit.
- **Next gate:** Independent read-only audit of the finalized taxonomy and
  report contract. Production implementation and every runtime action remain
  unauthorized.
