# Chatpad Protocol Kernel Compile Check

This isolated WDK static-library project proves that the portable protocol
headers, declarative activation request builder, complete five-byte keyboard
parser, activation-sequence planner, mocked activation executor contract, and
transport-independent state machine compile as C with the
`WindowsKernelModeDriver10.0` toolset.

It also compiles the WDF-independent transport-adapter public header and
production source. The transport check covers caller-owned state initialization,
generation begin, callback-based activation-plan emission, and summary output
without creating or referencing WDF requests, USB targets, handles, endpoints,
or driver callbacks.

It is a compile-time compatibility check only. The project has no entry point,
driver object, callbacks, device or transport code, USB, HID, IOCTL, PnP,
power, registry, service, install, package, signing, deployment, or hardware
behavior. It produces a `.lib`, never a `.sys`, and nothing consumes that
library at runtime. In particular, `ChatpadFilter` has no reference to this
project or its output.

The activation-request check compiles request-count access and request
construction. The activation-sequence check compiles sequence-count access and
planner step construction. The activation-executor check compiles sink
callbacks and execution-summary output. The state-machine check compiles
initialization, reset, parser-result mapping, and abstract-event application.
The transport check compiles the adapter's generation-bound operation emission
surface against the same portable activation executor.
It does not decode raw initialization/status forms and introduces no runtime
driver integration.

Run both supported configurations from the repository root:

```powershell
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadProtocolKernelCompatibility.ps1 -Configuration Release -Platform x64
```

Generated files remain beneath:

- `artifacts\bin\x64\<Configuration>\ChatpadProtocolKernelCompileCheck\`
- `artifacts\obj\x64\<Configuration>\ChatpadProtocolKernelCompileCheck\`

The wrapper prints the full `.lib` path and its SHA-256, rejects any active
signing evidence, and fails if the build creates a driver, package,
certificate, installer, or deployment artifact.
