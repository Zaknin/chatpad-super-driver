# Next Task

## Current State

* Branch: `test/protocol-fixtures`
* HEAD: task commit `feat: add portable chatpad keyboard parser` (the commit containing this file; parent `42236aba04b66cc4d74d15ce8520e230a9c0d595`).
* Toolchain: VS 2022 17.14.35, MSVC 14.44.35207, SDK/WDK 10.0.26100.0, KMDF 1.35, WDK integration ready.
* Driver build: Debug x64 and Release x64 exit 0, produce `NotSigned` `.sys` files, and execute no signing task.
* Protocol parser: portable C, exactly five bytes, type `0x00` only, modifier upper bits rejected as Phase 1 policy, all accepted fields preserved raw, and output cleared on failure.
* Offline tests: direct Debug x64 compilation and execution pass with 85/85 assertions. Fixtures are neutral and synthetic.
* Outputs: generated parser and test files exist only beneath ignored `artifacts/`; repository safety passes.
* No Visual Studio solution or project integration exists for the parser or tests.
* Driver remains a nonfunctional unsigned skeleton; `legacy/` is untouched.

## Next Recommended Objective

Integrate the parser and offline tests into native Debug and Release Visual Studio projects, contain all outputs under artifacts/, and run driver regression builds.

Specifically:

1. Add native Visual Studio projects for the portable parser and offline test executable with Debug x64 and Release x64 configurations.
2. Integrate those projects into `ChatpadWin11.sln` without linking the parser into the KMDF driver.
3. Route every parser/test output and intermediate beneath repository-root `artifacts/`.
4. Run parser tests in both Debug and Release and report exact assertion counts and hashes.
5. Re-run unsigned Debug x64 and Release x64 driver builds as regression checks.

## Required Branch and Starting Commit

* Branch: create `test/protocol-projects` from `origin/test/protocol-fixtures`.
* Starting commit: the pushed `feat: add portable chatpad keyboard parser` commit; record its exact hash with `git rev-parse origin/test/protocol-fixtures` before editing.

## Preconditions

* Confirm `origin/test/protocol-fixtures` matches the local parser commit and repository safety passes.
* Read `src/protocol/ChatpadProtocol/README.md`, `tests/protocol/README.md`, and `tools/Test-ChatpadProtocolParser.ps1` before designing projects.
* Do not modify any file under `legacy/`.
* Do not execute any file from `legacy-source/` or any generated `.sys`.
* Do not install, load, sign, package, deploy, or execute a driver.
* Do not commit generated binaries, PDBs, objects, or logs.

## Safety Restrictions

* Never modify `legacy/`.
* Offline parser test execution only; no device access or live USB/HID interaction.
* No INF, CAT, certificate, package, installer, deployment project, driver signing, or system configuration changes.
* Keep generated outputs under ignored `artifacts/` and preserve all current repository safety gates.
* Preserve the raw parser API and neutral fixture semantics unless new evidence is documented first.

## Acceptance Criteria

* Native parser and test projects build in Debug x64 and Release x64 with strict warnings and warnings-as-errors.
* All 85 assertions pass in both configurations with deterministic ASCII output.
* All generated parser, test, and driver outputs remain beneath ignored `artifacts/`.
* Existing Debug x64 and Release x64 driver regression builds exit 0 and remain `NotSigned`.
* The parser is not linked into the driver and no runtime/device behavior is added.
* Repository safety passes and no generated binary or log is tracked.

## Commands and Files to Inspect First

1. `git branch --show-current`, `git rev-parse HEAD`, `git status --short --branch`, and `git log --oneline -5`.
2. `tools/Test-RepositorySafety.ps1` and `tools/Test-ChatpadProtocolParser.ps1`.
3. `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.h` and `ChatpadKeyboardParser.c`.
4. `tests/protocol/ChatpadProtocolParserTests.c` and `fixtures/ChatpadKeyboardFixtures.h`.
5. `ChatpadWin11.sln`, `Directory.Build.props`, and existing driver output conventions.
