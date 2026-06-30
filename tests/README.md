# Tests Directory

Offline tests belong here.

The current test layers cover portable protocol parsing/state, activation
requests and sequences, transport-adapter behavior, request-owner state
ownership, control-setup translation, lifecycle bookkeeping, WDK compile-only
compatibility, and dormant driver preparation integration.

`tests/transport/ChatpadRequestOwnerModelTests` exhaustively classifies the
pure request-owner model's 14 states by 19 event classes, verifies race and
exact-once lifecycle accounting scenarios, and performs bounded deterministic
exploration. It creates no WDF object and performs no device, driver,
installation, signing, registry, service, or hardware action.

No test in this repository should load, install, execute, or depend on a
legacy driver binary.
