# Next Task

## Current State

* Branch: `test/protocol-fixtures`
* HEAD: task commit `docs: close protocol evidence audit` (the commit containing this file; parent `b012f2501e9255f87baf488b0c9d0e0918e7062b`).
* Toolchain: VS 2022 17.14.35, MSVC 14.44.35207, SDK/WDK 10.0.26100.0, KMDF 1.35, WDK integration ready.
* Build: Debug x64 and Release x64 both exit 0, produce `NotSigned` `.sys` files, and execute no signing task.
* Outputs: modern generated files exist only beneath ignored `artifacts/`; repository safety passes.
* Protocol evidence audit: complete. Authoritative document is `docs/CHATPAD-PROTOCOL.md` with Section A (wire-format evidence: 5-byte keyboard packet) and Section B (internal software structures). Classification corrections applied for virtual mouse, USB control transfer parameters, init bytes, and Byte 4.
* No parser implementation exists. No protocol tests or fixtures exist.
* Driver remains a nonfunctional unsigned skeleton.
* `legacy/` untouched.

## Next Recommended Objective

Implement the portable five-byte keyboard parser and minimal synthetic fixtures from the confirmed/proposed boundary in `docs/CHATPAD-PROTOCOL.md`, without Visual Studio solution integration yet.

Specifically:

1. Read Section A of `docs/CHATPAD-PROTOCOL.md` to identify the only confirmed wire-format packet: the 5-byte keyboard packet (Byte0=0x00 data, Byte1=modifier bits, Byte2-3=scan codes, Byte4=unknown).
2. Read the "Proposed Phase 1 Parser Boundary" section to identify the conservative validation rules (reject Byte0=0xF0, reject packets <5 bytes, reject invalid modifier bits as project policy).
3. Implement a pure-C or C++ parser function that accepts a 5-byte buffer and returns structured keyboard state, with no dependency on kernel-mode or Windows-specific headers.
4. Create minimal synthetic fixtures from the "Proposed Fixture Inventory" in the protocol document, each tagged with its source evidence line reference.
5. Keep the KMDF skeleton unchanged. No Visual Studio solution integration until later.

## Required Branch and Starting Commit

* Branch: `test/protocol-fixtures`
* Starting commit: `b012f2501e9255f87baf488b0c9d0e0918e7062b` (current HEAD)

## Preconditions

* Confirm `origin/test/protocol-fixtures` matches the local task commit and repository safety passes.
* Read `docs/CHATPAD-PROTOCOL.md` Section A and "Proposed Phase 1 Parser Boundary."
* Do not modify any file under `legacy/`.
* Do not execute any file from `legacy-source/` or any generated `.sys`.
* Do not install, load, sign, package, deploy, or execute a driver.
* Do not commit generated binaries, `.pdb`, `.tlog`, or build logs.

## Safety Restrictions

* Never modify `legacy/`.
* No device access or live USB/HID interaction.
* No INF, CAT, certificate, package, installer, deployment project, driver signing, or system configuration changes.
* Keep generated outputs under ignored `artifacts/` and preserve all current repository safety gates.

## Acceptance Criteria

* Parser handles valid 5-byte keyboard packets (Byte0=0x00, valid modifiers, scan codes).
* Parser rejects invalid packets per the Proposed Phase 1 policy (Byte0=0xF0, length <5, invalid modifier bits).
* Fixtures are traceable to source evidence and contain no executable legacy payload.
* Existing Debug x64 and Release x64 compile-only builds still exit 0, remain `NotSigned`, and produce outputs only under `artifacts/`.
* Repository safety passes and no generated binary or log is tracked.

## Commands the Next Agent Should Inspect First

1. `git branch --show-current`, `git rev-parse HEAD`, `git status --short --branch`, and `git log --oneline -5`.
2. `tools/Test-RepositorySafety.ps1`.
3. `docs/CHATPAD-PROTOCOL.md` Section A ("Device or Wire-Format Evidence") and "Proposed Phase 1 Parser Boundary."
4. `docs/CHATPAD-PROTOCOL.md` "Proposed Fixture Inventory" for fixture data.
