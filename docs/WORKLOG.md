# Worklog

Append-only. New entries at the top. Corrections are new entries that explain the earlier mistake.

---

## 2026-06-29 06:51 UTC — Disable signing and contain modern WDK outputs

**Objective:** Make the compile-only modern WDK skeleton build Debug x64 and Release x64 successfully without signing, contain every modern generated output beneath repository-root `artifacts/`, strengthen repository safety validation, update continuity records, and push `build/modern-wdk`.

**Starting branch and commit:** `build/modern-wdk`, `8ca4e2ec61210e40059238128ba81cbfce4223f8`.

**Investigation:**

* Confirmed the required branch, exact starting commit, clean ancestry gate (`6502452` is not an ancestor), and three pre-existing modified files from the interrupted Hermes attempt.
* Preserved and reviewed the partial edits. `SignMode=Off` was valid; wrapper output strings were incomplete; `ObjectFileName=$(IntDir)\` produced a spurious `+` intermediate directory.
* Verified the WDK import chain: `WindowsDriver.KernelMode.props` enables test signing for KMDF projects, and `WindowsDriver.Common.targets` defaults an empty `SignMode` to `TestSign`, then runs `DriverTestSign` after link. That default caused the original `SIGNTASK` failure.
* Verified the D8036 failure came from `/Fo` receiving an intermediate path without a trailing directory separator, so cl.exe interpreted it as one object filename while compiling two source files.
* Evaluated Debug and Release properties with MSBuild and confirmed `SignMode=Off` plus absolute `OutDir` and `IntDir` paths ending in a separator.
* Inspected every authorized stale-output location; none existed, so no stale directory needed removal.

**Files modified:**

* `Directory.Build.props`
* `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
* `tools/Build-Driver.ps1`
* `tools/Test-RepositorySafety.ps1`
* `docs/BUILDING.md`
* `src/driver/ChatpadFilter/README.md`
* `docs/TOOLCHAIN.md`
* `docs/PROJECT-STATE.md`
* `docs/DECISIONS.md`
* `docs/WORKLOG.md`
* `docs/NEXT-TASK.md`

**Implementation details:**

* Set WDK `SignMode` to `Off` in both `Debug|x64` and `Release|x64` configuration property groups.
* Removed shared props output-path definitions and made the wrapper compute absolute configuration-specific paths with `System.IO.Path` APIs.
* Preserved trailing directory separators in `OutDir` and `IntDir`, passed them through an argument array, and verified actual compiler `/Fo` values remained directory-valued.
* Added guarded cleanup limited to the selected `artifacts/bin/...` and `artifacts/obj/...` directories after confirming resolved paths are inside `artifacts/` and contain no tracked files.
* Added exact output-count, Authenticode `NotSigned`, SHA-256, diagnostic signing-execution, and post-build safety checks.
* Tightened repository safety checks for all named root/project output directories while retaining ignored historical/reference input roots such as `legacy-source/`.

**Commands and validation:**

* `tools/Get-DriverBuildEnvironment.ps1` — PASS, exit 0; VS 2022 17.14.35, MSVC 14.44.35207, SDK/WDK 10.0.26100.0, Spectre x64/x86, KMDF, and WDK integration ready.
* Initial tightened `tools/Test-RepositorySafety.ps1` run — FAIL because it classified pre-existing ignored historical binaries in `legacy-source/` as modern outputs. Corrected the distinction without deleting or modifying the reference tree; repeated pre-build and post-build runs passed.
* Final `tools/Build-Driver.ps1 -Configuration Debug -Platform x64` — PASS, MSBuild exit 0; `artifacts/logs/build-debug-x64-20260629T065511Z.log`.
* Final Debug output — `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys`; Authenticode `NotSigned`; SHA-256 `CAA3A0845B16FE34C1871F231E289892FB5213C45F2F425ADC2F160B2BDE2848`.
* Final `tools/Build-Driver.ps1 -Configuration Release -Platform x64` — PASS, MSBuild exit 0; `artifacts/logs/build-release-x64-20260629T065513Z.log`.
* Final Release output — `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys`; Authenticode `NotSigned`; SHA-256 `B7BD6DDBB036020CC36296C29148EF1E9DD1E228FCBF3C80E258EA2BC3CA8703`.
* Both diagnostic logs show `SignMode = Off`, six signing targets skipped, zero active signing evidence, and `/Fo` ending with a directory separator.
* One read-only diagnostic extraction one-liner had a PowerShell parser error; the corrected extraction command completed and reported zero active signing evidence for both logs.
* Repository safety, legacy diff, modern prohibited-file scan, generated-output location scan, tracked/staged binary/log scan, and `git diff --check` — PASS.

