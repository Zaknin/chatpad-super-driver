# Project State

*Last updated: 2026-07-03 (native adapter scaffold integrity remediation finalized)*

## Current State

- **Branch:** `feature/runtime-bringup-native-adapter-scaffold-integrity-remediation`.
- **Starting point:** `b7f5f700c68af3846850b7ba69a34f7c8dd66614`, the native adapter composition-root scaffold finalization commit selected for integrity remediation.
- **Implementation commit:** `60da3ee244eaa5c28cb5022748a41ca95e6474cc`, containing explicit primitive adapter/operation gates, fresh per-call scaffold constants, fail-closed object handling, manifest path forwarding repair, re-audit gating, and offline integrity regressions.
- **Expected finalization commit:** the commit containing this file, the regenerated readiness manifest, and continuity updates.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Adapter Scaffold

- A non-executing production native SetupAPI/Newdev adapter scaffold is implemented in `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`.
- Production identity is stable: `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic identity remains separate and explicit: `chatpad-fake-exact-instance-adapter-v1`.
- The composition root performs deterministic adapter selection and metadata wiring only. It is not an authorization boundary and does not create, expose, load, or invoke native Windows APIs.
- `Apply`, `Restore`, and `Restart` map deterministically to `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` with zero native operations, device queries, and Windows mutations.
- Unknown, missing, non-string, or caller-object adapter and operation selections fail closed. Production selection is never implicit, and synthetic fallback is never implicit.
- Public/exported native adapter APIs accept no caller-supplied capability, token, sentinel, secret, object, object method, or equivalent authorization value.
- Native scaffold constants are re-created from literal values per call and are not trusted through mutable module state.
- Static executable guards reject current declarations or invocations of SetupAPI/Newdev/native Windows mutation APIs in tracked PowerShell files.

## Verified Results

- Exact-instance suite under Windows PowerShell 5.1: `PASS`; 116 tests, 492 assertions, zero failed tests.
- Exact-instance suite under PowerShell 7: `PASS`; 116 tests, 492 assertions, zero failed tests.
- Full runtime bring-up readiness under Windows PowerShell 5.1: framework `PASS`; 420 fixtures, 2,216 assertions; exact suite 116/492; live readiness `BLOCKED`.
- Full runtime bring-up readiness under PowerShell 7: framework `PASS`; 420 fixtures, 2,216 assertions; exact suite 116/492; live readiness `BLOCKED`.
- Regenerated readiness manifest: 25 entries; framework `PASS`; live readiness `BLOCKED`.
- Manifest validation and corruption regression: `PASS`; 18 cases, zero failed cases.
- Complete PSScriptAnalyzer under Windows PowerShell 5.1: 52 files analyzed; errors `0`, warnings `187`, information `989`, tool failures `0`.
- Native executable guard: `PASS`; 52 files scanned; zero native declaration or invocation matches.
- AST parse inventory: `PASS`; 45 `.ps1`, seven `.psm1`, 52 total files, zero parse-error files.
- Repository safety: `PASS`; deployment, signing, packaging, certificate/key creation, Windows mutation, device query, and hardware-access counters all `0`.

## Readiness And Safety

- Offline design/framework status: `PASS`, final dual-runtime evidence validated.
- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- No driver build/link, signing, CAT generation, packaging, staging, installation, binding, loading, restoration, restart, reboot, driver-store mutation, device query, hardware access, registry, service, boot, security, trace, event-log, protocol, input, certificate, credential, production source/INF, frozen binary, or `legacy/` action occurred.

## Unresolved Blockers

- Independent read-only re-audit of the remediated production native adapter scaffold and composition-root wiring has not yet been performed.
- Native SetupAPI/Newdev execution remains unimplemented and explicitly blocked.
- Live execution remains blocked until a later implementation, audit, and explicit live authorization complete.
