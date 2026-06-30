# Project State

*Last updated: 2026-06-30 (documentation-only request-owner checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-request-owner-design`.
- **Starting checkpoint:**
  `b814822a540f84b93b1a02809fd1bdb0a61ac02d`
  (`driver: integrate offline activation plan`).
- **Authoritative request design:**
  [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
- **Selected future request strategy:** one reusable activation `WDFREQUEST`
  per device, explicitly parented to `WDFDEVICE`, with one typed request
  context and one operation slot.
- **Selected future buffer strategy:** separate request-parented two-byte
  outbound and inbound `WDFMEMORY` objects. Outbound capacity is the existing
  `CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH`; inbound capacity is the exact
  maximum expected by the six authoritative operations. No per-step allocation
  or arbitrary buffer size is selected.
- **Race/lifecycle design:** send intent and framework-call pins are published
  before outside-lock send/cancel calls. Completion owns terminal retirement
  after a successful send; immediate completion cannot make the slot reusable
  until the initiating framework call returns. One lifecycle acquire maps to
  one exact release obligation for the captured generation.
- **Synchronization:** the existing future per-device `WDFSPINLOCK` decision
  is preserved for short bookkeeping only. WDF calls, waits, delays, and
  lengthy logging remain outside it.
- **Production integration:** dormant `ChatpadPrepareActivationStep` remains
  compiled into `ChatpadFilter` and uncalled by every runtime callback.
- **Runtime state:** no WDF target, request, transfer memory, completion,
  cancellation, queue, timer, work item, wait, submission, executable delay,
  USB access, or hardware path exists.
- **Verification basis:** previous Debug/Release build and offline test results
  remain recorded in the integration checkpoint. This documentation-only task
  did not rebuild or rerun source, driver, or kernel tests.
- **Containment:** only tracked Markdown documentation is changed. Generated
  outputs and evidence remain ignored.

## Unresolved blockers

- The pure request-owner state model and race/accounting tests are not
  implemented or authorized.
- KMDF request context definitions, object creation, memory creation, target
  discovery, formatting, submission, completion, cancellation, and executable
  delay scheduling are not implemented or authorized.
- The exact framework-approved D0-exit deferral/rundown mechanism remains to be
  selected before completion/cancellation integration.
- Default-control visibility, effective placement beneath `xusb22`, controller
  preservation, activation effectiveness, Chatpad input, continuous input,
  and keyboard output remain unproven.
- Signing, trust, staging, Windows acceptance, installation, loading, and all
  hardware interaction remain incomplete and unauthorized.
- No usable production driver exists.