**Generated artifacts:** Ignored outputs beneath `artifacts/bin/`, `artifacts/obj/`, environment reports beneath `artifacts/environment/`, and diagnostic logs beneath `artifacts/logs/`. None are tracked or staged.

**Commit and push:** Commit message `build: disable signing and contain WDK outputs`; the exact commit is the commit containing this entry and is pushed only to `origin/build/modern-wdk`.

**Remaining risks and limitations:** The driver remains a compile-only, nonfunctional skeleton with no protocol, IOCTL, USB, HID, keyboard, or mouse behavior. It has no INF, CAT, certificate, package, installer, or deployment configuration and must not be installed or loaded.

## 2026-06-29 08:00 UTC — Establish persistent project continuity workflow

**Objective:** Create AGENTS.md, docs/PROJECT-STATE.md, docs/DECISIONS.md, docs/NEXT-TASK.md, and docs/WORKLOG.md; verify every stated fact against the real repository; commit; push `build/modern-wdk`.

**Starting branch and commit:** `build/modern-wdk`, `f139b218418f69907437d86735a417073fd9eb67`.

**Investigation:**
* Confirmed branch, HEAD, status, and remote (`origin` → `https://github.com/Zaknin/chatpad-super-driver.git`).
* Read all existing `docs/` files: BUILDING.md, LEGACY-ARCHITECTURE.md, PORTING-PLAN.md, SOURCE-INVENTORY.md, TOOLCHAIN.md, WIN11-BLOCKERS.md.
* Inspected `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`, `Directory.Build.props`, `ChatpadWin11.sln`, `tools/Build-Driver.ps1`.
* Read `.gitignore` and confirmed no binaries are staged.
* Verified build log at `artifacts/logs/build-debug-x64-20260627T164649Z.log` — compile+link succeed, `TestSign` exits 1 with `SIGNTASK : SignTool error : No file digest algorithm specified`.
* Read environment reports at `artifacts/environment/driver-build-environment.txt` and `artifacts/verification/driver-build-environment.txt` — VS 17.14.35, MSVC 14.44.35207, SDK+WDK 10.0.26100.0, KMDF 1.35, WDK integration present.
* Confirmed Git history: `f139b21` is the modern-wdk HEAD; `dab6433` is the fork baseline merge; backup branches retain SOXL history.
* Confirmed `legacy/` contains 68 source-only files; no binaries tracked.
* Confirmed no files are modified and none are staged.

**Files created/modified:**
* Created `AGENTS.md` — mandatory workflow protocol for all agents.
* Created `docs/PROJECT-STATE.md` — current truth snapshot.
* Created `docs/WORKLOG.md` — this file.
* Created `docs/DECISIONS.md` — durable decisions.
* Created `docs/NEXT-TASK.md` — next continuation point.
* Updated `docs/TOOLCHAIN.md` — corrected stale machine-status section (version 17.14.34 → 17.14.35, WDK now detected, signing issue documented).

**Commands and tests run:**
* `git branch --show-current`, `git log --oneline -5`, `git status --short`, `git log --all --oneline --graph --decorate`, `git diff --stat`, `git diff --cached --shortstat`.
* Inspected all project files, build logs, environment reports, vcxproj, props, sln.
* Ran `grep` on build log for signing errors.

**Results:**
* All facts verified against actual repo state.
* No staged or committed binaries.
* Documentation was stale (TOOLCHAIN.md listed old version and missing WDK) — corrected.
* All continuity files written per AGENTS.md format rules.

