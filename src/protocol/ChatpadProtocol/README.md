# Chatpad Protocol Phase 1 Parser

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

### Integrated build (preferred)

```powershell
.\tools\Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocol.ps1 -Configuration Release -Platform x64
```

### Direct compiler-only test (existing)

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

The existing direct-compiler script remains available as a lightweight parser-only regression.
It does not use MSBuild or the solution.

### MSBuild directly

```powershell
& msbuild src\protocol\ChatpadProtocol\ChatpadProtocol.vcxproj /p:Configuration=Debug /p:Platform=x64 /p:RepoRoot=<repo-root>
```

## Artifacts

All generated files are contained beneath `artifacts/`:

| Output | Path |
| --- | --- |
| Debug library | `artifacts\bin\x64\Debug\ChatpadProtocol\ChatpadProtocol.lib` |
| Release library | `artifacts\bin\x64\Release\ChatpadProtocol\ChatpadProtocol.lib` |
| Debug test executable | `artifacts\bin\x64\Debug\ChatpadProtocolTests\ChatpadProtocolTests.exe` |
| Release test executable | `artifacts\bin\x64\Release\ChatpadProtocolTests\ChatpadProtocolTests.exe` |
| Intermediate (Debug) | `artifacts\obj\x64\Debug\ChatpadProtocol\` |
| Intermediate (Release) | `artifacts\obj\x64\Release\ChatpadProtocol\` |

## Tests

The test executable runs a self-contained assertion framework with 85 assertions:

- Argument and length validation (null inputs, truncated, oversized)
- Valid packet parsing (no keys, boundary values, raw key0 nonzero)
- Type and modifier policy (unsupported type, policy-rejected modifier)
- Raw byte 4 handling
- Repeatability and sequence
- Sentinel guards around the output packet

```
Total: 85
Passed: 85
Failed: 0
```

No third-party test framework. No device or hardware APIs. Offline only.

## Project type

- **Native user-mode static library** — no CLR, no ATL, no MFC
- **C11**, MSVC v143, x64 only
- **Strict warnings with warnings-as-errors**
- **No precompiled headers**
- **No Windows SDK, WDK, USB, HID, device, or kernel dependencies**
- **No signing, deployment, or package configuration**
- **Parser code is not connected to the kernel driver**
- **Driver remains unsigned and nonfunctional**
