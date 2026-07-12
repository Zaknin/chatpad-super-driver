# Project State

*Last updated: 2026-07-12 (TASK 8I-P1B-LD-S1R2 package finalization)*

## Current state

- **Branch / starting HEAD:** `feature/native-adapter-self-test-signed-package` from `f0ca3a0e2c73aa1309812f94721f190fa7af835d`, parent `c70d1b94c9fdc14de598df8326b6e0e912dc811d`. The final task commit has that exact parent.
- **Status:** `SELF_TEST_SIGNED_LOCAL_DEVELOPMENT_PACKAGE_FINALIZED_FROM_CONTROLLED_POST_CAT_RECOVERY_CERTIFICATE_NOT_TRUSTED_TESTSIGNING_CONFIGURED_REBOOT_PENDING_PACKAGE_NOT_STAGED_NOT_INSTALLED_NOT_LOADED`.
- **Certificate/CER:** exactly one matching untrusted certificate remains only in `Cert:\CurrentUser\My`, thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; the tracked public DER CER is 1,104 bytes / SHA-256 `300238DB21F1ECD2F2C2E9F3A03EFF0147CBC419D474B1B3B89433569D5E6C96` and has no private key.
- **Final package:** `ChatpadFilter.sys` is 42,856 bytes / SHA-256 `B1FCF99F0B7631E83397396024E91213A4FCF9B145CCC97E01E6684562DC7190`; `ChatpadFilterExtension.cat` is 2,961 bytes / SHA-256 `B34C084E60020B401518A9259E476AFC22980DC2B51311EE053F1FF410DDCFF4`, Authenticode SHA-256 `672EA53BEC871D2948C4C5D81BB0473450897CCA0070DE1D3D017A554857DFE1`; INF remains 1,581 bytes / SHA-256 `0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC`. The CAT has one expected signer, no timestamp, and exactly INF/SYS members.
- **Recovery result:** the signed lowercase CAT directory entry was renamed through a temporary path to exact required casing. CAT bytes, signature, signer, timestamp state, and membership remained unchanged. S1R2 invoked Inf2Cat/signing/private-key access zero times.
- **Evidence limitation:** the generated CAT ordinary pre-sign identity is `NOT_RETAINED_BEFORE_IN_PLACE_SIGNING` / `NOT_AVAILABLE`; reconstruction was not attempted and the value must not be fabricated.
- **Evidence/contracts:** final signed-package evidence and immutable local APPLY package plan are tracked; readiness records 64 entries and the signed derivative without replacing the canonical reproducible unsigned package.
- **Validation:** focused recovery suite passes 24 tests / 94 assertions in PowerShell 7.6.3 and Windows PowerShell 5.1.26100.8655. Final complete dual-runtime matrix and readiness results are recorded in the task worklog.
- **Safety:** certificate trust was not installed; TESTSIGNING remains configured but ineffective until the already-pending reboot; no package staging, installation, driver load, device/driver-store query, SetupAPI/Newdev call, native execution, or live APPLY occurred.
- **Readiness:** `READY_FOR_SELF_TEST_SIGNED_PACKAGE_INDEPENDENT_AUDIT_ONLY`.
- **Blocker:** `BLOCKED_NATIVE_ADAPTER_SELF_TEST_SIGNED_PACKAGE_NOT_INDEPENDENTLY_AUDITED_CERTIFICATE_NOT_TRUSTED_AND_TESTSIGNING_NOT_EFFECTIVE_UNTIL_REBOOT`.
- **Next action:** TASK 8I-P1B-LD-S2 — independently audit the tracked self-test-signed package, evidence, contract, certificate, and explicit provenance limitation without mutation.
