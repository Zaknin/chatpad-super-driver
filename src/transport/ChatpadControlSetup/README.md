# ChatpadControlSetup

`ChatpadControlSetup` is a portable C static library that translates one
caller-provided `ChatpadActivationRequest` into caller-owned setup bytes and
data-stage metadata. The output contains the exact eight setup bytes, an
explicit data direction, copied outbound bytes, and expected inbound length.

Multibyte setup fields are encoded explicitly in little-endian order. No
packing, structure overlay, pointer, allocation, mutable global state, response
buffer, or retained caller storage is used. Failure clears a non-null output.

This layer does not format or submit a request and has no Windows, WDF, WDM,
USB-header, HID, IOCTL, URB, target, endpoint, pipe, handle, timer, thread, or
hardware behavior. It is not linked into `ChatpadFilter` and does not prove
default-control-pipe access or that any descriptor was transmitted or accepted.

Run native tests with:

```powershell
.\tools\Test-ChatpadControlSetup.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadControlSetup.ps1 -Configuration Release -Platform x64
```

Outputs remain under `artifacts\bin\x64\<Configuration>\ChatpadControlSetup\`.
