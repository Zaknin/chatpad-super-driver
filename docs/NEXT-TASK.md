# Next Task

## Current state

- **Branch:** `test/protocol-fixtures` / HEAD `d6a5c7e01b644871951aa3cfbb410cca92cdb01a`
- **Protocol integration:** Committed and pushed.
- **Working tree:** Clean.
- **All builds verified passing:** Parser 85/85, Protocol 85/85 (Debug+Release), Driver 0/0 (Debug+Release).
- **Driver isolation proven:** ChatpadFilter does not link ChatpadProtocol.lib.
- **ChatpadProtocol static library:** Builds cleanly as x64 Debug and Release under `artifacts/`.
- **ChatpadProtocolTests test executable:** Builds cleanly as x64 Debug and Release under `artifacts/`.
- **Dependency mechanism:** `ChatpadProtocolTests.vcxproj` uses a native `ProjectReference` to `ChatpadProtocol.vcxproj`; solution-level `SolutionDependencies` section removed.
- **Driver build order:** `Build-Driver.ps1` builds ChatpadProtocol first, then ChatpadFilter, via separate MSBuild invocations.

## Next recommended objective

Design a kernel-safe shared protocol interface boundary without connecting it to USB, IOCTL, HID, device callbacks, keyboard injection, mouse injection, or runtime driver behavior.

## Required branch and starting commit

- Branch: `test/protocol-fixtures`
- Starting commit: `969990ca9e532643b750a3fc1820a4c31770fd44`

## Preconditions

- Current state documented above is true (verified by running builds).
- The next agent must NOT begin Phase 2 semantic key mappings yet.
- The next agent must NOT recommend live hardware data or "real Chatpad data."

## Safety restrictions

- Do not install, load, sign, package, deploy, or execute a driver.
- Do not connect the interface boundary to USB, IOCTL, HID, device callbacks, keyboard injection, mouse injection, or runtime driver behavior.
- Do not modify `legacy/`.
- Keep all generated output under ignored `artifacts/`.
- Ensure prohibited commit `6502452` is not an ancestor of HEAD.
- Do not introduce private absolute machine paths into tracked source files.

## Acceptance criteria

- A design artifact describing the shared protocol interface boundary exists (e.g., a header + documentation).
- The interface is defined in a way that is kernel-safe: no user-mode assumptions, no dynamic dispatch, no function-pointer callbacks, no heap allocation requirements beyond what the static library already permits.
- The boundary does not reference USB, IOCTL, HID, device callbacks, keyboard injection, mouse injection, or any runtime driver behavior.
- The design is reviewable as a standalone artifact — the next agent can reason about it without building the driver.

## Commands or files the next agent should inspect first

1. `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.h` — current parser API surface.
2. `src/protocol/ChatpadProtocol/ChatpadKeyboardParser.c` — current parser implementation.
3. `docs/CHATPAD-PROTOCOL.md` — wire-format evidence document.
4. `docs/DECISIONS.md` — all durable decisions to date.
5. `ChatpadWin11.sln` — current solution structure.
6. `tools/Test-RepositorySafety.ps1` — repository safety checks.
