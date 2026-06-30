# Chatpad KMDF Request-Owner Context

Compile-only WDK/KMDF type declarations for the future activation request
owner.

This module defines the intended per-device owner storage, reusable request
context, future handle fields, fixed two-byte outbound and inbound transfer
storage, exact caller-owned object-attribute preparation, ordinary storage
initialization, and pre-object validation. It embeds the pure
`ChatpadActivationRequestOwner` model and reuses authoritative transport,
activation, and preparation types.

`ChatpadKmdfRequestOwnerInitializeStorage` initializes only ordinary storage
and sets only `CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`. It leaves
`WDFREQUEST`, `WDFMEMORY`, and `WDFSPINLOCK` handles null and does not publish
owner-ready state. `ChatpadKmdfRequestOwnerValidatePreObjectState` validates
that pre-object baseline before any future object-creation slice runs.

The four attribute helpers prepare only:

- device-parented bookkeeping-lock attributes without context;
- device-parented reusable-request attributes with
  `ChatpadKmdfActivationRequestContext`;
- request-parented outbound-memory attributes without context;
- request-parented inbound-memory attributes without context.

All four reject null output or parent arguments, leave execution level
inherited, select no automatic synchronization, and register no cleanup or
destroy callback.

The isolated module also compiles two independent dormant creation helpers:

- `ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock` can create at most one
  device-parented bookkeeping `WDFSPINLOCK`;
- `ChatpadKmdfRequestOwnerCreateReusableRequest` can create at most one
  device-parented targetless `WDFREQUEST`, retrieve its typed context, and
  initialize that context to inactive authoritative defaults.

`ChatpadKmdfRequestOwnerValidateCreationState` distinguishes the pre-object,
lock-created, and lock/request-created partial states. Fully ready remains
invalid. The creation helpers preserve exact framework `NTSTATUS`, reject
repeated calls before a WDF creation call, publish only the corresponding
created bit, and implement no deletion or rollback.

The two WDF creation calls are compiled into static libraries but are never
executed by the compile-check. This module still does not create memory
objects, publish owner-ready, format or send requests, register completion or
cancel callbacks, link into `ChatpadFilter`, install/load a driver, package,
sign, query devices, or access hardware.
