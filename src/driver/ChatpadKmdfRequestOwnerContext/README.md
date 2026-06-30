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
lock-created, lock/request-created, outbound-memory-created,
both-memory-created, and fully ready structural states. Fully ready requires
all four object handles and bits, exact fixed storage, inactive request
context, non-admitting pure model state, and `OWNER_READY`.

The creation helpers preserve exact framework `NTSTATUS`, reject repeated or
out-of-order calls before a WDF creation call, publish only the corresponding
created bit, and implement no deletion or rollback. Memory handles remain
authoritative in the owner; the request context does not duplicate them.

The ordinary initializer and pre-object validator are now referenced by
`ChatpadFilter`; the per-device context embeds the authoritative owner. The
four WDF creation calls remain dormant and are never executed by validation or
production. Production still does not publish owner-ready, format or send
requests, register completion or cancel callbacks, delete or roll back
objects, install/load a driver, package, sign, query devices, or access
hardware.

The module now also compiles
`ChatpadKmdfRequestOwnerRollbackPartialCreation` and the non-mutating
`ChatpadKmdfRequestOwnerClassifyRollbackState`. Rollback accepts only exact
pre-ready partial states, initiates deletion of the request hierarchy before
the independent spinlock, clears published handles/bits after each delete
call, and leaves `MODEL_READY | FAULTED`. Clean and previously rolled-back
owners are idempotent. The fixed arrays and pure model remain unchanged.

The module now also compiles
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph`. It validates a clean
`MODEL_READY` baseline, calls the four creation helpers in spinlock, request,
outbound-memory, inbound-memory order, validates after each step, publishes
`OWNER_READY` last, validates the final ready-but-non-admitting state, and uses
the rollback helper exactly once after any object-published failure.

The two `WdfObjectDelete` call sites and the orchestration path remain
compile-only and never execute during validation or production. No individual
memory deletion, normal teardown, active-operation rundown, production
orchestration linkage, target discovery, request formatting, send, completion,
or cancellation exists.
