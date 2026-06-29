# ChatpadWdfControlSetup

`ChatpadWdfControlSetup` is an isolated kernel-toolchain static library. It
validates the data-stage metadata in a caller-owned
`ChatpadControlSetupTranslation` and copies its exact eight setup bytes into a
caller-owned `WDF_USB_CONTROL_SETUP_PACKET.Generic.Bytes` value.

The installed KMDF 1.15 `wdfusb.h` exposes `Generic.Bytes[8]` and the
`WDF_USB_CONTROL_SETUP_PACKET_INIT`, `_INIT_CLASS`, and `_INIT_VENDOR` helpers.
Those helpers normalize request type and recipient and intentionally leave
`wLength` unset for a later request-formatting API. The formatter therefore
uses the public generic-byte member to preserve the authoritative translation
without reinterpreting request type, recipient, value, index, or length.
The header follows the installed KMDF USB template's declaration-only include
order: `wdf.h`, `usb.h`, `usbdlib.h`, then `wdfusb.h`.

This module creates no WDF object and has no device, target, request, memory,
queue, interface, timer, work item, callback, payload-buffer, response-buffer,
formatting, submission, completion, cancellation, I/O, or hardware behavior.
It is not referenced by `ChatpadFilter` and does not prove default-control-pipe
access, transmission, acceptance, acknowledgement, readiness, or response
semantics.

Build the formatter and its compile check with:

```powershell
.\tools\Test-ChatpadWdfControlSetup.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadWdfControlSetup.ps1 -Configuration Release -Platform x64
```
