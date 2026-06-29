# Project State

*Last updated: 2026-06-30T01:44+04:00*

## Current state

- **Branch:** `feature/offline-extension-inf-prototype`.
- **Starting checkpoint:** `08ad46584b62ae159971529a3a965d6ed6086146`.
- **Expected task commit:** `build: add offline extension inf prototype`.
- **Prototype:** exact source path
  `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf`; adjacent
  README states `OFFLINE PROTOTYPE — DO NOT INSTALL`.
- **Identity and target:** Extension class, stable `ExtensionId`
  `{69E7CCD7-7011-4059-95D4-618974E126DD}`, AMD64 Windows 11 build 22000+,
  exact hardware ID `USB\VID_045E&PID_028E`.
- **Filter/service model:** declarative `AddFilter=ChatpadFilter`,
  `FilterPosition=Lower`, no named level; non-associated kernel PnP service
  `ChatpadFilter`, demand start, DIRID 13, KMDF 1.15. The INF does not claim
  `xusb22` function-driver ownership.
- **Catalog boundary:** required future identity
  `ChatpadFilterExtension.cat` is declared; no CAT exists or was generated.
- **Static validation:** installed x64 WDK 10.0.26100.0 `InfVerif`
  10.0.26100.6584 passes `/k /v`, `/k /info`, and annotated `/k /l`; semantic
  guards pass. INF SHA-256 is
  `7E752EDAFDB252AF746C2AE6A9EFB3032A077A23FEB39C064D0E2C30700D11CE`.
- **Driver regression:** Debug and Release x64 builds pass and remain
  `Authenticode.NotSigned`. SHA-256 values are
  `f3b7123c783776b2f49296b03b5b54e66d65f14a4e71cce884a8a705d8d4c45b`
  and `00a9e8689114886c04b6c45e86603be1257b42e6215b76ce41d3a721f28c5f6a`.
- **Isolation:** `ChatpadFilter.vcxproj`, the solution, build wrapper, and
  driver outputs contain no prototype INF reference. Inf2Cat and DrvCat remain
  skipped; no INF or CAT appears under `artifacts/`.
- **Safety:** repository safety passes with one exact prototype-INF exception;
  `legacy/` remains unchanged; generated validation/build evidence is ignored
  under `artifacts/`.

## Unresolved blockers

- Static validation does not prove effective lower-filter ordering, attachment
  beneath `xusb22`, controller preservation, or runtime behavior.
- No complete package layout or generated catalog exists; no signing path is
  selected.
- Gate F is not operationally passed: no signed package has been independently
  reviewed or recovery-demonstrated on a noncritical system.
- No staging, Driver Store, registry, service, installation, loading, device,
  default-control, input, or transport authorization exists.
