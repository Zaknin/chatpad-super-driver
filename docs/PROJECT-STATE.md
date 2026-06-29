# Project State

*Last updated: 2026-06-30T00:58+04:00*

## Current state

- **Branch:** `feature/wdf-control-setup-formatter`.
- **Starting checkpoint:** `9542fdd63493a455f6de4720542a48ca22f6fa96`.
- **Expected task commit:** `build: add compile-only wdf control setup formatter`.
- **Formatter:** `src/transport/ChatpadWdfControlSetup/` converts one validated,
  caller-owned `ChatpadControlSetupTranslation` into a caller-owned
  `WDF_USB_CONTROL_SETUP_PACKET`. It clears the output before validation and
  copies all eight authoritative setup bytes through the public
  `Generic.Bytes` member.
- **Installed WDK contract:** KMDF 1.15 `wdfusb.h` provides
  `WDF_USB_CONTROL_SETUP_PACKET`, `WDF_USB_CONTROL_SETUP_PACKET_INIT`,
  `_INIT_CLASS`, and `_INIT_VENDOR`. The helpers normalize fields and leave
  `wLength` for later request formatting, so exact representation conversion
  uses `Generic.Bytes` after conservative direction and length checks.
- **Field mapping:** bytes 0 and 1 preserve `bmRequestType` and `bRequest`;
  bytes 2-3, 4-5, and 6-7 preserve little-endian `wValue`, `wIndex`, and
  `wLength`. Payload ownership remains outside the setup packet.
- **Formatter validation:** rejects null input/output, invalid data direction,
  direction-bit mismatch for data stages, inconsistent outbound/inbound
  lengths, nonzero no-data lengths, and unsupported outbound capacity.
- **Debug formatter:**
  `artifacts\bin\x64\Debug\ChatpadWdfControlSetup\ChatpadWdfControlSetup.lib`,
  SHA-256 `3C0FD775FA83FDDDEC1B1624284CE6C823A482C9FD2845CAE9476B5C767D8CAA`.
- **Release formatter:**
  `artifacts\bin\x64\Release\ChatpadWdfControlSetup\ChatpadWdfControlSetup.lib`,
  SHA-256 `51BDB4301D32B4A70104E7EDE4617FA3E2EA3BE1CCCB73D319964012E307145B`.
- **Compile checks:** Debug and Release formatter compile checks pass and emit
  only isolated static-library output beneath `artifacts/`; source/project,
  signing, prohibited-output, and artifact-containment guards pass.
- **Regressions:** protocol Debug/Release `610/610`; transport Debug/Release
  `186/186`; lifecycle Debug/Release `109/109`; pure control setup
  Debug/Release `141/141`.
- **Existing kernel compatibility:** Debug and Release pass with `.lib` only,
  no signing, and no prohibited output.
- **Driver:** Debug and Release builds pass and remain
  `Authenticode.NotSigned`. Diagnostic linker inputs contain only
  `ChatpadFilterLifecycle.obj`, `driver.obj`, `device.obj`, and WDK system
  libraries.
- **Isolation:** `ChatpadFilter.vcxproj` has no formatter, control-setup,
  protocol, or transport reference and compiles no formatter source. The
  solution contains no project-dependency section linking the formatter to the
  driver.
- **Safety:** no WDF object, target, request, memory, queue, interface, timer,
  work item, callback, transfer, device access, installation, signing,
  packaging, deployment, loading, capture, elevation, or hardware behavior was
  added or performed. `legacy/` remains unchanged.

## Unresolved blockers

- No Windows 11 default-control-pipe access is proven.
- Control-IN response bytes, acknowledgement, readiness, retry, timeout, and
  activation success remain unresolved.
- No WDF target/request creation, request formatting/submission, completion,
  cancellation, endpoint, pipe, or continuous-input behavior exists.
- No reviewed reversible device-specific lower-filter installation/recovery
  specification exists.
- No INF, signing, package, deployment, installation, load, or hardware
  authorization exists.
