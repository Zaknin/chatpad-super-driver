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
runtime invocation. The authoritative request and sequence sources are also
compiled directly by `ChatpadFilter` under the WDK toolchain for the dormant
preparation layer; the user-mode library itself is not linked into the driver.

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

## Chatpad Control Setup Translation (offline)

`ChatpadControlSetup` is a portable C static library that accepts a
caller-provided `ChatpadActivationRequest` and produces caller-owned explicit
setup bytes and data-stage metadata. It has no packed overlay, platform header,
WDF/WDM type, target, request, transfer, response buffer, allocation, I/O, or
hardware behavior.

```powershell
.\tools\Test-ChatpadControlSetup.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadControlSetup.ps1 -Configuration Release -Platform x64
```

The wrapper runs a source/project guard, builds the native library and test
executable, requires `141/141` assertions, prints full paths and SHA-256 hashes,
and verifies containment beneath `artifacts/`.

| Output | Path |
| --- | --- |
| Debug library | `artifacts\bin\x64\Debug\ChatpadControlSetup\ChatpadControlSetup.lib` |
| Release library | `artifacts\bin\x64\Release\ChatpadControlSetup\ChatpadControlSetup.lib` |
| Debug test executable | `artifacts\bin\x64\Debug\ChatpadControlSetupTests\ChatpadControlSetupTests.exe` |
| Release test executable | `artifacts\bin\x64\Release\ChatpadControlSetupTests\ChatpadControlSetupTests.exe` |

## WDF Control Setup Formatter (compile-only)

`ChatpadWdfControlSetup` is an isolated WDK static library that converts a
validated `ChatpadControlSetupTranslation` to a caller-owned
`WDF_USB_CONTROL_SETUP_PACKET` value. It performs exact representation copying
and conservative direction/length validation only. It creates no WDF object,
formats or submits no request, owns no payload or response buffer, and is not
linked as its standalone library into `ChatpadFilter`. The same authoritative
formatter source is compiled directly by the driver preparation layer.

```powershell
.\tools\Test-ChatpadWdfControlSetup.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadWdfControlSetup.ps1 -Configuration Release -Platform x64
```

The wrapper checks production and compile-check source/project files for
prohibited runtime surfaces, validates the exact dormant driver integration,
builds the formatter compile check and its formatter dependency, prints both
static-library paths and SHA-256 values, rejects active signing or prohibited
output, and verifies artifact containment.

| Output | Path |
| --- | --- |
| Debug formatter library | `artifacts\bin\x64\Debug\ChatpadWdfControlSetup\ChatpadWdfControlSetup.lib` |
| Release formatter library | `artifacts\bin\x64\Release\ChatpadWdfControlSetup\ChatpadWdfControlSetup.lib` |
| Debug compile-check library | `artifacts\bin\x64\Debug\ChatpadWdfControlSetupCompileCheck\ChatpadWdfControlSetupCompileCheck.lib` |
| Release compile-check library | `artifacts\bin\x64\Release\ChatpadWdfControlSetupCompileCheck\ChatpadWdfControlSetupCompileCheck.lib` |

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
`ChatpadTransportAdapter.c`, `ChatpadControlSetup.c`, and their shared public
headers as C with the WDK
kernel toolchain. It is compile-time
compatibility validation only: it has no entry point, is not referenced by
`ChatpadFilter` as a project, and does not install, load, sign, package, deploy,
or access hardware. Some authoritative sources are independently compiled by
the driver preparation layer. This compatibility project never produces a
`.sys`.

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

## Offline extension-INF prototype

`prototypes/inf/ChatpadFilterExtension/ChatpadFilterExtension.inf` is an
isolated AMD64 Windows 11 extension-INF prototype. It is not referenced by the
solution, driver project, build wrapper, or a package target.

Validate it without elevation using installed WDK `InfVerif`:

```powershell
.\tools\Test-ChatpadFilterInfPrototype.ps1
```

The Windows PowerShell 5.1-compatible wrapper performs semantic safety guards,
discovers installed x64 `InfVerif`, reads its advertised options, runs primary
declarative `/k /v` validation plus information and annotated-output passes,
prints the INF SHA-256, and writes logs only beneath
`artifacts\inf-validation\<UTC timestamp>\`.

The INF declares future catalog identity `ChatpadFilterExtension.cat` because
declarative validation requires `CatalogFile`, but this task creates no CAT,
package, signature, service, Driver Store entry, registry value, or device
action. Static validation is not installation readiness.

## Kernel driver (compile-only dormant preparation)

The driver project compiles to a non-installable `.sys` with a KMDF
filter-capable device object, lifecycle bookkeeping, and one dormant
activation-step preparation API. The API is retained but not called from any
runtime callback. It creates no WDF object and performs no request formatting
against a target, submission, wait, delay, or hardware action. The driver is
not installed, signed, packaged, deployed, or loaded.

```powershell
.\tools\Build-Driver.ps1 -Configuration Debug -Platform x64
.\tools\Build-Driver.ps1 -Configuration Release -Platform x64
```

### Artifacts

| Output | Path |
| --- | --- |
| Debug driver | `artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` |
| Release driver | `artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` |

Both outputs remain `Authenticode.NotSigned`. The driver project has no project
references. It compiles the exact authoritative activation-request, sequence,
control-setup, and WDF formatter sources directly under the WDK toolchain; it
does not link the user-mode `ChatpadProtocol` library or `ChatpadTransport`.
Project defaults and the wrapper keep outputs and intermediates beneath
`artifacts/`.

## Repository safety

Run `tools\Test-RepositorySafety.ps1` to verify:

- No generated outputs, logs, or keys are tracked
- `legacy/` matches `origin/win11-port`
- No forbidden legacy binaries are indexed
- No packaging, certificate, or deployment files in the modern source tree
- No generated build outputs in forbidden locations
- All generated output is beneath `artifacts/` or ignored `.vs/`
- Prohibited commit `6502452` is not an ancestor of HEAD
