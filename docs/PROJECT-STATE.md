# Project State

*Last updated: 2026-06-30 (compile-only KMDF request-owner context checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-request-owner-context`.
- **Expected checkpoint commit:** this documentation is part of the
  `driver: define compile-only request contexts` commit created from
  `7f5ff4264d3171a1067a3eb0090f48b9979fe609`.
- **Authoritative request design:**
  [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
- **Pure model checkpoint:**
  [Offline Request-Owner State Model](OFFLINE-REQUEST-OWNER-STATE-MODEL.md).
- **KMDF context checkpoint:**
  [Offline KMDF Request-Owner Context Definition](OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md).
- **Implementation state:** `ChatpadKmdfRequestOwnerContext` is an isolated
  compile-only WDK static-library module. It defines the future per-device
  request-owner storage, typed reusable-request context, exact two-byte
  outbound/inbound transfer storage, future WDF handle fields, initialization
  mask, and compile-time invariants. It embeds the pure
  `ChatpadActivationRequestOwner` model and reuses the authoritative transport
  operation token and activation preparation types.
- **Dormancy:** `ChatpadFilter` does not include, compile, link, retain, embed,
  or invoke the new context module. Runtime callbacks remain unchanged.
- **Verification basis:** final validation is recorded in `docs/WORKLOG.md`.
  The new Debug/Release context compile-check wrapper, existing offline
  regressions, full solution builds, driver builds, repository safety, and
  `git diff --check` are the required evidence set.
- **Containment:** generated outputs and logs remain ignored beneath
  `artifacts/`. Source-controlled changes are limited to compile-only context
  declarations, compile-check project/wrapper, solution inclusion, pure-model
  kernel compile fallback, and directly relevant documentation.

## Unresolved blockers

- WDF object creation, request creation, transfer-memory creation, spinlock
  creation, target discovery, live formatting, submission, completion callback,
  cancel callback, executable delay scheduling, cleanup, and D0-exit rundown
  integration are not implemented or authorized.
- The exact framework-approved D0-exit deferral/rundown mechanism remains to be
  selected before completion/cancellation integration.
- Default-control visibility, effective placement beneath `xusb22`, controller
  preservation, activation effectiveness, Chatpad input, continuous input, and
  keyboard output remain unproven.
- Signing, trust, staging, Windows acceptance, installation, loading, and all
  hardware interaction remain incomplete and unauthorized.
- No usable production driver exists.
