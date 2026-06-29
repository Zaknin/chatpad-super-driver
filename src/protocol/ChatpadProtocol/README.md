# Chatpad Protocol Parser, Offline State Machine, Activation Requests, and Activation Sequence Planner

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

`ChatpadActivationRequests.h` and `.c` add a transport-independent declarative
request builder for the six activation control requests confirmed by
`docs/CHATPAD-INIT-STATUS-EVIDENCE.md`. It performs no I/O, exposes no
transport handle, retains no caller pointer, and never sends a request.

`ChatpadActivationSequence.h` and `.c` add a transport-independent activation
sequence planner over those six request descriptors. It obtains each request
from `ChatpadBuildActivationRequest`, adds sequence/request indexes and
declarative timing metadata, and performs no sleep, timer, timeout, retry,
transport access, acknowledgement parsing, response decoding, or ready-state
transition.

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

## Activation Request API

```c
size_t ChatpadGetActivationRequestCount(void);

ChatpadActivationBuildResult ChatpadBuildActivationRequest(
    size_t requestIndex,
    ChatpadActivationRequest *output);
```

The API returns caller-owned value copies from a private immutable table.
Exactly six descriptors are available, in the executable legacy order:

| Index | Direction | `bmRequestType` | `bRequest` | `wValue` | `wIndex` | `wLength` | Outbound payload | Expected inbound data |
|---:|---|---:|---:|---:|---:|---:|---|---:|
| 0 | host to device | `40` | `a9` | `a30c` | `4423` | `0000` | none | `0000` |
| 1 | host to device | `40` | `a9` | `2344` | `7f03` | `0000` | none | `0000` |
| 2 | host to device | `40` | `a9` | `5839` | `6832` | `0000` | none | `0000` |
| 3 | device to host | `c0` | `a1` | `0000` | `e416` | `0002` | none | `0002` |
| 4 | host to device | `40` | `a1` | `0000` | `e416` | `0002` | `09 00` | `0000` |
| 5 | device to host | `c0` | `a1` | `0000` | `e416` | `0002` | none | `0002` |

`09 00` is the only confirmed outbound payload. The unsupported `90 00`
comment is not represented. Device-to-host descriptors contain no fabricated
response bytes. Building descriptors does not imply initialization success,
acknowledgement, readiness, retry, timeout, status, or keepalive semantics.

## Activation Sequence API

```c
size_t ChatpadGetActivationSequenceStepCount(void);

ChatpadActivationSequenceResult ChatpadGetActivationSequenceStep(
    size_t stepIndex,
    ChatpadActivationSequenceStep *output);
```

Exactly six steps are available. `SequenceIndex` and `RequestIndex` both match
the requested step index, and `Request` is a value-copy descriptor produced by
the activation-request builder.

| Step | Request index | Delay before metadata | Delay after metadata |
|---:|---:|---:|---:|
| 0 | 0 | `0 ms` | `12 ms` |
| 1 | 1 | `0 ms` | `12 ms` |
| 2 | 2 | `0 ms` | `12 ms` |
| 3 | 3 | `0 ms` | `12 ms` |
| 4 | 4 | `0 ms` | `12 ms` |
| 5 | 5 | `0 ms` | `12 ms` |

The 12 ms after-delay is only the confirmed legacy post-`SendControlRequest`
sleep metadata. The zero before-delay means no confirmed pre-request timing
metadata, not a proven no-delay device requirement. The planner never executes
that timing.

## Activation Execution API

```c
ChatpadActivationExecutionResult ChatpadExecuteActivationPlan(
    const ChatpadActivationExecutionSink *sink,
    ChatpadActivationExecutionSummary *summary);
```

The executor consumes the activation-sequence planner and emits planned
operations through callbacks only. `OnRequest` receives each planned request
descriptor as a pointer valid only for the callback call. `OnDelayMetadata`
receives nonzero post-request delay metadata. Current planner data produces
six request callbacks and six delay metadata callbacks in alternating order.

Callback acceptance means the caller accepted the planned operation emission;
it does not mean the request was transmitted. Delay metadata emission does not
sleep or prove elapsed time. Rejection stops execution immediately and is
reported as a callback/API outcome, not as a device, USB, HID, IOCTL, driver,
or hardware result.

The summary contains planned step count, emitted request count, emitted delay
metadata count, last completed step index, rejected operation kind, and
rejected step index. It contains no response, acknowledgement, readiness,
transport status, elapsed-time, timeout, retry, allocation, or caller pointer.

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

The direct-compiler script remains available as a lightweight regression for
the parser, state machine, activation request builder, activation sequence
planner, activation executor, and their tests. It does not use MSBuild or the
solution.

### Kernel-toolchain compatibility check

```powershell
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Release -Platform x64
```

This compiles the activation request, activation sequence, activation
executor, parser, and state-machine sources and public headers as C with the WDK
`WindowsKernelModeDriver10.0` toolset. It produces only an isolated static
library beneath `artifacts/`; it has no runtime entry point and produces no
`.sys`. `ChatpadFilter` neither references nor links the compatibility library
or protocol implementation.

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

The test executable runs a self-contained assertion framework with 610 assertions:

- Argument and length validation (null inputs, truncated, oversized)
- Valid packet parsing (no keys, boundary values, raw key0 nonzero)
- Type and modifier policy (unsupported type, policy-rejected modifier)
- Raw byte 4 handling
- Repeatability and sequence
- Sentinel guards around the output packet
- State initialization, repeated/sequential events, and explicit reset
- Null/invalid state-machine arguments and deterministic failure output
- Parser-result mapping, unresolved abstract classification, and sentinels
- Activation request count, invalid index/null output handling, exact field
  construction, payload boundaries, `09 00` presence, `90 00` absence,
  deterministic clearing, repeated construction, value-copy isolation, and
  no fabricated device-to-host outbound data
- Activation sequence count, null/invalid handling, exact one-to-one request
  builder mapping, setup and payload preservation, timing metadata,
  deterministic clearing, repeated construction, stateless sequencing,
  value-copy isolation, sentinel guards, and absence of acknowledgement,
  readiness, retry, timeout, response, or transport behavior
- Activation executor null/missing callback/null summary handling, exact
  planner-consumption order, exact six request and six delay metadata
  callbacks, request value-copy propagation, `09 00`/`90 00` boundaries,
  rejection stop behavior, accepted-operation counts, no retry, repeated-run
  determinism, recorder isolation, fixed-capacity exhaustion, sentinel guards,
  and no hardware/transport semantics

```
Total: 610
Passed: 610
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
- **Activation-request code is not connected to the kernel driver**
- **Activation-sequence code is not connected to the kernel driver**
- **Activation-executor code is not connected to the kernel driver**
- **Driver remains unsigned and nonfunctional**
