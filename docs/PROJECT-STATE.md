# Project State

*Last updated: 2026-06-30 (KMDF object-attribute preparation checkpoint)*

## Current state

- **Branch:** `feature/offline-kmdf-object-attributes`.
- **Expected checkpoint commit:** this documentation is part of the
  `driver: prepare dormant object attributes` commit created from
  `eee073e093ca10545ff6638044763653d5148487`.
- **Authoritative request design:**
  [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md).
- **Pure model checkpoint:**
  [Offline Request-Owner State Model](OFFLINE-REQUEST-OWNER-STATE-MODEL.md).
- **KMDF context checkpoint:**
  [Offline KMDF Request-Owner Context Definition](OFFLINE-KMDF-REQUEST-OWNER-CONTEXT-DEFINITION.md).
- **KMDF object lifecycle design:**
  [Windows 11 KMDF Request Object Creation and Cleanup Design](WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md).
- **KMDF owner storage initialization checkpoint:**
  [Offline KMDF Owner Storage Initialization Checkpoint](OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md).
- **KMDF object-attribute checkpoint:**
  [Offline KMDF Object-Attribute Preparation Checkpoint](OFFLINE-KMDF-OBJECT-ATTRIBUTE-PREPARATION.md).
- **Implementation state:** `ChatpadKmdfRequestOwnerContext` remains an
  isolated compile-only WDK static-library module. It now defines the future
  per-device request-owner storage, typed reusable-request context, fixed
  two-byte outbound/inbound transfer storage, future WDF handle fields,
  initialization mask, compile-time invariants, ordinary storage initialization
  and validation, and four exact object-attribute preparation APIs.
- **Storage helper state:** `ChatpadKmdfRequestOwnerInitializeStorage`
  initializes only ordinary owner storage, embeds and initializes the pure
  `ChatpadActivationRequestOwner` model, explicitly leaves all future WDF
  handle fields null, clears transfer storage and completion snapshot storage,
  and publishes only `MODEL_READY`. `ChatpadKmdfRequestOwnerValidatePreObjectState`
  validates signature/version, model-ready-only mask, null handles, zeroed
  fixed storage, zeroed completion snapshot, pure-model invariant success, and
  the pure model's unavailable baseline snapshot.
- **Object-lifecycle design state:** the future dormant creation location
  remains immediately after successful `WdfDeviceCreate` in `EvtDeviceAdd`.
  The future object graph remains device-owned activation-owner ordinary
  storage, device-parented `WDFSPINLOCK`, device-parented reusable
  `WDFREQUEST`, and request-parented outbound/inbound `WDFMEMORY` objects over
  fixed two-byte owner arrays.
- **Attribute helper state:** the compile-only helpers prepare caller-owned
  attributes for the device-parented bookkeeping lock, device-parented
  reusable request, request-parented outbound memory, and request-parented
  inbound memory. Only request attributes attach
  `ChatpadKmdfActivationRequestContext`. All leave execution level inherited,
  explicitly select no automatic synchronization, register no cleanup/destroy
  callback, reject null output/parent arguments, and create no object.
- **Dormancy:** `ChatpadFilter` does not include, compile, link, retain, embed,
  invoke, or call the context module. Runtime callbacks, `DriverEntry`, the
  live device context, INF, package/signing paths, and install/recovery
  material remain unchanged.
- **Verification basis:** final validation is recorded in `docs/WORKLOG.md`.
  This checkpoint uses repository inspection, semantic guards, WDK x64 Debug
  and Release compile-checks, repository safety, applicable offline regression
  builds/tests, and `git diff --check`.
- **Containment:** generated outputs and logs remain ignored beneath
  `artifacts/`. Source-controlled changes are limited to the isolated context
  module, its compile-check/validation wrapper, and documentation.

## Unresolved blockers

- WDF spinlock creation, request creation, transfer-memory creation, target
  discovery, live request formatting, completion registration, request
  submission, cancellation, executable delay scheduling, source cleanup
  integration, and D0-exit rundown implementation are not implemented or
  authorized.
- The storage and attribute helpers are not host-executed with a fake WDF
  runtime. They are WDK compile-checked and semantically guarded because the
  exact production helpers include WDK/KMDF handle types.
- The exact framework-approved D0-exit deferral/rundown mechanism remains to
  be selected before completion/cancellation integration.
- Default-control visibility, effective placement beneath `xusb22`, controller
  preservation, activation effectiveness, Chatpad input, continuous input, and
  keyboard output remain unproven.
- Signing, trust, staging, Windows acceptance, installation, loading, and all
  hardware interaction remain incomplete and unauthorized.
- No usable production driver exists.
