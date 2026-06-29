# Project State

*Last updated: 2026-06-29T22:15+04:00*

## Current state

- **Branch:** `feature/transport-adapter-contract`.
- **Starting checkpoint:** `37326ec5cc9c3745ee692f9250904475de0af7dd`.
- **Expected task commit:** `feat: add mocked transport adapter contract`.
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
- **Driver integration state:** `ChatpadFilter` runtime source is unchanged.
  Debug and Release compile-only builds pass, remain `Authenticode.NotSigned`,
  and show no SignTool execution. `ChatpadFilter.vcxproj` has no project
  reference to `ChatpadProtocol` or `ChatpadTransport` and does not compile/link
  transport or protocol sources.
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
