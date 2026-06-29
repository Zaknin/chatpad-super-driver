# Chatpad Protocol Kernel Compile Check

This isolated WDK static-library project proves that the portable protocol
headers and the complete five-byte keyboard parser implementation compile as C
with the `WindowsKernelModeDriver10.0` toolset.

It is a compile-time compatibility check only. The project has no entry point,
driver object, callbacks, device or transport code, USB, HID, IOCTL, PnP,
power, registry, service, install, package, signing, deployment, or hardware
behavior. It produces a `.lib`, never a `.sys`, and nothing consumes that
library at runtime. In particular, `ChatpadFilter` has no reference to this
project or its output.

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
