# Chatpad Protocol Parser and Offline State Machine

This directory contains a portable C interface and parser for the documented
five-byte Chatpad keyboard packet boundary. It allocates no memory, performs
no I/O, retains no caller pointer, and has no Windows, WDK, USB, HID, IOCTL,
device, or kernel dependency.

`ChatpadProtocolTypes.h` is the shared public type boundary. It defines
protocol-owned fixed-width byte and size types, the raw decoded packet, and
parse results without including a Windows or WDK header. It deliberately uses
no packing pragma: `ChatpadKeyboardPacket` is decoded output, not an on-wire
packed structure. `ChatpadKeyboardParser.h` adds the C function declaration
and C++ `extern "C"` linkage; `ChatpadKeyboardParser.c` is the portable parser
implementation.

`ChatpadProtocolStateMachine.h` and `.c` add a transport-independent,
caller-owned last-classification state machine. It performs no raw
initialization/status decoding and does not claim that its abstract events are
wire packets.

## Parser API

```c
ChatpadParseResult ChatpadParseKeyboardPacket(
    const ChatpadUInt8 *input,
    ChatpadSize length,
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

## State-Machine API

```c
ChatpadStateMachineResult ChatpadProtocolStateMachineInitialize(
    ChatpadProtocolStateMachine *stateMachine);

ChatpadStateMachineResult ChatpadProtocolStateMachineApply(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolEvent event,
    ChatpadProtocolTransition *transition);

ChatpadStateMachineResult ChatpadProtocolStateMachineReset(
    ChatpadProtocolStateMachine *stateMachine,
    ChatpadProtocolTransition *transition);

ChatpadStateMachineResult ChatpadProtocolEventFromParseResult(
    ChatpadParseResult parseResult,
    ChatpadProtocolEvent *event);
```

Initialization and explicit reset produce
`CHATPAD_PROTOCOL_STATE_AWAITING_CLASSIFICATION`. Each accepted event records
only the latest neutral classification:

| Abstract input event | Resulting state | Evidence meaning |
| --- | --- | --- |
| `ACCEPTED_KEYBOARD_PACKET` | `ACCEPTED_KEYBOARD_DATA` | Derived from parser `OK`; no key semantics added. |
| `UNSUPPORTED_PACKET` | `UNSUPPORTED_INPUT` | Derived from parser unsupported type; exact raw meaning remains unresolved. |
| `POLICY_REJECTED_PACKET` | `POLICY_REJECTED` | Derived from the conservative modifier policy. |
| `UNRESOLVED_CONTROL_STATUS` | `UNRESOLVED_CONTROL_STATUS` | Caller abstraction only; not decoded wire evidence. |
| `EXPLICIT_RESET` | `AWAITING_CLASSIFICATION` | Caller operation, not a device event. |

Parser null-argument, truncated, and oversized results are deliberately not
classified as protocol events and cause no transition. Invalid states/events
are rejected, failed transition outputs are cleared deterministically, and no
caller pointer is retained.

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

### Kernel-toolchain compatibility check

```powershell
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Release -Platform x64
```

This compiles the parser and state-machine sources and public headers as C with the WDK
`WindowsKernelModeDriver10.0` toolset. It produces only an isolated static
library beneath `artifacts/`; it has no runtime entry point and produces no
`.sys`. `ChatpadFilter` neither references nor links the compatibility library
or parser implementation.

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
| Kernel compatibility library (Debug) | `artifacts\bin\x64\Debug\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib` |
| Kernel compatibility library (Release) | `artifacts\bin\x64\Release\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib` |

## Tests

The test executable runs a self-contained assertion framework with 174 assertions:

- Argument and length validation (null inputs, truncated, oversized)
- Valid packet parsing (no keys, boundary values, raw key0 nonzero)
- Type and modifier policy (unsupported type, policy-rejected modifier)
- Raw byte 4 handling
- Repeatability and sequence
- Sentinel guards around the output packet
- State initialization, repeated/sequential events, and explicit reset
- Null/invalid state-machine arguments and deterministic failure output
- Parser-result mapping, unresolved abstract classification, and sentinels

```
Total: 174
Passed: 174
Failed: 0
```

No third-party test framework. No device or hardware APIs. Offline only.

## Project type

- **Native user-mode static library** — no CLR, no ATL, no MFC
- **C11**, MSVC v143, x64 only
- **Strict warnings with warnings-as-errors**
- **No precompiled headers**
- **Shared headers require no Windows or WDK API**
- **The isolated compatibility project compiles the implementation with the WDK toolchain only as a build-time proof**
- **No signing, deployment, or package configuration**
- **Parser code is not connected to the kernel driver**
- **State-machine code is not connected to the kernel driver**
- **Driver remains unsigned and nonfunctional**
