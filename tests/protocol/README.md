# Chatpad Protocol Test Suite

Offline tests for the portable Chatpad keyboard parser.

## Structure

- `ChatpadProtocolParserTests.c` — assertion framework and 85 offline tests
- `fixtures/` — synthetic five-byte packet data; not hardware captures

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
Total: 85
Passed: 85
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
