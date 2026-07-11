# Project State

*Last updated: 2026-07-11 (TASK 8I-P1B-1-C1 canonical Windows 11 package source)*

## Current state

- **Branch:** `feature/native-adapter-live-apply-package-source`.
- **Starting commit:** `e5c456efdf5d34863084be5558859a4884bd6a83` (`fix: reject pre-existing native declaration types`).
- **Current commit:** the single expected commit has parent `e5c456efdf5d34863084be5558859a4884bd6a83` and subject `feat: define canonical live apply package source`; derive its exact hash from Git after commit creation.
- **Accepted external audits:** TASK 8F-R2 passed for audited commit `4d3df0d6c623567655cd33db8d4163d0624696c5`, closing the TASK 8F native-declaration remediation lane. TASK 8I-P1A-R2R1 passed for audited commit `e5c456efdf5d34863084be5558859a4884bd6a83`, closing the supplemental declaration and dormant loader lane. Both audits were intentionally read-only and have no closure commits.
- **Production driver source:** `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`, the repository's only `ConfigurationType=Driver` project; AMD64 KMDF output `ChatpadFilter.sys`.
- **Canonical production INF source:** `src/driver/ChatpadFilter/package/ChatpadFilterExtension.inf`, 1,581 bytes, SHA-256 `0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC`.
- **Package model:** Extension class, exact `USB\VID_045E&PID_028E` physical-controller model, non-associated demand-start `ChatpadFilter` service, declarative `AddFilter`, `FilterPosition=Lower`, KMDF 1.15, DIRID 13, preserved Microsoft `xusb22.inf` / `xusb22` function driver, and no named filter level.
- **Package-source contract:** `tools/ExactInstance/contracts/chatpad-live-apply-package-source-plan.json`, schema `chatpad-live-apply-package-source-plan-v1`, 11,888 bytes, SHA-256 `EF814E4525275000F0A14A27F708C1D04148FF2902F5D6CB2F5504E317D33E81`.
- **Current package status:** `CANONICAL_WINDOWS_11_DRIVER_PACKAGE_SOURCE_DEFINED_NOT_BUILT_NOT_CATALOGED_NOT_SIGNED_NOT_STAGED_NOT_INSTALLABLE`.
- **Validation:** focused package-source tests pass 29 tests / 29 assertions in PowerShell 7 and Windows PowerShell 5.1. WDK 10.0.26100.6584 InfVerif `/k /v` reports `INF is VALID`. Required compatibility suites pass with exact expected counts in both runtimes; TASK 8G, TASK 8H, and TASK 8F-R1 regressions pass 297/297, 286/286, and 34/34. Readiness remains 57 entries / 0 defects.
- **Prototype boundary:** `prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf` remains 1,701 bytes, SHA-256 `821368368000A706BD2EAC0CB659090915C34E363F59F3F19F23D6DE0C4A05F4`, offline-only and excluded from production.
- **Signing state:** no production signing route has yet been selected or executed. P1B-2 must choose Microsoft attestation or WHCP signing without test mode, boot-policy changes, Secure Boot changes, or temporary certificate trust.
- **TASK 8I readiness:** blocked. No authorization phrase is active or carried forward.
- **Current blocker:** `BLOCKED_NATIVE_ADAPTER_CANONICAL_DRIVER_PACKAGE_NOT_BUILT_CATALOGED_SIGNED_AND_INDEPENDENTLY_AUDITED`.
- **Safety:** no driver build, SYS/catalog generation, signing, staging, installation, native declaration compilation/loading, SetupAPI/Newdev invocation, device/registry/service query, authorization issuance/consumption, binding, restart, rollback, restoration, or Windows mutation occurred. All prohibited counters remain zero.
- **Next task:** TASK 8I-P1B-2 — Build, catalog, sign, validate, and freeze the canonical Windows 11 driver package and immutable APPLY candidate contract.
