# Project State

*Last updated: 2026-06-30T01:21+04:00*

## Current state

- **Branch:** `analysis/device-specific-install-recovery-design`.
- **Starting checkpoint:** `93cc84d94ca3a262ac1c024abd7b1affcd08a349`.
- **Expected task commit:** `docs: design device filter install recovery`.
- **Recovery design:**
  `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md` specifies an exact-ID
  extension INF direction, declarative lower-filter placement, package
  identity ledger, read-only baseline and backup capture, staged authorization,
  normal/Safe Mode/offline rollback, controller preservation, and hard stops.
- **Package boundary:** no INF, CAT, certificate, package, service installation,
  signing, Driver Store mutation, registry mutation, device restart, load, or
  hardware action exists or was performed. Future package creation, signing,
  staging, attachment/loading, and interaction are separate gates.
- **Preserved base:** the design keeps `xusb22.inf`/`xusb22` as the Microsoft
  base/function driver and prohibits class filters, direct filter-value writes,
  binding replacement, and security weakening.
- **Verified formatter:** Debug and Release compile-only checks pass with
  static libraries only. Current formatter hashes are
  `D7D9357B1C3E969875E51BBE7C71F367D30A7B7E72BE438D8DD2B8848DB8FE8B`
  and `8337944B935E4323AEE8DA746BCB4E7348188C0C86448C81688B1DF23B4B0469`.
- **Verified driver:** Debug and Release builds pass and remain unsigned;
  current hashes are
  `c3a9c65869bedfd0bd5f2231d22181100a9b1d63177c5a7c410c6be8d40f70a0`
  and `7a6f9fd5c8fbe2699d101dc7765203a113ef7a4e8b82c2c7130035ddc6c6dd50`.
  Linker evidence contains only `ChatpadFilterLifecycle.obj`, `driver.obj`,
  `device.obj`, and WDK system libraries.
- **Isolation and safety:** formatter and portable projects remain absent from
  the driver project/dependency/link boundary; repository safety passes;
  `legacy/` is unchanged; all generated output remains ignored under
  `artifacts/`.

## Unresolved blockers

- No Windows 11 default-control-pipe access is proven.
- Control-IN response bytes, acknowledgement, readiness, retry, timeout, and
  activation success remain unresolved.
- No WDF target/request creation, request formatting/submission, completion,
  cancellation, endpoint, pipe, or continuous-input behavior exists.
- The recovery specification is not yet independently reviewed against an
  actual signed package or demonstrated on a noncritical test system; Gate F
  is not operationally passed.
- No INF, signing, package, deployment, installation, load, or hardware
  authorization exists.