**Next task:** Disable WDK signing entirely and contain all generated outputs under `artifacts/`. See `docs/NEXT-TASK.md`.

---

## 2026-06-29 12:00 UTC — Close protocol evidence audit

**Objective:** Validate `docs/CHATPAD-PROTOCOL.md` against the 8-point classification criteria; correct where evidence did not support wire-format claims; update all continuity files; verify repository safety; commit and push `test/protocol-fixtures`.

**Starting branch and commit:** `test/protocol-fixtures`, `b012f2501e9255f87baf488b0c9d0e0918e7062b`.

**Investigation:**

* Verified branch, HEAD, clean ancestry (`6502452` not an ancestor), and prior commit `docs: document chatpad protocol evidence`.
* Read full `docs/CHATPAD-PROTOCOL.md` (658 lines), `docs/PROJECT-STATE.md`, `docs/NEXT-TASK.md`, `docs/WORKLOG.md`, `docs/DECISIONS.md`.
* Inspected safety tools: `tools/Get-DriverBuildEnvironment.ps1` (exit 0, READY), `tools/Test-RepositorySafety.ps1` (PASS).

**Classification corrections applied:**

1. **Virtual Mouse Message (4 bytes)** — Moved from "Confirmed Packet Forms" (Section A, wire) to Section B (Internal Software Structures) with explicit note that this is a virtual device sent to Windows, not the chatpad itself. The document's own line 249 stated this but the header placement contradicted it.
2. **USB Control Transfer Structure (9 bytes base)** — Relabeled from "Confirmed Packet Form" to "Internal Software Structures" with explicit note that these are USB control request parameters (setup packet fields), not a serialized wire frame from the device.
3. **Initialization bytes 0x90/0x00** — Reclassified from "Confirmed" wire data to "C header struct" with unresolved completeness (whether a complete command, partial payload, or isolated constants).
4. **Byte 4** — Clarified that it is part of the wire packet (present in the 5-byte form processed by `HandleChatpadData`) but its semantic purpose is unknown — moved from ambiguous "Confirmed" description to "Unresolved" with explicit classification note.
5. **Proposed Phase 1 Parser Boundary** — Added explicit header marking these as "Project policy — not proven device requirements" to prevent policy from being read as confirmed protocol.

**Files modified:**
* `docs/CHATPAD-PROTOCOL.md` — restructured with Sections A (wire) and B (internal), corrected 4 classification issues, added policy label to Phase 1 boundary.
* `docs/PROJECT-STATE.md` — updated branch, HEAD, implementation state, added Protocol Evidence Audit section.
* `docs/WORKLOG.md` — appended this entry.

**Commands and validation:**
* `git branch --show-current` → `test/protocol-fixtures`
* `git rev-parse HEAD` → `b012f2501e9255f87baf488b0c9d0e0918e7062b`
* `git rev-parse 6502452` → `6502452b6cadaf1e7cb413e4a6662ef3d97d3e8e`; `git merge-base --is-ancestor 6502452 HEAD` → exit 1 (not an ancestor)
* `tools/Get-DriverBuildEnvironment.ps1` → PASS, exit 0, READY
* `tools/Test-RepositorySafety.ps1` → PASS, exit 0
* `git diff --check` → PASS (LF→CRLF warning only, no whitespace errors)
* `git diff --name-only -- legacy/` → empty (no legacy files modified)
* `git diff --stat` → 1 file changed: `docs/CHATPAD-PROTOCOL.md` (+127/-169)

**Safety confirmation:**
* No file beneath `legacy/` changed.
* Commit `6502452` is not an ancestor of HEAD.
* `git diff --check` passes.
* No binary, log, build output, private path, INF, CAT, certificate, package, service, or deployment file added.
* No hardware or device access occurred.

**Remaining risks and limitations:** No parser implementation exists. No protocol tests or fixtures exist. The driver remains a nonfunctional unsigned skeleton. Byte 4 purpose, exact modifier bit values, and complete initialization sequence remain unresolved.
