# ChatpadControlSetup Tests

These native offline tests obtain all six confirmed descriptors through
`ChatpadBuildActivationRequest` and validate exact setup bytes, little-endian
encoding, data-stage direction and lengths, copied `09 00`, absence of
unsupported `90 00`, deterministic failures, malformed synthetic descriptors,
value isolation, and sentinel protection.

Run Debug and Release through `tools/Test-ChatpadControlSetup.ps1`. The wrapper
also guards the pure source and project against platform/runtime dependencies,
requires the expected library and executable, prints exact assertion counts and
SHA-256 hashes, and verifies artifact containment.
