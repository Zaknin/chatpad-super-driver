# Chatpad KMDF Request-Owner Context Compile Check

WDK static-library compile check for the compile-only request-owner context
definitions.

The target includes the context header, compiles the shared context source,
compiles the pure request-owner model source under the WDK toolchain, validates
compile-time invariants, compiles all four exact parentage-aware attribute
helpers, and compiles the ordinary storage initializer/pre-object validator
against the exact production helper.

It also compiles the exact dormant spinlock/request and outbound/inbound
preallocated-memory creation implementations, targetless `WdfRequestCreate`
signature, both exact `WdfMemoryCreatePreallocated` signatures, generated
typed-context accessor, deterministic request-context initialization, and
partial-state validator. The compile-check source takes function addresses
only; it does not invoke any creation helper.

This is a static-library compile-check only. It does not create or run a
driver, execute a WDF call, create a WDF object, delete or roll back an object,
format or submit a request, install, package, sign, query devices, or access
hardware.

The target also takes typed addresses of the rollback classifier and partial
creation rollback helper. Their implementations compile exact request and
spinlock `WdfObjectDelete` calls, effects clearing, state classification, and
post-rollback validation. Neither function is invoked by the compile-check.

The target now also takes a typed address of
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph` and compiles the
orchestration report/stage/result surface. The compile-check proves type and
linkage compatibility only; it still does not invoke orchestration, creation,
or rollback helpers.
