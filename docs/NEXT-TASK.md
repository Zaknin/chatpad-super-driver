# Next Task

## Current continuation point

Branch `analysis/device-specific-install-recovery-design` contains the
documentation-only device-specific installation and recovery design. The task
commit subject is `docs: design device filter install recovery`; use the final
commit reported for this task and verify it equals
`origin/analysis/device-specific-install-recovery-design` before branching.

The design selects a future exact-ID extension INF with declarative lower
filter placement while preserving `xusb22`. It defines staged authorization,
package identity, baseline capture, normal/Safe Mode/offline rollback, security
policy, controller-preservation checks, and abort criteria. No INF or system
change exists.

## Recommended objective

Create and statically validate an offline-only extension-INF package scaffold
for `USB\VID_045E&PID_028E` that implements the reviewed design. This requires
new explicit authorization because the current task did not authorize INF or
package creation.

The task must stop after source/package validation. It must not sign, stage,
install, load, restart, enumerate, open, or interact with any device.

## Required branch and starting commit

- Create a dedicated feature branch from the final
  `analysis/device-specific-install-recovery-design` commit.
- Require exact equality between local starting commit and the reported remote
  commit, with a clean tree.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, all continuation documents,
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`, both Windows 11
  architecture documents, `docs/BUILDING.md`, and the connected-device
  inventory.
- Obtain explicit user authorization to create an INF/package scaffold.
- Verify the current unsigned driver and formatter remain isolated and that
  repository safety passes.
- Confirm current Microsoft INF/extension/filter rules from primary sources.

## Safety restrictions

- Offline source and static package validation only.
- No certificate creation/import, catalog signing, test signing, production
  signing, trust-store change, Secure Boot/HVCI/BCD change, staging, Driver
  Store or registry mutation, installation, loading, device restart, Device
  Manager, DevCon, PnPUtil mutation, DISM mutation, elevation, or hardware
  access.
- No WDF target/request/queue/interface/timer/work-item or transport runtime
  implementation.
- No `legacy/` or external-skill modification.

## Acceptance criteria

- The extension INF matches only `USB\VID_045E&PID_028E` and uses a stable
  `ExtensionId`.
- It adds a non-associated demand/PnP filter service through
  `DDInstall.Filters`/`AddFilter` with `FilterPosition=Lower` and preserves
  `xusb22` as the base/function driver.
- It has no class filter, direct `UpperFilters`/`LowerFilters` write, base
  binding replacement, co-installer, custom action, or executable installer.
- Static INF/package validation passes without signing or machine mutation.
- Generated validation output stays under ignored `artifacts/`.
- Existing formatter, driver isolation, unsigned state, and repository safety
  remain unchanged.

## Inspect first

- `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`
- `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`
- `docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md`
- `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`
- `docs/BUILDING.md`
- `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`
- `tools/Test-RepositorySafety.ps1`
