# Project State

*Last updated: 2026-06-30 (design-only KMDF request object lifecycle checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-request-object-lifecycle-design`.
- **Expected checkpoint commit:** this documentation is part of the
  `docs: define kmdf object lifecycle` commit created from
  `1be4637aa91fa675bc9b45caddd41e40279c1252`.
- **Authoritative request design:**
  [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
- **Pure model checkpoint:**
  [Offline Request-Owner State Model](OFFLINE-REQUEST-OWNER-STATE-MODEL.md).
- **KMDF context checkpoint:**
  [Offline KMDF Request-Owner Context Definition](OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md).
- **KMDF object lifecycle design:**
  [Windows 11 KMDF Request Object Creation and Cleanup Design](WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md).
- **Implementation state:** `ChatpadKmdfRequestOwnerContext` is an isolated
  compile-only WDK static-library module. It defines the future per-device
  request-owner storage, typed reusable-request context, exact two-byte
  outbound/inbound transfer storage, future WDF handle fields, initialization
  mask, and compile-time invariants. It embeds the pure
  `ChatpadActivationRequestOwner` model and reuses the authoritative transport
  operation token and activation preparation types.
- **Object-lifecycle design state:** the future dormant creation location is
  selected as immediately after successful `WdfDeviceCreate` in
  `EvtDeviceAdd`. The future object graph is device-owned activation-owner
  ordinary storage, device-parented `WDFSPINLOCK`, device-parented reusable
  `WDFREQUEST`, and request-parented outbound/inbound `WDFMEMORY` objects over
  fixed two-byte owner arrays. The selected rollback strategy is explicit
  reverse-order deletion during initialization failure, then framework parent
  hierarchy cleanup during normal device teardown after separately designed
  operation rundown.
- **Dormancy:** `ChatpadFilter` does not include, compile, link, retain, embed,
  invoke the context module, create request-owner WDF objects, format a
  request, register completion, send/cancel a request, discover a target, or
  access hardware. Runtime callbacks remain unchanged.
- **Verification basis:** final documentation validation is recorded in
  `docs/WORKLOG.md`. This checkpoint used repository inspection, installed
  KMDF 1.15 header inspection, Markdown link validation, required-section
  validation, contradiction searches, repository safety, and `git diff --check`.
- **Containment:** generated outputs and logs remain ignored beneath
  `artifacts/`. Source-controlled changes are limited to tracked Markdown
  design and continuity documentation.

## Unresolved blockers

- WDF object creation, request creation, transfer-memory creation, spinlock
  creation, target discovery, live formatting, submission, completion callback,
  cancel callback, executable delay scheduling, source cleanup integration, and
  D0-exit rundown implementation are not implemented or authorized.
- The exact framework-approved D0-exit deferral/rundown mechanism remains to be
  selected before completion/cancellation integration.
- Default-control visibility, effective placement beneath `xusb22`, controller
  preservation, activation effectiveness, Chatpad input, continuous input, and
  keyboard output remain unproven.
- Signing, trust, staging, Windows acceptance, installation, loading, and all
  hardware interaction remain incomplete and unauthorized.
- No usable production driver exists.
