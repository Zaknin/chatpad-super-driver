# Project State

*Last updated: 2026-07-03 (compile-only evidence portability remediated; independent re-audit pending)*

## Current State

- **Branch:** `feature/runtime-bringup-native-interop-compile-only-evidence-remediation`.
- **Starting commit:** `ac32b5c8b165919913ef335be44e515f20308a52`.
- **Implementation commit represented by evidence:** `164903a8e890dfe1eb1709eeac1272aabcb81b3e`.
- **Compile-only evidence:** `docs/evidence/native-interop-compile-only-validation.json`, schema `chatpad-native-interop-compile-only-validation-v2`, validation ID `native-interop-compile-only-20260703T194533Z`.
- **Readiness manifest:** `docs/evidence/runtime-bringup-readiness-manifest.json`, schema `chatpad-runtime-bringup-readiness-manifest-v4`.

## Remediated Evidence Boundary

- The independent audit of `ac32b5c8b165919913ef335be44e515f20308a52` returned `AUDIT FAIL` because five tracked text inputs and 30 readiness-manifest entries used LF identities that did not match raw CRLF working-tree bytes in a clean Windows checkout.
- The auditor proved all five LF-normalized identities matched the recorded evidence. Native declarations, wrapper behavior, the 18-file compile output, and all safety boundaries were unchanged.
- Tracked text inputs now use declared `canonical_lf_text`: strict UTF-8, optional UTF-8 BOM removed, CRLF/CR normalized to LF, UTF-8 without BOM.
- Evidence records canonical SHA-256/size as authoritative and raw working-tree SHA-256/size as informational.
- Compile outputs use declared `raw_file_bytes`; output hashes are not claimed to be stable across commits or output roots.
- `-OutputRoot`, `-NoLoad`, `-NoReflection`, and `-NoInvoke` provide an ignored, contained audit mode. Audit mode writes compile output, logs, and evidence only below the supplied root and does not delete the canonical output root.
- The native declaration and source-boundary files were not modified.

## Readiness And Safety

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- `Apply`, `Restore`, and `Restart` remain deterministic non-executing blocked operations.
- Native loading, reflection, entry-point resolution, native invocation, device query, exact-instance access, Windows mutation, driver build/link, signing, CAT generation, packaging, staging, installation, loading, binding, restoration, restart, reboot, hardware access, registry/service/boot mutation, production driver/INF/project changes, binary changes, and `legacy/` changes remain unauthorized and were not performed.

## Verified Results

- Canonical compile-only validation: `PASS`; compiler exit `0`; warnings/errors `0/0`; 18 outputs.
- Compile-evidence validator: `PASS`, zero defects.
- Exact suite: `PASS` under Windows PowerShell 5.1 and PowerShell 7; 209 tests, 839 assertions, zero failures.
- Full readiness: `PASS` under both runtimes; 513 fixtures, 2,563 assertions, Windows mutation count `0`.
- Audit output root with spaces: `PASS`; 18 isolated outputs; canonical output unchanged.
- Invalid output root outside ignored `artifacts/`: rejected before directory creation.
- Manifest validation returned `PASS` under Windows PowerShell 5.1 and PowerShell 7 with 32 entries and zero defects. Manifest corruption regression returned `PASS` under both runtimes with 23 cases and zero failed cases. Native guard, repository safety, generated-file scan, and final Git checks passed during closeout.

## Unresolved Blockers

- The remediated compile-only evidence and audit-output-root behavior require a new independent read-only audit.
- Native SetupAPI/Newdev adapter execution remains unimplemented.
- No compiled assembly may be loaded, reflected over, executed, or invoked.
