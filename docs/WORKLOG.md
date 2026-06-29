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
