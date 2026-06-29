# Project State

This file is updated at every task boundary by the END-OF-TASK ROUTINE.

---

## Current State

| Item | Value |
| --- | --- |
| Branch | `test/protocol-fixtures` (local and remote) |
| HEAD | Task commit `feat: add portable chatpad keyboard parser` (parent `42236aba04b66cc4d74d15ce8520e230a9c0d595`; exact task commit is the commit containing this file) |
| Remote | `origin` → `https://github.com/Zaknin/chatpad-super-driver.git` |

## Toolchain (verified 2026-06-29)

| Component | Version |
| --- | --- |
| OS | Windows 10 Pro 25H2 build 26200.8655 |
| Visual Studio 2022 | Community 17.14.35 (display) / 17.14.37411.7 (install) |
| MSBuild | C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe |
| MSVC v143 | 14.44.35207 |
| Spectre-mitigated libraries (x64/x86) | 14.44.35207 |
| Windows SDK | 10.0.26100.0 |
| WDK | 10.0.26100.0 (matching) |
| KMDF | Headers at 1.35 (latest), x64 libraries available |
| WDK VS integration | Installed; `WindowsKernelModeDriver10.0` target set |
| Build detector | `tools\Get-DriverBuildEnvironment.ps1` exits 0 |

## Build Status

| Configuration | Result | Output verification |
| --- | --- | --- |
| Debug x64 | MSBuild exit 0 | `NotSigned`; SHA-256 `CAA3A0845B16FE34C1871F231E289892FB5213C45F2F425ADC2F160B2BDE2848` |
| Release x64 | MSBuild exit 0 | `NotSigned`; SHA-256 `B7BD6DDBB036020CC36296C29148EF1E9DD1E228FCBF3C80E258EA2BC3CA8703` |
| Protocol parser Debug x64 | Compiler/linker exit 0; native test exit 0 | 85/85 assertions passed; executable SHA-256 `88D20E1150321CD942B66F2372B636AD6420D13F333C8A4397557C8E28A857EF` |

Outputs are confined to `artifacts/bin/x64/<Configuration>/ChatpadFilter/`; intermediates are confined to `artifacts/obj/x64/<Configuration>/ChatpadFilter/`. Logs and environment reports are under `artifacts/logs/` and `artifacts/environment/`. The complete trees are ignored by Git.

## Implementation State

* `src/driver/ChatpadFilter/` — compile-only, nonfunctional KMDF skeleton with `SignMode=Off` for Debug and Release (no INF, CAT, certificate, package, installer, or deployment).
* `ChatpadWin11.sln` — references the skeleton.
* `Directory.Build.props` — enforces Level 4 warnings, TreatWarningAsError, SDL, CompileAsC, Spectre mitigation, x64 preferred architecture, and deterministic builds.
* `tools/Build-Driver.ps1` — runs environment detection, passes absolute directory-valued output paths, builds, proves unsigned output, rejects signing execution, and runs repository safety validation.
* `tools/Get-DriverBuildEnvironment.ps1` — read-only toolchain detector, outputs to `artifacts/environment/`.
* `tools/Test-RepositorySafety.ps1` — rejects modern outputs outside `artifacts/` or ignored `.vs/` paths and preserves the existing legacy, ancestry, packaging, and tracked-binary gates.
* `docs/CHATPAD-PROTOCOL.md` — protocol evidence audit completed. Separates device/wire-format evidence from internal transport structures and treats `0xF0` neutrally as unsupported with exact meaning unresolved.
* `src/protocol/ChatpadProtocol/` — portable C parser accepting exactly five bytes, raw type `0x00`, and modifier values `0x00`-`0x0F`; preserves all five raw bytes and clears caller output before every testable failure.
* `tests/protocol/` — neutral synthetic fixtures and standalone ASCII-only native tests; 85 assertions pass offline in Debug x64.
* `tools/Test-ChatpadProtocolParser.ps1` — canonical direct MSVC x64 compile, link, execute, count, hash, and repository-safety entry point. No Visual Studio project integration exists.

## Historical Baseline

* Fork baseline: `dab6433` — merge of source audit and legacy baseline for Windows 11 port.
* Legacy snapshot preserved: `legacy/source_release_0_0_4a/` (68 files, source-only, no binaries).
* SOXL history cleaned from active branches; backup branches retain it: `backup/win11-port-before-history-cleanup`, `backup/modern-wdk-before-history-cleanup`, `backup/source-audit-before-history-cleanup`.

## Unresolved Blockers

1. The exact meaning of raw type `0xF0`, modifier bit meanings, and Byte 4 remain unresolved.
2. The parser and tests are not integrated into Visual Studio Debug or Release projects.
3. The kernel driver is unchanged, remains nonfunctional, and has no protocol integration.
4. Windows 11 architectural blockers documented in `docs/WIN11-BLOCKERS.md` remain unresolved.

## Safety State

* No driver has been installed, loaded, signed, packaged, deployed, or executed.
* No `.sys`, `.cat`, `.exe`, `.dll`, `.lib`, `.pdb`, `.bin`, or private-key file is tracked by Git.
* `legacy/` is untouched.
* Modern build outputs exist only under ignored `artifacts/`; no stale output directory exists at repository root or beneath `src/driver/ChatpadFilter/`.
* The protocol test executable is generated only beneath `artifacts/bin/x64/Debug/ChatpadProtocolParser/` and accesses no hardware.
* No secrets, machine-specific private information, or certificates in the repository.

## Protocol Evidence Audit

* **Status:** Complete.
* **Authoritative document:** `docs/CHATPAD-PROTOCOL.md`
* **Audit close commit:** `42236aba04b66cc4d74d15ce8520e230a9c0d595`
* **Classification corrections applied:** Virtual mouse message (4 bytes) moved from "Confirmed Packet Forms" (wire) to "Internal Software Structures"; USB control transfer structure (9 bytes) relabeled from "Confirmed Packet Form" to "Internal Software Structures" as USB control request parameters; initialization bytes 0x90/0x00 reclassified from confirmed wire data to C header struct with unresolved completeness.
* **Phase 1 parser:** Implemented as portable C with a raw, policy-labeled API.
* **Protocol tests and fixtures:** Implemented with neutral synthetic data; 85/85 assertions pass offline.
* **Driver remains a nonfunctional unsigned skeleton.**
* **Next phase:** Native Visual Studio Debug and Release project integration plus driver regression builds.
