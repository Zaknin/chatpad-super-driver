# Project State

This file is updated at every task boundary by the END-OF-TASK ROUTINE.

---

## Current State

| Item | Value |
| --- | --- |
| Branch | `build/modern-wdk` (local and remote) |
| HEAD | `f139b218418f69907437d86735a417073fd9eb67` — `build: add modern WDK skeleton and toolchain checks` |
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

| Configuration | Compile+Link | Signing |
| --- | --- | --- |
| Debug x64 | Pass | `TestSign` post-build task exits 1 — `SIGNTASK` error: "No file digest algorithm specified" — signtool invoked without a certificate |
| Release x64 | Pass | Same signing error |

Compiled artifacts are emitted to `x64\Debug\` and `x64\Release\` under the project, but `x64\` is `.gitignore`d. The `artifacts/` tree (under `.gitignore`) holds environment reports and build logs.

## Implementation State

* `src/driver/ChatpadFilter/` — compile-only, nonfunctional KMDF skeleton (no INF, no catalog, no signing config, no package, no deployment).
* `ChatpadWin11.sln` — references the skeleton.
* `Directory.Build.props` — enforces Level 4 warnings, TreatWarningAsError, SDL, CompileAsC, Spectre mitigation, x64 preferred architecture, deterministic builds, outputs under `artifacts/`.
* `tools/Build-Driver.ps1` — orchestrates env detection and MSBuild, writes logs to `artifacts/logs/`.
* `tools/Get-DriverBuildEnvironment.ps1` — read-only toolchain detector, outputs to `artifacts/environment/`.

## Historical Baseline

* Fork baseline: `dab6433` — merge of source audit and legacy baseline for Windows 11 port.
* Legacy snapshot preserved: `legacy/source_release_0_0_4a/` (68 files, source-only, no binaries).
* SOXL history cleaned from active branches; backup branches retain it: `backup/win11-port-before-history-cleanup`, `backup/modern-wdk-before-history-cleanup`, `backup/source-audit-before-history-cleanup`.

## Unresolved Blockers

1. WDK `TestSign` post-build task fails with exit code 1 (no signing certificate configured).
2. Windows 11 architectural blockers documented in `docs/WIN11-BLOCKERS.md` — unchecked buffer copies, null-deref risk, use-after-free patterns, etc.

## Safety State

* No driver has been installed, loaded, packaged, deployed, or executed.
* No `.sys`, `.cat`, `.exe`, `.dll`, `.lib`, `.pdb`, `.bin`, or private-key file is tracked by Git.
* `legacy/` is untouched in this branch.
* Build outputs are under `.gitignore`d `x64/`, `artifacts/`, and `src/driver/ChatpadFilter/x64/`.
* No secrets, machine-specific private information, or certificates in the repository.
