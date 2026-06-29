# Chatpad Protocol Test Suite

Offline tests for the portable Chatpad keyboard parser and transport-independent
protocol state machine.

## Structure

- `ChatpadProtocolParserTests.c` — parser tests and aggregate test entry point
- `ChatpadProtocolStateMachineTests.c` — focused state/event and mapping tests
- `fixtures/ChatpadKeyboardFixtures.h` — synthetic five-byte packet data
- `fixtures/ChatpadProtocolStateMachineFixtures.h` — synthetic abstract events

The suite contains 174 assertions: the original 85 parser assertions plus 89
state-machine assertions. Abstract event fixtures are not wire packets or
hardware captures and assign no meaning to unresolved initialization/status
bytes.

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
Total: 174
Passed: 174
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
