# Project State

*Last updated: 2026-06-29T23:05+04:00*

## Current state

- **Branch:** `feature/kmdf-lifecycle-scaffold`.
- **Starting checkpoint:** `29c3fc1a55ded35c8e33f6ceb88e2a434334ef9a`.
- **Expected task commit:** `feat: add kmdf lifecycle scaffold`.
- **ChatpadFilter lifecycle scaffold:** implemented as a compile-only,
  non-installable KMDF filter-capable skeleton with per-device context and
  portable lifecycle core state.
- **Filter declaration:** `EvtDeviceAdd` calls `WdfFdoInitSetFilter(DeviceInit)`
  and registers only prepare/release hardware and D0 entry/exit callbacks.
  This makes the binary filter-capable only; it does not prove stack
  attachment, lower-filter position, or hardware-ID targeting.
- **Lifecycle model:** neutral phases are unset, created, prepared, D0 active,
  rundown requested, D0 stopped, and released. Generation zero is invalid; the
  first D0 entry returns generation `1`; later D0 entries after completed D0
  exit increment generation; exhaustion fails deterministically.
- **Admission/rundown:** D0 entry opens operation admission. D0 exit closes
  admission, begins rundown, and completes only when outstanding operation
  count is zero. Stale-generation acquire/release/rundown/completion attempts
  do not mutate current state. No wait, retry, timer, work item, thread, or
  locking claim is made; the core is externally serialized.
- **Lifecycle tests:** native offline lifecycle tests live under
  `tests/driver/ChatpadFilterLifecycleTests/` and pass `109/109` in Debug and
  Release.
- **Transport adapter contract:** implemented as a portable C static library at
  `src/transport/ChatpadTransport/ChatpadTransport.vcxproj`.
- **Transport model:** caller-owned state, explicit device generation, neutral
  operation tokens, cancellation/stale-completion classification, and
  callback-based activation-plan emission through the existing protocol
  executor.
- **Mock/test model:** `tests/transport/ChatpadTransportTests.vcxproj` uses a
  bounded test-only mock sink and deterministic offline tests. Current
  transport assertion count: `186/186` in Debug and Release.
- **Protocol regression state:** direct protocol parser/state/activation tests
  pass `610/610`; Debug and Release project regressions pass `610/610`.
- **Kernel compatibility:** the existing WDK static-library compile check now
  includes the transport public header and production source in Debug and
  Release. It produces `.lib` only and no `.sys`, INF, CAT, signing, package,
  install, deployment, or runtime driver artifact.
- **Driver integration state:** Debug and Release compile-only builds pass,
  remain `Authenticode.NotSigned`, and show no SignTool execution.
  `ChatpadFilter.vcxproj` compiles `ChatpadFilterLifecycle.c`, has no project
  reference to `ChatpadProtocol` or `ChatpadTransport`, and does not compile or
  link transport or protocol sources.
- **Windows 11 architecture:** unchanged conditional direction: a future
  device-specific lower filter on physical `USB\VID_045E&PID_028E` beneath
  `xusb22`, still unresolved until default-control and input-transfer evidence
  is separately proven.
- **Safety:** no WDF/WDM/USB/HID/SetupAPI/Configuration Manager/WinUSB/IOCTL/
  URB/device-handle/endpoint/pipe/ETW/capture/sleep/timer/thread/retry/
  readiness/response/driver-callback/INF/CAT/sign/package/install/load/deploy
  behavior was added. `legacy/` remains immutable; generated outputs remain
  under ignored `artifacts/`.

## Unresolved blockers

- No current Windows 11 transport capability is proven.
- No endpoint, pipe, interface, default-control access, response semantics,
  acknowledgement, readiness, retry, timeout, or hardware behavior is selected
  or implemented.
- Driver installation, signing, packaging, loading, and live device testing
  remain unauthorized.
- Future installation remains responsible for exact
  `USB\VID_045E&PID_028E` hardware-ID targeting and device-specific lower
  filter placement beneath `xusb22`; no INF or install behavior exists here.
