# Tests Directory

Planned tests belong here.

The first test layer should use protocol packet fixtures and user-mode parser tests. Those tests should cover valid chatpad packets, controls packets, malformed lengths, unknown filter modes, and boundary conditions around the legacy 32-byte endpoint buffers.

No test in this repository should load, install, execute, or depend on a legacy driver binary.
