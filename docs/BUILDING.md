# Building

This document covers how to build every artifact in the repository.
All builds produce output beneath `artifacts/`. No artifacts are placed
in the source tree.

## Prerequisites

- Visual Studio 2022 with MSVC v143 x64 build tools
- Windows 10 SDK 10.0.26100.0
- WDK 10.0.26100.0
- Git
- PowerShell 5.1+

Run `tools/Get-DriverBuildEnvironment.ps1` to verify the full toolchain.
The current machine exposes KMDF headers and x64 libraries through version
1.35; existing driver projects still use the WDK default KMDF target 1.15.

## Chatpad Protocol Parser, State Machine, Activation Requests, Activation Sequence Planner, and Activation Executor (offline)

Portable C parser for the Phase 1 keyboard packet boundary plus a
transport-independent abstract state machine and declarative activation request
builder/planner/executor. Native user-mode static library. No hardware,
elevation, transport, request sending, executable timing, or driver
integration.

### Integrated build and test (preferred)

```powershell
.\tools\Test-ChatpadProtocol.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocol.ps1 -Configuration Release -Platform x64
```

Builds `ChatpadProtocol.vcxproj` and `ChatpadProtocolTests.vcxproj` via
MSBuild, runs the test executable, and verifies artifact containment.

### Direct compiler regression

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

Uses `cl.exe` and `link.exe` directly. It compiles the parser, state machine,
activation request builder, activation sequence planner, activation executor,
and offline tests without MSBuild or solution integration.

### Artifacts

| Output | Path |
| --- | --- |
| Debug library | `artifacts\bin\x64\Debug\ChatpadProtocol\ChatpadProtocol.lib` |
| Release library | `artifacts\bin\x64\Release\ChatpadProtocol\ChatpadProtocol.lib` |
| Debug test executable | `artifacts\bin\x64\Debug\ChatpadProtocolTests\ChatpadProtocolTests.exe` |
| Release test executable | `artifacts\bin\x64\Release\ChatpadProtocolTests\ChatpadProtocolTests.exe` |

## Kernel compatibility compile check

This isolated static-library build compiles `ChatpadActivationRequests.c`,
`ChatpadActivationSequence.c`, `ChatpadActivationExecutor.c`,
`ChatpadKeyboardParser.c`, `ChatpadProtocolStateMachine.c`, and their shared
public headers as C with the WDK kernel toolchain. It is compile-time
compatibility validation only: it has no entry point, is not referenced by
`ChatpadFilter`, and does not install, load, sign, package, deploy, or access
hardware. It never produces a `.sys`.

```powershell
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Release -Platform x64
```

| Output | Path |
| --- | --- |
| Debug compatibility library | `artifacts\bin\x64\Debug\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib` |
| Release compatibility library | `artifacts\bin\x64\Release\ChatpadProtocolKernelCompileCheck\ChatpadProtocolKernelCompileCheck.lib` |

The wrapper builds only the compatibility project, prints the library's full
path and SHA-256, rejects signing evidence or prohibited driver/package
outputs, and confirms every generated compatibility file remains beneath
`artifacts/`.

## Kernel driver (compile-only skeleton)

The driver project compiles to a nonfunctional `.sys` skeleton.
It is not installed, signed, or loaded.

```powershell
.\tools\Build-Driver.ps1 -Configuration Debug -Platform x64
.\tools\Build-Driver.ps1 -Configuration Release -Platform x64
```

### Artifacts

| Output | Path |
| --- | --- |
| Debug driver | `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` |
| Release driver | `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` |

Both outputs remain `Authenticode.NotSigned`.

## Repository safety

Run `tools\Test-RepositorySafety.ps1` to verify:

- No generated outputs, logs, or keys are tracked
- `legacy/` matches `origin/win11-port`
- No forbidden legacy binaries are indexed
- No packaging, certificate, or deployment files in the modern source tree
- No generated build outputs in forbidden locations
- All generated output is beneath `artifacts/` or ignored `.vs/`
- Prohibited commit `6502452` is not an ancestor of HEAD
