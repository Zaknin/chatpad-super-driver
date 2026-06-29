# Next Task

## Current State

* Branch: `build/modern-wdk`
* HEAD: task commit `build: disable signing and contain WDK outputs` (the commit containing this file; parent `8ca4e2ec61210e40059238128ba81cbfce4223f8`).
* Toolchain: VS 2022 17.14.35, MSVC v143 14.44.35207, SDK+WDK 10.0.26100.0, KMDF 1.35, WDK VS integration present.
* Build: Debug x64 and Release x64 both exit 0, produce `NotSigned` `.sys` files, and execute no signing task.
* Outputs: modern generated files exist only beneath ignored `artifacts/`; repository safety passes.
* No driver installed, loaded, signed, packaged, deployed, or executed.
* `legacy/` untouched.

## Next Recommended Objective

Implement Phase 1 protocol fixtures and a user-mode parser test harness from the preserved source evidence, without adding kernel behavior or opening the driver installation/package boundary.

Specifically:

1. Extract non-executable packet fixtures from preserved source comments and user-mode parsing paths into `tests/fixtures/`.
2. Add user-mode-only parser tests for packet length, endpoint identity, filter mode, and malformed inputs.
3. Keep the KMDF skeleton unchanged except for build-system integration strictly required to run user-mode tests.
4. Document every fixture's source evidence and avoid executing or trusting any ignored legacy binary.

## Required Branch and Starting Commit

* Branch: create `test/protocol-fixtures` from `origin/build/modern-wdk`.
* Starting commit: the pushed `build: disable signing and contain WDK outputs` commit; obtain and record its exact hash with `git rev-parse origin/build/modern-wdk` before editing.

## Preconditions

* Confirm `origin/build/modern-wdk` matches the local task commit and repository safety passes.
* Read `docs/PORTING-PLAN.md`, `docs/LEGACY-ARCHITECTURE.md`, `docs/WIN11-BLOCKERS.md`, and the cited sanitized legacy source files before designing fixtures.
* Do not modify any file under `legacy/`.
* Do not execute any file from `legacy-source/` or any generated `.sys`.
* Do not install, load, sign, package, deploy, or execute a driver.
* Do not commit generated binaries, `.pdb`, `.tlog`, or build logs.

## Safety Restrictions

* Never modify `legacy/`.
* User-mode, offline tests only; no device access or live USB/HID interaction.
* No INF, CAT, certificate, package, installer, deployment project, driver signing, or system configuration changes.
* Keep generated outputs under ignored `artifacts/` and preserve all current repository safety gates.

## Acceptance Criteria

* Fixtures are traceable to source evidence and contain no executable legacy payload.
* User-mode tests cover valid and malformed packet cases and pass without administrator rights or device access.
* Existing Debug x64 and Release x64 compile-only builds still exit 0, remain `NotSigned`, and produce outputs only under `artifacts/`.
* Repository safety passes and no generated binary or log is tracked.

## Commands the Next Agent Should Inspect First

1. `git branch --show-current`, `git rev-parse HEAD`, `git status --short --branch`, and `git log --oneline -5`.
2. `tools/Test-RepositorySafety.ps1`.
3. `docs/PORTING-PLAN.md` Phase 1 and `docs/WIN11-BLOCKERS.md`.
4. `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h` lines 21-90.
5. `legacy/source_release_0_0_4a/filter/chatpad_filter.h` lines 66-76 and 147-174.
6. Existing test/build conventions, if any, before selecting a user-mode test framework.
