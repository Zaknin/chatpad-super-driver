# Chatpad Protocol Parser Tests

These are standalone offline native C tests for the Phase 1 five-byte parser.
They use no test framework, hardware, device API, or elevation.

Run from the repository root:

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

The runner compiles and links directly with the installed MSVC x64 tools. It
places objects beneath
`artifacts/obj/x64/Debug/ChatpadProtocolParser/`, the executable beneath
`artifacts/bin/x64/Debug/ChatpadProtocolParser/`, and logs beneath
`artifacts/logs/`. There is no Visual Studio solution or project integration.

The native executable prints deterministic ASCII-only `PASS`, `FAIL`, `Total`,
`Passed`, and `Failed` lines. It exits 0 only when every assertion passes.

The current suite contains 85 assertions covering:

1. Null output.
2. Null input with nonzero length.
3. Zero-length input.
4. Truncation at lengths 1, 2, 3, and 4.
5. Valid exact-length neutral input.
6. Valid raw boundary input.
7. Oversized length 6.
8. A larger oversized input.
9. Supported Phase 1 type `0x00`.
10. Unsupported `0xF0` and another unsupported raw type without assigning meaning.
11. Modifier-policy acceptance.
12. Modifier-policy rejection.
13. Raw Byte 4 preservation.
14. Deterministic output clearing on every testable failure path.
15. Repeated parsing of a valid packet.
16. Sequential parsing of different valid packets.
17. Unchanged sentinels surrounding the caller-owned output structure.

The executable itself accesses no hardware.
