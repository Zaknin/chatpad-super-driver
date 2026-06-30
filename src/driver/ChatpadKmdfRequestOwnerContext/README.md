# Chatpad KMDF Request-Owner Context

Compile-only WDK/KMDF type declarations for the future activation request
owner.

This module defines the intended per-device owner storage, reusable request
context, future handle fields, fixed two-byte outbound and inbound transfer
storage, and context attribute declarations. It embeds the pure
`ChatpadActivationRequestOwner` model and reuses authoritative transport,
activation, and preparation types.

It does not create WDF objects, format or send requests, register completion or
cancel callbacks, link into `ChatpadFilter`, install/load a driver, package,
sign, query devices, or access hardware.
