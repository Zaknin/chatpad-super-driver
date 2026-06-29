# Chatpad Protocol Fixtures

`ChatpadKeyboardFixtures.h` contains neutral synthetic byte arrays for the
Phase 1 parser. They preserve the five-byte shape documented in
`docs/CHATPAD-PROTOCOL.md`, Section A, but are not device captures and are not
represented as observed hardware traffic.

## Provenance and Naming

The arrays use raw field and boundary names only. They do not label a modifier
bit as Shift, assign a key name to a raw byte, or claim a scan-code meaning.

| Fixture | Purpose |
| --- | --- |
| `ValidNoKeys` | Supported type with all remaining raw bytes zero. |
| `ValidRawModifierBit0` | Synthetic accepted raw modifier bit. |
| `ValidRawModifierBoundary` | Maximum modifier value accepted by Phase 1 policy. |
| `ValidRawKey0Nonzero` | Synthetic nonzero first raw key byte. |
| `ValidTwoRawKeys` | Synthetic nonzero values in both raw key slots. |
| `ValidRawBoundary` | Accepted raw boundary values, including unresolved Byte 4. |
| `ValidRawByte4Nonzero` | Nonzero unresolved Byte 4 value. |
| `ValidRawByte4Boundary` | Maximum unresolved Byte 4 value. |
| `UnsupportedTypeF0` | Documented `0xF0` form rejected neutrally as unsupported. |
| `UnsupportedTypeOther` | Another synthetic unsupported raw type. |
| `PolicyRejectedModifierBit4` | First modifier value rejected by Phase 1 policy. |
| `PolicyRejectedModifierBoundary` | Synthetic upper-bit rejection boundary. |
| `OversizedPacket` | Six-byte synthetic length boundary. |
| `LargerOversizedPacket` | Larger synthetic oversized input. |

The fixtures contain no executable legacy payload. Include the header only in
offline tests and run them with:

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```
