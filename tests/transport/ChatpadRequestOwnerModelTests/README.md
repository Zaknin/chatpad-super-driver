# Chatpad request-owner model tests

These native x64 tests exercise the pure request-owner state machine with no
driver, WDF runtime, administrator privilege, device enumeration, controller,
or network dependency.

Coverage includes:

- every one of the 14 states against every one of the 19 event classes;
- rejected-transition state preservation and effects clearing;
- 30 explicit send, completion, cancellation, drain, generation, identity,
  reuse, fault, and exact-accounting scenarios;
- deterministic bounded event-sequence exploration through depth 10;
- invariant and snapshot validation after every explored transition.

Run Debug and Release through
`tools\Test-ChatpadRequestOwnerModel.ps1`. All output is isolated beneath
ignored `artifacts/`.
