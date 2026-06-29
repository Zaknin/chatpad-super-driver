# Next Task

## Current State

* Branch: `build/modern-wdk`
* HEAD: `f139b218418f69907437d86735a417073fd9eb67`
* Toolchain: VS 2022 17.14.35, MSVC v143 14.44.35207, SDK+WDK 10.0.26100.0, KMDF 1.35, WDK VS integration present.
* Build: Debug and Release compile and link successfully. WDK `TestSign` post-build task fails with exit code 1.
* No driver installed, loaded, packaged, deployed, or executed.
* `legacy/` untouched.

## Next Recommended Objective

Disable WDK signing completely and contain all generated outputs under `artifacts/`.

Specifically:
1. Investigate why the WDK `TestSign` task runs even though no signing certificate is configured.
2. Determine the minimal project or property change needed to skip the signing step entirely (e.g., `SignMode=Disabled`, `SignToolWinObjCEnabled=false`, or equivalent in the vcxproj / Directory.Build.props / WDK MSBuild targets).
3. Ensure that all build outputs (`.sys`, `.pdb`, `.obj`, `.tlog`, intermediate files) go under `artifacts/bin/` and `artifacts/obj/` (already configured via `Directory.Build.props` `BaseOutputPath`/`BaseIntermediateOutputPath`) and are not emitted under the project directory tree where they risk being committed.
4. Verify that a clean Debug build and a clean Release build both complete with MSBuild exit code 0, producing outputs only under `artifacts/`.

## Required Branch and Starting Commit

* Branch: `build/modern-wdk`
* Starting commit: `f139b218418f69907437d86735a417073fd9eb67`

## Preconditions

* Toolchain must remain as-is (VS 2022, SDK 10.0.26100.0, WDK 10.0.26100.0, KMDF 1.35).
* Do not modify any file under `legacy/`.
* Do not install, load, sign, package, deploy, or execute any driver.
* Do not commit generated binaries, `.pdb`, `.tlog`, or build logs.

## Safety Restrictions

* Never modify `legacy/`.
* Never load, install, or execute a driver on the host machine.
* Keep all generated outputs under the `.gitignore`d `artifacts/` tree.
* Do not commit secrets, certificates, or machine-specific paths.

## Acceptance Criteria

* MSBuild exits 0 for both Debug x64 and Release x64.
* No output under `src/driver/ChatpadFilter/x64/` after a clean build.
* All `.sys`, `.pdb`, `.obj`, `.tlog`, and intermediate files appear only under `artifacts/bin/` and `artifacts/obj/`.
* `git status` shows no build artifacts staged or committed.

## Commands the Next Agent Should Inspect First

1. `git log --oneline -3` — confirm starting state.
2. `cat docs/PROJECT-STATE.md` — full state snapshot.
3. `cat docs/AGENTS.md` — workflow rules.
4. `cat src/driver/ChatpadFilter/ChatpadFilter.vcxproj` — current project config.
5. `cat Directory.Build.props` — current property overrides.
6. `grep -r "SignMode\|TestSign\|DriverSign" src/driver/ChatpadFilter/ --include="*.vcxproj" --include="*.props" --include="*.targets"` — locate any signing configuration.
7. `cat artifacts/logs/build-debug-x64-20260627T164649Z.log` — full build log showing the failure.
8. `cat .gitignore` — confirm artifact exclusion rules.
