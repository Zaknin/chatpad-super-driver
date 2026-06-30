# Chatpad KMDF Request-Owner Context Compile Check

WDK static-library compile check for the compile-only request-owner context
definitions.

The target includes the context header, compiles the shared context source,
compiles the pure request-owner model source under the WDK toolchain, validates
compile-time invariants, compiles all four exact parentage-aware attribute
helpers, and compiles the ordinary storage initializer/pre-object validator
against the exact production helper.

This is a compile-check only. It does not create or run a driver, create WDF
objects, call WDF object-creation or request-submission APIs, install, package,
sign, query devices, or access hardware.
