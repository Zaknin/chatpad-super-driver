# Project State

*Last updated: 2026-07-03 (native adapter composition-root scaffold in progress)*

## Current State

- **Branch:** `feature/runtime-bringup-native-adapter-composition-root`.
- **Starting point:** `a23259a73dc27f332a98f292e90866b0db42a764`, the accepted native adapter capability-boundary remediation finalization commit.
- **Expected implementation commit:** the commit containing the non-executing production native adapter scaffold, composition-root selection, offline regressions, schema/readiness integration, and design documentation.
- **Expected finalization commit:** the commit containing regenerated readiness manifest and continuity updates, if evidence binding requires a separate commit.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Adapter Scaffold

- A non-executing production native SetupAPI/Newdev adapter scaffold is implemented in `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`.
- Production identity is stable: `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic identity remains separate and explicit: `chatpad-fake-exact-instance-adapter-v1`.
- The composition root performs deterministic adapter selection and metadata wiring only. It is not an authorization boundary and does not create, expose, load, or invoke native Windows APIs.
- `Apply`, `Restore`, and `Restart` map deterministically to `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` with zero native operations, device queries, and Windows mutations.
- Unknown or missing adapter selections fail closed. Synthetic fallback is never implicit.
- Public/exported native adapter APIs accept no caller-supplied capability, token, sentinel, secret, or equivalent authorization value.
- Static executable guards reject current declarations or invocations of SetupAPI/Newdev/native Windows mutation APIs in tracked PowerShell files.

## Verified Results

- Smoke exact-instance suite under Windows PowerShell 5.1: `PASS`; 106 tests, 385 assertions, zero failed tests.
- Smoke full runtime bring-up readiness under Windows PowerShell 5.1: `PASS`; 410 fixtures, 2,109 assertions; exact suite 106/385; live readiness `BLOCKED`.
- Full dual-runtime validation, regenerated manifest validation, and final repository safety checks are pending before commit.

## Readiness And Safety

- Offline design/framework status: implementation in progress, smoke validated.
- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_AUDIT`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live binding authorization: `false`.
- No driver build/link, signing, CAT generation, packaging, staging, installation, binding, loading, restoration, restart, reboot, driver-store mutation, device query, hardware access, registry, service, boot, security, trace, event-log, protocol, input, certificate, credential, production source/INF, frozen binary, or `legacy/` action occurred.

## Unresolved Blockers

- Independent read-only audit of the production native adapter scaffold and composition-root wiring has not yet been performed.
- Native SetupAPI/Newdev execution remains unimplemented and explicitly blocked.
- Live execution remains blocked until a later implementation, audit, and explicit live authorization complete.
