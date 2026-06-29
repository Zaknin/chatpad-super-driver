# Worklog

Append-only. New entries at the top. Corrections are new entries that explain the earlier mistake.

---

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
