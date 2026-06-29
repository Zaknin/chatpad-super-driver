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

## Chatpad Transport Adapter (offline)

Portable C transport-adapter contract plus deterministic mocked tests. Native
user-mode static library. It adapts the existing activation executor into
generation-bound neutral operations and models cancellation/stale completion
classification. It has no WDF, WDM, USB, HID, SetupAPI, Configuration Manager,
WinUSB, IOCTL, URB, endpoint, pipe, handle, ETW, capture, sleep, timer, retry,
readiness, response, driver callback, INF, package, signing, install, deploy,
load, or hardware behavior.

```powershell
.\tools\Test-ChatpadTransport.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadTransport.ps1 -Configuration Release -Platform x64
```

The wrapper builds `ChatpadTransport.vcxproj` and
`ChatpadTransportTests.vcxproj`, runs the native test executable, validates the
deterministic assertion summary, prints SHA-256 values for the `.lib` and test
executable, and confirms generated outputs stay beneath `artifacts/`.

### Artifacts

| Output | Path |
| --- | --- |
| Debug library | `artifacts\bin\x64\Debug\ChatpadTransport\ChatpadTransport.lib` |
| Release library | `artifacts\bin\x64\Release\ChatpadTransport\ChatpadTransport.lib` |
| Debug test executable | `artifacts\bin\x64\Debug\ChatpadTransportTests\ChatpadTransportTests.exe` |
| Release test executable | `artifacts\bin\x64\Release\ChatpadTransportTests\ChatpadTransportTests.exe` |

## ChatpadFilter lifecycle core (offline)

Portable C lifecycle core used by `ChatpadFilter` and compiled into a native
user-mode test executable. The core models only neutral lifecycle phases,
nonzero D0 generations, operation admission, rundown, stale-generation
rejection, underflow/overflow rejection, and snapshots. It has no WDF, WDM,
Windows, USB, HID, IOCTL, device handle, queue, request, timer, work item,
protocol, transport, allocation, I/O, global mutable state, or retained
pointer.

```powershell
.\tools\Test-ChatpadFilterLifecycle.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadFilterLifecycle.ps1 -Configuration Release -Platform x64
```

The wrapper builds `ChatpadFilterLifecycleTests.vcxproj`, runs the native test
executable, verifies deterministic assertion totals, prints the executable's
SHA-256, runs source/project guards for prohibited runtime surfaces, and keeps
all outputs beneath `artifacts/`.

| Output | Path |
| --- | --- |
| Debug lifecycle test executable | `artifacts\bin\x64\Debug\ChatpadFilterLifecycleTests\ChatpadFilterLifecycleTests.exe` |
| Release lifecycle test executable | `artifacts\bin\x64\Release\ChatpadFilterLifecycleTests\ChatpadFilterLifecycleTests.exe` |

## Kernel compatibility compile check

This isolated static-library build compiles `ChatpadActivationRequests.c`,
`ChatpadActivationSequence.c`, `ChatpadActivationExecutor.c`,
`ChatpadKeyboardParser.c`, `ChatpadProtocolStateMachine.c`,
`ChatpadTransportAdapter.c`, and their shared public headers as C with the WDK
kernel toolchain. It is compile-time
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

The driver project compiles to a non-installable `.sys` skeleton with a KMDF
filter-capable device object and lifecycle bookkeeping only. It is not
installed, signed, packaged, deployed, or loaded.

```powershell
.\tools\Build-Driver.ps1 -Configuration Debug -Platform x64
.\tools\Build-Driver.ps1 -Configuration Release -Platform x64
```

### Artifacts

| Output | Path |
| --- | --- |
| Debug driver | `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` |
| Release driver | `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` |

Both outputs remain `Authenticode.NotSigned`. The driver project compiles
`ChatpadFilterLifecycle.c` but still has no project reference or link to
`ChatpadProtocol` or `ChatpadTransport`.

## Repository safety

Run `tools\Test-RepositorySafety.ps1` to verify:

- No generated outputs, logs, or keys are tracked
- `legacy/` matches `origin/win11-port`
- No forbidden legacy binaries are indexed
- No packaging, certificate, or deployment files in the modern source tree
- No generated build outputs in forbidden locations
- All generated output is beneath `artifacts/` or ignored `.vs/`
- Prohibited commit `6502452` is not an ancestor of HEAD
