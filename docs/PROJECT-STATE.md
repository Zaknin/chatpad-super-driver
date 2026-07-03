# Project State

*Last updated: 2026-07-03 (independent exact-instance remediation audit)*

## Current state

- **Branch:** `feature/runtime-bringup-exact-instance-contract-remediation`.
- **Starting commit:** `9b380ef6e070311d682866a5f130b51a44f8485a`.
- **Implementation commits:**
  `a969745f589a55243ca9f9e964a45d7104f9a5e8` and
  `c3c0930db1326d56808879f12a9e8951f0051e80`, followed by deterministic
  analyzer-evidence commit `fd70e9779056b336b43d09be97e686fa61ed5514`.
- **Remediation finalization commit:**
  `d22ba050a6f5fea0ab9e8a71470c90a474d7b548`.
- **Expected audit closeout commit:** the commit containing this file, with no
  executable source, build, package, driver, frozen-binary, or `legacy/`
  changes.
- **Accepted offline baseline:** commit
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`; manifest SHA-256
  `35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088`.

## Remediated exact-instance framework

- Restoration execution derives its effective driver identity from the
  authenticated snapshot. A mismatched plan copy fails with
  `RESTORATION_IDENTITY_SNAPSHOT_MISMATCH` before an adapter restoration call.
- Evidence validation is permanently offline/synthetic for schema v1.
  Coordinated changes to adapter, mode, source, synthetic, producer, or
  evidence-mode fields fail with `UNTRUSTED_EVIDENCE_ORIGIN`.
- The production composition root has no trusted live capability. Every real
  Apply/Restore request is blocked with `LIVE_ADAPTER_NOT_IMPLEMENTED`;
  caller strings, Booleans, elevation, switches, and reproducible hashes do
  not authorize execution.
- `chatpad-canonical-json-v1` preserves JSON strings and types, sorts property
  names ordinally, preserves array order, emits UTF-8 without BOM, and rejects
  duplicate names case-insensitively before deserialization.
- Runtime validation enforces the complete checked-in plan/snapshot/identity
  shape, additional-property policy, required fields, types, relationships,
  hashes, provenance, expiry, and operation/action agreement.
- Device instance IDs use an explicit printable-ASCII allowlist and reject
  Unicode control, format, separator, combining, compatibility, and
  visually-confusable characters before adapter access.
- Active uncertainty cannot complete or classify as PASS. Verified recovery
  is represented separately from active uncertainty.

## Verified results

- T1-T39: `PASS`; 39 records; 155 assertions under Windows PowerShell 5.1
  and PowerShell 7, independently rerun from finalization commit `d22ba05`.
- Four-direction plan/snapshot matrix: `PASS`; identical canonical bytes and
  SHA-256 values in all directions. Audit hashes:
  plan `c2495c7961a2bd6b976556170c252550239c963a97b2ed4f53d8e62896ae0a04`;
  snapshot `d7c8a3fdef0ce2095e8faf980319354988db940e3fc4011c297de1b97fb941bb`.
- State-machine contract: 50 allowed edges, zero allowed-edge failures, five
  prohibited probes, zero prohibited acceptances.
- Full readiness ledger: 343 records and 1,879 assertions, increased from
  329/1,823 by exactly 14 records and 56 assertions in
  `exact-instance-offline`. All accounting reconciliation defects are zero.
- Synthetic accounting: 14 bind attempts, four restoration attempts, zero
  restart attempts. Live binding, restoration, restart, observations, and
  Windows mutations are all zero.
- PowerShell inventory: 45 `.ps1`, six `.psm1`, 51 total; AST errors `0`.
- Complete PSScriptAnalyzer: errors `0`, warnings `166`, information `910`,
  tool failures `0`; no blanket suppression.
- Canonical manifest validation and isolated corruption regression: `PASS`.
- Independent read-only audit result: `PASS`. T26-T39 all passed, including
  restoration-identity tampering, coordinated evidence spoofing, public
  real-gate spoofing, duplicate JSON names, required-field deletion,
  hidden-Unicode instance IDs, canonical stability, and analyzer scope.

## Readiness and safety

- Offline framework status: implemented; independent read-only audit completed
  and passed for remediation commit `fd70e9779056b336b43d09be97e686fa61ed5514`
  plus finalization commit `d22ba050a6f5fea0ab9e8a71470c90a474d7b548`.
- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Capability blocker: `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Live adapter status: `NOT_IMPLEMENTED`; live binding authorization: `false`.
- No driver build/link, signing, CAT generation, packaging, staging,
  installation, binding, loading, restoration, restart, reboot, driver-store,
  device-query, hardware, registry, service, boot, security, trace, event-log,
  protocol, input, certificate, credential, production source/INF, frozen
  binary, or `legacy/` action occurred.
