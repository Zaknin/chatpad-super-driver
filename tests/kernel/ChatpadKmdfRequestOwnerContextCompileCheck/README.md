# Chatpad KMDF Request-Owner Context Compile Check

WDK static-library compile check for the compile-only request-owner context
definitions.

The target includes the context header, compiles the shared context source,
compiles the pure request-owner model source under the WDK toolchain, validates
compile-time invariants, and compiles request/context attribute declarations.
It does not create or run a driver, create WDF objects, call WDF runtime APIs,
install, package, sign, query devices, or access hardware.
