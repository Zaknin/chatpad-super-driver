# Next Task

## Current continuation point

Branch `feature/wdf-control-setup-formatter` contains the isolated compile-only
WDK formatter, its formatter-only kernel compile check, Debug/Release guard
validation, unchanged native regressions, existing kernel compatibility, and
unsigned driver regressions. The task commit subject is
`build: add compile-only wdf control setup formatter`; use the final commit
reported for this task and verify it equals
`origin/feature/wdf-control-setup-formatter` before branching.

The formatter creates no WDF object and is not linked into `ChatpadFilter`.
Default-control access and all runtime transport behavior remain unproven.

## Recommended objective

Design a reversible, device-specific lower-filter installation and recovery
specification for `USB\VID_045E&PID_028E`. Cover INF placement semantics,
driver-store and registry backup/export steps, controller-preservation checks,
Safe Mode and command-line removal, test-signing and HVCI implications,
rollback verification, and explicit authorization gates.

This is a documentation and design task only. Do not create an INF or perform
installation, signing, loading, device access, or hardware changes.

## Required branch and starting commit

- Create a dedicated design branch from the final
  `feature/wdf-control-setup-formatter` commit reported and pushed by this task.
- Require exact equality between local starting commit and the reported remote
  commit, with a clean tree.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, all continuation documents, both Windows 11
  architecture documents, `docs/BUILDING.md`, and existing safety rules.
- Verify formatter and driver isolation from projects, solution dependencies,
  source lists, and linker inputs.
- Inspect current documented PnP topology and attachment evidence without
  querying or changing the live controller.
- Treat exact recovery and controller-preservation proof as hard gates before
  any later implementation or live task.

## Safety restrictions

- Documentation/design changes only.
- No INF, CAT, certificate, service, package, installer, deployment, signing,
  test-signing setting, BCD setting, registry mutation, driver-store mutation,
  installation, loading, device action, Device Manager action, Safe Mode
  reboot, elevation, or hardware access.
- No controller enumeration, query, reset, disable/enable, disconnect,
  reconnect, or transfer.
- No WDF target/request/queue/interface/timer/work-item or transport runtime
  implementation.
- No `legacy/` or external-skill modification.

## Acceptance criteria

- The design targets only `USB\VID_045E&PID_028E` and explicitly rejects
  class-wide filter placement.
- Exact backup/export, install-order, rollback, Safe Mode, command-line removal,
  and post-recovery verification procedures are specified without execution.
- Test-signing, Secure Boot, Memory Integrity/HVCI, and unsigned-driver failure
  implications are documented without changing system state.
- Controller-preservation checks and hard abort criteria are explicit.
- Separate authorization gates cover future INF creation, signing, installation,
  loading, and any device interaction.
- Existing compile-only formatter and unsigned driver state remain unchanged.

## Inspect first

- `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`
- `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
- `docs/WINDOWS11-CONNECTED-DEVICE-INVENTORY.md`
- `docs/WIN11-BLOCKERS.md`
- `docs/PROJECT-STATE.md`
- `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
- `src/transport/ChatpadWdfControlSetup/README.md`
- `tools/Build-Driver.ps1`
