# Chatpad KMDF Request-Owner Context

Compile-only WDK/KMDF type declarations for the future activation request
owner.

This module defines the intended per-device owner storage, reusable request
context, future handle fields, fixed two-byte outbound and inbound transfer
storage, context attribute declarations, ordinary storage initialization, and
pre-object validation. It embeds the pure `ChatpadActivationRequestOwner`
model and reuses authoritative transport, activation, and preparation types.

`ChatpadKmdfRequestOwnerInitializeStorage` initializes only ordinary storage
and sets only `CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`. It leaves
`WDFREQUEST`, `WDFMEMORY`, and `WDFSPINLOCK` handles null and does not publish
owner-ready state. `ChatpadKmdfRequestOwnerValidatePreObjectState` validates
that pre-object baseline before any future object-creation slice runs.

It does not create WDF objects, format or send requests, register completion or
cancel callbacks, link into `ChatpadFilter`, install/load a driver, package,
sign, query devices, or access hardware.
