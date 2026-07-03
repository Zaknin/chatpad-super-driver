# Project State

*Last updated: 2026-07-03 (native adapter design gate finalization)*

## Current State

- **Branch:** `feature/runtime-bringup-native-adapter-design-gate`.
- **Starting point:** `feature/runtime-bringup-exact-instance-contract-remediation` at `5ef224e27b53f4c5a562be3556173bc7856f69d9`.
- **Implementation commits:** `df31800580222c2ac0a24393c8d608b648602d79`, `a3de8ea4f7d38d20c5acdcc96e3a985940fcb63b`, `72f6d9d7f41bd19e22c5a0b5e283f237b40e33d5`, and `66e357d7cd54cfab23eb1ce3b237aa63aae96eb0`.
- **Expected finalization commit:** the commit containing this file, the regenerated readiness manifest, and the continuity updates.
- **Accepted offline baseline:** commit `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256 `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Native Adapter Design Gate

- A non-executing native SetupAPI/Newdev adapter design gate is implemented in `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`.
- The gate defines the future API sequence, required structures, driver-node identity evidence, exact-instance binding/restoration proof, restart/reboot separation, error taxonomy, evidence fields, and composition-root boundary.
- Mutation authorization uses a module-private sentinel capability. Public callers cannot construct a trusted live mutation capability; `New-ChatpadNativeMutationCapability` returns blocker `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Read-only design probes are separate from mutation capability and do not authorize live API calls.
- Static executable guards reject current declarations or invocations of SetupAPI/Newdev/native Windows mutation APIs in tracked PowerShell files.
- There is still no native adapter implementation and no production composition root that can execute native binding, restoration, restart, or reboot.

## Verified Results

- Exact-instance suite: `PASS` under Windows PowerShell 5.1 and PowerShell 7; 54 tests, 215 assertions, zero failed tests.
- Full runtime bring-up readiness: exit `0` under both runtimes; 1,939 assertions; live readiness `BLOCKED`.
- Four-direction cross-runtime plan/snapshot matrix: `PASS`; four directions, zero failed directions.
- Complete PSScriptAnalyzer: 52 tracked files analyzed; errors `0`, warnings `168`, information `927`, tool failures `0`, no blanket suppression.
- AST parse inventory: 52 tracked PowerShell files parsed; parse-error file count `0`.
- Native executable guard: `PASS`; 52 files scanned, zero forbidden native declaration/invocation matches.
- Readiness manifest generation: 25 entries; framework status `PASS`; live installation readiness `BLOCKED`.
- Readiness manifest validation and isolated corruption regression: `PASS`; zero manifest defects and 18/18 corruption cases passed.
- Repository safety: `PASS`; deployment, signing, packaging, certificate, key, Windows mutation, device query, and hardware-access counters all `0`.

## Readiness And Safety

- Offline design/framework status: implemented and validated.
- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Capability blocker: `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Live adapter status: `NOT_IMPLEMENTED`; live binding authorization: `false`.
- No driver build/link, signing, CAT generation, packaging, staging, installation, binding, loading, restoration, restart, reboot, driver-store mutation, device query, hardware access, registry, service, boot, security, trace, event-log, protocol, input, certificate, credential, production source/INF, frozen binary, or `legacy/` action occurred.

## Unresolved Blockers

- Independent read-only audit of this design gate has not yet been performed.
- Native SetupAPI/Newdev implementation remains a future separately authorized task.
- Live execution remains blocked until a later implementation, audit, and explicit live authorization complete.
