# Project State

*Last updated: 2026-06-29T14:35Z*

## Current state

- **Branch:** `test/protocol-fixtures` (tracking `origin/test/protocol-fixtures`)
- **HEAD:** `d6a5c7e01b644871951aa3cfbb410cca92cdb01a` (continuity repair committed and pushed)
- **ChatpadProtocol static-library project:** `src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj` — builds x64 Debug and Release under `artifacts/`
- **ChatpadProtocolTests native test project:** `tests/protocol/ChatpadProtocolTests.vcxproj` — builds x64 Debug and Release under `artifacts/`
- **Parser direct tests:** 85/85 passed
- **Integrated Debug tests:** 85/85 passed (MSBuild exit 0, test exit 0)
- **Integrated Release tests:** 85/85 passed (MSBuild exit 0, test exit 0)
- **Driver Debug build:** exit 0, NotSigned, no SignTool execution
- **Driver Release build:** exit 0, NotSigned, no SignTool execution
- **Build tools:** MSBuild 17.14.40, MSVC v143, KMDF 1.15, Windows SDK 10.0.26100.0
- **Unresolved blockers:** None
- **Safety state:** PASS
  - All build artifacts under `artifacts/` (ignored by Git)
  - Driver is NotSigned (verified via certutil)
  - No SignTool execution detected
  - `legacy/` matches `origin/win11-port`
  - Prohibited commit `6502452` not an ancestor of HEAD

## Dependency relationship

- `ChatpadFilter` (driver) builds `ChatpadProtocol` (static library) first via explicit build order in `Build-Driver.ps1`.
- `ChatpadFilter` does NOT link `ChatpadProtocol.lib` — it remains a nonfunctional skeleton.
- `ChatpadProtocolTests` uses a native ProjectReference to `ChatpadProtocol` for library linkage, replacing the previous hardcoded `AdditionalDependencies`/`AdditionalLibraryDirectories` approach.

## Implementation state

- ChatpadProtocol: Phase 1 raw parser — neutral, policy-labeled, five-byte wire format only.
- ChatpadFilter: Nonfunctional skeleton — `driver.c`, `device.c`, `driver.h` present. No USB/IOCTL/HID/device callback/injection wiring yet.
- No install, load, package, signing, deployment, or hardware test has occurred.
