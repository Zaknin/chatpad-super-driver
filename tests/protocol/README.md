# Chatpad Protocol Test Suite

Offline tests for the portable Chatpad keyboard parser, transport-independent
protocol state machine, declarative activation request builder,
activation-sequence planner, and mocked activation executor.

## Structure

- `ChatpadProtocolParserTests.c` — parser tests and aggregate test entry point
- `ChatpadActivationExecutorTests.c` — mocked executor ordering, rejection,
  summary, and recorder-isolation tests
- `ChatpadActivationRequestsTests.c` — exact activation request descriptor tests
- `ChatpadActivationSequenceTests.c` — exact activation sequence and timing
  metadata tests
- `ChatpadProtocolStateMachineTests.c` — focused state/event and mapping tests
- `fixtures/ChatpadActivationExecutionFixtures.h` — fixed-capacity mocked
  execution recorder and deterministic rejection helpers
- `fixtures/ChatpadActivationRequestFixtures.h` — evidence-derived activation
  request descriptors reconstructed from docs
- `fixtures/ChatpadActivationSequenceFixtures.h` — evidence-derived timing
  metadata for the activation sequence planner
- `fixtures/ChatpadKeyboardFixtures.h` — synthetic five-byte packet data
- `fixtures/ChatpadProtocolStateMachineFixtures.h` — synthetic abstract events

The suite contains 610 assertions: the original 85 parser assertions, 89
state-machine assertions, 126 activation-request assertions, 143
activation-sequence assertions, and 167 activation-executor assertions.
Activation request and sequence fixtures are reconstructed from confirmed
source evidence, not captured from hardware. The execution fixture is a
deterministic test recorder, not a transport implementation.
Abstract event fixtures are not wire packets or hardware captures and assign
no meaning to unresolved initialization/status bytes.

## Running the tests

### Integrated (MSBuild)

```powershell
.\tools\Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocol.ps1 -Configuration Release -Platform x64
```

The integrated script:

1. Locates the repository root
2. Calls `Get-DriverBuildEnvironment.ps1`
3. Cleans only the protocol artifact directories
4. Builds both `ChatpadProtocol` and `ChatpadProtocolTests` via MSBuild
5. Verifies `.lib` and `.exe` exist beneath `artifacts/`
6. Runs the test executable
7. Reports exit codes, assertion counts, and SHA-256 hashes
8. Verifies no generated output escaped `artifacts/`
9. Runs `Test-RepositorySafety.ps1`

### Direct compiler-only (existing)

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

Uses `cl.exe` and `link.exe` directly. No MSBuild. No solution integration.

## Test framework

A minimal self-contained framework with `AssertTrue`, `AssertResult`, and
`AssertPacket` helpers. Output is deterministic ASCII suitable for machine
parsing.

```
PASS: <test name>
Total: 610
Passed: 610
Failed: 0
```

## Safety

- No device or hardware APIs
- No elevation
- No deployment configuration
- No signing configuration
- No third-party dependencies
- No USB, HID, IOCTL, or kernel calls
- No driver installation or loading
- No initialization/status wire decoding or semantic key mapping
- No request sending, acknowledgement parsing, retry policy, ready-state
  transition, or fabricated response bytes
- No executable sleeps, timers, response deadlines, or device-required timing
  claims
- No executor transport, no request transmission, no retained caller pointers,
  and no dynamic allocation in the mocked recorder
