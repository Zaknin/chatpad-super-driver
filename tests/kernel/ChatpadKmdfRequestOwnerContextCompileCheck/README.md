# Chatpad KMDF Request-Owner Context Compile Check

WDK static-library compile check for the compile-only request-owner context
definitions.

The target includes the context header, compiles the shared context source,
compiles the pure request-owner model source under the WDK toolchain, validates
compile-time invariants, compiles all four exact parentage-aware attribute
helpers, and compiles the ordinary storage initializer/pre-object validator
against the exact production helper.

It also compiles the exact dormant spinlock/request creation implementations,
targetless `WdfRequestCreate` signature, generated typed-context accessor,
deterministic request-context initialization, and partial-state validator.
The compile-check source takes function addresses only; it does not invoke
either creation helper.

This is a static-library compile-check only. It does not create or run a
driver, execute a WDF call, create a WDF object, create memory, delete or
rollback an object, format or submit a request, install, package, sign, query
devices, or access hardware.
