# Project State

*Last updated: 2026-06-30 (production owner ordinary initialization)*

## Current state

- **Branch:** `feature/offline-kmdf-owner-embedding-init`.
- **Starting checkpoint:** `41172d7f2877509a16f3b58abf0f81d231cbabaf`,
  `docs: complete production linkage evidence`.
- **Expected commit:** the commit containing this state uses subject
  `driver: initialize production request owner`.
- **Checkpoint record:**
  [Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
- **Evidence manifest:**
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json).
- **Production context:** `driver.h` includes the authoritative KMDF
  request-owner header and embeds exactly one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`.
- **Initialization:** `ChatpadEvtDeviceAdd` calls the ordinary initializer and
  immediate pre-object validator exactly once after scalar context setup and
  before lifecycle initialization. Failures stop before lifecycle state is
  initialized.
- **Project linkage:** the existing context static-library project reference
  is unchanged. `ChatpadFilter.vcxproj` compiles the portable request-owner
  model source directly as a WDK object and adds only the required include
  roots.
- **Owner baseline:** signature/version and pure model are initialized;
  initialization mask is exactly `MODEL_READY`; fixed two-byte arrays are
  zero; all WDF handles are null; `OWNER_READY`, `FAULTED`, creation bits,
  lifecycle obligations, and active operation state are absent.
- **Build/toolchain:** Visual Studio Community 2022 17.14.35, MSVC
  14.44.35207, SDK/WDK 10.0.26100.0, KMDF 1.15. Debug and Release context,
  driver, full-solution, semantic, kernel compatibility, and WDF formatter
  checks pass.
- **Regressions:** request-owner model `5002/5002`, protocol `610/610`,
  transport `186/186`, lifecycle `109/109`, and control setup `141/141` in
  Debug and Release.
- **Binary state:** Debug driver is 20,992 bytes, SHA-256
  `FB9E9DD550BEF64B99BFAA74810A953A5B0DC12BB455869D7787FB657B565B8F`;
  Release is 14,336 bytes, SHA-256
  `9EA24A8B6BEB2796B9A1FF55A04486C8E3EB59B94A191AEA6F50B322531CBCE3`.
  Both are `NotSigned`. No creation/rollback/orchestration symbols or
  forbidden object-management/target/request imports are exposed.
- **Safety:** no orchestration, WDF object creation/deletion, target/request
  operation, D0/removal change, signing, package, staging, installation,
  loading, Windows mutation, device enumeration, or hardware interaction was
  performed.

## Unresolved blockers

- The production owner-initialization checkpoint still requires an
  independent read-only audit.
- Dormant orchestration invocation remains unauthorized.
- Normal teardown, active-operation rundown, target discovery, request
  operations, D0 coordination, signing, staging, installation, loading, and
  hardware validation remain separate gates.
- No usable production driver exists.
