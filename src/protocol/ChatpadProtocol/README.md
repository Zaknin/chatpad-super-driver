# ChatpadProtocol Phase 1 Parser

This directory contains a portable C parser for the documented five-byte
Chatpad keyboard packet boundary. It allocates no memory, performs no I/O,
retains no caller pointer, and has no Windows, WDK, USB, HID, IOCTL, device,
or kernel dependency.

## Parser API

```c
ChatpadParseResult ChatpadParseKeyboardPacket(
    const uint8_t *input,
    size_t length,
    ChatpadKeyboardPacket *output);
```

The C-compatible header can be included by C or C++ callers. The caller owns
both input and output storage.

## Accepted Boundary

Phase 1 accepts exactly five bytes and only raw type `0x00`:

| Byte | Output field | Treatment |
| --- | --- | --- |
| 0 | `RawType` | Must be `0x00`; preserved raw. |
| 1 | `RawModifiers` | Bits 4-7 must be clear by conservative Phase 1 policy; preserved raw. |
| 2 | `RawKey0` | Preserved raw without assigning a key meaning. |
| 3 | `RawKey1` | Preserved raw without assigning a key meaning. |
| 4 | `RawByte4` | Meaning unresolved; preserved raw and never interpreted. |

The five-byte length is a Phase 1 project boundary. Inputs below five bytes
return `CHATPAD_PARSE_TRUNCATED`; inputs above five bytes return
`CHATPAD_PARSE_OVERSIZED`.

Type `0xF0` returns `CHATPAD_PARSE_UNSUPPORTED_TYPE`. The evidence shows that
legacy code ignores this form but does not establish its exact meaning, so the
parser does not call it repeated or assign another semantic interpretation.

Upper modifier bits return `CHATPAD_PARSE_POLICY_REJECTED_MODIFIER`. This is a
conservative project policy, not a confirmed device-validity rule. Values
`0x00` through `0x0F` are accepted and returned raw.

## Result Behavior

| Result | Meaning |
| --- | --- |
| `CHATPAD_PARSE_OK` | All five bytes passed the Phase 1 boundary and were copied raw. |
| `CHATPAD_PARSE_NULL_OUTPUT` | Output is null; no write is attempted. |
| `CHATPAD_PARSE_NULL_INPUT` | Input is null while length is nonzero. |
| `CHATPAD_PARSE_TRUNCATED` | Length is below five, including zero. |
| `CHATPAD_PARSE_OVERSIZED` | Length is above five. |
| `CHATPAD_PARSE_UNSUPPORTED_TYPE` | Raw type is not the supported `0x00` form. |
| `CHATPAD_PARSE_POLICY_REJECTED_MODIFIER` | Raw modifier has one or more upper bits set. |

When output is non-null, the parser clears every output field before any
failure return. Validation completes before any accepted input byte is copied.

## Build and Test

Run from the repository root:

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

The script initializes the installed MSVC x64 environment, compiles the parser
and standalone tests as C with strict warnings and warnings-as-errors, writes
all generated files beneath `artifacts/`, and runs the offline executable.

No Visual Studio solution or project integration exists yet. Testing requires
no hardware, device access, driver, or elevation.
