# Project State

*Last updated: 2026-06-30 (offline request-owner state model checkpoint)*

## Current state

- **Branch:** `feature/offline-request-owner-state-model`.
- **Expected checkpoint commit:** this documentation is part of the
  `model: add request owner state machine` commit created from
  `8444c0199144a6ccb24e8463a1778befe05736ec`.
- **Authoritative request design:**
  [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
- **Implemented request-owner checkpoint:**
  [Offline Request-Owner State Model](OFFLINE-REQUEST-OWNER-STATE-MODEL.md).
- **Implementation state:** `ChatpadRequestOwnerModel` is a pure,
  WDF-independent, caller-owned C state model for one future activation
  request-owner slot. It models lifecycle admission/release effects, operation
  identity, send and cancel call pins, immediate completion before framework
  call return, terminal ownership, stale/duplicate completion handling,
  draining, reuse, and faulted ownership.
- **Test state:** `ChatpadRequestOwnerModelTests` exhaustively classifies all
  14 states by 19 event classes, runs scenario tests and bounded deterministic
  exploration, and validates exact-once lifecycle accounting and race
  invariants.
- **Dormancy:** `ChatpadFilter` has no reference to the request-owner model.
  The existing dormant activation preparation seam remains uncalled by every
  runtime callback.
- **Verification basis:** final validation is recorded in `docs/WORKLOG.md`
  for this checkpoint. Debug/Release request-owner wrapper runs, full solution
  builds, existing protocol/transport/lifecycle/control-setup/kernel/WDF
  regressions, driver builds, repository safety, and `git diff --check` are the
  required evidence set.
- **Containment:** generated outputs and logs remain ignored beneath
  `artifacts/`. Source-controlled changes are limited to the pure model,
  offline tests, wrapper, solution inclusion, and continuity documentation.

## Unresolved blockers

- KMDF request context definitions, WDF object creation, transfer-memory
  creation, target discovery, live formatting, submission, completion callback,
  cancel callback, executable delay scheduling, and D0-exit rundown integration
  are not implemented or authorized.
- The exact framework-approved D0-exit deferral/rundown mechanism remains to be
  selected before completion/cancellation integration.
- Default-control visibility, effective placement beneath `xusb22`, controller
  preservation, activation effectiveness, Chatpad input, continuous input, and
  keyboard output remain unproven.
- Signing, trust, staging, Windows acceptance, installation, loading, and all
  hardware interaction remain incomplete and unauthorized.
- No usable production driver exists.
