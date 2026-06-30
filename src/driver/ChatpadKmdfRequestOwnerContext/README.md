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

The isolated module also compiles four independent dormant creation helpers:

- `ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock` can create at most one
  device-parented bookkeeping `WDFSPINLOCK`;
- `ChatpadKmdfRequestOwnerCreateReusableRequest` can create at most one
  device-parented targetless `WDFREQUEST`, retrieve its typed context, and
  initialize that context to inactive authoritative defaults;
- `ChatpadKmdfRequestOwnerCreateOutboundMemory` can create at most one
  request-parented preallocated `WDFMEMORY` descriptor over the owner's exact
  two-byte outbound array;
- `ChatpadKmdfRequestOwnerCreateInboundMemory` can create at most one
  request-parented preallocated `WDFMEMORY` descriptor over the owner's exact
  two-byte inbound array, after outbound memory exists.

`ChatpadKmdfRequestOwnerValidateCreationState` distinguishes the pre-object,
lock-created, lock/request-created, outbound-memory-created, and
both-memory-created partial states. Fully ready remains invalid. The creation
helpers preserve exact framework `NTSTATUS`, reject repeated or out-of-order
calls before a WDF creation call, publish only the corresponding created bit,
and implement no deletion or rollback. Memory handles remain authoritative in
the owner; the request context does not duplicate them.

The four WDF creation calls are compiled into static libraries but are never
executed by the compile-check. This module still does not publish owner-ready,
format or send requests, register completion or cancel callbacks, delete or
roll back objects, link into `ChatpadFilter`, install/load a driver, package,
sign, query devices, or access hardware.

The module now also compiles
`ChatpadKmdfRequestOwnerRollbackPartialCreation` and the non-mutating
`ChatpadKmdfRequestOwnerClassifyRollbackState`. Rollback accepts only exact
pre-ready partial states, initiates deletion of the request hierarchy before
the independent spinlock, clears published handles/bits after each delete
call, and leaves `MODEL_READY | FAULTED`. Clean and previously rolled-back
owners are idempotent. The fixed arrays and pure model remain unchanged.

The two `WdfObjectDelete` call sites are compile-only and never execute during
validation. No individual memory deletion, normal teardown, active-operation
rundown, creation orchestration, or production linkage exists.
