# ChatpadTransport

`ChatpadTransport` is a portable C transport-adapter contract. It is a static
library with caller-owned state and no OS object ownership.

The layer accepts the existing protocol activation plan and emits neutral
operations through a caller-supplied sink:

- activation setup descriptors are copied from `ChatpadActivationRequest`;
- delay values are copied as metadata only;
- each operation receives a generation-bound token;
- cancellation and stale-generation handling are represented only by state and
  return codes.

The public contract intentionally contains no WDF, WDM, USB, HID, SetupAPI,
Configuration Manager, WinUSB, IOCTL, URB, endpoint, pipe, handle, ETW,
capture, scheduling, or callback behavior tied to a kernel framework. It does
not install, load, sign, package, deploy, or access hardware.

Build output:

- `artifacts\bin\x64\Debug\ChatpadTransport\ChatpadTransport.lib`
- `artifacts\bin\x64\Release\ChatpadTransport\ChatpadTransport.lib`

Run:

```powershell
.\tools\Test-ChatpadTransport.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadTransport.ps1 -Configuration Release -Platform x64
```
